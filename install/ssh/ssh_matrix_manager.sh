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
# Golden-Unit-Protocol v2 revision:
#   U8  Fixed corrupted Markdown URL in GITHUB_USER_URL (was breaking curl).
#   U2  Added SCRIPT_PATH guard before self-reinvocation; added AddKeysToAgent/SendEnv.
#   U3  Removed Port 22 from Host * block; added Ciphers/MACs/KexAlgorithms pinning.
#   U4  Added -T 10 timeout to ssh-keyscan (closes 4.2 hard-fail).
#   U5  Added AllowUsers, MaxAuthTries, LoginGraceTime, LogLevel; removed TCPKeepAlive.
#   U6  Added || true guards on systemctl calls; added authorized_keys fingerprint display.
#

set -eu

# ==============================================================================
# Unit: global-init  [orchestrator]
# Declares all constants, creates the scoped temp directory, and binds the EXIT
# trap so every execution path — including abnormal termination — reclaims the
# temp tree unconditionally (Rule 4.4).
# ==============================================================================

EMAIL="andro@theworkpc"
# Bare URL — no Markdown link syntax — required for curl to parse correctly.
GITHUB_USER_URL="https://github.com/4ndr0666.keys"
AUR_HOST="aur.archlinux.org"

# mktemp preferred; date-based fallback for minimal POSIX environments.
TMP_DIR="$(mktemp -d 2>/dev/null || printf "/tmp/ssh_matrix_%s" "$(date +%s)")"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

# ==============================================================================
# Unit: enforce_keypair  [volatile-logic]
# Generates a fresh Ed25519 keypair when the private key is absent.
# Recovers the public key from an existing private key when only the public is
# missing (EAFP: attempt the real operation, react to what is absent — Rule 4.6).
# Enforces deterministic directory and file permissions on every run.
# ==============================================================================
enforce_keypair() {
    printf "[*] Enforcing Ed25519 keypair integrity...\n"

    ssh_dir="${HOME}/.ssh"
    priv_key="${ssh_dir}/id_ed25519"
    pub_key="${ssh_dir}/id_ed25519.pub"

    mkdir -p "${ssh_dir}/sockets"

    # Generate fresh keypair when no private key exists.
    if [ ! -f "$priv_key" ]; then
        printf "[+] No private key found. Generating new Ed25519 keypair...\n"
        ssh-keygen -t ed25519 -a 100 -C "$EMAIL" -f "$priv_key" -N ""
    fi

    # Recover public key from private key when only the public half is missing.
    if [ ! -f "$pub_key" ]; then
        printf "[!] Public key missing. Recovering from private key...\n"
        ssh-keygen -y -f "$priv_key" > "$pub_key"
        printf "[+] Recovery successful.\n"
    fi

    # Enforce strict deterministic permissions.
    chmod 700 "$ssh_dir"
    chmod 700 "${ssh_dir}/sockets"
    chmod 600 "$priv_key"
    chmod 644 "$pub_key"

    printf "[*] Keypair validated.\n"
}

# ==============================================================================
# Unit: deploy_client_config  [orchestrator]
# Writes user-specific ~/.ssh/config targeting the supplied host.
# Escalates for the root-only global config via a validated self-reinvocation;
# SCRIPT_PATH is resolved to an absolute, readable path before sudo is called so
# the invocation cannot silently break when the script is run from a pipe or an
# ephemeral working directory.
# Disables and masks the local SSH server daemon to reduce local attack surface.
# ==============================================================================
deploy_client_config() {
    target_ip="$1"
    printf "[*] Deploying strict client configuration targeting %s...\n" "$target_ip"

    # Resolve the script's absolute path before escalating so sudo can locate it.
    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    if [ ! -r "$SCRIPT_PATH" ]; then
        printf "[-] Cannot resolve a readable script path for sudo reinvocation.\n"
        printf "    Run the script from its own directory or as: sudo sh /path/to/%s\n" "$(basename "$0")"
        exit 1
    fi

    if [ "$(id -u)" -ne 0 ]; then
        printf "[!] Global config requires root. Escalating...\n"
        sudo sh "$SCRIPT_PATH" _internal_global_client
    else
        _internal_global_client
    fi

    printf "[*] Writing user-specific SSH configuration (~/.ssh/config)...\n"
    cat << EOF > "${HOME}/.ssh/config"
# ~/.ssh/config  (User-specific — managed by ssh_matrix_manager.sh)

Host *
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_ed25519
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600
    AddKeysToAgent no
    SendEnv -L *

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
    sudo systemctl disable --now sshd 2>/dev/null || true
    sudo systemctl mask sshd 2>/dev/null || true
}

