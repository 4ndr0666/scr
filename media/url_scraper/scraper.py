#!/usr/bin/env python3
# scraper.py
# Ψ-4ndr0666 High-Performance Omni-Enumerator (v4.3.0-CERTIFIED)
#
# COHESION & SUPERSET REPORT:
# - Resolved: Terminal freezing and CDN tarpitting by deprecating aria2c subsystem.
# - Enhanced: Integrated gallery-dl as the primary transfer delegate for supreme CDN evasion.
# - Enhanced: Intelligent multi-token URL tokenizer & formatter (isolates zero-padded and
#   primary sequence counters such as `021` and `3381` in Pixieset/CDN URLs like
#   `.../SOF_3381-021-d369bc98-2500.jpg` while excluding hex hashes and resolution suffixes).
# - Enhanced: Direct asset + parent gallery fallback in recursive DOM extraction (`--scrape`)
#   and automatic mode inference when invoked with a single URL.
# - Enhanced: Stdlib urllib/CookieJar async transport fallback when httpx is absent.
# - Enhanced: Pre-compiled regexes & pre-computed probe headers (PF-006 / PF-010 / CWE-1050).
# - Maintained: Unified Post-Exploitation prompt lifecycle & isatty() checks.
# - Maintained: Stateful session tracking (Cookie acquisition via pre-flight).
# - Maintained: Padding mismatch 404/403s via unpadded fallback heuristic.
# - Maintained: Streamed GET WAF evasion & dynamic Referer injection.
# - Maintained: Async context manager lifecycle & core routing.

import argparse
import asyncio
import os
import re
import shutil
import subprocess
import sys
import tempfile
import webbrowser
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urljoin, urlparse, urlsplit, urlunsplit

try:
    import httpx  # type: ignore[import-not-found]
except ImportError:
    httpx = None  # type: ignore[assignment]

BeautifulSoup = None
FeatureNotFound = Exception


def _load_bs4():
    global BeautifulSoup, FeatureNotFound
    if BeautifulSoup is None:
        try:
            from bs4 import BeautifulSoup as _BS, FeatureNotFound as _FNF
            BeautifulSoup = _BS
            FeatureNotFound = _FNF
        except ImportError:
            BeautifulSoup = False
    return BeautifulSoup if BeautifulSoup is not False else None


# --- Pre-compiled Hot-Path Patterns & Static Header Templates (PF-006 / PF-010) ---
_RAW_ASSET_URL_RE = re.compile(
    r'(?:http[s]?://|/)[^\s"\'<>(),;\[\]{}]+?\.(?:jpg|png|gif|webp|jpeg|bmp|svg|avif)',
    re.IGNORECASE,
)
_DIRECT_ASSET_EXT_RE = re.compile(
    r"\.(?:jpg|jpeg|png|gif|webp|bmp|svg|avif|tiff|ico)(?:$|[?#])",
    re.IGNORECASE,
)
_HTML_IMG_SRC_RE = re.compile(
    r'<img\b[^>]*?\b(?:src|data-src|data-original|data-lazy-src)=["\']([^"\']+)["\']',
    re.IGNORECASE,
)
_HTML_A_HREF_RE = re.compile(r'<a\b[^>]*?\bhref=["\']([^"\']+)["\']', re.IGNORECASE)
_STEM_TOKEN_RE = re.compile(r"[A-Za-z0-9]+")
_MIXED_PREFIX_NUM_RE = re.compile(r"^(?P<alpha>[A-Za-z]+)(?P<digits>\d{1,8})$")
_HEX_HASH_RE = re.compile(r"^(?=.*[0-9])(?=.*[a-fA-F])[0-9a-fA-F]{6,}$")
_QUERY_SEQ_KEYS = frozenset(("page", "p", "pg", "offset", "index", "num", "id"))
_COMMON_IMAGE_WIDTHS = frozenset({
    100, 120, 150, 160, 200, 240, 300, 320, 360, 400, 480, 500, 600, 640,
    720, 750, 800, 900, 960, 1000, 1024, 1080, 1200, 1280, 1440, 1500,
    1600, 1800, 1920, 2000, 2048, 2400, 2500, 2560, 3000, 3200, 3840, 4096,
})

_STATIC_PROBE_HEADERS = {
    "Range": "bytes=0-8192",
    "Sec-Fetch-Dest": "image",
    "Sec-Fetch-Mode": "no-cors",
    "Sec-Fetch-Site": "same-origin",
    "Sec-Ch-Ua": '"Google Chrome";v="119", "Chromium";v="119", "Not?A_Brand";v="24"',
    "Sec-Ch-Ua-Mobile": "?0",
    "Sec-Ch-Ua-Platform": '"Windows"',
}


# --- Stdlib Async HTTP Client Fallback (Preserves CookieJar & Streamed Range GET) ---
class _RequestError(Exception):
    """Transport error compatible with httpx.RequestError."""


