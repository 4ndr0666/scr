#!/bin/bash
# shellcheck disable=all

# Auto escalate to root
if [ "$(id -u)" -ne 0 ]; then
    echo "Attempting to escalate to root..."
    sudo "$0" "$@"
    exit $?
fi

# Variables
grub_cfg_path="/boot/grub/grub.cfg"
custom_entry_path="/etc/grub.d/40_custom"
entry_identifier="Garuda Hyprland" # Unique identifier for the custom entry

# Prompt for the ISO path
read -p "Enter the path to the ISO file (e.g., /boot/isos/garuda-hyprland.iso): " iso_path

# Check and create grub.cfg and 40_custom if they do not exist
if [ ! -f "${grub_cfg_path}" ]; then
    echo "grub.cfg not found. Creating..."
    touch "${grub_cfg_path}"
fi

if [ ! -f "${custom_entry_path}" ]; then
    echo "40_custom not found. Creating..."
    cat << 'EOF' > "${custom_entry_path}"
#!/bin/sh
exec tail -n +3 $0
EOF
    chmod +x "${custom_entry_path}"
fi

# Check for existing menu entry to ensure idempotency
if ! grep -q "${entry_identifier}" "${custom_entry_path}"; then
    # Append custom menu entries to 40_custom if not already present
    cat << EOF >> "${custom_entry_path}"

# Custom menu entries
menuentry "${entry_identifier}" {
    iso_path="${iso_path}"
    export iso_path
    search --set=root --file \$iso_path
    probe -u \$root --set=rootuuid
    export rootuuid
    loopback loop \$iso_path
    root=(loop)
    configfile /boot/grub/loopback.cfg
    loopback --delete loop
}

menuentry 'Reboot Computer' --class restart {
    reboot
}

menuentry 'Shutdown Computer' --class shutdown {
    halt
}
EOF
    echo "Custom GRUB entries added."
else
    echo "Custom GRUB entry '${entry_identifier}' already exists. No changes made."
fi

# Update GRUB configuration
echo "Updating GRUB configuration..."
grub-mkconfig -o "${grub_cfg_path}"

echo "GRUB configuration has been updated. Please reboot to see the changes."
