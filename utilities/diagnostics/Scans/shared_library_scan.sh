#!/bin/bash
# shellcheck disable=all

# Update the system
sudo pacman -Syu

# Check for conflicting packages
conflicting_packages=$(pacman -Qs "ffmpeg|mpv" | grep -E "^local/ffmpeg-git|^local/mpv-git" | awk '{print $1}')

if [ -n "$conflicting_packages" ]; then
    echo "Conflicting packages found:"
    echo "$conflicting_packages"
    echo "Removing conflicting packages..."
    sudo pacman -Rs $conflicting_packages
fi

# Install the required packages
sudo pacman -S ffmpeg mpv

# Check for dependency issues
dependencies=$(pacman -D --asdeps --print-format "%n" | grep -E "libavcodec|libplacebo|libxkbcommon")

if [ -n "$dependencies" ]; then
    echo "Resolving dependencies..."
    sudo pacman -S $dependencies
fi

echo "Dependency issues resolved. mpv and ffmpeg should now be installed correctly."
