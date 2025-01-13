#!/bin/bash

# Variables
SOURCE="/dev/sda"
TARGET="/dev/sdb"
LOG="/root/ddrescue.log"

# Ensure unmounted
sudo umount /mnt/source
sudo umount /mnt/target

# Clone with initial pass
sudo ddrescue -f -n $SOURCE $TARGET $LOG

# Retry bad sectors
sudo ddrescue -d -f -r3 $SOURCE $TARGET $LOG

# Verify
sudo fsck -f ${TARGET}1