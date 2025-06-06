#!/bin/bash
# shellcheck disable=all
# File: 4ndr0base.sh
# Author: 4ndr0666
# Quick setup script for basic requirements on a new machine.

# ============================== // 4NDR0BASEINSTALL.SH //
## Constants:
DOTFILES_REPO="https://github.com/4ndr0666/dotfiles.git" 
PKGLIST="https://raw.githubusercontent.com/4ndr0666/refs/heads/main/dotfiles/4ndr0pkglist.txt"
REPO_BRANCH="main"
AUR_HELPER="yay"
BACKUP_DIR="$HOME/backups"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TERM=ansi

## XDG 
export XDG_CONFIG_HOME="$USER/.config"
export XDG_DATA_HOME="$USER/.local/share"
export XDG_CACHE_HOME="$USER/.cache"
export XDG_STATE_HOME="$USER/.local/state"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"

## Colors:
RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
GREEN='\033[32m'

## Error handling
error() {
        printf "%s\n" "${RED}$1${RC}" >&2
        exit 1
}

installpkg() {
        yay --noconfirm --needed -S "$1" >/dev/null 2>&1
}

## Welcome
printf "%b\n" "Welcome ${CYAN}4ndr0666!${RC}"
sleep 2
printf "%b\n" "Getting things ready for you..."
sleep 1

## AUR Helper
install_aur_helper() {
    if ! command -v "$AUR_HELPER" &>/dev/null; then
        printf "%b\n" "Detected AUR helper: ${CYAN}($AUR_HELPER)${RC}"
        sleep 1
        installpkg base-devel
        git clone "https://aur.archlinux.org/$AUR_HELPER.git" "/tmp/$AUR_HELPER" || {
            error "Failed to clone $AUR_HELPER repository."
        }
        pushd "/tmp/$AUR_HELPER" || exit 1
        sudo -u "$USER" makepkg --noconfirm -si >/dev/null 2>&1 || {
            printf "%b\n" "${RED}Failed to build and install $AUR_HELPER.${RC}"
            popd || exit 1
            exit 1
        }
        popd || exit 1
        printf "%b\n" "${CYAN}$AUR_HELPER${RC} installed successfully."
    else
        printf "%b\n" "${GREEN}($AUR_HELPER) is already installed.${RC}"
    fi
}

## Base Pkgs:
setup_repos() {
    ### Refresh Keyrings
    sudo pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1 
    sudo pacman --noconfirm --needed -S \
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com >/dev/null 2>&1
    sudo pacman-key --lsign-key 3056513887B78AEB >/dev/null 2>&1

    ### Install Chaotic-AUR
    printf "%b\n" "Installing ${CYAN}Chaotic AUR${RC} Keyring..."    
    sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' >/dev/null 2>&1

    ### Add Repo To pacman.conf
    printf "%b\n" "Installing ${CYAN}Chaotic AUR${RC} Mirrorlist..."    
    sudo -u "$USER" grep -q "^\[chaotic-aur\]" /etc/pacman.conf ||
        sudo -u "$USER" echo "[chaotic-aur]
Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf
    sudo pacman -Sy --noconfirm >/dev/null 2>&1
    sudo pacman-key --populate archlinux >/dev/null 2>&1            
}

## Clone dotfiles
setup_dotfiles() {
    git clone --depth 1 --branch "$REPO_BRANCH" "$DOTFILES_REPO" "$HOME/dotfiles" 2>/dev/null || {
        printf "%b\n" "${GREEN}Dotfiles repository already exists. Pulling latest changes...${RC}"
        sudo -u "$USER" git -C "$HOME/dotfiles" pull origin "$REPO_BRANCH" || {
            error "Failed to update dotfiles repository."
        }
    }
    sudo -u "$USER" rsync -a --exclude=".git/" "$HOME/dotfiles/home/andro/" "$HOME/" || {
        error "Failed to rsync dotfiles to $HOME."
    }
    printf "%b\n" "${GREEN}Dotfiles cloned and deployed successfully.${RC}"
}

