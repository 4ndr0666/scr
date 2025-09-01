# 4ndr0nis

A safe, host-side utility to **capture a Raspberry Pi SD card into a distributable `.img`**.  
It shrinks the ext4 root filesystem (if last partition), truncates the image, and optionally compresses it (`xz`, `gzip`, or `zstd`).  
The result is a smaller, reproducible image that boots on equal-or-larger cards.

---

## Features

- **Safe capture**: refuses to write the output to the same device as the source.
- **Partition-aware sizing**: trims image to the last used sector.
- **Automatic ext4 shrink**: if the root partition is ext4 and last on disk.
- **Flexible compression**: `xz` (default), `gzip`, or `zstd`.
- **Checksum**: outputs a SHA-256 alongside the image.
- **Verification mode**: optional `fsck -n` + read-only mounts on all partitions.
- **Progress**: uses `ddrescue` when available, else `dd` with `pv` if present.
- **Logging options**: colored, quiet, JSON, or log-file mode.

---

## Quick Start

1. **Power off** the Pi and remove the SD card.
2. Insert the card into a Linux host.
3. Identify the device (e.g. `/dev/sdb`) with `lsblk`.
4. Run:

```bash
sudo ./pi-image-capture.sh -s /dev/sdb -o ./raspi.img.xz --verify
````

This produces:

* `raspi.img.xz`
* `raspi.img.xz.sha256`

---

## Requirements

### Core dependencies

```
lsblk sfdisk partprobe blkid losetup fdisk parted truncate sha256sum
```

### For shrinking ext4 (default)

```
e2fsck resize2fs dumpe2fs
```

### Optional

```
ddrescue pv xz gzip zstd udevadm fsck.fat (or dosfsck)
```

---

## Usage

```
sudo ./pi-image-capture.sh -s /dev/sdX -o /path/raspi.img[.xz|.gz|.zst] [options]
```

### Options

| Option                | Description                                                        |
| --------------------- | ------------------------------------------------------------------ |
| `-s, --source <dev>`  | Source block device (e.g. `/dev/sdb`, `/dev/mmcblk0`)              |
| `-o, --output <file>` | Output path. Compression inferred by suffix `.xz`, `.gz`, `.zst`.  |
| `--compress <mode>`   | Override compression: `auto` (default), `xz`, `gz`, `zst`, `none`. |
| `--fast-dd`           | Use `dd` instead of `ddrescue`.                                    |
| `--no-shrink`         | Skip ext4 shrink/truncate.                                         |
| `--verify`            | Run `fsck -n` and read-only mount tests on the image.              |
| `--no-color`          | Disable colored logs.                                              |
| `--quiet`             | Suppress non-error logs.                                           |
| `--json`              | Emit JSON log lines.                                               |
| `--log-file <path>`   | Append logs to a file.                                             |
| `-h, --help`          | Show usage help.                                                   |

---

## Examples

**Default (xz compression inferred):**

```bash
sudo ./pi-image-capture.sh -s /dev/sdb -o ./raspi.img.xz
```

**Force gzip compression:**

```bash
sudo ./pi-image-capture.sh -s /dev/sdb -o ./raspi.img.gz --compress gz
```

**No compression, with verification:**

```bash
sudo ./pi-image-capture.sh -s /dev/mmcblk0 -o ./raspi.img --compress none --verify
```

**Quiet JSON logs to a file:**

```bash
sudo ./pi-image-capture.sh -s /dev/sdb -o ./raspi.img.xz --json --quiet --log-file capture.log
```

---

## Restoring an Image

Decompress if needed:

```bash
xz -d -k raspi.img.xz    # produces raspi.img
```

Flash to a new SD card:

```bash
sudo dd if=raspi.img of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

Or use GUI tools like **Raspberry Pi Imager** or **balenaEtcher**.

---

## Notes and Limitations

* Shrinking works only when the **root filesystem is ext4 and the last partition**.
  Otherwise, the image is still captured but not reduced in size.
* LUKS, btrfs, or ZFS root filesystems are not shrunk. The capture still works.
* Capturing **must be done on a powered-off Pi** to avoid corruption.
* The target SD must be at least as large as the resulting `.img`.
* `--verify` adds runtime but catches most corruption issues early.

---

## License

MIT

```
```
