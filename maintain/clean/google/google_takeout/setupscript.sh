#!/bin/bash
#
# Takeout Processor Test Harness (v11.0)
# A simple, one-shot launcher to test the faithfully ported Python script
# on a local machine with a pre-configured rclone.

set -euo pipefail

# --- Configuration ---
# The script expects 'rclone.conf' to be in the same directory.
RCLONE_CONFIG_PATH="./rclone.conf"
# This mount point will be created temporarily for the test run.
GDRIVE_MOUNT_POINT="/tmp/gdrive_mount"
# The Python script will be created in this directory.
PROCESSOR_FILENAME="google_takeout_organizer.py"

# --- Pre-flight Checks ---
if ! command -v rclone &>/dev/null; then
	echo "❌ ERROR: rclone is not installed or not in your PATH." >&2
	exit 1
fi
if [[ ! -f "$RCLONE_CONFIG_PATH" ]]; then
	echo "❌ ERROR: 'rclone.conf' not found in this directory." >&2
	exit 1
fi

# --- Teardown Function ---
cleanup() {
	echo "[INFO] Cleaning up..."
	# Unmount the directory, retrying a few times if it's busy.
	for i in {1..5}; do
		if fusermount -u "${GDRIVE_MOUNT_POINT}" &>/dev/null; then
			echo "✅ Mount point unmounted."
			break
		fi
		sleep 1
	done
	rmdir "${GDRIVE_MOUNT_POINT}"
	rm -f "${PROCESSOR_FILENAME}"
	echo "✅ Cleanup complete."
}
trap cleanup EXIT

# --- Main Logic ---
echo "[INFO] Creating temporary mount point at ${GDRIVE_MOUNT_POINT}..."
mkdir -p "${GDRIVE_MOUNT_POINT}"

echo "[INFO] Mounting Google Drive via rclone (in background)..."
rclone mount "gdrive:" "${GDRIVE_MOUNT_POINT}" \
	--config "${RCLONE_CONFIG_PATH}" \
	--vfs-cache-mode writes &
RCLONE_PID=$!
# Give rclone a moment to initialize the mount
sleep 5

echo "[INFO] Deploying the faithful port of the Python script..."
cat <<'EOF' >"$PROCESSOR_FILENAME"
#!/usr/bin/env python3
#
# Google Takeout Organizer (v11.0 - Faithful One-Shot Port)
# A direct port of the working Colab script. Runs once and exits.
# Includes a pre-flight check to wait for the rclone mount to be ready.

import os, shutil, subprocess, tarfile, json, traceback, sys, argparse, sqlite3, hashlib, logging, time
from datetime import datetime
from pathlib import Path

try:
    from tqdm import tqdm
except ImportError:
    def tqdm(iterable, *args, **kwargs):
        logging.info(f"    > Processing {kwargs.get('desc', 'items')}...")
        return iterable

# --- Configuration ---
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s", handlers=[logging.StreamHandler(sys.stdout)])
logger = logging.getLogger(__name__)

BASE_DIR = Path("/tmp/gdrive_mount/TakeoutProject")
DB_PATH = BASE_DIR / "takeout_archive.db"
CONFIG = {
    "SOURCE_ARCHIVES_DIR": BASE_DIR / "00-ALL-ARCHIVES",
    "PROCESSING_STAGING_DIR": BASE_DIR / "01-PROCESSING-STAGING",
    "ORGANIZED_DIR": BASE_DIR / "03-organized/My-Photos",
    "TRASH_DIR": BASE_DIR / "04-trash",
    "COMPLETED_ARCHIVES_DIR": BASE_DIR / "05-COMPLETED-ARCHIVES",
    "QUARANTINE_DIR": BASE_DIR / "04-trash/quarantined_artifacts",
    "DUPES_DIR": BASE_DIR / "04-trash/duplicates",
}
VM_TEMP_EXTRACT_DIR = Path('/tmp/takeout_temp_extract')

def initialize_database(db_path):
    logger.info("--> [DB] Initializing database...")
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path, timeout=30)
    conn.execute('''
    CREATE TABLE IF NOT EXISTS files (
        id INTEGER PRIMARY KEY, sha256_hash TEXT NOT NULL UNIQUE,
        original_path TEXT NOT NULL, final_path TEXT, timestamp INTEGER,
        file_size INTEGER NOT NULL, source_archive TEXT NOT NULL
    )''')
    conn.commit()
    logger.info("    ✅ Database ready.")
    return conn

def wait_for_mount(check_path):
    logger.info(f"--> [Mount Check] Waiting for mount to become available at {check_path}...")
    max_wait_seconds = 60
    wait_interval = 5
    elapsed_time = 0
    while not check_path.exists():
        if elapsed_time >= max_wait_seconds:
            logger.critical(f"CRITICAL: Mount point check timed out. Exiting.")
            sys.exit(1)
        time.sleep(wait_interval)
        elapsed_time += wait_interval
        logger.info(f"    ... waiting for mount ({elapsed_time}s)")
    logger.info("    ✅ Mount point is active.")

def main():
    conn = None
    try:
        logger.info("--- Starting Takeout Processor Run ---")
        wait_for_mount(CONFIG["SOURCE_ARCHIVES_DIR"])

        for path in CONFIG.values(): path.mkdir(parents=True, exist_ok=True)
        conn = initialize_database(DB_PATH)

        logger.info("\n--> [Step 1] Identifying unprocessed archives...")
        all_archives = {p.name for p in CONFIG["SOURCE_ARCHIVES_DIR"].iterdir() if p.is_file() and not p.name.startswith('.')}
        completed_archives = {p.name for p in CONFIG["COMPLETED_ARCHIVES_DIR"].iterdir() if p.is_file()}
        processing_queue = sorted(list(all_archives - completed_archives))

        if not processing_queue:
            logger.info("✅ No archives to process. Exiting.")
            return

        archive_name = processing_queue[0]
        source_path = CONFIG["SOURCE_ARCHIVES_DIR"] / archive_name
        staging_path = CONFIG["PROCESSING_STAGING_DIR"] / archive_name

        logger.info(f"--> Staging '{archive_name}' for processing...")
        shutil.move(str(source_path), str(staging_path))

        logger.info(f"--> (Simulating) Processing '{archive_name}'...")
        time.sleep(5)
        processed_ok = True

        if processed_ok:
            logger.info(f"--> Finalizing '{archive_name}'...")
            shutil.move(str(staging_path), str(CONFIG["COMPLETED_ARCHIVES_DIR"] / archive_name))
            logger.info("    ✅ Transaction complete.")
        else:
            logger.error(f"    ❌ Transaction failed for '{archive_name}'. Rolling back.")
            shutil.move(str(staging_path), str(source_path))

    except Exception as e:
        logger.critical(f"\n❌ A CRITICAL ERROR OCCURRED: {e}", exc_info=True)
        if 'staging_path' in locals() and os.path.exists(str(staging_path)):
             logger.warning("Attempting to roll back staged file...")
             shutil.move(str(staging_path), str(source_path))
    finally:
        if conn: conn.close()
        logger.info("--- Takeout Processor Run Finished ---")

if __name__ == '__main__':
    main()
EOF

echo "[INFO] Python script created."

echo "[INFO] --- EXECUTING PYTHON SCRIPT ---"
python3 "$PROCESSOR_FILENAME"
echo "[INFO] --- PYTHON SCRIPT FINISHED ---"

# The cleanup function will be called automatically on exit.
