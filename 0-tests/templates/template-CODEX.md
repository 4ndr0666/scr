# CODEX.md

## Module: {{module_name}} — {{short_description}}
...
## 📂 Directory Target
**Path:** {{path}}  
**Alias:** {{module_name}}  
**Type:** {{module_type}}  
**Criticality:** {{importance_level}}  
...
## Codex Trigger
Start Codex analysis using:
```bash
codex-review-run --path {{path}} --ruleset CODEX.md --agent AGENTS.md
````

...

## Close Instruction

Begin evaluation of scripts under `{{path}}` immediately.
Stop after 3 scripts unless `CONTINUE` directive is received.
Defer to AGENTS.md for enforcement authority.
No heuristic rewrites permitted outside stated scope.
