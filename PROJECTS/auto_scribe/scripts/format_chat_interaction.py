import datetime

def format_chat_interaction(chat_text):
    formatted_text = f"## Interaction on {datetime.datetime.now().strftime('%Y-%m-%d')}\n\n" + chat_text
    return formatted_text

def save_formatted_interaction(chat_text, section="Misc"):
    formatted_text = format_chat_interaction(chat_text)
    save_chat_interaction(formatted_text, section)

# Example usage
formatted_text = """
Today, I worked on the system backup. The steps I followed were:
1. Backup permissions using getfacl.
2. Create a tarball with extended attributes.
"""
save_formatted_interaction(formatted_text, "System Backup")
