#!/bin/bash
# ==============================================================================
# DietPi First-Boot Custom Script (Automation_Custom_Script.sh)
# Target OS: DietPi Bookworm ARMv8 (64-bit) for Raspberry Pi 4
# Purpose: Headless automation, configuration, and secure integration of Homer,
#          Portainer, Shell In A Box, File Browser, Jellyfin, and Fail2Ban.
# Idempotency: Fully supported. Can be run multiple times safely.
#
# Revision notes (gap-mitigation pass against prior stable version):
#   - Step 6 (webserver restart) now also recognises Apache. AUTO_SETUP_WEB_SERVER_INDEX
#     in dietpi.txt has been corrected to -2 (Lighttpd) in this revision, so Apache
#     should no longer be the one actually installed — but the check is kept
#     defensive/superset so this script still works correctly if that preference
#     is ever changed back, or if Apache was already present on the system from
#     a prior manual install (dietpi-software auto-detects and reuses it).
#   - Step 5 (File Browser) now explicitly sets the service port to 8084 (the
#     current DietPi-shipped default) instead of assuming a fixed 8082, and does
#     so idempotently via the filebrowser CLI rather than relying on whatever the
#     package's own default happens to be release to release.
#   - Step 2's Fail2Ban block no longer defines a "shellinabox" jail using the
#     sshd log filter against /var/log/auth.log. Shell In A Box's login flow does
#     not reliably attribute failed attempts to a source IP in a form the sshd
#     filter can match, so that jail was silently inert (reported "active" via
#     fail2ban-client but never actually banning anything). It has been replaced
#     with a real, working protection at the iptables layer: a per-source-IP new-
#     connection rate limit on TCP/4200, persisted across reboots. The sshd jail
#     itself is untouched and continues to function as before.
# ==============================================================================

# Ensure logs are kept in first-boot setup log directory
LOG_FILE="/var/log/dietpi_custom_setup.log"
exec > >(tee -i "$LOG_FILE") 2>&1

echo "======================================================================"
echo "[DietPi-Automation] Starting Automation_Custom_Script.sh"
echo "Timestamp: $(date -u)"
echo "======================================================================"

# 1. Wait for stable network connection (Maximum 120 seconds)
echo "[DietPi-Automation] Verifying stable internet connectivity..."
NETWORK_SUCCESS=0
for i in {1..24}; do
  if ping -c 1 -W 5 9.9.9.9 &>/dev/null; then
    echo "[DietPi-Automation] Stable Internet Connection Detected!"
    NETWORK_SUCCESS=1
    break
  fi
  echo "Waiting for Network... ($i/24)"
  sleep 5
done

if [ "$NETWORK_SUCCESS" -ne 1 ]; then
  echo "[WARNING] System booted without external network! Skipping external integrations."
fi

# 2. Configure Fail2Ban to protect SSH immediately, and rate-limit Shell In A Box
echo "[DietPi-Automation] Hardening system with Fail2Ban configurations..."
cat << 'EOF' > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
EOF

systemctl restart fail2ban &>/dev/null
echo "[DietPi-Automation] Fail2Ban configured (SSH jail) and restarted."

echo "[DietPi-Automation] Applying connection rate-limit for Shell In A Box (port 4200)..."
# NB: Shell In A Box's login flow does not reliably surface a per-source IP in
# /var/log/auth.log in a form Fail2Ban's sshd filter can match, so log-based
# banning is not a functional protection here. iptables new-connection rate
# limiting protects the same attack surface (credential brute-forcing over the
# exposed port) without depending on an attribution the application doesn't
# provide.
IPT_CHAIN_MARK="shellinabox"
if ! iptables -C INPUT -p tcp --dport 4200 -m conntrack --ctstate NEW -m recent --set --name "$IPT_CHAIN_MARK" &>/dev/null; then
  iptables -A INPUT -p tcp --dport 4200 -m conntrack --ctstate NEW -m recent --set --name "$IPT_CHAIN_MARK"