class _StdlibResponse:
    __slots__ = ("status_code", "text", "url", "headers")

    def __init__(self, status_code: int, text: str, url: str, headers: dict):
        self.status_code = status_code
        self.text = text
        self.url = url
        self.headers = headers

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise _RequestError(f"HTTP {self.status_code} for {self.url}")


class _StdlibStreamContext:
    __slots__ = ("_client", "_method", "_url", "_headers")

    def __init__(self, client: "_StdlibAsyncClient", method: str, url: str, headers: dict):
        self._client = client
        self._method = method
        self._url = url
        self._headers = headers

    async def __aenter__(self) -> _StdlibResponse:
        return await asyncio.to_thread(
            self._client._sync_request,
            self._method,
            self._url,
            self._headers,
            True,
        )

    async def __aexit__(self, exc_type, exc_val, exc_tb) -> None:
        return None


class _StdlibAsyncClient:
    """Stateful CookieJar-backed async HTTP client used when httpx is not installed."""

    def __init__(self, headers: dict, timeout: float = 15.0):
        import urllib.request
        from http.cookiejar import CookieJar
        self.headers = dict(headers)
        self.timeout = timeout
        self.cookie_jar = CookieJar()
        self._opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.cookie_jar)
        )

    def _sync_request(
        self, method: str, url: str, extra_headers: dict | None = None, stream_only: bool = False
    ) -> _StdlibResponse:
        import urllib.error
        import urllib.request
        merged = dict(self.headers)
        if extra_headers:
            merged.update(extra_headers)
        req = urllib.request.Request(url, headers=merged, method=method.upper())
        try:
            with self._opener.open(req, timeout=self.timeout) as resp:
                status = getattr(resp, "status", resp.getcode())
                raw = resp.read(8192) if stream_only else resp.read()
                text = "" if stream_only else raw.decode("utf-8", errors="replace")
                return _StdlibResponse(status, text, url, dict(resp.headers))
        except urllib.error.HTTPError as e:
            return _StdlibResponse(e.code, "", url, dict(e.headers) if e.headers else {})
        except (urllib.error.URLError, OSError, ValueError) as e:
            raise _RequestError(str(e)) from e

    async def get(self, url: str, headers: dict | None = None) -> _StdlibResponse:
        return await asyncio.to_thread(self._sync_request, "GET", url, headers, False)

    def stream(self, method: str, url: str, headers: dict | None = None) -> _StdlibStreamContext:
        return _StdlibStreamContext(self, method, url, headers or {})

    async def aclose(self) -> None:
        return None


_HTTP_REQUEST_ERRORS = (
    (httpx.RequestError, _RequestError) if httpx is not None else (_RequestError,)
)


# --- XDG & Environment Setup ---
def get_xdg_dir(kind: str, fallback: str) -> Path:
    var = f"XDG_{kind.upper()}_HOME"
    return Path(os.environ.get(var, str(Path.home() / fallback)))


XDG_DATA = get_xdg_dir("data", ".local/share/akasha-enum")
XDG_CACHE = get_xdg_dir("cache", ".cache/akasha-enum")
DOWNLOADS_DIR = XDG_DATA / "downloads"
LOG_FILE = XDG_CACHE / "enum.log"

