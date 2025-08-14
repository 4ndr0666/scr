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
VM_TEMP_EXTRACT_DIR = "/content/temp_extract"
VM_TEMP_BATCH_DIR = "/content/temp_batch_creation"


# ==============================================================================
# --- 2. WORKFLOW FUNCTIONS & HELPERS ---
# ==============================================================================
def dummy_tqdm(iterable, *args, **kwargs):
    description = kwargs.get("desc", "items")
    print(f"    > Processing {description}...")
    return iterable


def initialize_database(db_path):
    """Creates the SQLite database and the necessary tables if they don't exist."""
    print("--> [DB] Initializing database...")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute(
        """
    CREATE TABLE IF NOT EXISTS files (
        id INTEGER PRIMARY KEY,
        sha256_hash TEXT NOT NULL UNIQUE,
        original_path TEXT NOT NULL,
        final_path TEXT,
        timestamp INTEGER,
        file_size INTEGER NOT NULL,
        source_archive TEXT NOT NULL
    )
    """
    )
    conn.commit()
    print("    ✅ Database ready.")
    return conn


def perform_startup_integrity_check():
    # This function is stable and complete
    print("--> [POST] Performing startup integrity check...")
    staging_dir = CONFIG["PROCESSING_STAGING_DIR"]
    source_dir = CONFIG["SOURCE_ARCHIVES_DIR"]
    if os.path.exists(staging_dir) and os.listdir(staging_dir):
        print(
            "    ⚠️ Found orphaned files in processing directory. Rolling back failed transaction..."
        )
        for orphan_file in os.listdir(staging_dir):
            shutil.move(
                os.path.join(staging_dir, orphan_file),
                os.path.join(source_dir, orphan_file),
            )
            print(f"        > Rolled back '{orphan_file}'.")
        if os.path.exists(VM_TEMP_EXTRACT_DIR):
            shutil.rmtree(VM_TEMP_EXTRACT_DIR)
        print("    ✅ Rollback complete.")
    for filename in os.listdir(source_dir):
        file_path = os.path.join(source_dir, filename)
        if os.path.isfile(file_path) and os.path.getsize(file_path) == 0:
            print(f"    ⚠️ Found 0-byte artifact: '{filename}'. Quarantining...")
            shutil.move(file_path, os.path.join(CONFIG["QUARANTINE_DIR"], filename))
            print("    ✅ Artifact quarantined.")
    print("--> [POST] Integrity check complete.")


def plan_and_repackage_archive(archive_path, dest_dir, conn, tqdm_module):
    # This function is stable and complete
    original_basename_no_ext = os.path.splitext(os.path.basename(archive_path))[0]
    print(f"--> Repackaging & Indexing '{os.path.basename(archive_path)}'...")
    repackage_chunk_size_bytes = REPACKAGE_CHUNK_SIZE_GB * (1024**3)
    cursor = conn.cursor()
    try:
        print("    > Loading existing file hashes from database...")
        cursor.execute("SELECT sha256_hash FROM files")
        existing_hashes = {row[0] for row in cursor.fetchall()}
        print(f"    > Index loaded with {len(existing_hashes)} records.")
        existing_parts = [
            f
            for f in os.listdir(dest_dir)
            if f.startswith(original_basename_no_ext) and ".part-" in f
        ]
        last_part_num = 0
        if existing_parts:
            part_numbers = [
                int(re.search(r"\.part-(\d+)\.tgz", f).group(1))
                for f in existing_parts
                if re.search(r"\.part-(\d+)\.tgz", f)
            ]
            if part_numbers:
                last_part_num = max(part_numbers)
            print(f"    ✅ Resuming after part {last_part_num}.")
        batches, current_batch, current_batch_size = [], [], 0
        with tarfile.open(archive_path, "r:gz") as original_tar:
            all_members = [m for m in original_tar.getmembers() if m.isfile()]
            for member in all_members:
                if (
                    current_batch
                    and (current_batch_size + member.size) > repackage_chunk_size_bytes
                ):
                    batches.append(current_batch)
                    current_batch, current_batch_size = [], 0
                current_batch.append(member)
                current_batch_size += member.size
            if current_batch:
                batches.append(current_batch)
        print(
            f"    > Plan complete: {len(all_members)} files -> up to {len(batches)} new archives."
        )
        for i, batch in enumerate(batches):
            part_number = i + 1
            if part_number <= last_part_num:
                continue
            os.makedirs(VM_TEMP_BATCH_DIR, exist_ok=True)
            temp_batch_archive_path = os.path.join(
                VM_TEMP_BATCH_DIR, f"temp_batch_{part_number}.tgz"
            )
            files_in_this_batch = 0
            with tarfile.open(temp_batch_archive_path, "w:gz") as temp_tar:
                with tarfile.open(archive_path, "r:gz") as original_tar_stream:
                    for member in tqdm_module(
                        batch, desc=f"Hashing & Staging Batch {part_number}"
                    ):
                        file_obj = original_tar_stream.extractfile(member)
                        if not file_obj:
                            continue
                        file_content = file_obj.read()
                        sha256 = hashlib.sha256(file_content).hexdigest()
                        if sha256 in existing_hashes:
                            continue
                        file_obj.seek(0)
                        temp_tar.addfile(member, file_obj)
                        cursor.execute(
                            "INSERT INTO files (sha256_hash, original_path, file_size, source_archive) VALUES (?, ?, ?, ?)",
                            (
                                sha256,
                                member.name,
                                member.size,
                                os.path.basename(archive_path),
                            ),
                        )
                        existing_hashes.add(sha256)
                        files_in_this_batch += 1
            if files_in_this_batch > 0:
                conn.commit()
                new_archive_name = (
                    f"{original_basename_no_ext}.part-{part_number:02d}.tgz"
                )
                final_dest_path = os.path.join(dest_dir, new_archive_name)
                print(
                    f"    --> Batch contains {files_in_this_batch} unique files. Moving final part {part_number} to Google Drive..."
                )
                shutil.move(temp_batch_archive_path, final_dest_path)
                print(f"    ✅ Finished part {part_number}.")
            else:
                print(
                    f"    > Batch {part_number} contained no unique files. Discarding empty batch."
                )
        return True
    except Exception as e:
        print(f"\n❌ ERROR during JIT repackaging: {e}")
        traceback.print_exc()
        return False
    finally:
        if os.path.exists(VM_TEMP_BATCH_DIR):
            shutil.rmtree(VM_TEMP_BATCH_DIR)


