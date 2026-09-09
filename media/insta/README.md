# ig_extract

Decode Instagram page source into direct MP4 URLs.

Single-purpose tool: feed it raw encoded text, a saved HTML page, or a URL,
and it prints every extractable video URL — progressive (video+audio) first,
DASH renditions second, anything else the fallback net catches last.

```
ig_extract/
├── README.md
└── ig_extract.py
```

---

## Why this works

Instagram preloads media metadata into the page itself, inside
`<script type="application/json" data-sjs>` Relay payloads. No API calls,
no browser session, no playback emulation — the signed CDN URLs are sitting
in the source, escaped. The entire problem is decoding, not discovery.

## Architecture — two routes, strict order

**Route 1 — structural (primary).** `json.loads` + recursive walk.
JSON parsing resolves `\/`, `\uXXXX`, and surrogate pairs natively, so any
payload that parses needs zero string surgery. The walk extracts:

- `video_versions[]` → progressive MP4s, video+audio in one file.
  `type: 101` is the best rendition; results are sorted by `type` ascending.
- `video_dash_manifest` → parsed as XML; each `<Representation>`'s
  `<BaseURL>` is emitted with its `FBQualityLabel` (360p/540p/720p/1080p,
  plus one audio-only track). DASH tracks are **video-only** or
  **audio-only** — they must be muxed for a playable file (see below).

**Route 2 — fallback net.** Regex over the `_clean()`-normalized raw text.
Catches what JSON parsing rejects: URLs embedded in JS string literals with
escaped colons (`https\u003A\u002F\u002F...`), entity-encoded bodies,
double-encoded `\u00253D` (`%3D`) forms, non-JSON script tags. Deduped
against Route 1, so a fully-parsed payload adds nothing from the net.

**Ordering constraint (enforced in code, not discipline):** `_clean()` is
NEVER applied to text before `json.loads`. `html.unescape()` and the
`\"` → `"` replacement corrupt raw JSON. The clean chain only ever sees
text that has already failed to parse, and its output only feeds the regex
net — never a parser.

### The clean chain

```
html.unescape()                    → &amp; &quot; &#x...;
surrogate pairs decoded FIRST      → \ud83d\ude00 becomes one codepoint
                                     (a naive \uXXXX pass would split the pair
                                      into lone surrogates and crash the UTF-8
                                      write later)
then single \uXXXX                 → \u0026 → &
then \\/ → /  and  \\" → "
```

## Usage

```sh
# raw encoded text, piped (the original use case)
cat blob.txt | python3 ig_extract.py -

# saved page or bare JSON blob
python3 ig_extract.py page.html

# live fetch (session recommended — see Limitations)
python3 ig_extract.py "https://www.instagram.com/stories/user/..." \
    --cookie "sessionid=...; ds_user_id=..."

# also download the best progressive URL
python3 ig_extract.py page.html --save out.mp4
```

Dependencies: **Python 3.10+ standard library only.** `requests` is needed
only for URL-fetch mode and `--save` (`pip install requests`).

## Output legend

```
[progressive type 101 — video+audio]   plays anywhere; this is the one
[dash 1080p — video-only]              needs muxing with the audio track
[dash audio-only — video-only]         the audio half of the DASH pair
[fallback net]                         matched by Route 2 only — inspect
```

Muxing DASH at full quality (both URLs printed by the tool):

```sh
ffmpeg -i video_1080p.mp4 -i audio.mp4 -c copy out.mp4
```

## Limitations

- **Login walls.** Anonymous GETs on story URLs frequently receive the login
  page instead of the payload. `--cookie` (paste your browser's
  `document.cookie`), or save the page from your browser with Ctrl+S and
  feed the file. Saved-DOM beats view-source: View Source shows only the
  initial payload; story data from SPA navigation arrives later via XHR.
- **Signed URLs expire.** The `oe=` query param is a validity timestamp —
  hours, not days. Decode and download in one motion; an archived URL list
  is a ledger, not an archive.
- **DRM is out of scope.** The extraction reads plaintext metadata. EME/
  Widevine content yields nothing, by design of the DRM, not the tool.
- **Private accounts** require a session cookie with access; the tool does
  not authenticate on its own.

## Verification

Reference payload (one 9:16 story, id `3981867390224570853`): Route 1 yields
1 progressive URL (type 101), 4 DASH video renditions (360p/540p/720p/1080p),
1 audio-only track; Route 2 contributes zero extras. All escape layers in the
payload — `\/`, `\u0026`, `\u00253D`, `&amp;` in the DASH XML — resolve
correctly.