# --- Formatting Constants ---
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[1;32m"
RED = "\033[1;31m"
CYAN = "\033[0;36m"
YELLOW = "\033[0;33m"
MAGENTA = "\033[1;35m"


# --- Intelligent Multi-Token URL Sanitization, Analysis & Formatting ---
def sanitize_input_url(raw_url: str) -> str:
    """Clean a user-supplied URL string (stripping quotes, brackets, and adding https://)."""
    cleaned = (raw_url or "").strip()
    while len(cleaned) >= 2 and (
        (cleaned[0] == cleaned[-1] and cleaned[0] in ('"', "'", "`"))
        or (cleaned[0] == "<" and cleaned[-1] == ">")
        or (cleaned[0] == "(" and cleaned[-1] == ")")
        or (cleaned[0] == "[" and cleaned[-1] == "]")
    ):
        cleaned = cleaned[1:-1].strip()
    if cleaned and cleaned[-1] in ",;":
        cleaned = cleaned.rstrip(",;")
    if not cleaned:
        return "https://www.example.com"
    if not cleaned.startswith(("http://", "https://")):
        cleaned = "https://" + cleaned.lstrip("/")
    return cleaned


def _is_hex_hash_token(token: str) -> bool:
    """Return True if `token` is a hexadecimal content/cache hash (e.g. `d369bc98`, `b8d3c251`)."""
    return len(token) >= 6 and bool(_HEX_HASH_RE.match(token))


def analyze_url_tokens(raw_url: str) -> list[dict]:
    """Extract and classify all candidate sequence tokens in `raw_url`.

    For complex CDN/Pixieset URLs such as:
      `https://images-pw.pixieset.com/site/B8vK3b/PVny4z/SOF_3381-021-d369bc98-2500.jpg`
    accurately:
      - Excludes directory site/collection IDs (`B8vK3b`, `PVny4z`)
      - Excludes hexadecimal content hashes (`d369bc98`, `b8d3c251`)
      - Excludes trailing resolution suffixes (`2500`, `1500`) when preceded by a hash
        or another sequence token
      - Extracts both the zero-padded sequence counter (`021` -> `SOF_3381-{}-d369bc98-2500.jpg`,
        `value=21`, `pad=3`, `is_zero_padded=True`) and the primary camera/file counter
        (`3381` -> `SOF_{}-021-d369bc98-2500.jpg`, `value=3381`, `pad=0`, `width=4`).
    """
    url = sanitize_input_url(raw_url)
    if "{}" in url:
        return [{
            "template": url,
            "token": "{}",
            "value": 1,
            "pad": 0,
            "width": 0,
            "is_zero_padded": False,
            "kind": "explicit",
        }]

    candidates: list[dict] = []
    q_pos = url.find("?")
    f_pos = url.find("#")
    if q_pos != -1:
        parts = urlsplit(url)
        if parts.query:
            q_pairs = parse_qsl(parts.query, keep_blank_values=True)
            for idx, (k, v) in enumerate(q_pairs):
                if k.lower() in _QUERY_SEQ_KEYS and v.isdigit():
                    is_zp = len(v) > 1 and v[0] == "0"
                    q_copy = list(q_pairs)
                    q_copy[idx] = (k, "__BRUTE_SLOT__")
                    new_query = urlencode(q_copy).replace("__BRUTE_SLOT__", "{}")
                    tpl = urlunsplit((parts.scheme, parts.netloc, parts.path, new_query, parts.fragment))
                    candidates.append({
                        "template": tpl,
                        "token": v,
                        "value": int(v),
                        "pad": len(v) if is_zp else 0,
                        "width": len(v),
                        "is_zero_padded": is_zp,
                        "kind": "query",
                    })
        cut = q_pos if (f_pos == -1 or q_pos < f_pos) else f_pos
        base_part = url[:cut]
        tail_part = url[cut:]
    elif f_pos != -1:
        base_part = url[:f_pos]
        tail_part = url[f_pos:]
    else:
        base_part = url
        tail_part = ""

    dir_prefix, sep, basename = base_part.rpartition("/")
    if not basename:
        return candidates

    stem, dot, ext = basename.rpartition(".")
    if not dot:
        stem, ext = basename, ""
    else:
        ext = f".{ext}"

    raw_tokens = []
    for m in _STEM_TOKEN_RE.finditer(stem):
        tok_text = m.group(0)
        start, end = m.span()
        if tok_text.isdigit():
            raw_tokens.append((tok_text, start, end, True, False))
        elif len(tok_text) >= 6 and _HEX_HASH_RE.match(tok_text):
            raw_tokens.append((tok_text, start, end, False, True))
        else:
            mixed = _MIXED_PREFIX_NUM_RE.match(tok_text)
            if mixed:
                alpha_len = len(mixed.group("alpha"))
                digits_str = mixed.group("digits")
                raw_tokens.append((digits_str, start + alpha_len, end, True, False))
            else:
                raw_tokens.append((tok_text, start, end, False, False))

    digit_indices = [i for i, t in enumerate(raw_tokens) if t[3]]
    num_tokens_total = len(raw_tokens)
    num_digit_tokens = len(digit_indices)
    prefix_head = f"{dir_prefix}{sep}" if sep else ""
    suffix_tail = f"{ext}{tail_part}"

    for tok_idx in digit_indices:
        num_str, start, end, _, _ = raw_tokens[tok_idx]
        num_val = int(num_str)

        if tok_idx == num_tokens_total - 1 and num_digit_tokens > 1 and (
            (tok_idx > 0 and raw_tokens[tok_idx - 1][4]) or num_val in _COMMON_IMAGE_WIDTHS
        ):
            continue

        is_zp = len(num_str) > 1 and num_str[0] == "0"
        tpl = f"{prefix_head}{stem[:start]}{{}}{stem[end:]}{suffix_tail}"
        candidates.append({
            "template": tpl,
            "token": num_str,
            "value": num_val,
            "pad": len(num_str) if is_zp else 0,
            "width": len(num_str),
            "is_zero_padded": is_zp,
            "kind": "path",
        })

    return candidates


def infer_brute_template(
    url: str,
    min_val: int | None = None,
    max_val: int | None = None,
    pad: int | None = None,
) -> tuple[str, int, int]:
    """Format a concrete single URL into `(brute_template_url, detected_num, pad_width)`."""
    clean_url = sanitize_input_url(url)
    if "{}" in clean_url:
        return (clean_url, 1, pad or 0)

    candidates = analyze_url_tokens(clean_url)
    if not candidates:
        return (f"{clean_url}{{}}", 1, pad or 0)

    if len(candidates) == 1:
        c = candidates[0]
        resolved_pad = pad if (pad is not None and pad > 0) else (c["pad"] or c["width"] if c["is_zero_padded"] else 0)
        return (c["template"], c["value"], resolved_pad)

    pool = candidates
    if min_val is not None and max_val is not None:
        lo, hi = (min_val, max_val) if min_val <= max_val else (max_val, min_val)
        in_range = [c for c in pool if lo <= c["value"] <= hi]
        if in_range:
            pool = in_range

    if pad is not None and pad > 0:
        pad_matches = [c for c in pool if c["width"] == pad]
        if pad_matches:
            chosen = pad_matches[0]
            return (chosen["template"], chosen["value"], pad)

    zp_matches = [c for c in pool if c["is_zero_padded"]]
    chosen = zp_matches[0] if zp_matches else pool[0]
    resolved_pad = pad if (pad is not None and pad > 0) else chosen["pad"]
    return (chosen["template"], chosen["value"], resolved_pad)


def format_url_for_scraping(
    raw_url: str,
    mode: str = "auto",
    min_val: int | None = None,
    max_val: int | None = None,
    pad: int | None = None,
) -> dict:
    """Inspect and format any user-supplied URL for either `--brute` or `--scrape` execution."""
    clean_url = sanitize_input_url(raw_url)
    concrete_url = clean_url.replace("{}", "1") if "{}" in clean_url else clean_url
    is_asset = bool(_DIRECT_ASSET_EXT_RE.search(concrete_url))
    candidates = analyze_url_tokens(clean_url)
    tpl, det_val, det_pad = infer_brute_template(
        clean_url, min_val=min_val, max_val=max_val, pad=pad
    )

    slash_idx = concrete_url.rfind("/")
    parent_url = concrete_url[: slash_idx + 1] if slash_idx > 8 else concrete_url

    if mode in ("brute", "scrape"):
        rec_mode = mode
    elif "{}" in clean_url or (is_asset and bool(candidates)):
        rec_mode = "brute"
    else:
        rec_mode = "scrape"

    return {
        "clean_url": concrete_url,
        "brute_template": tpl,
        "detected_value": det_val,
        "detected_pad": det_pad,
        "all_candidates": candidates,
        "parent_gallery_url": parent_url,
        "is_direct_asset": is_asset,
        "recommended_mode": rec_mode,
    }


# --- Core Engine ---
class AkashaEnumerator:
    def __init__(self, headers):
        self.headers_dict = {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
            ),
            "Accept": (
                "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,"
                "image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
            ),
            "Accept-Language": "en-US,en;q=0.9",
            "Upgrade-Insecure-Requests": "1",
        }

        for h in headers or []:
            if ":" in h:
                k, v = h.split(":", 1)
                self.headers_dict[k.strip()] = v.strip()

        self._has_custom_referer = any(k.lower() == "referer" for k in self.headers_dict)
        self.client = None
        self.found_urls = set()

    async def __aenter__(self):
        if httpx is not None:
            limits = httpx.Limits(max_keepalive_connections=50, max_connections=100)
            try:
                self.client = httpx.AsyncClient(
                    headers=self.headers_dict,
                    limits=limits,
                    timeout=15.0,
                    follow_redirects=True,
                    http2=True,
                )
            except ImportError:
                self.client = httpx.AsyncClient(
                    headers=self.headers_dict,
                    limits=limits,
                    timeout=15.0,
                    follow_redirects=True,
                    http2=False,
                )
        else:
            self.client = _StdlibAsyncClient(headers=self.headers_dict, timeout=15.0)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.client:
            await self.client.aclose()

    async def _pre_flight(self, target_url: str):
        if not self.client:
            return
        clean_target = sanitize_input_url(target_url).replace("{}", "1")
        parsed = urlparse(clean_target)
        base_target = f"{parsed.scheme}://{parsed.netloc}/"
        try:
            print(
                f"{CYAN}[Ψ] Executing pre-flight request to establish session state...{RESET}"
            )
            await self.client.get(base_target)
        except _HTTP_REQUEST_ERRORS as e:
            print(f"{YELLOW}[-] Pre-flight warning: {e}{RESET}")

    def _build_probe_headers(self, url: str) -> dict:
        request_headers = dict(_STATIC_PROBE_HEADERS)
        if not self._has_custom_referer:
            slash_idx = url.rfind("/")
            request_headers["Referer"] = url[: slash_idx + 1] if slash_idx != -1 else url
        return request_headers

    async def _check_status(self, url: str):
        if not self.client:
            return None
        try:
            request_headers = self._build_probe_headers(url)
            async with self.client.stream("GET", url, headers=request_headers) as resp:
                if resp.status_code in (200, 206):
                    return 200
                return resp.status_code
        except _HTTP_REQUEST_ERRORS:
            return None

    async def _brute_worker(
        self, url_pattern: str, unpadded_url: str, sem: asyncio.Semaphore
    ):
        async with sem:
            status = await self._check_status(url_pattern)
            if status == 200:
                print(f"{GREEN}[+] VALID:{RESET} {url_pattern}")
                self.found_urls.add(url_pattern)
                return

            if status in (404, 403) and url_pattern != unpadded_url:
                alt_status = await self._check_status(unpadded_url)
                if alt_status == 200:
                    print(f"{GREEN}[+] VALID (Unpadded):{RESET} {unpadded_url}")
                    self.found_urls.add(unpadded_url)
                    return
                print(f"{YELLOW}[-] INVALID (HTTP {alt_status}):{RESET} {unpadded_url}")
            elif status:
                print(f"{YELLOW}[-] INVALID (HTTP {status}):{RESET} {url_pattern}")
            else:
                print(f"{RED}[!] TIMEOUT:{RESET} {url_pattern}")

    async def run_brute(self, base_url: str, min_val: int, max_val: int, pad: int):
        base_url = sanitize_input_url(base_url)
        if min_val > max_val:
            min_val, max_val = max_val, min_val

        if "{}" not in base_url:
            base_url, _, inferred_pad = infer_brute_template(
                base_url, min_val=min_val, max_val=max_val, pad=pad
            )
            if pad == 0 and inferred_pad > 0:
                pad = inferred_pad

        print(
            f"\n{CYAN}[Ψ] Initiating Brute-Force Matrix (Range: {min_val}-{max_val}, Padding: {pad}){RESET}"
        )
        print(f"{CYAN}[Ψ] Formatted Target Template: {base_url}{RESET}")

        await self._pre_flight(base_url)

        sem = asyncio.Semaphore(50)
        tasks = [
            asyncio.create_task(
                self._brute_worker(
                    base_url.replace("{}", str(i).zfill(pad) if pad > 0 else str(i)),
                    base_url.replace("{}", str(i)),
                    sem,
                )
            )
            for i in range(min_val, max_val + 1)
        ]

        await asyncio.gather(*tasks)

    def _extract_links_from_html(self, base_url: str, html_text: str) -> set[str]:
        extracted: set[str] = set()
        raw_links: list[str] = []
        bs_cls = _load_bs4()
        if bs_cls is not None:
            try:
                soup = bs_cls(html_text, "lxml")
            except FeatureNotFound:
                soup = bs_cls(html_text, "html.parser")
            for img in soup.find_all("img"):
                for attr in ("src", "data-src", "data-original", "data-lazy-src"):
                    val = img.get(attr)
                    if val:
                        raw_links.append(str(val))
            for source in soup.find_all("source", srcset=True):
                srcset = str(source["srcset"]).split(",")[0].strip().split(" ")[0]
                if srcset:
                    raw_links.append(srcset)
            for meta in soup.find_all("meta"):
                if str(meta.get("property", "")).lower() in ("og:image", "twitter:image"):
                    content = meta.get("content")
                    if content:
                        raw_links.append(str(content))
            for a_tag in soup.find_all("a", href=True):
                raw_links.append(str(a_tag["href"]))
        else:
            raw_links.extend(_HTML_IMG_SRC_RE.findall(html_text))
            raw_links.extend(_HTML_A_HREF_RE.findall(html_text))

        raw_links.extend(_RAW_ASSET_URL_RE.findall(html_text))
        for link in set(raw_links):
            absolute_url = urljoin(base_url, link).split("#", 1)[0]
            if absolute_url.startswith("http"):
                extracted.add(absolute_url)
        return extracted

    async def run_recursive(self, target_url: str):
        formatted = format_url_for_scraping(target_url, mode="scrape")
        clean_url = formatted["clean_url"]
        print(
            f"\n{CYAN}[Ψ] Initiating Recursive DOM Extraction on: {clean_url}{RESET}"
        )
        if not self.client:
            return

        await self._pre_flight(clean_url)

        if formatted["is_direct_asset"]:
            status = await self._check_status(clean_url)
            if status == 200:
                self.found_urls.add(clean_url)
                print(f"{GREEN}[+] EXTRACTED (Direct Asset):{RESET} {clean_url}")
            parent_url = formatted["parent_gallery_url"]
            if parent_url and parent_url != clean_url:
                try:
                    resp = await self.client.get(parent_url)
                    if resp.status_code == 200 and "<html" in resp.text[:1024].lower():
                        for abs_url in sorted(self._extract_links_from_html(parent_url, resp.text)):
                            self.found_urls.add(abs_url)
                            print(f"{GREEN}[+] EXTRACTED:{RESET} {abs_url}")
                except Exception:
                    pass
            return

        try:
            resp = await self.client.get(clean_url)
            resp.raise_for_status()

            content_type = str(resp.headers.get("Content-Type", "") or resp.headers.get("content-type", "")).lower()
            if content_type.startswith("image/"):
                self.found_urls.add(clean_url)
                print(f"{GREEN}[+] EXTRACTED (Direct Image):{RESET} {clean_url}")
                return

            for absolute_url in sorted(self._extract_links_from_html(clean_url, resp.text)):
                self.found_urls.add(absolute_url)
                print(f"{GREEN}[+] EXTRACTED:{RESET} {absolute_url}")

        except Exception as e:
            print(f"{RED}[!] Extraction Failed: {e}{RESET}")


