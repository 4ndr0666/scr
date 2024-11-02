# File: /home/$USER/.zshrc
# Author: 4ndr0666
# Edited: 09-22-2024

# ======================================== // 4NDR0666_ZSHRC // 
# ---------------------------- // PROMPTS //
# --- // Fancy Prompt:
source ~/.config/shellz/fancy-prompts.zsh

precmd() {
	fancy-prompts-precmd
}
prompt-zee -PDp "≽ "

# --- // Custom Prompt:
#autoload -U colors && colors    
#PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%🗁%{$fg[red]%}]%{$reset_color%}$%b "

# --- // Powerlevel10 Prompt:
#if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
#fi
#if [ -f /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme ]; then
#   source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
#fi
#[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# --- // General opt: 
setopt extended_glob          # Enable extended globbing
setopt autocd                 # Auto `cd` into directories
setopt interactive_comments   # Allow comments in interactive shells
# Disable Ctrl+S to prevent terminal freeze
stty stop undef

# ----------------------------- // ALIAS //
alias reload='exec zsh'

# ----------------------------- // CUSTOM FFMPEG BUILD //
export PATH="/home/andro/bin:$PATH"
export PKG_CONFIG_PATH="home/andro/ffmpeg_build/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="/home/andor/ffmpeg_build/lib:$LD_LIBRARY_PATH"

# ----------------------------- // AUTO COMPLETE //
autoload -U compinit 
compinit -d /home/andro/.cache/zsh/zcompdump-"$ZSH_VERSION"

# Set completion styles
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' completer _expand _complete _ignored _approximate
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
zstyle ':completion:*:descriptions' format '%U%F{cyan}%d%f%u'
# Speed-up Completions:
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zcache

zmodload zsh/complist
compinit
_comp_options+=(globdots)

# ---------------------------- // SETOPT //
# --- // HISTORY:
setopt inc_append_history     # Append to history, not overwrite
setopt share_history          # Share history across all sessions
setopt extended_history       # Save timestamps in history
setopt hist_expire_dups_first
setopt hist_ignore_space

# fix zsh history behavior
#h() { if [ -z "$*" ]; then history 1; else history 1 | egrep "$@"; fi; }

# ---------------------------- // DIRECTORY NAVIGATION //
# --- // LFCD:
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

# --- // VIM:
# Delete character with a specific key sequence
bindkey '^[[P' delete-char
# Edit command line with Vim using Ctrl+E
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^e' edit-command-line
bindkey -M vicmd '^[[P' vi-delete-char
bindkey -M vicmd '^e' edit-command-line
bindkey -M visual '^[[P' vi-delete

# --- // LINE NAVIGATION:
#autoload -Uz up-line-or-beginning-search
#autoload -Uz down-line-or-beginning-search
#zle -N up-line-or-beginning-search
#zle -N down-line-or-beginning-search
#bindkey '\eOA' up-line-or-beginning-search
#bindkey '\e[A' up-line-or-beginning-search
#bindkey '\eOB' down-line-or-beginning-search
#bindkey '\e[B' down-line-or-beginning-search

# --- // FZFCD:
#cd_fzf() {
#    local dir
#    dir=$(dirname "$(fzf)")
#    if [ -d "$dir" ]; then
#        cd "$dir"
#    else
#        echo "Directory not found: $dir"
#    fi
#}

# --- // Autoset_Display: 
#if [ -z "$DISPLAY" ]; then
#    if command -v loginctl &>/dev/null; then
#        LOGINCTL_SESSION=$(loginctl show-user "$USER" -p Display 2>/dev/null | cut -d= -f2)
#        if [ -n "$LOGINCTL_SESSION" ]; then
#            export DISPLAY=$(loginctl show-session "$LOGINCTL_SESSION" -p Display | cut -d= -f2)
#        fi
#    fi
#    if command -v ck-list-sessions &>/dev/null; then
#        eval "$(ck-list-sessions | awk "/^Session/{right=0} /unix-user = '$UID'/{right=1} /x11-display = '(.+)'/{ if(right == 1) printf(\"DISPLAY=%s\\n\", \$3); }")"
#    fi
#fi

# ----------------------------- // ON-DEMAND REHASH //
# Refresh Zsh completions if pacman cache changes
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

# ----------------------------- // SOURCES //
#export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Source custom functions
functions_file="/home/andro/.config/shellz/functions/functions.zsh"
if [ -f "$functions_file" ]; then
    source "$functions_file"
else
    echo "Warning: $functions_file not found"
fi

# Source additional configuration files
for config_file in "/home/andro/.config/zsh/.zprofile" "/home/andro/.config/shellz/aliasrc"; do
    if [ -f "$config_file" ]; then
        source "$config_file"
    else
        echo "Warning: $config_file not found"
    fi
done

# Fpath completions
fpath=("$HOME/.local/share/zsh/completions" "/usr/share/zsh/vendor-completions" $fpath)

# fzf
source <(fzf --zsh)

# ----------------------------- // NVM //
export NVM_DIR="/home/andro/.config/nvm"

# Function to source NVM scripts
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

# ----------------------------- // GPG ENV //
gpg_env_file="/home/andro/.config/shellz/gpg_env"
if [ -f "$gpg_env_file" ]; then
    source "$gpg_env_file"
else
    echo "Warning: $gpg_env_file not found"
fi

# ---------------------------- // PLUGINS //
# Define the plugins directory
source_dir="/usr/share/zsh/plugins/"

# Source all .zsh plugin files in subdirectories
if [ -d "$source_dir" ]; then
    for plugin_dir in "$source_dir"/*/; do
        for plugin_file in "$plugin_dir"*.zsh; do
            if [ -f "$plugin_file" ]; then
                source "$plugin_file"
            fi
        done
    done
else
    echo "Warning: Plugin directory '$source_dir' does not exist."
fi

# Specific Plugin Sources:
source /usr/share/doc/find-the-command/ftc.zsh noupdate quiet
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
