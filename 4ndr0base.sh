#!/bin/bash
# File: 4ndr0base.sh
# Author: 4ndr0666
# Quick setup script for basic requirements on a new machine.

# ============================== // 4NDR0BASEINSTALL.SH //
# --- // Colors:
RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
GREEN='\033[32m'

# --- // Base Pkgs:
setupbase() {
	sudo pacman -Sy --noconfirm --needed base-devel unzip archlinux-keyring github-cli git-delta exa fd micro expac bat bash-completion pacdiff xorg-xhost xclip ripgrep diffuse neovim
	yay -Sy --noconfirm --needed sysz brave-beta-bin zsh-syntax-highlighting zsh-autosuggestions bashmount-git debugedit lsd lf-git
}

# --- // Nerd Font:
setupfont() {
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
setupzsh() {
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
    ZSHRC_FILE="$CONFIG_DIR/.zshrc"

    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
    fi

    cat <<EOL >"$ZSHRC_FILE"
# ===================== // 4NDR0666_ZSHRC //
# --- // Soloarized prompt:
PROMPT='%F{32}%n%f%F{166}@%f%F{64}%m:%F{166}%~%f%F{15}$%f '
RPROMPT='%F{15}(%F{166}%D{%H:%M}%F{15})%f'

# --- // History:
HISTFILE="$HOME/.cache/zsh/history"
HISTSIZE=10000000
SAVEHIST=10000000

# --- // Setopt:
setopt extended_glob
setopt autocd
setopt interactive_comments
setopt inc_append_history

# --- // Aliases
## 'h' for cmd history:
h() { if [ -z "" ]; then history 1; else history 1 | egrep ""; fi; }

# --- // Autocomplete:
[ -f "$HOME/.cache/zsh/zcache" ] && touch "$HOME/.cache/zsh/zcache"
chmod ug+rw "$HOME/.cache/zsh/zcache"

autoload -U compinit
compinit -d $HOME/.cache/zsh/zcompdump-"$ZSH_VERSION"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle -d ':completion:*' format
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' completer _expand _complete _ignored _approximate
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
zstyle ':completion:*:descriptions' format '%U%F{cyan}%d%f%u'
bindkey '^ ' autosuggest-accept
## Speed-Up:
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path $HOME/.cache/zsh/zcache
zmodload zsh/complist
compinit
_comp_options+=(globdots)


# --- // Source the files:
[ -f "/home/andro/.config/zsh/aliasrc" ] && source "/home/andro/.config/zsh/aliasrc"
[ -f "/home/andro/.config/zsh/functions.zsh" ] && source "/home/andro/.config/zsh/functions.zsh"
[ -f "/home/andro/.config/zsh/.zprofile" ] && source "/home/andro/.config/zsh/.zprofile"
[ -d "/usr/share/zsh/plugins/zsh-autosuggestions" ] && source "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" 2>/dev/null
[ -d "/usr/share/zsh/plugins/zsh-syntax-highlighting" ] && source "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" 2>/dev/null

EOL

    # --- // Create the symlink:
    ln -svf "$ZSHRC_FILE" "$HOME/.zshrc" || {
        printf "%b\n" "${RED}Failed to create symlink for .zshrc${RC}"
        exit 1
    }
}

setupconfig() {
    printf "%b\n" "${YELLOW}Configurating...${RC}"
    if [ -d "${HOME}/.config/zsh/" ] && [ ! -d "${HOME}/.config/zsh-bak" ]; then
        cp -r "${HOME}/.config/zsh" "${HOME}/.config/zsh-bak"
    fi
    mkdir -p "${HOME}/.config/zsh/"

    if [ -d "${HOME}/.config/lf/" ] && [ ! -d "${HOME}/.config/lf-bak" ]; then
        cp -r "${HOME}/.config/lf" "${HOME}/.config/lf-bak"
    fi
    mkdir -p "${HOME}/.config/lf/"

    curl -sSLo "${HOME}/.config/zsh/aliasrc" https://github.com/4ndr0666/dotfiles/raw/main/config/shellz/aliasrc
    curl -sSLo "${HOME}/.config/zsh/functions.zsh" https://github.com/4ndr0666/dotfiles/raw/main/config/shellz/functions.zsh
    if [ -f "$HOME/.config/zsh/.zprofile" ] && [ ! -f "$HOME/.config/zsh/.zprofile" ]; then 
        curl -sSLo "${HOME}/.config/zsh/.zprofile" https://github.com/4ndr0666/dotfiles/raw/main/config/zsh/.zprofile
    fi
    curl -sSLo "${HOME}/.config/zsh/gpg_env" https://github.com/4ndr0666/dotfiles/raw/main/config/shellz/gpg_env        
    curl -sSLo "${HOME}/.config/user-dirs.dirs" https://github.com/4ndr0666/dotfiles/raw/main/config/user-dirs.dirs
    curl -sSLo "${HOME}/.config/user-dirs.locale" https://github.com/4ndr0666/dotfiles/raw/main/config/user-dirs.locale
    curl -sSLo "${HOME}/.config/lf/cleaner" https://github.com/4ndr0666/dotfiles/raw/main/config/lf/cleaner
    curl -sSLo "${HOME}/.config/lf/icons" https://github.com/4ndr0666/dotfiles/raw/main/config/lf/icons
    curl -sSLo "${HOME}/.config/lf/lfrc" https://github.com/4ndr0666/dotfiles/raw/main/config/lf/lfrc
    curl -sSLo "${HOME}/.config/lf/scope" https://github.com/4ndr0666/dotfiles/raw/main/config/lf/scope
#    curl -sSLo "${HOME}/.config/mimeapps.list" https://github.com/4ndr0666/dotfiles/raw/main/config/mimeapps.list        

}

setupdotfiles() {
    cd ~
    git clone https://github.com/4ndr0666/dotfiles
    cp -r ~/dotfiles/config/ ~/.config

}
setupwayfire() {
    printf "%b\n" "${YELLOW}Setting up Wayfire...${RC}"
    if [ -d "${HOME}/.config/wayfire/" ] && [ ! -d "${HOME}/.config/wayfire-bak" ]; then
        cp -r "${HOME}/.config/wayfire" "${HOME}/.config/wayfire-bak"
    fi
    mkdir -p "${HOME}/.config/wayfire/"
    curl -sSLo "${HOME}/.config/wayfire.ini" https://github.com/4ndr0666/dotfiles/raw/main/config/wayfire.ini        

}


setupbase
setupfont
setupzsh
setupconfig
setupwayfire

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