# --- Subsystem Integrations ---
class AkashaIntegrator:
    @staticmethod
    def open_browser(urls):
        if not urls:
            return
        print(f"{CYAN}[Ψ] Injecting {len(urls)} targets into default browser...{RESET}")
        for u in urls:
            webbrowser.open_new_tab(u)

    @staticmethod
    def store_idempotent(urls, filename: str):
        if not urls:
            return
        existing = set()
        if os.path.exists(filename):
            with open(filename, "r", encoding="utf-8") as f:
                existing = {line.strip() for line in f if line.strip()}

        new_urls = set(urls) - existing
        if not new_urls:
            print(f"{YELLOW}[*] Storage: Zero new URLs to append.{RESET}")
            return

        parent_dir = os.path.dirname(os.path.abspath(filename))
        if parent_dir and not os.path.exists(parent_dir):
            os.makedirs(parent_dir, exist_ok=True)

        with open(filename, "a", encoding="utf-8") as f:
            for u in sorted(new_urls):
                f.write(f"{u}\n")
        print(
            f"{GREEN}[+] Storage Complete: Appended {len(new_urls)} assets to {filename}{RESET}"
        )

    @staticmethod
    def delegate_gallerydl(urls, out_dir: Path):
        if not urls:
            return
        if not shutil.which("gallery-dl"):
            print(
                f"{RED}[!] CRITICAL: gallery-dl binary not found in PATH. Download skipped.{RESET}"
            )
            return

        out_dir.mkdir(parents=True, exist_ok=True)
        print(
            f"{CYAN}[Ψ] Delegating bulk transfer to gallery-dl (Target: {out_dir}){RESET}"
        )

        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", delete=False) as tmp:
            for u in sorted(urls):
                tmp.write(f"{u}\n")
            tmp_path = tmp.name

        try:
            cmd = ["gallery-dl", "-i", tmp_path, "-d", str(out_dir)]
            print(f"{MAGENTA}[*] Launching gallery-dl transfer matrix...{RESET}")
            subprocess.run(cmd, check=True, timeout=300)
            print(f"{GREEN}[+] Matrix Download Complete.{RESET}")
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
            print(f"{RED}[!] gallery-dl Subsystem Failure: {e}{RESET}")
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)


