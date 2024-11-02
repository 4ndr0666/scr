#!/usr/bin/env bash

# File: /home/$USER/.config/zsh/.zprofile
# Author: 4ndr0666
# Edited: 10-19-24

# ======================================== // ZPROFILE //
static_dirs=(
#    "$HOME/.npm-global/bin"
#    "$HOME/.gem/ruby/2.7.0/bin"  # Adjust Ruby version as needed
#    "$HOME/.pyenv/bin"
#    "$HOME/.pyenv/shims"
#    "$HOME/.config/yarn/global/node_modules/.bin"
    "$HOME/.local/share/go/"
    "/usr/local/go/bin"
#    "${JAVA_HOME:-/usr/lib/jvm/default/bin}"  # Use JAVA_HOME if set, else default
#    "$HOME/.rvm/bin"
#    "$HOME/.virtualenvs"
#    "$HOME/.poetry/bin"
    "$HOME/.local/bin"
    "$HOME/bin"
#    "/opt/"
    "$CARGO_HOME/bin"
    "/sbin"
    "/usr/sbin"
    "/usr/local/sbin"
    "/usr/bin"
)

cache_file="$HOME/.cache/dynamic_dirs.list"

# Generate and cache directory list if cache doesn't exist or is outdated
if [[ ! -f "$cache_file" || /Nas/Build/git/syncing/scr/ -nt "$cache_file" ]]; then
    echo "Updating dynamic directories cache..."
    find /Nas/Build/git/syncing/scr/ -type d \
        \( -name '.git' -o -name '.github' \) -prune -o -type d -print > "$cache_file"
fi

#$(find /Nas/Build/git/syncing/scr -type d | paste -sd ':' -)  # FIND
#(/Nas/Build/git/syncing/scr/**/*(/))                          # ZSH GLOBBING 

# Load dynamic directories from cache
dynamic_dirs=($(/usr/bin/cat "$cache_file"))

# Combine static and dynamic directories
all_dirs=("${static_dirs[@]}" "${dynamic_dirs[@]}")

# Ensure PATH contains unique entries
typeset -U PATH

# Iterate over all directories and add those with executables to PATH
for dir in "${all_dirs[@]}"; do
    dir=${dir%/}  # Remove trailing slash if present
    if [[ -d "$dir" && -n "$dir/*(.x)" ]]; then
        PATH="$PATH:$dir"
        # Optional: Uncomment the next line for logging
        # echo "Added to PATH: $dir"
    fi
done

# Export the updated PATH
export PATH
unsetopt PROMPT_SP 2>/dev/null

# ======================== // DEFAULT_PROGRAMS //
export MICRO_TRUECOLOR=1
export EDITOR="nvim"
export TERMINAL="alacritty"
export TERMINAL_PROG="st"
export BROWSER="brave-beta"
# History:
HISTSIZE=30000
SAVEHIST=30000

# =================================== // XDG_BASE_SPECIFICATIONS //
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

# ============================================ // SYSTEM_WIDE_XDG_COMPLIANCE //
export XINITRC="$XDG_CONFIG_HOME"/x11/xinitrc
# export XAUTHORITY="$XDG_RUNTIME_DIR/Xauthority"
# ^^^ This line will break some DMs
export NOTMUCH_CONFIG="$XDG_CONFIG_HOME"/notmuch-config
export GTK2_RC_FILES="$XDG_CONFIG_HOME"/gtk-2.0/gtkrc
export W3M_DIR="$XDG_DATA_HOME"/w3m
export TLDR_CACHE_DIR="$XDG_CACHE_HOME"/tldr
export TRASHDIR="$XDG_DATA_HOME"/Trash
export WGETRC="$XDG_CONFIG_HOME"/wget/wgetrc
export INPUTRC="$XDG_CONFIG_HOME"/shell/inputrc
export WINEPREFIX="$XDG_DATA_HOME"/wineprefixes/default
export WINEARCH=win32
export PASSWORD_STORE_DIR="$XDG_DATA_HOME"/password-store
export TMUX_TMPDIR="$XDG_RUNTIME_DIR"
export ANDROID_SDK_HOME="$XDG_CONFIG_HOME"/android
export CARGO_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/cargo"
export GOPATH="$XDG_DATA_HOME"/go
export GOMODCACHE="$XDG_CACHE_HOME"/go/mod
#export POETRY_CACHE_DIR="$XDG_CACHE_HOME/pypoetry"
#export POETRY_VIRTUALS_PATH="$POETRY_CACHE_DIR/virtualenvs"
export ENV_DIR="$XDG_DATA_HOME"/virtualenv
export VIRTUAL_ENV_PROMPT="(💀)"
export PYTHONSTARTUP="$XDG_CONFIG_HOME"/python/pythonrc
export PIP_DOWNLOAD_CACHE="$XDG_CACHE_HOME"/pip/
export SQLITE_HISTORY="$XDG_DATA_HOME"/sqlite_history
# export KODI_DATA="$XDG_DATA_HOME/kodi"
export ZDOTDIR="$HOME"/.config/zsh/
export DICS=/usr/share/stardict/dic/
export AUR_DIR=/home/build
export TEXMFVAR="$XDG_CACHE_HOME"/texlive/texmf-var
export RUSTUP_HOME="$XDG_DATA_HOME"/rustup
export RBENV_ROOT="$XDG_DATA_HOME"/rbenv
export PARALLEL_HOME="$XDG_CONFIG_HOME"/parallel
export _JAVA_OPTIONS=-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME"/java
export NUGET_PACKAGES="$XDG_CACHE_HOME"/NuGetPackages
export MODE_REPL_HISTORY="$XDG_DATA_HOME"/node_repl_history
export XCURSOR_PATH=/usr/share/icons:$XDG_DATA_HOME/icons
export SCREENRC="$XDG_CONFIG_HOME"/screen/screenrc
export GEM_HOME="$XDG_DATA_HOME"/gem
export DOTNET_CLI_HOME="$XDG_DATA_HOME"/dotnet
export HISTFILE="$XDG_STATE_HOME"/zsh/history
export HISTFILE="${XDG_STATE_HOME}"/bash/history

