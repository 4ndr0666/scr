#######################################################################
######################## Customization Options ########################
#######################################################################

# User interface of choice (cli, dialog)
export USER_INTERFACE='cli'

# Editor used to modify settings (vim, nano, micro)
export SETTINGS_EDITOR='lite-xl'

# Country to generate the mirror list for
export MIRRORLIST_COUNTRY='United States'

#######################################################################
####################### AUR Helper Configuration ######################
#######################################################################

# Define the AUR helper to use (trizen, yay, or others)
export AUR_HELPER="trizen"

# Directory where currently installed AUR packages are stored
export AUR_DIR="/home/build"

# Option to decide whether or not to upgrade AUR Packages while rebuilding
export AUR_UPGRADE=true

# Whitelist of AUR packages that should not show up as dropped packages
export AUR_WHITELIST=("ffmpeg" "ffpmeg-full-git" "ffmpeg-git" "expressvpn")

# Example:
# export AUR_WHITELIST=("yay" "paru" "spotify")

#######################################################################
####################### Backup / Restore Options ######################
#######################################################################

# Location where system backup will be stored
# Make sure this directory exists before backup, or provide a warning.
export BACKUP_LOCATION="/Nas/Backups/maint/"

# Directories to exclude from the backup/restore process
# You may move this list to a separate file for easier maintenance.
export BACKUP_EXCLUDE=(
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

# Example:
# If you wish to use an external exclusion file:
# export BACKUP_EXCLUDE_FILE="$HOME/.backup_exclude_list"

#######################################################################
####################### System Cleaning Options #######################
#######################################################################

# Directories in which broken symlinks should be searched for
# Ensure that these directories are essential for cleaning and check permissions.
export SYMLINKS_CHECK=("/etc" "/home" "/opt" "/srv" "/usr")

# Example:
# Make sure that permissions for each directory are checked
# before running cleanup operations.