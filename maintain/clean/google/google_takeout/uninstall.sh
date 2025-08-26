#!/usr/bin/env bash
# Author: 4ndr0666
# ==================== // UNINSTALL.SH //
## Description: This is a simple uninstaller for 
#  the google takeout setup; itll clean up all 
#  the leftover bullshit.
# --------------------------------------------

# stop and disable all services
systemctl stop takeout-organizer.timer
systemctl stop takeout-organizer.service
systemctl stop gdrive-mount.service
systemctl disable takeout-organizer.timer
systemctl disable takeout-organizer.service
systemctl disable gdrive-mount.service
  
# erase service files
rm -f /etc/systemd/system/takeout-organizer.service
rm -f /etc/systemd/system/takeout-organizer.timer
rm -f /etc/systemd/system/gdrive-mount.service

# purge system packages
apt-get purge --autoremove -y rclone fuse jdupes
   
# purge python packages 
pip3 uninstall -y PyDrive2 tqdm
   
# remove all artifacts
 rm -rf /opt/google_takeout_organizer

# restart daemon
systemctl daemon-reload
systemctl reset-failed