#if [ ! -d "$HISTFILE" ]; then
#    mkdir -p "$HISTFILE"
#fi

mkdir -p "$WINEPREFIX" "$CARGO_HOME" "$GOPATH" "$GOMODCACHE"

# ================================================ // X11:
#export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
# --- OPENBOX:
# export XGD_CURRENT_DESKTOP='openbox'
# export _JAVA_AWT_WM_NONREPARENTING=1
# export OpenGL_GL_PREFERENCE=GLVND  # For screen tearing
# export QT_QPA_PLATFORMTHEME=qt5ct
# export MOZ_USE_XINPUT2=1
# export AWT_TOOLKIT=MToolkit wmname LG3D  # May have to install wmname
# export _JAVA_OPTIONS="-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel -Dswing.crossplatformlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel ${_JAVA_OPTIONS}"

# --- // Auto-complete:
#zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # Case insensitive tab completion
#zstyle ':completion:*' rehash true  # Automatically find new executables in path
#zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"  # Colored completion (different colors for dirs/files/etc)
#zstyle ':completion:*' completer _expand _complete _ignored _approximate
#zstyle ':completion:*' menu select
#zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
#zstyle ':completion:*:descriptions' format '%U%F{cyan}%d%f%u'

# --- // Speed-up Completeions:
#zstyle ':completion:*' accept-exact '*(N)'
#zstyle ':completion:*' use-cache on
#zstyle ':completion:*' cache-path ~/.cache/zcache
#source <(fzf --zsh)

# ======================================= // LIBRARY_AND_SECURITY //
export LD_LIBRARY_PATH="/home/andro/ffmpeg_build/lib:$HOME/.local/lib:/usr/local/lib:$LD_LIBRARY_PATH"
export SUDO_ASKPASS="/usr/bin/pinentry-dmenu"
# export XAUTHORITY="$XDG_RUNTIME_DIR/Xauthority"

# --- // GPG:
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
if [ ! -d "$GNUPGHOME" ]; then
    mkdir -p "$GNUPGHOME"
fi
chmod 700 "$GNUPGHOME"
#export GPG_TTY="$(tty)"
#gpg-connect-agent updatestartuptty /bye >/dev/null
#gpg-connect-agent reloadagent /bye >/dev/null
#eval $(ssh-agent) && ssh-add 2&>/dev/null

# ========================================== // Pager:
# --- // Bat:
export MANPAGER="sh -c 'col -bx | bat -l man -p | less -R'"

# --- // Fzf:
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

bindkey '^R' fzf-history-widget

export FZF_DEFAULT_OPTS="
  --layout=reverse
  --height=40%
  --border
  --bind='ctrl-a:select-all,ctrl-d:deselect-all'
  --cycle
  --inline-info
  --tiebreak=index
  --preview='bat --style=numbers --color=always --line-range :500 {} | head -n 100'
  --preview-window='right:50%'
  --color=bg+:-1,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
  --color=marker:#f5e0dc,fg+:#a6e3a1,prompt:#cba6f7,hl+:#f38ba8"

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


# Ensure truecolor support
case "${COLORTERM}" in
    truecolor|24bit) ;;  # Already supports truecolor
    *) export COLORTERM="24bit" ;;
esac

# --- // LESS Configuration:
export LESS='-R'  # Preserve raw control characters
unset LESS_TERMCAP_mb
unset LESS_TERMCAP_md
unset LESS_TERMCAP_me
unset LESS_TERMCAP_so
unset LESS_TERMCAP_se
unset LESS_TERMCAP_us
unset LESS_TERMCAP_ue

# --- // LESSOPEN Configuration:
export LESSOPEN="| bat --paging=never --style=numbers --color=always {}"

# ------------------------------------------------------- // MISC //
# --- // SPEEDUP KEYS:
#command -v xset &>/dev/null && xset r rate 300 50 || echo "xset command not found, skipping keyboard rate configuration."
#xset r rate 300 50

# --- // LF_SHORTCUTS:
[ ! -f "$XDG_CONFIG_HOME/shell/shortcutrc" ] && setsid -f shortcuts >/dev/null 2>&1
# Switch escape and caps if tty and no passwd required:
#sudo -n loadkeys "$XDG_DATA_HOME/larbs/ttymaps.kmap" 2>/dev/null
