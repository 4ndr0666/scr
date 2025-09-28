#!/bin/bash
#
# ==============================================================================
# // QUICK-SECURE.SH - REFORGED //
#
# A robust, idempotent, and safer system hardening script.
# This script applies common security configurations based on CIS and STIG
# benchmarks. It is designed to be run multiple times without causing errors.
#
# ALWAYS review this script and understand its actions before deploying on a
# production system.
# ==============================================================================

# --- Strict Mode & Error Handling ---
# set -e: Exit immediately if a command exits with a non-zero status.
# set -u: Treat unset variables as an error when substituting.
# set -o pipefail: The return value of a pipeline is the status of the last
#                  command to exit with a non-zero status, or zero if no
#                  command exited with a non-zero status.
set -euo pipefail

# === // GLOBALS & CONFIGURATION // ========
# Using readonly ensures these variables cannot be accidentally overwritten.
readonly SCRIPT_NAME="${0##*/}"
readonly LOG_FILE="/var/log/quick-secure.log"

# --- Colors and Symbols ---
# Use tput for better terminal compatibility.
if [[ -t 1 ]]; then
  readonly BOLD="$(tput bold)"
  readonly GREEN="$(tput setaf 2)"
  readonly RED="$(tput setaf 1)"
  readonly NC="$(tput sgr0)" # No Color
else
  # If not a TTY, disable color codes.
  readonly BOLD=""
  readonly GREEN=""
  readonly RED=""
  readonly NC=""
fi

readonly SUCCESS="✔️"
readonly FAILURE="❌"
readonly INFO="➡️"
readonly EXPLOSION="💥"

# --- Packages to be removed (if they exist) ---
# Use an array for cleaner management.
readonly INSECURE_PACKAGES=(
    "vsftpd" "telnet-server" "rsh-server" "ypserv" "tftp-server" "talk"
    "telnet" "rdate" "tcpdump" "vnc-server" "tigervnc-server" "wireshark"
    "wireless-tools" "bind9-host" "libbind9-90" "vino"
)

# --- System accounts to be removed (if they exist) ---
readonly OBSOLETE_USERS=(
    "games" "news" "gopher" "ftp" "operator" "lp" "uucp" "irc" "gnats"
    "pcap" "netdump" "avahi" "haldaemon" "nfsnobody"
)

# === // UTILITY FUNCTIONS // ========

# --- Logging ---
# A robust logging function that timestamps and prefixes messages.
# It logs to both stdout and a dedicated log file.
log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

info() { log "INFO" "$1"; }
success() { log "SUCCESS" "${GREEN}${BOLD}$1${NC}"; }
error() { log "ERROR" "${RED}${BOLD}$1${NC}"; }
warn() { log "WARN" "$1"; }

# --- Command Execution ---
# Safely executes a command, logging its action and result.
run_cmd() {
  info "Executing: $*"
  if "$@"; then
    success "Successfully executed: $*"
  else
    error "Failed to execute: $* (Exit code: $?)"
    # Depending on desired strictness, you might want to exit here.
    # For this script, we log the error and continue.
  fi
}

# --- Permission Setting ---
# Idempotent function to set permissions and ownership.
# It checks current values before making changes to reduce noise and unnecessary operations.
set_perms() {
  local mode="$1"
  local owner="$2"
  local group="$3"
  local path="$4"
  
  if [[ ! -e "$path" ]]; then
    warn "Path not found, skipping permissions for: $path"
    return
  fi

  # Check and set ownership
  local current_owner
  current_owner=$(stat -c "%U" "$path")
  if [[ "$current_owner" != "$owner" ]]; then
    info "Setting owner of $path to $owner"
    chown "$owner" "$path"
  fi

  local current_group
  current_group=$(stat -c "%G" "$path")
  if [[ "$current_group" != "$group" ]]; then
    info "Setting group of $path to $group"
    chgrp "$group" "$path"
  fi

  # Check and set mode
  local current_mode
  current_mode=$(stat -c "%a" "$path")
  if [[ "$current_mode" != "$mode" ]]; then
    info "Setting mode of $path to $mode"
    chmod "$mode" "$path"
  fi
}

# === // HARDENING FUNCTIONS // ========