fi
if ! iptables -C INPUT -p tcp --dport 4200 -m conntrack --ctstate NEW -m recent --update --seconds 600 --hitcount 6 --name "$IPT_CHAIN_MARK" -j DROP &>/dev/null; then
  iptables -A INPUT -p tcp --dport 4200 -m conntrack --ctstate NEW -m recent --update --seconds 600 --hitcount 6 --name "$IPT_CHAIN_MARK" -j DROP
fi
echo "[DietPi-Automation] Shell In A Box: new connections capped at 6 per source IP per 10 minutes."

# Persist iptables rules across reboots, since this custom script only runs on first boot.
if command -v netfilter-persistent &>/dev/null; then
  netfilter-persistent save &>/dev/null
  echo "[DietPi-Automation] iptables rules saved via netfilter-persistent."
elif [ "$NETWORK_SUCCESS" -eq 1 ]; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent &>/dev/null
  if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save &>/dev/null
    echo "[DietPi-Automation] iptables-persistent installed and rules saved."
  else
    echo "[WARNING] Could not install iptables-persistent; the port 4200 rate-limit will not survive a reboot until saved manually."
  fi
else
  echo "[WARNING] No network available to install iptables-persistent; the port 4200 rate-limit will not survive a reboot until saved manually."
fi

# 3. Headless Portainer Auto-Initialization and App-Template configuration
echo "[DietPi-Automation] Initializing Portainer Admin Profile..."
PORTAINER_URL="http://localhost:9000"
PORTAINER_READY=0

# Loop to wait for Portainer to be fully active (Max 3 minutes)
for i in {1..36}; do
  if curl -s -f "$PORTAINER_URL/api/status" &>/dev/null; then
    echo "[DietPi-Automation] Portainer API is responsive!"
    PORTAINER_READY=1
    break
  fi
  echo "Waiting for Portainer container services... ($i/36)"
  sleep 5
done

if [ "$PORTAINER_READY" -eq 1 ]; then
  # Portainer requires password length >= 12 characters. Pre-defining our secure admin credentials.
  ADMIN_PASS="androandro123"
  
  # Trigger the admin user initialization POST call (idempotent, fails gracefully if already initialized)
  INIT_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"admin\",\"Password\":\"$ADMIN_PASS\"}" \
    "$PORTAINER_URL/api/users/admin/init")
  
  # Get JWT auth token
  JWT_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"Username\":\"admin\",\"Password\":\"$ADMIN_PASS\"}" \
    "$PORTAINER_URL/api/auth")
  
  JWT_TOKEN=$(echo "$JWT_RESPONSE" | grep -oP '"jwt":"\K[^"]+')
  
  if [ -n "$JWT_TOKEN" ]; then
    echo "[DietPi-Automation] Successfully authenticated with Portainer API!"
    
    # Configure Portainer settings to use the custom ARM64 templates URL automatically on first boot
    TEMPLATE_URL="https://raw.githubusercontent.com/pi-hosted/pi-hosted/master/template/portainer-v3-arm64.json"
    UPDATE_SETTINGS=$(curl -s -X PUT \
      -H "Authorization: Bearer $JWT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"templatesURL\":\"$TEMPLATE_URL\"}" \
      "$PORTAINER_URL/api/settings")
      
    if echo "$UPDATE_SETTINGS" | grep -q "templatesURL"; then
      echo "[DietPi-Automation] Portainer successfully configured with custom template URL!"
    else
      echo "[ERROR] Portainer API update settings failed: $UPDATE_SETTINGS"
    fi
  else
    echo "[WARNING] Portainer may have been already initialized. Response was: $INIT_RESPONSE"
  fi
else
  echo "[ERROR] Portainer services did not start up in time. Skipping API configurations."
fi

# 4. Homer Dashboard: Build a stunning custom config.yml automatically
echo "[DietPi-Automation] Configuring Homer Dashboard Page Assets..."
HOMER_DIR="/var/www/homer"

# Make sure Homer assets folder structure exists
mkdir -p "$HOMER_DIR/assets"

cat << 'EOF' > "$HOMER_DIR/assets/config.yml"
# Homer Dashboard Configurations - Custom Headless Build
title: "Raspberry Pi Server"
subtitle: "Pi-Hosted Homelab Dashboard"
logo: "assets/logo.png"

header: true
footer: '<p>System built with DietPi and Docker | Created with ♥</p>'

