#!/bin/bash

# --- // Securely_add_ssh_key:
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa

# --- // Start_here:
cd $PWD

# --- // Command_loop:
for d in */ ; do
    echo "Processing directory $d"
    cd "$d"
    gh tidy
    cd ..
done
