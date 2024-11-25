# ===================== // SETTINGS.SH //

# Safeguard for pkg_path function
if ! declare -f pkg_path > /dev/null; then
    echo "Error: pkg_path function is not defined. Ensure controller.sh is sourced before settings.sh."
    exit 1
fi

# --- // User Interface Selection: 'cli' or 'dialog'
export USER_INTERFACE='cli'  # Options: 'cli', 'dialog'

# --- // Preferred Editor for Settings Modification
export SETTINGS_EDITOR='nvim'  # Options: 'vim', 'nano', 'emacs', 'micro', 'nvim'

# --- // Backup Directory for Settings Backups
export BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/4ndr0service/backups/settings_backups/"

# --- // Log File Path
export LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0service/logs/service_optimization.log"

# --- // Additional Configurations (Template Placeholders)
# Add any additional settings below as needed. These can be managed through the settings UI.

# ======================================= // END SETTINGS.SH //
