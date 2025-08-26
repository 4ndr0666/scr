# Google Takeout Organizer Appliance

## Overview

The **Google Takeout Organizer Appliance** is a headless, automated system designed to process and organize large Google Takeout archives. It operates as a long-running service on a low-power device, such as a Raspberry Pi running DietPi, making it a "set it and forget it" solution for digital archivists.

This project was born out of the necessity to handle Google Takeout's unwieldy, multi-gigabyte `.tgz` archives. Manually downloading, extracting, deduplicating, and organizing this data is tedious and error-prone. This appliance automates the entire workflow, transforming a chaotic collection of archives into a neatly organized, date-structured, and deduplicated library of your personal data directly within Google Drive.

The core of the appliance is a Python script that uses the `PyDrive2` library to interact directly with the Google Drive API. It is designed to be robust, with transactional processing, startup integrity checks, and a resilient, timer-based execution model managed by `systemd`.

## Key Features

-   **Headless & Automated:** Designed to run 24/7 on a server without any user interaction.
-   **Transactional Processing:** Each archive is processed in an "all or nothing" transaction. If any step fails, the operation is rolled back, ensuring no data is left in a partially-processed state.
-   **Intelligent Photo Organization:** Parses Google Photos' `.json` metadata to accurately rename and date-sort your photos, preserving the correct chronological order.
-   **Deduplication:** All non-photo files are hashed (SHA256). Duplicates already present in your organized library are discarded, saving significant storage space.
-   **Robust Error Handling:** Includes startup integrity checks to recover from crashes or unexpected shutdowns, automatically rolling back incomplete tasks.
-   **Timer-Based Execution:** Uses a `systemd` timer to run periodically (e.g., every 15 minutes). This is more efficient and reliable than a continuous `while True` loop, ensuring clean starts and low idle resource usage.
-   **API-Driven:** Interacts directly with the Google Drive API, eliminating the need for fragile and slow file system mounts (`rclone`, `drive.mount`).

## How It Works

The appliance operates on a simple, robust loop managed by a `systemd` timer:

1.  **Scan:** The service wakes up and queries the `00-ALL-ARCHIVES` folder in your Google Drive's `TakeoutProject` directory.
2.  **Select & Stage:** It selects the oldest archive for processing and moves it to the `01-PROCESSING-STAGING` folder. This acts as a transactional lock.
3.  **Download:** The archive is downloaded to a temporary local directory (`/tmp`) on the appliance.
4.  **Process Locally:**
    *   The archive is extracted.
    *   **Photos** are identified, renamed according to their metadata timestamp (`YYYY-MM-DD_HHhMMs_filename.ext`), and uploaded to `03-organized/My-Photos`. Their hashes are recorded.
    *   **Other files** are hashed. If the hash is new, the file is uploaded to `03-organized/My-Files`. If the hash already exists in the database, the file is discarded.
5.  **Finalize:** Upon successful processing, the original archive is moved from `01-PROCESSING-STAGING` to `05-COMPLETED-ARCHIVES`.
6.  **Exit:** The script cleans up all temporary files and exits, waiting for the next trigger from the `systemd` timer.

If any step fails, the script attempts to move the archive from `01-PROCESSING-STAGING` back to `00-ALL-ARCHIVES` before exiting. The startup integrity check will also catch and roll back any stalled archives from a previous failed run.

## Installation on DietPi (or other Debian-based systems)

This setup assumes you are running as the `root` user.

### Prerequisites

1.  **A Google Cloud Project:** You need a project with the Google Drive API enabled.
2.  **Service Account Credentials:** You must create a Service Account within your Google Cloud Project. Download its key as a `client_secrets.json` file.
3.  **Share Google Drive Folder:** Share the root `TakeoutProject` folder (or the folder where you will upload your archives) with the service account's email address (e.g., `your-service-account@your-project.iam.gserviceaccount.com`).

### Deployment Steps

1.  **SSH into your DietPi device.**

2.  **Create the installation directory:**
    ```bash
    mkdir -p /opt/google_takeout_organizer
    ```

3.  **Place Credentials:** Copy your `client_secrets.json` file to the device at the following exact path:
    ```
    /opt/google_takeout_organizer/client_secrets.json
    ```

4.  **Create the Setup Script:** Create the main setup script file.
    ```bash
    nano setup_takeout_organizer.sh
    ```
    Paste the entire contents of the `setup_takeout_organizer.sh` (v6.0) script into this file. Save and exit (`Ctrl+X`, `Y`, `Enter`).

5.  **Make the script executable and run it:**
    ```bash
    chmod +x setup_takeout_organizer.sh
    ./setup_takeout_organizer.sh
    ```
    This script will perform the following actions:
    *   Stop and remove any old versions of the service.
    *   Install necessary system packages (`python3`, `pip`, `jdupes`).
    *   Install required Python libraries (`PyDrive2`, `tqdm`).
    *   Deploy the main Python script to `/opt/google_takeout_organizer/`.
    *   Create, enable, and start a `systemd` timer (`takeout-organizer.timer`) that runs the processor service every 15 minutes.

## Usage & Monitoring

The appliance is designed to be fully autonomous. Once set up, it will run automatically.

*   **To check the logs in real-time:**
    ```bash
    journalctl -fu takeout-organizer.service
    ```

*   **To check the status of the timer (when it last ran and when it will next):**
    ```bash
    systemctl list-timers
    ```

*   **To trigger a manual run immediately:**
    ```bash
    systemctl start takeout-organizer.service
    ```

*   **To upload new archives:** Simply upload your Google Takeout `.tgz` files to the `TakeoutProject/00-ALL-ARCHIVES` folder in your Google Drive. The appliance will automatically pick them up on its next run.

---