columns: "4"
connectivity_checker: true

colors:
  light:
    highlight-primary: "#3367d6"
    highlight-secondary: "#4285f4"
    background: "#f5f5f5"
    card-background: "#ffffff"
    text: "#2c3e50"
    text-header: "#ffffff"
  dark:
    highlight-primary: "#4285f4"
    highlight-secondary: "#3367d6"
    background: "#121212"
    card-background: "#1e1e1e"
    text: "#eaeaea"
    text-header: "#ffffff"

services:
  - name: "Core Infrastructure"
    icon: "fa-solid fa-server"
    items:
      - name: "Portainer"
        icon: "fa-brands fa-docker"
        subtitle: "Docker GUI Container Manager"
        url: "http://192.168.0.100:9000"
        target: "_blank"
      - name: "Shell In A Box"
        icon: "fa-solid fa-terminal"
        subtitle: "Secure Web Terminal / SSH Console"
        url: "https://192.168.0.100:4200"
        target: "_blank"
      - name: "File Browser"
        icon: "fa-solid fa-folder-open"
        subtitle: "Web-based file management"
        url: "http://192.168.0.100:8084"
        target: "_blank"

  - name: "Media Services"
    icon: "fa-solid fa-photo-film"
    items:
      - name: "Jellyfin"
        icon: "fa-solid fa-play"
        subtitle: "Headless Media & Streaming Platform"
        url: "http://192.168.0.100:8096"
        target: "_blank"
EOF

# Correct directory permissions to allow default webservers to serve static assets properly
chown -R www-data:www-data "$HOMER_DIR"
chmod -R 755 "$HOMER_DIR"
echo "[DietPi-Automation] Homer dashboard config.yml template generated."

# 5. File Browser Service: explicit, idempotent port configuration and enablement
echo "[DietPi-Automation] Configuring File Browser port bindings..."
# Prior versions of this script assumed a fixed port of 8082 without setting it
# explicitly, i.e. it relied on whatever the installed filebrowser package's
# own default happened to be. Current DietPi-shipped File Browser defaults to
# 8084. Rather than continue to assume any particular default, the port is
# now set explicitly and idempotently via the filebrowser CLI, which requires
# the service to be stopped while the change is applied.
FILEBROWSER_BIN="/opt/filebrowser/filebrowser"
FILEBROWSER_DB="/mnt/dietpi_userdata/filebrowser/filebrowser.db"
FILEBROWSER_PORT=8084

if [ -x "$FILEBROWSER_BIN" ] && [ -f "$FILEBROWSER_DB" ]; then
  systemctl stop filebrowser &>/dev/null
  "$FILEBROWSER_BIN" -d "$FILEBROWSER_DB" config set --port "$FILEBROWSER_PORT" &>/dev/null
  systemctl enable --now filebrowser &>/dev/null
  echo "[DietPi-Automation] File Browser port explicitly set to $FILEBROWSER_PORT and service enabled."
else
  echo "[WARNING] File Browser binary or database not found at expected paths ($FILEBROWSER_BIN / $FILEBROWSER_DB)."
  echo "[WARNING] Skipping explicit port configuration; enabling service with its installed defaults instead."
  systemctl enable --now filebrowser &>/dev/null
fi

# 6. Verify and restart the active webserver to serve Homer
if systemctl is-active lighttpd &>/dev/null; then
  systemctl restart lighttpd &>/dev/null
  echo "[DietPi-Automation] Lighttpd web server restarted to apply config changes."
elif systemctl is-active nginx &>/dev/null; then
  systemctl restart nginx &>/dev/null
  echo "[DietPi-Automation] Nginx web server restarted to apply config changes."
elif systemctl is-active apache2 &>/dev/null; then
  systemctl restart apache2 &>/dev/null
  echo "[DietPi-Automation] Apache web server restarted to apply config changes."
else
  echo "[WARNING] No active recognized webserver (Lighttpd/Nginx/Apache) was detected. Homer will not be reachable until a webserver is installed and running."
fi

echo "======================================================================"
echo "[DietPi-Automation] Headless Post-Script Setup Completed Successfully!"
echo "Timestamp: $(date -u)"
echo "======================================================================"
exit 0
