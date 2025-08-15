#!/bin/bash
set -e

task=${1:-'fix'}

keyring=false
reset_pacman=false
internal_update=0
if [ "$task" == "setup" ]; then
    update
    exit 0
elif [ "$task" == "keyring" ]; then
    keyring=true
elif [ "$task" == "fix" ]; then
    if [ "$VERSION" != 1 ]; then
        echo "This will reset a few configuration files like pacman.conf 🛑"
        echo "Are you sure? (y/n)"
        read yusure
        [ $yusure != "y" ] && exit 1
    fi
    keyring=true
    reset_pacman=true
elif [ "$task" == "fullfix" ]; then
    if [ "$VERSION" != 1 ]; then
        echo "This will reset a few configuration files like pacman.conf 🛑"
        echo -e "\033[1;33mWarning: Fullfix mode! This will reinstall all packages!\033[0m"
        echo "Are you sure? (y/n)"
        read yusure
        [ $yusure != "y" ] && exit 1
    fi
    keyring=true
    reset_pacman=true
    internal_update=2
elif [ "$task" == "reinstall" ]; then
    echo -e "\033[1;33mWarning: This will reinstall all packages!\033[0m"
    echo "Are you sure? (y/n)"
    read yusure
    [ $yusure != "y" ] && exit 1
    internal_update=2
elif [ "$task" == "reset-snapper" ]; then
    exec bash -c ". <(wget -qO- https://gitlab.com/garuda-linux/themes-and-settings/settings/garuda-common-settings/-/snippets/2147440/raw/main/reset-snapper)"
elif [ "$task" == "reset-audio" ]; then
    internal_update=0
else
    echo -e "\033[1;31m\nUnknown subcommand!\n\033[0m";
    exit 1
fi

blackarch=false
if [ "$keyring" = true ] || [ "$reset_pacman" = true ]; then
    grep -Fxq "[blackarch]" /etc/pacman.conf && blackarch=true
fi

# Get a usable pacman version if possible
pacman=pacman

if [ "$reset_pacman" = true ]; then
    temp_file=$(mktemp)
    wget https://pkgbuild.com/~morganamilo/pacman-static/x86_64/bin/pacman-static -O $temp_file && chmod +x $temp_file && pacman="$temp_file" || { echo -e "\033[1;31m\nFailed to download pacman-static\n\033[0m"; }
    $pacman --version

    wget https://gitlab.com/garuda-linux/tools/garuda-tools/-/raw/master/data/pacman-default.conf -O /etc/pacman.conf || { echo -e "\033[1;31m\nFailed to restore pacman.conf\n\033[0m"; }

    # Set global CDN mirrors
    wget https://archlinux.org/mirrorlist/all/ -O /etc/pacman.d/mirrorlist || true
    cat <<-"EOF" >> /etc/pacman.d/mirrorlist
Server = http://mirrors.kernel.org/archlinux/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = http://mirror.rackspace.com/archlinux/$repo/os/$arch
EOF

    # Set chaotic mirrors
    wget https://aur.chaotic.cx/mirrorlist.txt -O /etc/pacman.d/chaotic-mirrorlist || cat <<-"EOF" > /etc/pacman.d/chaotic-mirrorlist
Server = https://random-mirror.chaotic.cx/$repo/$arch
Server = https://cdn-mirror.chaotic.cx/$repo/$arch
Server = https://geo-mirror.chaotic.cx/$repo/$arch
EOF
fi

if [ "$keyring" = true ]; then
    rm -rf /etc/pacman.d/gnupg
    rm -rf /var/lib/pacman/sync
    pacman-key --init
    pacman-key --populate archlinux chaotic || { echo -e "\033[1;31m\nFailed to populate keyrings\n\033[0m"; }
    pacman-key --recv-key FBA220DFC880C036 6D42BDD116E0068F --keyserver keyserver.ubuntu.com && pacman-key --lsign-key FBA220DFC880C036 6D42BDD116E0068F || { echo -e "\033[1;31m\nFailed to install some keys\n\033[0m"; }
    rm /var/cache/pacman/pkg/* || true
fi
# Re-set-up blackarch
if [ "$blackarch" == "true" ]; then
    bash <(wget -qO- https://blackarch.org/strap.sh) && SKIP_AUTOSNAP=1 SNAP_PAC_SKIP=y $pacman -S blackarch-keyring --noconfirm --needed || { echo -e "\033[1;31m\nFailed to fix blackarch\n\033[0m"; } # Too bad
fi
if [ "$keyring" = true ]; then
    SKIP_AUTOSNAP=1 SNAP_PAC_SKIP=y $pacman -Sy archlinux-keyring chaotic-keyring --noconfirm
fi

if [ "$internal_update" = "1" ]; then
    $pacman -Syu
elif [ "$internal_update" = "2" ]; then
    $pacman -Qqn | $pacman -Sy -
else
    SKIP_AUTOSNAP=1 SNAP_PAC_SKIP=y $pacman -Sy --noconfirm --overwrite='*' garuda-update
    PACMAN_EXE="$pacman" update
fi

if [ "$task" == "reset-audio" ]; then
    if [ ! -z "$SUDO_USER" ]; then
        pacman -Qq pipewire pipewire-pulse pipewire-media-session jamesdsp wireplumber pluseaudio 2>/dev/null || true
        SKIP_AUTOSNAP=1 SNAP_PAC_SKIP=y pacman -S --needed wireplumber pipewire-support
        systemctl disable --now pulseaudio pulseaudio.socket pipewire-media-session.service jack --user --machine=$SUDO_USER@.host
        systemctl enable -f --now pipewire.socket pipewire-pulse.socket pipewire.service pipewire-pulse.service wireplumber.service --user --machine=$SUDO_USER@.host
    else
        echo -e "\033[1;31m\nCould not detect sudo user.\n\033[0m";
    fi
fi

if [ ! -z "$temp_file" ]; then
    rm -f $temp_file
fi
