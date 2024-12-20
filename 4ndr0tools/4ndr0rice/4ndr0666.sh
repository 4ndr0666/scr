#!/bin/sh
# File: 4ndr0666.sh
# Author: 4ndr0666
# Edited: 4-23-24
#
# --- // 4ndr0666.sh <4ndr0666@github.com> // ========

# --- // CONSTANTS:
dotfilesrepo="https://github.com/4ndr0666/dotfiles.git"
progsfile="https://raw.githubusercontent.com/4ndr0666/scr/main/static/progs.csv"
aurhelper="yay"
repobranch="master"
export TERM=ansi

rssurls="https://lukesmith.xyz/rss.xml
https://videos.lukesmith.xyz/feeds/videos.xml?videoChannelId=2 \"~Luke Smith (Videos)\"
https://www.youtube.com/feeds/videos.xml?channel_id=UC2eYFnH61tmytImy1mTYvhA \"~Luke Smith (YouTube)\"
https://lindypress.net/rss
https://notrelated.xyz/rss
https://landchad.net/rss.xml
https://based.cooking/index.xml
https://artixlinux.org/feed.php \"tech\"
https://www.archlinux.org/feeds/news/ \"tech\"
https://github.com/LukeSmithxyz/voidrice/commits/master.atom \"~LARBS dotfiles\""

# --- // UTILITY_FUNCTIONS:

