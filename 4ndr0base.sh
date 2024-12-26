#!/bin/sh -e
# File: 4ndr0base.sh
# Author: 4ndr0666
## Description: Quick setup script for basic requirements on a new machine.

# ============================== // 4NDR0BASEINSTALL.SH //
RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
GREEN='\033[32m'

# --- // Base Pkgs:
setup_base() {
	sudo pacman -Sy --noconfirm --needed base-devel unzip archlinux-keyring github-cli git-delta lsd eza fd micro expac \
	bat bash-completion pacdiff xorg-xhost xclip ripgrep diffuse neovim
	yay -Sy --noconfirm zsh-syntax-highlighting zsh-autosuggestions bashmount-git debugedit lf-git
}

# --- // Nerd Font:
setup_font() {
    FONT_DIR="$HOME/.local/share/fonts"
    FONT_ZIP="$FONT_DIR/Meslo.zip"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    FONT_INSTALLED=$(fc-list | grep -i "Meslo")
    if [ -n "$FONT_INSTALLED" ]; then
        printf "%b\n" "${GREEN}Meslo Nerd-fonts are already installed.${RC}"
        return 0
    fi
    if [ ! -d "$FONT_DIR" ]; then
        mkdir -p "$FONT_DIR" || {
            printf "%b\n" "${RED}Failed to create directory: $FONT_DIR${RC}"
            return 1
        }
    else
        printf "%b\n" "${GREEN}$FONT_DIR exists, skipping creation.${RC}"
    fi
    if [ ! -f "$FONT_ZIP" ]; then
        # Download the font zip file
        curl -sSLo "$FONT_ZIP" "$FONT_URL" || {
            printf "%b\n" "${RED}Failed to download Meslo Nerd-fonts from $FONT_URL${RC}"
            return 1
        }
    else
        printf "%b\n" "${GREEN}Meslo.zip already exists in $FONT_DIR, skipping download.${RC}"
    fi
    if [ ! -d "$FONT_DIR/Meslo" ]; then
        mkdir -p "$FONT_DIR/Meslo" || {
            printf "%b\n" "${RED}Failed to create directory: $FONT_DIR/Meslo${RC}"
            return 1
        }
        unzip "$FONT_ZIP" -d "$FONT_DIR" || {
            printf "%b\n" "${RED}Failed to unzip $FONT_ZIP${RC}"
            return 1
        }
    else
        printf "%b\n" "${GREEN}Meslo font files already unzipped in $FONT_DIR, skipping unzip.${RC}"
    fi
    rm "$FONT_ZIP" || {
        printf "%b\n" "${RED}Failed to remove $FONT_ZIP${RC}"
        return 1
    }
    fc-cache -fv || {
        printf "%b\n" "${RED}Failed to rebuild font cache${RC}"
        return 1
    }

    printf "%b\n" "${GREEN}Meslo Nerd-fonts installed successfully${RC}"
}

# --- // Zsh:
setup_zsh() {
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
    ZSHRC_FILE="$CONFIG_DIR/.zshrc"

    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
    fi

    cat <<EOL >"$ZSHRC_FILE"
# =========================================== // 4NDR0666_ZSHRC //
# --- // History:
HISTFILE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/history"
HISTSIZE=10000000
SAVEHIST=10000000
setopt extended_glob
setopt autocd
setopt interactive_comments

# --- // Soloarized prompt:
PROMPT='%F{32}%n%f%F{166}@%f%F{64}%m:%F{166}%~%f%F{15}$%f '
RPROMPT='%F{15}(%F{166}%D{%H:%M}%F{15})%f'

# --- // Aliased 'h' for cmd history:
h() { if [ -z "$*" ]; then history 1; else history 1 | egrep "$@"; fi; }

# --- // Source the files:
[ -f "$HOME/.config/zsh/aliasrc" ] && source "$HOME/.config/zsh/aliasrc"
[ -f "$HOME/.config/zsh/functions.zsh" ] && source "$HOME/.config/zsh/functions.zsh"
[ -f "$HOME/.config/zsh/.zprofile" ] && source "$HOME/.config/zsh/.zprofile"
[ -d "/usr/share/zsh/plugins/zsh-autosuggestions" ] && source "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" 2>/dev/null
[ -d "/usr/share/zsh/plugins/zsh-syntax-highlighting" ] && source "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" 2>/dev/null

EOL

    # --- // Create the symlink:
    ln -svf "$ZSHRC_FILE" "$HOME/.zshrc" || {
        printf "%b\n" "${RED}Failed to create symlink for .zshrc${RC}"
        exit 1
    }
}


# ==================== // ToDo //
### File creation from DL:
#populate_configs() {
#    printf "%b\n" "${YELLOW}Copying configuration files...${RC}"
#    if [ -d "${HOME}/.config/EXAMPLE" ] && [ ! -d "${HOME}/.config/EXAMPLE-bak" ]; then
#        cp -r "${HOME}/.config/EXAMPLE" "${HOME}/.config/EXAMPLE-bak"
#    fi
#    mkdir -p "${HOME}/.config/EXAMPLE/"
#    curl -sSLo "${HOME}/.config/EXAMPLE/EXAMPLE.conf" https://github.com/4ndr0666/dotfiles/raw/main/config/EXAMPLE/EXAMPLE.conf
#    curl -sSLo "${HOME}/.config/EXAMPLE/EXAMPLE.conf" https://github.com/4ndr0666/dotfiles/raw/main/config/EXAMPLE/EXAMPLE.conf
#}
### Check, make and append to file:
#[ ! -f /etc/zsh/zshenv ] && "$ESCALATION_TOOL" mkdir -p /etc/zsh && "$ESCALATION_TOOL" touch /etc/zsh/zshenv
#echo "export ZDOTDIR=\"$HOME/.config/zsh\"" | "$ESCALATION_TOOL" tee -a /etc/zsh/zshenv
