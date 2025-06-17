#!/bin/python3

import os
import subprocess
import sys
from datetime import datetime

LOG_FILE = "/var/log/audio_troubleshooting.log"
BACKUP_DIR = "/var/recover"
CONFIG_FILES = [
    "~/.config/pulse/default.pa",
    "~/.config/mpv/mpv.conf",
    "~/.mplayer/config",
    "/etc/modprobe.d/alsa-base.conf",
    "/etc/modules-load.d/",
]
REQUIRED_MODULES = [
    "snd_hda_intel",
    "snd_hda_codec_realtek",
    "snd_intel_dspcfg",
    "snd_pcm",
]

# --- // Auto-escalate privileges if not running as root
if os.geteuid() != 0:
    try:
        print("Attempting to escalate privileges...")
        subprocess.check_call(["sudo", sys.executable] + sys.argv)
        sys.exit()
    except subprocess.CalledProcessError as e:
        print(f"Error escalating privileges: {e}")
        sys.exit(e.returncode)


# Function to log messages
def log_message(message, level="INFO"):
    try:
        log_entry = f"[{level}] {datetime.now()} - {message}"
        print(log_entry)
        with open(LOG_FILE, "a") as log_file:
            log_file.write(log_entry + "\n")
    except PermissionError as e:
        print(f"[ERROR] Permission denied when writing to log file: {e}")


# Function to execute shell commands and handle errors
def execute_command(command, sudo=False):
    try:
        if sudo:
            command = "sudo " + command
        result = subprocess.run(
            command, check=True, shell=True, capture_output=True, text=True
        )
        log_message(f"Command executed successfully: {command}")
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        log_message(f"Error running command '{command}': {e}", level="ERROR")
        return None


# Function to verify if a kernel module is loaded
def verify_module(module):
    """Check if a kernel module is loaded."""
    result = subprocess.run(
        f"lsmod | grep {module}", shell=True, capture_output=True, text=True
    )
    if result.returncode == 0:
        log_message(f"Module {module} is loaded.")
        return True
    else:
        log_message(f"Module {module} is not loaded.", level="WARNING")
        return False


# Function to load required kernel modules
def load_kernel_modules():
    """Load required kernel modules for audio."""
    log_message("Loading required kernel modules...")
    for module in REQUIRED_MODULES:
        if not verify_module(module):
            log_message(f"Attempting to load module {module}...")
            if not execute_command(f"modprobe {module}", sudo=True):
                log_message(f"Failed to load module {module}.", level="ERROR")
            else:
                log_message(f"Module {module} loaded successfully.")
    log_message("Module loading process completed.")


# Function to create modprobe configuration for automatic module loading
def create_modprobe_config():
    """Create a modprobe configuration file to ensure automatic loading of modules."""
    config_file = "/etc/modprobe.d/sound.conf"
    try:
        with open(config_file, "w") as conf:
            conf.write(
                """
# Ensure snd_hda_intel and related modules are loaded after boot
install snd_hda_intel /sbin/modprobe --ignore-install snd_hda_intel && /sbin/modprobe snd_intel_dspcfg
install snd_hda_codec_realtek /sbin/modprobe --ignore-install snd_hda_codec_realtek && /sbin/modprobe snd_pcm
            """
            )
        log_message(f"Modprobe configuration written to {config_file}")
    except PermissionError as e:
        log_message(f"Failed to write modprobe configuration: {e}", level="ERROR")


# Function to restart audio services (PipeWire or PulseAudio)
def restart_audio_services():
    """Restart the active audio service (PipeWire or PulseAudio)."""
    services = {"pipewire": ["pipewire", "wireplumber"], "pulseaudio": ["pulseaudio"]}

    for service in services.keys():
        result = execute_command(f"systemctl --user is-active {service}")
        if result == "active":
            log_message(f"{service} is active. Restarting services...")
            for subservice in services[service]:
                if execute_command(
                    f"systemctl --user restart {subservice}", sudo=False
                ):
                    log_message(f"Restarted {subservice} successfully.")
                else:
                    log_message(f"Failed to restart {subservice}.", level="ERROR")
            return  # Exit after restarting the active service

    log_message("Neither PipeWire nor PulseAudio is running.", level="WARNING")


# Function to test audio output
def test_audio_output():
    """Test audio output by playing a test sound."""
    test_sound = "/usr/share/sounds/alsa/Front_Center.wav"
    if not os.path.exists(test_sound):
        log_message(f"Test sound file not found at {test_sound}", level="ERROR")
        return False
    if execute_command(f"aplay {test_sound}"):
        log_message("Audio test completed successfully. You should hear the sound.")
        return True
    else:
        log_message("Audio test failed.", level="ERROR")
        return False


# Function to check and install system updates
def check_for_updates():
    """Check for available system updates and install them."""
    log_message("Checking for available package updates...")
    if not execute_command("sudo pacman -Sy", sudo=True):
        log_message("Failed to refresh package database.", level="ERROR")
        return
    updates = execute_command("pacman -Qu")
    if updates:
        log_message(f"Updates available: {updates}")
        if execute_command("sudo pacman -Syu --noconfirm", sudo=True):
            log_message("All updates installed successfully.")
        else:
            log_message("Failed to install some or all updates.", level="ERROR")
    else:
        log_message("No updates available. The system is up to date.")


