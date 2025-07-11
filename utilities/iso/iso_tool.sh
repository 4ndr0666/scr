#!/bin/bash
# shellcheck disable=all

# Variables
WORKDIR="/home/username/archlive"
PROFILE="releng"
ISO_NAME="arch-custom.iso"

# Prepare the working directory
mkdir -p $WORKDIR
cp -r /usr/share/archiso/configs/$PROFILE/* $WORKDIR

# Customize the profile as needed
# For example, edit $WORKDIR/packages.x86_64 to include additional packages

# Build the ISO
mkarchiso -v -w $WORKDIR -o $WORKDIR $WORKDIR

# Rename the output ISO
mv $WORKDIR/out/$PROFILE-*.iso $WORKDIR/out/$ISO_NAME
