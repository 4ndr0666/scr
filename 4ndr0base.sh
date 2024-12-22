#!/bin/bash
# File: 4ndr0baseinstall.sh
# Author: 4ndr0666

# ============================== // 4NDR0BASEINSTALL.SH //
# --- // Colors:
#tput setaf 0 = black
#tput setaf 1 = red
#tput setaf 2 = green
#tput setaf 3 = yellow
#tput setaf 4 = dark blue
#tput setaf 5 = purple
#tput setaf 6 = cyan
#tput setaf 7 = gray
#tput setaf 8 = light blue

# --- // Base Pkgs:
install_packages() {
	sudo pacman -Sy 
	sudo pacman -S github-cli git-delta \
	lsd eza fd micro expac pacdiff \
	xorg-xhost xclip \
	ripgrep diffuse neovim --noconfirm
	yay -Sy
	yay -S  bashmount-git debugedit lf-git --noconfirm
}

# --- // Zsh:
setup_zsh() {
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
    ZSHRC_FILE="$CONFIG_DIR/.zshrc"

    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONIFIG_DIR"
    fi

    # Write the configuration to .zshrc
    cat <<EOL >"$ZSHRC_FILE"
# =========================================== // 4NDR0666_ZSHRC //
PROMPT='%F{32}%n%f%F{166}@%f%F{64}%m:%F{166}%~%f%F{15}$%f '
RPROMPT='%F{15}(%F{166}%D{%H:%M}%F{15})%f'

HISTFILE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/history"
HISTSIZE=10000000
SAVEHIST=10000000
setopt extended_glob
setopt autocd 
setopt interactive_comments

# --- // Press `h` for cmd history: 
h() { if [ -z "$*" ]; then history 1; else history 1 | egrep "$@"; fi; }     #

[ -f "$HOME/.config/zsh/aliasrc" ] && source "$HOME/.config/zsh/aliasrc"
[ -f "$HOME/.config/zsh/functions.zsh" ] && source "$HOME/.config/zsh/functions.zsh"
[ -f "$HOME/.config/zsh/.zprofile" ] && source "$HOME/.config/zsh/.zprofile"
[ -d "/usr/share/zsh/plugins/zsh-autosuggestions" ] && source "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" 2>/dev/null
[ -d "/usr/share/zsh/plugins/fast-syntax-highlighting" ] && source "/usr/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" 2>/dev/null

EOL

    ln -s "$ZSHRC_FILE" $HOME/.zshrc || echo "Failed to create symlink for zsh config."
    # Ensure /etc/zsh/zshenv sets ZDOTDIR to the user's config directory
    #[ ! -f /etc/zsh/zshenv ] && "$ESCALATION_TOOL" mkdir -p /etc/zsh && "$ESCALATION_TOOL" touch /etc/zsh/zshenv
    #echo "export ZDOTDIR=\"$HOME/.config/zsh\"" | "$ESCALATION_TOOL" tee -a /etc/zsh/zshenv
}

