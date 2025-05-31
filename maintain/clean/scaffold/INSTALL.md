# Scaffold - Installation Guide

---

## 1. Requirements

- Python 3.6 or higher
- (Optional) `rich` library for enhanced CLI output:

```bash
pip install rich
```

- Git (if cloning repository)

---

## 2. Download Scaffold

Clone the repository:

```bash
git clone https://your-git-host/scaffold.git
cd scaffold/
```

Or download the latest release bundle manually.

---

## 3. Local Usage (No Install)

You can run Scaffold directly from the project directory:

```bash
python3 scaffold.py
```

✅ No global install necessary for basic use.

---

## 4. Optional Global Install

Install Scaffold globally for easier use:

```bash
sudo cp scaffold.py /usr/local/bin/scaffold
sudo chmod +x /usr/local/bin/scaffold
```

Now you can run it from anywhere:

```bash
scaffold
```

---

## 5. Preset Management

- Presets are stored inside the `presets/` directory.
- To add new project structures:
  - Create a new JSON file inside `presets/`.
  - Follow the structure of the existing templates.

Example:

```json
{
  "directories": [
    "src",
    "docs",
    "tests"
  ],
  "files": [
    "README.md",
    "setup.py",
    ".gitignore"
  ]
}
```

---

## 6. Uninstall

To remove the global install:

```bash
sudo rm /usr/local/bin/scaffold
```

No system services or daemons are ever installed.

---

# 📋 Summary

| Action | Command |
|:-------|:-------|
| Install optional rich library | `pip install rich` |
| Run locally | `python3 scaffold.py` |
| Install globally | `sudo cp scaffold.py /usr/local/bin/scaffold` |
| Uninstall | `sudo rm /usr/local/bin/scaffold` |

---