# ==============================================================================
# Unit: _internal_global_client  [volatile-logic]
# Writes the hardened system-wide /etc/ssh/ssh_config.
# Must be executed as root — invoked internally by deploy_client_config.
# Port 22 is deliberately ABSENT from Host * to avoid overriding operator-
# configured non-standard ports on other hosts.  Algorithm pinning restricts
# negotiation to modern, audited primitives.
# ==============================================================================
_internal_global_client() {
    printf "[*] Writing global system defaults (/etc/ssh/ssh_config)...\n"
    cat << 'EOF' > /etc/ssh/ssh_config
# /etc/ssh/ssh_config  (System-wide client defaults — managed by ssh_matrix_manager.sh)
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
    AddKeysToAgent no
    SendEnv -L *
    # Modern algorithm pinning — negotiates only audited primitives.
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
    KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org
EOF
    chmod 644 /etc/ssh/ssh_config
    printf "[+] Global client config written.\n"
}

# ==============================================================================
# Unit: deploy_aur_trust  [volatile-logic]
# Idempotently pins the AUR host key into the hashed known_hosts file.
# ssh-keyscan is bounded by a 10-second system-level timeout (Rule 4.2) so a
# network stall cannot hang the orchestrator indefinitely.
# ==============================================================================
deploy_aur_trust() {
    printf "[*] Pinning AUR host key...\n"
    known_hosts="${HOME}/.ssh/known_hosts"

    touch "$known_hosts"

    # Idempotency: skip scan if the host is already present.
    if ! ssh-keygen -F "$AUR_HOST" -f "$known_hosts" >/dev/null 2>&1; then
        # -T 10: hard network timeout satisfying Rule 4.2.
        ssh-keyscan -T 10 "$AUR_HOST" >> "$known_hosts" 2>/dev/null
        # Hash all plain-text entries and remove the unencrypted backup.
        ssh-keygen -H -f "$known_hosts" >/dev/null 2>&1
        rm -f "${known_hosts}.old"
        printf "[+] AUR host key pinned and hashed.\n"
    else
        printf "[+] AUR host key is already pinned.\n"
    fi

    chmod 600 "$known_hosts"
}

# ==============================================================================
# Unit: deploy_server_config  [orchestrator]
# Root-only.  Fetches the operator's public keys from GitHub (curl bounded at
# 10 s) into a staged temp file, merges with any existing authorized_keys
# entries (awk 'NF' removes blank lines; sort -u deduplicates), then atomically
# replaces authorized_keys via mv.
# Writes a hardened sshd_config with AllowUsers, MaxAuthTries, LoginGraceTime,
# and VERBOSE logging, then validates syntax and restarts the daemon.
# ==============================================================================
deploy_server_config() {
    if [ "$(id -u)" -ne 0 ]; then
        printf "[-] Server configuration requires root. Run: sudo sh %s server\n" "$0"
        exit 1
    fi

    printf "[*] Hardening server (dietpi)...\n"

    target_user="dietpi"
    target_home="/home/${target_user}"
    auth_keys="${target_home}/.ssh/authorized_keys"

    # --- 1. Fetch and install authorized keys ---
    printf "[*] Fetching canonical public keys from GitHub...\n"
    mkdir -p "${target_home}/.ssh"

    # Stage to an isolated temp file first so a partial download cannot corrupt
    # the live authorized_keys (Rule 4.1 isolation).
    if curl -fsSL --max-time 10 "$GITHUB_USER_URL" > "${TMP_DIR}/keys.pub"; then
        touch "$auth_keys"
        # Merge: existing keys are preserved alongside the fetched keys;
        # blank lines are stripped; exact duplicates are removed.
        awk 'NF' "$auth_keys" "${TMP_DIR}/keys.pub" | sort -u > "${TMP_DIR}/keys.new"
        mv "${TMP_DIR}/keys.new" "$auth_keys"
        chown -R "${target_user}:${target_user}" "${target_home}/.ssh"
        chmod 700 "${target_home}/.ssh"
        chmod 600 "$auth_keys"
        printf "[+] Keys installed successfully.\n"
    else
        printf "[-] Failed to fetch keys from GitHub. Aborting server configuration.\n"
        exit 1
    fi

    # --- 2. Write hardened sshd_config ---
    printf "[*] Writing hardened /etc/ssh/sshd_config...\n"
    cat << 'EOF' > /etc/ssh/sshd_config
# /etc/ssh/sshd_config  (Hardened server — managed by ssh_matrix_manager.sh)

Port 22
ListenAddress 0.0.0.0

# Authentication hardening
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries 3
LoginGraceTime 30

# Restrict login to the designated service account.
AllowUsers dietpi

# Host key — Ed25519 only.
HostKey /etc/ssh/ssh_host_ed25519_key

# Connection hygiene — ClientAliveInterval supersedes TCPKeepAlive.
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging and environment
LogLevel VERBOSE
UsePAM yes
X11Forwarding no
PrintMotd no

Subsystem sftp /usr/lib/ssh/sftp-server
EOF
    chmod 644 /etc/ssh/sshd_config

    # --- 3. Validate syntax and restart ---
    printf "[*] Validating sshd configuration syntax...\n"
    sshd -t

    printf "[*] Restarting SSH daemon...\n"
    systemctl restart ssh 2>/dev/null || systemctl restart sshd
    printf "[+] Server secured.\n"
}