# --- Async Orchestrator ---
async def execute_sequence(engine_kwargs, args_obj):
    async with AkashaEnumerator(**engine_kwargs) as engine:
        if args_obj.get("brute"):
            await engine.run_brute(
                args_obj["url"],
                args_obj["min_val"],
                args_obj["max_val"],
                args_obj["pad"],
            )
        else:
            await engine.run_recursive(args_obj["url"])

        return engine.found_urls


# --- Interactive Menu System ---
def interactive_menu(initial_url: str | None = None):
    print(f"\n{MAGENTA}{BOLD}==== Ψ-4NDR0666 OMNI-ENUMERATOR CONSOLE ===={RESET}")
    print(f"{CYAN}Welcome to the interactive reconnaissance matrix.{RESET}\n")

    eof_state = {"reached": False}

    def ask(prompt_str: str, default: str = "") -> str:
        if eof_state["reached"]:
            return default
        try:
            val = input(prompt_str).strip()
            return val if val else default
        except (EOFError, StopIteration):
            eof_state["reached"] = True
            return default

    if initial_url:
        raw_target = initial_url
    else:
        raw_target = ask(
            f"{BOLD}Enter Target URL (e.g., https://example.com/img_{{}}.jpg): {RESET}",
            "https://www.example.com",
        )

    info = format_url_for_scraping(raw_target)
    target = info["clean_url"] if "{}" not in raw_target else sanitize_input_url(raw_target)
    candidates = info["all_candidates"]
    default_choice = "2" if info["recommended_mode"] == "brute" else "1"

    if candidates:
        print(f"{CYAN}[Ψ] Detected URL sequence pattern:{RESET} {info['brute_template']}")
        if len(candidates) > 1:
            for idx, cand in enumerate(candidates, start=1):
                print(
                    f"    Slot {idx}: token='{cand['token']}' (val={cand['value']}, pad={cand['pad']}) -> {cand['template']}"
                )

    print(f"\n{BOLD}Select Operational Mode:{RESET}")
    print(f"  {GREEN}1){RESET} Recursive DOM Extraction (Scrape)")
    print(f"  {GREEN}2){RESET} Sequence Brute-Force (Zero-padded enumeration)")

    mode_choice = ask(f"Choice [1/2, default: {default_choice}]: ", default_choice)

    is_brute = mode_choice == "2"
    default_min = 1 if info["detected_pad"] > 0 else (info["detected_value"] or 1)
    default_max = (default_min + 99) if default_min > 1 else 100
    default_pad = info["detected_pad"]

    min_val, max_val, pad = default_min, default_max, default_pad

    if is_brute:
        try:
            min_val = int(ask(f"Minimum Sequence Value [default: {default_min}]: ", str(default_min)))
            max_val = int(ask(f"Maximum Sequence Value [default: {default_max}]: ", str(default_max)))
            pad = int(ask(f"Zero-padding width (e.g. 3 for 001) [default: {default_pad}]: ", str(default_pad)))
        except ValueError:
            print(f"{RED}[!] Invalid integer input. Aborting.{RESET}")
            sys.exit(1)

        target, _, resolved_pad = infer_brute_template(
            target, min_val=min_val, max_val=max_val, pad=pad
        )
        if pad == 0 and resolved_pad > 0:
            pad = resolved_pad

    print(f"\n{MAGENTA}[*] Launching Engine...{RESET}")

    return {
        "url": target,
        "brute": is_brute,
        "scrape": not is_brute,
        "min_val": min_val,
        "max_val": max_val,
        "pad": pad,
        "store": None,
        "download": False,
        "browser": False,
    }


