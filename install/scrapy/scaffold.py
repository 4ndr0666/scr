#!/usr/bin/env python3
"""Automated Scrapy Project & Ψ-4ndr0666 Omni-Enumerator Spider Generator.

Unifies `scaffold.py` with the operational architecture of `scraper.py`
(`AkashaEnumerator` + `AkashaIntegrator`) so that executing `scaffold.py` prompts
for a single target URL and user-selected operational parameters, generating a
complete Scrapy spider and pipeline suite with:
  - Stateful pre-flight session cookie acquisition (`_pre_flight` / `start_requests`)
  - Streamed Range (`bytes=0-8192`) + `Sec-Fetch-*` + `Sec-Ch-Ua*` + dynamic `Referer`
    WAF evasion headers
  - Zero-padded sequence brute-force matrix (`min_val..max_val`, `pad`) with automatic
    HTTP 404/403 unpadded fallback heuristic (`001` -> `1`) and concrete single-URL
    sequence token replacement
  - Recursive DOM + raw regex asset extraction (`<img>`, `<a href>`, `<meta og:image>`,
    and inline regex URL discovery)
  - Post-Exploitation `AkashaIntegrator` (`store_idempotent`, `delegate_gallerydl`,
    `open_browser`) integrated into both the Scrapy pipeline lifecycle and spider close
"""

import argparse
import os
import re
import subprocess
import sys
import textwrap
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

# --- Pre-compiled Module-Level Regular Expressions & Translation Tables (PF-006 / PF-010) ---
_NON_IDENT_RE = re.compile(r"[^a-zA-Z0-9_]+")
_MULTI_UNDERSCORE_RE = re.compile(r"_+")
_SPLIT_WORDS_RE = re.compile(r"[^a-zA-Z0-9]+")
_SAFE_FILENAME_RE = re.compile(r"[^A-Za-z0-9._-]+")
_IMAGE_EXT_RE = re.compile(r"\.(?:jpg|jpeg|png|gif|webp|bmp|svg|avif|tiff|ico)$", re.IGNORECASE)
_MEDIA_EXT_RE = re.compile(
    r"\.(?:jpg|jpeg|png|gif|webp|bmp|svg|avif|tiff|ico|pdf|mp4|webm|mp3|zip|tar|gz)$",
    re.IGNORECASE,
)
_PREF_SEQ_RE = re.compile(
    r"^(?P<prefix>.*?(?:img|image|pic|photo|page|p|sof|item|file|num|seq|[a-zA-Z])[_-]?)"
    r"(?P<num>\d{1,8})"
    r"(?P<suffix>(?:[-_][0-9a-fA-F]{6,}.*|\D.*)?)$",
    re.IGNORECASE,
)
_FALLBACK_SEQ_RE = re.compile(r"^(?P<prefix>.*?)(?P<num>\d+)(?P<suffix>\D*)$")
_QUERY_SEQ_KEYS = frozenset(("page", "p", "pg", "offset", "index", "num", "id"))

_CLEAN_NAME_TABLE = str.maketrans({
    " ": "_",
    "/": "-",
    "\\": "-",
    ":": "-",
    "\0": "",
})
_DISPLAY_NAME_TABLE = str.maketrans({
    "_": " ",
    "-": " ",
})

VALID_EXTRACTION_MODES = ("images", "text", "links", "full", "scrape", "brute")
VALID_PAGINATION_MODES = ("auto", "sequence", "brute", "link", "none")
VALID_EXPORT_FORMATS = ("json", "jsonl", "csv", "xml")


class SpiderConfig:
    """Compact __slots__ configuration unifying single-URL Scrapy generation with AkashaEnumerator."""
    __slots__ = (
        "project_name",
        "spider_name",
        "start_url",
        "url_template",
        "allowed_domain",
        "extraction_mode",
        "target_selector",
        "download_images",
        "pagination_mode",
        "next_page_selector",
        "max_pages",
        "min_val",
        "max_val",
        "pad",
        "download_delay",
        "concurrent_requests",
        "respect_robots",
        "export_format",
        "is_direct_media",
        "detected_sequence_num",
        "custom_headers",
        "user_agent",
        "store_file",
        "delegate_gallerydl",
        "open_browser",
        "extra_domains",
    )

    def __init__(
        self,
        project_name="akasha_enum",
        spider_name="akasha",
        start_url="https://www.example.com",
        url_template="https://www.example.com",
        allowed_domain="www.example.com",
        extraction_mode="images",
        target_selector="",
        download_images=True,
        pagination_mode="auto",
        next_page_selector='a[rel="next"]::attr(href), a.next::attr(href), li.next a::attr(href)',
        max_pages=10,
        min_val=1,
        max_val=10,
        pad=0,
        download_delay=1.0,
        concurrent_requests=2,
        respect_robots=False,
        export_format="json",
        is_direct_media=False,
        detected_sequence_num=None,
        custom_headers=None,
        user_agent="",
        store_file="found_urls.txt",
        delegate_gallerydl=False,
        open_browser=False,
        extra_domains=None,
    ):
        self.project_name = project_name
        self.spider_name = spider_name
        self.start_url = start_url
        self.url_template = url_template
        self.allowed_domain = allowed_domain
        self.extraction_mode = extraction_mode
        self.target_selector = target_selector
        self.download_images = download_images
        self.pagination_mode = pagination_mode
        self.next_page_selector = next_page_selector
        self.max_pages = max_pages
        self.min_val = min_val
        self.max_val = max_val
        self.pad = pad
        self.download_delay = download_delay
        self.concurrent_requests = concurrent_requests
        self.respect_robots = respect_robots
        self.export_format = export_format
        self.is_direct_media = is_direct_media
        self.detected_sequence_num = detected_sequence_num
        self.custom_headers = list(custom_headers) if custom_headers else []
        self.user_agent = user_agent
        self.store_file = store_file
        self.delegate_gallerydl = delegate_gallerydl
        self.open_browser = open_browser
        self.extra_domains = list(extra_domains) if extra_domains else []


_ACTIVE_CONFIG = None


def get_active_config():
    """Return the active SpiderConfig populated by the latest parse_arguments() call."""
    return _ACTIVE_CONFIG


def set_active_config(config):
    """Set the module-level active SpiderConfig."""
    global _ACTIVE_CONFIG
    _ACTIVE_CONFIG = config


def sanitize_identifier(raw, default="akasha_enum"):
    """Convert an arbitrary string into a valid lowercase PEP 8 Python identifier."""
    if not raw or not raw.strip():
        return default
    cleaned = _NON_IDENT_RE.sub("_", raw.strip().lower())
    cleaned = _MULTI_UNDERSCORE_RE.sub("_", cleaned).strip("_")
    if not cleaned:
        return default
    if cleaned[0].isdigit():
        cleaned = f"s_{cleaned}"
    if cleaned in {"scrapy", "spider", "items", "pipelines", "settings", "middlewares", "test", "tests", "os", "sys"}:
        cleaned = f"{cleaned}_project"
    return cleaned


def to_class_prefix(name):
    """Convert a project or spider identifier into a valid PascalCase class name prefix."""
    parts = [p for p in _SPLIT_WORDS_RE.split(name.strip()) if p]
    if not parts:
        return "Default"
    if len(parts) == 1:
        prefix = parts[0].capitalize()
    else:
        prefix = "".join(p.capitalize() for p in parts)
    if prefix[0].isdigit():
        prefix = f"S{prefix}"
    return prefix


def extract_sequence_token(url):
    """Locate the primary numeric sequence token in a URL query or path basename."""
    if not url:
        return None
    q_pos = url.find("?")
    if q_pos != -1:
        parts = urlsplit(url)
        if parts.query:
            q_pairs = parse_qsl(parts.query, keep_blank_values=True)
            for idx, (k, v) in enumerate(q_pairs):
                if k.lower() in _QUERY_SEQ_KEYS and v.isdigit():
                    return ("query", k, v, str(idx))
        path = parts.path or ""
    else:
        f_pos = url.find("#")
        path = url[:f_pos] if f_pos != -1 else url

    basename = path.rsplit("/", 1)[-1]
    if not basename:
        return None

    stem, dot, ext = basename.rpartition(".")
    if not dot:
        stem, ext = basename, ""
    else:
        ext = f".{ext}"

    match = _PREF_SEQ_RE.match(stem) or _FALLBACK_SEQ_RE.match(stem)
    if not match:
        return None
    return (
        "path",
        match.group("prefix"),
        match.group("num"),
        f"{match.group('suffix')}{ext}",
    )


def extract_url_sequence_number(url):
    """Return the integer value of the primary sequence token in `url`, or 0 if absent."""
    token = extract_sequence_token(url)
    if token is None:
        return 0
    return int(token[2])


