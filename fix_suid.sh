#!/bin/bash

# Check the ownership and permissions of the chrome-sandbox file
if [[ $(stat -c %U:%G /usr/share/*/chrome-sandbox) != "root:root" || $(stat -c %a /usr/share/*/chrome-sandbox) !=
"4755" ]]; then
    # Fix the ownership and permissions of the chrome-sandbox file
    sudo chown root:root /usr/share/*/chrome-sandbox
    sudo chmod 4755 /usr/share/*/chrome-sandbox
fi
