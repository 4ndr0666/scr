# Utility Functions

# Copy Path to Clipboard
copypath() {
    # If no argument passed, use current directory
    local file="${1:-.}"

    # If argument is not an absolute path, prepend $PWD
    [[ $file = /* ]] || file="$PWD/$file"

    # Copy the absolute path without resolving symlinks
    print -n "${file:a}" | clipcopy || return 1

    echo "${(%):-"%B${file:a}%b copied to clipboard."}"
}

# Spellcheck Function
spell() {
    if ! command -v spellcheck &> /dev/null; then
        echo "Error: 'spellcheck' command not found. Please ensure it is located in ~/.local/bin."
        return 1
    fi

    if [ $# -eq 0 ]; then
        echo "❓ Usage: spell <word1> [word2]..."
        return 1
    fi

    for word in "$@"; do
        echo "Checking spelling for: $word"
        spellcheck "$word"
        echo # Add a newline for better readability between checks
    done
}

# Restart Waybar
restart_waybar() {
    killall -9 waybar &> /dev/null
    waybar </dev/null &>/dev/null &
}
