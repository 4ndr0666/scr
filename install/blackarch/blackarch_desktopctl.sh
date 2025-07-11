#!/bin/bash
# shellcheck disable=all

# This script manages BlackArch Linux repositories and desktop entries.

# Dictionary for mapping package groups to desktop entry categories
declare -A group_to_category=(
  [blackarch-anti-forensic]="X-BlackArch-Anti-Forensic;"
  [blackarch-automation]="X-BlackArch-Automation;"
  # Add more mappings here
)

# Checks if required packages are installed
check_dependencies() {
  local dependencies=("pacman" "awk" "cut" "sed")
  for dependency in "${dependencies[@]}"; do
    if ! command -v "$dependency" &>/dev/null; then
      echo "Error: Required command $dependency is not installed."
      exit 1
    fi
  done
}

# Adds BlackArch Linux repositories to pacman.conf
add_repos() {
  local repo_entry="[blackarch]\nServer = https://www.mirrorservice.org/sites/blackarch.org/blackarch/\\\$repo/os/\\\$arch"
  if grep -q "\[blackarch\]" /etc/pacman.conf; then
    echo "BlackArch repository is already added."
  else
    echo -e "$repo_entry" | sudo tee -a /etc/pacman.conf
    sudo pacman -Sy
  fi
}

# Generates desktop entries for BlackArch Linux packages
generate_entries() {
  for package in $(pacman -Qqg blackarch); do
    pkginfo=$(pacman -Si "blackarch/$package" 2>/dev/null)
    if [ -z "$pkginfo" ]; then
      echo "Package info for $package not found."
      continue
    fi

    desc=$(echo "$pkginfo" | awk 'NR==4' | cut -d':' -f2 | sed 's/^ //g')
    groups=$(get_groups "$pkginfo")

    if [[ -f "/usr/share/applications/$package.desktop" ]] || [[ -z "$groups" ]]; then
      continue
    fi

    cat >"/usr/share/applications/ba-$package.desktop" <<EOF
[Desktop Entry]
Name=$package
Icon=utilities-terminal
Comment=$desc
TryExec=/usr/bin/$package
Exec=sh -c '/usr/bin/$package;\$SHELL'
StartupNotify=true
Terminal=true
Type=Application
Categories=$groups
EOF

    echo "Generated desktop entry for $package"
  done
}

# Removes desktop entries for BlackArch Linux packages
remove_entries() {
  read -p "Are you sure you want to remove all BlackArch desktop entries? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    for package in $(pacman -Qqg blackarch); do
      if [[ -f "/usr/share/applications/ba-$package.desktop" ]]; then
        rm -f "/usr/share/applications/ba-$package.desktop"
        echo "Removed desktop entry for $package"
      fi
    done
  fi
}

# Converts package groups to desktop entry categories
get_groups() {
  local pkginfo=$1
  local groups=$(echo "$pkginfo" | awk 'NR==8' | cut -d':' -f2)
  local category=""

  for group in $groups; do
    category+="${group_to_category[$group]}"
  done

  echo "$category"
}

# Main script logic
main() {
  check_dependencies

  case $1 in
    add)
      add_repos
      ;;
    gen)
      generate_entries
      ;;
    rem)
      remove_entries
      ;;
    *)
      echo "Usage: $0 [add|gen|rem]"
      exit 2
      ;;
  esac
}

# Run the script
main "$@"
