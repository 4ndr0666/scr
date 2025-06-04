#!/usr/bin/perl
# shellcheck disable=all
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

# Function to log operations
sub log_operations {
    my ($message) = @_;
    my $logfile = "ntfs_repair.log";
    open(my $logfh, '>>', $logfile) or die "Could not open log file: $!";
    my $timestamp = localtime->strftime('%Y-%m-%d %H:%M:%S');
    print $logfh "$timestamp - $message\n";
    close($logfh);
}

# Function to read a sector from the disk
sub read_sector {
    my ($device, $sector_number, $size) = @_;
    open(my $fh, '<', $device) or die "Error opening device: $!";
    binmode($fh);
    seek($fh, $sector_number * $size, SEEK_SET) or die "Error seeking to sector: $!";
    my $buffer;
    read($fh, $buffer, $size) or die "Error reading sector: $!";
    close($fh);
    return $buffer;
}

# Function to write a sector to the disk
sub write_sector {
    my ($device, $sector_number, $buffer) = @_;
    open(my $fh, '+<', $device) or die "Error opening device: $!";
    binmode($fh);
    seek($fh, $sector_number * $SECTOR_SIZE, SEEK_SET) or die "Error seeking to sector: $!";
    print $fh $buffer or die "Error writing sector: $!";
    close($fh);
}

# Function to check for NTFS signature
sub check_ntfs_signature {
    my ($boot_sector) = @_;
    return substr($boot_sector, 3, 8) eq "NTFS    ";
}

# Function to recreate NTFS boot sector
sub recreate_ntfs_boot_sector {
    my ($device) = @_;
    my $boot_sector = read_sector($device, 0, $SECTOR_SIZE);
    if (!check_ntfs_signature($boot_sector)) {
        print "NTFS signature missing. Recreating boot sector...\n";
        log_operations("NTFS signature missing. Recreating boot sector...");

        # Example boot sector template
        my $new_boot_sector = $NTFS_SIGNATURE . substr($boot_sector, 11); # Preserving remaining part

        # Write the new boot sector
        write_sector($device, 0, $new_boot_sector);
        print "Boot sector recreated.\n";
        log_operations("Boot sector recreated.");
    } else {
        print "NTFS signature is present. No need to recreate boot sector.\n";
        log_operations("NTFS signature is present. No need to recreate boot sector.");
    }
}

# Function to attempt basic NTFS repair with ntfsfix
sub ntfsfix_repair {
    my ($device) = @_;
    my $output = `sudo ntfsfix $device 2>&1`;
    log_operations("ntfsfix output: $output");
    if ($? == 0) {
        print "ntfsfix completed successfully.\n";
        log_operations("ntfsfix completed successfully on $device.");
    } else {
        print "ntfsfix encountered errors.\n";
        log_operations("ntfsfix encountered errors on $device.");
    }
}

# Function to backup MBR
sub backup_mbr {
    my ($device, $backup_file) = @_;
    open(my $src, '<', $device) or die "Error opening device for MBR backup: $!";
    open(my $dst, '>', $backup_file) or die "Error creating MBR backup file: $!";
    binmode($src);
    binmode($dst);
    my $buffer;
    read($src, $buffer, $MBR_SIZE) or die "Error reading MBR: $!";
    print $dst $buffer or die "Error writing MBR backup: $!";
    close($src);
    close($dst);
    log_operations("MBR backup completed to $backup_file.");
    print "MBR backup completed.\n";
}

# Function to check and create swap file if necessary
sub ensure_swap {
    my $swap_info = `swapon --show`;
    if ($swap_info !~ /\/swapfile/) {
        print "No swap file detected. Creating swap file...\n";
        log_operations("No swap file detected. Creating swap file...");

        system("sudo fallocate -l 4G /swapfile");
        system("sudo chmod 600 /swapfile");
        system("sudo mkswap /swapfile");
        system("sudo swapon /swapfile");

        my $new_swap_info = `swapon --show`;
        log_operations("Swap file created. New swap info: $new_swap_info");
        print "Swap file created.\n";
    } else {
        print "Swap file already exists.\n";
        log_operations("Swap file already exists.");
    }
}

# Main logic
sub main {
    my $device;
    my $backup_file;
    GetOptions(
        'device=s' => \$device,
        'backup=s' => \$backup_file,
    ) or die "Invalid options passed. Use --device <device> [--backup <backup_file>]\n";

    die "Usage: $0 --device <device> [--backup <backup_file>]\n" unless $device;

    if ($backup_file) {
        backup_mbr($device, $backup_file);
    }

    ensure_swap();
    recreate_ntfs_boot_sector($device);
    ntfsfix_repair($device);
}

# Run the main logic
main();