harden_selinux() {
  info "--- Hardening SELinux Configuration ---"
  if ! command -v getenforce >/dev/null 2>&1; then
    warn "SELinux tools not found. Skipping SELinux hardening."
    return
  fi

  if [[ "$(getenforce)" == "Disabled" ]]; then
    error "SELinux is disabled. Manual intervention is required to enable it."
    warn "A hardening script should NEVER disable SELinux. This script will ensure it is set to 'enforcing' if it is not disabled."
    return
  fi

  if [[ -f /etc/selinux/config ]]; then
    info "Ensuring SELinux is set to 'enforcing' in /etc/selinux/config"
    # Use sed to replace 'disabled' or 'permissive' with 'enforcing'
    sed -i 's/^\s*SELINUX\s*=\s*\(disabled\|permissive\)/SELINUX=enforcing/' /etc/selinux/config
    if ! grep -q "^\s*SELINUX\s*=\s*enforcing" /etc/selinux/config; then
      warn "/etc/selinux/config does not contain a SELINUX line. Adding it."
      echo "SELINUX=enforcing" >> /etc/selinux/config
    fi
    set_perms "640" "root" "root" "/etc/selinux/config"
  fi

  if [[ "$(getenforce)" != "Enforcing" ]]; then
    info "Temporarily setting SELinux to Enforcing mode."
    run_cmd setenforce 1
  fi
  success "SELinux is configured to be in Enforcing mode."
}

harden_fstab() {
  info "--- Hardening Filesystem Mount Options in /etc/fstab ---"
  if [[ ! -f /etc/fstab ]]; then
    error "/etc/fstab not found. Cannot proceed."
    return 1
  fi

  # Create a backup of fstab before modifying it.
  local backup_file="/etc/fstab.bak.$(date +%F-%T)"
  info "Backing up /etc/fstab to $backup_file"
  cp /etc/fstab "$backup_file"

  # Use awk for safe, line-by-line processing. This is vastly superior to the
  # original script's dangerous sed commands.
  awk '
    # Skip comments and empty lines
    /^\s*#/ || /^\s*$/ { print; next }

    # Define mount points and the options to add
    BEGIN {
      mounts["/tmp"] = "nodev,nosuid,noexec";
      mounts["/var/tmp"] = "nodev,nosuid,noexec";
      mounts["/dev/shm"] = "nodev,nosuid,noexec";
      mounts["/home"] = "nodev,nosuid";
      mounts["/boot"] = "nodev,nosuid,noexec";
    }

    {
      mount_point = $2;
      options = $4;

      if (mount_point in mounts) {
        # Split the required options and current options into arrays
        split(mounts[mount_point], required_opts, ",");
        split(options, current_opts, ",");

        # Create a set of current options for easy lookup
        delete current_set; # Clear the array for each line
        for (i in current_opts) {
          current_set[current_opts[i]] = 1;
        }

        # Check for each required option and add if missing
        for (i in required_opts) {
          opt = required_opts[i];
          if (!(opt in current_set)) {
            # Add the missing option
            options = options "," opt;
            # Log the change (awk cannot call shell functions)
            print "# INFO: Added option " opt " to " mount_point > "/dev/stderr";
          }
        }
        $4 = options;
      }
      # Reconstruct and print the line with original formatting as much as possible
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, $6;
    }
  ' /etc/fstab > /etc/fstab.tmp 2> >(tee -a "$LOG_FILE" >&2) && mv /etc/fstab.tmp /etc/fstab

  success "fstab hardening complete. Review changes and reboot for them to take effect."
}

harden_ssh() {
  info "--- Hardening SSH Daemon Configuration ---"
  local ssh_config='/etc/ssh/sshd_config'
  if [[ ! -f "$ssh_config" ]]; then
    warn "SSH config not found at $ssh_config. Skipping."
    return
  fi

  # Create a backup
  cp "$ssh_config" "$ssh_config.bak.$(date +%F-%T)"

  # Define key-value pairs for hardening
  declare -A ssh_options=(
    ["PermitRootLogin"]="no"
    ["Protocol"]="2"
    ["LogLevel"]="VERBOSE"
    ["PermitEmptyPasswords"]="no"
    ["X11Forwarding"]="no"
    ["MaxAuthTries"]="3"
    ["IgnoreRhosts"]="yes"
    ["HostbasedAuthentication"]="no"
    ["ClientAliveInterval"]="300"
    ["ClientAliveCountMax"]="0"
    ["LoginGraceTime"]="60"
    ["Banner"]="/etc/issue.net"
  )

  for key in "${!ssh_options[@]}"; do
    local value="${ssh_options[$key]}"
    info "Setting SSH config: $key $value"
    # If key exists, update it. If not, append it.
    if grep -qE "^\s*#?\s*${key}\s+" "$ssh_config"; then
      sed -i -E "s/^\s*#?\s*${key}\s+.*/${key} ${value}/" "$ssh_config"
    else
      echo "${key} ${value}" >> "$ssh_config"
    fi
  done

  # Set permissions on SSH files
  set_perms "700" "root" "root" "/root/.ssh"
  find /root/.ssh -type f -exec chmod 600 {} \;
  set_perms "600" "root" "root" "/etc/ssh/sshd_config"
  set_perms "644" "root" "root" "/etc/ssh/ssh_config"

  info "Restarting SSH service to apply changes..."
  if command -v systemctl >/dev/null 2>&1; then
    run_cmd systemctl restart sshd.service
  elif command -v service >/dev/null 2>&1; then
    run_cmd service sshd restart
  else
    warn "Could not determine service manager to restart SSH."
  fi
}

