# 🛰️ YTDLC Protocol Installer  
**Version:** 1.1.0  
**Author:** 4ndr0666  

---

## 📑 Table of Contents

- [🗂️ Script Purpose](#️️📂-script-purpose)  
- [🔍 Highlights](#🔍-highlights)  
- [🚀 Quick Start](#🚀-quick-start)  
- [🖥️ Requirements](#🖥️-requirements)  
- [🔧 Features](#🔧-features)  
- [🧪 Testing Suite](#🧪-testing-suite)  
- [🧠 Developer Tips](#🧠-developer-tips)  
- [🔐 Security & Safety](#🔐-security--safety)  
- [📂 Directory Layout After Install](#📂-directory-layout-after-install)  
- [🌐 Bookmarklet](#🌐-bookmarklet)  
- [🆘 Troubleshooting](#🆘-troubleshooting)  
- [🤝 Contributing](#🤝-contributing)  
- [📜 License](#📜-license)  
- [🎉 Thanks](#🎉-thanks)  

---

## 🗂️ Script Purpose

`install_ytdlc.sh` is a **modular, interactive shell installer** for a robust multimedia download framework on Arch Linux. It automates:

- Dependency installation via `pacman`  
- Cookie-store setup for `yt-dlp`  
- Generation of:
  - `ytdl.zsh`: cookie-aware download functions for Zsh  
  - `ytdl-handler.sh`: `ytdl://` URI launcher  
  - `dmenuhandler`: dynamic Dmenu-based media launcher  
  - `ytdl.desktop`: custom protocol registration  
- Bookmarklet for 1-click browser downloads

---

## 🔍 Highlights

- ✅ **Modular & XDG-compliant**  
- ✅ **Automatic dependency management**  
- ✅ **Failsafe design with `chattr +i` locking**  
- ✅ **Comprehensive test suite with `--repair` support**  
- 🎨 **Color-coded feedback & spinner animations**  
- 🛠️ **Production-ready, no placeholders**

---

## 🚀 Quick Start

```bash
git clone https://github.com/youruser/ytdlc-installer.git
cd ytdlc-installer
chmod +x install_ytdlc.sh test_ytdlc.sh
./install_ytdlc.sh
```

---

## 🖥️ Requirements

| Requirement        | Details                                                      |
|--------------------|--------------------------------------------------------------|
| **OS**             | Arch Linux or derivatives                                    |
| **Shell**          | Zsh                                                          |
| **Package Manager**| pacman                                                       |
| **Tools**          | `yt-dlp`, `aria2c`, `jq`, `dmenu`, `wl-clipboard` or `xclip`|
| **Optional**       | `fzf`, `mpv`, `zathura`, `lynx`, `nsxiv`                    |
| **Env Vars**       | `$TERMINAL`, `$EDITOR`, `$BROWSER`                           |

> All required packages are installed automatically if missing.

---

## 🔧 Features

| Component             | Description                                                           |
|-----------------------|-----------------------------------------------------------------------|
| **ytdl.zsh**          | Zsh functions: `ytdl`, `ytf`, `ytdlc` with cookie support            |
| **ytdl-handler.sh**   | Protocol handler: decodes `ytdl://` URIs, calls `dmenuhandler`       |
| **dmenuhandler**      | Dmenu menu: launch `ytf`, `mpv`, `queue` actions on URLs/files       |
| **ytdl.desktop**      | MIME registration for `x-scheme-handler/ytdl`                        |
| **Bookmarklet**       | One-click browser integration for any page                           |
| **Hardening**         | Uses `chattr +i` to lock generated scripts against accidental edits   |

---

## 🧪 Testing Suite

After install, verify with:

```bash
chmod +x test_ytdlc.sh
./test_ytdlc.sh
```

- **Debug mode**:  
  ```bash
  DEBUG=1 ./test_ytdlc.sh
  ```
- **Auto-repair** (fix shebangs, perms, version tags, immutability):  
  ```bash
  REPAIR=1 ./test_ytdlc.sh
  ```

---

## 🧠 Developer Tips

- **Manual URI test**:  
  ```bash
  ytdl-handler.sh 'ytdl://https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdQw4w9WgXcQ'
  ```
- **Customize `dmenuhandler`**:  
  Edit `$HOME/.local/bin/dmenuhandler`—it’s pure shell script.
- **Temporarily unlock files**:  
  ```bash
  sudo chattr -i /usr/local/bin/ytdl-handler.sh
  ```

---

## 🔐 Security & Safety

- **Do NOT** run the installer as root.  
- Uses `sudo` internally only when needed.  
- Generated files are locked with `chattr +i` to prevent tampering.  

---

## 📂 Directory Layout After Install

```
$HOME/.config/
├── yt-dlp/
│   └── *.cookies.txt
└── zsh/
    └── ytdl.zsh

/usr/local/bin/
└── ytdl-handler.sh

$HOME/.local/bin/
└── dmenuhandler

$HOME/.local/share/applications/
└── ytdl.desktop
```

---

## 🌐 Bookmarklet

Save this as a browser bookmark named **YTF**:

```javascript
javascript:(()=>{const u=location.href;if(!/^https?:/.test(u)){alert('bad URL');return;}location.href=`ytdl://${encodeURIComponent(u)}`})();
```

---

## 🆘 Troubleshooting

| Issue                          | Solution                                                 |
|-------------------------------|----------------------------------------------------------|
| `ytdl: command not found`     | Ensure you sourced `ytdl.zsh` in your `~/.zshrc`         |
| `dmenu not found`             | Install `dmenu` or set `DEBUG=1` to trace issues         |
| `xdg-mime` registration error | Re-run `register_xdg` function or `update-desktop-database` |

---

## 🤝 Contributing

1. Fork this repo  
2. Make enhancements (Arch-specific!)  
3. Submit a PR—fully implemented, no placeholders  

---

## 📜 License

MIT License. Do anything with it—just don’t ship bugs.

---

## 🎉 Thanks

Built by **4ndr0666** for power users desiring seamless multimedia downloads🧪📦  
Happy scripting!  
