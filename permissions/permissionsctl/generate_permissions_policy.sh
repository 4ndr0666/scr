#!/usr/bin/env bash

# Script to generate permissions_policy.yaml based on default package permissions

OUTPUT_FILE="/etc/permissions_policy.yaml"

echo "directories:" > "$OUTPUT_FILE"
echo "files:" >> "$OUTPUT_FILE"

# Iterate over all installed packages
packages=$(pacman -Qq)

for pkg in $packages; do
    # Get detailed file info from the package database
    pacman -Qipl "$pkg" | awk '
        BEGIN { section = ""; }
        /^PACKAGE/ { next; }
        /^Name/ { next; }
        /^Version/ { next; }
        /^Description/ { next; }
        /^Architecture/ { next; }
        /^URL/ { next; }
        /^Licenses/ { next; }
        /^Groups/ { next; }
        /^Provides/ { next; }
        /^Depends On/ { next; }
        /^Optional Deps/ { next; }
        /^Required By/ { next; }
        /^Optional For/ { next; }
        /^Conflicts With/ { next; }
        /^Replaces/ { next; }
        /^Installed Size/ { next; }
        /^Packager/ { next; }
        /^Build Date/ { next; }
        /^Install Date/ { next; }
        /^Install Reason/ { next; }
        /^Install Script/ { next; }
        /^Validated By/ { next; }
        /^Files/ { section = "files"; next; }
        section == "files" && NF > 0 {
            perms = $1
            owner = $2
            group = $3
            path = substr($0, index($0,$4))
            if (substr(perms,1,1) == "d") {
                print "  - path: \"" path "\""
                print "    owner: \"" owner "\""
                print "    group: \"" group "\""
                print "    permissions: \"" substr(perms,2) "\""
            } else {
                print "  - path: \"" path "\""
                print "    owner: \"" owner "\""
                print "    group: \"" group "\""
                print "    permissions: \"" substr(perms,2) "\""
            }
        }
    ' >> "$OUTPUT_FILE"
done

echo "Permissions policy generated at $OUTPUT_FILE"
