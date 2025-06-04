# shellcheck disable=all
#######################################################################
######################## Customization Options ########################
#######################################################################

# User interface of choice (cli, dialog)
export USER_INTERFACE='cli'

# Editor used to modify settings (vim, nano, micro)
# NOTE: EDITOR environment variable takes precedence
export SETTINGS_EDITOR='nvim'

# Country to generate the mirror list for
export MIRRORLIST_COUNTRY='United States'

#######################################################################
####################### AUR Helper Configuration ######################
#######################################################################

# Define the AUR helper to use (trizen, yay, or others)
export AUR_HELPER="yay"

# Directory where currently installed AUR packages are stored
export AUR_DIR="/home/build"

# Decide whether or not to upgrade AUR Packages while rebuilding
export AUR_UPGRADE=false

# Whitelist of AUR packages that should not show up as dropped packages
# NOTE: AUR packages in the AUR_DIR will automatically be whitelisted
export AUR_WHITELIST=()


#######################################################################
####################### Backup / Restore Options ######################
#######################################################################

# Where to store the system backup
export BACKUP_LOCATION="/Nas/Backups/4ndr0update/"


# Directories to exclude from backup/restore process
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
export SYMLINKS_CHECK=("/etc" "/home" "/opt" "/srv" "/usr")
