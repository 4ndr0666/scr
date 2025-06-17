#!/usr/bin/env python3
import os
import sys
import subprocess
import optparse
import re
import random
import shutil

###############################################################################
# 1. Privilege escalation / root check
###############################################################################


def ensure_root():
    """
    If not running as root, attempt to re-run via sudo.
    """
    if os.geteuid() != 0:
        try:
            print("[*] Attempting to escalate privileges via sudo...")
            subprocess.check_call(["sudo", sys.executable] + sys.argv)
            sys.exit(0)
        except subprocess.CalledProcessError as e:
            print(f"[-] Error escalating privileges: {e}")
            sys.exit(e.returncode)


###############################################################################
# 2. Basic command helpers
###############################################################################


def safe_cmd(cmd_list):
    """
    Runs a command list; exits on nonzero return code.
    """
    print(f"[cmd] {' '.join(cmd_list)}")
    ret = subprocess.call(cmd_list)
    if ret != 0:
        sys.exit(f"[-] Command '{' '.join(cmd_list)}' failed with code {ret}")


def run_cmd(cmd_list):
    """
    Runs a command list, returning (exit_code, output) without exiting.
    """
    try:
        output = subprocess.check_output(cmd_list, stderr=subprocess.STDOUT)
        return (0, output.decode("utf-8", errors="replace"))
    except subprocess.CalledProcessError as e:
        return (e.returncode, e.output.decode("utf-8", errors="replace"))


###############################################################################
# 3. chattr helper (lock/unlock) that ignores unsupported errors
###############################################################################


def chattr_set_immutable(path, enable=True):
    """
    Uses chattr to set (+i) or unset (-i) the immutable bit on a file.
    If the filesystem doesn’t support chattr, a warning is printed.
    """
    if not os.path.isfile(path):
        return
    flag = "+i" if enable else "-i"
    code, out = run_cmd(["chattr", flag, path])
    if code != 0:
        if "Operation not supported" in out:
            print(f"[!] chattr {flag} not supported on {path}; skipping.")
        else:
            sys.exit(f"[-] chattr {flag} on {path} failed: {out.strip()}")


###############################################################################
# 4. MAC address generation and retrieval
###############################################################################


def generate_random_mac():
    """
    Generates a random, locally administered, unicast MAC address.
    """
    first_octet = random.randint(0x00, 0xFF)
    first_octet = (first_octet | 0x02) & 0xFE
    rest = [random.randint(0x00, 0xFF) for _ in range(5)]
    return ":".join(f"{x:02x}" for x in [first_octet] + rest)


def get_current_mac(interface):
    """
    Retrieves the current MAC of the interface using ip link.
    """
    try:
        out = (
            subprocess.check_output(["ip", "link", "show", interface])
            .decode("utf-8")
            .lower()
        )
        match = re.search(r"link/ether\s+([0-9a-f:]{17})", out)
        if match:
            return match.group(1)
    except Exception as ex:
        print(f"[-] Could not retrieve MAC for {interface}: {ex}")
    return None


def change_mac_ephemeral(interface, new_mac):
    """
    Immediately changes the MAC address via ip link.
    """
    print(f"[+] Changing MAC for {interface} to {new_mac} (ephemeral)")
    safe_cmd(["ip", "link", "set", interface, "down"])
    safe_cmd(["ip", "link", "set", interface, "address", new_mac])
    safe_cmd(["ip", "link", "set", interface, "up"])


###############################################################################
# 5. .nmconnection file manipulation
###############################################################################


def get_connection_id(nm_file):
    """
    Parses the .nmconnection file for the connection id from the [connection] section.
    """
    if not os.path.isfile(nm_file):
        return None
    try:
        with open(nm_file, "r") as f:
            lines = f.readlines()
    except Exception as ex:
        print(f"[-] Could not read {nm_file}: {ex}")
        return None

    in_conn = False
    for line in lines:
        ls = line.strip().lower()
        if ls == "[connection]":
            in_conn = True
            continue
        if ls.startswith("[") and ls != "[connection]":
            in_conn = False
        if in_conn and "=" in line:
            k, v = line.strip().split("=", 1)
            if k.strip().lower() == "id":
                return v.strip()
    return None


