# Project: Google_takout_organizer.py (v4.0)

**Author:** 4ndr0666 & ProjectOS AI Assistant
**Version:** 4.0-database
**Status:** Production Ready, Stable

---

## 1. Overview

The Takeout Processor is an enterprise-grade, transactional data processing pipeline designed to handle massive Google Takeout archives within resource-constrained environments like Google Colab. It transforms opaque, multi-gigabyte `.tgz` archives into a clean, deduplicated, organized, and fully queryable personal data warehouse.

This script was born from the necessity of processing archives larger than the available disk space, and it has evolved to be a robust, self-healing, and highly efficient system for digital asset management.

![Workflow Visualization](https://i.imgur.com/your-image-link-here.png)  <!-- Placeholder for a flowchart or diagram -->

---

## 2. Core Features

*   **Transactional & Resilient:** Every operation is atomic. If the script crashes for any reason, it performs an automatic rollback on the next run, ensuring the system is always in a clean, consistent state.
*   **Intelligent Repackaging:** Automatically detects archives that are too large to process safely. It then uses a hyper-efficient "Just-in-Time" streaming process to break the large archive into smaller, manageable, numbered parts without ever overwhelming the local disk.
*   **Proactive, Hash-Based Deduplication:** Before writing a single file, the script calculates its SHA-256 hash and cross-references it against a central SQLite database. Known duplicates are never written, saving immense amounts of disk space and processing time.
*   **SQLite Database Indexing:** Every unique file is indexed in a central `takeout_archive.db` file. This database stores file metadata, including its hash, original path, final organized path, and timestamp, transforming your file archive into a powerful, queryable dataset.
*   **Performance Optimized:** From in-memory indexing for photo organization to Just-in-Time local batching, every function has been tuned to minimize slow network I/O and maximize performance in a cloud environment.
*   **Automated Self-Healing:** The script automatically detects and quarantines failed artifacts (like 0-byte files) from previous crashed runs.

---

## 3. Directory Structure

The script creates and manages a clear, logical directory structure within your `BASE_DIR`:

-   `takeout_archive.db`: The central SQLite database.
-   `00-ALL-ARCHIVES/`: **The Inbox.** Place all your raw Takeout `.tgz` files here.
-   `01-PROCESSING-STAGING/`: **The Transaction Lock.** (Should normally be empty). Files are moved here during active processing.
-   `03-organized/My-Photos/`: **The Final Destination.** Your clean, organized, and deduplicated photo library.
-   `04-trash/`:
    -   `duplicates/`: Contains all duplicate files found by `jdupes`.
    -   `quarantined_artifacts/`: Contains any corrupted or 0-byte files found.
-   `05-COMPLETED-ARCHIVES/`: **The Outbox.** Source archives are moved here after they have been successfully processed.

---

## 4. How to Use

This script is designed to be run iteratively in an environment like Google Colab.

### **Step 1: Initial Setup**

1.  Place your large Google Takeout `.tgz` files in the `00-ALL-ARCHIVES/` directory.
2.  Open the `takeout_processor.py` script in a Google Colab notebook.
3.  Ensure the `BASE_DIR` variable at the top of the script points to your project folder.

### **Step 2: Execution**

Simply run the main script cell. The script is designed to process **one transaction per run**.

-   If it finds a large archive, its first run will be dedicated to repackaging that archive into smaller parts.
-   Subsequent runs will then process each of those parts, one by one.

After the message `--- WORKFLOW CYCLE COMPLETE. ---` appears, simply run the cell again to process the next item in the queue.

### **Step 3: Automation (Optional)**

The script supports a command-line flag for fully automated runs:
*   `--auto-delete-artifacts`: If this flag is passed, the script will automatically delete 0-byte artifact files instead of moving them to the quarantine folder.

---

## 5. Dependencies

The script requires the following command-line utilities. It will attempt to install them automatically in a Colab environment.

-   `jdupes`: For the final, file-system-level deduplication.
-   `tqdm` (Python library): For displaying progress bars.
