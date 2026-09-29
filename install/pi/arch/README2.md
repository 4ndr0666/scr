# Arch Linux On Raspberry Pi4
>O.M.A. provisioned

## 1. Installation

1. Run `provision-gup-pi4.sh` on the bench against an SD car.

2. Identify the SD card **before inserting it into the Pi**:

```bash
\lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
```

3. Provision it:

```bash
sudo ./provision-gup-pi4.sh /dev/sdX
```

Replace `/dev/sdX` with the **actual removable device**. The script intentionally refuses to guess the device.

---

## 2. What this actually establishes

The resulting Pi has:

| Layer                        | Result                         |
| ---------------------------- | ------------------------------ |
| Hardware                     | Raspberry Pi 4                 |
| Architecture                 | AArch64                        |
| OS                           | Arch Linux ARM                 |
| Boot                         | Pi 4 AArch64/U-Boot path       |
| Root FS                      | ext4                           |
| Boot FS                      | FAT32                          |
| Network                      | systemd-networkd DHCP          |
| SSH                          | enabled                        |
| GUP repository               | cloned automatically           |
| Repository bootstrap         | immutable reviewed commit      |
| Golden Units                 | attempted automatically        |
| O.M.A.-1                     | executed automatically         |
| Evidence                     | retained under `oma-evidence/` |
| O.M.A.-2 destructive testing | deliberately **not** automated |

The Pi 4's official power recommendation is 5 V/3 A; inadequate power can produce instability and filesystem corruption, which would contaminate recovery testing. ([Arch Linux ARM][1])

The Pi 4 also has an EEPROM bootloader and supports SD boot directly; USB boot is available when configured in the EEPROM boot order. ([Raspberry Pi][2]) For this certification machine, **SD boot is preferable initially** because it gives us a clean, independently replaceable recovery medium.

---

## 3. First boot

Insert the provisioned SD card into the Pi.

Connect:

* Ethernet
* HDMI if you want console visibility
* keyboard if desired
* adequate Pi 4 power

Do **not** begin O.M.A.-2 fault injection yet.

Arch Linux ARM's Pi 4 instructions use the `alarm` account with `alarm` as the initial password and `root` with `root` as the initial root password; the keyring is initialized after first boot. ([Arch Linux ARM][1])

The provisioning script already schedules the GUP bootstrap, so after networking comes up it will:

1. initialize the Arch Linux ARM keyring;
2. update the base system;
3. install certification tooling;
4. clone `4ndr0666_hyprland`;
5. record repository identity;
6. execute the Golden Units;
7. execute `tests/oma/run-oma1.sh`;
8. retain O.M.A.-1 evidence.

The repository itself requires immutable bootstrap execution rather than executing mutable `main`; the reviewed bootstrap ref is the same `f1468f500a14ef6ff25ff03ddee8a64044c96849` already present in your O.M.A. evidence.

---

## 4. After the Pi boots

Find it from your workstation:

```bash
\ip neigh
```

or from your router's DHCP leases.

Then:

```bash
ssh alarm@PI_ADDRESS
```

On the Pi:

```bash
cd ~/gup/4ndr0666_hyprland

printf '\n===== REPOSITORY =====\n'
git rev-parse HEAD
git status --short

printf '\n===== GOLDEN UNITS =====\n'
bash tests/run-golden-units.sh

printf '\n===== O.M.A.-1 =====\n'
bash tests/oma/run-oma1.sh

printf '\n===== EVIDENCE =====\n'
latest="$(\ls -t oma-evidence/oma1-*.txt | head -n1)"
cat "$latest"

printf '\n===== HASH =====\n'
cat "$latest.sha256"
sha256sum -c "$latest.sha256"
```

If the Golden Unit runner has a different filename in the current checkout, the bootstrap's inventory output will expose it rather than silently pretending that it ran.

---

## 5. Important certification boundary

The Pi gets us past the exact limitation we hit: **we now have an independent machine on which the destructive/recovery class can eventually be exercised**.

But we should not call it O.M.A.-2 merely because a second machine exists.

GUP explicitly defines:

> O.M.A.-1 → machine equivalence matrix
> O.M.A.-2 → O.M.A.-1 + fault injection, interruption, recovery, concurrency, lifecycle
> O.M.A.-3 → independent reproduction
> O.M.A.-4 → O.M.A.-3 + retained evidence + no unresolved CRITICAL/HIGH defects + fail-closed unsupported-state testing.

The current repository inventory you supplied contains only:

```text
tests/oma/run-oma.sh
tests/oma/run-oma1.sh
```

Therefore **there is presently no repository O.M.A.-2 harness to execute**. Inventing one implicitly and calling it certification would violate the GUP evidence rule.

The immediate milestone is therefore:

```text
WORKSTATION
    │
    ├── provision-gup-pi4.sh
    │
    ▼
RASPBERRY PI 4
    │
    ├── Arch Linux ARM AArch64
    ├── immutable GUP bootstrap
    ├── Golden Units
    └── O.M.A.-1
            │
            ▼
      INDEPENDENT BASELINE
            │
            ▼
      O.M.A.-2 HARNESS
      ├── lifecycle
      ├── concurrency
      ├── interruption
      ├── fault injection
      └── recovery
```

That is the concrete next gap: **build the O.M.A.-2 harness against the now-established O.M.A.-1 contract**, rather than pretending the existing two scripts already provide it.

### Sources

* [Arch Linux ARM — Raspberry Pi 4 installation](https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-4?utm_source=chatgpt.com)
* [Raspberry Pi documentation — hardware and boot flow](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html?utm_source=chatgpt.com)
* [4ndr0666_hyprland repository](https://github.com/4ndr0666/4ndr0666_hyprland?utm_source=chatgpt.com)

**Next milestone requiring your feedback:** run the provisioning script through the SD write and first Pi boot. Once the Pi produces its first O.M.A.-1 evidence, provide that evidence/hash output; the next execution step is the **O.M.A.-2 harness implementation**, not another round of baseline diagnosis.

[1]: https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-4?utm_source=chatgpt.com "Raspberry Pi 4 | Arch Linux ARM"
[2]: https://www.raspberrypi.com/documentation/computers/raspberry-pi.html?utm_source=chatgpt.com "Raspberry Pi computer hardware - Raspberry Pi Documentation"