def update_nm_file_mac(src_file, dest_file, new_mac):
    """
    Reads src_file, updates or inserts cloned-mac-address=<new_mac> in [ethernet],
    and writes the result to dest_file.
    """
    if not os.path.isfile(src_file):
        print(f"[-] Source file {src_file} not found.")
        return False

    try:
        with open(src_file, "r") as f:
            lines = f.readlines()
    except Exception as ex:
        print(f"[-] Could not read {src_file}: {ex}")
        return False

    new_lines = []
    in_ethernet = False
    replaced = False

    for line in lines:
        ls = line.strip().lower()
        if ls == "[ethernet]":
            in_ethernet = True
            new_lines.append(line)
            continue
        if ls.startswith("[") and ls != "[ethernet]":
            if in_ethernet and not replaced:
                new_lines.append(f"cloned-mac-address={new_mac}\n")
                replaced = True
            in_ethernet = False
            new_lines.append(line)
            continue
        if in_ethernet:
            if ls.startswith("cloned-mac-address=") or ls.startswith("mac-address="):
                new_lines.append(f"cloned-mac-address={new_mac}\n")
                replaced = True
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)
    if in_ethernet and not replaced:
        new_lines.append(f"cloned-mac-address={new_mac}\n")

    try:
        with open(dest_file, "w") as f:
            f.writelines(new_lines)
        os.chmod(dest_file, 0o600)
        return True
    except Exception as ex:
        print(f"[-] Could not write to {dest_file}: {ex}")
        return False


###############################################################################
# 6. Memorize and restore original MAC and .nmconnection file
###############################################################################


def memorize_original_mac(interface):
    """
    Saves the current MAC of the interface to /tmp/original_mac_<iface>.
    """
    mac = get_current_mac(interface)
    if mac:
        mem_file = f"/tmp/original_mac_{interface}"
        try:
            with open(mem_file, "w") as f:
                f.write(mac + "\n")
            os.chmod(mem_file, 0o600)
            print(f"[+] Memorized original MAC {mac} in {mem_file}")
        except Exception as ex:
            print(f"[-] Could not store original MAC: {ex}")


def backup_nm_file(nm_file):
    """
    Creates a backup of the nm_file as nm_file.bak if it doesn't already exist.
    """
    bak_file = nm_file + ".bak"
    if not os.path.isfile(bak_file):
        try:
            shutil.copy2(nm_file, bak_file)
            os.chmod(bak_file, 0o600)
            print(f"[+] Backed up {nm_file} to {bak_file}")
        except Exception as ex:
            print(f"[-] Could not backup {nm_file}: {ex}")
    else:
        print(f"[*] Backup already exists: {bak_file}")


def restore_nm_file(nm_file):
    """
    Restores the original .nmconnection file from its backup.
    """
    bak_file = nm_file + ".bak"
    if not os.path.isfile(bak_file):
        print(f"[-] Backup file {bak_file} not found; cannot restore.")
        return False
    try:
        # Remove immutable if set
        chattr_set_immutable(nm_file, enable=False)
        shutil.copy2(bak_file, nm_file)
        print(f"[+] Restored {nm_file} from {bak_file}")
        return True
    except Exception as ex:
        print(f"[-] Could not restore {nm_file}: {ex}")
        return False


def restore_interface_mac(interface):
    """
    Restores the original MAC of the interface from /tmp.
    """
    mem_file = f"/tmp/original_mac_{interface}"
    if not os.path.isfile(mem_file):
        print(f"[*] No memorized MAC in {mem_file}")
        return
    try:
        with open(mem_file, "r") as f:
            orig_mac = f.read().strip()
        if orig_mac:
            print(f"[+] Restoring interface {interface} MAC to {orig_mac}")
            safe_cmd(["ip", "link", "set", interface, "down"])
            safe_cmd(["ip", "link", "set", interface, "address", orig_mac])
            safe_cmd(["ip", "link", "set", interface, "up"])
    except Exception as ex:
        print(f"[-] Could not restore interface MAC: {ex}")


