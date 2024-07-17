#!/bin/bash

#find ~/.local/share/Trash/files/ -type f -mtime +1 -exec rm {} \; && find /run/media/$USER/*/.Trash-*/files/ -type f -mtime +1 -exec rm {} \;
fc-cache -f -v
journalctl --vacuum-time=3d;
rm -rf ~/.cache/opera/Cache; 
rm -rf ~/.cache/falkon/default/Cache; 
rm -rf ~/.cache/mozilla/firefox/*/cache2/entries; 
rm -rf ~/.cache/thumbnails/large; 
rm -rf ~/.cache/thumbnails/normal; 
rm -rf ~/.cache/google-chrome;
rm -rf ~/.cache/BraveSoftware/Brave-Browser;
mkdir -p ~/.cache/opera/Cache; 
mkdir -p ~/.cache/falkon/default/Cache; 
mkdir -p ~/.cache/mozilla/firefox/*/cache2/entries; 
mkdir -p ~/.cache/thumbnails/large; 
mkdir -p ~/.cache/thumbnails/normal



notify-send -i "garuda" 'Clear cache' 'Cache cleared'
