#!/bin/zsh
# shellcheck disable=all

# Define variables
SERVICE_FILE="/etc/systemd/system/aria2.service"
USER_NAME="andro"
ARIA2_BIN="/usr/bin/aria2c"
ARIA2_CONF="/home/andro/.config/aria2/aria2.conf"

# Create the systemd service file
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Aria2c Download Manager
After=network.target
RequiresMountsFor=/sto2/Downloads/

[Service]
Type=simple
User=$USER_NAME
ExecStart=$ARIA2_BIN --conf-path=$ARIA2_CONF
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "Systemd service file for aria2 has been created at $SERVICE_FILE."

# Reload systemd daemon
sudo systemctl daemon-reload

# Enable and start aria2 service
sudo systemctl enable aria2
sudo systemctl start aria2

# Check the status of the aria2 service
sudo systemctl status aria2