# ==============================================================================
# Unit: audit_system  [volatile-logic]
# Prints a structured snapshot of the local SSH environment:
#   - Key and directory state
#   - Active multiplexing sockets
#   - SSH daemon service status
#   - Port-22 listeners
#   - Fingerprints of installed authorized_keys (when present)
# All systemctl queries are guarded with || true so set -e does not abort
# the audit on inactive units.
# ==============================================================================
audit_system() {
    printf "========================================\n"
    printf " SSH SYSTEM AUDIT\n"
    printf "========================================\n\n"

    printf '%s\n' "--- [ Local Key State ] ---"
    ls -la "${HOME}/.ssh" 2>/dev/null || printf '%s\n' "No ~/.ssh directory found."

    printf '\n%s\n' "--- [ Multiplexing Sockets ] ---"
    ls -la "${HOME}/.ssh/sockets" 2>/dev/null || printf '%s\n' "No sockets active."

    printf '\n%s\n' "--- [ SSH Daemon Status ] ---"
    # || true guards prevent set -e from aborting on inactive units.
    systemctl is-active sshd 2>/dev/null || systemctl is-active ssh 2>/dev/null || \
        printf '%s\n' "sshd is completely disabled/masked."

    printf '\n%s\n' "--- [ Listening Ports ] ---"
    ss -tnlp 2>/dev/null | grep ':22' || printf '%s\n' "No process listening on port 22."

    printf '\n%s\n' "--- [ Authorized Key Fingerprints ] ---"
    # Display fingerprints for the dietpi service account if this is the server,
    # and for the current user if local authorized_keys exist.
    for keys_path in \
        "/home/dietpi/.ssh/authorized_keys" \
        "${HOME}/.ssh/authorized_keys"
    do
        if [ -f "$keys_path" ]; then
            printf "Keys in %s:\n" "$keys_path"
            ssh-keygen -l -f "$keys_path" 2>/dev/null || \
                printf "  (unable to read fingerprints)\n"
        fi
    done

    printf "\n========================================\n"
}

# ==============================================================================
# Unit: main  [orchestrator]
# Dispatches on the first positional argument.  Prompts interactively for the
# target IP when the 'client' command is given without one.
# _internal_global_client is exposed here only for the validated sudo reinvocation
# path inside deploy_client_config; it is not intended for direct user invocation.
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
            printf "\n[✔] Key recovery complete.\n"
            ;;
        audit)
            audit_system
            ;;
        _internal_global_client)
            # Internal entry point for the root-escalated reinvocation from
            # deploy_client_config.  Not intended for direct user invocation.
            _internal_global_client
            ;;
        *)
            printf "Usage: %s {client <IP>|server|recover|audit}\n" "$0"
            exit 1
            ;;
    esac
}

main "$@"