def build_url_template(url):
    """Convert a concrete URL or `{}` URL into `(url_template, detected_num, detected_pad)`."""
    if "{}" in url:
        return (url, 1, 0)
    token = extract_sequence_token(url)
    if token is None:
        return (f"{url}{{}}", None, 0)
    kind, prefix, num_str, suffix = token
    num_val = int(num_str)
    pad_w = len(num_str) if (len(num_str) > 1 and num_str[0] == "0") else 0
    if kind == "query":
        parts = urlsplit(url)
        idx = int(suffix)
        q_pairs = parse_qsl(parts.query, keep_blank_values=True)
        q_pairs[idx] = (prefix, "__BRUTE_SLOT__")
        new_query = urlencode(q_pairs).replace("__BRUTE_SLOT__", "{}")
        return (
            urlunsplit((parts.scheme, parts.netloc, parts.path, new_query, parts.fragment)),
            num_val,
            pad_w,
        )

    q_pos = url.find("?")
    f_pos = url.find("#")
    split_at = q_pos if (q_pos != -1 and (f_pos == -1 or q_pos < f_pos)) else f_pos
    if split_at != -1:
        base_part = url[:split_at]
        tail_part = url[split_at:]
    else:
        base_part = url
        tail_part = ""
    dir_prefix, sep, _ = base_part.rpartition("/")
    new_basename = f"{prefix}{{}}{suffix}"
    new_base = f"{dir_prefix}{sep}{new_basename}" if sep else new_basename
    return (f"{new_base}{tail_part}", num_val, pad_w)


def increment_sequence_url(url, step=1, _precomputed_token=None):
    """Return a new URL with its primary numeric sequence token incremented by `step`."""
    token = _precomputed_token if _precomputed_token is not None else extract_sequence_token(url)
    if token is None:
        return None
    kind, prefix, num_str, suffix = token
    width = len(num_str)
    next_val = int(num_str) + step
    if next_val < 0:
        return None
    formatted = f"{next_val:0{width}d}" if (width > 1 and num_str[0] == "0") else str(next_val)

    if kind == "query":
        parts = urlsplit(url)
        idx = int(suffix)
        q_pairs = parse_qsl(parts.query, keep_blank_values=True)
        q_pairs[idx] = (prefix, formatted)
        new_query = urlencode(q_pairs)
        return urlunsplit((parts.scheme, parts.netloc, parts.path, new_query, parts.fragment))

    q_pos = url.find("?")
    f_pos = url.find("#")
    split_at = q_pos if (q_pos != -1 and (f_pos == -1 or q_pos < f_pos)) else f_pos
    if split_at != -1:
        base_part = url[:split_at]
        tail_part = url[split_at:]
    else:
        base_part = url
        tail_part = ""

    dir_prefix, sep, _ = base_part.rpartition("/")
    new_basename = f"{prefix}{formatted}{suffix}"
    new_base = f"{dir_prefix}{sep}{new_basename}" if sep else new_basename
    return f"{new_base}{tail_part}"


def clean_image_stem(url):
    """Extract a human-readable, normalized display name from a URL path basename."""
    q_pos = url.find("?")
    f_pos = url.find("#")
    cut = q_pos if (q_pos != -1 and (f_pos == -1 or q_pos < f_pos)) else f_pos
    path = url[:cut] if cut != -1 else url
    basename = path.rstrip("/").rsplit("/", 1)[-1]
    dot = basename.find(".")
    stem = basename[:dot] if dot > 0 else (basename or "default")
    normalized = " ".join(stem.strip().translate(_DISPLAY_NAME_TABLE).split())
    return normalized.capitalize() if normalized else "Default"


def sanitize_storage_name(name):
    """Sanitize an item/image name for safe filesystem path usage (prevents traversal)."""
    if not name:
        return "default_name"
    cleaned = name.strip().translate(_CLEAN_NAME_TABLE)
    if ".." in cleaned:
        cleaned = cleaned.replace("..", "_")
    cleaned = _SAFE_FILENAME_RE.sub("_", cleaned)
    if "__" in cleaned:
        cleaned = _MULTI_UNDERSCORE_RE.sub("_", cleaned)
    cleaned = cleaned.strip("._-")
    return cleaned or "default_name"


def inspect_target_url(raw_url):
    """Normalize a single target URL and infer domain, media type, sequence template, and defaults."""
    candidate = (raw_url or "").strip().strip('"').strip("'")
    if not candidate:
        candidate = "https://www.example.com"
    if "://" not in candidate:
        candidate = f"https://{candidate.lstrip('/')}"

    has_brace_slot = "{}" in candidate
    probe_url = candidate.replace("{}", "1") if has_brace_slot else candidate

    parts = urlsplit(probe_url)
    hostname = parts.hostname or parts.netloc.split("@")[-1].split(":")[0] or "www.example.com"
    normalized_probe = urlunsplit((
        parts.scheme or "https",
        parts.netloc or hostname,
        parts.path or "",
        parts.query,
        "",
    ))

    if has_brace_slot:
        # Preserve {} in template while setting start_url to first concrete item
        raw_parts = urlsplit(candidate)
        url_template = urlunsplit((
            raw_parts.scheme or "https",
            raw_parts.netloc or hostname,
            raw_parts.path or "",
            raw_parts.query,
            "",
        ))
        seq_num = 1
        pad_width = 0
        normalized_url = url_template.replace("{}", "1")
    else:
        normalized_url = normalized_probe
        url_template, seq_num, pad_width = build_url_template(normalized_url)

    path_lower = (parts.path or "").lower()
    is_image = bool(_IMAGE_EXT_RE.search(path_lower))
    is_media = bool(_MEDIA_EXT_RE.search(path_lower))

    host_core = hostname.lower()
    for prefix in ("www.", "images-pw.", "images.", "cdn.", "static.", "api.", "m."):
        if host_core.startswith(prefix) and len(host_core) > len(prefix):
            host_core = host_core[len(prefix):]
            break
    domain_root = host_core.split(".")[0] if "." in host_core else host_core
    if domain_root in ("example", "localhost", "127"):
        default_project = "akasha_enum"
        default_spider = "images" if is_image else "akasha"
    else:
        default_project = sanitize_identifier(f"{domain_root}_scraper", default="akasha_enum")
        path_segments = [
            seg for seg in (parts.path or "").split("/")
            if seg and not _MEDIA_EXT_RE.search(seg) and not seg.isdigit()
        ]
        if is_image or has_brace_slot:
            default_spider = "images"
        elif path_segments:
            default_spider = sanitize_identifier(path_segments[-1], default=domain_root)
        else:
            default_spider = sanitize_identifier(domain_root, default="akasha")

    default_mode = "images" if (is_image or has_brace_slot) else "full"
    default_pagination = "sequence" if (has_brace_slot or (is_image and seq_num is not None)) else "auto"

    return {
        "normalized_url": normalized_url,
        "url_template": url_template,
        "allowed_domain": hostname,
        "is_image": is_image,
        "is_media": is_media,
        "has_brace_slot": has_brace_slot,
        "sequence_number": seq_num,
        "pad_width": pad_width,
        "default_project": default_project,
        "default_spider": default_spider,
        "default_mode": default_mode,
        "default_pagination": default_pagination,
    }


def validate_and_create_dir(path):
    """Ensure directory `path` exists and return `path`."""
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)
    return path


def _find_executable(name):
    """Locate executable `name` on PATH without importing shutil at startup."""
    for directory in os.environ.get("PATH", "").split(os.pathsep):
        if not directory:
            continue
        candidate = os.path.join(directory, name)
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


def bootstrap_project_skeleton(project_name):
    """Initialize a complete Scrapy project layout with bounded subprocess timeout and fallback."""
    pkg_dir = validate_and_create_dir(os.path.join(project_name, project_name))
    spiders_dir = validate_and_create_dir(os.path.join(pkg_dir, "spiders"))

    scrapy_bin = _find_executable("scrapy")
    cfg_path = os.path.join(project_name, "scrapy.cfg")
    if scrapy_bin and not os.path.exists(cfg_path):
        try:
            subprocess.run(
                [scrapy_bin, "startproject", project_name, project_name],
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=30,
            )
        except (OSError, subprocess.SubprocessError):
            pass

    if not os.path.exists(cfg_path):
        cfg_content = (
            "[settings]\n"
            f"default = {project_name}.settings\n\n"
            "[deploy]\n"
            f"#url = http://localhost:6800/\n"
            f"project = {project_name}\n"
        )
        with open(cfg_path, "w", encoding="utf-8") as f:
            f.write(cfg_content)

    for init_dir in (pkg_dir, spiders_dir):
        init_file = os.path.join(init_dir, "__init__.py")
        if not os.path.exists(init_file):
            with open(init_file, "w", encoding="utf-8") as f:
                f.write('"""Scrapy package initialization."""\n')

    settings_file_path = os.path.join(pkg_dir, "settings.py")
    if not os.path.exists(settings_file_path):
        base_settings = (
            f'BOT_NAME = "{project_name}"\n\n'
            f'SPIDER_MODULES = ["{project_name}.spiders"]\n'
            f'NEWSPIDER_MODULE = "{project_name}.spiders"\n\n'
            "ROBOTSTXT_OBEY = False\n"
            'REQUEST_FINGERPRINTER_IMPLEMENTATION = "2.7"\n'
            'TWISTED_REACTOR = "twisted.internet.asyncioreactor.AsyncioSelectorReactor"\n'
            'FEED_EXPORT_ENCODING = "utf-8"\n'
        )
        with open(settings_file_path, "w", encoding="utf-8") as f:
            f.write(base_settings)