installpkg() {
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

welcomemsg() {
    whiptail --title "4ndr0666.sh" \
        --msgbox "This will rice your machine to the 4ndr0666.sh specs.\\n\\n-4ndr0666" 10 60

    whiptail --title "!WARNING!" --yes-button "Continue" \
		--no-button "Return..." \
        --yesno "Ensure latest updates and refreshed Arch keyrings.\\n\\n" 8 70
}

getuserandpass() {
    # Prompts user for new username and password.
    name=$(whiptail --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
    while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
        name=$(whiptail --nocancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
    pass1=$(whiptail --nocancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
    pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    while ! [ "$pass1" = "$pass2" ]; do
        unset pass2
        pass1=$(whiptail --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
        pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
}

usercheck() {
    ! { id -u "$name" >/dev/null 2>&1; } ||
        whiptail --title "WARNING" --yes-button "CONTINUE" \
            --no-button "Abort" \
            --yesno "The user \`$name\` already exists on this system. The script can install for a user already existing, but it will OVERWRITE any conflicting settings/dotfiles on the user account.\\n\\nRicer will NOT overwrite your user files, documents, videos, etc., but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that the script will change $name's password to the one you just gave." 14 70
}

preinstallmsg() {
    whiptail --title "Environment is Ready" --yes-button "RICE" \
        --no-button "Abort" \
        --yesno "System now primed for automated installation\\n\\nClick RICE to intiate!" 13 60 || {
        clear
        exit 1
    }
}

adduserandpass() {
    # Adds user `$name` with password $pass1.
    whiptail --infobox "Adding user \"$name\"..." 7 50
    useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
        usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
    export repodir="/home/$name/.local/src"
    mkdir -p "$repodir"
    chown -R "$name":wheel "$(dirname "$repodir")"
    echo "$name:$pass1" | chpasswd
    unset pass1 pass2
}

refreshkeys() {
    case "$(readlink -f /sbin/init)" in
    *systemd*)
        whiptail --infobox "Refreshing Arch Keyring..." 7 40
        pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
        ;;
    *)
        whiptail --infobox "Enabling Chaotic AUR" 7 40
        pacman --noconfirm --needed -S \
        sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com >/dev/null 2>&1
        sudo pacman-key --lsign-key 3056513887B78AEB >/dev/null 2>&1
        whiptail --infobox "Installing Chaotic AUR Keyring and Mirrorlist..." 7 40
        sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' >/dev/null 2>&1

        grep -q "^\[chaotic-aur\]" /etc/pacman.conf ||
            echo "[chaotic-aur]
Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf
        pacman -Sy --noconfirm >/dev/null 2>&1
        pacman-key --populate archlinux >/dev/null 2>&1
        ;;
    esac
}

manualinstall() {
    # Installs $1 manually. Used only for AUR helper here.
    # Should be run after repodir is created and var is set.
    pacman -Qq "$1" && return 0
    whiptail --infobox "Installing \"$1\" manually." 7 50
    sudo -u "$name" mkdir -p "$repodir/$1"
    sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
        --no-tags -q "https://aur.archlinux.org/$1.git" "$repodir/$1" ||
        {
            cd "$repodir/$1" || return 1
            sudo -u "$name" git pull --force origin master
        }
    cd "$repodir/$1" || exit 1
    sudo -u "$name" \
        makepkg --noconfirm -si >/dev/null 2>&1 || return 1
}

maininstall() {
    # Installs all needed programs from main repo.
    whiptail --title "4ndr0666.sh Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
    installpkg "$1"
}

gitmakeinstall() {
    progname="${1##*/}"
    progname="${progname%.git}"
    dir="$repodir/$progname"
    whiptail --title "4ndr0666 Installation" \
        --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 8 70
    sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
        --no-tags -q "$1" "$dir" ||
        {
            cd "$dir" || return 1
            sudo -u "$name" git pull --force origin master
        }
    cd "$dir" || exit 1
    make >/dev/null 2>&1
    make install >/dev/null 2>&1
    cd /tmp || return 1
}

aurinstall() {
    whiptail --title "4ndr0666 Installation" \
        --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 9 70
    echo "$aurinstalled" | grep -q "^$1$" && return 1
    sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
}

pipinstall() {
    whiptail --title "4ndr0666 Installation" \
        --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 9 70
    [ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1
    yes | pip install "$1"
}

installationloop() {
    ([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) ||
        curl -Ls "$progsfile" | sed '/^#/d' >/tmp/progs.csv
    total=$(wc -l </tmp/progs.csv)
    aurinstalled=$(pacman -Qqm)
    while IFS=, read -r tag program comment; do
        n=$((n + 1))
        echo "$comment" | grep -q "^\".*\"$" &&
            comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"
        case "$tag" in
        "A") aurinstall "$program" "$comment" ;;
        "G") gitmakeinstall "$program" "$comment" ;;
        "P") pipinstall "$program" "$comment" ;;
        *) maininstall "$program" "$comment" ;;
        esac
    done </tmp/progs.csv
}

putgitrepo() {
    # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
    whiptail --infobox "Downloading and installing config files..." 7 60
    [ -z "$3" ] && branch="master" || branch="$repobranch"
    dir=$(mktemp -d)
    [ ! -d "$2" ] && mkdir -p "$2"
    chown "$name":wheel "$dir" "$2"
    sudo -u "$name" git -C "$repodir" clone --depth 1 \
        --single-branch --no-tags -q --recursive -b "$branch" \
        --recurse-submodules "$1" "$dir"
    sudo -u "$name" cp -rfT "$dir" "$2"
}

vimplugininstall() {
    # Installs vim plugins.
    whiptail --infobox "Installing neovim plugins..." 7 60
    mkdir -p "/home/$name/.config/nvim/autoload"
    curl -Ls "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" >  "/home/$name/.config/nvim/autoload/plug.vim"
    chown -R "$name:wheel" "/home/$name/.config/nvim"
    sudo -u "$name" nvim -c "PlugInstall|q|q"
}

makeuserjs() {
    # Get the Arkenfox user.js and prepare it.
    arkenfox="$pdir/arkenfox.js"
    overrides="$pdir/user-overrides.js"
    userjs="$pdir/user.js"
    ln -fs "/home/$name/.config/firefox/larbs.js" "$overrides"
    [ ! -f "$arkenfox" ] && curl -sL "https://raw.githubusercontent.com/arkenfox/user.js/master/user.js" > "$arkenfox"
    cat "$arkenfox" "$overrides" > "$userjs"
    chown "$name:wheel" "$arkenfox" "$userjs"
    # Install the updating script.
    mkdir -p /usr/local/lib /etc/pacman.d/hooks
    cp "/home/$name/.local/bin/arkenfox-auto-update" /usr/local/lib/
    chown root:root /usr/local/lib/arkenfox-auto-update
    chmod 755 /usr/local/lib/arkenfox-auto-update
    # Trigger the update when needed via a pacman hook.
    echo "[Trigger]
Operation = Upgrade
Type = Package
Target = firefox
Target = librewolf
Target = librewolf-bin
[Action]
Description=Update Arkenfox user.js
When=PostTransaction
Depends=arkenfox-user.js
Exec=/usr/local/lib/arkenfox-auto-update" > /etc/pacman.d/hooks/arkenfox.hook
}

installffaddons(){
    addonlist="ublock-origin decentraleyes istilldontcareaboutcookies vim-vixen"
    addontmp="$(mktemp -d)"
    trap "rm -fr $addontmp" HUP INT QUIT TERM PWR EXIT
    IFS=' '
    sudo -u "$name" mkdir -p "$pdir/extensions/"
    for addon in $addonlist; do
        if [ "$addon" = "ublock-origin" ]; then
            addonurl="$(curl -sL https://api.github.com/repos/gorhill/uBlock/releases/latest | grep -E 'browser_download_url.*\.firefox\.xpi' | cut -d '"' -f 4)"
        else
            addonurl="$(curl --silent "https://addons.mozilla.org/en-US/firefox/addon/${addon}/" | grep -o 'https://addons.mozilla.org/firefox/downloads/file/[^"]*')"
        fi
        file="${addonurl##*/}"
        sudo -u "$name" curl -LOs "$addonurl" > "$addontmp/$file"
        id="$(unzip -p "$file" manifest.json | grep "\"id\"")"
        id="${id%\"*}"
        id="${id##*\"}"
        mv "$file" "$pdir/extensions/$id.xpi"
    done
    chown -R "$name:$name" "$pdir/extensions"
    # Fix a Vim Vixen bug with dark mode not fixed on upstream:
    sudo -u "$name" mkdir -p "$pdir/chrome"
    [ ! -f  "$pdir/chrome/userContent.css" ] && sudo -u "$name" echo ".vimvixen-console-frame { color-scheme: light !important; }
#category-more-from-mozilla { display: none !important }" > "$pdir/chrome/userContent.css"
}

