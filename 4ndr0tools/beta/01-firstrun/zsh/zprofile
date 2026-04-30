#!/bin/bash
# File: /home/$USER/.config/zsh/.zprofile
# Author: 4ndr0666
# Edited: 12-2-24

# ======================================== // ZPROFILE //
# --- // Default_progs: 
export MICRO_TRUECOLOR=1
export EDITOR="nvim"
export TERMINAL="alacritty"
export TERMINAL_PROG="st"
export BROWSER="brave-beta"

# --- // History:
HISTSIZE=10000
SAVEHIST=10000
export HISTFILE="$XDG_CACHE_HOME/zshhistory"
#if [ ! -d "$HISTFILE" ]; then
#    mkdir -p "$HISTFILE"
#fi

# --- // Dynamic_Path:
static_dirs=(
    "$HOME/.npm-global/bin"
    "${JAVA_HOME:-/usr/lib/jvm/default/bin}"
    "$XDG_DATA_HOME/virtualenv"
    "$HOME/.local/bin"
    "$HOME/bin"
    "$HOME/andro/.local/share/goenv/bin"
    "/opt/"
    "$CARGO_HOME/bin"
    "/sbin"
    "/usr/sbin"
    "/usr/local/sbin"
    "/usr/bin"
)
dynamic_dirs=(/Nas/Build/git/syncing/scr/**/*(/))

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

# --- // Setup Cache File:
## cache_file="$HOME/.cache/dynamic_dirs.list"
##
## if [[ ! -f "$cache_file" || /Nas/Build/git/syncing/scr/ -nt "$cache_file" ]]; then
##     echo "Updating dynamic directories cache..."
##     find /Nas/Build/git/syncing/scr/ -type d \( -name '.git' -o -name '.github' \) -prune -o -type d -print > "$cache_file"
## fi
##
## dynamic_dirs=($(cat "$cache_file"))

# =========================================== // XDG_COMPLIANCE //
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# --- // XDG_RUNTIME_DIR:
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi

# --- // XDG_DATA_DIRS:
[ -z "$XDG_DATA_DIRS" ] && export XDG_DATA_DIRS="/usr/local/share:/usr/share"

# --- // Env:
export TRASHDIR="$XDG_DATA_HOME/Trash"
export ZDOTDIR="$HOME/.config/zsh/"
export DICS="$XDG_DATA_HOME/stardict/dic/"
export AUR_DIR="$XDG_DATA_HOME/aur_build"
export XINITRC="$XDG_CONFIG_HOME/x11/xinitrc"
export NOTMUCH_CONFIG="$XDG_CONFIG_HOME/notmuch-config"
export GTK2_RC_FILES="$XDG_CONFIG_HOME/gtk-2.0/gtkrc"
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
export GOROOT="$XDG_DATA_HOME/go"
export PATH="$GOROOT/bin:$PATH"
# export GOPATH="$XDG_DATA_HOME/go"
export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
export GOENV_ROOT="$XDG_DATA_HOME/goenv"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export RBENV_ROOT="$XDG_DATA_HOME/rbenv"
export PARALLEL_HOME="$XDG_CONFIG_HOME/parallel"
export _JAVA_OPTIONS=-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME/java"
export NUGET_PACKAGES="$XDG_CACHE_HOME/NuGetPackages"
export MODE_REPL_HISTORY="$XDG_DATA_HOME/node_repl_history"
export MESON_HOME="$XDG_CONFIG_HOME/meson"
export GEM_HOME="$XDG_DATA_HOME/gem"
export DOTNET_CLI_HOME="$XDG_DATA_HOME/dotnet"
export PSQL_HOME="$XDG_DATA_HOME/postgresql"
export MYSQL_HOME="$XDG_DATA_HOME/mysql"
export SQLITE_HOME="$XDG_DATA_HOME/sqlite"
export SQL_DATA_HOME="$XDG_DATA_HOME/sql"
export SQL_CONFIG_HOME="$XDG_CONFIG_HOME/sql"
export SQL_CACHE_HOME="$XDG_CACHE_HOME/sql"
export SQLITE_HISTORY="$XDG_DATA_HOME/sqlite_history"
export ELECTRON_CACHE="$XDG_CACHE_HOME/electron"
# export ELECTRON_MIRROR="https://npm.taobao.org/mirrors/electron/"
export NODE_DATA_HOME="$XDG_DATA_HOME/node"
export NODE_CONFIG_HOME="$XDG_CONFIG_HOME/node"
export TEXMFVAR="$XDG_CACHE_HOME/texlive/texmf-var"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export ANDROID_SDK_HOME="$XDG_CONFIG_HOME/android"
export LIBVA_DRIVERS_PATH="/usr/lib/dri/i965_drv_video.so"
export LIBVA_DRIVER_NAME=i965
# export LIBVA_DRIVER_NAME=mesa
# export LIBVA_DISPLAY=wayland
# export XAUTHORITY="$XDG_RUNTIME_DIR/Xauthority"
# ^^^ This line will break some DMs

