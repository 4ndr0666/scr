#!/bin/bash

# Log a message with a timestamp
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# Untrack problematic files from LFS
untrack_problematic_files() {
    log_message "Untracking problematic files from LFS..."
    git lfs untrack "pkgs/hooks.tar.gz"
    git lfs untrack "config/wayfire/4ndr0666_wayfire.tar.gz"
    git lfs untrack ".config/mpv/Utils/mpv.conf_backup.tar.gz"
    git lfs untrack "config/openbox/scripts/ob-popup_backup.tar.gz"
    git lfs untrack "etc/skel/skel.tar.gz"
}

# Prune and clean up LFS objects
cleanup_lfs_objects() {
    log_message "Pruning and cleaning up LFS objects..."
    git lfs prune
    git lfs dedup
    git lfs fsck
}

# Track the files again
track_files_again() {
    log_message "Tracking files again..."
    git lfs track "pkgs/hooks.tar.gz"
    git lfs track "config/wayfire/4ndr0666_wayfire.tar.gz"
    git lfs track ".config/mpv/Utils/mpv.conf_backup.tar.gz"
    git lfs track "config/openbox/scripts/ob-popup_backup.tar.gz"
    git lfs track "etc/skel/skel.tar.gz"
}

# Add and commit changes
add_and_commit_changes() {
    log_message "Adding and committing changes..."
    git add .gitattributes
    git add "pkgs/hooks.tar.gz"
    git add "config/wayfire/4ndr0666_wayfire.tar.gz"
    git add ".config/mpv/Utils/mpv.conf_backup.tar.gz"
    git add "config/openbox/scripts/ob-popup_backup.tar.gz"
    git add "etc/skel/skel.tar.gz"
    git commit -m "Re-track problematic files with Git LFS"
}

# Force push all changes
force_push_all_changes() {
    log_message "Force pushing all changes to remote repository..."
    git push --force origin main
    git lfs push --all origin main
}

# Main execution
main() {
    log_message "Starting LFS cleanup and resolution script..."
    untrack_problematic_files
    cleanup_lfs_objects
    track_files_again
    add_and_commit_changes
    force_push_all_changes
    log_message "Completed LFS cleanup and resolution script."
}

# Run the main function
main
