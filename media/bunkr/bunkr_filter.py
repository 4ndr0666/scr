#!/usr/bin/env python3
"""bunkr_filter.py — Bunkr filter query builder.

Reads your session token from ~/.bunkr/token (chmod 600).
Builds a syntactically correct query from the documented filter grammar
and pipes the result to wl-copy for pasting into the Bunkr safe dashboard.

Filter grammar reference (bunkr.cr safe dashboard search box):
    albumid:<id>          — filter by album ID (repeatable)
    albumid:-             — uploads with no album
    -albumid:<id>         — exclude album
    date:<range>          — filter by upload date (once only)
    expiry:<range>        — filter by expiry date (once only)
    is:image|video|audio  — filter by type
    -is:<type>            — exclude type
    sort:<col>[:d]        — sort by column (repeatable)
    <keyword>             — match filename (repeatable)
    -<keyword>            — exclude filename match

Date range format: YYYY/MM/DD HH:MM:SS-YYYY/MM/DD HH:MM:SS
    Either bound may be omitted.
    Quotes required only when the range string contains spaces.
    Examples:
        2019/06
        -2020/02/05
        "2020/04/07 12-2020/04/07 23:59:59"
        12:34:56
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt
from rich import box
from rich.table import Table

# ── Constants ────────────────────────────────────────────────────────────────

TOKEN_PATH = Path.home() / ".bunkr" / "token"

VALID_TYPES = {"image", "video", "audio"}

# Accepts all documented date/time shorthand forms.
# Either side of the '-' separator is optional.
_DATE_PART = (
    r"\d{4}"
    r"(?:/\d{2}"
    r"(?:/\d{2}"
    r"(?:\s+\d{2}"
    r"(?::\d{2}"
    r"(?::\d{2}"
    r")?)?)?)?)?"
)
_TIME_ONLY = r"\d{2}:\d{2}:\d{2}"
_BOUND = rf"(?:{_DATE_PART}|{_TIME_ONLY})"
DATE_RANGE_RE = re.compile(rf"^-?{_BOUND}?(?:-{_BOUND}?)?$")

console = Console()


# ── Token ────────────────────────────────────────────────────────────────────


def load_token() -> str:
    """Load the Bunkr session token from ~/.bunkr/token."""
    if not TOKEN_PATH.exists():
        console.print(
            f"[bold red]Token not found:[/bold red] {TOKEN_PATH}\n"
            "Create it with:\n"
            f"  mkdir -p {TOKEN_PATH.parent} && chmod 700 {TOKEN_PATH.parent}\n"
            f"  echo 'YOUR_TOKEN' > {TOKEN_PATH} && chmod 600 {TOKEN_PATH}",
        )
        sys.exit(1)

    token = TOKEN_PATH.read_text(encoding="utf-8").strip()
    if not token:
        console.print(
            f"[bold red]Token file is empty:[/bold red] {TOKEN_PATH}",
        )
        sys.exit(1)

    return token


# ── Query builder ─────────────────────────────────────────────────────────────


class QueryBuilder:
    """Assemble a Bunkr filter query string from validated components."""

    def __init__(self) -> None:
        self.parts: list[str] = []

    def add_album(self, value: str, *, exclude: bool = False) -> None:
        """Add an albumid filter. value may be a numeric ID or '-' (no album)."""
        prefix = "-" if exclude else ""
        self.parts.append(f"{prefix}albumid:{value}")

    def add_date(self, range_str: str) -> None:
        """Add a date range filter."""
        self.parts.append(_format_range("date", range_str))

    def add_expiry(self, range_str: str) -> None:
        """Add an expiry range filter."""
        self.parts.append(_format_range("expiry", range_str))

    def add_type(self, media_type: str, *, exclude: bool = False) -> None:
        """Add a type-is filter. media_type must be image, video, or audio."""
        if media_type not in VALID_TYPES:
            raise ValueError(
                f"Invalid type '{media_type}'. Must be one of {VALID_TYPES}",
            )
        prefix = "-" if exclude else ""
        self.parts.append(f"{prefix}is:{media_type}")

    def add_sort(self, column: str, *, descending: bool = False) -> None:
        """Add a sort key. Column may be any DB column name or date/expiry shortcut."""
        suffix = ":d" if descending else ""
        self.parts.append(f"sort:{column}{suffix}")

    def add_keyword(self, keyword: str, *, exclude: bool = False) -> None:
        """Add a filename keyword or glob."""
        prefix = "-" if exclude else ""
        self.parts.append(f"{prefix}{keyword}")

    def build(self) -> str:
        """Return the assembled query string."""
        return " ".join(self.parts)

    def reset(self) -> None:
        """Clear all accumulated parts."""
        self.parts.clear()


def _format_range(key: str, range_str: str) -> str:
    """Wrap range in quotes if it contains spaces, per the documented format."""
    if " " in range_str:
        return f'{key}:"{range_str}"'
    return f"{key}:{range_str}"


# ── Validation ────────────────────────────────────────────────────────────────


def validate_date_range(value: str) -> bool:
    """Return True if value matches the documented date/time range grammar."""
    cleaned = value.strip('"').strip("'").strip()
    return bool(DATE_RANGE_RE.match(cleaned))


def validate_album_id(value: str) -> bool:
    """Return True if value is a numeric ID or the special '-' sentinel."""
    return value == "-" or value.lstrip("-").isdigit()


# ── Interactive prompts ───────────────────────────────────────────────────────


def prompt_albums(builder: QueryBuilder) -> None:
    """Guided album filter entry."""
    console.print("\n[bold cyan]Album filters[/bold cyan]")
    console.print(
        "  Enter album IDs one at a time.\n"
        "  [dim]'-' = uploads with no album | prefix with '-' to exclude (e.g. -69) "
        "| empty line to finish[/dim]",
    )

    while True:
        raw = Prompt.ask("  albumid", default="").strip()
        if not raw:
            break

        # Distinguish the no-album sentinel from a negated ID
        if raw == "-":
            builder.add_album("-", exclude=False)
            console.print("  [green]Added:[/green] albumid:-")
            continue

        exclude = raw.startswith("-")
        value = raw.lstrip("-")

        if not value.isdigit():
            console.print(
                f"  [red]Invalid album ID '{raw}'. Must be a number, '-' or '-<number>'.[/red]",
            )
            continue

        builder.add_album(value, exclude=exclude)
        label = f"-albumid:{value}" if exclude else f"albumid:{value}"
        console.print(f"  [green]Added:[/green] {label}")


def prompt_date_range(builder: QueryBuilder) -> None:
    """Guided date range entry."""
    console.print("\n[bold cyan]Date range[/bold cyan]")
    console.print(
        "  Format: YYYY/MM/DD HH:MM:SS-YYYY/MM/DD HH:MM:SS\n"
        "  [dim]Either bound optional. Examples:[/dim]\n"
        "    [dim]2019/06                            (since June 2019)[/dim]\n"
        "    [dim]-2020/02/05                        (before 5 Feb 2020)[/dim]\n"
        '    [dim]"2020/04/07 12-2020/04/07 23:59:59"[/dim]\n'
        "    [dim]12:34:56                           (today at this time)[/dim]",
    )

    raw = Prompt.ask("  date range", default="").strip()
    if not raw:
        return

    cleaned = raw.strip('"').strip("'")
    if not validate_date_range(cleaned):
        console.print(
            f"  [red]Unrecognised date format '{raw}' — skipping.[/red]",
        )
        return

    builder.add_date(cleaned)
    console.print(f"  [green]Added:[/green] {_format_range('date', cleaned)}")


def prompt_expiry_range(builder: QueryBuilder) -> None:
    """Guided expiry range entry."""
    console.print("\n[bold cyan]Expiry range[/bold cyan]")
    console.print(
        "  Same format as date range.\n" "  [dim]Empty to skip.[/dim]",
    )

    raw = Prompt.ask("  expiry range", default="").strip()
    if not raw:
        return

    cleaned = raw.strip('"').strip("'")
    if not validate_date_range(cleaned):
        console.print(
            f"  [red]Unrecognised expiry format '{raw}' — skipping.[/red]",
        )
        return

    builder.add_expiry(cleaned)
    console.print(f"  [green]Added:[/green] {_format_range('expiry', cleaned)}")


def prompt_types(builder: QueryBuilder) -> None:
    """Guided type-is filter entry."""
    console.print("\n[bold cyan]Type filters[/bold cyan]")
    console.print(
        "  Options: [bold]image[/bold], [bold]video[/bold], [bold]audio[/bold]\n"
        "  [dim]Prefix with '-' to exclude. "
        "Cannot mix inclusion and exclusion. Empty line to finish.[/dim]",
    )

    has_include = False
    has_exclude = False

    while True:
        raw = Prompt.ask("  is", default="").strip()
        if not raw:
            break

        exclude = raw.startswith("-")
        media_type = raw.lstrip("-")

        if media_type not in VALID_TYPES:
            console.print(
                f"  [red]Invalid type '{media_type}'. "
                "Choose from: image, video, audio.[/red]",
            )
            continue

        if exclude and has_include:
            console.print(
                "  [red]Cannot mix inclusion and exclusion type filters.[/red]",
            )
            continue

        if not exclude and has_exclude:
            console.print(
                "  [red]Cannot mix inclusion and exclusion type filters.[/red]",
            )
            continue

        if exclude:
            has_exclude = True
        else:
            has_include = True

        builder.add_type(media_type, exclude=exclude)
        label = f"-is:{media_type}" if exclude else f"is:{media_type}"
        console.print(f"  [green]Added:[/green] {label}")


def prompt_keywords(builder: QueryBuilder) -> None:
    """Guided keyword/glob entry."""
    console.print("\n[bold cyan]Filename keywords / globs[/bold cyan]")
    console.print(
        "  Matched against filenames. Globs supported (e.g. *.mp4).\n"
        "  [dim]Prefix with '-' to exclude. Empty line to finish.[/dim]",
    )

    while True:
        raw = Prompt.ask("  keyword", default="").strip()
        if not raw:
            break

        exclude = raw.startswith("-") and len(raw) > 1
        keyword = raw[1:] if exclude else raw

        builder.add_keyword(keyword, exclude=exclude)
        label = f"-{keyword}" if exclude else keyword
        console.print(f"  [green]Added:[/green] {label}")


def prompt_sort(builder: QueryBuilder) -> None:
    """Guided sort key entry."""
    console.print("\n[bold cyan]Sort keys[/bold cyan]")
    console.print(
        "  Any DB column name, or shortcuts: [bold]date[/bold], [bold]expiry[/bold]\n"
        "  [dim]Append ':d' for descending (e.g. size:d). "
        "Multiple keys allowed — order sets priority. Empty line to finish.[/dim]",
    )

    while True:
        raw = Prompt.ask("  sort", default="").strip()
        if not raw:
            break

        descending = raw.endswith(":d") or raw.endswith(":descending")
        column = re.sub(r":d(escending)?$", "", raw).strip()

        if not column:
            console.print("  [red]Sort column cannot be empty.[/red]")
            continue

        builder.add_sort(column, descending=descending)
        label = f"sort:{column}:d" if descending else f"sort:{column}"
        console.print(f"  [green]Added:[/green] {label}")


# ── Summary table ─────────────────────────────────────────────────────────────


def display_query_breakdown(parts: list[str]) -> None:
    """Render a table showing each query component and its role."""
    if not parts:
        return

    table = Table(
        box=box.SIMPLE,
        show_header=True,
        header_style="bold cyan",
        border_style="bright_blue",
        title="[bold]Query Breakdown[/bold]",
    )
    table.add_column("Token", style="green", no_wrap=True)
    table.add_column("Type", style="dim")

    for part in parts:
        if part.startswith("-albumid:"):
            label = "albumid (exclude)"
        elif part.startswith("albumid:"):
            label = "albumid (include)"
        elif part.startswith("date:"):
            label = "date range"
        elif part.startswith("expiry:"):
            label = "expiry range"
        elif part.startswith("-is:"):
            label = "type (exclude)"
        elif part.startswith("is:"):
            label = "type (include)"
        elif part.startswith("sort:"):
            label = "sort key"
        elif part.startswith("-"):
            label = "keyword (exclude)"
        else:
            label = "keyword / glob"

        table.add_row(part, label)

    console.print()
    console.print(table)


# ── Clipboard ─────────────────────────────────────────────────────────────────


def copy_to_clipboard(text: str) -> None:
    """Pipe text to wl-copy."""
    try:
        subprocess.run(
            ["wl-copy"],
            input=text.encode("utf-8"),
            check=True,
        )
        console.print("[green]✓ Copied to clipboard via wl-copy[/green]")
    except FileNotFoundError:
        console.print(
            "[yellow]wl-copy not found — query not copied to clipboard.[/yellow]\n"
            f"  Query: [bold]{text}[/bold]",
        )
    except subprocess.CalledProcessError as err:
        console.print(f"[red]wl-copy failed:[/red] {err}")


# ── Main flow ─────────────────────────────────────────────────────────────────


def build_query_interactive(builder: QueryBuilder) -> str:
    """Run the full interactive query builder and return the assembled query."""
    console.clear()
    console.print(
        Panel(
            "[bold magenta]BUNKR FILTER QUERY BUILDER[/bold magenta]\n"
            "[dim]Build a filter query for the Bunkr safe dashboard search box.\n"
            "Each section is optional — press Enter to skip.[/dim]",
            border_style="magenta",
        )
    )

    builder.reset()

    prompt_albums(builder)
    prompt_date_range(builder)
    prompt_expiry_range(builder)
    prompt_types(builder)
    prompt_keywords(builder)
    prompt_sort(builder)

    query = builder.build()

    display_query_breakdown(builder.parts)

    console.print()
    console.print(
        Panel(
            f"[bold green]{query if query else '(empty query — nothing to copy)'}[/bold green]",
            title="Assembled Query",
            border_style="green",
        )
    )

    return query


def print_help() -> None:
    """Print a reference card for the filter grammar."""
    console.print(
        Panel(
            "[bold]Filter grammar reference[/bold]\n\n"
            "  [cyan]albumid:<id>[/cyan]          include album (repeatable)\n"
            "  [cyan]albumid:-[/cyan]             uploads with no album\n"
            "  [cyan]-albumid:<id>[/cyan]         exclude album (repeatable)\n"
            "  [cyan]date:<range>[/cyan]          filter by upload date (once)\n"
            "  [cyan]expiry:<range>[/cyan]        filter by expiry date (once)\n"
            "  [cyan]is:image|video|audio[/cyan]  include by type\n"
            "  [cyan]-is:<type>[/cyan]            exclude by type\n"
            "  [cyan]sort:<col>[:d][/cyan]        sort column, :d = descending (repeatable)\n"
            "  [cyan]<keyword>[/cyan]             filename match / glob (repeatable)\n"
            "  [cyan]-<keyword>[/cyan]            filename exclusion (repeatable)\n\n"
            "[bold]Date format:[/bold] YYYY/MM/DD HH:MM:SS-YYYY/MM/DD HH:MM:SS\n"
            "  Either bound optional. Quote if the string contains spaces.\n\n"
            "[bold]Examples:[/bold]\n"
            "  albumid:-\n"
            "  -albumid:69\n"
            "  date:2019/06\n"
            "  date:-2020/02/05\n"
            '  date:"2020/04/07 12-2020/04/07 23:59:59"\n'
            "  *.gz -*.tar.gz\n"
            "  *.mp4 sort:size:d",
            title="Help",
            border_style="dim",
        )
    )


def main() -> None:
    """Entry point."""
    load_token()  # Validate token exists and is non-empty before doing anything
    builder = QueryBuilder()

    console.print(
        Panel(
            "[bold magenta]BUNKR FILTER QUERY BUILDER[/bold magenta]\n"
            "[dim]Paste the output into the Bunkr safe dashboard search box.[/dim]",
            border_style="magenta",
        )
    )

    while True:
        console.print()
        console.print(
            "  [dim]b[/dim] = build query   "
            "[dim]h[/dim] = help / grammar reference   "
            "[dim]q[/dim] = quit",
        )
        choice = Prompt.ask(
            "[bold]Command[/bold]",
            choices=["b", "h", "q"],
            default="b",
            show_choices=False,
            show_default=False,
        )

        if choice == "q":
            console.print("[dim]Exiting.[/dim]")
            break

        if choice == "h":
            print_help()
            continue

        # choice == "b"
        query = build_query_interactive(builder)

        if not query:
            console.print("[yellow]Empty query — nothing to copy.[/yellow]")
            continue

        copy_to_clipboard(query)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n[dim]Interrupted.[/dim]")
        sys.exit(0)
