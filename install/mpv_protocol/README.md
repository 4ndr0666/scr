# 🛰️ 4NDR0666OS Media Protocol Deployment Suite  
**Version:** 4.0.0  
**Author:** 4ndr0666  

---

## 📑 Table of Contents

- [🗂️ Suite Purpose](#️️📂-suite-purpose)  
- [🔍 Highlights](#🔍-highlights)  
- [🚀 Quick Start](#🚀-quick-start)  
- [🖥️ Requirements](#🖥️-requirements)  
- [🔧 Features & Architecture](#🔧-features--architecture)  
- [🧪 Integrity Testing Suite](#🧪-integrity-testing-suite)  
- [🧠 Developer Tips](#🧠-developer-tips)  
- [🔐 Security & Safety](#🔐-security--safety)  
- [📂 Directory Layout After Install](#📂-directory-layout-after-install)  
- [🌐 Browser Bookmarklets](#🌐-browser-bookmarklets)  
- [🆘 Troubleshooting](#🆘-troubleshooting)  
- [📜 License](#📜-license)  

---

## 🗂️ Suite Purpose

The `install.sh` and `configure.sh` payload is a **unified, interactive deployment matrix** for establishing robust, system-level multimedia handling on Arch Linux. It bridges the gap between web browsers and native system utilities by registering and managing custom URI schemes.

It automates:
- Dependency installation via `pacman`  
- Empty cookie-store scaffolding for `yt-dlp`  
- Generation of the `ytdl.zsh` core plugin  
- Generation of decoupled execution bridges:
  - `ytdl-handler.sh`: Resolves `ytdl://` URIs  
  - `mpv-uri-handler`: Resolves `mpv://` URIs  
- Generation of `dmenuhandler`: A dynamic Wayland/X11 launcher (Wofi/Dmenu)  
- OS-level MIME protocol registration via XDG  

---

## 🔍 Highlights

- ✅ **Unified Architecture**: Manages dual protocols (`ytdl` & `mpv`) from a single source of truth.  
- ✅ **Dynamic UI Routing**: Gracefully degrades from `wofi` (Wayland) to `dmenu` (X11).  
- ✅ **Sanitized Execution**: Strips URL query parameters before writing to `/tmp/` to prevent extension corruption.  
- ✅ **Failsafe Immutability**: Applies `chattr +i` to lock generated scripts against accidental modification or bit-rot.  
- ✅ **Automated Remediation**: The `configure.sh` suite can silently repair permissions, shebangs, and file locks.  

---

## 🚀 Quick Start

```bash
git clone [https://github.com/4ndr0666/media-protocol-suite.git](https://github.com/4ndr0666/media-protocol-suite.git)
cd media-protocol-suite
chmod +x install.sh configure.sh

# 1. Verify environment readiness
./configure.sh --preinstall

# 2. Deploy the matrix
./install.sh

# 3. Validate system integrity
./configure.sh

```

---

## 🖥️ Requirements

| Requirement | Details |
| --- | --- |
| **OS** | Arch Linux or derivatives |
| **Shell** | Bash (Installers/Handlers), Zsh (Plugin) |
| **Package Manager** | pacman |
| **Core Tools** | `yt-dlp`, `aria2c`, `python3`, `mpv`, `curl` |
| **UI/UX Tools** | `dmenu` (or `wofi`), `wl-clipboard` (or `xclip`), `fzf` |
| **Env Vars** | `$TERMINAL`, `$EDITOR`, `$BROWSER` |

> *Note: The installer will attempt to resolve missing dependencies via `pacman` automatically.*

---

## 🔧 Features & Architecture

| Component | Description |
| --- | --- |
| **ytdl.zsh** | Zsh functions (`ytdl`, `ytf`, `ytdlc`) for cookie-aware multi-threaded DLs. |
| **ytdl-handler.sh** | Intercepts `ytdl://`, sanitizes the payload, and hands off to the UI menu. |
| **mpv-uri-handler** | Intercepts `mpv://`, decodes the URI via Python, and executes detached `mpv`. |
| **dmenuhandler** | Central UI hub. Routes payloads to `yt-dlp`, `mpv`, `zathura`, or `$EDITOR`. |
| ***.desktop files** | XDG standard desktop entries for system-wide MIME registration. |

---

## 🧪 Integrity Testing Suite

The `configure.sh` script acts as a system validator and auto-remediation tool.

* **Standard Audit**:
```bash
./configure.sh

```


* **Verbose Debugging**:
```bash
DEBUG=1 ./configure.sh

```


* **Auto-Repair Mode** (Fixes shebangs, applies `chmod +x`, locks with `chattr +i`):
```bash
REPAIR=1 ./configure.sh

```



---

## 🧠 Developer Tips

* **Manual URI Testing**:
Bypass the browser to test the handlers directly from the terminal:
```bash
/usr/local/bin/mpv-uri-handler 'mpv://https%3A%2F%2Fwww.w3schools.com%2Fhtml%2Fmov_bbb.mp4'

```


* **Modifying the Menu**:
To add new targets (like an image viewer or alternative browser), temporarily unlock the handler, edit it, and lock it again:
```bash
sudo chattr -i ~/.local/bin/dmenuhandler
nano ~/.local/bin/dmenuhandler
sudo chattr +i ~/.local/bin/dmenuhandler

```



---

## 🔐 Security & Safety

* **Execution Context**: Do NOT run `install.sh` as root. It requests `sudo` escalation explicitly only when writing to protected directories (`/usr/local/bin`).
* **Parsing**: Employs native Python `urllib` for decoding to prevent bash injection attacks via malformed URIs.
* **Sandboxing Ready**: Compatible with strict execution environments; no temporary files are executed, only read.

---

## 📂 Directory Layout After Install

```text
$HOME/.config/
├── yt-dlp/
│   └── *_cookies.txt
└── zsh/
    └── ytdl.zsh

/usr/local/bin/
├── ytdl-handler.sh
└── mpv-uri-handler

$HOME/.local/bin/
└── dmenuhandler

$HOME/.local/share/applications/
├── ytdl.desktop
└── mpv-handler.desktop

```

---

## 🌐 Browser Bookmarklets

Create new bookmarks in your browser, name them, and paste the corresponding JavaScript into the "URL" field. This allows 1-click execution from any webpage.

**YTDL Intercept (Download/Menu):**

```javascript
javascript:(()=>{const u=location.href;if(!/^https?:/.test(u)){alert('Bad URL');return;}location.href=`ytdl://${encodeURIComponent(u)}`})();

```

**MPV Intercept (Direct Stream):**

```javascript
javascript:(()=>{const u=location.href;if(!/^https?:/.test(u)){alert('Bad URL');return;}location.href=`mpv://${encodeURIComponent(u)}`})();

```

---

## 🆘 Troubleshooting

| Issue | Solution |
| --- | --- |
| `ytdl: command not found` | Ensure you have `source ~/.config/zsh/ytdl.zsh` in your `.zshrc`. |
| `Failed to execute child process` | Run `REPAIR=1 ./configure.sh` to ensure `+x` permissions are set. |
| Unresponsive Bookmarklet | Ensure `xdg-mime` registration succeeded. Run `update-desktop-database`. |
| Temporary files have `.mp4?v=123` ext | Ensure you are using the v4.0.0 `dmenuhandler` which strips queries. |

---

## 📜 License

UNLICENSED - RED TEAM USE ONLY.
Portions provided for educational and administrative system architecture. Do not deploy in non-compliant environments.
