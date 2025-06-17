# CODEX.md

**Work Order: Shell Script Remediation (pre-commit & ShellCheck)**

---

## Scope

This task applies only to files listed as failing in the attached pre-commit/ShellCheck findings and *explicitly named* in this order.
**Do not modify any scripts outside those referenced in the current work order.**

---

## Directives (per CODEX.md & AGENTS.md)

### General

* All code changes must be full, explicit, and in-place. No placeholders or omitted logic.
* All scripts must be modular, XDG-compliant, and strictly pass `shellcheck` and `shfmt`.
* All revisions must implement `--help` and `--dry-run` where relevant.
* *All revisions must be cleaned of merge artifacts with*
  `0-tests/codex-merge-clean.sh <file ...>`
  *before lint, test, or commit.*

### Coding Standards

* Quote all variables, especially in command arguments and redirections.
* Use long-form flags (e.g., `--help`), avoid short flags unless standard.
* Prefer `printf` over `echo`; all output must be non-interactive/pipeline-safe.
* Variable declarations and assignments must be separate.
* Avoid cyclomatic complexity: use clear, logical, testable functions.
* Strict error handling (`set -euo pipefail`); check all critical command returns.
* Validate input/output and check file existence/permissions.
* Avoid ambiguous constructs, placeholder lines, or unquoted expansions.
* **Redirection:** No use of `&>`; always `>file 2>&1`.
* No unbound/arbitrary variables; all variables must be assigned.
* All exports must be validated.
* Satisfy XDG Base Directory requirements for any file path handling.
* For all scripts that touch the filesystem, enforce dry-run and logging to `$XDG_DATA_HOME/logs/`.
* All scripts must be linted via `shellcheck` (no errors/warnings) and formatted with `shfmt`.

### Function Validation

* Each function must be:

  * Idempotent, logically isolated, explicitly error-handling.
  * Free of ambiguity, unnecessary newlines, or improper word splitting.
  * Disclose function count and total script line count after revision.
  * Compare with original; on gross mismatch, retry up to 3 times.

---

## Task Steps

1. **Review shellcheck/pre-commit findings for all listed scripts.**
2. For each issue, apply remediation according to the Coding Standards above.
3. Remove all CODEX or merge artifact markers before proceeding.
4. Validate scripts pass `shellcheck` and `shfmt` with zero warnings or errors.
5. Ensure all variable assignments, quoting, and control structures are correct and robust.
6. For any ambiguity or policy conflict, document and justify in a comment in the script and in `CODEX.md`.
7. Update or add test cases (preferably with `bats`) as feasible.
8. Write a summary of changes to `0-tests/task_outcome.md` and update `0-tests/CHANGELOG.md` with per-script entries.
9. Before finalizing, disclose the number of functions and total line count for each revised script.
10. **Do not bypass any lint, dry-run, or policy enforcement steps.**

---

## Success Criteria

* All targeted scripts pass `pre-commit run --all-files` and `shellcheck` cleanly.
* All code changes strictly follow AGENTS.md and this CODEX.md.
* No placeholders or omitted sections; all functional logic is present and validated.
* All changes and any exceptions are documented as per instructions above.

---

## Bugs

You are required to address all of the following conflicts:

codex-merge-clean........................................................Failed
- hook id: codex-merge-clean
- exit code: 1

Executable `/home/git/clone/scr/bash` not found

ruff (legacy alias)......................................................Failed
- hook id: ruff
- exit code: 1

4ndr0tools/02-recovery_tools/os-repair/system_clock_automation.py:13:40: F821 Undefined name `sys`
   |
11 |     try:
12 |         print("Attempting to escalate privileges...")
13 |         subprocess.check_call(["sudo", sys.executable] + sys.argv)
   |                                        ^^^ F821
14 |         sys.exit()
15 |     except subprocess.CalledProcessError as e:
   |

4ndr0tools/02-recovery_tools/os-repair/system_clock_automation.py:13:58: F821 Undefined name `sys`
   |
