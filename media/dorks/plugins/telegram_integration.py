try:
    from telethon import TelegramClient
    import re
except ImportError as e:
    raise ImportError("This plugin requires 'telethon'. Install with: pip install telethon")

def search_and_extract(search_term, api_id, api_hash, session_name='4ndr0666OS', channels=None, max_results=100):
    """
    Search public Telegram channels for Mega.nz links matching the search term.
    Dedupes, error-resilient, ready for batch export.
    """
    if channels is None:
        channels = ['megaleaks', 'megahunt']  # Extend as needed
    results = set()
    try:
        with TelegramClient(session_name, api_id, api_hash) as client:
            for channel in channels:
                try:
                    for message in client.iter_messages(channel, search=search_term, limit=max_results):
                        found_links = re.findall(r'https?://mega\.nz/[^\s]+', message.text or '')
                        for link in found_links:
                            results.add(link.strip())
                        # Optionally: Download media attachments or add logic for non-mega leaks
                except Exception as channel_exc:
                    print(f"[TG] Failed to search {channel}: {channel_exc}")
    except Exception as e:
        print(f"[TG] Critical error: {e}")
    return sorted(results)
