#!/usr/bin/env python3
"""
4NDR0666OS Network Identity Mutation Suite (NIMS)
Version: 3.2.1 (Gap Mitigation: Auto-Gen & Flexible Args)
Author: Ψ-4ndr0666
Target: Linux Network Stack (iproute2 / NetworkManager)
"""

import os
import sys
import subprocess
import argparse
import re
import random
import shutil
import configparser

# -----------------------------------------------------------------------------
# CONSTANTS & CONFIGURATION
# -----------------------------------------------------------------------------
COLORS = {
    "RED": "\033[91m",
    "GREEN": "\033[92m",
    "YELLOW": "\033[93m",
    "BLUE": "\033[94m",
    "CYAN": "\033[96m",
    "RESET": "\033[0m"
}

NM_PATH = "/etc/NetworkManager/system-connections/"
RENAMER_SCRIPT_PATH = "/usr/local/bin/iface-renamer.sh"
CONFIG_PATH = "/etc/NetworkManager/mac-changer.conf"

# -----------------------------------------------------------------------------
# UTILITY CLASSES
# -----------------------------------------------------------------------------
class Logger:
    @staticmethod
    def info(msg):
        print(f"{COLORS['BLUE']}[*]{COLORS['RESET']} {msg}")

    @staticmethod
    def success(msg):
        print(f"{COLORS['GREEN']}[+]{COLORS['RESET']} {msg}")

    @staticmethod
    def warn(msg):
        print(f"{COLORS['YELLOW']}[!]{COLORS['RESET']} {msg}")

    @staticmethod
    def error(msg, fatal=True):
        print(f"{COLORS['RED']}[-]{COLORS['RESET']} {msg}")
        if fatal:
            sys.exit(1)

class Privileges:
    @staticmethod
    def ensure_root():
        """
        Auto-escalation routine.
        If not root, re-executes the current script with sudo.
        """
        if os.geteuid() != 0:
            try:
                print(f"{COLORS['YELLOW']}[!] Insufficient privileges. Attempting to escalate...{COLORS['RESET']}")
                # Re-run the script with sudo, preserving all arguments
                subprocess.check_call(['sudo', sys.executable] + sys.argv)
                sys.exit(0)
            except subprocess.CalledProcessError as e:
                print(f"{COLORS['RED']}[-] Error escalating privileges: {e}{COLORS['RESET']}")
                sys.exit(e.returncode)

class SystemShell:
    @staticmethod
    def run(cmd_list, fatal=True, quiet=False):
        if not quiet:
            print(f"{COLORS['CYAN']}[CMD]{COLORS['RESET']} {' '.join(cmd_list)}")
        try:
            output = subprocess.check_output(cmd_list, stderr=subprocess.STDOUT)
            return output.decode("utf-8", errors="replace").strip()
        except subprocess.CalledProcessError as e:
            if fatal:
                Logger.error(f"Command failed: {' '.join(cmd_list)}\nOutput: {e.output.decode()}")
            return None

# -----------------------------------------------------------------------------
# CORE LOGIC: MAC MANIPULATION
# -----------------------------------------------------------------------------
class MacEngine:
    @staticmethod
    def generate_random():
        """Generates a unicast, locally administered MAC."""
        first_octet = random.randint(0x00, 0xFF)
        # Set locally administered bit (bit 1), unset multicast bit (bit 0)
        first_octet = (first_octet | 0x02) & 0xFE
        rest = [random.randint(0x00, 0xFF) for _ in range(5)]
        mac = ":".join(f"{x:02x}" for x in [first_octet] + rest).upper()
        return mac

    @staticmethod
    def validate(mac):
        if not re.match(r"^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$", mac):
            Logger.error(f"Invalid MAC format: {mac}")
        return mac.upper()

    @staticmethod
    def get_current(interface):
        try:
            out = SystemShell.run(["ip", "link", "show", interface], quiet=True)
            match = re.search(r"link/ether\s+([0-9a-fA-F:]{17})", out)
            return match.group(1).upper() if match else None
        except Exception:
            return None

    @staticmethod
    def set_ephemeral(interface, new_mac):
        Logger.info(f"Applying ephemeral MAC: {new_mac} on {interface}")
        SystemShell.run(["ip", "link", "set", interface, "down"])
        SystemShell.run(["ip", "link", "set", interface, "address", new_mac])
        SystemShell.run(["ip", "link", "set", interface, "up"])
        Logger.success("Ephemeral mutation complete.")

