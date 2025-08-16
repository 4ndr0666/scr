import os
import shutil
import subprocess
import tarfile
import json
from datetime import datetime
import traceback
import re
import sys
import argparse
import sqlite3
import hashlib
import time
from tqdm.notebook import tqdm # Correct import for Colab environment
from google.colab import drive # Correct import for Colab environment

# ==============================================================================
# --- 1. CORE CONFIGURATION ---
# ==============================================================================
TARGET_MAX_VM_USAGE_GB = 70
REPACKAGE_CHUNK_SIZE_GB = 15
MAX_SAFE_ARCHIVE_SIZE_GB = 25

BASE_DIR = "/content/drive/MyDrive/TakeoutProject"
DB_PATH = os.path.join(BASE_DIR, "takeout_archive.db")
CONFIG = {
    "SOURCE_ARCHIVES_DIR": os.path.join(BASE_DIR, "00-ALL-ARCHIVES/"),
    "PROCESSING_STAGING_DIR": os.path.join(BASE_DIR, "01-PROCESSING-STAGING/"),
    "ORGANIZED_DIR": os.path.join(BASE_DIR, "03-organized/My-Photos/"),
    "TRASH_DIR": os.path.join(BASE_DIR, "04-trash/"),
    "COMPLETED_ARCHIVES_DIR": os.path.join(BASE_DIR, "05-COMPLETED-ARCHIVES/"),
}
CONFIG["QUARANTINE_DIR"] = os.path.join(CONFIG["TRASH_DIR"], "quarantined_artifacts/")
CONFIG["DUPES_DIR"] = os.path.join(CONFIG["TRASH_DIR"], "duplicates/")
VM_TEMP_EXTRACT_DIR = '/content/temp_extract'
VM_TEMP_BATCH_DIR = '/content/temp_batch_creation'

