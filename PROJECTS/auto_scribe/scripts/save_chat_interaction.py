import os
import datetime
import logging

SANDBOX_PATH = "/mnt/data/sandbox"

def save_chat_interaction(chat_text, section="Misc"):
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    file_path = os.path.join(SANDBOX_PATH, "data", section, f"chat_{timestamp}.md")
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(file_path, 'w') as file:
        file.write(chat_text)
    logging.info(f"Chat interaction saved to {file_path}")

# Example usage
chat_text = """
Today, I worked on backing up the system. Here are the steps:
1. Used getfacl to backup permissions.
2. Created a tarball with extended attributes.
"""
save_chat_interaction(chat_text, "System Backup")
