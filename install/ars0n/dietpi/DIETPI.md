# Ars0n Sentinel Node - Genesis Protocol (v2.1 - Battle-Hardened)

## 1. Project Objective

To forge a headless, autonomous, and low-power appliance for persistent, long-term reconnaissance operations. This device, the "Ars0n Sentinel," is engineered for maximum stability, performance, and security. Its function is to serve as a 24/7 foundation for the `ars0n-framework` Docker stack.

This protocol is a battle-tested, two-stage process. **Stage A** uses DietPi automation to build the hardened OS foundation. **Stage B** uses a master installation script to arm the Sentinel with its software payload and configure its systems, eliminating the unreliability of a fully automated software install.

## 2. Phase 0: Ordnance Acquisition

*   **Compute Unit:** Raspberry Pi 4 Model B (8GB RAM variant is mandatory).
*   **Storage Medium:** 64GB+ High-Endurance or Industrial-Grade MicroSD Card.
*   **Power Unit:** Official Raspberry Pi USB-C Power Supply.
*   **Thermal Regulation:** An active cooling solution (e.g., a case with a fan).
*   **OS Image:** Latest 64-bit DietPi image for Raspberry Pi.

## 3. Phase 1, Stage A: Automated Foundation Forging

This stage creates the hardened, networked base operating system.

### Step 1.1: Image Flashing

1.  Download the DietPi image and flash it to the MicroSD card using BalenaEtcher.
2.  Do not eject the card. The `boot` partition must be accessible.

### Step 1.2: Scribing the OS Blueprint (`dietpi.txt`)

This blueprint builds the OS, network, and security layers. Software installation is **intentionally omitted** for reliability. Open the `boot` partition and **replace the entire contents** of `dietpi.txt` with the following.

> **CRITICAL:** You MUST edit `AUTO_SETUP_GLOBAL_PASSWORD` and `AUTO_SETUP_NET_STATIC_*` values before deployment.

```ini
AUTO_SETUP_AUTOMATED=1
AUTO_SETUP_GLOBAL_PASSWORD=YourSuperStrongSecretPassword
AUTO_SETUP_LOCALE=en_US.UTF-8
AUTO_SETUP_KEYBOARD_LAYOUT=us
AUTO_SETUP_TIMEZONE=Etc/UTC
AUTO_SETUP_NET_ETHERNET_ENABLED=0
AUTO_SETUP_NET_WIFI_ENABLED=1
AUTO_SETUP_NET_WIFI_COUNTRY_CODE=US
AUTO_SETUP_NET_USESTATIC=1
AUTO_SETUP_NET_STATIC_IP=192.168.1.10
AUTO_SETUP_NET_STATIC_MASK=255.255.255.0
AUTO_SETUP_NET_STATIC_GATEWAY=192.168.1.1
AUTO_SETUP_NET_STATIC_DNS=1.1.1.1 1.0.0.1
AUTO_SETUP_NET_HOSTNAME=ars0n-sentinel
AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=1
AUTO_SETUP_SWAPFILE_SIZE=1
AUTO_SETUP_SWAPFILE_LOCATION=/var/swap
AUTO_SETUP_HEADLESS=1
CONFIG_SERIAL_CONSOLE_ENABLE=0
AUTO_SETUP_SSH_SERVER_INDEX=-2
AUTO_SETUP_SSH_PUBKEY=ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEP8eBYQVDJmrsVDoqIhJgtxBnNgVLearCQhyWS26zdF 01_dolor.loftier
CONFIG_CPU_GOVERNOR=performance
SOFTWARE_DISABLE_SSH_PASSWORD_LOGINS=1
SURVEY_OPTED_IN=0
```

### Step 1.3: Scribing the Network Credentials (`dietpi-wifi.txt`)

In the same `boot` partition, create a **new file named `dietpi-wifi.txt`**. Populate it with the following.

```ini
aWIFI_SSID='SpectrumSetup-70'
aWIFI_KEY='proudberry319'
aWIFI_KEYMGR='WPA-PSK'
```

### Step 1.4: Deployment & Genesis

1.  Eject the MicroSD card and insert it into the Sentinel Pi.
2.  Ensure no Ethernet cable is connected and apply power.
3.  The device will now undergo its automated genesis (15-30 minutes).
4.  Once complete, connect via SSH from the machine holding the private key:
    `ssh -i /path/to/your/private_key root@192.168.1.10`

## 4. Phase 1, Stage A: Kali Update

Here we update the fresh Kali install.

```bash
sudo apt update && sudo apt-get update
sudo apt -y upgrade && sudo apt-get -y upgrade
wget "https://github.com/R-s0n/ars0n-framework-v2/releases/download/beta-0.0.1/ars0n-framework-v2-beta-0.0.1.zip"
unzip ars0n-framework-v2-beta-0.0.1.zip
cd ars0n-framework
```

---


## 4. Phase 1, Stage B: Scripted Payload Deployment

This stage is executed from the SSH session. Place the `install.sh` and `Makefile` from this repository into the `/root` directory of the Sentinel.

### Step 1.5: Execute the Master Installation Script

Make the script executable and run it. This script handles all subsequent software installation and configuration.

```bash
chmod +x install.sh
./install.sh
```

The script will perform the following actions:
1.  **Interrogate the System:** Dynamically finds the correct DietPi software IDs for all required packages.
2.  **Install Payload:** Installs Docker, Docker Compose, PostgreSQL, Redis, and Git.
3.  **Harden PostgreSQL:** Executes the authoritative `ALTER SYSTEM` and `pg_hba.conf` modifications required for network functionality.
4.  **Acquire Framework:** Clones the `ars0n-framework-v2` repository into `/opt/ars0n-framework`.
5.  **Configure Environment:** Creates the necessary `.env` file and a `docker-compose.override.yml` to seize Port 80.
6.  **Create and Enable Autostart Service:** Forges a resilient `systemd` service to ensure the framework starts on boot.
7.  **Ignition:** Builds and launches the Docker stack for the first time.

## 5. Day-to-Day Operations (`Makefile`)

The `Makefile` is your primary tool for managing the Sentinel's services from within the `/opt/ars0n-framework` directory.

-   **Start the framework:** `make up`
-   **Stop the framework:** `make down`
-   **View live logs:** `make logs`
-   **Check container status:** `make ps`
-   **Restart the stack:** `make restart`
-   **Clean up unused Docker resources:** `make clean`

## 6. Final System Verification

After the `install.sh` script completes, reboot (`sudo reboot`) and then verify.

1.  **Verify Core Services:**
    `docker --version && docker compose version && systemctl status redis-server`

2.  **Verify PostgreSQL Network Readiness (Absolute Proof):**
    `pg_isready -h 127.0.0.1 -p 5432`
    *   *Expected Output: `127.0.0.1:5432 - accepting connections`*

3.  **Verify `ars0n-framework` Autostart:**
    `systemctl status ars0n.service`
    *   *Expected output is a green `active (running)` status.*

4.  **Confirm Web Interface Access:** Open a web browser on a machine on the same network and navigate to `http://<SENTINEL_IP>`. The `ars0n-framework` interface should be visible.

## Conclusion

The Genesis Protocol is complete. The Ars0n Sentinel is forged, armed, and fully operational.
