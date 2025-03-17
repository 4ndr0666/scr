#!/usr/bin/env bash
set -euo pipefail

# ================== // INSTALL_ETH_RENAME_SERVICE.SH //

## Privileges

if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges. Please enter your password to continue."
    exec sudo "$0" "$@"
fi
echo "💀WARNING💀 - you are now operating as root..."
sleep 2

## Cyan highlight variables (for success messages)
CYAN='\033[0;36m'
RESET='\033[0m'

## Constants

TARGET_MAC="74:27:EA:66:76:46"
TARGET_IF="enp2s0"
RENAME_SCRIPT="/usr/local/bin/rename_eth.sh"
UDEV_RULE="/etc/udev/rules.d/70-custom-network.rules"
SYSTEMD_SERVICE="/etc/systemd/system/rename-eth.service"
echo "🔧 Starting Ethernet Device Renaming Installation..."

## Rename_eth.sh

echo "📄 Creating rename_eth.sh script at ${RENAME_SCRIPT}..."
sudo tee "${RENAME_SCRIPT}" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail

TARGET_MAC="${TARGET_MAC}"
TARGET_IF="${TARGET_IF}"

CURRENT_IF="\$(ip -o link | awk -v mac="\$TARGET_MAC" 'tolower(\$0) ~ tolower(mac) {print \$2}' | sed 's/://')"

if [ -z "\$CURRENT_IF" ]; then
    echo "❌ Ethernet iface with MAC \$TARGET_MAC not found."
    exit 1
fi

if [ "\$CURRENT_IF" != "\$TARGET_IF" ]; then
    echo "🔄 Renaming iface from \$CURRENT_IF → \$TARGET_IF"
    ip link set "\$CURRENT_IF" down
    ip link set "\$CURRENT_IF" name "\$TARGET_IF"
    ip link set "\$TARGET_IF" up
else
    echo "✔️ Iface dev already named \$TARGET_IF"
fi
EOF

sudo chmod +x "${RENAME_SCRIPT}"
echo -e "${CYAN}✅ Service script created successfully.${RESET}"

## Udev rule

echo "📄 Creating Udev rule at ${UDEV_RULE}..."
sudo tee "${UDEV_RULE}" >/dev/null <<EOF
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="${TARGET_MAC}", NAME="${TARGET_IF}"
EOF

echo -e "${CYAN}✅ Udev rule created successfully.${RESET}"

## Systemd Service

echo "📄 Creating systemd service file ${SYSTEMD_SERVICE}..."
sudo tee "${SYSTEMD_SERVICE}" >/dev/null <<EOF
[Unit]
Description=Ethernet Interface Rename
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
ExecStart=${RENAME_SCRIPT}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo -e "${CYAN}✅ Systemd service installed.${RESET}"

# 4. Reload Systemd, Udev, and Enable Service
echo "🔄 Reloading Udev rules and Systemd daemon..."
sudo udevadm control --reload
sudo udevadm trigger --attr-match=address="${TARGET_MAC}"
sudo systemctl daemon-reload
sudo systemctl enable --now rename-eth.service

echo -e "${CYAN}✅ Ethernet renaming service enabled and started.${RESET}"

# Final check
echo -e "${CYAN}Installation Complete! Current network ifaces:${RESET}"
ip link show "${TARGET_IF}"