install_pkgs() {
    installpkg - < "$PKGLIST" || {
    	printf "%b\n" "${RED}ERROR:${RC} Could not download 4ndr0pkglist.txt. Check the internet connection."
    }
    printf "%b\n" "Manually installing base packages..."
    installpkg base-devel debugedit unzip archlinux-keyring github-cli git-delta exa lsd fd micro expac bat bash-completion pacdiff pkgfile neovim xorg-xhost bat xclip ripgrep diffuse neovim fzf sysz brave-beta-bin zsh-syntax-highlighting zsh-history-substring-search zsh-autosuggestions bashmount-git lsd lf-git || {
    	error "Failed to download and manually install base packages"
    }
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

    printf "%b\n" "${GREEN}Meslo Nerd-fonts are installed.${RC}"
}

setupconfig() {    
    printf "%b\n" "Backing up existing config files"
    mkdir -p "$BACKUP_DIR"
    
    if [ -d "$HOME/.config" ] && [ ! -d "$BACKUP_DIR/.config-bak" ]; then
        cp -r "$HOME/.config" "$BACKUP_DIR/.config-bak"
    fi
    mkdir -p "$HOME/.config"
    
#    if [ -d "$HOME/.config/wayfire/" ] && [ ! -d "$BACKUP_DIR/.config/wayfire-bak" ]; then
#        cp -r "$HOME/.config/wayfire" "$BACKUP_DIR/.config/wayfire-bak"
#    fi
#    mkdir -p "$HOME/.config/wayfire"
    
#    if [ -d "$HOME/.config/zsh/" ] && [ ! -d "$BACKUP_DIR/.config/zsh-bak" ]; then
#        cp -r "$HOME/.config/zsh" "$HOME/.config/zsh-bak"
#    fi
#    mkdir -p "$HOME/.config/zsh/"

#    if [ -d "$HOME/.config/Thunar/" ] && [ ! -d "$BACKUP_DIR/.config/Thunar-bak" ]; then
#        cp -r "$HOME/.config/Thunar" "$BACKUP_DIR/.config/Thunar-bak"
#    fi
#    mkdir -p "$HOME/.config/Thunar/"
    
    yes | cp -r "$HOME/dotfiles/home/andro/.config" "$HOME"
    cd "$HOME" && git clone https://github.com/4ndr0666/Wayfire_4ndr0666
    yes | cp -r "$HOME/Wayfire_4ndr0666/config/wayfire" "$HOME/.config"
#    curl -sSLo "$HOME/.config/wayfire.ini" https://raw.githubusercontent.com/4ndr0666/Wayfire_4ndr0666/refs/heads/main/config/wayfire.ini
#    curl -sSLo "${HOME}/.config/zsh/aliasrc" https://raw.githubusercontent.com/4ndr0666/dotfiles/refs/heads/main/home/andro/.config/zsh/aliasrc  
#    curl -sSLo "${HOME}/.config/zsh/functions.zsh" https://raw.githubusercontent.com/4ndr0666/dotfiles/refs/heads/main/home/andro/.config/zsh/functions.zsh
#    curl -sSLo "${HOME}/.config/zsh/gpg_env" https://raw.githubusercontent.com/4ndr0666/dotfiles/refs/heads/main/home/andro/.config/zsh/gpg_env      
#    curl -sSLo "${HOME}/.config/user-dirs.dirs" https://raw.githubusercontent.com/4ndr0666/dotfiles/refs/heads/main/home/andro/.config/user-dirs.dirs
#    curl -sSLo "${HOME}/.config/user-dirs.locale" https://raw.githubusercontent.com/4ndr0666/dotfiles/refs/heads/main/home/andro/.config/user-dirs.locale
#    curl -sSLo "${HOME}/.config/lf/cleaner" https://raw.githubusercontent.com/4ndr0666/dotfiles/refs/heads/main/home/andro/.config/lf/cleaner
#    curl -sSLo "${HOME}/.config/lf/icons" https://raw.githubusercontent.com/4ndr0666/dotfiles/refs/heads/main/home/andro/.config/lf/icons
#    curl -sSLo "${HOME}/.config/lf/lfrc" https://raw.githubusercontent.com/4ndr0666/dotfiles/refs/heads/main/home/andro/.config/lf/lfrc
#    curl -sSLo "${HOME}/.config/lf/scope" https://raw.githubusercontent.com/4ndr0666/dotfiles/refs/heads/main/home/andro/.config/lf/scope
}

