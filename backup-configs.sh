#! /bin/bash

backup_dir="/home/andro/Documents/Backups/backups-configs"
base_name="configs-$(date +%Y-%m-%d@%H:%M:%S)"

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

for path in "${paths[@]}"; do
    tar -rpf "${backup_dir}/${base_name}.tar" -C / "${path#/}"
done
gzip "${backup_dir}/${base_name}.tar"
 