harden_kernel_sysctl() {
  info "--- Hardening Kernel Parameters via sysctl ---"
  local sysctl_conf="/etc/sysctl.d/99-hardening.conf"
  info "Writing hardening parameters to $sysctl_conf"

  # Use a heredoc for a clean, readable configuration block.
  cat > "$sysctl_conf" << EOF
# --- Kernel Hardening Parameters ---

# Turn on ASLR (Conservative Randomization)
kernel.randomize_va_space=2

# Hide Kernel Pointers from unprivileged users
kernel.kptr_restrict=1

# Restrict ptrace scope to prevent process snooping
kernel.yama.ptrace_scope=1

# Enable protection against hardlink and symlink attacks
fs.protected_hardlinks=1
fs.protected_symlinks=1

# --- Network Hardening Parameters ---

# Enable TCP SYN Cookie Protection to prevent SYN floods
net.ipv4.tcp_syncookies=1

# Disable IP Source Routing (uncommon and a security risk)
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0

# Disable ICMP Redirect Acceptance (prevents MITM attacks)
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0

# Do not send ICMP redirects
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0

# Enable IP Spoofing Protection (Reverse Path Filtering)
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1

# Ignore all ICMP echo requests to make the host less visible
net.ipv4.icmp_echo_ignore_all=1

# Ignore ICMP broadcasts to prevent smurf attacks
net.ipv4.icmp_echo_ignore_broadcasts=1

# Ignore bogus ICMP error responses
net.ipv4.icmp_ignore_bogus_error_responses=1

# Log martian packets (spoofed, source-routed, or redirect packets)
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.default.log_martians=1

# Prefer RFC 4941 privacy addresses for IPv6
net.ipv6.conf.all.use_tempaddr=2
net.ipv6.conf.default.use_tempaddr=2
EOF

  success "Applying sysctl settings..."
  run_cmd sysctl --system
}