11 |     try:
12 |         print("Attempting to escalate privileges...")
13 |         subprocess.check_call(["sudo", sys.executable] + sys.argv)
   |                                                          ^^^ F821
14 |         sys.exit()
15 |     except subprocess.CalledProcessError as e:
   |

4ndr0tools/02-recovery_tools/os-repair/system_clock_automation.py:14:9: F821 Undefined name `sys`
   |
12 |         print("Attempting to escalate privileges...")
13 |         subprocess.check_call(["sudo", sys.executable] + sys.argv)
14 |         sys.exit()
   |         ^^^ F821
15 |     except subprocess.CalledProcessError as e:
16 |         print(f"Error escalating privileges: {e}")
   |

4ndr0tools/02-recovery_tools/os-repair/system_clock_automation.py:17:9: F821 Undefined name `sys`
   |
15 |     except subprocess.CalledProcessError as e:
16 |         print(f"Error escalating privileges: {e}")
17 |         sys.exit(e.returncode)
   |         ^^^ F821
   |

4ndr0tools/4ndr0update/service/arch_news.py:28:12: E712 Avoid equality comparisons to `False`; use `not last_upgrade:` for false checks
   |
26 |     exit_code = 0
27 |     for news_post in arch_news["rss"]["channel"]["item"]:
28 |         if last_upgrade == False or parse(news_post["pubDate"]).replace(
   |            ^^^^^^^^^^^^^^^^^^^^^ E712
29 |             tzinfo=None
30 |         ) >= parse(last_upgrade):
   |
   = help: Replace with `not last_upgrade`

install/scrapy/imagecrawler.py:78:9: F524 `.format` call is missing argument(s) for placeholder(s):
            'scrapy,
            'User-Agent'
   |
76 |       settings_file_path = os.path.join(project_name, project_name, "settings.py")
77 |       settings_append = textwrap.dedent(
78 | /         """
79 | |         # Custom Settings
80 | |         ITEM_PIPELINES = {
81 | |             'scrapy.pipelines.images.ImagesPipeline': 1,
82 | |             'scrapy.pipelines.files.FilesPipeline': 1,
83 | |             'scrapy.pipelines.images.{project_name.capitalize()}ImagesPipeline': 300,
84 | |         }
85 | |         IMAGES_STORE = 'images'
86 | |         AUTOTHROTTLE_ENABLED = True
87 | |         HTTPCACHE_ENABLED = True
88 | |         LOG_LEVEL = 'INFO'
89 | |         DEFAULT_REQUEST_HEADERS = {
90 | |             'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
91 | |                           'AppleWebKit/537.36 (KHTML, like Gecko) '
92 | |                           'Chrome/58.0.3029.110 Safari/537.3'
93 | |         }
94 | |     """.format(
95 | |             project_name=project_name
96 | |         )
   | |_________^ F524
97 |       )
   |

install/waybar/scripts/rofi_network:236:12: E721 Use `is` and `is not` for type comparisons, or `isinstance()` for isinstance checks
    |
234 |     delay = CONF.getint("nmdm", "rescan_delay", fallback=5)
235 |     for dev in CLIENT.get_devices():
236 |         if gi.repository.NM.DeviceWifi == type(dev):
    |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ E721
237 |             try:
238 |                 dev.request_scan_async(None, rescan_cb, None)
    |

maintain/btrfs/btrfs_unified_manager.py:43:5: F811 Redefinition of unused `log_message` from line 21
   |
43 | def log_message(message):
   |     ^^^^^^^^^^^ F811
44 |     with open(LOG_FILE, "a") as log_file:
45 |         log_file.write(f"{datetime.now()}: {message}\n")
   |
   = help: Remove definition: `log_message`

maintain/clean/scaffold/release/dirmaid2.py:159:29: F821 Undefined name `os`
    |
157 |         return
158 |
159 |     for subdir, _, files in os.walk(directory_path):
    |                             ^^ F821
160 |         for file in files:
161 |             src_path = Path(subdir) / file
    |

maintain/clean/scaffold/release/dirmaid4.py:1:1: F821 Undefined name `python`
  |
1 | python
  | ^^^^^^ F821
