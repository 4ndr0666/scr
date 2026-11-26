#!/usr/bin/perl
use strict;
use warnings;
use File::Copy;
use IO::Handle;
use Fcntl qw(:seek);
use Getopt::Long;
use File::Basename;
use File::Path qw(make_path);
use Time::Piece;

# Constants
my $SECTOR_SIZE = 512;
my $NTFS_SIGNATURE = "\xEB\x52\x90NTFS    ";
my $MBR_SIZE = 512;
my $MIN_SWAP_SIZE = 4 * 1024 * 1024 * 1024; # 4GB
my $LOG_FILE = $ENV{NTFS_REPAIR_LOG} // "ntfs_repair.log";

sub log_operations {
    my ($message) = @_;
    open(my $logfh, '>>', $LOG_FILE) or die "Could not open log file '$LOG_FILE': $!";
    my $timestamp = localtime->strftime('%Y-%m-%d %H:%M:%S');
    print $logfh "$timestamp - $message\n";
    close($logfh);
}

sub read_sector {
    my ($device, $sector_number, $size) = @_;
    open(my $fh, '<', $device) or die "Error opening device '$device': $!";
    binmode($fh);
    seek($fh, $sector_number * $size, SEEK_SET) or die "Error seeking to sector: $!";
    my $buffer = '';
    my $n = read($fh, $buffer, $size);
    close($fh);
    die "Error reading sector from '$device': $!" unless defined($n) && $n == $size;
    return $buffer;
}

sub write_sector {
    my ($device, $sector_number, $buffer) = @_;
    die "Refusing to write invalid sector buffer length (" . length($buffer) . " != $SECTOR_SIZE)\n"
        unless defined($buffer) && length($buffer) == $SECTOR_SIZE;
    open(my $fh, '+<', $device) or die "Error opening device '$device' for write: $!";
    binmode($fh);
    seek($fh, $sector_number * $SECTOR_SIZE, SEEK_SET) or die "Error seeking to sector: $!";
    print $fh $buffer or die "Error writing sector: $!";
    close($fh);
}

sub check_ntfs_signature {
    my ($boot_sector) = @_;
    return defined($boot_sector) && length($boot_sector) >= 11 && substr($boot_sector, 3, 8) eq "NTFS    ";
}

sub recreate_ntfs_boot_sector {
    my ($device, $dry_run) = @_;
    my $boot_sector = read_sector($device, 0, $SECTOR_SIZE);
    if (!check_ntfs_signature($boot_sector)) {
        print "NTFS signature missing. Recreating boot sector...\n";
        log_operations("NTFS signature missing on $device.");
        if ($dry_run) {
            print "[dry-run] Would write repaired 512-byte NTFS boot sector to $device.\n";
            return;
        }
        my $new_boot_sector = $NTFS_SIGNATURE . substr($boot_sector, 11);
        write_sector($device, 0, $new_boot_sector);
        print "Boot sector recreated.\n";
        log_operations("Boot sector recreated on $device.");
    } else {
        print "NTFS signature is present. No need to recreate boot sector.\n";
        log_operations("NTFS signature is present on $device.");
    }
}

sub ntfsfix_repair {
    my ($device, $dry_run) = @_;
    if ($dry_run) {
        print "[dry-run] Would execute: ntfsfix $device\n";
        return 0;
    }
    my @cmd = ($> == 0) ? ('ntfsfix', $device) : ('sudo', 'ntfsfix', $device);
    open(my $pipe, '-|', @cmd) or die "Failed to invoke ntfsfix: $!";
    local $/;
    my $output = <$pipe> // '';
    close($pipe);
    my $rc = $? >> 8;
    log_operations("ntfsfix output (rc=$rc): $output");
    if ($rc == 0) {
        print "ntfsfix completed successfully.\n";
        log_operations("ntfsfix completed successfully on $device.");
    } else {
        print STDERR "ntfsfix encountered errors (rc=$rc).\n";
        log_operations("ntfsfix encountered errors on $device (rc=$rc).");
    }
    return $rc;
}

sub backup_mbr {
    my ($device, $backup_file) = @_;
    my $buffer = read_sector($device, 0, $MBR_SIZE);
    open(my $dst, '>', $backup_file) or die "Error creating MBR backup file '$backup_file': $!";
    binmode($dst);
    print $dst $buffer or die "Error writing MBR backup: $!";
    close($dst);
    log_operations("MBR backup completed to $backup_file.");
    print "MBR backup completed.\n";
}

sub ensure_swap {
    my ($dry_run) = @_;
    open(my $pipe, '-|', 'swapon', '--show') or die "Failed to run swapon --show: $!";
    local $/;
    my $swap_info = <$pipe> // '';
    close($pipe);
    if ($swap_info !~ /\/swapfile/) {
        print "No swap file detected. Creating swap file...\n";
        log_operations("No swap file detected. Creating /swapfile...");
        if ($dry_run) {
            print "[dry-run] Would allocate and activate 4G /swapfile.\n";
            return;
        }
        my @prefix = ($> == 0) ? () : ('sudo');
        for my $cmd (
            [@prefix, 'fallocate', '-l', '4G', '/swapfile'],
            [@prefix, 'chmod', '600', '/swapfile'],
            [@prefix, 'mkswap', '/swapfile'],
            [@prefix, 'swapon', '/swapfile'],
        ) {
            system(@$cmd) == 0 or die "Swap setup command failed: @$cmd (rc=" . ($? >> 8) . ")\n";
        }
        log_operations("Swap file created and activated.");
        print "Swap file created.\n";
    } else {
        print "Swap file already exists.\n";
        log_operations("Swap file already exists.");
    }
}

sub show_help {
    print <<"EOF";
Usage: $0 --device <device_or_image> [--backup <file>] [--ensure-swap] [--dry-run] [--help]

Options:
  --device <path>   Target NTFS block device or image file (required)
  --backup <file>   Backup first 512-byte boot sector before repair
  --ensure-swap     Create/activate a 4G /swapfile if none is active
  --dry-run         Inspect and report actions without modifying the device
  -h, --help        Show this help message and exit
EOF
}

sub main {
    my ($device, $backup_file, $do_swap, $dry_run, $help);
    GetOptions(
        'device=s'    => \$device,
        'backup=s'    => \$backup_file,
        'ensure-swap' => \$do_swap,
        'dry-run'     => \$dry_run,
        'help|h'      => \$help,
    ) or die "Invalid options passed. Run $0 --help for usage.\n";

    if ($help) {
        show_help();
        return 0;
    }

    die "Usage: $0 --device <device> [--backup <file>] [--ensure-swap] [--dry-run]\n" unless defined($device) && length($device);
    die "Device or image does not exist: $device\n" unless -e $device;

    backup_mbr($device, $backup_file) if $backup_file;
    ensure_swap($dry_run) if $do_swap;
    recreate_ntfs_boot_sector($device, $dry_run);
    my $rc = ntfsfix_repair($device, $dry_run);
    return $rc;
}

exit main();
