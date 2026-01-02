import asyncio
import httpx
import re
import pyperclip
from rich.progress import Progress, BarColumn, TextColumn, TimeElapsedColumn

# Configuration
CONCURRENCY = 40
TIMEOUT = 8.0

def parse_input() -> list[str]:
    print("Paste URLs (newline separated), end with blank line:")
    urls = []
    while True:
        try:
            line = input().strip()
        except EOFError:
            break
        if not line:
            break
        urls.append(line)
    return urls

def format_output(urls: list[str]) -> str:
    return ",\n".join(f'"{u}"' for u in urls) + ","

async def check_url(client: httpx.AsyncClient, url: str) -> bool:
    try:
        r = await client.head(url, timeout=TIMEOUT, follow_redirects=True)
        if 200 <= r.status_code < 400:
            return True
        r = await client.get(url, timeout=TIMEOUT, follow_redirects=True)
        return 200 <= r.status_code < 400
    except Exception:
        return False

async def validate_all(urls: list[str]) -> list[str]:
    valid = []
    sem = asyncio.Semaphore(CONCURRENCY)
    async with httpx.AsyncClient() as client:
        with Progress(
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TextColumn("{task.completed}/{task.total}"),
            TimeElapsedColumn(),
        ) as progress:
            task = progress.add_task("Validating URLs", total=len(urls))

            async def worker(u):
                async with sem:
                    ok = await check_url(client, u)
                    if ok:
                        valid.append(u)
                    progress.update(task, advance=1)

            await asyncio.gather(*(worker(u) for u in urls))
    return valid

def main():
    urls = parse_input()
    if not urls:
        print("Empty list, nothing to do."); return

    valid = asyncio.run(validate_all(urls))

    print(f"\nFound {len(valid)} working URLs.\n")
    formatted = format_output(valid)
    print(formatted)

    pyperclip.copy(formatted)
    print("\n[Copied valid URLs to clipboard]")

if __name__ == "__main__":
    main()
