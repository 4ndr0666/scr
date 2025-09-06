# 🛡️ Brave Unified Wrapper & Systemd Installer

## 📖 Overview

This project provides a **single, self-contained installer script** that sets up:

* An **argv0-aware Brave wrapper** (`brave-wrapper`) that keeps
  `~/.config/brave-flags.conf` canonical and optimized for **low-RAM systems**.
* Symlinks: `brave`, `brave-beta`, `brave-nightly` → wrapper.
* A **systemd service unit** (global or per-user) to auto-launch Brave with managed flags.
* Full **idempotency**: safe to run repeatedly without duplication or corruption.

---

## ⚡ Key Features

* **Hardware acceleration aware**: auto-enables GPU rasterization only if GPU is usable.
* **Minimal RAM profile**: disables unnecessary features, enforces memory purges.
* **Self-healing flags**: guarantees exactly one `--enable-features` and `--disable-features`.
* **System-wide or per-user install**:

  * Global (`--global`): installs to `/usr/lib/systemd/user` (requires root).
  * Per-user (`--user`): installs to `~/.config/systemd/user`.
* **Environment overrides**:

  * `PREFIX=/opt/local` → install wrapper to `/opt/local/bin`.
  * `AUTO_ENABLE=0` → install systemd unit without enabling.
  * `BRAVE_ENV="KEY=VAL …"` → inject runtime environment into systemd unit.

---

## 🚀 Installation

### Global Install (default)

```bash
sudo ./brave-install.sh --global install
```

Installs wrapper to `/usr/local/bin`, creates symlinks, and places
systemd *user* unit in `/usr/lib/systemd/user`.

Enable service:

```bash
sudo systemctl --global enable brave.service
```

### Per-User Install

```bash
./brave-install.sh --user install
```

Installs wrapper in `/usr/local/bin`, creates symlinks, and places
systemd *user* unit in `~/.config/systemd/user`.

Enable service:

```bash
systemctl --user enable --now brave.service
```

---

## 🧹 Uninstallation

Remove wrapper, symlinks, and all service units:

```bash
sudo ./brave-install.sh --global uninstall
```

or

```bash
./brave-install.sh --user uninstall
```

Alias:

```bash
./brave-install.sh clean
```

---

## ⚙️ Wrapper Behavior

* Executable name (`argv0`) determines which Brave binary to call:

  * `brave` → `/usr/bin/brave`
  * `brave-beta` → `/usr/bin/brave-beta`
  * `brave-nightly` → `/usr/bin/brave-nightly`
* Before launching, wrapper ensures `~/.config/brave-flags.conf` is:

  * Deduplicated and sorted.
  * Populated with tuned flags:

    * ✅ `--disable-crash-reporter`
    * ✅ `--disk-cache-size=104857600`
    * ✅ `--extensions-process-limit=1`
    * ✅ `--ozone-platform=wayland`
    * ✅ `--allowlisted-extension-id=clngdbkpkpeebahjckkjfobafhncgmne`
  * With managed feature sets:

    * **Enable**: `DefaultSiteInstanceGroups`, `InfiniteTabsFreeze`,
      `MemoryPurgeOnFreezeLimit`, (`UseGpuRasterization`, `ZeroCopy` if HW accel).
    * **Disable**: `BackForwardCache`, `SmoothScrolling`.
  * Resolves conflicts automatically: if a feature is in both enable & disable, **disable wins**.

---

## 🌍 Systemd Integration

### Global User Service

* Installed to `/usr/lib/systemd/user/brave.service`
* Managed with:

  ```bash
  sudo systemctl --global enable --now brave.service
  sudo systemctl --global disable brave.service
  ```

### Per-User Service

* Installed to `~/.config/systemd/user/brave.service`
* Managed with:

  ```bash
  systemctl --user enable --now brave.service
  systemctl --user disable --now brave.service
  ```

### Environment Injection

Values from `BRAVE_ENV` are passed as `Environment=` lines in the service file.
Example:

```bash
BRAVE_ENV="BRAVE_LOW_ISOLATION=0 BRAVE_EXTRA_FLAGS=--new-window"
```

---

## 📌 Reference

For a full list of **Brave and Chromium flags** (including Arch Linux integration, deprecated flags, and automation practices), see:

📄 [Canonical Brave Flags Reference](./brave_flags_refference.md)

---

## ✅ Quick Commands

### Install globally (root):

```bash
sudo ./brave-install.sh --global install
```

### Install per-user:

```bash
./brave-install.sh --user install
```

### Uninstall (alias `clean`):

```bash
sudo ./brave-install.sh --global clean
```
