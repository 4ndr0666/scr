#!/usr/bin/env python3
import json
from pathlib import Path

prefs_path = Path.home() / ".config/BraveSoftware/Brave-Browser-Beta/Default/Preferences"

with prefs_path.open("r", encoding="utf-8") as f:
    prefs = json.load(f)

flags = prefs.get("browser", {}).get("enabled_labs_experiments", [])
print("Extracted brave://flags entries:")
for flag in sorted(flags):
    print(f"--enable-features={flag}")
