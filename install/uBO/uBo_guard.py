#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ubo_guard.py v1.2.0 — uBlock Origin logger & filter-list guard.

Replaces every manual step of the scriptlet-collision workflow (WO-002)
with machine-executed, reproducible commands. Deterministic and idempotent:
same input, same output; re-running never duplicates or drifts.

MODES
  audit     <logger.txt> [--console console.txt]
  generate  <logger.txt> [--out rules.txt] [--merge filters.txt] [--all]
  validate  <filters.txt>
  verify    <logger.txt> --console console.txt [--rules filters.txt] [--strict]

PLAIN-LANGUAGE PRIMER (what the symbols mean)
  ##+js(name, args)  = "inject scriptlet <name> here"   (a filter command)
  #@#+js(name, args) = "do NOT inject here"             (an exception)
  generic rule       = no hostname in front of ## — matches EVERY frame on
                       EVERY site (huge blast radius)
  host-scoped rule   = hostname(s) in front of ## — matches only those hosts
  storage-family     = scriptlet that reads/writes cookies or storage
                       (set-cookie, *cookie*, *storage*) — the only family
                       that can throw "SecurityError: ... sandboxed ..." in
                       an opaque-origin (sandboxed) iframe
  payload-rewriter   = scriptlet that sits BETWEEN the network and the
                       page's parsers and REWRITES response payloads
                       (trusted-replace-outbound-text, trusted-json-edit,
                       json-prune, trusted-replace-fetch-response, ...).
                       Cannot throw sandbox errors, but it CAN corrupt an
                       SSE/JSON stream the app then fails to parse — the
                       "response could not load" failure class (WO-002-R5)

  Logger "info" rows like `[host][name ⁝ arg ⁝ ...] Done|Edited` are
  EXECUTION EVIDENCE: the injected scriptlet ran and what it did. `Done`
  on a storage-family injection proves a clean (non-throwing) run; an
  `Edited` on a payload-rewriter proves a live response rewrite occurred.
  Attribution matches exact URL first, then URL-without-query (telemetry
  endpoints carry per-epoch t=/sid= parameters that differ between
  captures).

LOGGER-EXPORT FIELD SEMANTICS (verified against uBO source: logger-ui.js
parseLogEntry + static-net-filtering.js LogData — WO-002-R4)
  Each exported row = [time] [filter] [marker] [doc-hostname] [partyness]
  [method] [type] [URL]; EMPTY FIELDS ARE SKIPPED by the list export.
  filter present   = that filter matched (its text shown verbatim)
  filter ABSENT    = NO filter matched — uBO did not touch the request
  marker  --       = deny-realm match (a plain network filter => BLOCK;
                     a *$... modifier filter => response MODIFIED, NOT blocked)
  marker  ++       = exception/allow match;  ** = modifier applied;  << = redirect
  partyness 1      = first-party to the tab
  partyness 3      = third-party to the tab;  "3,1" = third-party to the
                     tab but first-party to the frame that requested it
                     (PARTYNESS IS NOT A BLOCK CODE — a row with "3,1" and
                     no filter is an untouched third-party request)

