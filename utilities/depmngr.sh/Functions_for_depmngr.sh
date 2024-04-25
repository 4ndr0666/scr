# Parse CLI options
PARAMETERS=("$@")
PARSED_OPTIONS=$(getopt --options="a" --longoptions="aur,skip-mirrorlist,noconfirm" --name "$0" -- "${PARAMETERS[@]}")
if [[ $? -ne 0 ]]; then
    echo -e "\033[1;31m\nFailed to parse CLI options. Use --help for more information.\n\033[0m"
    exit 1
fi
eval set -- "$PARSED_OPTIONS"
while true; do
    case "$1" in
        -a | --aur)
            UPDATE_AUR=1
            shift
            ;;
        --skip-mirrorlist)
            SKIP_MIRRORLIST=1
            shift
            ;;
        --noconfirm)
            PACMAN_NOCONFIRM=1
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            shift
            break
            ;;
    esac
done


package-replaces() {
        local packages
        packages="$($PACMAN -Qq python-xdg garuda-dr460nized garuda-xfce-kwin-settings garuda-lxqt-kwin-settings gar
uda-wayfire-settings sweet-kde-git sweet-cursor-theme-git pipewire-media-session pipewire-support qemu-base virt-man
ager-meta libretro-meta libretro-mame-git jack2 pipewire-jack libpipewire-0.3.so=0-64 jre-openjdk-headless jre-openj
dk jdk-openjdk pinta dotnet-runtime-7.0 2>/dev/null | xargs || true)"
        # We replace python-xdg with python-pyxdg from extra
        # This is not done automatically for some reason
        if [[ "$packages" =~ (^| )python-xdg($| ) ]]; then
                echo python-pyxdg
        fi
        if [[ "$packages" =~ (^| )(garuda-dr460nized|garuda-xfce-kwin-settings|garuda-lxqt-kwin-settings|garuda-wayf
ire-settings)($| ) ]] && [[ "$packages" =~ (^| )(sweet-cursor-theme-git|sweet-kde-git)($| ) ]]; then
                echo --ignore
                echo sweet-kde-git,sweet-cursor-theme-git,kvantum-theme-sweet-git,sweet-gtk-theme-dark,plasma5-theme
-sweet-git
        fi
        if [[ "$packages" =~ (^| )pipewire-media-session($| ) ]] && [[ "$packages" =~ (^| )pipewire-support($| ) ]];
 then
                echo --ignore
                echo pipewire-media-session
        fi
        if [[ "$packages" =~ (^| )libretro-meta($| ) ]] && [[ "$packages" =~ (^| )libretro-mame-git($| ) ]]; then
                echo --ignore
                echo libretro-mame-git
        fi
        if [[ "$packages" =~ (^| )jack2($| ) ]] && [[ "$packages" =~ (^| )pipewire-jack($| ) ]]; then
                echo --ignore
                echo jack2,lib32-jack2,jack2-dbus
        fi
        if [[ "$packages" =~ (^| )pipewire($| ) ]]; then
                echo --ignore
                echo pipewire-common-git
        fi
        if [[ "$packages" =~ (^| )jdk-openjdk($| ) ]] && [[ "$packages" =~ (^| )jre-openjdk(-headless)?($| ) ]]; the
n
                echo --ignore
                echo jre-openjdk,jre-openjdk-headless
        elif [[ "$packages" =~ (^| )jre-openjdk($| ) ]] && [[ "$packages" =~ (^| )jre-openjdk-headless($| ) ]]; then
                echo --ignore
                echo jre-openjdk-headless
        fi
        # TODO: Remove this when pinta is updated to .NET 8 or pacman's dependency resolver is fixed lmao
        if [[ "$packages" =~ (^| )pinta($| ) ]] && ! [[ "$packages" =~ (^| )dotnet-runtime-7.0($| ) ]]; then
                echo dotnet-runtime-7.0
        fi
}


#!/usr/bin/expect -f

if {![exp_debug]} {trap {exit 1} {SIGINT SIGTERM}}

variable noconfirm [string equal $::env(AUTOPACMAN_PACMAN_NOCONFIRM) "1"]
variable noconfirm_downloading false
variable conflictsfile_set [expr [info exist ::env(AUTOPACMAN_CONFLICTSFILE)] && [file exist $::env(AUTOPACMAN_CONFLICTSFILE)] ? true : false]

