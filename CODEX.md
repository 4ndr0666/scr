### `CODEX.md` 

```markdown
# CODEX – Coding & Contribution Standards
_A lightweight companion to `AGENTS.md` focused on code style,
tooling, and commit hygiene._

---

## 1  Language Versions
| Language | Version | Formatter | Linter |
|----------|---------|-----------|--------|
| Bash     | 5.x     | `shfmt -i 4 -ci` | `shellcheck` |
| Python   | 3.11-LTS| `black` (`--line-length 100`) | `ruff` |
| JS/TS    | ES2022  | `prettier` | `eslint` |

---

## 2  Style Primer
* **80/100 column soft wrap** – long strings OK when unavoidable.
* One logical change per commit.
* Prefer **pure functions**; log side-effects explicitly.

---

## 3  Commit Message Template
````

<type>: <scope>: <subject> <BLANK>

<body – what & why>
<BLANK>
Refs: #ticket-id
```
Types: `feat|fix|docs|style|refactor|test|chore`.

---

## 4  Directory-Local `CODEX.md`

Many sub-projects (e.g. `install`, `media`) keep a *local* `CODEX.md`
for runtime specifics (FFmpeg flags, systemd unit patterns, etc.).
Hierarchy:

```
/AGENTS.md  →  /CODEX.md  →  /<subdir>/CODEX.md
(highest)        |               (lowest)
```

The deeper file may **extend** but may *not* weaken parent rules.

---

## 5  Testing

* Bats tests live under `/0-tests/bats`.
* Integration scripts belong in `/scripts/integration_tests.sh`.
* For Python, use `pytest`; for Bash, prefer `bats-core`.

---

## 6  CI Toolchain

| Stage | Tool                                   |
| ----- | -------------------------------------- |
| Lint  | `make lint` (see repo-root `Makefile`) |
| Test  | `make test`                            |
| Build | `make build`                           |
| Docs  | `mkdocs gh-deploy`                     |

---

## 7  Glossary

| Term             | Meaning                                                                 |
| ---------------- | ----------------------------------------------------------------------- |
| **AGENT**        | Human or automated actor operating under AGENTS.md.                     |
| **Bypass**       | Temporary, logged suspension of a hard rule.                            |
| **Task Outcome** | Markdown log describing what an agent finally did or decided not to do. |

````

---

### Updated file-tree snapshot (unchanged structure – marked files updated)

```text
.
├── AGENTS.md   *updated*
├── CODEX.md    *updated*
├── 0-tests
│   ├── CHANGELOG.md
│   └── task_outcome.md
├── 4ndr0tools
│   └── CODEX.md
├── git
│   └── CODEX.md
├── install
│   └── CODEX.md
├── maintain
│   └── CODEX.md
├── media
│   └── CODEX.md
├── security
│   └── CODEX.md
├── systemd
│   └── CODEX.md
└── utilities
    └── CODEX.md
````
