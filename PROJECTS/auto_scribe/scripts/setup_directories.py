import os
import logging

SANDBOX_PATH = "/mnt/data/sandbox"

def setup_directories():
    directories = [
        "Introduction", "Preparation", "System Backup", "Recovery and Repair",
        "Automation Scripts", "Testing and Validation", "Advanced Topics",
        "Troubleshooting", "Conclusion", "Drafts", "Final"
    ]
    for directory in directories:
        path = os.path.join(SANDBOX_PATH, "data", directory)
        os.makedirs(path, exist_ok=True)
    logging.info("Directories set up successfully.")

setup_directories()