## TODO
#setupp10k() {
#}

## Zshrc:
setupzsh() {
    printf "%b\n" "Setting up ZSH"
    CONFIG_DIR="$HOME/.config/zsh"
    ZSHRC_FILE="$CONFIG_DIR/.zshrc"

    if [ ! -f "${ZSHRC_FILE" ]; then  
    cat <<EOL >"$ZSHRC_FILE"
# ===================== // 4NDR0666_ZSHRC //
## Powerlevel10k:
#if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
#fi

## Standard:
autoload -U colors && colors
#PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}$%b "

## Solarized:
PROMPT='%F{32}%n%f%F{166}@%f%F{64}%m:%F{166}%~%f%F{15}$%f '
RPROMPT='%F{15}(%F{166}%D{%H:%M}%F{15})%f'

## Auto-completions 
autoload -U compinit && compinit
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:complete:(\\|*)cd:*' fzf-preview 'exa -1 --color=always --icons $realpath'
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' fzf-preview 'echo ${(P)word}'
zstyle ':fzf-tab:complete:*:*' fzf-preview 'less ${(Q)realpath}'
export LESSOPEN='|fzf_preview %s'
zstyle ':fzf-tab:complete:*:options' fzf-preview
zstyle ':fzf-tab:complete:*:argument-1' fzf-preview
setopt RM_STAR_WAIT
setopt print_exit_value
setopt no_beep
setopt correct
unsetopt correct_all
fpath=("$HOME/.config/zsh/completion" $fpath)
zstyle ':completion:*' menu select=2
unsetopt complete_aliases
unsetopt always_to_end
unsetopt menu_complete
setopt auto_menu
setopt auto_list
setopt auto_name_dirs
setopt auto_param_slash
setopt complete_in_word
setopt extended_glob
setopt glob_complete
DIRSTACKSIZE=8
setopt autocd
setopt cdable_vars
setopt auto_pushd
setopt pushd_to_home
setopt pushd_minus
setopt pushd_ignore_dups
setopt pushd_silent

## History:
[ -d ! "$HOME/.cache/zsh" ] && mkdir -p "$HOME/.cache/zsh"
chmod ug+rw "$HOME/.cache/zsh"
[ -f ! "$HOME/.cache/zsh/history" ] && touch -f "$HOME/.cache/zsh/history"
chmod ug+rw "$HOME/.cache/zsh/history"
HISTFILE="$HOME/.cache/zsh/history"
HISTSIZE=10000000
SAVEHIST=10000000

## Setopt:
setopt extended_glob
setopt autocd
setopt interactive_comments
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt hist_verify
setopt append_history
setopt extended_history
setopt inc_append_history
setopt share_history
setopt hist_ignore_dups
setopt hist_expire_dups_first

### Expand global aliases:
globalias() {
    if [[$LBUFFER =~ ' [a-Z0-9]+S' ]]; then
	zle _expand_alias
	zle expand-word
    fi
    zle self-insert
}

zle -N globalias

# FD
### Use FD indtead of find
_fzf_compgen_path() {
	fd --hidden --follow --exclude ".git" . "$1"
}

_fzf_compgen_dir() {
	fd --type d --hidden --follow --exclude ".git" . "$1"
}

## Rehash
if [[ ! -d "$HOME/.cache/zsh/zcache" ]]; then
    touch "$HOME/.cache/zsh/zcache" 
    chmod ug+rw "$HOME/.cache/zsh/zcache" 
else
    exit 0
fi

zshcache_time="$(date +%s%N)"

rehash_precmd() {
    if [[ -a /var/cache/zsh/pacman ]]; then
        local paccache_time="$(stat -c %Y /var/cache/zsh/pacman)"
        if (( zshcache_time < paccache_time )); then
            rehash
            zshcache_time="$paccache_time"
        fi
    fi
}
autoload -Uz add-zsh-hook
add-zsh-hook -Uz precmd rehash_precmd

## Bindings
### Vim:
bindkey -v
bindkey -a -r t
export KEYTIMEOUT=1
bindkey -a u undo
bindkey -a U redo

### Swap:
bindkey -a a vi-add-eol
bindkey -a A vi-add-next

### Vim tab-complete menu:
bindkey -a h backward-char
bindkey -a n history-substring-search-down
bindkey -a e history-substring-search-up
bindkey -a k vi-repeat-search
bindkey -a K vi-rev-repeat-search
bindkey -a j vi-forward-workd-end
bindkey -a E vi-forward-blank-word-end

### Home and end:
bindkey -a "^[[1~" beginning-of-line
bindkey -a "^[[4~" end-of-line

### History substring search:
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey "^[[1~" beginning-of-line
bindkey "^[[4~" end-of-line
bindkey "^[[5~" beginning-of-history
bindkey "^[[6~" end-of-history
bindkey "^[[3~" delete-char
bindkey "^[[2~" quoted-insert

### Allow deleting before insertion:
bindkey '^?' backward-delete-char
bindkey "^W" backward-kill-word
bindkey '^H' backward-kill-word

## LF
lfcd () {
    tmp="$(mktemp -uq)"
    trap 'rm -f $tmp >/dev/null 2>&1 && trap - HUP INT QUIT TERM PWR EXIT' HUP INT QUIT TERM PWR EXIT
    lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir="$(cat "$tmp")"
        [ -d "$dir" ] && [ "$dir" != "$(pwd)" ] && cd "$dir"
    fi
}

bindkey -s '^o' '^ulfcd\n'

bindkey -s '^a' '^ubc -lq\n'

bindkey -s '^f' '^ucd "$(dirname "$(fzf)")"\n'

bindkey '^[[P' delete-char

## NVM
export NVM_DIR="$XDG_CONFIG_HOME/nvm"

source_nvm() {
    local script="$1"
    if [ -s "$script" ]; then
        source "$script"
    else
        echo "Warning: NVM script not found at $script"
    fi
}
source_nvm "$NVM_DIR/nvm.sh"
source_nvm "$NVM_DIR/bash_completion"

## Minor Aliases
### 'h' for cmd history:
h() { if [ -z "" ]; then history 1; else history 1 | egrep ""; fi; }
alias reload='echo "Reloading .zshrc" && source ~/.zshrc'

# --- // Source the files:
[ -f "$HOME/.config/zsh/aliasrc" ] && source "$HOME/.config/zsh/aliasrc"
[ -f "$HOME/.config/zsh/functions.zsh" ] && source "$HOME/.config/zsh/functions.zsh"
[ -f "$HOME/.config/zsh/.zprofile" ] && source "$HOME/.config/zsh/.zprofile"
[ -d "/usr/share/zsh/plugins/zsh-autosuggestions" ] && source "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" 2>/dev/null
[ -d "/usr/share/zsh/plugins/zsh-syntax-highlighting" ] && source "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" 2>/dev/null

## Plugins 
### FZF
source <(fzf --zsh)

### History-substring-search
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh 2>/dev/null

### Autosuggestions
ZSH_AUTOSUGGEST_USE_ASYNC=true
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null

### Fast-Syntax-highlighting
source /usr/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh 2>/dev/null

EOL
    fi
    ### Create the symlink:
    ln -sv "$ZSHRC_FILE" "$HOME/.zshrc" || {
        error "Failed to create symlink for .zshrc"
    }
}