def _resolve_config(project_name, spider_name=None, start_url=None, config=None):
    """Merge explicit arguments with the active or default `SpiderConfig`."""
    base = config or _ACTIVE_CONFIG
    url_to_use = start_url or (base.start_url if base else "https://www.example.com")
    info = inspect_target_url(url_to_use)
    proj = sanitize_identifier(project_name or (base.project_name if base else "akasha_enum"), default="akasha_enum")
    spid = sanitize_identifier(spider_name or (base.spider_name if base else "akasha"), default="akasha")
    seq_start = info["sequence_number"] if info["sequence_number"] is not None else 1

    if base is not None:
        return SpiderConfig(
            project_name=proj,
            spider_name=spid,
            start_url=str(info["normalized_url"]),
            url_template=str(info["url_template"]),
            allowed_domain=str(info["allowed_domain"]),
            extraction_mode=base.extraction_mode,
            target_selector=base.target_selector,
            download_images=base.download_images,
            pagination_mode=base.pagination_mode,
            next_page_selector=base.next_page_selector,
            max_pages=base.max_pages,
            min_val=base.min_val,
            max_val=base.max_val,
            pad=base.pad,
            download_delay=base.download_delay,
            concurrent_requests=base.concurrent_requests,
            respect_robots=base.respect_robots,
            export_format=base.export_format,
            is_direct_media=bool(info["is_media"]),
            detected_sequence_num=info["sequence_number"],
            custom_headers=list(base.custom_headers),
            user_agent=base.user_agent,
            store_file=base.store_file,
            delegate_gallerydl=base.delegate_gallerydl,
            open_browser=base.open_browser,
            extra_domains=list(base.extra_domains),
        )

    return SpiderConfig(
        project_name=proj,
        spider_name=spid,
        start_url=str(info["normalized_url"]),
        url_template=str(info["url_template"]),
        allowed_domain=str(info["allowed_domain"]),
        extraction_mode=str(info["default_mode"]),
        target_selector="",
        download_images=True,
        pagination_mode=str(info["default_pagination"]),
        max_pages=10,
        min_val=seq_start,
        max_val=seq_start + 9,
        pad=int(info["pad_width"]),
        download_delay=1.0,
        concurrent_requests=2,
        respect_robots=False,
        export_format="json",
        is_direct_media=bool(info["is_media"]),
        detected_sequence_num=info["sequence_number"],
    )


