#!/bin/sh

# Installation script for YTDL utility project
# Creates all required files and ensures proper configuration

# Define directories
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
CONFIG_DIR="$HOME/.config/zsh"

# Create directories if they don't exist
mkdir -p "$BIN_DIR" "$APP_DIR" "$CONFIG_DIR"

echo "Directories created or already exist:"
echo "  - $BIN_DIR"
echo "  - $APP_DIR"
echo "  - $CONFIG_DIR"

# Install dmenuhandler
cat > "$BIN_DIR/dmenuhandler" << 'EOF'
#!/bin/sh

# Log file for debugging
LOGFILE=~/dmenuhandler.log

# Input feed
feed="${1:-$(true | dmenu -p 'Paste URL or file path')}"

echo "Feed received: $feed" >> "$LOGFILE"

# Display dmenu options
choice=$(printf "Copy URL\nView Image\nSet Background\nOpen as PDF\nOpen in Browser\nOpen in Lynx\nEdit in Vim\nPlay in MPV\nDownload\nQueue YTDL\nQueue YTDLC\nYTF" | dmenu -i -p "Choose action:")

echo "Choice selected: $choice" >> "$LOGFILE"

case "$choice" in
    "Copy URL")
        echo "$feed" | wl-copy
        ;;
    "View Image")
        tmpfile="/tmp/$(basename "$feed" | sed "s/%20/ /g")"
        curl -sL "$feed" > "$tmpfile" && nsxiv -a "$tmpfile" >> "$LOGFILE" 2>&1
        ;;
    "Set Background")
        sed -i -e "s|WALLPAPER=.*|WALLPAPER='$feed'|g" "/home/andro/.config/wayfire/scripts/wallpaper" >> "$LOGFILE" 2>&1
        ;;
    "Open as PDF")
        tmpfile="/tmp/$(basename "$feed" | sed "s/%20/ /g")"
        curl -sL "$feed" > "$tmpfile" && zathura "$tmpfile" >> "$LOGFILE" 2>&1
        ;;
    "Open in Browser")
        setsid -f "$BROWSER" "$feed" >> "$LOGFILE" 2>&1
        ;;
    "Open in Lynx")
        lynx "$feed" >> "$LOGFILE" 2>&1
        ;;
    "Edit in Vim")
        tmpfile="/tmp/$(basename "$feed" | sed "s/%20/ /g")"
        curl -sL "$feed" > "$tmpfile" && setsid -f "$TERMINAL" -e "$EDITOR" "$tmpfile" >> "$LOGFILE" 2>&1
        ;;
    "Play in MPV")
        setsid -f mpv -quiet "$feed" >> "$LOGFILE" 2>&1
        ;;
    "Download")
        qndl "$feed" 'curl -LO' >> "$LOGFILE" 2>&1
        ;;
    "Queue YTDL")
        setsid -f "$TERMINAL" -e zsh -ic "ytdl \"$feed\"; echo 'Press Enter to close the terminal.'; read" >> "$LOGFILE" 2>&1
        ;;
    "Queue YTDLC")
        setsid -f "$TERMINAL" -e zsh -ic "ytdlc \"$feed\"; echo 'Press Enter to close the terminal.'; read" >> "$LOGFILE" 2>&1
        ;;
    "YTF")
        setsid -f "$TERMINAL" -e zsh -ic "
            echo 'Listing formats for $feed:' && \
            ytf \"$feed\" && \
            echo 'Enter the desired format ID: ' && \
            read fmt && \
            echo 'Choose YTDL or YTDLC for download: ' && \
            echo '1) YTDL' && \
            echo '2) YTDLC' && \
            read choice && \
            case \"\$choice\" in
                1) ytdl \"$feed\" -f \"\$fmt\" ;;
                2) ytdlc \"$feed\" -f \"\$fmt\" ;;
                *) echo 'Invalid choice. Exiting.' ;;
            esac
            echo 'Press Enter to close the terminal.'
            read
        " >> "$LOGFILE" 2>&1
        ;;
    *)
        echo "Invalid choice or no action taken." >> "$LOGFILE"
        ;;
esac
EOF

chmod +x "$BIN_DIR/dmenuhandler"
echo "Installed: dmenuhandler"

# Install ytdl.zsh
cat > "$CONFIG_DIR/ytdl.zsh" << 'EOF'
<Insert full ytdl.zsh content shared earlier>
EOF

chmod +x "$CONFIG_DIR/ytdl.zsh"
echo "Installed: ytdl.zsh"

# Install ytdl-handler.sh
cat > "$BIN_DIR/ytdl-handler.sh" << 'EOF'
#!/bin/sh

# Log file for debugging
LOGFILE=~/dmenuhandler.log
echo "Script called at $(date)" >> "$LOGFILE"
echo "Feed received: $1" >> "$LOGFILE"

# Check if the argument is valid
if [ -z "$1" ] || [ "$1" = "%u" ]; then
    echo "Error: No valid URL provided. Exiting." >> "$LOGFILE"
    exit 1
fi

# Remove the `ytdl://` prefix and decode the URL
feed=$(echo "$1" | sed 's|^ytdl://||' | python3 -c "import sys, urllib.parse as ul; print(ul.unquote(sys.stdin.read().strip()))")
echo "Final feed processed: $feed" >> "$LOGFILE"

# Call dmenuhandler with the processed URL
exec dmenuhandler "$feed"
EOF

chmod +x "$BIN_DIR/ytdl-handler.sh"
echo "Installed: ytdl-handler.sh"

# Install ytdl.desktop
cat > "$APP_DIR/ytdl.desktop" << 'EOF'
[Desktop Entry]
Name=YTDL Handler
Exec=/home/andro/.local/bin/ytdl-handler.sh %u
Type=Application
MimeType=x-scheme-handler/ytdl;
NoDisplay=true
EOF

xdg-mime default ytdl.desktop x-scheme-handler/ytdl
echo "Installed: ytdl.desktop and registered MIME type"

# Install bookmarklet
cat > "$BIN_DIR/bookmarklet" << 'EOF'
javascript:(function(){const url=encodeURIComponent(window.location.href);window.location=`ytdl://${url}`})();
EOF

chmod +x "$BIN_DIR/bookmarklet"
echo "Installed: bookmarklet"

echo "Installation complete!"
echo "The following files were installed:"
echo "  - $BIN_DIR/dmenuhandler"
echo "  - $CONFIG_DIR/ytdl.zsh"
echo "  - $BIN_DIR/ytdl-handler.sh"
echo "  - $APP_DIR/ytdl.desktop"
echo "  - $BIN_DIR/bookmarklet"