## Zprofile:
setupzprofile() {
    printf "%b\n" "Setting up the Zprofile..."
    CONFIG_DIR="$HOME/.config/zsh"
    ZPROFILE="$CONFIG_DIR/.zprofile"

    if [ ! -f "$ZPROFILE" ]; then
    cat <<EOL >"$ZPROFILE"
#!/bin/sh
# ======================================== // ZPROFILE //

## Default programs
export MICRO_TRUECOLOR=1
export EDITOR="nvim"
export TERMINAL="alacritty"
export TERMINAL_PROG="st"
export BROWSER="brave-beta"

## Dynamic Path
static_dirs=(
    "$HOME/.npm-global/bin"
    "$HOME/.local/share/goenv/bin"
    "$HOME/.local/bin"
    "$HOME/bin"
    "$XDG_DATA_HOME/gem/ruby/3.3.0/bin"
    "$XDG_DATA_HOME/virtualenv"
    "$XDG_DATA_HOME/go/bin"
    "$CARGO_HOME/bin"
    "${JAVA_HOME:-/usr/lib/jvm/default/bin}"
    "/sbin"
    "/opt/"
    "/usr/sbin"
    "/usr/local/sbin"
    "/usr/bin"
)
dynamic_dirs=($HOME/scr/**/*(/))
all_dirs=("${static_dirs[@]}" "${dynamic_dirs[@]}")
typeset -U PATH

for dir in "${all_dirs[@]}"; do
    dir=${dir%/}
    # Add directory to PATH if it contains at least one executable file
    if [[ -d "$dir" && -n "$(find "$dir" -maxdepth 1 -type f -executable | head -n 1)" ]]; then
        PATH="$PATH:$dir"
    fi
done
export PATH

## XDG
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir "$XDG_RUNTIME_DIR"       # Bypassing the alias
    \chmod 0700 "$XDG_RUNTIME_DIR"
fi

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

## Environment
export TRASHDIR="$XDG_DATA_HOME/Trash"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh/"
export DICS="$XDG_DATA_HOME/stardict/dic/"
export AUR_DIR="/home/build"
export XINITRC="$XDG_CONFIG_HOME/x11/xinitrc"
#export XAUTHORITY="$XDG_RUNTIME_DIR/Xauthority" # This line will break some DMs.
export NOTMUCH_CONFIG="$XDG_CONFIG_HOME/notmuch-config"
export GTK2_RC_FILES="$XDG_CONFIG_HOME/gtk-2.0/gtkrc-2.0"
export W3M_DIR="$XDG_DATA_HOME/w3m"
export TLDR_CACHE_DIR="$XDG_CACHE_HOME/tldr"
export WGETRC="$XDG_CONFIG_HOME/wget/wgetrc"
export INPUTRC="$XDG_CONFIG_HOME/shell/inputrc"
export XCURSOR_PATH="/usr/share/icons:$XDG_DATA_HOME/icons"
export SCREENRC="$XDG_CONFIG_HOME/screen/screenrc"
export PASSWORD_STORE_DIR="$XDG_DATA_HOME/password-store"
export TMUX_TMPDIR="$XDG_RUNTIME_DIR"
export WINEPREFIX="$XDG_DATA_HOME/wineprefixes/default"
export WINEARCH=win32
export VENV_HOME="$XDG_DATA_HOME/virtualenv"
export PIPX_HOME="$XDG_DATA_HOME/pipx"
export ENV_DIR="$XDG_DATA_HOME/virtualenv"
export VIRTUAL_ENV_PROMPT="(💀)"
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonrc"
export PIP_DOWNLOAD_CACHE="$XDG_CACHE_HOME/pip/"
export GOPATH="$XDG_DATA_HOME/go"
export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
export GOENV_ROOT="$XDG_DATA_HOME/goenv"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export RBENV_ROOT="$XDG_DATA_HOME/rbenv"
export PARALLEL_HOME="$XDG_CONFIG_HOME/parallel"
export _JAVA_OPTIONS="-Djava.util.prefs.userRoot=\"$XDG_CONFIG_HOME/java\""
export MODE_REPL_HISTORY="$XDG_DATA_HOME/node_repl_history"
export MESON_HOME="$XDG_CONFIG_HOME/meson"
export GEM_HOME="$XDG_DATA_HOME/gem"
export SQLITE_HISTORY="$XDG_DATA_HOME/sqlite_history"
export ELECTRON_CACHE="$XDG_CACHE_HOME/electron"
#export ELECTRON_MIRROR="https://npm.taobao.org/mirrors/electron/"
export NODE_DATA_HOME="$XDG_DATA_HOME/node"
export NODE_CONFIG_HOME="$XDG_CONFIG_HOME/node"
export TEXMFVAR="$XDG_CACHE_HOME/texlive/texmf-var"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export LIBVA_DRIVER_NAME=radeonsi
# export LIBVA_DISPLAY=wayland

mkdir "$WINEPREFIX" \
"$CARGO_HOME" \
"$GOPATH" \
"$GOMODCACHE" \
"$XDG_DATA_HOME/lib" \
"$AUR_DIR" \
"$XDG_DATA_HOME/stardict/dic" \
"$XDG_DATA_HOME/bin" \
"$XDG_DATA_HOME/go/bin" \
"$XDG_DATA_HOME/cargo/bin" \
"$XDG_CONFIG_HOME/nvm" \
"$XDG_CONFIG_HOME/meson" \
"$XDG_CACHE_HOME/zsh" \
"$XDG_DATA_HOME/gem" \
"$XDG_DATA_HOME/virtualenv" \
"$HOME/.local/pipx" \
"$ELECTRON_CACHE" \
"$NODE_DATA_HOME" \
"$XDG_DATA_HOME/node/npm-global" \
"$RBENV_ROOT" \
"$W3M_DIR" \
"$PARALLEL_HOME" \
"$GEM_HOME" >/dev/null 2>&1

\chmod ug+rw "$WINEPREFIX" \
"$CARGO_HOME" \
"$GOPATH" \
"$GOMODCACHE" \
"$XDG_DATA_HOME/lib" \
"$XDG_DATA_HOME/stardict/dic" \
"$XDG_DATA_HOME/bin" \
"$XDG_DATA_HOME/go/bin" \
"$XDG_DATA_HOME/cargo/bin" \
"$XDG_CONFIG_HOME/nvm" \
"$XDG_CONFIG_HOME/meson" \
"$XDG_CACHE_HOME/zsh" \
"$XDG_DATA_HOME/gem" \
"$XDG_DATA_HOME/virtualenv" \
"$HOME/.local/pipx" \
"$ELECTRON_CACHE" \
"$NODE_DATA_HOME" \
"$XDG_DATA_HOME/node/npm-global" \
"$RBENV_ROOT" \
"$W3M_DIR" \
"$PARALLEL_HOME" \
"$GEM_HOME"

export PSQL_HOME="$XDG_DATA_HOME/postgresql"
export MYSQL_HOME="$XDG_DATA_HOME/mysql"
export SQLITE_HOME="$XDG_DATA_HOME/sqlite"
export SQL_DATA_HOME="$XDG_DATA_HOME/sql"
export SQL_CONFIG_HOME="$XDG_CONFIG_HOME/sql"
export SQL_CACHE_HOME="$XDG_CACHE_HOME/sql"

mkdir "$PSQL_HOME" \
"$MYSQL_HOME" \
"$SQLITE_HOME" \
"$SQL_DATA_HOME" \
"$SQL_CONFIG_HOME" \
"$SQL_CACHE_HOME" >/dev/null 2>&1

\chmod ug+rw "$PSQL_HOME" \
"$MYSQL_HOME" \
"$SQLITE_HOME" \
"$SQL_DATA_HOME" \
"$SQL_CONFIG_HOME" \
"$SQL_CACHE_HOME"

## Library
export LD_LIBRARY_PATH="$XDG_DATA_HOME/lib:/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

## Askpass
export SUDO_ASKPASS="$XDG_CONFIG_HOME"/wayfire/scripts/rofi_askpass  # Wayfire specific
#export SUDO_ASKPASS="/usr/bin/pinentry-dmenu"    # Xorg

## GPG
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
if [ ! -d "$GNUPGHOME" ]; then
    \mkdir -p "$GNUPGHOME"
    \chmod 700 "$GNUPGHOME"
fi

gpg_env_file="$XDG_CONFIG_HOME/shellz/gpg_env"
if [ -f "$gpg_env_file" ]; then
    source "$gpg_env_file"
else
    echo "Warning: $gpg_env_file not found"
fi

#---

# FZF
### Defaults:
export FZF_DEFAULT_OPTS="
  --height=60%
  --border=double
  --padding=1%
  --info=right
  --separator=_
  --preview='
    set filename (basename {})
    if string match -q \"*.txt\" -- \$filename
      bat --style=numbers --color=always {}
    else if string match -q \"*.pdf\" -- \$filename
      zathura {} &
    else if string match -q \"*.jpg\" -- \$filename
      feh {} &
    else if string match -q \"*.jpeg\" -- \$filename
      feh {} &
    else if string match -q \"*.png\" -- \$filename
      feh {} &
    else if string match -q \"*.gif\" -- \$filename
      feh {} &
    else
      bat --style=numbers --color=always {}
    end
  '
  --preview-window=hidden:right:69%
  --preview-label=eyes
  --margin=5%
  --border-label=search
  --color=16
  --layout=reverse
  --prompt=⭐
  --bind='enter:execute(
    set filename (basename {})
    if string match -q \"*.txt\" -- \$filename
      emacsclient -nw {}
    else if string match -q \"*.pdf\" -- \$filename
      zathura {}
    else if string match -q \"*.jpg\" -- \$filename
      feh {}
    else if string match -q \"*.jpeg\" -- \$filename
      feh {}
    else if string match -q \"*.png\" -- \$filename
      feh {}
    else if string match -q \"*.gif\" -- \$filename
      feh {}
    else
      emacsclient -nw {}
    end
  )'
  --bind=alt-o:toggle-preview