def define_spider(spider_name, project_name, start_url, config=None):
    """Generate a complete Akasha-grade Scrapy spider tailored to `start_url` and `config`."""
    cfg = _resolve_config(project_name, spider_name, start_url, config)
    spiders_dir = validate_and_create_dir(os.path.join(project_name, project_name, "spiders"))
    spider_slug = sanitize_identifier(spider_name, default="akasha")
    spider_file_path = os.path.join(spiders_dir, f"{spider_slug}.py")

    project_class = to_class_prefix(project_name)
    spider_class = to_class_prefix(spider_name)
    allowed_domains = [cfg.allowed_domain] + [d for d in cfg.extra_domains if d != cfg.allowed_domain]

    spider_code = f'''\
from __future__ import annotations

import datetime
import re
from html.parser import HTMLParser
from urllib.parse import parse_qsl, urlencode, urljoin, urlparse, urlsplit, urlunsplit

try:
    import scrapy
    from scrapy.exceptions import CloseSpider
except ImportError:
    class CloseSpider(Exception):
        """Fallback CloseSpider exception when scrapy is not installed in active interpreter."""
        def __init__(self, reason: str = "cancelled") -> None:
            super().__init__(reason)
            self.reason = reason

    class _FallbackLogger:
        def warning(self, msg: str) -> None:
            pass
        def error(self, msg: str) -> None:
            pass
        def debug(self, msg: str) -> None:
            pass
        def info(self, msg: str) -> None:
            pass

    class _FallbackRequest:
        def __init__(
            self,
            url: str,
            callback=None,
            errback=None,
            headers=None,
            meta=None,
            dont_filter: bool = False,
        ) -> None:
            self.url = url
            self.callback = callback
            self.errback = errback
            self.headers = dict(headers or {{}})
            self.meta = dict(meta or {{}})
            self.dont_filter = dont_filter

    class _FallbackSpider:
        name: str = ""
        allowed_domains: list = []
        start_urls: list = []

        def __init__(self, *args, **kwargs) -> None:
            self.logger = _FallbackLogger()
            for k, v in kwargs.items():
                setattr(self, k, v)

    class _ScrapyShim:
        Spider = _FallbackSpider
        Request = _FallbackRequest

    scrapy = _ScrapyShim()  # type: ignore[assignment]

from {project_name}.items import {project_class}Item

_IMAGE_EXT_RE = re.compile(r"\\.(?:jpg|jpeg|png|gif|webp|bmp|svg|avif|tiff|ico)(?:$|[?#])", re.IGNORECASE)
_RAW_ASSET_URL_RE = re.compile(
    r'(?:http[s]?://|/)[^\\s"\\'<>]+(?:\\.jpg|\\.png|\\.gif|\\.webp|\\.jpeg)',
    re.IGNORECASE,
)
_PREF_SEQ_RE = re.compile(
    r"^(?P<prefix>.*?(?:img|image|pic|photo|page|p|sof|item|file|num|seq|[a-zA-Z])[_-]?)"
    r"(?P<num>\\d{{1,8}})"
    r"(?P<suffix>(?:[-_][0-9a-fA-F]{{6,}}.*|\\D.*)?)$",
    re.IGNORECASE,
)
_FALLBACK_SEQ_RE = re.compile(r"^(?P<prefix>.*?)(?P<num>\\d+)(?P<suffix>\\D*)$")
_QUERY_SEQ_KEYS = ("page", "p", "pg", "offset", "index", "num", "id")
_DISPLAY_NAME_TABLE = str.maketrans({{"_": " ", "-": " "}})

# WAF Evasion & Streamed Probe Headers from AkashaEnumerator (scraper.py)
_STATIC_WAF_PROBE_HEADERS = {{
    "Range": "bytes=0-8192",
    "Sec-Fetch-Dest": "image",
    "Sec-Fetch-Mode": "no-cors",
    "Sec-Fetch-Site": "same-origin",
    "Sec-Ch-Ua": '"Google Chrome";v="119", "Chromium";v="119", "Not?A_Brand";v="24"',
    "Sec-Ch-Ua-Mobile": "?0",
    "Sec-Ch-Ua-Platform": '"Windows"',
}}


class _SimpleHTMLCollector(HTMLParser):
    """Lightweight stdlib HTML extractor supporting fallback execution and link/image discovery."""
    def __init__(self) -> None:
        super().__init__()
        self.images: list[str] = []
        self.links: list[str] = []
        self.next_links: list[str] = []
        self.texts: list[str] = []
        self.title: str = ""
        self._in_title = False
        self._in_text_tag = False
        self._in_next_a = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr_map = {{k.lower(): (v or "") for k, v in attrs if k}}
        t = tag.lower()
        if t == "title":
            self._in_title = True
        elif t in ("h1", "h2", "h3", "p", "article", "li"):
            self._in_text_tag = True
        elif t == "img":
            for key in ("src", "data-src", "data-original", "data-lazy-src"):
                val = attr_map.get(key, "").strip()
                if val:
                    self.images.append(val)
        elif t == "source":
            srcset = attr_map.get("srcset", "").strip()
            if srcset:
                first_url = srcset.split(",")[0].strip().split(" ")[0]
                if first_url:
                    self.images.append(first_url)
        elif t == "meta":
            if attr_map.get("property", "").lower() in ("og:image", "twitter:image"):
                val = attr_map.get("content", "").strip()
                if val:
                    self.images.append(val)
        if t == "a":
            href = attr_map.get("href", "").strip()
            if href and not href.startswith(("javascript:", "mailto:", "tel:")):
                self.links.append(href)
                if _IMAGE_EXT_RE.search(href):
                    self.images.append(href)
                rel = attr_map.get("rel", "").lower()
                cls = attr_map.get("class", "").lower()
                if "next" in rel or "next" in cls:
                    self.next_links.append(href)
                else:
                    self._in_next_a = True
                    self._pending_href = href

    def handle_endtag(self, tag: str) -> None:
        t = tag.lower()
        if t == "title":
            self._in_title = False
        elif t in ("h1", "h2", "h3", "p", "article", "li"):
            self._in_text_tag = False
        elif t == "a":
            self._in_next_a = False

    def handle_data(self, data: str) -> None:
        cleaned = " ".join(data.split())
        if not cleaned:
            return
        if self._in_title and not self.title:
            self.title = cleaned
        if self._in_text_tag:
            self.texts.append(cleaned)
        if getattr(self, "_in_next_a", False) and cleaned.lower() in ("next", "next >", "next »", "»", "older"):
            href = getattr(self, "_pending_href", "")
            if href:
                self.next_links.append(href)


class {spider_class}Spider(scrapy.Spider):
    name = "{spider_slug}"
    allowed_domains = {allowed_domains!r}
    start_urls = [{cfg.start_url!r}]
    handle_httpstatus_list = [200, 206, 403, 404]

    # User-prompted & Akasha Omni-Enumerator configuration attributes
    url_template = {cfg.url_template!r}
    extraction_mode = {cfg.extraction_mode!r}
    target_selector = {cfg.target_selector!r}
    download_images = {bool(cfg.download_images)!r}
    pagination_mode = {cfg.pagination_mode!r}
    next_page_selector = {cfg.next_page_selector!r}
    max_pages = {int(cfg.max_pages)}
    min_val = {int(cfg.min_val)}
    max_val = {int(cfg.max_val)}
    pad = {int(cfg.pad)}
    store_file = {cfg.store_file!r}
    delegate_gallerydl = {bool(cfg.delegate_gallerydl)!r}
    open_browser = {bool(cfg.open_browser)!r}

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if "start_url" in kwargs and kwargs["start_url"]:
            self.start_urls = [str(kwargs["start_url"])]
        if "max_pages" in kwargs and kwargs["max_pages"] is not None:
            self.max_pages = int(kwargs["max_pages"])
        self._pages_crawled = 0
        self._visited_urls = set()
        self.found_urls = set()

    def build_waf_headers(self, target_url: str, is_probe: bool = False) -> dict:
        """Build Akasha WAF-evasion headers with dynamic Referer and optional Range probe."""
        headers = dict(_STATIC_WAF_PROBE_HEADERS) if is_probe else {{}}
        slash_idx = target_url.rfind("/")
        headers["Referer"] = target_url[: slash_idx + 1] if slash_idx != -1 else target_url
        return headers

    def start_requests(self):
        """Execute Akasha pre-flight request to establish session cookies before target enumeration."""
        if not self.start_urls:
            return
        primary_url = self.start_urls[0]
        parsed = urlparse(primary_url.replace("{{}}", "1"))
        base_origin = f"{{parsed.scheme}}://{{parsed.netloc}}/"
        yield scrapy.Request(
            base_origin,
            callback=self._after_preflight,
            errback=self._preflight_errback,
            meta={{"is_preflight": True, "target_url": primary_url}},
            dont_filter=True,
        )

    def _preflight_errback(self, failure):
        self.logger.warning(f"Pre-flight warning: {{failure}}")
        req = getattr(failure, "request", None)
        meta = getattr(req, "meta", {{}}) if req else {{}}
        target_url = meta.get("target_url") or (self.start_urls[0] if self.start_urls else "")
        if target_url:
            yield from self._dispatch_enumeration_requests(target_url)

    def _after_preflight(self, response):
        meta = getattr(response, "meta", None) or {{}}
        target_url = meta.get("target_url") or (self.start_urls[0] if self.start_urls else response.url)
        yield from self._dispatch_enumeration_requests(target_url)

    def _dispatch_enumeration_requests(self, target_url: str):
        """Dispatch either the Akasha brute-force matrix (with unpadded fallback metadata) or initial scrape."""
        if self.pagination_mode == "brute" or self.extraction_mode == "brute" or "{{}}" in self.url_template:
            tpl = self.url_template if "{{}}" in self.url_template else (target_url + "{{}}")
            for i in range(self.min_val, self.max_val + 1):
                padded_str = str(i).zfill(self.pad) if self.pad > 0 else str(i)
                unpadded_str = str(i)
                padded_url = tpl.replace("{{}}", padded_str)
                unpadded_url = tpl.replace("{{}}", unpadded_str)
                meta = {{"brute_index": i}}
                if padded_url != unpadded_url:
                    meta["unpadded_fallback_url"] = unpadded_url
                yield scrapy.Request(
                    padded_url,
                    callback=self.parse,
                    errback=self.handle_error,
                    headers=self.build_waf_headers(padded_url, is_probe=True),
                    meta=meta,
                )
        else:
            yield scrapy.Request(
                target_url,
                callback=self.parse,
                errback=self.handle_error,
                headers=self.build_waf_headers(target_url, is_probe=self._is_media_url(target_url)),
            )

    def parse(self, response):
        status = getattr(response, "status", 200)
        meta = getattr(response, "meta", None) or {{}}

        # Akasha Unpadded Fallback Heuristic on HTTP 404 / 403
        if status in (404, 403) and meta.get("unpadded_fallback_url") and not meta.get("is_unpadded_fallback"):
            fallback_url = meta["unpadded_fallback_url"]
            if fallback_url not in self._visited_urls:
                self._visited_urls.add(fallback_url)
                self.logger.info(f"Padding mismatch (HTTP {{status}}) on {{response.url}}; trying unpadded fallback {{fallback_url}}")
                yield scrapy.Request(
                    fallback_url,
                    callback=self.parse,
                    errback=self.handle_error,
                    headers=self.build_waf_headers(fallback_url, is_probe=True),
                    meta={{"is_unpadded_fallback": True, "brute_index": meta.get("brute_index")}},
                )
            return

        if status not in (200, 206):
            if meta.get("brute_index") is not None or meta.get("is_unpadded_fallback"):
                self.logger.warning(f"Invalid brute target: {{response.url}} (HTTP {{status}})")
                return
            self.logger.warning(f"Failed to retrieve URL: {{response.url}} (HTTP {{status}})")
            raise CloseSpider(f"Non-200 status code encountered: {{status}}")

        self._pages_crawled += 1
        self._visited_urls.add(response.url)

        now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
        if self._is_direct_media_response(response):
            image_url = response.url
            image_name = self.extract_image_name(image_url)
            self.found_urls.add(image_url)
            item = {project_class}Item()
            item["image_urls"] = [image_url]
            item["image_name"] = image_name
            item["page_url"] = response.url
            item["title"] = image_name
            item["extracted_text"] = []
            item["extracted_links"] = []
            item["timestamp"] = now_iso
            yield item
        else:
            extracted = self._extract_document_data(response)
            image_urls = extracted["image_urls"]
            if not image_urls and self.extraction_mode == "images":
                image_urls = [response.url]
            for u in image_urls:
                self.found_urls.add(u)
            for u in extracted["links"]:
                if self._is_media_url(u) or self.extraction_mode in ("links", "scrape", "full"):
                    self.found_urls.add(u)

            primary_ref = image_urls[0] if image_urls else response.url
            image_name = self.extract_image_name(primary_ref)
            if extracted["title"] and self.extraction_mode in ("text", "links"):
                image_name = self.extract_image_name(extracted["title"])

            item = {project_class}Item()
            item["image_urls"] = image_urls if self.download_images else []
            item["image_name"] = image_name
            item["page_url"] = response.url
            item["title"] = extracted["title"] or image_name
            item["extracted_text"] = extracted["texts"]
            item["extracted_links"] = extracted["links"]
            item["timestamp"] = now_iso
            yield item

        # Bounded pagination / sequence iteration when not already dispatched as a full brute batch
        if (
            self.pagination_mode not in ("none", "brute")
            and meta.get("brute_index") is None
            and self._pages_crawled < self.max_pages
        ):
            for next_url in self._discover_next_urls(response):
                if next_url and next_url not in self._visited_urls:
                    self._visited_urls.add(next_url)
                    yield scrapy.Request(
                        next_url,
                        callback=self.parse,
                        errback=self.handle_error,
                        headers=self.build_waf_headers(next_url, is_probe=self._is_media_url(next_url)),
                    )

    def _is_media_url(self, url: str) -> bool:
        return bool(_IMAGE_EXT_RE.search(url))

    def _is_direct_media_response(self, response) -> bool:
        headers = getattr(response, "headers", None) or {{}}
        content_type = ""
        if hasattr(headers, "get"):
            raw_ct = headers.get("Content-Type") or headers.get(b"Content-Type") or ""
            content_type = raw_ct.decode("utf-8", errors="ignore") if isinstance(raw_ct, bytes) else str(raw_ct)
        if content_type.lower().startswith(("image/", "video/", "audio/", "application/pdf", "application/octet-stream")):
            return True
        text_body = getattr(response, "text", None)
        if isinstance(text_body, str) and "<html" in text_body[:512].lower():
            return False
        return bool(_IMAGE_EXT_RE.search(response.url))

    def _extract_document_data(self, response) -> dict:
        image_urls: list[str] = []
        texts: list[str] = []
        links: list[str] = []
        next_links: list[str] = []
        title = ""

        body_text = getattr(response, "text", "") or ""
        if not body_text and isinstance(getattr(response, "body", None), (bytes, bytearray)):
            body_text = response.body.decode("utf-8", errors="ignore")

        has_selector_api = hasattr(response, "css") and hasattr(response, "xpath")
        if has_selector_api:
            title_vals = response.css("title::text").getall()
            title = title_vals[0].strip() if title_vals else ""

            if self.target_selector:
                sel = self.target_selector.strip()
                matched = (
                    response.xpath(sel).getall()
                    if sel.startswith(("/", "("))
                    else response.css(sel).getall()
                )
                cleaned_matches = [m.strip() for m in matched if m and m.strip()]
                if self.extraction_mode == "images":
                    image_urls.extend(urljoin(response.url, u) for u in cleaned_matches)
                elif self.extraction_mode == "links":
                    links.extend(urljoin(response.url, u) for u in cleaned_matches)
                else:
                    texts.extend(cleaned_matches)

            if self.extraction_mode in ("images", "full", "scrape") and not image_urls:
                raw_imgs = (
                    response.css("img::attr(src), img::attr(data-src), img::attr(data-original)::attr(src)").getall()
                    + response.css('meta[property="og:image"]::attr(content)').getall()
                )
                for raw_u in raw_imgs:
                    if raw_u and raw_u.strip():
                        image_urls.append(urljoin(response.url, raw_u.strip()).split("#", 1)[0])

            if self.extraction_mode in ("text", "full", "scrape") and not texts:
                raw_texts = response.css("h1::text, h2::text, h3::text, p::text, article ::text").getall()
                texts.extend(" ".join(t.split()) for t in raw_texts if t and t.strip())

            if self.extraction_mode in ("links", "full", "scrape") and not links:
                for href in response.css("a::attr(href)").getall():
                    if href and not href.startswith(("javascript:", "mailto:", "tel:")):
                        links.append(urljoin(response.url, href.strip()).split("#", 1)[0])
        else:
            collector = _SimpleHTMLCollector()
            try:
                collector.feed(body_text)
            except Exception:
                pass
            title = collector.title
            image_urls = [urljoin(response.url, u).split("#", 1)[0] for u in collector.images]
            texts = collector.texts
            links = [urljoin(response.url, u).split("#", 1)[0] for u in collector.links]
            next_links = [urljoin(response.url, u).split("#", 1)[0] for u in collector.next_links]

        # Akasha raw regex extraction from page source (captures inline JSON/JS asset URLs)
        if body_text:
            for raw_match in _RAW_ASSET_URL_RE.findall(body_text):
                abs_asset = urljoin(response.url, raw_match).split("#", 1)[0]
                if abs_asset.startswith("http"):
                    image_urls.append(abs_asset)

        return {{
            "title": title,
            "image_urls": list(dict.fromkeys(image_urls)),
            "texts": list(dict.fromkeys(texts)),
            "links": list(dict.fromkeys(links)),
            "next_links": list(dict.fromkeys(next_links)),
        }}

    def _discover_next_urls(self, response) -> list[str]:
        candidates: list[str] = []
        if self.pagination_mode in ("link", "auto") and not self._is_direct_media_response(response):
            if hasattr(response, "css") and hasattr(response, "xpath") and self.next_page_selector:
                sel = self.next_page_selector.strip()
                raw_next = (
                    response.xpath(sel).getall()
                    if sel.startswith(("/", "("))
                    else response.css(sel).getall()
                )
                for href in raw_next:
                    if href and href.strip():
                        candidates.append(urljoin(response.url, href.strip()))
            else:
                extracted = self._extract_document_data(response)
                candidates.extend(extracted.get("next_links", []))

        if self.pagination_mode in ("sequence", "auto") and not candidates:
            try:
                next_seq_url = self.build_next_sequence_url(response.url)
                if next_seq_url and next_seq_url != response.url:
                    candidates.append(next_seq_url)
            except Exception as e:
                self.logger.debug(f"Could not iterate URL: {{e}}")

        return candidates

    def handle_error(self, failure):
        req = getattr(failure, "request", None)
        failed_url = getattr(req, "url", str(failure))
        self.logger.error(f"Request failed: {{failed_url}}")

    def extract_image_name(self, url: str) -> str:
        path = urlsplit(url).path if "://" in url or "?" in url or "#" in url else url
        basename = path.rstrip("/").rsplit("/", 1)[-1]
        image_name = basename.split(".", 1)[0] if basename else "default"
        cleaned = " ".join(image_name.strip().translate(_DISPLAY_NAME_TABLE).split())
        return cleaned.capitalize() if cleaned else "Default"

    def extract_image_number(self, url: str) -> int:
        parts = urlsplit(url)
        if parts.query:
            for k, v in parse_qsl(parts.query, keep_blank_values=True):
                if k.lower() in _QUERY_SEQ_KEYS and v.isdigit():
                    return int(v)
        basename = (parts.path or url).rsplit("/", 1)[-1]
        stem = basename.rpartition(".")[0] or basename
        match = _PREF_SEQ_RE.match(stem) or _FALLBACK_SEQ_RE.match(stem)
        if match:
            try:
                return int(match.group("num"))
            except ValueError:
                return 0
        return 0

    def build_next_sequence_url(self, url: str, step: int = 1) -> str:
        parts = urlsplit(url)
        if parts.query:
            q_pairs = parse_qsl(parts.query, keep_blank_values=True)
            for idx, (k, v) in enumerate(q_pairs):
                if k.lower() in _QUERY_SEQ_KEYS and v.isdigit():
                    width = len(v)
                    nxt = int(v) + step
                    q_pairs[idx] = (k, f"{{nxt:0{{width}}d}}" if (width > 1 and v.startswith("0")) else str(nxt))
                    return urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(q_pairs), parts.fragment))

        dir_prefix, sep, basename = (parts.path or "").rpartition("/")
        if not basename:
            return url
        stem, dot, ext = basename.rpartition(".")
        if not dot:
            stem, ext = basename, ""
        else:
            ext = f".{{ext}}"

        match = _PREF_SEQ_RE.match(stem) or _FALLBACK_SEQ_RE.match(stem)
        if not match:
            return url
        num_str = match.group("num")
        width = len(num_str)
        next_num = int(num_str) + step
        formatted = f"{{next_num:0{{width}}d}}" if (width > 1 and num_str.startswith("0")) else str(next_num)
        new_basename = f"{{match.group('prefix')}}{{formatted}}{{match.group('suffix')}}{{ext}}"
        new_path = f"{{dir_prefix}}{{sep}}{{new_basename}}" if sep else new_basename
        return urlunsplit((parts.scheme, parts.netloc, new_path, parts.query, parts.fragment))
'''
    with open(spider_file_path, "w", encoding="utf-8") as f:
        f.write(textwrap.dedent(spider_code))
    return spider_file_path


