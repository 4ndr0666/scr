#!/bin/bash

# Update system packages
sudo pacman -Syyu

# Install Ruby dependencies
sudo pacman -S --needed base-devel libffi libyaml openssl zlib --noconfirm

# Install Ruby using rbenv and add PATH (zsh or bash)
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(rbenv init -)"' >> ~/.zshrc
source ~/.zshrc

# Enter Ruby version here
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
rbenv install <desired_ruby_version>
rbenv global <desired_ruby_version>

# Install gems
gem update --system
gem install bundler

# Install Node.js and npm
sudo pacman -S nodejs npm --noconfirm --overwrite="*" 

# Install Rust using rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Add cargo to PATH (zsh or bash)
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Update Rust and cargo
rustup update

# Install topgrade
cargo install topgrade

# Run topgrade to update all packages
sudo topgrade

# Install mpm
pip install -U --use-pep517 --check-build-dependencies mpm --break-system-packages

# Update AUR packages using mpm
sudo mpm update

# If above fails
mpm -C /home/andro/.config/mpm/config.toml update -A

# Clean up
sudo pacman -Rns $(pacman -Qdtq)

echo "Installation and maintenance completed successfully!"

###################################################################
##Make sure to replace <desired_ruby_version> with the Ruby version you want to install (e.g., 2.7.4).
#
##Save the script to a file (e.g., maintain_arch_system.sh), make it executable (chmod +x maintain_arch_system.sh) and run it with sudo ./maintain_arch_system.sh. The script will update system packages, install Ruby, gems, Node.js,npm, Rust, topgrade, and mpm, and update them to the latest versions. It will also update AUR packages using mpm.