###############################################################################
# 7. Main flows: apply new MAC (ephemeral & persistent) or restore
###############################################################################


def apply_new_mac(interface, nm_file, new_mac, persistent=False):
    """
    1. Memorize the current MAC.
    2. Backup the nm_file.
    3. Remove immutable attribute if possible.
    4. Update the nm_file with the new MAC (ephemeral change).
    5. Optionally, leave the change persistent.
    6. Reload NetworkManager by using nmcli with the connection ID.
    7. Immediately set the MAC on the interface.
    """
    memorize_original_mac(interface)
    backup_nm_file(nm_file)

    # Remove immutable before editing; ignore if unsupported.
    chattr_set_immutable(nm_file, enable=False)

    # Update nm_file in-place.
    temp_nm = nm_file + ".temp"
    if not update_nm_file_mac(nm_file, temp_nm, new_mac):
        sys.exit("[-] Failed to update the .nmconnection file.")
    try:
        shutil.move(temp_nm, nm_file)
        print(f"[+] Updated {nm_file} with new MAC {new_mac}")
    except Exception as ex:
        sys.exit(f"[-] Failed to move temporary file: {ex}")

    # Lock the file if desired.
    chattr_set_immutable(nm_file, enable=True)

    # Reload NetworkManager using the connection ID.
    conn_id = get_connection_id(nm_file)
    if not conn_id:
        sys.exit("[-] Could not parse connection ID from the .nmconnection file.")
    safe_cmd(["nmcli", "connection", "reload"])
    safe_cmd(["nmcli", "connection", "up", conn_id])

    # Immediately change the MAC using ip link.
    change_mac_ephemeral(interface, new_mac)

    if persistent:
        print("[+] Persistent mode: The new MAC will remain in the nmconnection file.")
    else:
        print("[*] Ephemeral change applied; you can restore later with --restore.")


def restore_original(interface, nm_file):
    """
    Restores the original nm_file from backup and resets the interface MAC.
    """
    if restore_nm_file(nm_file):
        conn_id = get_connection_id(nm_file)
        if conn_id:
            safe_cmd(["nmcli", "connection", "reload"])
            safe_cmd(["nmcli", "connection", "up", conn_id])
        else:
            print("[-] Could not determine connection ID from restored file.")
    restore_interface_mac(interface)


###############################################################################
# 8. Command-line parsing and main entry
###############################################################################


def get_arguments():
    parser = optparse.OptionParser()
    parser.add_option(
        "-i", "--interface", dest="interface", help="Network interface (e.g. enp2s0)"
    )
    parser.add_option(
        "-m",
        "--mac",
        dest="new_mac",
        help="New MAC address. If omitted (and not restoring), a random MAC is generated.",
    )
    parser.add_option(
        "-f",
        "--file",
        dest="nm_file",
        help="Path to the .nmconnection file (default: '/etc/NetworkManager/system-connections/Ethernet connection 1.nmconnection')",
    )
    parser.add_option(
        "-r",
        "--restore",
        action="store_true",
        dest="restore",
        default=False,
        help="Restore original MAC and configuration.",
    )
    parser.add_option(
        "-p",
        "--persistent",
        action="store_true",
        dest="persistent",
        default=False,
        help="Make the change persistent across reboots.",
    )
    opts, _ = parser.parse_args()

    if not opts.interface:
        parser.error("[-] Please specify --interface, e.g. -i enp2s0")
    if not opts.nm_file:
        opts.nm_file = (
            "/etc/NetworkManager/system-connections/Ethernet connection 1.nmconnection"
        )
    if not opts.restore and not opts.new_mac:
        opts.new_mac = generate_random_mac()
        print(f"[+] No --mac provided; generated random MAC: {opts.new_mac}")
    return opts


def main():
    ensure_root()
    opts = get_arguments()

    if opts.restore:
        restore_original(opts.interface, opts.nm_file)
    else:
        apply_new_mac(
            opts.interface, opts.nm_file, opts.new_mac, persistent=opts.persistent
        )


if __name__ == "__main__":
    main()