def configure_settings(project_name, config=None):
    """Configure Scrapy settings.py with anti-ban defaults, WAF headers, feed exports, and item pipelines."""
    cfg = _resolve_config(project_name, config=config)
    bootstrap_project_skeleton(project_name)
    settings_file_path = os.path.join(project_name, project_name, "settings.py")
    project_class = to_class_prefix(project_name)

    existing = ""
    if os.path.exists(settings_file_path):
        with open(settings_file_path, "r", encoding="utf-8") as f:
            existing = f.read()

    marker = "# --- Custom Anti-Ban & Stability Settings ---"
    if marker in existing:
        existing = existing.split(marker, 1)[0].rstrip() + "\n"

    feed_format = cfg.export_format if cfg.export_format in VALID_EXPORT_FORMATS else "json"
    feed_ext = "jsonl" if feed_format == "jsonl" else feed_format
    feed_driver = "jsonlines" if feed_format == "jsonl" else feed_format
    ua = cfg.user_agent or "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"

    settings_append = f'''
# --- Custom Anti-Ban & Stability Settings ---
# Replaces default async DNS with standard threaded resolver (VPN/Arch safe)
DNS_RESOLVER = 'scrapy.resolver.CachingThreadedResolver'

ROBOTSTXT_OBEY = {bool(cfg.respect_robots)!r}
COOKIES_ENABLED = True
DOWNLOAD_DELAY = {float(cfg.download_delay)}
CONCURRENT_REQUESTS = {int(cfg.concurrent_requests)}
CONCURRENT_REQUESTS_PER_DOMAIN = {int(cfg.concurrent_requests)}

USER_AGENT = {ua!r}
LOG_LEVEL = 'INFO'
HTTPCACHE_ENABLED = True
AUTOTHROTTLE_ENABLED = True

DOWNLOADER_MIDDLEWARES = {{
    '{project_name}.middlewares.{project_class}DownloaderMiddleware': 543,
}}

# --- Pipeline & Export Configuration ---
IMAGES_STORE = 'images'
ITEM_PIPELINES = {{
    '{project_name}.pipelines.{project_class}Pipeline': 100,
    '{project_name}.pipelines.{project_class}ImagesPipeline': 200,
}}

FEEDS = {{
    'output.{feed_ext}': {{
        'format': '{feed_driver}',
        'encoding': 'utf8',
        'overwrite': True,
    }},
}}
'''
    with open(settings_file_path, "w", encoding="utf-8") as f:
        f.write(existing + settings_append)
    return settings_file_path


