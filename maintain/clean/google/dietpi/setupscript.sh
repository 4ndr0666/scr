#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v4.0 - Rclone Mount Model)
# This version replicates the successful Colab environment by using rclone to mount
# Google Drive, allowing a file-system-based script to run reliably.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/google_takeout_organizer"
RCLONE_CONFIG_PATH="${INSTALL_DIR}/rclone.conf"
GDRIVE_MOUNT_POINT="/content/drive/MyDrive" # Mount point to match Colab script

PROCESSOR_FILENAME="google_takeout_organizer.py"
PROCESSOR_SCRIPT_PATH="${INSTALL_DIR}/${PROCESSOR_FILENAME}"
PROCESSOR_SERVICE_NAME="takeout-organizer.service"
PROCESSOR_SERVICE_PATH="/etc/systemd/system/${PROCESSOR_SERVICE_NAME}"

RCLONE_SERVICE_NAME="gdrive-mount.service"
RCLONE_SERVICE_PATH="/etc/systemd/system/${RCLONE_SERVICE_NAME}"

# --- Logging Utilities ---
_log_info() { printf "\n[INFO] %s\n" "$*"; }
_log_ok()   { printf "✅ %s\n" "$*"; }
_log_warn() { printf "⚠️  %s\n" "$*"; }
_log_fail() { printf "❌ ERROR: %s\n" "$*"; exit 1; }

