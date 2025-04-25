# 🛰️ YTDLC Protocol Installer  
**Version:** 1.0.0  
**Author:** 4ndr0666

---

## 🗂️ Script Purpose

This script, `install_ytdlc.sh`, is a **modular and interactive shell-based installer** for a complete multimedia download framework using `yt-dlp`, with rich cookie management, URI scheme integration, and dynamic launcher support via `dmenu`.

It provides:

- Automatic setup of dependencies, cookie paths, launcher scripts
- System protocol integration for `ytdl://` URLs
- A user-friendly, clipboard-aware download menu
- Bookmarklet integration for 1-click downloading from any browser

Targeted toward advanced **Arch Linux** users who value flexibility, XDG compliance, and control.

---

## 🔍 Highlights

- ✅ **Fully modular architecture**
- ✅ **Adheres to XDG standards**
- ✅ **Failsafe design with chattr locking**
- ✅ **Rich debug & test suite**
- 🎨 **User-friendly CLI UI with color-coded feedback**
- 🛠️ **No placeholders—fully implemented & production-ready**

---

## 🚀 Quick Start

```bash
git clone https://github.com/youruser/ytdlc-installer.git
cd ytdlc-installer
chmod +x install_ytdlc.sh
./install_ytdlc.sh
```

---

## 🖥️ Requirements

| Requirement        | Details |
|--------------------|---------|
| OS                 | Arch Linux or derivatives |
| Shell              | Zsh |
| Package Manager    | pacman |
| Required Tools     | `yt-dlp`, `aria2`, `jq`, `dmenu`, `wl-clipboard` or `xclip` |
| Optional Enhancers | `fzf`, `mpv`, `zathura`, `lynx`, `nsxiv` |
| Environment Vars   | `$TERMINAL`, `$EDITOR`, `$BROWSER` (used in `dmenuhandler`) |

> All required packages are auto-installed via `pacman` if missing.

---

## 🔧 Features

| Component          | Description |
|-------------------|-------------|
| `ytdl.zsh`        | Zsh script with cookie-aware download logic |
| `ytdl-handler.sh` | Protocol handler for `ytdl://` links with `dmenu` |
| `dmenuhandler`    | Dmenu-powered launcher for files/URLs |
| `ytdl.desktop`    | MIME registration for custom protocol |
| **Bookmarklet**   | Enables 1-click streaming download from browsers |
| **Hardening**     | Uses `chattr +i` to prevent accidental edits |

---

## 🧪 Testing Suite

Run the full verification suite after installation:

```bash
chmod +x test_ytdlc.sh
./test_ytdlc.sh
```

### With debug output:
```bash
DEBUG=1 ./test_ytdlc.sh
```

### With auto-repair (e.g., re-lock files):
```bash
REPAIR=1 ./test_ytdlc.sh
```

---

## 🧠 Developer Tips

- You can simulate a browser-based call manually like so:
  ```bash
  ./ytdl-handler.sh 'ytdl://https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdQw4w9WgXcQ'
  ```
- Want to customize `dmenuhandler`? Edit the script directly—it's just a shell menu!

---

## 🔐 Security & Safety

- **DO NOT** run the installer as root. It uses `sudo` internally where needed.
- Files are locked with `chattr +i` after generation to prevent tampering.
- Manual override:
  ```bash
  sudo chattr -i /usr/local/bin/ytdl-handler.sh
  ```

---

## 📂 Directory Layout After Install

```

$HOME/.config/
├── yt-dlp/
│   └── *.cookies.txt
└── zsh/
    └── ytdl.zsh              # CLI download wrapper

/usr/local/bin/
└── ytdl-handler.sh           # ytdl:// URI scheme handler

$HOME/.local/bin/
└── dmenuhandler              # Dynamic dmenu-based media launcher

$HOME/.local/share/applications/
└── ytdl.desktop              # MIME registration file

```

---

## 🌐 Bookmarklet

Paste this into a browser bookmark:

```javascript
javascript:(()=>{const u=location.href;if(!/^https?:/.test(u)){alert('bad URL');return;}location.href=`ytdl://${encodeURIComponent(u)}`})();
```

Save it as **YTF**.

---

## 🆘 Troubleshooting

| Issue                            | Fix |
|----------------------------------|-----|
| `zsh: command not found: ytf`    | Ensure you sourced or called `ytdl.zsh` in your `.zshrc` |
| `dmenu not found`                | Confirm `dmenu` is installed or try `DEBUG=1` to trace |
| `xdg-mime not registering`       | Manually re-run `register_xdg` function in the script |

---

## 🤝 Contributing

Contributions welcome!

1. Fork the repo
2. Make enhancements (must be Arch-specific!)
3. Submit a clean PR (no placeholders, fully debugged)

---

## 📜 License

MIT License. Do anything with it—just don't ship bugs.

---

## 🎉 Thanks

Built by **4ndr0666** for hackers who want seamless, scriptable, and GUI-integrated control of their multimedia downloads—directly from the browser or clipboard.

Happy scripting! 🧪📦
