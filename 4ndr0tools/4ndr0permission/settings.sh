# =================== // Default Programs  //
# --- // UI (cli or dialog):
export USER_INTERFACE='cli'

# --- // Editor:
export SETTINGS_EDITOR='lite-xl'

# =================== // Exclusions //
# --- // Dirs to exclude:
export EXCLUDE=(
    "/23.1/*" "/dev/*" "/proc/*" "/sys/*" "/tmp/*" "/run/*"
    "/mnt/*" "/media/*" "/home/andro/Videos/*" "/home/andro/Pictures/*"
    "/home/andro/Downloads/*" "/Nas/*" "/storage/*" "/4ndr0/*" "/sto2/*"
    "/home/andro/.cache/*" "/home/andro/.borgmatic/*" "/home/andro/.mozilla/*"
    "/home/andro/dotnet/*" "/home/andro/Avatars/*" "/home/andro/ffmpeg_build/*"
    "/home/andro/ffmpeg_sources/*" "/home/andro/node_modules/*" "/home/andro/Overrides/*"
    "/home/andro/.npm/*" "/home/andro/.vim/*" "/home/andro/Dots~1~/*" "/home/andro/.gphoto/*"
    "/home/andro/.luarocks/*" "/home/andro/nuget/*" "/home/andro/mystiq_output/*"
    "/home/andro/.config/BraveSoftware/*"
)

# =================== // Backups //
# --- // Backup dir:
export BACKUP_LOCATION="/Nas/Backups/maint/"