def update_items_py(project_name, config=None):
    """Write `<project>/<project>/items.py` with full Scrapy & fallback Item support."""
    validate_and_create_dir(os.path.join(project_name, project_name))
    project_class = to_class_prefix(project_name)
    items_path = os.path.join(project_name, project_name, "items.py")

    items_code = f'''\
try:
    import scrapy
except ImportError:
    class _FallbackItem(dict):
        """Dict-backed Scrapy Item shim when scrapy is not installed in active interpreter."""
        pass

    class _ScrapyItemShim:
        Item = _FallbackItem
        @staticmethod
        def Field(*args, **kwargs):
            return {{}}

    scrapy = _ScrapyItemShim()  # type: ignore[assignment]


class {project_class}Item(scrapy.Item):
    image_urls = scrapy.Field()
    images = scrapy.Field()
    image_name = scrapy.Field()
    page_url = scrapy.Field()
    title = scrapy.Field()
    extracted_text = scrapy.Field()
    extracted_links = scrapy.Field()
    timestamp = scrapy.Field()
'''
    with open(items_path, "w", encoding="utf-8") as f:
        f.write(textwrap.dedent(items_code))
    return items_path


def update_middlewares_py(project_name, config=None):
    """Write `<project>/<project>/middlewares.py` with Akasha WAF-evasion downloader middleware."""
    validate_and_create_dir(os.path.join(project_name, project_name))
    project_class = to_class_prefix(project_name)
    middlewares_path = os.path.join(project_name, project_name, "middlewares.py")

    middlewares_code = f'''\
try:
    from scrapy import signals
except ImportError:
    class signals:  # type: ignore[no-redef]
        spider_opened = "spider_opened"


class {project_class}SpiderMiddleware:
    @classmethod
    def from_crawler(cls, crawler):
        s = cls()
        crawler.signals.connect(s.spider_opened, signal=signals.spider_opened)
        return s

    def process_spider_input(self, response, spider):
        return None

    def process_spider_output(self, response, result, spider):
        for i in result:
            yield i

    def process_spider_exception(self, response, exception, spider):
        return None

    def process_start_requests(self, start_requests, spider):
        for r in start_requests:
            yield r

    def spider_opened(self, spider):
        spider.logger.info(f"Spider opened: {{spider.name}}")


class {project_class}DownloaderMiddleware:
    """Injects AkashaEnumerator WAF evasion headers, dynamic Referer, and Client Hints."""
    DEFAULT_USER_AGENT = (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
    )
    WAF_HEADERS = {{
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Sec-Fetch-Mode": "no-cors",
        "Sec-Fetch-Site": "same-origin",
        "Sec-Ch-Ua": '"Google Chrome";v="119", "Chromium";v="119", "Not?A_Brand";v="24"',
        "Sec-Ch-Ua-Mobile": "?0",
        "Sec-Ch-Ua-Platform": '"Windows"',
    }}

    @classmethod
    def from_crawler(cls, crawler):
        s = cls()
        crawler.signals.connect(s.spider_opened, signal=signals.spider_opened)
        return s

    def process_request(self, request, spider):
        if hasattr(request, "headers") and isinstance(request.headers, dict):
            request.headers.setdefault("User-Agent", self.DEFAULT_USER_AGENT)
            for k, v in self.WAF_HEADERS.items():
                request.headers.setdefault(k, v)
            req_url = getattr(request, "url", "")
            if req_url and "Referer" not in request.headers and b"Referer" not in request.headers:
                slash_idx = req_url.rfind("/")
                request.headers["Referer"] = req_url[: slash_idx + 1] if slash_idx != -1 else req_url
        return None

    def process_response(self, request, response, spider):
        return response

    def process_exception(self, request, exception, spider):
        spider.logger.warning(f"Downloader exception on {{getattr(request, 'url', request)}}: {{exception}}")
        return None

    def spider_opened(self, spider):
        spider.logger.info(f"Downloader middleware active for: {{spider.name}}")
'''
    with open(middlewares_path, "w", encoding="utf-8") as f:
        f.write(textwrap.dedent(middlewares_code))
    return middlewares_path


def update_pipelines_py(project_name, config=None):
    """Write `<project>/<project>/pipelines.py` with path-safe item processing & AkashaIntegrator."""
    validate_and_create_dir(os.path.join(project_name, project_name))
    project_class = to_class_prefix(project_name)
    pipelines_path = os.path.join(project_name, project_name, "pipelines.py")

    pipelines_code = f'''\
import datetime
import os
import re
import shutil
import subprocess
import tempfile
import webbrowser
from pathlib import Path
from urllib.parse import urlsplit

try:
    from scrapy import Request
    from scrapy.exceptions import DropItem
    from scrapy.pipelines.images import ImagesPipeline
except ImportError:
    class DropItem(Exception):
        """Fallback DropItem exception when scrapy is not installed in active interpreter."""
        pass

    class Request:  # type: ignore[no-redef]
        def __init__(self, url: str, meta=None) -> None:
            self.url = url
            self.meta = dict(meta or {{}})

    class ImagesPipeline:  # type: ignore[no-redef]
        @classmethod
        def from_crawler(cls, crawler):
            return cls()

_CLEAN_NAME_TABLE = str.maketrans({{
    " ": "_",
    "/": "-",
    "\\\\": "-",
    ":": "-",
    "\\0": "",
}})
_SAFE_FILENAME_RE = re.compile(r"[^A-Za-z0-9._-]+")
_MULTI_UNDERSCORE_RE = re.compile(r"_+")


def get_xdg_dir(kind: str, fallback: str) -> Path:
    var = f"XDG_{{kind.upper()}}_HOME"
    return Path(os.environ.get(var, str(Path.home() / fallback)))


XDG_DATA = get_xdg_dir("data", ".local/share/akasha-enum")
DOWNLOADS_DIR = XDG_DATA / "downloads"


class AkashaIntegrator:
    """Post-exploitation subsystem integrations ported from scraper.py into the Scrapy pipeline."""

    @staticmethod
    def open_browser(urls) -> None:
        if not urls:
            return
        for u in urls:
            webbrowser.open_new_tab(u)

    @staticmethod
    def store_idempotent(urls, filename: str) -> int:
        if not urls or not filename:
            return 0
        existing = set()
        if os.path.exists(filename):
            with open(filename, "r", encoding="utf-8") as f:
                existing = {{line.strip() for line in f if line.strip()}}
        new_urls = set(urls) - existing
        if not new_urls:
            return 0
        parent_dir = os.path.dirname(os.path.abspath(filename))
        if parent_dir and not os.path.exists(parent_dir):
            os.makedirs(parent_dir, exist_ok=True)
        with open(filename, "a", encoding="utf-8") as f:
            for u in sorted(new_urls):
                f.write(f"{{u}}\\n")
        return len(new_urls)

    @staticmethod
    def delegate_gallerydl(urls, out_dir: Path = DOWNLOADS_DIR) -> bool:
        if not urls or not shutil.which("gallery-dl"):
            return False
        out_dir.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", delete=False) as tmp:
            for u in sorted(urls):
                tmp.write(f"{{u}}\\n")
            tmp_path = tmp.name
        try:
            subprocess.run(["gallery-dl", "-i", tmp_path, "-d", str(out_dir)], check=True, timeout=300)
            return True
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            return False
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)


class {project_class}Pipeline:
    def __init__(self) -> None:
        self.collected_urls: set[str] = set()

    def process_item(self, item, spider):
        mode = getattr(spider, "extraction_mode", "images")
        has_images = bool(item.get("image_urls"))
        has_text_or_links = bool(item.get("extracted_text") or item.get("extracted_links") or item.get("title"))

        if mode == "images" and (not has_images or not item.get("image_name")):
            raise DropItem(f"Missing required fields in {{item}}")
        if not has_images and not has_text_or_links and not item.get("image_name"):
            raise DropItem(f"Missing required fields in {{item}}")

        raw_name = item.get("image_name") or item.get("title") or "default_name"
        item["image_name"] = self.clean_image_name(str(raw_name))
        if not item.get("timestamp"):
            item["timestamp"] = datetime.datetime.now(datetime.timezone.utc).isoformat()

        for u in item.get("image_urls") or []:
            self.collected_urls.add(u)
        return item

    def close_spider(self, spider) -> None:
        all_urls = set(self.collected_urls) | set(getattr(spider, "found_urls", set()))
        if not all_urls:
            return
        store_file = getattr(spider, "store_file", "")
        if store_file:
            AkashaIntegrator.store_idempotent(all_urls, store_file)
        if getattr(spider, "delegate_gallerydl", False):
            AkashaIntegrator.delegate_gallerydl(all_urls, DOWNLOADS_DIR)
        if getattr(spider, "open_browser", False):
            AkashaIntegrator.open_browser(all_urls)

    def clean_image_name(self, name: str) -> str:
        if not name or not name.strip():
            return "default_name"
        cleaned = name.strip().translate(_CLEAN_NAME_TABLE).replace("..", "_")
        cleaned = _SAFE_FILENAME_RE.sub("_", cleaned)
        cleaned = _MULTI_UNDERSCORE_RE.sub("_", cleaned).strip("._-")
        return cleaned or "default_name"


class {project_class}ImagesPipeline(ImagesPipeline):
    def get_media_requests(self, item, info):
        cleaned_name = item.get("image_name") or "default_name"
        for image_url in item.get("image_urls", []):
            yield Request(image_url, meta={{"image_name": cleaned_name}})

    def file_path(self, request, response=None, info=None, *, item=None):
        raw_meta_name = (
            request.meta.get("image_name")
            or (item.get("image_name") if item else None)
            or "default_name"
        )
        safe_folder = (
            str(raw_meta_name).strip().translate(_CLEAN_NAME_TABLE).replace("..", "_")
        )
        safe_folder = _SAFE_FILENAME_RE.sub("_", safe_folder).strip("._-") or "default_name"

        clean_path = urlsplit(request.url).path
        raw_guid = os.path.basename(clean_path) or "image.jpg"
        safe_guid = _SAFE_FILENAME_RE.sub("_", raw_guid.replace("..", "_")).strip("._-") or "image.jpg"
        return f"{{safe_folder}}/{{safe_guid}}"
'''
    with open(pipelines_path, "w", encoding="utf-8") as f:
        f.write(textwrap.dedent(pipelines_code))
    return pipelines_path