# ==============================================================================
# --- Main Installation Logic ---
# ==============================================================================
main() {
    _log_info "--- Starting Takeout Processor Appliance Setup (v4.0 Rclone Mount Model) ---"
    if [[ $EUID -ne 0 ]]; then _log_fail "This script must be run as root."; fi

    _log_info "Ensuring any old services are stopped..."
    systemctl stop ${PROCESSOR_SERVICE_NAME} &>/dev/null || true
    systemctl stop ${RCLONE_SERVICE_NAME} &>/dev/null || true
    systemctl disable ${PROCESSOR_SERVICE_NAME} &>/dev/null || true
    systemctl disable ${RCLONE_SERVICE_NAME} &>/dev/null || true
    _log_ok "Services stopped and disabled."

    _log_info "Updating package lists and installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null
    # Add rclone and fusermount
    apt-get install -y python3 jdupes sqlite3 python3-tqdm rclone fuse >/dev/null
    _log_ok "All dependencies (including rclone) are installed."

    _log_info "Creating directories..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$GDRIVE_MOUNT_POINT"
    _log_ok "Directories created."
    
    _log_info "Checking for rclone configuration..."
    if [[ ! -f "$RCLONE_CONFIG_PATH" ]]; then
        _log_warn "CRITICAL: 'rclone.conf' not found at ${RCLONE_CONFIG_PATH}."
        _log_warn "The mount service WILL FAIL until you place a valid config file there."
    else
        chmod 600 "$RCLONE_CONFIG_PATH"
        _log_ok "Found 'rclone.conf' and set permissions."
    fi

    _log_info "Deploying the Takeout Processor script (File System Version)..."
    # --- BEGIN EMBEDDED PYTHON SCRIPT (v4.0) ---
    cat << 'EOF' > "$PROCESSOR_SCRIPT_PATH"
"""
Google Takeout Organizer (v4.0 - File System Model)
This script is a direct port of the working Colab v4.1.1. It assumes that
the Google Drive is already mounted at the specified BASE_DIR by an external
service like rclone.
"""
import os, shutil, subprocess, tarfile, json, traceback, re, sys, argparse, sqlite3, hashlib, time
from datetime import datetime

try:
    from tqdm import tqdm
except ImportError:
    def tqdm(iterable, *args, **kwargs):
        print(f"    > Processing {kwargs.get('desc', 'items')}...")
        return iterable

# ==============================================================================
# --- 1. CORE CONFIGURATION ---
# ==============================================================================
BASE_DIR = "/content/drive/MyDrive/TakeoutProject"
DB_PATH = os.path.join(BASE_DIR, "takeout_archive.db")
CONFIG = {
    "SOURCE_ARCHIVES_DIR": os.path.join(BASE_DIR, "00-ALL-ARCHIVES/"),
    "PROCESSING_STAGING_DIR": os.path.join(BASE_DIR, "01-PROCESSING-STAGING/"),
    "ORGANIZED_PHOTOS_DIR": os.path.join(BASE_DIR, "03-organized/My-Photos/"),
    "ORGANIZED_FILES_DIR": os.path.join(BASE_DIR, "03-organized/My-Files/"), # Added for clarity
    "TRASH_DIR": os.path.join(BASE_DIR, "04-trash/"),
    "COMPLETED_ARCHIVES_DIR": os.path.join(BASE_DIR, "05-COMPLETED-ARCHIVES/"),
}
CONFIG["QUARANTINE_DIR"] = os.path.join(CONFIG["TRASH_DIR"], "quarantined_artifacts/")
CONFIG["DUPES_DIR"] = os.path.join(CONFIG["TRASH_DIR"], "duplicates/")
VM_TEMP_EXTRACT_DIR = '/tmp/temp_extract'
VM_TEMP_BATCH_DIR = '/tmp/temp_batch_creation'
PROCESSING_IDLE_SLEEP_SECONDS = 300

# ==============================================================================
# --- 2. WORKFLOW FUNCTIONS & HELPERS ---
# ==============================================================================
def initialize_database(db_path):
    print("--> [DB] Initializing database...")
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.execute('''
    CREATE TABLE IF NOT EXISTS files (
        sha256_hash TEXT PRIMARY KEY,
        source_archive TEXT NOT NULL
    )''')
    conn.commit()
    print("    ✅ Database ready.")
    return conn

def perform_startup_integrity_check():
    print("--> [POST] Performing startup integrity check...")
    # Check for stalled archives in staging
    staging_dir = CONFIG["PROCESSING_STAGING_DIR"]
    source_dir = CONFIG["SOURCE_ARCHIVES_DIR"]
    if os.path.exists(staging_dir) and os.listdir(staging_dir):
        print(f"    ⚠️ Found {len(os.listdir(staging_dir))} orphaned file(s). Rolling back...")
        for orphan in os.listdir(staging_dir):
            shutil.move(os.path.join(staging_dir, orphan), os.path.join(source_dir, orphan))
        print("    ✅ Rollback complete.")
    else:
        print("    ✅ No orphaned files found.")

def deduplicate_and_move_files(source_dir, dest_dir, dupe_dir, conn, archive_name):
    print("\n--> [Step 2b] Deduplicating new files...")
    known_hashes = {row[0] for row in conn.execute("SELECT sha256_hash FROM files")}
    new_files_to_db = []
    
    takeout_dir = os.path.join(source_dir, "Takeout")
    if not os.path.exists(takeout_dir):
        print("    > No 'Takeout' directory found to process for general files.")
        return

    for root, _, files in os.walk(takeout_dir):
        if "Google Photos" in root: continue # Skip photos, handled separately
        for filename in files:
            file_path = os.path.join(root, filename)
            with open(file_path, 'rb') as f:
                sha256 = hashlib.sha256(f.read()).hexdigest()
            
            if sha256 in known_hashes:
                # It's a duplicate, move to duplicates folder
                dupe_dest = os.path.join(dupe_dir, filename)
                shutil.move(file_path, dupe_dest)
            else:
                # It's unique, move to final destination
                relative_path = os.path.relpath(file_path, takeout_dir)
                final_path = os.path.join(dest_dir, relative_path)
                os.makedirs(os.path.dirname(final_path), exist_ok=True)
                shutil.move(file_path, final_path)
                new_files_to_db.append((sha256, archive_name))
                known_hashes.add(sha256)

    if new_files_to_db:
        conn.executemany("INSERT OR IGNORE INTO files VALUES (?, ?)", new_files_to_db)
        conn.commit()
    print(f"    ✅ Processed {len(new_files_to_db)} unique general files.")

def organize_photos(source_dir, final_dir, conn, archive_name):
    print("\n--> [Step 2c] Organizing photos...")
    photos_source_path = os.path.join(source_dir, "Takeout", "Google Photos")
    if not os.path.isdir(photos_source_path):
        print("    > 'Google Photos' directory not found. Skipping.")
        return

    known_hashes = {row[0] for row in conn.execute("SELECT sha256_hash FROM files")}
    new_files_to_db = []
    
    for root, _, files in os.walk(photos_source_path):
        for filename in files:
            if filename.lower().endswith('.json'): continue
            media_path = os.path.join(root, filename)
            with open(media_path, 'rb') as f:
                sha256 = hashlib.sha256(f.read()).hexdigest()

            if sha256 in known_hashes: continue

            json_path = os.path.splitext(media_path)[0] + '.json'
            ts = int(os.path.getmtime(media_path)) # Fallback to file modification time
            if os.path.exists(json_path):
                try:
                    with open(json_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                    ts = int(data.get('photoTakenTime', {}).get('timestamp', ts))
                except: pass

            dt = datetime.fromtimestamp(ts)
            new_name = f"{dt.strftime('%Y-%m-%d_%Hh%Mm%Ss')}_{filename}"
            final_filepath = os.path.join(final_dir, new_name)

            shutil.move(media_path, final_filepath)
            new_files_to_db.append((sha256, archive_name))
            known_hashes.add(sha256)

    if new_files_to_db:
        conn.executemany("INSERT OR IGNORE INTO files VALUES (?, ?)", new_files_to_db)
        conn.commit()
    print(f"    ✅ Processed {len(new_files_to_db)} unique photos.")


def main():
    conn = None
    try:
        print("--> [Step 0] Initializing environment...")
        for path in CONFIG.values(): os.makedirs(path, exist_ok=True)
        os.makedirs(VM_TEMP_EXTRACT_DIR, exist_ok=True)

        conn = initialize_database(DB_PATH)
        perform_startup_integrity_check()
        print("✅ Workspace ready.")

        while True:
            print("\n--> [Step 1] Identifying unprocessed archives...")
            if not os.path.exists(CONFIG["SOURCE_ARCHIVES_DIR"]):
                print(f"    > Source directory not found. Is Drive mounted? Sleeping...")
                time.sleep(PROCESSING_IDLE_SLEEP_SECONDS)
                continue

            all_archives = set(os.listdir(CONFIG["SOURCE_ARCHIVES_DIR"]))
            completed_archives = set(os.listdir(CONFIG["COMPLETED_ARCHIVES_DIR"]))
            processing_queue = sorted([f for f in list(all_archives - completed_archives) if not f.startswith('.')])

            if not processing_queue:
                print("\n✅🎉 No archives to process. Idling...")
                time.sleep(PROCESSING_IDLE_SLEEP_SECONDS)
                continue

            archive_name = processing_queue[0]
            source_path = os.path.join(CONFIG["SOURCE_ARCHIVES_DIR"], archive_name)
            staging_path = os.path.join(CONFIG["PROCESSING_STAGING_DIR"], archive_name)

            print(f"--> Locking and staging '{archive_name}' for processing...")
            shutil.move(source_path, staging_path)

            try:
                print(f"\n--> [Step 2a] Extracting '{archive_name}'...")
                with tarfile.open(staging_path, 'r:gz') as tf:
                    tf.extractall(path=VM_TEMP_EXTRACT_DIR)

                organize_photos(VM_TEMP_EXTRACT_DIR, CONFIG["ORGANIZED_PHOTOS_DIR"], conn, archive_name)
                deduplicate_and_move_files(VM_TEMP_EXTRACT_DIR, CONFIG["ORGANIZED_FILES_DIR"], CONFIG["DUPES_DIR"], conn, archive_name)
                
                shutil.move(staging_path, os.path.join(CONFIG["COMPLETED_ARCHIVES_DIR"], archive_name))
                print(f"✅ Transaction for '{archive_name}' complete.")

            except Exception as e:
                print(f"❌ ERROR processing '{archive_name}': {e}")
                traceback.print_exc()
                # Rollback
                shutil.move(staging_path, source_path)
            finally:
                if os.path.exists(VM_TEMP_EXTRACT_DIR):
                    shutil.rmtree(VM_TEMP_EXTRACT_DIR)

            print("\n--- WORKFLOW CYCLE COMPLETE ---")
            
    except Exception as e:
        print(f"\n❌ A CRITICAL UNHANDLED ERROR OCCURRED: {e}")
        traceback.print_exc()
    finally:
        if conn:
            conn.close()
            print("--> [DB] Database connection closed.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.parse_known_args()
    main()
EOF
    # --- END EMBEDDED PYTHON SCRIPT ---

    chmod +x "$PROCESSOR_SCRIPT_PATH"
    _log_ok "Application script deployed successfully."
    
    _log_info "Creating and enabling systemd services..."
    
    # --- RCLONE MOUNT SERVICE ---
    cat << EOF > "$RCLONE_SERVICE_PATH"
[Unit]
Description=Google Drive Mount Service (rclone)
After=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/bin/rclone mount "gdrive:" "${GDRIVE_MOUNT_POINT}" \\
    --config "${RCLONE_CONFIG_PATH}" \\
    --allow-other \\
    --vfs-cache-mode writes \\
    --log-level INFO
ExecStop=/bin/fusermount -u "${GDRIVE_MOUNT_POINT}"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # --- PYTHON PROCESSOR SERVICE ---
    cat << EOF > "$PROCESSOR_SERVICE_PATH"
[Unit]
Description=Google Takeout Organizer Service (v4.0)
# This service requires the drive to be mounted first
Requires=${RCLONE_SERVICE_NAME}
After=${RCLONE_SERVICE_NAME}

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${PROCESSOR_SCRIPT_PATH}
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$RCLONE_SERVICE_NAME"
    systemctl enable "$PROCESSOR_SERVICE_NAME"
    _log_ok "Systemd services created and enabled."

    echo ""
    _log_ok "--------------------------------------------------------"
    _log_ok "Takeout Processor Appliance Setup is COMPLETE!"
    _log_warn "ACTION REQUIRED: A valid 'rclone.conf' must be placed at:"
    _log_warn "  ${RCLONE_CONFIG_PATH}"
    _log_warn "The remote must be named 'gdrive:' for the mount to work."
    _log_info "After placing the file, reboot or run:"
    _log_info "  systemctl start ${RCLONE_SERVICE_NAME}"
    _log_info "  systemctl start ${PROCESSOR_SERVICE_NAME}"
    _log_info "To monitor, run: journalctl -fu ${PROCESSOR_SERVICE_NAME}"
    _log_ok "--------------------------------------------------------"
}

main