# ==============================================================================
# --- 2. WORKFLOW FUNCTIONS & HELPERS ---
# ==============================================================================
def initialize_database(db_path):
    print("--> [DB] Initializing database...")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS files (
        id INTEGER PRIMARY KEY, sha256_hash TEXT NOT NULL UNIQUE, original_path TEXT NOT NULL,
        final_path TEXT, timestamp INTEGER, file_size INTEGER NOT NULL, source_archive TEXT NOT NULL
    )''')
    conn.commit()
    print("    ✅ Database ready.")
    return conn

def perform_startup_integrity_check():
    print("--> [POST] Performing startup integrity check...")
    staging_dir = CONFIG["PROCESSING_STAGING_DIR"]
    source_dir = CONFIG["SOURCE_ARCHIVES_DIR"]
    if os.path.exists(staging_dir) and os.listdir(staging_dir):
        print("    ⚠️ Found orphaned files. Rolling back transaction...")
        for orphan_file in os.listdir(staging_dir):
            shutil.move(os.path.join(staging_dir, orphan_file), os.path.join(source_dir, orphan_file))
        if os.path.exists(VM_TEMP_EXTRACT_DIR): shutil.rmtree(VM_TEMP_EXTRACT_DIR)
        print("    ✅ Rollback complete.")
    if os.path.exists(source_dir):
        for filename in os.listdir(source_dir):
            file_path = os.path.join(source_dir, filename)
            if os.path.isfile(file_path) and os.path.getsize(file_path) == 0:
                print(f"    ⚠️ Found 0-byte artifact: '{filename}'. Quarantining...")
                shutil.move(file_path, os.path.join(CONFIG["QUARANTINE_DIR"], filename))
    print("--> [POST] Integrity check complete.")

def plan_and_repackage_archive(archive_path, dest_dir, conn, tqdm_module):
    original_basename_no_ext = os.path.splitext(os.path.basename(archive_path))[0]
    print(f"--> Repackaging & Indexing '{os.path.basename(archive_path)}'...")
    repackage_chunk_size_bytes = REPACKAGE_CHUNK_SIZE_GB * (1024**3)
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT sha256_hash FROM files")
        existing_hashes = {row[0] for row in cursor.fetchall()}
        existing_parts = [f for f in os.listdir(dest_dir) if f.startswith(original_basename_no_ext) and '.part-' in f]
        last_part_num = 0
        if existing_parts:
            part_numbers = [int(re.search(r'\.part-(\d+)\.tgz', f).group(1)) for f in existing_parts if re.search(r'\.part-(\d+)\.tgz', f)]
            if part_numbers: last_part_num = max(part_numbers)
            print(f"    ✅ Resuming after part {last_part_num}.")
        batches, current_batch, current_batch_size = [], [], 0
        with tarfile.open(archive_path, 'r:gz') as original_tar:
            all_members = [m for m in original_tar.getmembers() if m.isfile()]
            for member in all_members:
                if current_batch and (current_batch_size + member.size) > repackage_chunk_size_bytes:
                    batches.append(current_batch); current_batch, current_batch_size = [], 0
                current_batch.append(member); current_batch_size += member.size
            if current_batch: batches.append(current_batch)
        print(f"    > Plan complete: {len(all_members)} files -> up to {len(batches)} new archives.")
        for i, batch in enumerate(batches):
            part_number = i + 1
            if part_number <= last_part_num: continue
            os.makedirs(VM_TEMP_BATCH_DIR, exist_ok=True)
            temp_batch_archive_path = os.path.join(VM_TEMP_BATCH_DIR, f"temp_batch_{part_number}.tgz")
            files_in_this_batch = 0
            with tarfile.open(temp_batch_archive_path, 'w:gz') as temp_tar:
                with tarfile.open(archive_path, 'r:gz') as original_tar_stream:
                    for member in tqdm_module(batch, desc=f"Hashing & Staging Batch {part_number}"):
                        file_obj = original_tar_stream.extractfile(member)
                        if not file_obj: continue
                        file_content = file_obj.read()
                        sha256 = hashlib.sha256(file_content).hexdigest()
                        if sha256 in existing_hashes: continue
                        file_obj.seek(0)
                        temp_tar.addfile(member, file_obj)
                        cursor.execute("INSERT INTO files (sha256_hash, original_path, file_size, source_archive) VALUES (?, ?, ?, ?)",
                                       (sha256, member.name, member.size, os.path.basename(archive_path)))
                        existing_hashes.add(sha256)
                        files_in_this_batch += 1
            if files_in_this_batch > 0:
                conn.commit()
                new_archive_name = f"{original_basename_no_ext}.part-{part_number:02d}.tgz"
                final_dest_path = os.path.join(dest_dir, new_archive_name)
                shutil.move(temp_batch_archive_path, final_dest_path)
        return True
    except Exception as e: print(f"\n❌ ERROR during JIT repackaging: {e}"); traceback.print_exc(); return False
    finally:
        if os.path.exists(VM_TEMP_BATCH_DIR): shutil.rmtree(VM_TEMP_BATCH_DIR)

def process_regular_archive(archive_path, conn, tqdm_module, auto_delete_artifacts):
    archive_name = os.path.basename(archive_path)
    print(f"\n--> Processing transaction for '{archive_name}'...")
    cursor = conn.cursor()
    try:
        if os.path.getsize(archive_path) == 0:
            if auto_delete_artifacts: os.remove(archive_path)
            else: shutil.move(archive_path, os.path.join(CONFIG["QUARANTINE_DIR"], archive_name))
            return False
        cursor.execute("SELECT original_path FROM files WHERE source_archive = ? AND final_path IS NOT NULL", (archive_name,))
        completed_files = {row[0] for row in cursor.fetchall()}
        os.makedirs(VM_TEMP_EXTRACT_DIR, exist_ok=True)
        with tarfile.open(archive_path, 'r:gz') as tf:
            all_members = [m for m in tf.getmembers() if m.isfile()]
            for member in tqdm_module(all_members, desc=f"Scanning {archive_name}"):
                if member.name not in completed_files:
                    tf.extract(member, path=VM_TEMP_EXTRACT_DIR, set_attrs=False)
        if not os.listdir(VM_TEMP_EXTRACT_DIR):
            print("    ✅ All files in this archive were already processed."); return True
        print(f"    ✅ Unpacked new/missing files to temp dir.")
        organize_photos(VM_TEMP_EXTRACT_DIR, CONFIG["ORGANIZED_DIR"], conn, tqdm_module, archive_name)
        deduplicate_files(VM_TEMP_EXTRACT_DIR, CONFIG["ORGANIZED_DIR"], CONFIG["DUPES_DIR"], conn, archive_name)
        return True
    except Exception as e: print(f"\n❌ ERROR during transaction: {e}"); traceback.print_exc(); return False
    finally:
        if os.path.exists(VM_TEMP_EXTRACT_DIR): shutil.rmtree(VM_TEMP_EXTRACT_DIR)

def deduplicate_files(source_path, primary_storage_path, trash_path, conn, source_archive_name):
    print("--> Deduplicating new files...")
    if not shutil.which('jdupes'): return
    command = f'jdupes -r -S -nh --linkhard --move="{trash_path}" "{source_path}" "{primary_storage_path}"'
    subprocess.run(command, shell=True, capture_output=True)
    cursor = conn.cursor()
    files_moved = 0
    takeout_source = os.path.join(source_path, "Takeout")
    if os.path.exists(takeout_source):
        for root, _, files in os.walk(takeout_source):
            for filename in files:
                unique_file_path = os.path.join(root, filename)
                relative_path = os.path.relpath(unique_file_path, takeout_source)
                final_path = os.path.join(primary_storage_path, relative_path)
                os.makedirs(os.path.dirname(final_path), exist_ok=True)
                shutil.move(unique_file_path, final_path)
                original_path = os.path.relpath(unique_file_path, source_path)
                cursor.execute("UPDATE files SET final_path = ? WHERE original_path = ? AND source_archive = ?",
                               (final_path, original_path, source_archive_name))
                files_moved += 1
        if files_moved > 0: conn.commit()
    print(f"    ✅ Processed {files_moved} unique files.")

def organize_photos(source_path, final_dir, conn, tqdm_module, source_archive_name):
    print("--> Organizing photos...")
    photos_organized_count = 0
    photos_source_path = os.path.join(source_path, "Takeout", "Google Photos")
    if not os.path.isdir(photos_source_path): return
    try: existing_filenames = set(os.listdir(final_dir))
    except FileNotFoundError: existing_filenames = set()
    all_json_files = [os.path.join(r, f) for r, _, files in os.walk(photos_source_path) for f in files if f.lower().endswith('.json')]
    cursor = conn.cursor()
    for json_path in tqdm_module(all_json_files, desc="Organizing photos"):
        media_path = os.path.splitext(json_path)[0]
        if not os.path.exists(media_path): continue
        try:
            with open(json_path, 'r', encoding='utf-8') as f: data = json.load(f)
            ts = data.get('photoTakenTime', {}).get('timestamp')
            if not ts: continue
            dt = datetime.fromtimestamp(int(ts)); new_name_base = dt.strftime('%Y-%m-%d_%Hh%Mm%Ss'); ext = os.path.splitext(media_path)[1].lower()
            new_filename = f"{new_name_base}{ext}"; counter = 0
            while new_filename in existing_filenames:
                counter += 1; new_filename = f"{new_name_base}_{counter}{ext}"
            final_filepath = os.path.join(final_dir, new_filename)
            shutil.move(media_path, final_filepath)
            original_path = os.path.relpath(media_path, source_path)
            cursor.execute("UPDATE files SET final_path = ?, timestamp = ? WHERE original_path = ? AND source_archive = ?",
                           (final_filepath, int(ts), original_path, source_archive_name))
            existing_filenames.add(new_filename); photos_organized_count += 1
        except Exception: continue
    if photos_organized_count > 0:
        conn.commit()
        print(f"    ✅ Organized and updated DB for {photos_organized_count} new files.")

# ==============================================================================
# --- MAIN EXECUTION SCRIPT ---
# ==============================================================================
def main(args):
    conn = None
    try:
        print("--> [Step 0] Initializing environment...")
        
        # This is the standard script for Colab, so we need the Colab-specific code.
        drive.mount('/content/drive')
        
        for path in CONFIG.values(): os.makedirs(path, exist_ok=True)
        conn = initialize_database(DB_PATH)
        perform_startup_integrity_check()

        total_vm, used_vm, free_vm = shutil.disk_usage('/content/')
        used_vm_gb = used_vm / (1024**3)
        if used_vm_gb > TARGET_MAX_VM_USAGE_GB:
            print(f"\n❌ PRE-FLIGHT CHECK FAILED: Initial disk usage ({used_vm_gb:.2f} GB) is too high.")
            print("    >>> PLEASE RESTART THE COLAB RUNTIME (Runtime -> Restart runtime) AND TRY AGAIN. <<<")
            return
        print(f"✅ Pre-flight disk check passed. (Initial Usage: {used_vm_gb:.2f} GB)")
        subprocess.run("apt-get -qq install jdupes", shell=True)
        print("✅ Workspace ready.")

        print("\n--> [Step 1] Identifying unprocessed archives...")
        all_archives = set(os.listdir(CONFIG["SOURCE_ARCHIVES_DIR"]))
        completed_archives = set(os.listdir(CONFIG["COMPLETED_ARCHIVES_DIR"]))
        processing_queue = sorted(list(all_archives - completed_archives))

        if not processing_queue:
            print("\n✅🎉 All archives have been processed!")
        else:
            archive_name = processing_queue[0]
            source_path = os.path.join(CONFIG["SOURCE_ARCHIVES_DIR"], archive_name)
            staging_path = os.path.join(CONFIG["PROCESSING_STAGING_DIR"], archive_name)

            print(f"--> Locking and staging '{archive_name}' for processing...")
            shutil.move(source_path, staging_path)

            archive_size_gb = os.path.getsize(staging_path) / (1024**3)
            if archive_size_gb > MAX_SAFE_ARCHIVE_SIZE_GB and '.part-' not in archive_name:
                processed_ok = plan_and_repackage_archive(staging_path, CONFIG["SOURCE_ARCHIVES_DIR"], conn, tqdm)
            else:
                processed_ok = process_regular_archive(staging_path, conn, tqdm, args.auto_delete_artifacts)
            
            if processed_ok:
                shutil.move(staging_path, os.path.join(CONFIG["COMPLETED_ARCHIVES_DIR"], archive_name))
            else:
                print(f"    ❌ Transaction failed for '{archive_name}'. It will be rolled back on the next run.")

            print("\n--- WORKFLOW CYCLE COMPLETE. ---")
    except Exception as e:
        print(f"\n❌ A CRITICAL UNHANDLED ERROR OCCURRED: {e}"); traceback.print_exc()
    finally:
        if conn:
            conn.close()
            print("--> [DB] Database connection closed.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Process Google Takeout archives.")
    parser.add_argument('--auto-delete-artifacts', action='store_true', help="Enable automatic deletion of 0-byte artifact files.")
    try:
        args = parser.parse_args([])
    except SystemExit:
        args = parser.parse_args()
    main(args)