# -----------------------------------------------------------------------------
# PERSISTENCE ENGINE: NETWORK MANAGER
# -----------------------------------------------------------------------------
class NetworkManagerHandler:
    def __init__(self, filepath):
        self.filepath = filepath
        if not os.path.exists(filepath):
            Logger.error(f"Connection file not found: {filepath}")

    def _toggle_immutable(self, enable=True):
        flag = "+i" if enable else "-i"
        try:
            subprocess.check_call(["chattr", flag, self.filepath], stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            pass 

    def backup(self):
        backup_path = f"{self.filepath}.bak"
        if not os.path.exists(backup_path):
            shutil.copy2(self.filepath, backup_path)
            Logger.success(f"Backup created: {backup_path}")
        else:
            Logger.info("Backup already exists.")

    def restore(self):
        backup_path = f"{self.filepath}.bak"
        if not os.path.exists(backup_path):
            Logger.error("No backup found. Cannot restore.")
        
        self._toggle_immutable(False)
        shutil.copy2(backup_path, self.filepath)
        self._toggle_immutable(True)
        Logger.success("Restoration complete.")
        self.reload_connection()

    def update_mac(self, new_mac):
        self.backup()
        self._toggle_immutable(False)

        config = configparser.ConfigParser(interpolation=None)
        config.optionxform = str 
        
        try:
            config.read(self.filepath)
            
            if "ethernet" not in config.sections():
                config.add_section("ethernet")
            
            config["ethernet"]["cloned-mac-address"] = new_mac
            
            with open(self.filepath, "w") as configfile:
                config.write(configfile, space_around_delimiters=False)
            
            os.chmod(self.filepath, 0o600)
            Logger.success(f"Updated {self.filepath} with cloned-mac-address={new_mac}")
            
        except Exception as e:
            Logger.error(f"Failed to parse/write .nmconnection: {e}")
        finally:
            self._toggle_immutable(True)

    def reload_connection(self):
        config = configparser.ConfigParser(interpolation=None)
        config.optionxform = str
        config.read(self.filepath)
        conn_id = None
        if "connection" in config and "id" in config["connection"]:
            conn_id = config["connection"]["id"]
        
        SystemShell.run(["nmcli", "connection", "reload"])
        if conn_id:
            SystemShell.run(["nmcli", "connection", "up", conn_id])
            Logger.success(f"Reloaded connection: {conn_id}")

# -----------------------------------------------------------------------------
# AUXILIARY TOOLS
# -----------------------------------------------------------------------------
class Auxiliary:
    @staticmethod
    def install_renamer(target_if, target_mac):
        """Generates and installs the interface renamer script."""
        Logger.info("Synthesizing interface renamer payload...")
        
        script_content = f"""#!/usr/bin/env bash
# 4NDR0666OS Generated Renamer
set -euo pipefail

TARGET_MAC="{target_mac}"
TARGET_IF="{target_if}"

echo "[*] Scanning for device with MAC: $TARGET_MAC"
CURRENT_IF="$(ip -o link | awk -v mac="$TARGET_MAC" 'tolower($0) ~ tolower(mac) {{print $2}}' | sed 's/://')"

if [ -z "$CURRENT_IF" ]; then
    echo "[-] Device not found."
    exit 1
fi

if [ "$CURRENT_IF" != "$TARGET_IF" ]; then
    echo "[+] Renaming $CURRENT_IF -> $TARGET_IF"
    ip link set "$CURRENT_IF" down
    ip link set "$CURRENT_IF" name "$TARGET_IF"
    ip link set "$TARGET_IF" up
else
    echo "[*] Interface already named correctly."
fi
"""
        try:
            with open(RENAMER_SCRIPT_PATH, "w") as f:
                f.write(script_content)
            os.chmod(RENAMER_SCRIPT_PATH, 0o755)
            Logger.success(f"Renamer installed to {RENAMER_SCRIPT_PATH}")
            Logger.info("NOTE: Add this script to /etc/rc.local or a systemd service for boot persistence.")
        except Exception as e:
            Logger.error(f"Failed to write renamer script: {e}")

    @staticmethod
    def generate_config_file(default_mac=None):
        if os.path.exists(CONFIG_PATH):
            overwrite = input(f"{COLORS['YELLOW']}[?] Config exists. Overwrite? [y/N]: {COLORS['RESET']}").lower()
            if overwrite != 'y':
                return

        mac = default_mac if default_mac else ""
        content = f"""# 4NDR0666OS MAC Changer Config
[MAC-Changer]
default_mac={mac}
"""
        try:
            with open(CONFIG_PATH, "w") as f:
                f.write(content)
            os.chmod(CONFIG_PATH, 0o644)
            Logger.success(f"Config generated at {CONFIG_PATH}")
        except Exception as e:
            Logger.error(f"Config generation failed: {e}")

# -----------------------------------------------------------------------------
# MAIN EXECUTABLE
# -----------------------------------------------------------------------------
def main():
    # 1. Argument Parsing Configuration
    parser = argparse.ArgumentParser(
        description="4NDR0666OS Network Identity Mutation Suite",
        formatter_class=argparse.RawTextHelpFormatter,
        epilog="""
Examples:
  %(prog)s -i eth0 -m 00:11:22:33:44:55
  %(prog)s -i wlan0 -m  # Random MAC
  %(prog)s -i wlan0 --persistent
  %(prog)s --restore -i eth0
  %(prog)s --gen-config
"""
    )
    
    parser.add_argument("-i", "--interface", help="Target Network Interface (e.g., eth0)")
    # 'nargs="?"' allows -m to be used as a flag (value=const) or with an arg
    parser.add_argument("-m", "--mac", nargs="?", const="RANDOM", help="Target MAC Address. Random if omitted/flagged.")
    parser.add_argument("-f", "--file", help="Path to .nmconnection file", 
                        default="/etc/NetworkManager/system-connections/Ethernet connection 1.nmconnection")
    
    mode_group = parser.add_argument_group("Operation Modes")
    mode_group.add_argument("--ephemeral", action="store_true", help="Change MAC in memory only (lost on reboot)")
    mode_group.add_argument("--persistent", action="store_true", help="Modify NetworkManager config for persistence")
    mode_group.add_argument("-r", "--restore", action="store_true", help="Restore original configuration from backup")
    
    aux_group = parser.add_argument_group("Auxiliary Functions")
    aux_group.add_argument("--gen-config", action="store_true", help="Generate tool configuration file")
    aux_group.add_argument("--install-renamer", action="store_true", help="Install bash interface renamer script")
    aux_group.add_argument("--target-if-name", help="Target Interface Name for renamer script")

    # 2. Check for empty args to trigger help
    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        sys.exit(1)

    args = parser.parse_args()

    # 3. Privilege Escalation
    Privileges.ensure_root()

    # 4. DETERMINE TARGET MAC (Moved Upstream)
    # This logic ensures a MAC is available for ALL downstream functions (Auxiliary & Main)
    final_mac = None
    if not args.restore:
        # If user provided a specific MAC
        if args.mac and args.mac != "RANDOM":
            final_mac = MacEngine.validate(args.mac)
        # If user omitted flag OR used -m flag without arg (RANDOM)
        else:
            final_mac = MacEngine.generate_random()
            Logger.info(f"Generated Random MAC: {final_mac}")

    # 5. Handle Auxiliary - Config Generation
    if args.gen_config:
        Auxiliary.generate_config_file(final_mac)
        sys.exit(0)

    # 6. Handle Auxiliary - Renamer Install
    if args.install_renamer:
        # Fallback: Use interface name if target-if-name is missing
        target_if = args.target_if_name if args.target_if_name else args.interface
        
        if not target_if:
             Logger.error("Renamer installation requires --target-if-name OR --interface")
             
        Logger.info(f"Using MAC {final_mac} for renamer script.")
        Auxiliary.install_renamer(target_if, final_mac)
        sys.exit(0)

    # 7. Main Operations Check
    if not args.interface and not args.restore:
        Logger.error("Argument --interface is required for main operations.")

    # 8. Restore Logic
    if args.restore:
        nm_handler = NetworkManagerHandler(args.file)
        nm_handler.restore()
        
        # Restore hardware MAC if we have it memorized in /tmp (Best effort)
        tmp_mem = f"/tmp/original_mac_{args.interface}"
        if os.path.exists(tmp_mem):
            with open(tmp_mem, 'r') as f:
                orig_mac = f.read().strip()
            MacEngine.set_ephemeral(args.interface, orig_mac)
        return

    # 9. Memorize Original MAC (Ramdisk only)
    if args.interface:
        current_mac = MacEngine.get_current(args.interface)
        if current_mac:
            tmp_mem = f"/tmp/original_mac_{args.interface}"
            if not os.path.exists(tmp_mem):
                with open(tmp_mem, 'w') as f:
                    f.write(current_mac)
                Logger.info(f"Original MAC {current_mac} memorized in {tmp_mem}")

    # 10. Apply Persistent
    if args.persistent:
        nm_handler = NetworkManagerHandler(args.file)
        nm_handler.update_mac(final_mac)
        nm_handler.reload_connection()
    
    # 11. Apply Ephemeral
    if args.interface:
        MacEngine.set_ephemeral(args.interface, final_mac)

if __name__ == "__main__":
    main()