mkdir -p "$WINEPREFIX" \
         "$CARGO_HOME" \
         "$GOROOT" \
         "$GOMODCACHE" \
         "$XDG_DATA_HOME/lib" \
         "$XDG_DATA_HOME/aur_build" \
         "$XDG_DATA_HOME/stardict/dic" \
         "$XDG_DATA_HOME/bin" \
         "$XDG_DATA_HOME/go/bin" \
         "$XDG_DATA_HOME/cargo/bin" \
         "$XDG_CONFIG_HOME/nvm" \
         "$XDG_CONFIG_HOME/meson" \
         "$XDG_DATA_HOME/gem" \
         "$XDG_DATA_HOME/virtualenv" \
         "$HOME/.local/pipx" \
         "$PSQL_HOME" \
         "$MYSQL_HOME" \
         "$SQLITE_HOME" \
         "$SQL_DATA_HOME" \
         "$SQL_CONFIG_HOME" \
         "$SQL_CACHE_HOME" \
         "$ELECTRON_CACHE" \
         "$NODE_DATA_HOME" \
         "$XDG_DATA_HOME/node/npm-global" \
         "$RBENV_ROOT" \
         "$W3M_DIR" \
         "$PARALLEL_HOME" \
         "$GEM_HOME" \
         "$DOTNET_CLI_HOME"

# Setting permissions where necessary (if any directory is not writable, we can adjust):
chmod u+w "$CARGO_HOME" "$GOROOT" "$GOMODCACHE" "$PSQL_HOME" "$MYSQL_HOME" "$SQLITE_HOME"

# ================================================ // X11_ENV //
#export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
# --- OPENBOX:
# export XGD_CURRENT_DESKTOP='openbox'
# export _JAVA_AWT_WM_NONREPARENTING=1
# export OpenGL_GL_PREFERENCE=GLVND  # For screen tearing
# export QT_QPA_PLATFORMTHEME=qt5ct
# export MOZ_USE_XINPUT2=1
# export AWT_TOOLKIT=MToolkit wmname LG3D  # May have to install wmname
# export _JAVA_OPTIONS="-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel -Dswing.crossplatformlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel ${_JAVA_OPTIONS}"
# =======================================================

# --- // Library:
export LD_LIBRARY_PATH="$XDG_DATA_HOME/lib:/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# --- // Askpass:
export SUDO_ASKPASS="$XDG_CONFIG_HOME"/wayfire/scripts/rofi_askpass  # Wayfire specific
#export SUDO_ASKPASS="/usr/bin/pinentry-dmenu"    # Xorg

# --- // GPG:
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
if [ ! -d "$GNUPGHOME" ]; then
    mkdir -p "$GNUPGHOME"
fi
chmod 700 "$GNUPGHOME"

gpg_env_file="$XDG_CONFIG_HOME/shellz/gpg_env"
if [ -f "$gpg_env_file" ]; then
    source "$gpg_env_file"
else
    echo "Warning: $gpg_env_file not found"
fi

#export GPG_TTY="$(tty)"
#gpg-connect-agent updatestartuptty /bye >/dev/null
#gpg-connect-agent reloadagent /bye >/dev/null
#eval $(ssh-agent) && ssh-add 2&>/dev/null

# --- // FZF:
bindkey '^R' fzf-history-widget
export FZF_DEFAULT_OPTS="
  --layout=reverse
  --height=40%
  --border
  --bind='ctrl-a:select-all,ctrl-d:deselect-all'
  --cycle
  --inline-info
  --tiebreak=index
  --preview 'bat --color=always --style=numbers --line-range=:500 {}'
  --preview-window='~3'
  --color=bg+:-1,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
  --color=marker:#f5e0dc,fg+:#a6e3a1,prompt:#cba6f7,hl+:#f38ba8"
#[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
#  --preview-window='right:50%'

#export FZF_DEFAULT_OPTS="
#  --layout=reverse
#  --height=40%
#  --border
#  --bind='ctrl-a:select-all,ctrl-d:deselect-all'
#  --cycle
#  --inline-info
#  --tiebreak=index
#  --preview='bat --style=numbers --color=always --line-range :500 {}'
#  --color=bg+:-1,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
#  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
#  --color=marker:#f5e0dc,fg+:#a6e3a1,prompt:#cba6f7,hl+:#f38ba8"

# --- // Truecolor:
case "${COLORTERM}" in
    truecolor|24bit) ;;
    *) export COLORTERM="24bit" ;;
esac

# --- // Bat:
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# --- // Less:
#export LESS='-RF'
#unset LESS_TERMCAP_mb
#unset LESS_TERMCAP_md
#unset LESS_TERMCAP_me
#unset LESS_TERMCAP_so
#unset LESS_TERMCAP_se
#unset LESS_TERMCAP_us
#unset LESS_TERMCAP_ue

# --- // LESSOPEN Configuration:
#export LESSOPEN="| bat --paging=never --style=numbers --color=always {}"

# --- // SPEEDUP KEYS:
#command -v xset &>/dev/null && xset r rate 300 50 || echo "xset command not found, skipping keyboard rate configuration."
#xset r rate 300 50

# --- // LF_SHORTCUTS:
[ ! -f "$XDG_CONFIG_HOME/shell/shortcutrc" ] && setsid -f shortcuts >/dev/null 2>&1
# Switch escape and caps if tty and no passwd required:
#sudo -n loadkeys "$XDG_DATA_HOME/larbs/ttymaps.kmap" 2>/dev/null
