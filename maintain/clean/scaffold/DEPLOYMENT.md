# 📜 `DEPLOYMENT.md` (for `scaffold/`)

```markdown
# Scaffold Deployment Guide

## Requirements
- Python 3.6+
- (Optional) `rich` package for enhanced CLI output

## Install (Local User)

1. Clone Repository
```bash
git clone https://your-git-host/scaffold.git
cd scaffold
```

2. Install Optional Python Dependency
```bash
pip install rich
```

3. (Optional) Install globally
```bash
sudo cp scaffold.py /usr/local/bin/scaffold
sudo chmod +x /usr/local/bin/scaffold
```

You can now run `scaffold` from anywhere.

## Usage

From inside the scaffold project folder:
```bash
python3 scaffold.py
```
Or if globally installed:
```bash
scaffold
```

## First Run Steps
1. Choose a preset scaffold template.
2. Confirm dry-run structure.
3. Approve or cancel actual directory creation.

## Notes
- **No system services installed.**
- **No permanent changes until you approve after dry-run.**
- **All presets are stored in `presets/` folder.**

---

# Optional Tips
- You can create new templates by copying and editing JSON files in `presets/`
- To extend functionality, future versions may allow YAML templates too.

---
