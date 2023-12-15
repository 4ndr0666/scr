#!/bin/bash

# Define source and destination directories
src_dir="$HOME/.config/BraveSoftware/Brave-Browser"
dest_dir="/Nas/Nas/Brave_repo"

# Create backup
cp -r "$src_dir" "$dest_dir"