"

## History binding:
bindkey '^R' fzf-history-widget

## fh - repeat history
fh() {
  print -z $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed -E 's/ *[0-9]*\*? *//' | sed -E 's/\\/\\\\/g')
}

## Use ctrl Y to copy:
export FZF_DEFAULT_OPTS='--bind "ctrl-y:execute-silent(printf {} | cut -f 2- | wl-copy --trim-newline)"'

## Truecolor
case "${COLORTERM}" in
    truecolor|24bit) ;;
    *) export COLORTERM="24bit" ;;
esac

## PAGER
export PAGER=vimpager

## Less
export LESS='-R'
export LESS_TERMCAP_mb=$'\E[01;31m'             # begin blinking
export LESS_TERMCAP_md=$'\E[01;31m'             # begin bold
export LESS_TERMCAP_me=$'\E[0m'                 # end mode
export LESS_TERMCAP_se=$'\E[0m'                 # end standout-mode
export LESS_TERMCAP_so=$'\E[01;44;33m'          # begin standout-mode - info box
export LESS_TERMCAP_ue=$'\E[0m'                 # end underline
export LESS_TERMCAP_us=$'\E[01;32m'             # begin underline

## LESSOPEN 
export LESSOPEN="| /usr/bin/highlight -O ansi %s 2>/dev/null"

EOL
    fi
    ### Create the symlink:
    ln -sf "$ZPROFILE" "$HOME/.zprofile" || {
        error "Failed to create symlink for .zprofile"
    }
}

cleanup() {
    printf "%b\n" "Cleaning up..."
    sleep 1
    rm "$HOME/.config/yay" -rf
    bat cache --build >/dev/null/ 2>&1
    printf "%b\n" "${CYAN}4ndr0basepkgs${RC} installation completed."    
}

## Main Entry Point
install_aur_helper
setupfont
setup_repos
setup_dotfiles
setupconfig
setupzsh
setupzprofile
cleanup

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