def process_regular_archive(archive_path, conn, tqdm_module):
    """
    Handles a regular-sized archive. It unpacks to a temporary VM directory,
    hashes and indexes unique files, then runs organization and deduplication.
    """
    archive_name = os.path.basename(archive_path)
    print(f"\n--> [Step 2a] Processing transaction for '{archive_name}'...")
    cursor = conn.cursor()
    try:
        print("    > Loading existing file hashes from database...")
        cursor.execute("SELECT sha256_hash FROM files")
        existing_hashes = {row[0] for row in cursor.fetchall()}
        print(f"    > Index loaded with {len(existing_hashes)} records.")

        os.makedirs(VM_TEMP_EXTRACT_DIR, exist_ok=True)
        # Unpack first
        with tarfile.open(archive_path, "r:gz") as tf:
            for member in tqdm_module(
                tf.getmembers(), desc=f"Unpacking {archive_name} to VM"
            ):
                if member.isfile():
                    tf.extract(member, path=VM_TEMP_EXTRACT_DIR, set_attrs=False)
        print(f"    ✅ Unpacked to temporary VM directory.")

        # Hash and index unique files
        print("    > Hashing and indexing new files...")
        new_files_count = 0
        for root, _, files in os.walk(VM_TEMP_EXTRACT_DIR):
            for filename in tqdm_module(files, desc="Indexing files"):
                file_path = os.path.join(root, filename)
                with open(file_path, "rb") as f:
                    file_content = f.read()
                sha256 = hashlib.sha256(file_content).hexdigest()

                if sha256 not in existing_hashes:
                    original_path = os.path.relpath(file_path, VM_TEMP_EXTRACT_DIR)
                    cursor.execute(
                        "INSERT INTO files (sha256_hash, original_path, file_size, source_archive) VALUES (?, ?, ?, ?)",
                        (
                            sha256,
                            original_path,
                            os.path.getsize(file_path),
                            archive_name,
                        ),
                    )
                    existing_hashes.add(sha256)
                    new_files_count += 1

        if new_files_count > 0:
            conn.commit()
            print(f"    ✅ Indexed {new_files_count} new unique files.")
        else:
            print("    > No new unique files found in this archive.")

        # Run organization and deduplication
        organize_photos(VM_TEMP_EXTRACT_DIR, CONFIG["ORGANIZED_DIR"], conn, tqdm_module)
        deduplicate_files(
            VM_TEMP_EXTRACT_DIR, CONFIG["ORGANIZED_DIR"], CONFIG["DUPES_DIR"]
        )

        return True
    except Exception as e:
        print(f"\n❌ ERROR during archive processing transaction: {e}")
        traceback.print_exc()
        return False
    finally:
        if os.path.exists(VM_TEMP_EXTRACT_DIR):
            shutil.rmtree(VM_TEMP_EXTRACT_DIR)
            print("    > Cleaned up temporary VM directory.")


def deduplicate_files(source_path, primary_storage_path, trash_path):
    # This function is stable and complete
    print("\n--> [Step 2b] Deduplicating new files...")
    if not shutil.which("jdupes"):
        print("    ⚠️ 'jdupes' not found. Skipping.")
        return
    command = f'jdupes -r -S -nh --linkhard --move="{trash_path}" "{source_path}" "{primary_storage_path}"'
    subprocess.run(command, shell=True, capture_output=True)
    takeout_source = os.path.join(source_path, "Takeout")
    if os.path.exists(takeout_source):
        print("    > Moving unique new files to primary storage...")
        shutil.copytree(takeout_source, primary_storage_path, dirs_exist_ok=True)
    print("    ✅ Deduplication and move complete.")