# Function to back up configuration files before and after changes
def backup_config_files(stage="pre"):
    """Back up configuration files before and after changes."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_stage_dir = f"{BACKUP_DIR}/{stage}_backup_{timestamp}"
    if not os.path.exists(BACKUP_DIR):
        execute_command(f"sudo mkdir -p {BACKUP_DIR}", sudo=True)

    log_message(f"Backing up configuration files to {backup_stage_dir}")
    for config_file in CONFIG_FILES:
        config_file = os.path.expanduser(config_file)  # Expand ~ to the home directory
        if os.path.exists(config_file):
            execute_command(f"sudo cp -r {config_file} {backup_stage_dir}", sudo=True)
            log_message(f"Backed up {config_file}")
        else:
            log_message(
                f"Config file {config_file} not found. Skipping.", level="WARNING"
            )


# Function to restore configuration files from the most recent backup
def restore_config_files():
    """Restore configuration files from the most recent backup."""
    backups = sorted(
        [f for f in os.listdir(BACKUP_DIR) if "post_backup" in f], reverse=True
    )
    if not backups:
        log_message(
            "No recent backup found. Cannot restore configuration.", level="ERROR"
        )
        return
    latest_backup = f"{BACKUP_DIR}/{backups[0]}"
    log_message(f"Restoring configuration files from {latest_backup}")
    for config_file in os.listdir(latest_backup):
        original_location = os.path.basename(config_file)
        execute_command(
            f"sudo cp -r {latest_backup}/{config_file} {original_location}", sudo=True
        )
        log_message(f"Restored {original_location}")


# Function to rebuild initramfs (if mkinitcpio or dracut is detected)
def rebuild_initramfs():
    """Rebuild initramfs to apply changes to the system."""
    if execute_command("which mkinitcpio"):
        log_message("Detected mkinitcpio. Rebuilding initramfs...")
        execute_command("sudo mkinitcpio -P", sudo=True)
    elif execute_command("which dracut"):
        log_message("Detected dracut. Rebuilding initramfs...")
        execute_command("sudo dracut --force", sudo=True)
    else:
        log_message(
            "Neither mkinitcpio nor dracut detected. Cannot rebuild initramfs.",
            level="ERROR",
        )


# Function to install missing dependencies
def install_missing_dependencies(dependencies):
    """Install missing dependencies dynamically."""
    for dep in dependencies:
        if execute_command(f"pacman -Q {dep}"):
            log_message(f"Dependency {dep} is already installed.")
        else:
            log_message(f"Installing missing dependency: {dep}")
            if not execute_command(f"sudo pacman -S --needed {dep}", sudo=True):
                log_message(f"Failed to install {dep}", level="ERROR")


# Function to enhance the selected audio service
def enhance_audio_service():
    """Enhance the selected audio service by offering packages for installation."""
    services = {
        "pipewire": [
            "pipewire-alsa",
            "pipewire-pulse",
            "pipewire-jack",
            "wireplumber",
            "helvum",
            "qjackctl",
        ],
        "pulseaudio": ["pavucontrol", "pulseaudio-ctl", "pulsemixer"],
    }

    active_service = None
    if execute_command("systemctl --user is-active pipewire") == "active":
        active_service = "pipewire"
    elif execute_command("systemctl --user is-active pulseaudio") == "active":
        active_service = "pulseaudio"

    if active_service:
        log_message(f"Enhancing the {active_service} service...")
        packages = services[active_service]
        for package in packages:
            install_missing_dependencies([package])
    else:
        log_message(
            "Neither PipeWire nor PulseAudio is running. Cannot offer enhancements.",
            level="WARNING",
        )


# Function to create a custom SystemD service for loading modules
def create_systemd_service():
    """Create a custom SystemD service to load sound modules at boot."""
    service_file = "/etc/systemd/system/load-sound-modules.service"
    log_message(f"Creating SystemD service at {service_file}...")
    service_content = """
[Unit]
Description=Load Sound Modules

[Service]
Type=oneshot
ExecStart=/sbin/modprobe snd_hda_intel snd_intel_dspcfg snd_hda_codec_realtek snd_pcm snd_hda_core

