# Package Management Functions

# Mirrors Management
mirrors() {
    sudo reflector --latest 10 --age 2 --fastest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
}

# Fix Pacman Lock
fixpacman() {
    sudo unlink /var/lib/pacman/db.lck
}

fixpacman2() {
    sudo unlink /var/cache/pacman/pkg/cache.lck
}

# Clean Pacman Cache
cleanpacman() {
    sudo find /var/cache/pacman/pkg/ -iname '*.part' -delete
}

# Check Pacman Database
checkdb() {
    sudo pacman -Dk
}

# Find Package
findpkg() {
    sudo pacman -Fyx
}

# End of Life Packages
eol() {
    comm -23 <(pacman -Qqm | sort) <(curl https://aur.archlinux.org/packages.gz | gzip -cd | sort)
}

# Package Lists
bigpkg() {
    expac -H M '%m\t%n' | sort -h | nl
}

rip() {
    expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl
}

riplong() {
    expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -3000 | nl
}

gitpkg() {
    pacman -Q | grep -i '\-git' | wc -l
}

pkgbysize() {
    expac -Q '%m - %n %v' | sort -n -r
}

mkpkglist() {
    bat /tmp/pacui-ls
}

# Yay Search with Parameters
yaysearch() {
    read -p "Choose a search parameter (1-5): " search_param
    case $search_param in
        1) yay --singlelineresults --groups --provides --searchby name ;;
        2) yay --singlelineresults --groups --provides --searchby desc ;;
        3) yay --singlelineresults --groups --provides --searchby maintainer ;;
        4) yay --singlelineresults --groups --provides --searchby packager ;;
        5) yay --singlelineresults --groups --provides --searchby depends ;;
        *) echo "Invalid choice. Please choose a number between 1 and 5." ;;
    esac
}

# Yay Dependencies
yaydeps() {
    yay --sudoloop --refresh --singlelineresults --sysupgrade --timeupdate --verbose
}

# Yay Skip Integrity
yayskip() {
    yay -S --mflags --skipinteg
}

# Yay Overwrite
yayow() {
    yay -S --overwrite="*" --noconfirm
}

# Trizen Skip Integrity
trizenskip() {
    trizen -S --skipinteg
}

# Update All Packages
update() {
    sudo pacman -Sy && sudo powerpill -Su && paru -Su
}

# Unsafe Install (Security Bypass)
fninstall() {
    yay -S --needed --cleanafter --cleanmenu --devel --noconfirm --rebuild --refresh --sudoloop --sysupgrade --overwrite='*' --disable-download-timeout --pgpfetch=false --removemake --redownload --batchinstall=false --answerclean=yes --answerdiff=no --answeredit=no
}

# Unsafe Update (Security Bypass)
fnupdate() {
    yay -Syyu --noconfirm --disable-download-timeout --removemake --rebuild --pgpfetch=false --bottomup --overwrite="*"
}

# Unsafe Removal (Dependency Bypass)
fnremove() {
    yay -Rddn --noconfirm
}

# Disable PGP Signature Verification
pacmansigoff() {
    read -p 'Are you sure you want to disable PGP signature verification? (yes/no): ' answer
    if [[ $answer == 'yes' ]]; then
        if sudo cp --preserve=all -f /etc/pacman.conf /etc/pacman.conf.backup; then
            sudo sed -i '/^SigLevel/ s/Required/Never/' /etc/pacman.conf
            echo 'PGP signature verification bypassed.'
        else
            echo 'Failed to create backup. Aborting.'
        fi
    else
        echo 'Operation canceled.'
    fi
}

# Enable PGP Signature Verification
pacmansigon() {
    if [[ -f /etc/pacman.conf.backup ]]; then
        if sudo cp --preserve=all -f /etc/pacman.conf.backup /etc/pacman.conf; then
            sudo rm /etc/pacman.conf.backup
            echo 'PGP signature verification restored.'
        else
            echo 'Failed to restore the original pacman.conf. Aborting.'
        fi
    else
        echo 'Backup file not found. Cannot restore.'
    fi
}