def _run_benchmark_workload(iterations: int) -> None:
    """Deterministic hot-path benchmark exercising multi-token URL formatting, probe header generation, and regex extraction."""
    enum = AkashaEnumerator(headers=["X-Custom: 1"])
    sample_urls = (
        "https://images-pw.pixieset.com/site/B8vK3b/PVny4z/SOF_3381-021-d369bc98-2500.jpg",
        "https://images-pw.pixieset.com/site/B8vK3b/RnMmeP/SOF_1587-b8d3c251-1500.jpg",
        "https://cdn.example.org/gallery/2026/photo_0042.webp?width=1200",
        "https://media.example.com/assets/banner-hero_12-a1b2c3d4.png",
    )
    sample_html = (
        '<div class="gallery"><img src="/a/pic_01.jpg"><a href="https://cdn.example.com/b/pic_02.webp"></a>'
        '{"hero":"https://images-pw.pixieset.com/site/B8vK3b/PVny4z/SOF_3381-021-d369bc98-2500.jpg"}</div>'
    )
    total = 0
    last_tpl = ""
    for i in range(iterations):
        u = sample_urls[i & 3]
        hdrs = enum._build_probe_headers(u)
        tpl, num, pad = infer_brute_template(u, min_val=1, max_val=100)
        matches = _RAW_ASSET_URL_RE.findall(sample_html)
        total += num + pad + len(hdrs) + len(matches)
        last_tpl = tpl
    print(f"SCRAPER_BENCH_OK iterations={iterations} total={total} template={last_tpl}")


