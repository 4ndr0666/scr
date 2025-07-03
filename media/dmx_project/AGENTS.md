# 🗂️ **AGENTS.md — Operational Orchestration Charter for DMX V2**

> **Purpose**
> This document transforms the high-level **CODEX.md** work-order into a concrete *people & automation matrix*.
> It names every **Agent** (human role *or* CI bot), maps them to the tickets (**DMX-101 → DMX-110**), defines explicit hand-offs, SLAs, approval gates, and telemetry hooks.
> Treat it as the living control-plane for day-to-day execution, retrospectives, and future onboarding.

---

## 1 Agent Roster & Mandates

| Agent ID         | Persona (real / bot)                | Core Mandate                                          | Key Artefacts Produced            |
| ---------------- | ----------------------------------- | ----------------------------------------------------- | --------------------------------- |
| **A-Lead**       | *Tech-Lead* (human)                 | Scope policing, architecture sign-off, unblocker      | §2 Sprint Boards, ADRs            |
| **A-Backend**    | *Dev* squad                         | Python code, refactors, path migration logic          | PRs tagged `backend`, unit tests  |
| **A-Frontend**   | *TUI/UX* dev                        | Colour overhaul, prompt\_toolkit tweaks, help banners | CSS/ANSI palettes, screenshots    |
| **A-Docs**       | *Tech-writer*                       | README, man-page, CHANGELOG, diagrams                 | Markdown, PNG assets              |
| **A-CI**         | *GitHub Actions bot*                | Build, test, lint, colour snapshots                   | CI logs, artefact bundles         |
| **A-QA**         | *QA-analyst*                        | Manual matrix tests, TestRail reports                 | QA verdicts, defect tickets       |
| **A-SecOps**     | *Security engineer*                 | SBOM, plugin trust review, OpenSCAP scan              | CycloneDX JSON, risk memo         |
| **A-ReleaseEng** | *Release manager*                   | Version bump, tagging, PyPI publish                   | Release notes, signed tarballs    |
| **A-Perf**       | *Perf-team bot* (hyperfine wrapper) | Speed/memory regression dashboards                    | HTML trend reports                |
| **A-UXBot**      | Axe-CLI wrapper                     | WCAG AA colour-contrast audit                         | JSON reports, accessibility badge |

*Slack handles:* `@lead`, `@be`, `@fe`, `@docs`, `@qa`, `@sec`, `@rel`, `@perf`, `@uxbot`

---

## 2 Ticket → Agent Responsibility Matrix

| Ticket  | Primary Agent    | Review Agent(s)  | CI Checks Triggered               |
| ------- | ---------------- | ---------------- | --------------------------------- |
| DMX-101 | **A-Backend**    | A-QA, A-Docs     | `pytest::test_batch_enhance_stub` |
| DMX-102 | **A-Backend**    | A-Frontend, A-QA | `pytest::test_menu_paths`         |
| DMX-103 | **A-Backend**    | A-SecOps, A-QA   | `pytest::test_cfg_precedence`     |
| DMX-104 | **A-Frontend**   | A-UXBot, A-Docs  | `ci/colour-diff.yml`, `axe-cli`   |
| DMX-105 | **A-ReleaseEng** | A-Backend, A-CI  | `semrel` dry-run                  |
| DMX-106 | **A-Docs**       | A-Frontend, A-QA | `markdownlint`, link-checker      |
| DMX-107 | **A-Backend**    | A-CI             | coverage gate ≥ 90 %              |
| DMX-108 | **A-CI**         | A-Frontend       | snapshot diff size < 1 KB         |
| DMX-109 | **A-SecOps**     | A-Backend        | `trivy`, SBOM diff                |
| DMX-110 | **A-QA**         | A-Lead           | All gates green ✔︎                |

> **Hand-off rule:** a ticket is *Definition-of-Done* only when the **Review Agent** merges the PR and the downstream CI stage passes. A-Lead is final arbiter on contentious merges.

---

## 3 Sprint Cadence & Rituals

| Ceremony                       | Cadence                             | Participants            | Artefact             |
| ------------------------------ | ----------------------------------- | ----------------------- | -------------------- |
| **Sprint Planning**            | bi-weekly (Mon 10:00 CST)           | All                     | Updated §2 matrix    |
| **Daily Stand-up**             | async Slack thread `#dmx-v2-launch` | All agents              | 3-bullet status      |
| **Bug Triage**                 | Tue/Thu 15:00 CST                   | A-Lead, A-Backend, A-QA | Triage board         |
| **Colour Snapshot Review**     | On every DMX-104 commit             | A-Frontend, A-UXBot     | `gh-pages/ansi.html` |
| **Security Sync**              | Friday 13:00 CST                    | A-SecOps, A-Backend     | Risk log             |
| **Release Candidate Go/No-Go** | Sprint end                          | A-Lead + all reviewers  | Sign-off sheet       |

