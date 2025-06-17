#!/usr/bin/env python3
import subprocess


def log_and_print(message, level="info"):
    print(f"[{level.upper()}] {message}")


# Step 1: Calculate 25% of total memory
mem_total_cmd = "awk '/MemTotal/ {print int($2 * 1024 * 0.25)}' /proc/meminfo"
mem_total_output = subprocess.check_output(mem_total_cmd, shell=True).strip()
log_and_print(f"Memory calculation output: {mem_total_output}", "info")
mem_total = int(mem_total_output)
log_and_print(f"Calculated ZRam size: {mem_total} bytes", "info")

# Step 2: Check if an existing zram device is available or create one
try:
    log_and_print("Attempting to find an existing zram device...", "info")
    zram_device = subprocess.run(
        ["sudo", "zramctl", "--find", "--size", str(mem_total)],
        stdout=subprocess.PIPE,
        text=True,
        check=True,
    ).stdout.strip()
    log_and_print(f"Using existing zram device: {zram_device}", "info")
except subprocess.CalledProcessError:
    log_and_print("No free zram device found. Creating a new one...", "info")
    subprocess.run(["sudo", "modprobe", "zram"], check=True)
    zram_device = subprocess.run(
        ["sudo", "zramctl", "--find", "--size", str(mem_total)],
        stdout=subprocess.PIPE,
        text=True,
        check=True,
    ).stdout.strip()
    log_and_print(f"Created new zram device: {zram_device}", "info")

# Step 3: Set up the zram device as swap
log_and_print(f"Setting up {zram_device} as swap...", "info")
subprocess.run(["sudo", "mkswap", zram_device], check=True)
subprocess.run(["sudo", "swapon", zram_device, "-p", "32767"], check=True)
log_and_print(f"ZRam device {zram_device} is set as swap.", "info")