def setup_pyproject_toml(project_name, config=None):
    """Write `<project>/pyproject.toml` with Poetry dependency metadata."""
    validate_and_create_dir(project_name)
    toml_path = os.path.join(project_name, "pyproject.toml")
    toml_content = f'''\
[tool.poetry]
name = "{project_name}"
version = "0.1.0"
description = "Automated Scrapy Extraction Matrix"
authors = ["Ghost <ghost@matrix.local>"]

[tool.poetry.dependencies]
python = "^3.11"
scrapy = "^2.11.0"
pillow = "^10.0.0"
'''
    with open(toml_path, "w", encoding="utf-8") as f:
        f.write(textwrap.dedent(toml_content))
    return toml_path


def _looks_like_url(value):
    """Return True if `value` resembles a URL or domain rather than a plain project identifier."""
    v = value.strip()
    if not v:
        return False
    return "://" in v or "/" in v or "." in v or ":" in v or "{}" in v


def prompt_user_for_spider_config(initial_url=None, initial_project=None, initial_spider=None):
    """Prompt the user for a single target URL and Akasha / Scrapy spider answers."""
    print("==== Ψ-4NDR0666 SCRAPY & OMNI-ENUMERATOR GENERATOR ====")
    print("Enter a single target URL and answer the prompts (press Enter for defaults):")
    eof_state = {"reached": False}

    def ask(prompt_text, default):
        if eof_state["reached"]:
            return default
        try:
            ans = input(prompt_text).strip()
            return ans if ans else default
        except (EOFError, StopIteration):
            eof_state["reached"] = True
            return default

    legacy_project = None
    legacy_spider = None

    if initial_url:
        raw_url = initial_url
    else:
        first_val = ask("Enter start URL [https://www.example.com]: ", "https://www.example.com")
        if _looks_like_url(first_val):
            raw_url = first_val
        else:
            legacy_project = first_val
            legacy_spider = ask("Enter spider name [akasha]: ", "akasha")
            raw_url = ask("Enter start URL [https://www.example.com]: ", "https://www.example.com")

    url_info = inspect_target_url(raw_url)
    normalized_url = str(url_info["normalized_url"])
    url_template = str(url_info["url_template"])
    allowed_domain = str(url_info["allowed_domain"])
    default_project = initial_project or legacy_project or str(url_info["default_project"])
    default_spider = initial_spider or legacy_spider or str(url_info["default_spider"])
    default_mode = str(url_info["default_mode"])
    default_pagination = str(url_info["default_pagination"])
    detected_num = url_info["sequence_number"]
    detected_pad = int(url_info["pad_width"])

    if initial_project or legacy_project:
        raw_project = default_project
    else:
        raw_project = ask(f"Enter project name [{default_project}]: ", default_project)

    if initial_spider or legacy_spider:
        raw_spider = default_spider
    else:
        raw_spider = ask(f"Enter spider name [{default_spider}]: ", default_spider)

    raw_mode = ask(
        f"Select extraction mode (1=scrape / 2=brute / images / text / links / full) [{default_mode}]: ",
        default_mode,
    ).lower()
    if raw_mode == "1":
        extraction_mode = "scrape"
    elif raw_mode == "2":
        extraction_mode = "brute"
    elif raw_mode in VALID_EXTRACTION_MODES:
        extraction_mode = raw_mode
    else:
        extraction_mode = default_mode

    target_selector = ask(
        "Enter target CSS or XPath selector (leave blank for auto-discovery) []: ",
        "",
    )

    default_dl_img = "y" if extraction_mode in ("images", "full", "scrape", "brute") else "n"
    raw_dl_img = ask(
        f"Download discovered images via ImagesPipeline? (y/n) [{default_dl_img}]: ",
        default_dl_img,
    ).lower()
    download_images = raw_dl_img.startswith("y")

    if extraction_mode == "brute":
        pagination_mode = "brute"
    else:
        raw_pagination = ask(
            f"Select pagination strategy (auto/sequence/brute/link/none) [{default_pagination}]: ",
            default_pagination,
        ).lower()
        pagination_mode = raw_pagination if raw_pagination in VALID_PAGINATION_MODES else default_pagination

    default_next_sel = 'a[rel="next"]::attr(href), a.next::attr(href), li.next a::attr(href)'
    if pagination_mode in ("link", "auto") and not bool(url_info["is_media"]):
        next_page_selector = ask(
            f"Enter next-page CSS/XPath selector [{default_next_sel}]: ",
            default_next_sel,
        )
    else:
        next_page_selector = default_next_sel

    default_min = int(detected_num) if detected_num is not None else 1
    pad = detected_pad

    if pagination_mode == "brute" or extraction_mode == "brute" or bool(url_info["has_brace_slot"]):
        default_max = default_min + 99
        raw_min = ask(f"Minimum Sequence Value [{default_min}]: ", str(default_min))
        raw_max = ask(f"Maximum Sequence Value [{default_max}]: ", str(default_max))
        raw_pad = ask(f"Zero-padding width (e.g. 3 for 001) [{detected_pad}]: ", str(detected_pad))
        try:
            min_val = int(raw_min)
            max_val = int(raw_max)
            pad = max(0, int(raw_pad))
        except ValueError:
            min_val, max_val, pad = default_min, default_max, detected_pad
        max_pages = max(1, abs(max_val - min_val) + 1)
    else:
        raw_max_pages = ask("Enter max pages/items to crawl [10]: ", "10")
        try:
            max_pages = max(1, int(raw_max_pages))
        except ValueError:
            max_pages = 10
        min_val = default_min
        max_val = default_min + max_pages - 1

    raw_delay = ask("Enter download delay in seconds [1.0]: ", "1.0")
    try:
        download_delay = max(0.0, float(raw_delay))
    except ValueError:
        download_delay = 1.0

    raw_robots = ask("Obey robots.txt? (y/n) [n]: ", "n").lower()
    respect_robots = raw_robots.startswith("y")

    raw_format = ask("Select output export format (json/jsonl/csv/xml) [json]: ", "json").lower()
    export_format = raw_format if raw_format in VALID_EXPORT_FORMATS else "json"

    store_file = ask("Idempotent URL store file (blank to disable) [found_urls.txt]: ", "found_urls.txt")
    raw_gdl = ask("Delegate bulk transfer to gallery-dl on completion? (y/n) [n]: ", "n").lower()
    delegate_gdl = raw_gdl.startswith("y")
    raw_browser = ask("Open discovered assets in browser on completion? (y/n) [n]: ", "n").lower()
    open_browser = raw_browser.startswith("y")

    cfg = SpiderConfig(
        project_name=sanitize_identifier(raw_project, default="akasha_enum"),
        spider_name=sanitize_identifier(raw_spider, default="akasha"),
        start_url=normalized_url,
        url_template=url_template,
        allowed_domain=allowed_domain,
        extraction_mode=extraction_mode,
        target_selector=target_selector,
        download_images=download_images,
        pagination_mode=pagination_mode,
        next_page_selector=next_page_selector,
        max_pages=max_pages,
        min_val=min_val,
        max_val=max_val,
        pad=pad,
        download_delay=download_delay,
        concurrent_requests=2,
        respect_robots=respect_robots,
        export_format=export_format,
        is_direct_media=bool(url_info["is_media"]),
        detected_sequence_num=detected_num,
        store_file=store_file,
        delegate_gallerydl=delegate_gdl,
        open_browser=open_browser,
    )
    set_active_config(cfg)
    return cfg