harden_permissions() {
  info "--- Applying Secure File Permissions and Ownership ---"
  # This is a sample. A full list would be extensive.
  # Focus on critical files first.
  set_perms "644" "root" "root" "/etc/passwd"
  set_perms "400" "root" "root" "/etc/shadow"
  set_perms "644" "root" "root" "/etc/group"
  set_perms "400" "root" "root" "/etc/gshadow"
  set_perms "440" "root" "root" "/etc/sudoers"
  set_perms "750" "root" "root" "/etc/sudoers.d"
  set_perms "600" "root" "root" "/etc/crontab"
  set_perms "700" "root" "root" "/etc/cron.hourly"
  set_perms "700" "root" "root" "/etc/cron.daily"
  set_perms "700" "root" "root" "/etc/cron.weekly"
  set_perms "700" "root" "root" "/etc/cron.monthly"
  set_perms "700" "root" "root" "/etc/cron.d"
  set_perms "700" "root" "root" "/root"
  set_perms "600" "root" "root" "/boot/grub2/grub.cfg"
  set_perms "1777" "root" "root" "/tmp"
  set_perms "1777" "root" "root" "/var/tmp"

  info "Hardening user home directory permissions..."
  if [[ -d /home ]]; then
    for homedir in /home/*; do
      if [[ -d "$homedir" ]]; then
        local user
        user=$(basename "$homedir")
        set_perms "700" "$user" "$user" "$homedir"
      fi
    done
  fi
}

remove_insecure_services() {
  info "--- Removing Insecure and Unnecessary Packages ---"
  local pkg_manager=""
  if command -v dnf >/dev/null 2>&1; then
    pkg_manager="dnf"
  elif command -v yum >/dev/null 2>&1; then
    pkg_manager="yum"
  elif command -v apt-get >/dev/null 2>&1; then
    pkg_manager="apt-get"
  elif command -v pacman >/dev/null 2>&1; then
    pkg_manager="pacman"
  else
    warn "Could not determine package manager. Skipping package removal."
    return
  fi
  info "Using package manager: $pkg_manager"

  for pkg in "${INSECURE_PACKAGES[@]}"; do
    info "Checking for package: $pkg"
    # Check if package is installed before trying to remove it.
    local is_installed=false
    case "$pkg_manager" in
      dnf|yum) rpm -q "$pkg" >/dev/null 2>&1 && is_installed=true ;;
      apt-get) dpkg -l "$pkg" | grep -q "^ii" && is_installed=true ;;
      pacman) pacman -Q "$pkg" >/dev/null 2>&1 && is_installed=true ;;
    esac

    if [[ "$is_installed" == true ]]; then
      warn "Removing package: $pkg"
      case "$pkg_manager" in
        dnf|yum) run_cmd "$pkg_manager" remove -y "$pkg" ;;
        apt-get) run_cmd "$pkg_manager" purge -y "$pkg" ;;
        # Pacman's -Rdd is dangerous, use -Rns to remove dependencies safely.
        pacman) run_cmd "$pkg_manager" -Rns --noconfirm "$pkg" ;;
      esac
    else
      info "Package $pkg is not installed."
    fi
  done
}

cleanup_accounts() {
  info "--- Cleaning Up Obsolete User Accounts ---"
  for user in "${OBSOLETE_USERS[@]}"; do
    if id "$user" >/dev/null 2>&1; then
      warn "Removing user: $user"
      run_cmd userdel -r "$user"
    else
      info "User $user does not exist."
    fi
  done
}

# === // SCRIPT EXECUTION // ========

main() {
  # --- Auto-escalate to root ---
  if [[ "$(id -u)" -ne 0 ]]; then
    info "This script requires root privileges. Attempting to re-run with sudo..."
    # Use exec to replace the current process, avoiding duplicate execution.
    exec sudo bash "$0" "$@"
  fi

  # Setup logging
  touch "$LOG_FILE"
  chmod 600 "$LOG_FILE"
  chown root:root "$LOG_FILE"

  # --- Disclaimer and Confirmation ---
  echo -e "${BOLD}${GREEN}"
  cat << "EOF"
#  ________        .__        __                                                                   .__
#  \_____  \  __ __|__| ____ |  | __           ______ ____   ____  __ _________   ____        _____|  |__
#   /  / \  \|  |  \  |/ ___\|  |/ /  ______  /  ___// __ \_/ ___\|  |  \_  __ \_/ __ \      /  ___/  |  \
#  /   \_/.  \  |  /  \  \___|    <  /_____/  \___ \\  ___/\  \___|  |  /|  | \/\  ___/      \___ \|   Y  \
#  \_____\ \_/____/|__|\___  >__|_ \         /____  >\___  >\___  >____/ |__|    \___  > /\ /____  >___|  /
#         \__>             \/     \/              \/     \/     \/                   \/  \/      \/     \/
EOF
  echo -e "${NC}"
  
  info "${EXPLOSION} This script will apply significant security changes to $(hostname) ${EXPLOSION}"
  warn "ALWAYS REVIEW A SCRIPT BEFORE DEPLOYMENT."

  if [[ "${1:-}" != "-f" && "${1:-}" != "--force" ]]; then
    read -p "Initiate fully automated deployment? (y/N): " -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      error "Deployment aborted by user."
      exit 1
    fi
  else
    info "Force flag detected. Proceeding without confirmation."
  fi

  # --- Execute Hardening Functions ---
  harden_selinux
  harden_permissions
  harden_fstab
  harden_ssh
  harden_kernel_sysctl
  remove_insecure_services
  cleanup_accounts

  echo ""
  success "$SUCCESS SCAN AND HARDENING COMPLETED..."
  info "$EXPLOSION SYSTEM WAS REFORGED AND SECURED $EXPLOSION"
  info "A reboot is recommended to ensure all changes take effect."
  exit 0
}

# --- Run the main function, passing all script arguments to it ---
main "$@"