---

## 4 SLAs & KPI Targets

| Metric                     | Target    | Agent Owner   | Measurement      |
| -------------------------- | --------- | ------------- | ---------------- |
| **PR review latency**      | ≤ 24 h    | All reviewers | GitHub Insights  |
| **Unit test coverage**     | ≥ 90 %    | A-Backend     | `coverage xml`   |
| **WCAG contrast**          | Pass (AA) | A-UXBot       | axe-cli score    |
| **Security criticals**     | 0         | A-SecOps      | Trivy CVE report |
| **CI pipeline duration**   | ≤ 8 min   | A-CI          | GH Actions stats |
| **Performance regression** | ± 5 %     | A-Perf        | hyperfine delta  |

---

## 5 Automation Hook Map

| Hook                | Trigger                         | Script / Path                                             | Responsible Agent |
| ------------------- | ------------------------------- | --------------------------------------------------------- | ----------------- |
| **pre-commit**      | `git commit`                    | `.pre-commit-config.yaml` → `ruff`, `black`, `shellcheck` | A-CI              |
| **colour-snapshot** | Push touching `ui/` or `style/` | `.github/workflows/colour-diff.yml`                       | A-CI              |
| **coverage-gate**   | All PRs                         | `pytest --cov`                                            | A-CI              |
| **security-scan**   | Nightly                         | `.github/workflows/trivy.yml`                             | A-SecOps          |
| **perf-bench**      | Weekly                          | `perf/run_bench.sh`                                       | A-Perf            |

---

## 6 Directory Conventions

```
dmx/
├── src/
│   ├── backend/        # core modules
│   └── tui/            # colour, prompt_toolkit
├── docs/
│   ├── assets/
│   └── CHANGELOG.md
├── tests/
│   ├── unit/
│   └── regression/
└── infra/
    ├── docker/
    ├── ci/
    └── sbom/
```

---

## 7 Leaderboard & Definitive-Function Ledger  *(“War Game” rules)*

* File **`scr/0-tests/LEADERBOARD.md`** tracks each round:

  ```markdown
  | Date | Function | Winner | Score |
  |------|----------|--------|-------|
  | 2025-07-02 | tmpf() | @andrew (user) | 1-0 |
  ```
* **A-Lead** updates “definitive” function versions in **`scr/0-tests/definitive/`** after mutual agreement.

---

## 8 Escalation & Risk Management

* Red build for > 2 h → **A-CI** pages **A-Backend** via Slack `#alerts`.
* CVSS ≥ 9 detected → **A-SecOps** triggers immediate hot-fix branch.
* Colour contrast fail → blocks merge (required check).

---

## 9 Future Role Expansions (road-map preview)

| Future Agent       | Trigger          | Scope                      |
| ------------------ | ---------------- | -------------------------- |
| **A-Marketplace**  | post-V2          | Plugin repository curation |
| **A-Localisation** | i18n sprint      | Translation workflow       |
| **A-Telemetry**    | opt-in analytics | Usage dashboards           |

---

## 10 Appendices

### 10-A Colour Tokens

| Token      | RGB                   | ANSI                    |
| ---------- | --------------------- | ----------------------- |
| `CYAN`     | `#15FFFF`             | `\033[38;2;21;255;255m` |
| `BG_BLACK` | `#000000`             | `\033[40m`              |
| `RED`      | `#FF3333` (unchanged) | `\033[31m`              |
| `BOLD`     | —                     | `\033[1m`               |
| `DIM`      | —                     | `\033[2m`               |

### 10-B Feature Index ↔ Ticket Mapping

See §2 matrix for authoritative linkage.

### 10-C Sign-off Sheet Template

```
Ticket: ___________
Dev Owner: ___________
Reviewer: ___________
CI Build #: ___________
Unit Coverage Δ: _____
QA Verdict: [PASS/FAIL]
Date: __ / __ / 2025
```

---

**Document Version:** AGENTS-v2.0-draft-1 (2025-07-03)
Maintainer: **A-Lead** (`@lead`) – amendments via PR only.
