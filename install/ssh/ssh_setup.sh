#!/bin/sh
#
# SSH Matrix Manager
# End-to-end secure SSH configuration, key management, and recovery.
# Architecture: theworkpc (Client) <--> dietpi (Host) <--> AUR / GitHub
#
# Usage:
#   ./ssh_matrix_manager.sh [command] [args]
# Commands:
#   client [IP] - Configures the local workstation (requires target Pi IP/Hostname)
#   server      - Configures the remote host (locks down sshd, fetches GitHub keys)
#   recover     - Recovers a missing public key from the private key
#   audit       - Runs a system audit on the current machine
#

set -eu

# --- Configuration Constants ---
EMAIL="andro@theworkpc"
GITHUB_USER_URL="[https://github.com/4ndr0666.keys](https://github.com/4ndr0666.keys)"
AUR_HOST="aur.archlinux.org"

# --- Resource Reclamation (Rule 4.4) ---
# Use mktemp if available, fallback to a process-specific tmp path for POSIX compliance
TMP_DIR="$(mktemp -d 2>/dev/null \vert{}\vert{} printf "/tmp/ssh_matrix_\%s" "$$")"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

# ==============================================================================
# Unit: enforce_keypair
# ==============================================================================
enforce_keypair() {
    printf "[*] Enforcing Ed25519 keypair integrity...\n"

    ssh_dir="${HOME}/.ssh"
    priv_key="${ssh_dir}/id_ed25519"
    pub_key="${ssh_dir}/id_ed25519.pub"

    mkdir -p "${ssh_dir}/sockets"

    # If neither exists, generate fresh.
    if [ ! -f "$priv_key" ]; then
        printf "[+] No private key found. Generating new Ed25519 keypair...\n"
        ssh-keygen -t ed25519 -a 100 -C "$EMAIL" -f "$priv_key" -N ""
    fi

    # If private exists but public is missing, recover it (Rule 4.6 EAFP approach)
    if [ ! -f "$pub_key" ]; then
        printf "[!] Public key missing! Recovering from private key...\n"
        ssh-keygen -y -f "$priv_key" > "$pub_key"
        printf "[+] Recovery successful.\n"
    fi

    # Enforce strict deterministic permissions
    chmod 700 "$ssh_dir"
    chmod 700 "${ssh_dir}/sockets"
    chmod 600 "$priv_key"
    chmod 644 "$pub_key"

    printf "[*] Keypair validated.\n"
}

# ==============================================================================
# Unit: deploy_client_config
# ==============================================================================
deploy_client_config() {
    target_ip="$1"
    printf "[*] Deploying strict client configurations targeting %s...\n" "$target_ip"

    if [ "$(id -u)" -ne 0 ]; then
        printf "[!] Global config requires sudo. Escalating...\n"
        sudo sh "$0" _internal_global_client
    else
        _internal_global_client
    fi

    printf "[*] Writing user-specific SSH configuration (~/.ssh/config)...\n"
    cat << EOF > "${HOME}/.ssh/config"
# ~/.ssh/config (User-specific Client Config)

Host *
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_ed25519
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600

Host dietpi
    HostName ${target_ip}
    User dietpi
    HostKeyAlgorithms ssh-ed25519

Host ${AUR_HOST}
    User aur
    HostKeyAlgorithms ssh-ed25519
EOF
    chmod 600 "${HOME}/.ssh/config"

    printf "[*] Disabling local SSH server daemon to reduce attack surface...\n"
    sudo systemctl disable --now sshd || true
    sudo systemctl mask sshd || true
}

_internal_global_client() {
    # Executed as root via deploy_client_config
    printf "[*] Writing global system defaults (/etc/ssh/ssh_config)...\n"
    cat << 'EOF' > /etc/ssh/ssh_config
# /etc/ssh/ssh_config (System-wide Client Defaults)
# Include /etc/ssh/ssh_config.d/*.conf

Host *
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    GSSAPIAuthentication no
    StrictHostKeyChecking yes
    HashKnownHosts yes
    UpdateHostKeys yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    RekeyLimit 1G 1h
    ForwardAgent no
    ForwardX11 no
    Port 22
EOF
    chmod 644 /etc/ssh/ssh_config
}

# ==============================================================================
# Unit: deploy_aur_trust
# ==============================================================================
deploy_aur_trust() {
    printf "[*] Pinning AUR host key...\n"
    known_hosts="${HOME}/.ssh/known_hosts"

    touch "$known_hosts"

    # Check if host is already pinned to enforce idempotency
    if ! ssh-keygen -F "$AUR_HOST" >/dev/null 2>&1; then
        ssh-keyscan "$AUR_HOST" >> "$known_hosts" 2>/dev/null
        ssh-keygen -H -f "$known_hosts" >/dev/null 2>&1
        rm -f "${known_hosts}.old"
        printf "[+] AUR host key pinned and hashed.\n"
    else
        printf "[+] AUR host key is already pinned.\n"
    fi

    chmod 600 "$known_hosts"
}