# [package to be replaced]: [package to be replaced with]
array set auto_replace_conflicts {
    python-xdg python-pyxdg
    sweet-kde-git sweet-theme-full-git
    sweet-cursor-theme-git sweet-theme-full-git
    kvantum-theme-sweet-git sweet-theme-full-git
    sweet-gtk-theme-dark sweet-theme-full-git
    plasma5-theme-sweet-git sweet-theme-full-git
    xcursor-sweet sweet-theme-full-git
    exe-thumbnailer icoextract
    pipewire-media-session wireplumber
    ipw2100-fw garuda-common-settings
    ipw2200-fw garuda-common-settings
    firedragon-extension-xdm-browser-monitor garuda-common-settings
    qemu-base qemu-desktop
    libretro-mame-git libretro-meta
    jack2 pipewire-jack
    networkmanager-fortisslvpn networkmanager-support
    ananicy-rules cachyos-ananicy-rules-git
    sweet-theme-full-git plasma5-themes-sweet-full-git
    sweet-kde-theme-git plasma5-themes-sweet-kde-git
    jre-openjdk jdk-openjdk
    jre-openjdk-headless {jdk-openjdk jre-openjdk}
    plasma5-applets-window-appmenu garuda-dr460nized
    plasma5-applets-window-title garuda-dr460nized
    plasma5-applets-window-buttons garuda-dr460nized
    plasma5-applets-betterinlineclock-git garuda-dr460nized
    plasma5-wallpapers-blurredwallpaper garuda-dr460nized
    plasma-applet-window-buttons garuda-dr460nized
}

if { $::conflictsfile_set } {
    set conflictsfile [open $::env(AUTOPACMAN_CONFLICTSFILE) r]
    array set auto_replace_conflicts [gets $conflictsfile]
    close $conflictsfile
}

proc parseConflicts {first second} {
    foreach {key value} [array get ::auto_replace_conflicts] {
        if { [string equal $second $key] && [lsearch -exact $value $first] != -1 } {
            send "y\r"
            return
        }
    }
    if { $::noconfirm } {
        return
    } elseif { $::conflictsfile_set } {
        send "n\r"
    } else {
        expect_user -timeout -1 -re "(.*)\n"
        if {[regexp {^[Yy]$} $expect_out(1,string)]} {
            set ::auto_replace_conflicts($second) $first
            send "y\r"
        } else {
            send "n\r"
        }
    }
}

proc doExit {} {
    catch wait result
    if {[info exist ::env(AUTOPACMAN_CONFLICTSFILE)] && ![file exist $::env(AUTOPACMAN_CONFLICTSFILE)] } {
        set conflictsfile [open $::env(AUTOPACMAN_CONFLICTSFILE) [list WRONLY CREAT EXCL] 0600]
        puts $conflictsfile [array get ::auto_replace_conflicts]
        close $conflictsfile
    }
    exit [lindex $result 3]
}

spawn {*}$argv

log_user 1

set timeout -1

expect {
    "Starting full system upgrade..." { }
    eof doExit
}

set timeout 15

expect {
    -re {Replace \S+ with \S+ \[Y\/n\]} { send "y\r"; exp_continue }
    "resolving dependencies..." { }
    timeout { }
    eof doExit
}

expect {
    "looking for conflicting packages" { exp_continue }
    "Enter a number (default=1):" { if { $noconfirm } { send "1\r"; exp_continue; } { interact -o "\r" exp_continue; } }
    -re {(\S+) and (\S+) are in conflict( \(\S+\))?\.} { parseConflicts $expect_out(1,string) $expect_out(2,string); exp_continue }
    -re {Proceed with installation.*} { if { [info exist ::env(AUTOPACMAN_LOG)] } { log_file $::env(AUTOPACMAN_LOG) }; if { $::noconfirm || $::conflictsfile_set } { send "y\r"; set noconfirm_downloading true } }
    timeout { }
    eof doExit
}

if { $noconfirm } {
    if { $noconfirm_downloading } {
        set timeout -1
        expect {
            -re {Do you want to delete it.*} { send "y\r"; exp_continue }
            -re {.*\[Y/n\]} { }
            eof doExit
        }
    }
    exp_send_error "\nUnexpected user input required. Try again without --noconfirm"
    close
} else {
    expect_background {
        -re {Do you want to delete it.*} { send "y\r"; exp_continue }
    }
    catch interact
}
doExit
