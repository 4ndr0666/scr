### `AGENTS.md`

```markdown
# AGENTS Policy & Run-book
_One source of truth for every human or automated agent interacting with this
repository.  If a rule conflicts with local `CODEX.md` files, **this file wins.**_

---

## 1  Goals & Guarantees
| Goal | Guarantee |
|------|-----------|
| **Safety** | No action can destroy data, bypass tests, or ship merge artefacts. |
| **Reproducibility** | All tasks are logged, deterministic, and XDG-compliant. |
| **Traceability** | Every change – even one-line edits – is linked to a test, changelog entry, and task-outcome note. |

---

## 2  Scope & Permissions
1. **Default read-only.** Agents must request scope explicitly.  
2. **Recursive rules**  
   * If a _directory_ is named, the entire subtree is in scope.  
   * If a _glob_ is used (`*.sh`), only matching paths inside the given scope are touched.

---

## 3  Environment Rules
| Category | Rule |
|----------|------|
| **XDG** | Resolve `$XDG_*` variables first; _fallback_ to:<br>`$XDG_DATA_HOME → ~/.local/share`, etc. |
| **Shell** | Target `bash` ≥ 5 or `zsh` ≥ 5 unless task states otherwise. |
| **Temp files** | Create under `$XDG_RUNTIME_DIR` and auto-clean. |

---

## 4  Change-Management Pipeline
1. **Dry-run + lint** (`shellcheck`, `shfmt -d`, `eslint`, or language-specific).  
2. **Unit / bats / integration tests**  
3. **`codex-merge-clean.sh`** – removes merge markers; fails build if any remain.  
4. **Update `/0-tests/CHANGELOG.md`** – _every_ change (single-file included) with:  
```

yyyy-mm-dd • <file> • <±LOC> • <summary>

````
5. **Append outcome** to `/0-tests/task_outcome.md`.

---

## 5  Bypasses & Exceptions
If a policy _must_ be bypassed (e.g. technical blocker):
```text
1. Add an inline `# AGENT-BYPASS:<reason>` comment.
2. Record the rationale + affected lines in CHANGELOG.
3. Summarise in task_outcome.md.
````

Automation halts until a human reviewer clears the entry.

---

## 6  Escalation Protocol

When an agent cannot decide safely, it must:

1. Stop further edits.
2. Write a concise **numerical decision list** in `task_outcome.md`.
3. Ping the human reviewer.

---

## 7  Test-Coverage Gaps

If a script cannot be fully tested:

* Document why in `task_outcome.md`.
* Mark the code with `# NO-TEST:<reason>`.

---

## 8  Termination Conditions

| Condition              | Action                                         |
| ---------------------- | ---------------------------------------------- |
| Merge artefacts remain | **Fail CI**, log offending files, abort merge. |
| Lint / tests fail      | Same as above.                                 |
| Undocumented bypass    | Reject commit, require escalation.             |

---

## 9  Quick Reference

| Area         | Hard Rule                                     |
| ------------ | --------------------------------------------- |
| XDG fallback | Always provide `${VAR:-default}`              |
| Glob / Dir   | Dir → recursive, Glob → explicit matches only |
| Changelog    | *Every* commit, even 1-line                   |
| Bypass       | Inline tag + logs + halt                      |
| Escalation   | Numerical list in `task_outcome.md`           |
| Merge clean  | Block on remaining artefacts                  |
| Test gaps    | Document & annotate                           |

````