# ==============================================================================
# Unit: deploy_server_config
# ==============================================================================
deploy_server_config() {
    if [ "$(id -u)" -ne 0 ]; then
        printf "[-] Server configuration requires root. Please run: sudo sh %s server\n" "$0"
        exit 1
    fi

    printf "[*] Hardening Server (dietpi)...\n"

    # 1. Fetch authorized keys from GitHub with hard timeout (Rule 4.2)
    target_user="dietpi"
    target_home="/home/${target_user}"
    auth_keys="${target_home}/.ssh/authorized_keys"

    printf "[*] Fetching canonical public keys from GitHub...\n"
    mkdir -p "${target_home}/.ssh"

    # Download to temporary isolated file first (Rule 4.1)
    if curl -fsSL --max-time 10 "$GITHUB_USER_URL" > "${TMP_DIR}/keys.pub"; then
        touch "$auth_keys"
        awk 'NF' "$auth_keys" "${TMP_DIR}/keys.pub" \vert{} sort -u > "${TMP_DIR}/keys.new"
        mv "${TMP_DIR}/keys.new" "$auth_keys"
        chown -R "${target_user}:${target_user}" "${target_home}/.ssh"
        chmod 700 "${target_home}/.ssh"
        chmod 600 "$auth_keys"
        printf "[+] Keys installed successfully.\n"
    else
        printf "[-] Failed to fetch keys from GitHub. Aborting server configuration.\n"
        exit 1
    fi

    # 2. Write hardened sshd_config
    printf "[*] Writing hardened /etc/ssh/sshd_config...\n"
    cat << 'EOF' > /etc/ssh/sshd_config
# /etc/ssh/sshd_config (Hardened Server)

Port 22
ListenAddress 0.0.0.0

PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
AuthorizedKeysFile .ssh/authorized_keys

HostKey /etc/ssh/ssh_host_ed25519_key

UsePAM yes
X11Forwarding no
PrintMotd no
TCPKeepAlive yes
ClientAliveInterval 300
ClientAliveCountMax 2

Subsystem sftp /usr/lib/ssh/sftp-server
EOF
    chmod 644 /etc/ssh/sshd_config

    # 3. Validate and Restart
    printf "[*] Validating SSHD syntax...\n"
    sshd -t

    printf "[*] Restarting SSH daemon...\n"
    systemctl restart ssh || systemctl restart sshd
    printf "[+] Server secured.\n"
}

# ==============================================================================
# Unit: audit_system
# ==============================================================================
audit_system() {
    printf "========================================\n"
    printf " SSH SYSTEM AUDIT\n"
    printf "========================================\n\n"

    printf "--- [ Local Key State ] ---\n"
    ls -la "${HOME}/.ssh"

    printf "\n--- [ Multiplexing Sockets ] ---\n"
    ls -la "${HOME}/.ssh/sockets" 2>/dev/null || printf "No sockets active.\n"

    printf "\n--- [ SSH Daemon Status ] ---\n"
    systemctl is-active sshd || systemctl is-active ssh || printf "sshd is completely disabled/masked.\n"

    printf "\n--- [ Listening Ports ] ---\n"
    ss -tnlp | grep ':22' || printf "No process listening on port 22.\n"

    printf "\n========================================\n"
}

# ==============================================================================
# Unit: orchestrator_main
# ==============================================================================
main() {
    cmd="${1:-}"

    case "$cmd" in
        client)
            target_ip="${2:-}"
            if [ -z "$target_ip" ]; then
                printf "Enter Target Pi IP or Hostname (e.g., 192.168.2.3): "
                read -r target_ip
            fi
            if [ -z "$target_ip" ]; then
                printf "[-] Error: Target IP or Hostname is required.\n"
                exit 1
            fi

            enforce_keypair
            deploy_client_config "$target_ip"
            deploy_aur_trust
            printf "\n[✔] Client workstation configured.\n"
            ;;
        server)
            deploy_server_config
            printf "\n[✔] Server host configured.\n"
            ;;
        recover)
            enforce_keypair
            ;;
        audit)
            audit_system
            ;;
        _internal_global_client)
            _internal_global_client
            ;;
        *)
            printf "Usage: %s {client <IP>|server|recover|audit}\n" "$0"
            exit 1
            ;;
    esac
}

main "$@"