2 |
3 | #!/usr/bin/env python3
  |

maintain/clean/scaffold/release/dirmaid4.py:35:1: E402 Module level import not at top of file
   |
33 | """
34 |
35 | import os
   | ^^^^^^^^^ E402
36 | import shutil
37 | import mimetypes
   |

maintain/clean/scaffold/release/dirmaid4.py:36:1: E402 Module level import not at top of file
   |
35 | import os
36 | import shutil
   | ^^^^^^^^^^^^^ E402
37 | import mimetypes
38 | import hashlib
   |

maintain/clean/scaffold/release/dirmaid4.py:37:1: E402 Module level import not at top of file
   |
35 | import os
36 | import shutil
37 | import mimetypes
   | ^^^^^^^^^^^^^^^^ E402
38 | import hashlib
39 | import zipfile
   |

maintain/clean/scaffold/release/dirmaid4.py:38:1: E402 Module level import not at top of file
   |
36 | import shutil
37 | import mimetypes
38 | import hashlib
   | ^^^^^^^^^^^^^^ E402
39 | import zipfile
40 | import tarfile
   |

maintain/clean/scaffold/release/dirmaid4.py:39:1: E402 Module level import not at top of file
   |
37 | import mimetypes
38 | import hashlib
39 | import zipfile
   | ^^^^^^^^^^^^^^ E402
40 | import tarfile
41 | import py7zr
   |

maintain/clean/scaffold/release/dirmaid4.py:40:1: E402 Module level import not at top of file
   |
38 | import hashlib
39 | import zipfile
40 | import tarfile
   | ^^^^^^^^^^^^^^ E402
41 | import py7zr
42 | import rarfile
   |

maintain/clean/scaffold/release/dirmaid4.py:41:1: E402 Module level import not at top of file
   |
39 | import zipfile
40 | import tarfile
41 | import py7zr
   | ^^^^^^^^^^^^ E402
42 | import rarfile
43 | import logging
   |

maintain/clean/scaffold/release/dirmaid4.py:42:1: E402 Module level import not at top of file
   |
40 | import tarfile
41 | import py7zr
42 | import rarfile
   | ^^^^^^^^^^^^^^ E402
43 | import logging
44 | import json
   |

maintain/clean/scaffold/release/dirmaid4.py:43:1: E402 Module level import not at top of file
   |
41 | import py7zr
42 | import rarfile
43 | import logging
   | ^^^^^^^^^^^^^^ E402
44 | import json
45 | import subprocess
   |

maintain/clean/scaffold/release/dirmaid4.py:44:1: E402 Module level import not at top of file
   |
42 | import rarfile
43 | import logging
44 | import json
   | ^^^^^^^^^^^ E402
45 | import subprocess
46 | from pathlib import Path
   |

maintain/clean/scaffold/release/dirmaid4.py:45:1: E402 Module level import not at top of file
   |
43 | import logging
44 | import json
45 | import subprocess
   | ^^^^^^^^^^^^^^^^^ E402
46 | from pathlib import Path
47 | from datetime import datetime
   |

maintain/clean/scaffold/release/dirmaid4.py:46:1: E402 Module level import not at top of file
   |
44 | import json
45 | import subprocess
46 | from pathlib import Path
   | ^^^^^^^^^^^^^^^^^^^^^^^^ E402
47 | from datetime import datetime
48 | from time import sleep
   |

maintain/clean/scaffold/release/dirmaid4.py:47:1: E402 Module level import not at top of file
   |
45 | import subprocess
46 | from pathlib import Path
47 | from datetime import datetime
   | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ E402
48 | from time import sleep
   |

maintain/clean/scaffold/release/dirmaid4.py:48:1: E402 Module level import not at top of file
   |
46 | from pathlib import Path
47 | from datetime import datetime
48 | from time import sleep
   | ^^^^^^^^^^^^^^^^^^^^^^ E402
49 |
50 | # Rich-based CLI
   |

maintain/clean/scaffold/release/dirmaid4.py:51:1: E402 Module level import not at top of file
   |
50 | # Rich-based CLI
51 | from rich.console import Console
   | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ E402
52 | from rich.table import Table
53 | from rich.prompt import Prompt
   |

maintain/clean/scaffold/release/dirmaid4.py:52:1: E402 Module level import not at top of file
   |
50 | # Rich-based CLI
51 | from rich.console import Console
52 | from rich.table import Table
   | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ E402
53 | from rich.prompt import Prompt
   |

maintain/clean/scaffold/release/dirmaid4.py:53:1: E402 Module level import not at top of file
   |
51 | from rich.console import Console
52 | from rich.table import Table
53 | from rich.prompt import Prompt
   | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ E402
54 |
55 | try:
   |

maintain/users/user_manager.py:13:1: E402 Module level import not at top of file
   |
12 | gi.require_version("Gtk", "3.0")
13 | from gi.repository import Gtk
   | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ E402
14 | import re
15 | import os
   |

maintain/users/user_manager.py:14:1: E402 Module level import not at top of file
   |
12 | gi.require_version("Gtk", "3.0")
13 | from gi.repository import Gtk
14 | import re
   | ^^^^^^^^^ E402
15 | import os
16 | import sys
   |

maintain/users/user_manager.py:15:1: E402 Module level import not at top of file
   |
13 | from gi.repository import Gtk
14 | import re
15 | import os
   | ^^^^^^^^^ E402
16 | import sys
17 | import subprocess
   |

maintain/users/user_manager.py:16:1: E402 Module level import not at top of file
   |
14 | import re
15 | import os
16 | import sys
   | ^^^^^^^^^^ E402
17 | import subprocess
18 | import gettext
   |

maintain/users/user_manager.py:17:1: E402 Module level import not at top of file
   |
15 | import os
16 | import sys
17 | import subprocess
   | ^^^^^^^^^^^^^^^^^ E402
18 | import gettext
19 | import locale
   |

maintain/users/user_manager.py:18:1: E402 Module level import not at top of file
   |
16 | import sys
17 | import subprocess
18 | import gettext
   | ^^^^^^^^^^^^^^ E402
19 | import locale
20 | import argparse
   |

maintain/users/user_manager.py:19:1: E402 Module level import not at top of file
   |
17 | import subprocess
18 | import gettext
19 | import locale
   | ^^^^^^^^^^^^^ E402
20 | import argparse
   |

maintain/users/user_manager.py:20:1: E402 Module level import not at top of file
   |
18 | import gettext
19 | import locale
20 | import argparse
   | ^^^^^^^^^^^^^^^ E402
21 |
22 | # Initialize gettext for internationalization
   |

maintain/users/user_manager.py:1130:9: F841 Local variable `app` is assigned to but never used
     |
1129 |         # Launch the GUI
1130 |         app = NotebookApp()
     |         ^^^ F841
1131 |         Gtk.main()
1132 |         return 0
     |
     = help: Remove assignment to unused variable `app`

media/dmx:291:31: F401 `vapoursynth` imported but unused; consider using `importlib.util.find_spec` to test for availability
    |
289 |     # Check if VapourSynth module is available
290 |     try:
291 |         import vapoursynth as vs
    |                               ^^ F401
292 |
293 |         logging.info("VapourSynth module is available.")
    |
    = help: Remove unused import: `vapoursynth`

media/dmx_project/dmxbeta:291:31: F401 `vapoursynth` imported but unused; consider using `importlib.util.find_spec` to test for availability
    |
289 |     # Check if VapourSynth module is available
290 |     try:
291 |         import vapoursynth as vs
    |                               ^^ F401
292 |
293 |         logging.info("VapourSynth module is available.")
    |
    = help: Remove unused import: `vapoursynth`

media/gallerydl/gallerydl_config_generator.py:39:5: F841 Local variable `file_extension` is assigned to but never used
   |
37 | ):
38 |     # Extract file extension from the base URL (e.g., jpg, png)
39 |     file_extension = base_url.split(".")[-1]
   |     ^^^^^^^^^^^^^^ F841
40 |
41 |     # Replace the numeric part of the base URL with a placeholder
   |
   = help: Remove assignment to unused variable `file_extension`

media/gallerydl/gallerydl_customizer.py:321:5: F841 Local variable `ORANGE` is assigned to but never used
    |
319 |     LIGHTGREEN = "\033[1;32m"
320 |     LIGHTRED = "\033[1;31m"
321 |     ORANGE = "\033[0;33m"
    |     ^^^^^^ F841
322 |     CYAN = "\033[0;36m"
323 |     WHT = "\033[0m"
    |
    = help: Remove assignment to unused variable `ORANGE`

media/gallerydl/gallerydl_customizer.py:322:5: F841 Local variable `CYAN` is assigned to but never used
    |
320 |     LIGHTRED = "\033[1;31m"
321 |     ORANGE = "\033[0;33m"
322 |     CYAN = "\033[0;36m"
    |     ^^^^ F841
323 |     WHT = "\033[0m"
324 |     NC = "\033[0J"
    |
    = help: Remove assignment to unused variable `CYAN`

media/vidutil.py:247:5: F841 Local variable `width` is assigned to but never used
    |
245 |         return None
246 |
247 |     width = int(width_match.group(1))
    |     ^^^^^ F841
248 |     height = int(height_match.group(1))
249 |     r_frame_rate_num = int(r_frame_rate_match.group(1))
    |
    = help: Remove assignment to unused variable `width`

media/vidutil.py:248:5: F841 Local variable `height` is assigned to but never used
    |
247 |     width = int(width_match.group(1))
248 |     height = int(height_match.group(1))
    |     ^^^^^^ F841
249 |     r_frame_rate_num = int(r_frame_rate_match.group(1))
250 |     r_frame_rate_den = int(r_frame_rate_match.group(2))
    |
    = help: Remove assignment to unused variable `height`

media/vidutil.py:377:5: F841 Local variable `container_format` is assigned to but never used
    |
376 |     # Unpack user options
377 |     container_format = user_options.get("container_format", "mp4")
    |     ^^^^^^^^^^^^^^^^ F841
378 |     video_codec = user_options.get("video_codec", "libx264")
379 |     crf = user_options.get("crf")
    |
    = help: Remove assignment to unused variable `container_format`

media/vidutil.py:378:5: F841 Local variable `video_codec` is assigned to but never used
    |
376 |     # Unpack user options
377 |     container_format = user_options.get("container_format", "mp4")
378 |     video_codec = user_options.get("video_codec", "libx264")
    |     ^^^^^^^^^^^ F841
379 |     crf = user_options.get("crf")
380 |     bitrate = user_options.get("bitrate")
    |
    = help: Remove assignment to unused variable `video_codec`

media/vidutil.py:379:5: F841 Local variable `crf` is assigned to but never used
    |
377 |     container_format = user_options.get("container_format", "mp4")
378 |     video_codec = user_options.get("video_codec", "libx264")
379 |     crf = user_options.get("crf")
    |     ^^^ F841
380 |     bitrate = user_options.get("bitrate")
381 |     preset = user_options.get("preset", "medium")
    |
    = help: Remove assignment to unused variable `crf`

media/vidutil.py:380:5: F841 Local variable `bitrate` is assigned to but never used
    |
378 |     video_codec = user_options.get("video_codec", "libx264")
379 |     crf = user_options.get("crf")
380 |     bitrate = user_options.get("bitrate")
    |     ^^^^^^^ F841
381 |     preset = user_options.get("preset", "medium")
382 |     target_resolution = user_options.get("target_resolution")
    |
    = help: Remove assignment to unused variable `bitrate`

media/vidutil.py:381:5: F841 Local variable `preset` is assigned to but never used
    |
379 |     crf = user_options.get("crf")
380 |     bitrate = user_options.get("bitrate")
381 |     preset = user_options.get("preset", "medium")
    |     ^^^^^^ F841
382 |     target_resolution = user_options.get("target_resolution")
383 |     target_framerate = user_options.get("target_framerate")
    |
    = help: Remove assignment to unused variable `preset`

media/vidutil.py:382:5: F841 Local variable `target_resolution` is assigned to but never used
    |
380 |     bitrate = user_options.get("bitrate")
381 |     preset = user_options.get("preset", "medium")
382 |     target_resolution = user_options.get("target_resolution")
    |     ^^^^^^^^^^^^^^^^^ F841
383 |     target_framerate = user_options.get("target_framerate")
384 |     motion_interpolation = user_options.get("motion_interpolation", False)
    |
    = help: Remove assignment to unused variable `target_resolution`

media/vidutil.py:383:5: F841 Local variable `target_framerate` is assigned to but never used
    |
381 |     preset = user_options.get("preset", "medium")
382 |     target_resolution = user_options.get("target_resolution")
383 |     target_framerate = user_options.get("target_framerate")
    |     ^^^^^^^^^^^^^^^^ F841
384 |     motion_interpolation = user_options.get("motion_interpolation", False)
385 |     merging_mode = user_options.get(
    |
    = help: Remove assignment to unused variable `target_framerate`

media/vidutil.py:384:5: F841 Local variable `motion_interpolation` is assigned to but never used
    |
382 |     target_resolution = user_options.get("target_resolution")
383 |     target_framerate = user_options.get("target_framerate")
384 |     motion_interpolation = user_options.get("motion_interpolation", False)
    |     ^^^^^^^^^^^^^^^^^^^^ F841
385 |     merging_mode = user_options.get(
386 |         "merging_mode", "concat"
    |
    = help: Remove assignment to unused variable `motion_interpolation`

media/vidutil.py:479:5: F841 Local variable `container_format` is assigned to but never used
    |
477 |     # This function handles merging a group of videos using the specified merging mode
478 |     merging_mode = user_options.get("merging_mode", "concat")
479 |     container_format = user_options.get("container_format", "mp4")
    |     ^^^^^^^^^^^^^^^^ F841
480 |     video_codec = user_options.get("video_codec", "libx264")
481 |     crf = user_options.get("crf")
    |
    = help: Remove assignment to unused variable `container_format`

media/vidutil2.py:578:9: E722 Do not use bare `except`
    |
576 |             pad_filter = f"pad={w}:{h}:(ow-iw)/2:(oh-ih)/2"
577 |             vf_chain_elems += [scale_filter, pad_filter]
578 |         except:
    |         ^^^^^^ E722
579 |             pass
    |

media/vidutil2.py:612:5: E722 Do not use bare `except`
    |
610 |         if "audio" in r.stdout.lower():
611 |             audio_opt = ["-c:a", "aac", "-b:a", "128k"]
612 |     except:
    |     ^^^^^^ E722
613 |         pass
    |

media/vidutil2.py:756:13: E722 Do not use bare `except`
    |
754 |                 w, h = target_resolution.split("x")
755 |                 target_width, target_height = int(w), int(h)
756 |             except:
    |             ^^^^^^ E722
757 |                 pass
    |

media/vidutil2.py:884:13: E722 Do not use bare `except`
    |
882 |                 h = int(props["height"])
883 |                 file_areas.append((f, w * h))
884 |             except:
    |             ^^^^^^ E722
885 |                 pass
886 |     if not file_areas:
    |

media/vidutil2.py:889:5: F841 Local variable `largest_video` is assigned to but never used
    |
887 |         error_exit("Auto merging: no valid files with area.")
888 |     file_areas.sort(key=lambda x: x[1], reverse=True)
889 |     largest_video = file_areas[0][0]
    |     ^^^^^^^^^^^^^ F841
890 |     sorted_files = [x[0] for x in file_areas]
891 |     normalized_files = []
    |
    = help: Remove assignment to unused variable `largest_video`

media/vidutil2.py:1187:9: E722 Do not use bare `except`
     |
1185 |             if crf < 0 or crf > 51:
1186 |                 raise ValueError
1187 |         except:
     |         ^^^^^^ E722
1188 |             crf = 23
1189 |             print_warning("Invalid CRF. Using default 23.")
     |

media/vidutil2.py:1223:5: E722 Do not use bare `except`
     |
1221 |     try:
1222 |         preset = preset_opts[int(preset_choice) - 1]
1223 |     except:
     |     ^^^^^^ E722
1224 |         preset = "medium"
1225 |         print_warning("Invalid preset. Using default 'medium'.")
     |

media/vidutil2.py:1270:9: E722 Do not use bare `except`
     |
1268 |             chosen_fps = int(chosen_fps)
1269 |             print_info(f"Selected frame rate: {chosen_fps} fps")
1270 |         except:
     |         ^^^^^^ E722
1271 |             chosen_fps = 60
1272 |             print_warning("Invalid frame rate. Using 60 fps")
     |

security/network/ghostnet:87:17: F841 Local variable `proc` is assigned to but never used
   |
85 |                     "macchanger -p %s | tail -n 1 | sed 's/  //g'" % Faded._iface
86 |                 ).read()
87 |                 proc = os.popen(
   |                 ^^^^ F841
88 |                     "ifconfig %s up | tail -n 1 | sed 's/  //g'" % Faded._iface
89 |                 ).read()
   |
   = help: Remove assignment to unused variable `proc`

security/network/ghostnet:266:8: E712 Avoid equality comparisons to `True`; use `err:` for truth checks
    |
264 |     _resp = "\033[1;92m"
265 |
266 |     if err == True:
    |        ^^^^^^^^^^^ E712
267 |         msg = _err + msg + _nor
268 |     elif warn == True:
    |
    = help: Replace with `err`

security/network/ghostnet:268:10: E712 Avoid equality comparisons to `True`; use `warn:` for truth checks
    |
266 |     if err == True:
267 |         msg = _err + msg + _nor
268 |     elif warn == True:
    |          ^^^^^^^^^^^^ E712
269 |         msg = _warn + msg + _nor
270 |     elif resp == True:
    |
    = help: Replace with `warn`

security/network/ghostnet:270:10: E712 Avoid equality comparisons to `True`; use `resp:` for truth checks
    |
268 |     elif warn == True:
269 |         msg = _warn + msg + _nor
270 |     elif resp == True:
    |          ^^^^^^^^^^^^ E712
271 |         msg = _resp + msg + _nor
272 |     else:
    |
    = help: Replace with `resp`

security/network/ghostnet:300:18: E711 Comparison to `None` should be `cond is None`
    |
298 |             else:
299 |                 pass
300 |     if _iface == None:
    |                  ^^^^ E711
301 |         sys.exit(
302 |             log(
    |
    = help: Replace with `cond is None`

security/network/ghostnet:517:5: E722 Do not use bare `except`
    |
515 |     try:
516 |         job = (sys.argv)[1]
517 |     except:
    |     ^^^^^^ E722
518 |         sys.exit(usage())
519 |     else:
    |

systemd/sysd_manager/systemd911.py:350:9: F821 Undefined name `rename_snapshot`
    |
348 |         compress_snapshot(snapshot_name)
349 |     elif action == "3":
350 |         rename_snapshot(snapshot_name)
    |         ^^^^^^^^^^^^^^^ F821
351 |     elif action == "4":
352 |         view_snapshot_contents(snapshot_name)
    |

systemd/sysd_manager/systemd_manger.py:345:9: F821 Undefined name `rename_snapshot`
    |
343 |         compress_snapshot(snapshot_name)
344 |     elif action == "3":
345 |         rename_snapshot(snapshot_name)
    |         ^^^^^^^^^^^^^^^ F821
346 |     elif action == "4":
347 |         view_snapshot_contents(snapshot_name)
    |

utilities/files/createfiletree.py:170:19: F821 Undefined name `string`
    |
168 |         None
169 |     """
170 |     for letter in string.ascii_uppercase:
    |                   ^^^^^^ F821
171 |         path = os.path.join(base_path, letter)
172 |         create_directory(path)
    |

Found 69 errors.
No fixes available (22 hidden fixes can be enabled with the `--unsafe-fixes` option).

**End of Work Order**
