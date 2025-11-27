try:
    from telethon import TelegramClient
    import re
except ImportError as e:
    # We defer raising until run time so Dorkmaster doesn't crash on load
    pass

from rich.prompt import Prompt

def run(config, console):
    """Entry point for Dorkmaster Plugin System."""
    console.print("[bold blue]Telegram Leak Hunter[/bold blue]")

    api_id = config.get("telegram_api_id")
    api_hash = config.get("telegram_api_hash")

    if not api_id or not api_hash:
        console.print("[red]Error: 'telegram_api_id' and 'telegram_api_hash' must be set in config.json[/red]")
        return

    try:
        from telethon import TelegramClient
    except ImportError:
        console.print("[red]Error: 'telethon' library missing. Install via pip install telethon[/red]")
        return

    term = Prompt.ask("Enter Search Term (e.g. 'onlyfans mega')")
    if not term:
        return

    console.print("[dim]Initializing Telegram Client... (First run requires login)[/dim]")
    
    # We use a session file stored in the configured session dir
    session_path = f"{config.get('session_dir', '.')}/dorkmaster_tg_session"
    
    try:
        links = search_and_extract(term, api_id, api_hash, session_name=session_path)
        if links:
            console.print(f"[green]Found {len(links)} Mega.nz links:[/green]")
            for l in links:
                console.print(f"  - {l}")
        else:
            console.print("[yellow]No links found.[/yellow]")
    except Exception as e:
        console.print(f"[red]Execution failed: {e}[/red]")


def search_and_extract(search_term, api_id, api_hash, session_name='4ndr0666OS', channels=None, max_results=100):
    """
    Search public Telegram channels for Mega.nz links matching the search term.
    Dedupes, error-resilient, ready for batch export.
    """
    if channels is None:
        channels = ['megaleaks', 'megahunt']  # Extend as needed
    results = set()
    
    # Create client but don't connect in 'with' block yet to handle async loop issues if nested
    # For a simple script sync-style wrapper:
    client = TelegramClient(session_name, api_id, api_hash)
    
    async def main_search():
        await client.start()
        for channel in channels:
            try:
                # console.print(f"Scanning {channel}...") # Can't use rich console inside async easily without passing it
                async for message in client.iter_messages(channel, search=search_term, limit=max_results):
                    found_links = re.findall(r'https?://mega\.nz/[^\s]+', message.text or '')
                    for link in found_links:
                        results.add(link.strip())
            except Exception as channel_exc:
                print(f"[TG] Failed to search {channel}: {channel_exc}")
    
    with client:
        client.loop.run_until_complete(main_search())

    return sorted(results)
