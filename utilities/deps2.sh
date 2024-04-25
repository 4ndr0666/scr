#!/bin/bash

# Enhanced script for managing package installations and updates

# Colors and Symbols for visual feedback
BUILD_DIR="$HOME/build"
LOG_FILE="$HOME/dep_install.log"
declare -A colors=( ["green"]='\033[0;32m' ["cyan"]='\033[0;36m' ["bold"]='\033[1m' ["red"]='\033[0;31m' ["nc"]='\033[0m' )
declare -A symbols=( ["success"]="✔️" ["failure"]="❌" ["info"]="➡️" ["explosion"]="💥" )

# Utility functions
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"; }
display() { echo -e "${colors[$1]}$2${colors[nc]}"; }
confirm() { read -r -p "$1 [y/N] " response; [[ "$response" =~ ^[yY](es)?$ ]]; }
manage_cursor() { tput "$1"; }  # civis - hide, cnorm - show

# Ensure the log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Verify and update pkgfile database
ensure_pkgfile() {
    if ! command -v pkgfile &>/dev/null; then
        display info "pkgfile is required but not installed. Installing pkgfile..."
        sudo pacman -S pkgfile --noconfirm && sudo pkgfile --update
    else
        sudo pkgfile --update
    fi
}

# Spinner animation during operations
spinner() {
    local pid=$1 msg="${2:-Processing...}" spinstr='|/-\\'
    display info "$msg"
    manage_cursor civis
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\b\b\b\b\b\b"
    done
    printf "\r\e[K"
    manage_cursor cnorm
}

# Progress bar for visual feedback on processes
progress_bar() {
    local total=$1 current=$2
    local filled=$((current * 20 / total)) unfilled=$((20 - filled))
    printf "${colors[cyan]}|%*s%s%*s|${colors[nc]}\r" "$filled" '' '=>' "$unfilled" ''
}

# Check for missing shared libraries after installation
check_missing_libraries() {
    local binary_path=$1
    local missing_libs=$(ldd "$binary_path" 2>&1 | grep "not found" | awk '{print $1}')

    if [[ ! -z "$missing_libs" ]]; then
        echo "Missing libraries detected:"
        echo "$missing_libs"
        local lib
        for lib in $missing_libs; do
            resolve_missing_library "$lib"
        done
    else
        display green "${symbols[success]} All libraries are present for $binary_path."
    fi
}

# Ensure pkgfile database is updated
ensure_pkgfile() {
    sudo pkgfile --update
}

# Resolve and install packages providing missing libraries
resolve_missing_library() {
    local missing_lib=$1
    local provider=$(pkgfile "$missing_lib")

    if [[ -z "$provider" ]]; then
        display red "No package found providing $missing_lib."
    else
        display info "Missing library $missing_lib is provided by package(s): $provider"
        if confirm "Install package providing $missing_lib ($provider)?"; then
            sudo yay -S --noconfirm "$provider" & spinner $! "Installing $provider..."
            if [ $? -eq 0 ]; then
                display green "${symbols[success]} Package providing $missing_lib ($provider) installed successfully!"
            else
                display red "${symbols[failure]} Failed to install $provider. Check log for details."
            fi
        fi
    fi
}

# Enhanced installation function with post-install checks
install_package() {
    local package=$1
    if yay -Qi "$package" &>/dev/null; then
        log "$package is already installed."
        check_missing_libraries "/usr/bin/$package"
    elif confirm "Install $package?"; then
        echo -n "${symbols[explosion]} Installing $package... "
        (yay -S --noconfirm "$package" &>/dev/null & spinner $! "Installing $package...")
        if [ $? -eq 0 ]; then
            display green "${symbols[success]} Package $package installed successfully!"
            check_missing_libraries "/usr/bin/$package"
        else
            display red "${symbols[failure]} Failed to install $package. See $LOG_FILE for details."
        fi
    else
        log "Installation aborted by the user."
    fi
}


# Entry point of the script, handling the user interface and choice management
handle_user_choice() {
    echo -e "${colors[green]}Select an operation:${colors[nc]}"
    echo "1) Check and install dependencies for a specific package"
    echo "2) Check and install all missing dependencies system-wide"
    echo "3) Display usage information"
    echo "4) Exit"
    read -rp "Enter choice: " choice
    case "$choice" in
        1)
            read -rp "Enter package name: " pkg
            install_package "$pkg"
            ;;
        2)
            echo "System-wide dependency check initiated."
            # Example placeholder for system-wide checks
            ;;
        3)
            show_help
            ;;
        4)
            exit 0
            ;;
        *)
            display red "Invalid choice. Please try again."
            ;;
    esac
}

# Display the menu until a valid choice is made or exit is selected
while true; do
    handle_user_choice
done