BLOCKED-RESOURCE ATTRIBUTION (the R4 lesson)
  A console "net::ERR_BLOCKED_BY_CLIENT" on a URL whose logger row shows
  NO filter means the block was issued by a NON-uBO client layer: Chrome
  DevTools "Request blocking" patterns (console signature: "Request was
  blocked by DevTools") or another extension. No uBO filter change —
  blocking or exception — can ever restore such a request. Attribution
  BEFORE remediation; never presume a block is uBO's or presume it benign.
"""

import argparse
import re
import sys
from dataclasses import dataclass, field
from typing import List, Optional

TOOL = "ubo_guard v1.2.0 (WO-002-R5)"

# --------------------------------------------------------------------------
# Logger text-export parsing (lenient, format-tolerant)
# --------------------------------------------------------------------------

EPOCH_RE = re.compile(r"^\+\d+$")
URL_RE = re.compile(r"^[a-z][a-z0-9+.\-]*://", re.I)
PARTYNESS_RE = re.compile(r"^\d+(?:[.,]\d+)*$")
HOSTNAME_RE = re.compile(r"^(?:[a-z0-9*-]+\.)*[a-z0-9*-]+(?:\.[a-z0-9*-]+)+$", re.I)

KNOWN_TYPES = {
    "scriptlet", "script", "css", "frame", "xhr", "image", "media", "doc",
    "sub_frame", "websocket", "font", "popup", "other",
}
KNOWN_METHODS = {"get", "post", "head", "options", "put", "delete", "patch", "connect"}


def clean_lines(text: str):
    """Yield meaningful lines; strip markdown/HTML wrappers from pastes."""
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("```"):
            continue
        if ("<details" in line or "</details" in line
                or "<summary" in line or "</summary" in line):
            continue
        yield line


@dataclass
class Entry:
    epoch: str = ""
    filter: Optional[str] = None
    host: Optional[str] = None
    partyness: Optional[str] = None
    method: Optional[str] = None
    rtype: Optional[str] = None
    url: Optional[str] = None
    marker: Optional[str] = None  # uBO result marker: -- / ++ / ** / <<
    extra: List[str] = field(default_factory=list)


def looks_like_filter(s: str) -> bool:
    return ("##+js(" in s or "#@#+js(" in s or "#@#" in s or "##" in s
            or s.startswith("||") or s.startswith("@@")
            or s.startswith("*$") or s.startswith("*$$")
            or s.startswith("$"))


def looks_like_host(s: str) -> bool:
    if "$" in s or "=" in s or "/" in s or ":" in s or "~" in s:
        return False
    return HOSTNAME_RE.match(s) is not None


def parse_logger(text: str) -> List[Entry]:
    """Parse the uBO logger text export into structured entries.

    Source-verified shape (logger-ui.js parseLogEntry): [+NN epoch] then
    the non-empty cells [filter] [marker] [doc-hostname] [partyness]
    [method] [type] URL — URL terminates the entry. Empty cells (no
    filter, no marker, no partyness) are omitted by the list export.
    """
    entries: List[Entry] = []
    buf: List[str] = []
    epoch = ""

    def commit(url: Optional[str]):
        nonlocal buf
        if not buf and url is None:
            return
        e = Entry(epoch=epoch, url=url)
        for item in buf:
            if e.marker is None and item in ("--", "++", "**", "<<"):
                e.marker = item
                continue
            if e.filter is None and looks_like_filter(item):
                e.filter = item
            elif e.rtype is None and item in KNOWN_TYPES:
                e.rtype = item
            elif e.method is None and item in KNOWN_METHODS:
                e.method = item
            elif e.partyness is None and PARTYNESS_RE.match(item):
                e.partyness = item
            elif e.host is None and looks_like_host(item):
                e.host = item
            else:
                e.extra.append(item)
        entries.append(e)
        buf = []

    for line in clean_lines(text):
        if EPOCH_RE.match(line):
            epoch = line
            continue
        if URL_RE.match(line):
            commit(url=line)
            continue
        buf.append(line)
    commit(None)
    return entries


# --------------------------------------------------------------------------
# Scriptlet rule model
# --------------------------------------------------------------------------

@dataclass
class ScriptletRule:
    raw: str
    is_exception: bool
    hosts: List[str]
    name: str
    args_raw: str

    @property
    def generic(self) -> bool:
        return not self.hosts


def parse_scriptlet(text: str) -> Optional[ScriptletRule]:
    m = re.search(r"(#@#|##)\+js\(", text)
    if not m:
        return None
    is_exc = m.group(1) == "#@#"
    prefix = text[:m.start()].strip()
    rest = text[m.end():].rstrip()
    if rest.endswith(")"):
        rest = rest[:-1]
    if "," in rest:
        name, args = rest.split(",", 1)
        name, args = name.strip(), args.strip()
    else:
        name, args = rest.strip(), ""
    hosts = [h.strip() for h in prefix.split(",") if h.strip()] if prefix else []
    return ScriptletRule(raw=text, is_exception=is_exc, hosts=hosts,
                         name=name, args_raw=args)


def token_matches(tok: str, host: str) -> bool:
    """uBO hostname-token match: exact, subdomain-inclusive, or wildcard.

    A trailing `*` swallows ALL remaining labels (uBO entity syntax:
    `google.*` matches google.com AND google.co.uk), so `cdn.*` matches
    cdn.platform.openai.com. This is deliberate uBO semantics.
    """
    tok, host = tok.lower(), host.lower()
    if "*" in tok:
        rx = "^" + re.escape(tok).replace(r"\*", ".*") + "$"
        return re.match(rx, host) is not None
    return host == tok or host.endswith("." + tok)


def rule_applies(hosts: List[str], host: str) -> bool:
    negs = [h[1:] for h in hosts if h.startswith("~")]
    poss = [h for h in hosts if not h.startswith("~")]
    for n in negs:
        if token_matches(n, host):
            return False
    if not poss:
        return True
    return any(token_matches(p, host) for p in poss)


def is_storage_family(name: str) -> bool:
    return "cookie" in name or "storage" in name


# Scriptlets that rewrite response payloads between network and app parsers.
# The SSE/JSON corruption risk family (WO-002-R5).
PAYLOAD_REWRITERS = {
    "trusted-replace-outbound-text",   # wraps TextDecoder.prototype.decode — every stream chunk
    "trusted-json-edit",               # rewrites fetch/XHR JSON bodies
    "json-prune", "json-prune-fetch-response", "json-prune-xhr-response",
    "trusted-replace-fetch-response", "trusted-replace-xhr-response",
    "xml-prune", "evaldata-prune",
}


def is_payload_rewriter(name: str) -> bool:
    return name in PAYLOAD_REWRITERS


# `[host][scriptlet ⁝ arg ⁝ ...] Done|Edited|Error|...` — uBO logger info rows
EXEC_ROW_RE = re.compile(
    r"^\[([^\]]+)\]\[([^\]]+)\]\s*(Done|Edited|Error|\S.*)$")


def parse_exec_rows(text: str) -> List[tuple]:
    """Extract (host, scriptlet-signature, outcome) execution-evidence rows."""
    out = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line.startswith("[") or "⁝" not in line:
            continue
        m = EXEC_ROW_RE.match(line)
        if m:
            out.append((m.group(1).strip(), m.group(2).strip(), m.group(3).strip()))
    return out


# --------------------------------------------------------------------------
# Console capture analysis
# --------------------------------------------------------------------------

THROW_SIGS = ["isolatedScriptlets"]
SANDBOX_SIGS = ["SecurityError", "DOMException", "sandboxed and lacks"]

BLOCKED_URL_RE = re.compile(r"(?:GET|POST)\s+(https?://\S+)\s+net::ERR_BLOCKED_BY_CLIENT")
FETCHFAIL_URL_RE = re.compile(r"(?:POST|GET)\s+request\s+to\s+(https?://\S+?)[\s.]")
DEVTOOLS_SIG = "Request was blocked by DevTools"
CSP_SIGS = ("Refused to execute", "violates the following Content Security Policy")

KNOWN_BENIGN = [
    ("GroupMarkerNotSet", "Chromium software-WebGL deprecation (benign; Chromium internals, embedder canvas)"),
    ("ERR_BLOCKED_BY_CLIENT", "Resource blocked by A CLIENT LAYER — attribution REQUIRED (uBO filter vs DevTools request blocking vs another extension); never presume owner or benignness"),
    ("bazaar/conversation", "OpenAI ads/telemetry endpoint — blocked by design"),
    ("Maximize_Any_Media", "Known open upstream item (G-105): sandbox-safe LS read; already handled by that script's own catch"),
    ("AlwaysNewWindow", "Informational boot banner (no error)"),
    ("Statsig", "Handled fetch() failure (telemetry transport) — owning blocker must be attributed, not presumed benign"),
]


def analyze_console(text: str) -> dict:
    """Parse a Chrome DevTools console capture (.log export or pasted text).

    Extracts, per line family:
      throw_lines    — uBO scriptlet throw signatures (isolatedScriptlets)
      sandbox_lines  — SecurityError / DOMException / sandboxed-storage
      blocked_urls   — resource loads that failed net::ERR_BLOCKED_BY_CLIENT
      devtools_lines — "Request was blocked by DevTools" (the DevTools
                       request-blocking layer; NOT visible to uBO's logger)
      csp_lines      — page-own CSP refusals (embedder-owned, unfixable
                       from any blocker)
      fetchfail_urls — endpoints whose fetch() failed (handled by page JS,
                       e.g. Statsig transport errors)
      classified     — known-family labels (counts only; labels never
                       assert benignness — attribution decides)
    """
    out = {"throw_lines": [], "sandbox_lines": [], "classified": {},
           "blocked_urls": [], "devtools_lines": [], "csp_lines": [],
           "fetchfail_urls": []}
    for line in text.splitlines():
        if any(sig in line for sig in THROW_SIGS):
            out["throw_lines"].append(line.strip())
        if any(sig in line for sig in SANDBOX_SIGS):
            out["sandbox_lines"].append(line.strip())
        if DEVTOOLS_SIG in line:
            out["devtools_lines"].append(line.strip())
        if any(sig in line for sig in CSP_SIGS):
            out["csp_lines"].append(line.strip())
        m = BLOCKED_URL_RE.search(line)
        if m and m.group(1) not in out["blocked_urls"]:
            out["blocked_urls"].append(m.group(1))
        m = FETCHFAIL_URL_RE.search(line)
        if m and m.group(1) not in out["fetchfail_urls"]:
            out["fetchfail_urls"].append(m.group(1))
        for key, label in KNOWN_BENIGN:
            if key in line:
                out["classified"].setdefault(label, []).append(line.strip())
    return out


def attribute_blocks(entries: List[Entry], blocked_urls: List[str]) -> List[tuple]:
    """Attribute each blocked-by-client URL to the layer that blocked it.

    Cross-reference semantics (uBO source, WO-002-R4): a logger network row
    with NO filter text means uBO never touched the request. A console
    ERR_BLOCKED_BY_CLIENT on such a URL is therefore issued by a NON-uBO
    client layer — Chrome DevTools "Request blocking" patterns or another
    extension. Returns (url, verdict, detail) tuples with verdicts:
      UBO-OWNED       — a deny-realm network filter matched (fixable via a
                        mirrored @@ exception in the user's list)
      NOT-UBO         — no filter match; external client layer owns it;
                        NO filter change can restore the request
      UNATTRIBUTED    — no logger row in the captured epochs (logger was
                        not capturing when the request fired)
    """
    rows_by_url = {}
    rows_by_base = {}
    for e in entries:
        if e.url:
            rows_by_url.setdefault(e.url, []).append(e)
            rows_by_base.setdefault(e.url.split("?")[0], []).append(e)
    out = []
    for url in blocked_urls:
        rows = [r for r in rows_by_url.get(url, []) if r.rtype != "scriptlet"]
        matched = "exact"
        if not rows:
            rows = [r for r in rows_by_base.get(url.split("?")[0], [])
                    if r.rtype != "scriptlet"]
            matched = "query-stripped (telemetry params differ per capture)"
        if not rows:
            out.append((url, "UNATTRIBUTED",
                        "no network logger row for this URL in the captured epochs"))
            continue
        plain_blocks = [r for r in rows
                        if r.marker == "--" and r.filter
                        and not r.filter.startswith(("*$", "##", "#@#", "@@"))]
        nofilter = [r for r in rows if not r.filter]
        modifiers = [r for r in rows if r.filter and r.filter.startswith("*$")]
        if plain_blocks:
            out.append((url, "UBO-OWNED",
                        "blocked by uBO filter: %s" % short(plain_blocks[0].filter, 70)))
        elif nofilter:
            note = "logger row(s) show NO filter match — uBO did not touch this request"
            if modifiers:
                note += "; a *$... modifier rule only MODIFIED the response (%s ...)" % short(modifiers[0].filter, 40)
            out.append((url, "NOT-UBO", note))
        elif modifiers:
            out.append((url, "NOT-UBO",
                        "only *$... modifier rows (response modified, never blocked by uBO)"))
        else:
            out.append((url, "NOT-UBO", "no deny-realm filter match on any row"))
    return out


# --------------------------------------------------------------------------
# Reporting helpers
# --------------------------------------------------------------------------

class Report:
    def __init__(self):
        self.lines: List[str] = []
        self.errors = 0
        self.warns = 0
        self.infos = 0

    def line(self, s=""):
        self.lines.append(s)

    def finding(self, sev, msg):
        if sev == "ERROR":
            self.errors += 1
        elif sev == "WARN":
            self.warns += 1
        else:
            self.infos += 1
        self.lines.append("  [%s] %s" % (sev, msg))

    def result(self, exit_code):
        self.line()
        self.line("RESULT: %d error(s), %d warning(s), %d info(s) | EXIT %d"
                  % (self.errors, self.warns, self.infos, exit_code))
        return exit_code

    def dump(self):
        return "\n".join(self.lines)


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def short(url: Optional[str], limit: int = 88) -> str:
    if not url:
        return "-"
    return url if len(url) <= limit else url[:limit - 3] + "..."


# --------------------------------------------------------------------------
# mode: audit
# --------------------------------------------------------------------------

def cmd_audit(args) -> int:
    rep = Report()
    entries = parse_logger(read_text(args.logger))
    cons = analyze_console(read_text(args.console)) if args.console else None

    epochs = []
    for e in entries:
        if e.epoch not in epochs:
            epochs.append(e.epoch)
    scriptlet_rows = [e for e in entries if e.rtype == "scriptlet" and e.filter]
    other_rows = [e for e in entries if e not in scriptlet_rows]

    rep.line("== AUDIT: %s ==" % args.logger)
    rep.line("epochs: %s | entries: %d (scriptlet rows: %d, other rows: %d)"
             % (", ".join(epochs) if epochs else "(none)",
                len(entries), len(scriptlet_rows), len(other_rows)))

    injections, exceptions = [], []
    for e in scriptlet_rows:
        r = parse_scriptlet(e.filter)
        if r is None:
            rep.finding("ERROR", "unparseable scriptlet row: %s" % short(e.filter))
            continue
        (exceptions if r.is_exception else injections).append((e, r))

    rep.line()
    rep.line("SCRIPTLET INJECTIONS (##+js — code injected INTO frames):")
    if not injections:
        rep.line("  (none)")
    seen = {}
    for e, r in injections:
        key = (r.name, r.args_raw, e.host or "(no host)")
        seen.setdefault(key, {"rule": r, "url": e.url, "count": 0})
        seen[key]["count"] += 1
    for (name, sargs, host), info in seen.items():
        tag = "GENERIC (no hostname — matches EVERY frame on EVERY site)" if info["rule"].generic \
            else "scoped: %s" % ",".join(info["rule"].hosts)
        fam = "STORAGE-FAMILY (reads/writes cookies or storage — the family that throws inside sandboxed iframes)" \
            if is_storage_family(name) else "non-storage family (cannot produce the sandboxed-storage error)"
        rep.line("  - %s(%s) -> frame %s [%s] [x%d]" % (name, short(sargs, 60), host, fam, info["count"]))
        rep.line("      source: %s | %s | frame URL: %s" % (tag, "##+js rule", short(info["url"])))

    rep.line()
    rep.line("ACTIVE EXCEPTIONS (#@#+js — injections neutralized on a host):")
    if not exceptions:
        rep.line("  (none)")
    seen_exc = set()
    for e, r in exceptions:
        key = (r.name, r.args_raw, e.host)
        if key in seen_exc:
            continue
        seen_exc.add(key)
        rep.line("  - %s+js(%s) active on frame %s" % ("#@#" if r.is_exception else "##", r.name + (", " + short(r.args_raw, 50) if r.args_raw else ""), e.host))

    # WO-002-R5: payload-rewriter inventory — the stream-corruption family
    rep.line()
    rep.line("PAYLOAD-REWRITER INVENTORY (scriptlets that rewrite response "
             "payloads between network and app parsers):")
    rewriters = [((name, sargs, host), info)
                 for (name, sargs, host), info in seen.items()
                 if is_payload_rewriter(name)]
    if not rewriters:
        rep.line("  (none)")
    else:
        for (name, sargs, host), info in rewriters:
            rep.line("  - %s(%s) -> %s [x%d]"
                     % (name, short(sargs, 60), host, info["count"]))
        rep.finding("WARN",
                    "%d distinct payload-rewriter rule(s) active — these sit between "
                    "the network and the app's stream parsers; a stale regex or an "
                    "overlapping rewrite can corrupt the SSE/JSON stream, which the "
                    "app then fails to parse (the 'response could not load' class). "
                    "A/B test: generate --family payload emits byte-mirrored "
                    "exceptions; or toggle the owning list. Attribute BEFORE "
                    "remediation." % len(rewriters))

    # WO-002-R5: execution-evidence rows (info) — what the injected code DID
    execs = parse_exec_rows(read_text(args.logger))
    rep.line()
    rep.line("SCRIPTLET EXECUTION EVIDENCE (info rows — what injected code DID):")
    if not execs:
        rep.line("  (none)")
    for host, sig, outcome in execs:
        rep.line("  - [%s][%s] %s" % (host, short(sig, 70), outcome))
        if outcome == "Edited":
            rep.finding("WARN",
                        "LIVE REWRITE PROVEN: a payload-rewriter EDITED a response on "
                        "%s — this is not a hypothetical risk in this capture" % host)
        if outcome not in ("Done", "Edited"):
            rep.finding("WARN", "scriptlet execution outcome '%s' (not Done/Edited) "
                        "on %s — inspect the owning list" % (outcome, host))
    exec_ok = {(sig.split(" ⁝ ")[0], host) for host, sig, out in execs
               if out == "Done"}

    if cons:
        rep.line()
        rep.line("CONSOLE CROSS-REFERENCE (%s):" % args.console)
        rep.line("  isolatedScriptlets throw signatures : %d  %s"
                 % (len(cons["throw_lines"]),
                    "<- THE error family" if cons["throw_lines"] else "(clean)"))
        rep.line("  SecurityError/DOMException/sandbox : %d"
                 % len(cons["sandbox_lines"]))
        for label, lns in cons["classified"].items():
            rep.line("  classified x%-3d : %s" % (len(lns), label))
        rep.line("  net::ERR_BLOCKED_BY_CLIENT resources : %d" % len(cons["blocked_urls"]))
        rep.line("  'Request was blocked by DevTools'    : %d  %s"
                 % (len(cons["devtools_lines"]),
                    "<- DevTools request-blocking layer ACTIVE" if cons["devtools_lines"] else "(none)"))
        rep.line("  page-own CSP refusals                : %d" % len(cons["csp_lines"]))
        rep.line("  handled fetch() failures (page JS)   : %d distinct endpoint(s)"
                 % len(cons["fetchfail_urls"]))

    blocked_src = []
    origins = {}
    if cons:
        for u in cons["blocked_urls"]:
            blocked_src.append(u)
            origins[u] = "console"
    if getattr(args, "urls", None):
        for u in [l.strip() for l in read_text(args.urls).splitlines() if l.strip()]:
            if u not in blocked_src:
                blocked_src.append(u)
                origins[u] = "supplied"

    if blocked_src:
        rep.line()
        rep.line("BLOCKED-RESOURCE ATTRIBUTION (console/supplied URLs x logger rows):")
        attrib = attribute_blocks(entries, blocked_src)
        for i, (url, verdict, detail) in enumerate(attrib, 1):
            rep.line("  %d. [%s] %s" % (i, origins.get(url, "?"), short(url, 100)))
            rep.line("     -> %s — %s" % (verdict, detail))
        if cons and cons["devtools_lines"]:
            rep.finding("WARN",
                        "DevTools request-blocking layer ACTIVE (%d console line(s)) — "
                        "patterns live in DevTools > (three-dot menu) > More tools > "
                        "Request blocking; uBO cannot see or undo these blocks"
                        % len(cons["devtools_lines"]))
        not_ubo = [a for a in attrib if a[1] == "NOT-UBO"]
        if not_ubo:
            rep.finding("WARN",
                        "%d blocked resource(s) are NOT uBO blocks (logger shows no "
                        "filter match) — a NON-uBO client layer (DevTools request "
                        "blocking or another extension) owns them; NO uBO filter "
                        "change can restore them" % len(not_ubo))
        ubo_owned = [a for a in attrib if a[1] == "UBO-OWNED"]
        for url, _, detail in ubo_owned:
            rep.finding("WARN",
                        "uBO-owned block (restorable via an @@ exception): %s — %s"
                        % (short(url, 80), detail))

    rep.line()
    rep.line("COVERAGE — storage-family injections lacking an active exception:")
    uncovered = []
    exec_clean = []
    for (name, sargs, host), info in seen.items():
        if not is_storage_family(name):
            continue
        covered = any(x.name == name and x.args_raw == sargs and rule_applies(x.hosts, host)
                      for _, x in exceptions)
        if not covered:
            if (name, host) in exec_ok:
                exec_clean.append((host, name, sargs))
            else:
                uncovered.append((host, name, sargs))
    if exec_clean:
        for host, name, sargs in exec_clean:
            rep.finding("INFO",
                        "storage-family injection %s(%s) into %s executed CLEAN "
                        "('Done' evidence row) — no exception needed"
                        % (name, short(sargs, 50), host))
    # WO-002-R5 scoping: the sandbox throw is only possible in an
    # opaque-origin FRAME. A scriptlet whose frame URL IS a top-level
    # document (rtype=doc rows) runs with full privileges and cannot
    # throw there. NOTE: same-host is NOT sufficient — runner.html is
    # same-host yet opaque-sandboxed (the R2/R3 throw case).
    doc_urls = {e.url for e in entries if e.rtype == "doc" and e.url}
    firstparty = []
    for (name, sargs, host), info in seen.items():
        if not is_storage_family(name):
            continue
        covered = any(x.name == name and x.args_raw == sargs and rule_applies(x.hosts, host)
                      for _, x in exceptions)
        if covered or (name, host) in exec_ok:
            continue
        furl = info["url"] or ""
        if furl in doc_urls:
            firstparty.append((host, name, sargs))
        elif (host, name, sargs) not in uncovered:
            uncovered.append((host, name, sargs))
    uncovered = [u for u in uncovered if u not in firstparty]
    for host, name, sargs in firstparty:
        if (host, name, sargs) not in exec_clean:
            rep.finding("INFO",
                        "storage-family injection %s(%s) runs in a TOP-LEVEL "
                        "document context (frame URL is a doc row — cannot "
                        "produce the sandbox throw; only opaque-origin "
                        "frames can)"
                        % (name, short(sargs, 50)))
    if not uncovered:
        rep.line("  (none — all storage-family injections are covered or executed clean)")
    else:
        for host, name, sargs in uncovered:
            rep.finding("ERROR",
                        "UNCOVERED storage-family injection: %s(%s) into frame %s — "
                        "generate mode emits the host-scoped exception with args mirrored verbatim"
                        % (name, short(sargs, 50), host))

    if cons and cons["throw_lines"] and uncovered:
        rep.line()
        rep.line("CORRELATION (rule-based): the console shows %d isolatedScriptlets "
                 "throw(s); the logger shows %d uncovered storage-family injection(s). "
                 "isolatedScriptlets is uBO's injected-scriptlet wrapper name; storage-family "
                 "scriptlets read document.cookie, which throws exactly this SecurityError "
                 "inside opaque-origin (sandboxed) frames."
                 % (len(cons["throw_lines"]), len(uncovered)))

    exit_code = 1 if (rep.errors or uncovered) else 0
    rep.result(exit_code)
    print(rep.dump())
    return exit_code


# --------------------------------------------------------------------------
# mode: generate
# --------------------------------------------------------------------------

def cmd_generate(args) -> int:
    entries = parse_logger(read_text(args.logger))
    injections, exceptions = [], []
    for e in entries:
        if e.rtype != "scriptlet" or not e.filter:
            continue
        r = parse_scriptlet(e.filter)
        if r is None:
            continue
        (exceptions if r.is_exception else injections).append((e, r))

    family = getattr(args, "family", "storage")
    if getattr(args, "all", False):
        family = "all"
    only = getattr(args, "scriptlet", None)

    def wanted(name: str) -> bool:
        if only:
            return name == only
        if family == "all":
            return True
        if family == "payload":
            return is_payload_rewriter(name)
        return is_storage_family(name)

    print("== GENERATE: %s == (family: %s%s)" % (args.logger, family,
          (", scriptlet: %s" % only) if only else ""))
    rules, skipped = [], 0
    seen = set()
    for e, r in injections:
        host = e.host
        if not host:
            continue
        if not wanted(r.name):
            skipped += 1
            continue
        covered = any(x.name == r.name and x.args_raw == r.args_raw
                      and rule_applies(x.hosts, host) for _, x in exceptions)
        if covered:
            continue
        key = (host, r.name, r.args_raw)
        if key in seen:
            continue
        seen.add(key)
        rules.append("%s#@#+js(%s)" % (host, r.name + (", " + r.args_raw if r.args_raw else "")))

    print("  in-scope injections processed; out-of-scope rows skipped: %d" % skipped)
    print("  active exceptions already in this logger: %d" % len(exceptions))
    print("  rules emitted: %d" % len(rules))
    for rule in rules:
        print("    " + rule)

    if args.merge:
        base = read_text(args.merge)
        existing = {ln.strip() for ln in base.splitlines() if ln.strip()}
        new_rules = [r for r in rules if r not in existing]
        print("  --merge %s: %d rule(s) already present, %d new"
              % (args.merge, len(rules) - len(new_rules), len(new_rules)))
        content = base
        if new_rules:
            if not content.endswith("\n"):
                content += "\n"
            content += "\n! ubo_guard-managed scriptlet exceptions (added %s, idempotent)\n" % TOOL.split(" ")[0]
            for r in new_rules:
                content += r + "\n"
        out_path = args.out or (args.merge if args.out is None else None)
        # default: write merged content to --out (required with --merge)
        if not args.out:
            print("  ERROR: --merge requires --out (refusing to modify input in place)")
            return 2
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(content)
        print("  merged filter list written: %s (%d lines)" % (args.out, content.count("\n") + 1))
    elif args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write("\n".join(rules) + ("\n" if rules else ""))
        print("  rules file written: %s" % args.out)
    print()
    print("RESULT: %d rule(s) emitted | EXIT 0" % len(rules))
    return 0


# --------------------------------------------------------------------------
# mode: validate
# --------------------------------------------------------------------------

STOCK_SCRIPTLETS = {
    "abort-current-script", "abort-event-listener", "abort-fetch",
    "abort-on-iframe-property-read", "abort-on-iframe-property-write",
    "abort-on-property-read", "abort-on-property-write", "abort-on-stack-trace",
    "addEventListener-once", "aopr", "aopw", "aost", "acs",
    "arraybuffer-defuser", "atob-decode-object", "blob-defuser",
    "call-nothrow", "cookie-remover", "delay-defuser", "dir-string",
    "evaldata-prune", "json-prune", "json-prune-fetch-response",
    "json-prune-xhr-response", "log", "noeval", "noeval-if", "nofetch",
    "nofetch-if", "noiframe-if", "noinfinitewhile", "nologgers", "noopen",
    "nopop", "notab", "nowebrtc", "nowebrtc-if", "object-assign",
    "object-define", "object-defineproperties", "object-set-prototype",
    "prevent-addEventListener", "prevent-adfly", "prevent-bab",
    "prevent-canvas", "prevent-clipboard-write", "prevent-document-write",
    "prevent-eval-if", "prevent-fetch", "prevent-fetch-if",
    "prevent-large-media", "prevent-listener", "prevent-location-href",
    "prevent-mousedown-strict", "prevent-newtab-links", "prevent-popups",
    "prevent-refresh", "prevent-setInterval", "prevent-setTimeout",
    "prevent-sharethis", "prevent-splice", "prevent-window-open",
    "prevent-xhr", "prevent-xhr-if", "refresh-defuser", "remove-attr",
    "remove-class", "remove-cookie", "remove-element", "set-attr",
    "set-constant", "set-cookie", "set-cookie-reload",
    "set-local-storage-item", "set-session-storage-item",
    "setInterval-defuser", "setTimeout-defuser", "spoof-css",
    "trusted-abort-current-script", "trusted-abort-on-property-read",
    "trusted-abort-on-property-write", "trusted-click-element",
    "trusted-replace-fetch-response", "trusted-replace-xhr-response",
    "trusted-set-constant", "trusted-set-cookie",
    "trusted-set-local-storage-item", "window-close-if", "xml-prune",
    "xhr-filter", "trusted-json-edit", "trusted-replace-outbound-text",
}

GENERIC_SERVICE_LABELS = {
    "cdn", "static", "assets", "img", "images", "media", "api", "ads", "ad",
    "js", "css", "s", "dl", "download", "files", "file", "tracking",
    "telemetry", "www", "secure", "cdn2", "static2",
}

KNOWN_MODIFIERS = {
    "1p", "3p", "all", "badfilter", "beacon", "cookie", "csp", "css",
    "denyallow", "doc", "document", "domain", "elemhide", "font", "frame",
    "from", "generichide", "genericblock", "gh", "image", "important",
    "match-case", "media", "mp4", "object", "other", "permissions", "ping",
    "popup", "redirect", "redirect-rule", "removeparam", "replace", "script",
    "strict1p", "strict3p", "stylesheet", "subdocument", "to",
    "urltransform", "websocket", "xhr", "first-party", "third-party",
    "speculative", "archive",
}


def cmd_validate(args) -> int:
    rep = Report()
    text = read_text(args.filters)
    raw_lines = text.splitlines()
    rep.line("== VALIDATE: %s ==" % args.filters)
    rep.line("lines: %d" % len(raw_lines))

    seen_lines = {}
    counts = {"rule": 0, "comment": 0, "blank": 0}

    for lineno, raw in enumerate(raw_lines, 1):
        line = raw.strip()
        if not line:
            counts["blank"] += 1
            continue
        if line.startswith("!"):
            counts["comment"] += 1
            continue
        counts["rule"] += 1

        # exact duplicates (uBO dedupes silently — hygiene errors)
        if line in seen_lines:
            rep.finding("ERROR",
                        "L%03d DUPLICATE — identical to L%03d: `%s` "
                        "(uBO ignores the copy silently; remove one)"
                        % (lineno, seen_lines[line], short(line, 70)))
        else:
            seen_lines[line] = lineno

        # scriptlet rules
        sr = parse_scriptlet(line)
        if sr is not None:
            if not re.match(r"^[a-zA-Z0-9-]+$", sr.name or ""):
                rep.finding("ERROR",
                            "L%03d SCRIPTLET-NAME — cannot parse a valid kebab-case "
                            "name from: `%s`" % (lineno, short(line, 60)))
                continue
            if line.count("(") != line.count(")"):
                rep.finding("ERROR",
                            "L%03d UNBALANCED-PARENS — truncated/malformed rule: `%s`"
                            % (lineno, short(line, 60)))
            if sr.is_exception and not sr.hosts:
                rep.finding("ERROR",
                            "L%03d GLOBAL-EXCEPTION — hostless `#@#+js(...)` would "
                            "disable this scriptlet on EVERY site; add a hostname"
                            % lineno)
            if not sr.is_exception and sr.generic:
                rep.finding("WARN",
                            "L%03d GENERIC-SCRIPTLET — hostless `##+js(...)` injects "
                            "into EVERY frame on EVERY site" % lineno)
            if not sr.is_exception:
                wilds = [h for h in sr.hosts if h.endswith(".*") and not h.startswith("~")]
                negs = [h for h in sr.hosts if h.startswith("~")]
                for w in wilds:
                    base = w[:-2]
                    if base in GENERIC_SERVICE_LABELS:
                        rep.finding("WARN",
                                    "L%03d WILDCARD-BREADTH — `%s` matches EVERY "
                                    "`%s.`-prefixed host on every site "
                                    "(e.g. %s.jsdelivr.net, %s.platform.openai.com); "
                                    "rule: %s%s"
                                    % (lineno, w, base, base, base, sr.name,
                                       ("; negations present: " + ",".join(negs) + " (partially mitigated)") if negs else ""))
                    else:
                        rep.finding("INFO",
                                    "L%03d entity wildcard `%s` — broad by design "
                                    "(matches %s.<any-TLD chain>); verify intent"
                                    % (lineno, w, base))
            if sr.name not in STOCK_SCRIPTLETS:
                rep.finding("INFO",
                            "L%03d CUSTOM-SCRIPTLET — `%s` is not in the stock "
                            "scriptlet list; if it is yours, verify the resource "
                            "is defined in your userResourcesLocation bundle"
                            % (lineno, sr.name))
            continue

        # network rules (blocking / exception)
        if "$" in line and (line.startswith("||") or line.startswith("@@")
                            or line.startswith("*") or line.startswith("~")):
            opts = line.split("$", 1)[1]
            for tok in opts.split(","):
                tok = tok.strip()
                if not tok:
                    continue
                base = tok.split("=", 1)[0]
                base = base.lstrip("~")
                if base and base not in KNOWN_MODIFIERS:
                    rep.finding("WARN",
                                "L%03d UNKNOWN-MODIFIER — `$%s` is not in the known "
                                "uBO modifier set (verify against current uBO docs)"
                                % (lineno, tok))
            if line.startswith("@@") and "$all" in line:
                rep.finding("INFO",
                            "L%03d `$all` exception — fully un-blocks this host "
                            "everywhere; confirm intent" % lineno)
            continue

        # cosmetic rules
        if "##" in line:
            sel = line.split("##", 1)[1] if "##" in line else ""
            if not sel:
                rep.finding("ERROR", "L%03d EMPTY-SELECTOR — `##` with no selector" % lineno)
            for proc in (":remove(", ":remove-class(", ":has-text(", ":matches-path(", ":style(", ":if("):
                if proc in line:
                    rep.finding("INFO",
                                "L%03d procedural cosmetic (`%s(...)`) — valid uBO "
                                "extension syntax" % (lineno, proc.strip(":(.")))
                    break
            continue

    rep.line("composition: %d rule(s), %d comment(s), %d blank"
             % (counts["rule"], counts["comment"], counts["blank"]))
    exit_code = 1 if rep.errors else 0
    print(rep.dump())
    return exit_code


# --------------------------------------------------------------------------
# mode: verify
# --------------------------------------------------------------------------

def cmd_verify(args) -> int:
    rep = Report()
    entries = parse_logger(read_text(args.logger))
    cons = analyze_console(read_text(args.console))
    rules_text = read_text(args.rules) if args.rules else ""

    print("== VERIFY: %s ==" % args.logger)
    print("  console: %s | rules: %s | strict: %s"
          % (args.console, args.rules or "(not checked)", bool(args.strict)))

    injections, exceptions = [], []
    for e in entries:
        if e.rtype != "scriptlet" or not e.filter:
            continue
        r = parse_scriptlet(e.filter)
        if r is None:
            continue
        (exceptions if r.is_exception else injections).append((e, r))

    checks = []

    # C1: zero throw signatures in console
    n_throw = len(cons["throw_lines"])
    checks.append(("C1  console has 0 isolatedScriptlets throw signatures",
                   n_throw == 0, "found %d: %s" % (n_throw, short(cons["throw_lines"][0], 60) if cons["throw_lines"] else "")))

    # C1b (strict): no SecurityError/DOMException/sandbox at all
    if args.strict:
        n_sandbox = len(cons["sandbox_lines"])
        checks.append(("C1+ console has 0 SecurityError/DOMException/sandbox lines (strict)",
                       n_sandbox == 0, "found %d" % n_sandbox))

    # C2: every storage-family injection covered by an active exception
    uncovered = []
    for e, r in injections:
        if not is_storage_family(r.name):
            continue
        host = e.host or ""
        covered = any(x.name == r.name and x.args_raw == r.args_raw
                      and rule_applies(x.hosts, host) for _, x in exceptions)
        if not covered:
            uncovered.append((host, r.name, r.args_raw))
    checks.append(("C2  every storage-family injection is covered by an active exception",
                   not uncovered, "uncovered: %s" % (uncovered or "none")))

    # C3: every active exception exists in the live rules file
    missing_in_file = []
    if args.rules:
        for e, r in exceptions:
            needle = "#@#+js(%s)" % (r.name + (", " + r.args_raw if r.args_raw else ""))
            if needle not in rules_text:
                missing_in_file.append(needle)
        checks.append(("C3  every active exception exists in the filter list file",
                       not missing_in_file, "missing: %s" % (missing_in_file or "none")))

    # C5 (WO-002-R5, informational): payload-rewriter family active on any host
    rewriters = sorted({(r.name, e.host or "") for e, r in injections
                        if is_payload_rewriter(r.name)})
    print()
    print("  C5 payload-rewriter scriptlets active (stream-editing family): %d"
          % len(rewriters))
    for name, host in rewriters:
        print("    %s on %s" % (name, host))
    if rewriters:
        print("    -> these rewrite response payloads between network and app; if the")
        print("       site fails to parse responses ('response could not load'), A/B")
        print("       test them (audit -> generate --family payload -> import -> reload).")

    # informational: remaining (protective) injections + classified console noise
    protective = sorted({r.name for _, r in injections if not is_storage_family(r.name)})
    print()
    print("  active exceptions observed in logger : %d" % len(exceptions))
    for e, r in exceptions:
        print("    #@#+js(%s) on frame %s" % (r.name + (", " + r.args_raw if r.args_raw else ""), e.host))
    print("  remaining (non-storage) injections   : %s — protective, kept by design"
          % (", ".join(protective) if protective else "(none)"))
    if cons["classified"]:
        print("  console lines classified benign:")
        for label, lns in cons["classified"].items():
            print("    x%-3d %s" % (len(lns), label))

    # C4 (WO-002-R4): blocked-resource attribution — external blocker detection.
    # Informational by design: it is NOT a filter-side regression, so it does
    # not gate the exit code — but it is printed loudly when active.
    attrib = attribute_blocks(entries, cons["blocked_urls"])
    not_ubo = [a for a in attrib if a[1] == "NOT-UBO"]
    ubo_owned = [a for a in attrib if a[1] == "UBO-OWNED"]
    unattrib = [a for a in attrib if a[1] == "UNATTRIBUTED"]
    print()
    print("  C4 blocked-resource attribution (external client-blocker detection):")
    print("    blocked resources in console                 : %d" % len(cons["blocked_urls"]))
    print("    ... UBO-OWNED (filter restorable via @@)     : %d" % len(ubo_owned))
    print("    ... NOT-UBO (external layer owns the block)  : %d" % len(not_ubo))
    print("    ... UNATTRIBUTED (no logger row in capture)  : %d" % len(unattrib))
    print("    'Request was blocked by DevTools' lines      : %d" % len(cons["devtools_lines"]))
    for url, verdict, detail in not_ubo:
        print("      NOT-UBO: %s" % short(url, 92))
    if cons["devtools_lines"] or not_ubo:
        print("    -> EXTERNAL-BLOCKER ACTIVE: the uBO side is NOT the owner of these")
        print("       blocks. Clear DevTools > (three-dot menu) > More tools > Request")
        print("       blocking patterns (and/or toggle-test extensions one by one).")
        print("       No uBO filter change can restore these requests.")

    print()
    ok = True
    for desc, passed, detail in checks:
        rep.line("  [%s] %s%s" % ("PASS" if passed else "FAIL", desc,
                                  (" — " + detail) if detail else ""))
        ok = ok and passed
    exit_code = 0 if ok else 1
    rep.line()
    rep.line("VERDICT: %s | EXIT %d" % ("PASS — end-to-end acceptance criteria met" if ok else "FAIL", exit_code))
    print(rep.dump())
    return exit_code


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def main(argv):
    ap = argparse.ArgumentParser(prog="ubo_guard", description=TOOL)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("audit", help="parse a logger export; classify injections")
    p.add_argument("logger")
    p.add_argument("--console")
    p.add_argument("--urls",
                   help="file with one URL per line to attribute against the logger "
                        "(e.g. a network-tab list of blocked requests)")

    p = sub.add_parser("generate", help="emit exception rules (args mirrored verbatim)")
    p.add_argument("logger")
    p.add_argument("--out")
    p.add_argument("--merge")
    p.add_argument("--all", action="store_true",
                   help="emit exceptions for EVERY injection (all families)")
    p.add_argument("--family", choices=["storage", "payload"], default="storage",
                   help="which family to emit exceptions for (default: storage; "
                        "payload = the response-stream rewriters, WO-002-R5)")
    p.add_argument("--scriptlet", help="emit exceptions only for this scriptlet name")

    p = sub.add_parser("validate", help="static analysis of a filter list")
    p.add_argument("filters")

    p = sub.add_parser("verify", help="end-to-end acceptance check")
    p.add_argument("logger")
    p.add_argument("--console", required=True)
    p.add_argument("--rules")
    p.add_argument("--strict", action="store_true")

    args = ap.parse_args(argv)

    if args.cmd == "audit":
        return cmd_audit(args)
    if args.cmd == "generate":
        return cmd_generate(args)
    if args.cmd == "validate":
        return cmd_validate(args)
    if args.cmd == "verify":
        return cmd_verify(args)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