[Install]
WantedBy=multi-user.target
"""
    try:
        with open(service_file, "w") as service:
            service.write(service_content)
        execute_command("sudo systemctl enable load-sound-modules.service")
        log_message(f"SystemD service {service_file} created and enabled.")
    except PermissionError as e:
        log_message(f"Failed to create SystemD service: {e}", level="ERROR")


# Function to manually select the audio service (PipeWire or PulseAudio)
def select_audio_service():
    """Manually select and configure audio service (PipeWire or PulseAudio)."""
    log_message("Selecting and configuring audio service...")

    choice = input("Choose audio service:\n1. PipeWire\n2. PulseAudio\nEnter 1 or 2: ")

    if choice == "1":
        # Install and configure PipeWire
        log_message("Configuring PipeWire...")
        install_missing_dependencies(
            ["pipewire", "pipewire-alsa", "pipewire-pulse", "wireplumber"]
        )
        execute_command("systemctl --user disable pulseaudio.service --now", sudo=True)
        execute_command("systemctl --user enable --now pipewire wireplumber", sudo=True)
        log_message("PipeWire configured successfully.")
    elif choice == "2":
        # Install and configure PulseAudio
        log_message("Configuring PulseAudio...")
        install_missing_dependencies(["pulseaudio", "pavucontrol"])
        execute_command("systemctl --user disable pipewire.service --now", sudo=True)
        execute_command("systemctl --user enable --now pulseaudio", sudo=True)
        log_message("PulseAudio configured successfully.")
    else:
        log_message("Invalid choice. No changes made.", level="ERROR")


# Function to restart PulseAudio with custom default.pa handling
def restart_pulseaudio_with_backup():
    """Rename default.pa to default.pa.bak and restart PulseAudio."""
    pulse_config_dir = os.path.expanduser("~/.config/pulse")
    default_pa = os.path.join(pulse_config_dir, "default.pa")
    backup_pa = os.path.join(pulse_config_dir, "default.pa.bak")

    if os.path.exists(default_pa):
        # Backup default.pa to default.pa.bak
        log_message(f"Backing up {default_pa} to {backup_pa}")
        execute_command(f"mv {default_pa} {backup_pa}")

        # Restart PulseAudio with verbose logging
        log_message("Restarting PulseAudio with verbose logging...")
        execute_command("pulseaudio -k && pulseaudio -vvvvv")
        log_message("PulseAudio restarted with verbose logging.")
    else:
        log_message(f"{default_pa} not found. No changes made.", level="WARNING")


# Function to run full automated troubleshooting
def run_automated_troubleshooting():
    """Run the full automated troubleshooting process."""
    log_message("Running full automated troubleshooting process...")

    # Check and load kernel modules
    load_kernel_modules()

    # Restart audio services
    restart_audio_services()

    # Check for system updates
    check_for_updates()

    # Test audio output
    test_audio_output()

    # Rebuild initramfs (if necessary)
    rebuild_initramfs()

    log_message("Automated troubleshooting process completed.")


# Function to install and invoke needrestart for handling reboots or service restarts
def install_needrestart():
    """Install and run needrestart for managing system reboots after updates."""
    log_message("Installing needrestart from the AUR...")
    if not execute_command("command -v needrestart"):
        if execute_command("command -v yay"):
            execute_command("yay -S --noconfirm needrestart")
        elif execute_command("command -v paru"):
            execute_command("paru -S --noconfirm needrestart")
        else:
            log_message(
                "[ERROR] AUR helper not found. Please install needrestart manually.",
                level="ERROR",
            )
            return
    else:
        log_message("needrestart is already installed.")

    # Run needrestart
    log_message(
        "Running needrestart to check for reboot or service restart requirements..."
    )
    execute_command("sudo needrestart")


# Interactive main menu
def main_menu():
    """Display the main menu and handle user selection."""
    while True:
        print("\n" + "=" * 50)
        print("AUDIO TROUBLESHOOTING TOOL")
        print("=" * 50)
        print("1. Load Required Kernel Modules")
        print("2. Restart Audio Services")
        print("3. Test Audio Output")
        print("4. Create Modprobe Configuration")
        print("5. Check for System Updates")
        print("6. Backup Configuration Files")
        print("7. Restore Configuration Files")
        print("8. Rebuild Initramfs")
        print("9. Install/Reboot via needrestart")
        print("10. Enhance Audio Service")
        print("11. Create SystemD Service for Audio Modules")
        print("12. Run Full Automated Troubleshooting")
        print("13. Select Audio Service")
        print("14. Restart PulseAudio with Backup of default.pa")
        print("15. Exit")
        print("=" * 50)
        choice = input("Select an option: ")

        if choice == "1":
            load_kernel_modules()
        elif choice == "2":
            restart_audio_services()
        elif choice == "3":
            test_audio_output()
        elif choice == "4":
            create_modprobe_config()
        elif choice == "5":
            check_for_updates()
        elif choice == "6":
            backup_config_files()
        elif choice == "7":
            restore_config_files()
        elif choice == "8":
            rebuild_initramfs()
        elif choice == "9":
            install_needrestart()
        elif choice == "10":
            enhance_audio_service()
        elif choice == "11":
            create_systemd_service()
        elif choice == "12":
            run_automated_troubleshooting()
        elif choice == "13":
            select_audio_service()
        elif choice == "14":
            restart_pulseaudio_with_backup()
        elif choice == "15":
            log_message("Exiting the tool.")
            sys.exit(0)
        else:
            log_message("Invalid selection, please try again.", level="WARNING")


# Run the tool
if __name__ == "__main__":
    main_menu()
