#! /bin/bash

backup_dir="$HOME/Documents/Backups/backups-configs"
base_name="configs-$(date +%Y-%m-%d@%H:%M:%S)"
archive="${backup_dir}/${base_name}.tar.gz"

[ ! -d "$backup_dir" ] && mkdir -p "$backup_dir"

paths=(
    "$HOME/.config"
    "$HOME/.gnupg"
    "$HOME/.bash"
    "$HOME/.zsh"
    "$HOME/.ssh"
    "$HOME/.tmux"
    "$HOME/.vim"
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.xinitrc"
    "$HOME/.xserverrc"
    "$HOME/.Xauthority"
    "$HOME/.pam_environment"
    "$HOME/.gitconfig"
    "$HOME/.xinitrc"
)

tar -czf "$archive" -C / "${paths[@]/#/.}"