def parse_arguments(argv=None):
    """Parse CLI arguments or launch the interactive single-URL prompt generator."""
    parser = argparse.ArgumentParser(description="Automate Scrapy Scaffold & Single-URL Spider Generator")
    parser.add_argument("-u", "--url", help="Start URL (concrete URL or {} brute template)")
    parser.add_argument("--project", help="Project name")
    parser.add_argument("--spider", help="Spider name")
    parser.add_argument(
        "-i",
        "--interactive",
        action="store_true",
        help="Prompt interactively for a single URL and spider configuration answers",
    )
    parser.add_argument(
        "-m",
        "--menu",
        action="store_true",
        help="Launch the interactive Akasha console menu",
    )
    parser.add_argument(
        "--mode",
        choices=VALID_EXTRACTION_MODES,
        help="Extraction mode (images, text, links, full, scrape, brute)",
    )
    parser.add_argument("--brute", action="store_true", help="Enable zero-padded sequence brute-force mode")
    parser.add_argument("--scrape", action="store_true", help="Enable recursive DOM + regex extraction mode")
    parser.add_argument("--min", dest="min_val", type=int, default=None, help="Minimum sequence value (Brute mode)")
    parser.add_argument("--max", dest="max_val", type=int, default=None, help="Maximum sequence value (Brute mode)")
    parser.add_argument("--pad", type=int, default=None, help="Zero-padding width (e.g., 3 for 001)")
    parser.add_argument("--selector", default="", help="Custom CSS or XPath selector for extraction")
    parser.add_argument(
        "--pagination",
        choices=VALID_PAGINATION_MODES,
        help="Pagination strategy (auto, sequence, brute, link, none)",
    )
    parser.add_argument("--next-selector", default="", help="CSS or XPath selector for next-page links")
    parser.add_argument("--max-pages", type=int, default=10, help="Maximum pages/items to crawl")
    parser.add_argument("--delay", type=float, default=1.0, help="Download delay in seconds")
    parser.add_argument("--robots", action="store_true", help="Obey robots.txt")
    parser.add_argument("-H", "--header", action="append", default=[], help="Custom headers ('Key: Value')")
    parser.add_argument("-A", "--user-agent", default="", help="Override default User-Agent")
    parser.add_argument("--store", default="found_urls.txt", help="Save discovered assets to file (Idempotent)")
    parser.add_argument("--download", action="store_true", help="Delegate bulk download to gallery-dl on completion")
    parser.add_argument("--browser", action="store_true", help="Open discovered assets in browser on completion")
    parser.add_argument(
        "--format",
        choices=VALID_EXPORT_FORMATS,
        default="json",
        help="Output feed format (json, jsonl, csv, xml)",
    )
    parser.add_argument(
        "--benchmark-workload",
        type=int,
        default=0,
        help=argparse.SUPPRESS,
    )
    args = parser.parse_args(argv)

    if args.benchmark_workload > 0:
        _run_benchmark_workload(args.benchmark_workload)
        raise SystemExit(0)

    if args.interactive or args.menu or not args.url:
        cfg = prompt_user_for_spider_config(
            initial_url=args.url,
            initial_project=args.project,
            initial_spider=args.spider,
        )
        return cfg.project_name, cfg.spider_name, cfg.start_url

    url_info = inspect_target_url(args.url)
    project_name = sanitize_identifier(
        args.project or str(url_info["default_project"]),
        default="akasha_enum",
    )
    spider_name = sanitize_identifier(
        args.spider or str(url_info["default_spider"]),
        default="akasha",
    )
    if args.brute:
        extraction_mode = "brute"
        pagination_mode = "brute"
    elif args.scrape:
        extraction_mode = "scrape"
        pagination_mode = args.pagination or "auto"
    else:
        extraction_mode = args.mode or str(url_info["default_mode"])
        pagination_mode = args.pagination or str(url_info["default_pagination"])

    seq_start = int(url_info["sequence_number"]) if url_info["sequence_number"] is not None else 1
    min_val = args.min_val if args.min_val is not None else seq_start
    max_val = args.max_val if args.max_val is not None else (min_val + max(1, args.max_pages) - 1)
    pad = args.pad if args.pad is not None else int(url_info["pad_width"])
    next_sel = args.next_selector or 'a[rel="next"]::attr(href), a.next::attr(href), li.next a::attr(href)'

    cfg = SpiderConfig(
        project_name=project_name,
        spider_name=spider_name,
        start_url=str(url_info["normalized_url"]),
        url_template=str(url_info["url_template"]),
        allowed_domain=str(url_info["allowed_domain"]),
        extraction_mode=extraction_mode,
        target_selector=args.selector,
        download_images=extraction_mode in ("images", "full", "scrape", "brute"),
        pagination_mode=pagination_mode,
        next_page_selector=next_sel,
        max_pages=max(1, args.max_pages),
        min_val=min_val,
        max_val=max_val,
        pad=pad,
        download_delay=max(0.0, args.delay),
        concurrent_requests=2,
        respect_robots=bool(args.robots),
        export_format=args.format,
        is_direct_media=bool(url_info["is_media"]),
        detected_sequence_num=url_info["sequence_number"],
        custom_headers=list(args.header),
        user_agent=args.user_agent,
        store_file=args.store,
        delegate_gallerydl=bool(args.download),
        open_browser=bool(args.browser),
    )
    set_active_config(cfg)
    return cfg.project_name, cfg.spider_name, cfg.start_url


def _run_benchmark_workload(iterations):
    """Execute deterministic hot-path URL/filename sanitization and sequence extraction workload."""
    sample_urls = (
        "https://images-pw.pixieset.com/site/B8vK3b/RnMmeP/SOF_1587-b8d3c251-1500.jpg",
        "https://cdn.example.org/gallery/2026/photo_0042.webp?width=1200",
        "https://archive.example.net/articles/deep-dive-part-09.html",
        "https://media.example.com/assets/banner-hero_12-a1b2c3d4.png",
    )
    checksum = 0
    last_name = ""
    last_next = ""
    for i in range(iterations):
        u = sample_urls[i & 3]
        stem = clean_image_stem(u)
        safe = sanitize_storage_name(stem)
        tok = extract_sequence_token(u)
        seq = int(tok[2]) if tok is not None else 0
        nxt = increment_sequence_url(u, step=1, _precomputed_token=tok) or u
        checksum += seq + len(safe)
        last_name = safe
        last_next = nxt
    print(f"BENCH_OK iterations={iterations} checksum={checksum} last_name={last_name} last_next={last_next}")


def main(argv=None):
    if argv is None and len(sys.argv) == 3 and sys.argv[1] == "--benchmark-workload":
        _run_benchmark_workload(int(sys.argv[2]))
        return 0
    project_name, spider_name, start_url = parse_arguments(argv)
    cfg = get_active_config() or _resolve_config(project_name, spider_name, start_url)

    validate_and_create_dir(project_name)
    bootstrap_project_skeleton(project_name)

    define_spider(spider_name, project_name, start_url, config=cfg)
    configure_settings(project_name, config=cfg)
    update_items_py(project_name, config=cfg)
    update_middlewares_py(project_name, config=cfg)
    update_pipelines_py(project_name, config=cfg)
    setup_pyproject_toml(project_name, config=cfg)

    print(f"\n[+] Scaffold complete. Run: cd {project_name} && scrapy crawl {spider_name.lower()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())