#!/bin/sh

## ARCHLINUX UPDATE HELPER ##

updateMirrorlist () {
  echo "Optimizing mirrorlist..."
  if ! pacman -Qs reflector > /dev/null; then 
    echo "Installing reflector"
    sudo pacman -Sy --noconfirm reflector
  fi
  sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
  sudo reflector -l 5 --verbose --sort rate --save /etc/pacman.d/mirrorlist
  sudo pacman -Syy --noconfirm
  echo "Mirrorlist updated"
}

updateSystem () {
  echo "Updating system..."
  sudo pacman -Syu --noconfirm --color=auto
  echo "System updated"
}

optimizePacman () {
  echo "Optimizing pacman..."
  sudo pacman -Rs $(pacman -Qtdq)
  sudo pacman-optimize
  echo "Pacman optimized"
}

updateMirrorlist
updateSystem
optimizePacman

echo "System updated and optimized."