finalize() {
    whiptail --title "Ricing Complete!" \
      
        --msgbox "Graphical environment is ready launch at tty1, log out and log back in as your new user, then type \"startx\"\\n\\n.t 4ndr0666" 13 80 
}

# --------------------------------------------------------- // SCRIPT_STARTS_HERE //
pacman --noconfirm --needed -Sy libnewt ||
    error "Are you sure you're running this as the root user, are on an Arch-based distribution and have an internet connection?"

# --- // WELCOME_MESSAGE:
welcomemsg || error "User exited."

# --- // SET_USERNAME_AND_PASSWORD:
getuserandpass || error "User exited."

# --- // USER_VALIDATION:
usercheck || error "User exited."

# --- // PREINSTALL:
preinstallmsg || error "User exited."

# --- // REPO_KEYS:
refreshkeys ||
    error "Error automatically refreshing Arch keyring. Consider doing so manually."

for x in curl ca-certificates base-devel git ntp zsh dash; do
    whiptail --title "4ndr0666 Installation" \
        --infobox "Installing \`$x\` which is required to install and configure other programs." 8 70
    installpkg "$x"
done

whiptail --title "4ndr0666 Installation" \
    --infobox "Synchronizing system time..." 8 70
ntpd -q -g >/dev/null 2>&1

adduserandpass || error "Error adding username and/or password."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
trap 'rm -f /etc/sudoers.d/andro-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL
Defaults:%wheel,root runcwd=*" >/etc/sudoers.d/andro-temp

# --- // PACMAN.CONF:
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

# --- // MAKEPKG.CONF:
sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

# --- // INSTALL_YAY_OR_FALLBACK:
manualinstall $aurhelper || echo "AUR helper installation failed executing fallback."

if ! command -v yay &> /dev/null; then
    installpkg git >/dev/null 2>&1
    installpkg base-devel >/dev/null 2>&1
    git clone https://aur.archlinux.org/yay.git /tmp/yay >/dev/null 2>&1
    pushd /tmp/yay >/dev/null 2>&1
    makepkg -si || error "Failed to make package."
    popd >/dev/null 2>&1
else
    echo "Yay seems to be installed after all..."
fi

if ! yay -Syu --noconfirm; then
    error "Fallback mechanism failed. Aborting..."
fi

# --- // AUTOUPDATE_.*-git_AUR_PKGS:
$aurhelper -Y --save --devel

# --- // INSTALL_LOGIC_LOOP:
installationloop

# --- // FETCH_DOTFILES_AND_CLEANUP:
putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
rm -rf "/home/$name/.git/" "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml"

# Write urls for newsboat if it doesn't already exist
[ -s "/home/$name/.config/newsboat/urls" ] ||
	sudo -u "$name" echo "$rssurls" > "/home/$name/.config/newsboat/urls"

# --- // NVIM_PLUG_INSTALLATION:
[ ! -f "/home/$name/.config/nvim/autoload/plug.vim" ] && vimplugininstall

# --- // ZSH:
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
sudo -u "$name" mkdir -p "/home/$name/.config/abook/"
sudo -u "$name" mkdir -p "/home/$name/.config/mpd/playlists/"

# Make dash the default #!/bin/sh symlink.
ln -sfT /bin/dash /bin/sh >/dev/null 2>&1
# --- // DBUS_UUID_FOR_RUNIT_INIT_SYSTEMS:
dbus-uuidgen >/var/lib/dbus/machine-id

# --- // PUSH_BROWSER_NOTIFICATIONS_TO_DBUS:
echo "export \$(dbus-launch)" >/etc/profile.d/dbus.sh

# --- // TAP_TO_CLICK:
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	# Enable left mouse button by tapping
	Option "Tapping" "on"
EndSection' >/etc/X11/xorg.conf.d/40-libinput.conf

# --- // BROWSER:
whiptail --infobox "Setting browser privacy settings and add-ons..." 7 60

browserdir="/home/$name/.librewolf"
profilesini="$browserdir/profiles.ini"

# Start librewolf headless so it generates a profile. Then get that profile in a variable.
sudo -u "$name" librewolf --headless >/dev/null 2>&1 &
sleep 1
profile="$(sed -n "/Default=.*.default-default/ s/.*=//p" "$profilesini")"
pdir="$browserdir/$profile"

[ -d "$pdir" ] && makeuserjs

[ -d "$pdir" ] && installffaddons

# Kill the now unnecessary librewolf instance.
pkill -u "$name" librewolf

# --- // AUTO_ESCALATE:
# (like `shutdown` to run without password).
echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-andro-wheel-can-sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/pacman -S -y --config /etc/pacman.conf --,/usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/etc/sudoers.d/01-andro-cmds-without-password
echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-andro-visudo-editor
mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf

# Cleanup
rm -f /etc/sudoers.d/larbs-temp

# Last message! Install complete!
finalize