def organize_photos(source_path, final_dir, conn, tqdm_module):
    # This function is stable and complete
    print("\n--> [Step 2c] Organizing photos...")
    photos_organized_count = 0
    photos_source_path = os.path.join(source_path, "Takeout", "Google Photos")
    if not os.path.isdir(photos_source_path):
        print("    > 'Google Photos' directory not found. Skipping.")
        return

    print("    > Building index of existing filenames for faster processing...")
    try:
        existing_filenames = set(os.listdir(final_dir))
    except FileNotFoundError:
        existing_filenames = set()
    print(f"    > Index complete with {len(existing_filenames)} files.")

    all_json_files = [
        os.path.join(r, f)
        for r, _, files in os.walk(photos_source_path)
        for f in files
        if f.lower().endswith(".json")
    ]
    cursor = conn.cursor()

    for json_path in tqdm_module(all_json_files, desc="Organizing photos"):
        media_path = os.path.splitext(json_path)[0]
        if not os.path.exists(media_path):
            continue
        try:
            with open(json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            ts = data.get("photoTakenTime", {}).get("timestamp")
            if not ts:
                continue

            dt = datetime.fromtimestamp(int(ts))
            new_name_base = dt.strftime("%Y-%m-%d_%Hh%Mm%Ss")
            ext = os.path.splitext(media_path)[1].lower()
            new_filename = f"{new_name_base}{ext}"
            counter = 0
            while new_filename in existing_filenames:
                counter += 1
                new_filename = f"{new_name_base}_{counter}{ext}"

            final_filepath = os.path.join(final_dir, new_filename)
            shutil.move(media_path, final_filepath)

            # Update the database with the final path
            original_path = os.path.relpath(media_path, source_path)
            cursor.execute(
                "UPDATE files SET final_path = ?, timestamp = ? WHERE original_path = ?",
                (final_filepath, int(ts), original_path),
            )

            existing_filenames.add(new_filename)
            photos_organized_count += 1
        except Exception:
            continue

    if photos_organized_count > 0:
        conn.commit()
        print(
            f"    ✅ Organized and updated DB for {photos_organized_count} new files."
        )


# ==============================================================================
# --- MAIN EXECUTION SCRIPT ---
# ==============================================================================
def main(args):
    conn = None
    try:
        print("--> [Step 0] Initializing environment...")
        try:
            from tqdm.notebook import tqdm
        except ImportError:
            tqdm = dummy_tqdm
        from google.colab import drive

        if not os.path.exists("/content/drive/MyDrive"):
            drive.mount("/content/drive")
        else:
            print("✅ Google Drive already mounted.")

        for path in CONFIG.values():
            os.makedirs(path, exist_ok=True)
        conn = initialize_database(DB_PATH)
        perform_startup_integrity_check()

        total_vm, used_vm, free_vm = shutil.disk_usage("/content/")
        used_vm_gb = used_vm / (1024**3)
        if used_vm_gb > TARGET_MAX_VM_USAGE_GB:
            print(
                f"\n❌ PRE-FLIGHT CHECK FAILED: Initial disk usage ({used_vm_gb:.2f} GB) is too high."
            )
            print(
                "    >>> PLEASE RESTART THE COLAB RUNTIME (Runtime -> Restart runtime) AND TRY AGAIN. <<<"
            )
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

            if (
                os.path.getsize(staging_path) / (1024**3) > MAX_SAFE_ARCHIVE_SIZE_GB
                and ".part-" not in archive_name
            ):
                repackaging_ok = plan_and_repackage_archive(
                    staging_path, CONFIG["SOURCE_ARCHIVES_DIR"], conn, tqdm
                )
                if repackaging_ok:
                    shutil.move(
                        staging_path,
                        os.path.join(CONFIG["COMPLETED_ARCHIVES_DIR"], archive_name),
                    )
            else:
                processed_ok = process_regular_archive(staging_path, conn, tqdm)
                if processed_ok:
                    shutil.move(
                        staging_path,
                        os.path.join(CONFIG["COMPLETED_ARCHIVES_DIR"], archive_name),
                    )
                else:
                    print(
                        f"    ❌ Transaction failed for '{archive_name}'. It will be rolled back on the next run."
                    )

            print("\n--- WORKFLOW CYCLE COMPLETE. ---")
    except Exception as e:
        print(f"\n❌ A CRITICAL UNHANDLED ERROR OCCURRED: {e}")
        traceback.print_exc()
    finally:
        if conn:
            conn.close()
            print("--> [DB] Database connection closed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process Google Takeout archives.")
    parser.add_argument(
        "--auto-delete-artifacts",
        action="store_true",
        help="Enable automatic deletion of 0-byte artifact files.",
    )
    try:
        args = parser.parse_args([])
    except SystemExit:
        args = parser.parse_args()
    main(args)
