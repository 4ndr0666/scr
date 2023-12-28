#!/bin/bash

# Check if required packages are installed
check_dependencies() {
  local dependencies=("pacman" "awk" "cut" "sed")
  for dependency in "${dependencies[@]}"; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      echo "Error: $dependency is not installed. Please install it and try again."
      exit 1
    fi
  done
}

# Add BlackArch Linux repositories to pacman.conf
add_repos() {
  echo "[blackarch]" | sudo tee -a /etc/pacman.conf
  echo "Server = https://www.mirrorservice.org/sites/blackarch.org/blackarch/\$repo/os/\$arch" | sudo tee -a /etc/pacman.conf
  sudo pacman -Sy
}

# Generate desktop entries for BlackArch Linux packages
generate_entries() {
  for package in $(pacman -Qqg blackarch); do
    pkginfo=$(pacman -Si "blackarch/$package" 2>/dev/null)
    package=$(echo "$pkginfo" | awk 'NR==2' | cut -d':' -f 2 | sed 's/^ //g')
    desc=$(echo "$pkginfo" | awk 'NR==4' | cut -d':' -f 2 | sed 's/^ //g')
    groups=$(get_groups "$pkginfo")

    if [[ -f "/usr/share/applications/$package.desktop" ]]; then
      continue
    fi

    if [[ ! $groups ]]; then
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

# Remove desktop entries for BlackArch Linux packages
remove_entries() {
  for package in $(pacman -Qqg blackarch); do
    if [[ -f "/usr/share/applications/ba-$package.desktop" ]]; then
      rm -f "/usr/share/applications/ba-$package.desktop"
      echo "Removed desktop entry for $package"
    fi
  done
}

# Extract package groups and convert them into categories
get_groups() {
  local pkginfo=$1
  local groups=$(echo "$pkginfo" | awk 'NR==8' | cut -d':' -f 2)
  local category=""
  for group in $groups; do
    case "$group" in
      blackarch-anti-forensic)
        category="$category X-BlackArch-Anti-Forensic;"
        ;;
      blackarch-automation)
        category="$category X-BlackArch-Automation;"
        ;;
      # Add more group cases here
    esac
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