# --- Primary CLI Invocation ---
def main(argv=None):
    effective_argv = sys.argv[1:] if argv is None else argv
    if len(effective_argv) == 2 and effective_argv[0] == "--benchmark-workload":
        _run_benchmark_workload(int(effective_argv[1]))
        return 0

    epilog_text = f"""
{BOLD}EXAMPLES:{RESET}
  {CYAN}1. Direct Single-URL Auto-Format & Enumeration:{RESET}
     python3 scraper.py -u "https://images-pw.pixieset.com/site/B8vK3b/PVny4z/SOF_3381-021-d369bc98-2500.jpg"
     
  {CYAN}2. Zero-Padded Sequence Brute Force (001 to 050):{RESET}
     python3 scraper.py --brute -u "https://target.com/img_{{}}.jpg" --min 1 --max 50 --pad 3 --store valid.txt
     
  {CYAN}3. Stealth Extraction with Custom WAF/Auth Headers:{RESET}
     python3 scraper.py --scrape -u https://target.com -A "Googlebot/2.1" -H "Authorization: Bearer token123"
     
  {CYAN}4. Launch Interactive Console Menu:{RESET}
     python3 scraper.py --menu
"""

    parser = argparse.ArgumentParser(
        description=f"{MAGENTA}{BOLD}Ψ-4ndr0666 High-Performance Omni-Enumerator (v4.3.0-CERTIFIED){RESET}",
        formatter_class=argparse.RawTextHelpFormatter,
        epilog=epilog_text,
    )

    parser.add_argument(
        "positional_url",
        nargs="?",
        help="Optional positional Target URL (auto-formatted for scraping or brute-force)",
    )
    parser.add_argument(
        "-m",
        "--menu",
        action="store_true",
        help="Launch the interactive console menu (Overrides other flags)",
    )
    parser.add_argument(
        "-u",
        "--url",
        type=str,
        help="Target Base URL (supports {} template or any concrete single URL)",
    )

    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument(
        "--brute",
        action="store_true",
        help="Enable sequential zero-padding brute force",
    )
    mode_group.add_argument(
        "--scrape", action="store_true", help="Enable recursive DOM extraction"
    )

    parser.add_argument(
        "--min", type=int, default=None, help="Minimum sequence value (Brute mode)"
    )
    parser.add_argument(
        "--max", type=int, default=None, help="Maximum sequence value (Brute mode)"
    )
    parser.add_argument(
        "--pad", type=int, default=None, help="Zero-padding width (e.g., 3 for 001)"
    )

    parser.add_argument(
        "-H",
        "--header",
        action="append",
        default=[],
        help="Custom headers (Format: 'Key: Value')",
    )
    parser.add_argument("-A", "--user-agent", help="Override default User-Agent")

    parser.add_argument(
        "--browser", action="store_true", help="Open discovered assets in browser"
    )
    parser.add_argument(
        "--store",
        type=str,
        metavar="FILE",
        help="Save discovered assets to file (Idempotent)",
    )
    parser.add_argument(
        "--download",
        action="store_true",
        help="Download assets via gallery-dl subsystem",
    )
    parser.add_argument(
        "--benchmark-workload",
        type=int,
        default=0,
        help=argparse.SUPPRESS,
    )

    if len(effective_argv) == 0:
        if sys.stdin.isatty():
            exec_args = interactive_menu()
            custom_headers = []
        else:
            parser.print_help()
            sys.exit(1)
    else:
        args = parser.parse_args(effective_argv)

        if args.benchmark_workload > 0:
            _run_benchmark_workload(args.benchmark_workload)
            return 0

        custom_headers = list(args.header)
        if args.user_agent:
            custom_headers.append(f"User-Agent: {args.user_agent}")

        raw_url = args.url or args.positional_url
        if args.menu:
            exec_args = interactive_menu(initial_url=raw_url)
        else:
            if not raw_url:
                print(
                    f"{RED}[!] Error: CLI execution requires --url (or positional URL) or --menu.{RESET}"
                )
                sys.exit(1)

            requested_mode = "brute" if args.brute else ("scrape" if args.scrape else "auto")
            url_meta = format_url_for_scraping(
                raw_url,
                mode=requested_mode,
                min_val=args.min,
                max_val=args.max,
                pad=args.pad,
            )
            is_brute = url_meta["recommended_mode"] == "brute"
            resolved_pad = args.pad if args.pad is not None else int(url_meta["detected_pad"])
            if args.min is not None:
                resolved_min = args.min
            elif resolved_pad > 0:
                resolved_min = 1
            else:
                resolved_min = int(url_meta["detected_value"] or 1)
            resolved_max = (
                args.max
                if args.max is not None
                else ((resolved_min + 99) if resolved_min > 1 else 100)
            )
            target_url = (
                url_meta["brute_template"]
                if is_brute
                else url_meta["clean_url"]
            )

            exec_args = {
                "url": target_url,
                "brute": is_brute,
                "scrape": not is_brute,
                "min_val": resolved_min,
                "max_val": resolved_max,
                "pad": resolved_pad,
                "store": args.store,
                "download": args.download,
                "browser": args.browser,
            }

    try:
        found_urls = asyncio.run(
            execute_sequence({"headers": custom_headers}, exec_args)
        )

        if found_urls:
            print(f"\n{CYAN}--- Post-Exploitation Integrations ---{RESET}")
            asset_count = len(found_urls)

            if exec_args.get("store"):
                AkashaIntegrator.store_idempotent(found_urls, exec_args["store"])
            elif sys.stdin.isatty():
                ans = (
                    input(f"{BOLD}Store {asset_count} results to file? [y/N]: {RESET}")
                    .strip()
                    .lower()
                )
                if ans == "y":
                    store_file = (
                        input(
                            f"{BOLD}Enter filename [default: found_urls.txt]: {RESET}"
                        ).strip()
                        or "found_urls.txt"
                    )
                    AkashaIntegrator.store_idempotent(found_urls, store_file)

            if exec_args.get("download"):
                AkashaIntegrator.delegate_gallerydl(found_urls, DOWNLOADS_DIR)
            elif sys.stdin.isatty():
                ans = (
                    input(
                        f"{BOLD}Download {asset_count} assets via gallery-dl? [y/N]: {RESET}"
                    )
                    .strip()
                    .lower()
                )
                if ans == "y":
                    AkashaIntegrator.delegate_gallerydl(found_urls, DOWNLOADS_DIR)

            if exec_args.get("browser"):
                AkashaIntegrator.open_browser(found_urls)
            elif sys.stdin.isatty():
                ans = (
                    input(f"{BOLD}Open {asset_count} assets in browser? [y/N]: {RESET}")
                    .strip()
                    .lower()
                )
                if ans == "y":
                    AkashaIntegrator.open_browser(found_urls)
        else:
            print(f"{YELLOW}[-] Sequence terminated. Zero assets acquired.{RESET}")

    except KeyboardInterrupt:
        print(f"\n{YELLOW}[!] User aborted sequence. Halting event loop.{RESET}")
        sys.exit(130)
    return 0


if __name__ == "__main__":
    main()