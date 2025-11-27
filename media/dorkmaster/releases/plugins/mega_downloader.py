import subprocess
import os
import shutil

def batch_download(links, output_dir=".", log_errors=True):
    """
    Batch download a list of Mega.nz links using megadl (megatools).
    Dedupes links, creates output_dir, logs errors, and returns completed/failed.
    """
    if not shutil.which("megadl"):
        msg = "[CRIT] megadl (megatools) is not installed or not in PATH."
        if log_errors:
            print(msg)
        return {"completed": [], "failed": [(link, msg) for link in links]}

    completed, failed = [], []
    os.makedirs(output_dir, exist_ok=True)
    for link in set(links):  # Dedupe
        cmd = ["megadl", link, "--path", output_dir]
        print(f"[MEGA] Downloading: {link}")
        try:
            subprocess.run(cmd, check=True, timeout=300)
            completed.append(link)
        except Exception as e:
            if log_errors:
                print(f"[MEGA] Failed: {link} ({e})")
            failed.append((link, str(e)))
    return {"completed": completed, "failed": failed}
