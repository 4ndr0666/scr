# Arch Raspberry Pi 4 
>OMA provisioned

## Usage

### 1. Put the Pi on the bench

Required:

* Raspberry Pi 4
* microSD card dedicated to this test machine
* Ethernet cable
* **3A-capable Pi power supply**
* Linux workstation with the SD card reader

The 3A requirement matters here: Arch Linux ARM specifically warns that inadequate Pi 4 power can produce filesystem corruption, which would contaminate recovery-test results. ([Arch Linux ARM][1])

### 2. Identify the SD card

Do **not** guess `/dev/sdX`.

Run:

```bash
\lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL,SERIAL
```

Prefer the stable `/dev/disk/by-id/...` path.

Example:

```bash
\ls -l /dev/disk/by-id/
```

### 3. Run the provisioner

```bash
chmod +x oma-rpi4-provision.sh

sudo ./oma-rpi4-provision.sh \
    /dev/disk/by-id/usb-YOUR_RASPBERRY_PI_SD_CARD
```

The script has **two destructive confirmations** before touching the card.

It then owns the entire SD provisioning process.

### 4. Boot the Pi

The script will eventually stop waiting for the Pi to appear.

At that point:

1. Safely eject the SD card.
2. Put it in the Pi.
3. Connect Ethernet.
4. Connect the 3A power supply.
5. Power it on.
6. Let it boot.

The official AArch64 installation uses the mainline kernel/U-Boot path and the Raspberry Pi 3/4 AArch64 rootfs. ([Arch Linux ARM][1])

The provisioner handles the Pi-specific `mmcblk0` → `mmcblk1` correction required by the official instructions. ([Arch Linux ARM][1])

### 5. The script takes over again

It discovers/waits for SSH and performs:

```text
Arch first boot
    ↓
pacman keyring
    ↓
system update
    ↓
base-devel / git / rsync / sudo / tmux
    ↓
GUP repository clone
    ↓
Golden Units
    ↓
O.M.A. inventory
    ↓
O.M.A. verification
    ↓
O.M.A.-1
    ↓
machine evidence + SHA-256
```

Arch Linux ARM's current documentation explicitly requires initializing and populating its package-signing keyring after first boot; the current package-signing documentation also documents the Arch Linux ARM keyring model. ([Arch Linux ARM][1])

## What this deliberately does **not** do

There is an important boundary here.

The Pi becomes:

> **O.M.A.-2 disposable recovery target**

but the script does **not** suddenly start simulating power failure.

That would conflate **machine provisioning** with **adversarial testing**.

Your repository's own O.M.A. definition says:

> O.M.A.-2 = matrix + fault injection, interruption, recovery, lifecycle, and concurrency testing.

And it explicitly requires destructive interruption/recovery testing to use a dedicated/disposable recovery machine. 

So after this script succeeds, we have:

```text
                         theworkpc
                            │
                 development/certification
                            │
                  ┌─────────┴─────────┐
                  │                   │
             GUP source          O.M.A.-1
                  │
                  │ SSH
                  ▼
             Raspberry Pi 4
          disposable recovery host
                  │
          ┌───────┴────────┐
          │                │
    safe O.M.A.-2     destructive O.M.A.-2
    lifecycle/etc.      interruption
          │                │
          └───────┬────────┘
                  ▼
             recovery proof
```

### Why the Pi is useful even though it isn't a Hyprland desktop

That is intentional.

The O.M.A.-2 recovery machine's value is primarily in testing **transactional and recovery behavior**, not reproducing the exact graphical hardware of `theworkpc`.

Your existing GUP suite already contains substantial lifecycle coverage, including Cava, portal, SwayNC, refresh, detection, keyboard-layout, wallpaper-effect, theme, and runtime orchestration tests. 

The Pi gives us an isolated machine on which we can safely introduce the classes of failure that should **not** be introduced into `theworkpc`.

## One adjustment before we actually execute this

I would make **one repository-side change after the Pi's O.M.A.-1 baseline passes**:

```text
tests/oma/
├── run-oma.sh
├── run-oma1.sh
├── run-oma2.sh
└── lib/
    ├── evidence.sh
    ├── lifecycle.sh
    ├── concurrency.sh
    ├── interruption.sh
    └── recovery.sh
```

That gives O.M.A.-2 an actual executable harness rather than having the Pi merely serve as an isolated shell machine.

The existing repository currently has only `run-oma.sh` and `run-oma1.sh`; the documented O.M.A.-2 level exists conceptually, but the repository-side harness still needs to be constructed. 

**So the immediate operation is now unambiguous:** run the single provisioner above against the dedicated SD card. The first hard milestone is **Pi boot + GUP 76/76 + O.M.A.-1 PASS on the Pi**. After that, the next repository work is the actual `run-oma2.sh` adversarial harness, not another manual provisioning procedure.

[1]: https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-4?utm_source=chatgpt.com "Raspberry Pi 4 | Arch Linux ARM"
[2]: https://archlinuxarm.org/about/downloads?utm_source=chatgpt.com "Downloads | Arch Linux ARM"

## Architecture

>That matches the repository's documented distinction: O.M.A.-1 is the machine matrix; O.M.A.-2 adds fault injection, interruption, recovery, lifecycle, and concurrency; destructive interruption belongs on a disposable recovery machine. 
**End-to-end disposable O.M.A.-2 recovery machine bootstrap**.

It will:

1. Download the official Arch Linux ARM RPi 3/4 AArch64 rootfs.
2. Verify the downloaded archive.
3. Identify and require explicit confirmation of the SD card.
4. Wipe/repartition it.
5. Create FAT32 + ext4.
6. Install Arch Linux ARM.
7. Apply the RPi4-specific AArch64 `/etc/fstab` correction.
8. Configure hostname, networking, SSH, and a dedicated O.M.A. test account.
9. Boot the Pi.
10. Discover its DHCP address.
11. Finish first-boot configuration over SSH.
12. Clone `4ndr0666_hyprland`.
13. Establish the GUP prerequisite environment.
14. Run the Golden Units.
15. Run O.M.A.-1.
16. Capture/hash evidence.
17. Prepare the machine for **O.M.A.-2 non-destructive testing**.
18. Stop before destructive fault injection and require the explicit recovery-machine gate.
