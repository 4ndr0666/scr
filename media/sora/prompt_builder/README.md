# AI Image to Video Prompt Builder

A modular, robust toolkit for building platform-compliant, cinematic prompts from *aggregated canonical AI data*—purpose-built for Sora, Hailuo, and next-gen multimodal video AI.  
All prompt logic, options, and blocks are battle-tested for photorealism and creative fidelity.

---

## Components

- **promptlib.py**  
  Canonical Python library for constructing, validating, and chaining prompts.  
  Aggregates all pose, lighting, lens, camera, environment, shadow, micro-detail, and policy blocks.  
  All block-building and orchestration functions included.

- **sora_prompt_builder.sh**  
  Modern CLI for live, variable-driven prompt creation using `promptlib.py`.  
  Features interactive mode, plugin/markdown library loading, validation, and clipboard copying.

- **plugin_loader.py**  
  Utility to extract and categorize prompt blocks from Markdown plugin-packs.  
  Supports legacy null-delimited and new JSON/YAML outputs for extensibility.

---

## Requirements

- **Bash** (for CLI script)
- **Python 3.9+**
- **shellcheck** (for script linting, optional)
- **fzf** (for interactive selection)
- **bat** (optional, pretty Markdown preview)
- **wl-copy** (optional, clipboard integration)
- **prompt_toolkit** (Python; required for interactive mode)

---

## CLI Quick-Reference

| Command                                     | Description                                                   |
|----------------------------------------------|---------------------------------------------------------------|
| `./sora_prompt_builder.sh --interactive`     | Launch full interactive prompt builder (autocompletion)       |
| `./sora_prompt_builder.sh --deakins`         | Add Deakins-style lighting to interactive prompt              |
| `./sora_prompt_builder.sh --plugin FILE.md`  | Load plugin markdown (legacy/interactive prompt selection)    |
| `./sora_prompt_builder.sh --help`            | Show help/usage                                               |

**Tip:** Combine flags for best workflow, e.g.:
`./sora_prompt_builder.sh --interactive --deakins`

---

## Usage

### Interactive Prompt Builder

```bash
./sora_prompt_builder.sh --interactive
````

Options:

* `--deakins` — Insert Deakins-style lighting/mood blocks
* `--plugin <file.md>` — Use plugin prompt library for selection

All menus feature autocompletion. Interactive mode requires `prompt_toolkit` and a real terminal.

---

### Generate a Prompt from Plugin

```bash
./sora_prompt_builder.sh --plugin plugins/prompts1.md
```

Choose a prompt from the plugin library using fzf/fuzzy search. The prompt is copied automatically if `wl-copy` is available.

---

### Library Import (Python)

Use in your own workflow:

```python
from promptlib import prompt_orchestrator
result = prompt_orchestrator(pose_tag="crouching")
print(result["final_prompt"])
```

---

## Plugin Authoring Guide

Extend your prompt library by creating markdown plugins (see `plugins/`).

**Structure:**

* Use blockquotes with double-quotes for each prompt block (legacy-compatible)
* Optionally group blocks under markdown headings for category tagging
* Indent sub-blocks as needed for clarity

**Example:**

```markdown
# My Custom Prompt Plugin

## pose
"leaning_forward
> The model leans subtly forward, posture alert but calm.
> Lens: 85mm f/1.4, shallow DoF.
> Lighting: softbox key at 45° right, gentle fill 135° left.
> Camera: [push in]."

## lighting
"golden_hour
> golden-hour sunlight from 35° camera-left; warm color haze."

## lens
"100mm macro f/2.8, fine detail, shallow depth."

## camera_move
"[truck left]"

## environment
"neutral seamless studio backdrop"

## shadow
"soft, gradual edges"

## detail
"Preserve skin pore texture and catchlights"
```

**How to load your plugin:**

```bash
./sora_prompt_builder.sh --plugin plugins/my_custom_prompts.md --interactive
```

All valid quoted blocks are available for selection, with deduplication and validation.

---

## Validation, Idempotency, and Policy

* All prompt fields and plugin content are deduplicated and validated on load.
* Policy and safety filtering are always enforced at the block level.
* The toolkit is idempotent: re-running or reloading does not create duplicates or invalid state.
* **No placeholders, stubs, or incomplete logic:** all code and prompt data is ready for production use.

---

## Troubleshooting

* If you see missing options in the interactive menu, update `promptlib.py` and reload your plugin packs.
* Interactive mode requires `prompt_toolkit` and a real TTY; check your environment if you see errors.
* For errors about missing fields or policy violations, review your prompt/markdown plugins.

---

## Credits

* Author: 4ndr0666
* Prompt library design and orchestration: \[Your Name/Team]

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

*This toolkit is designed for professional-grade cinematic prompting with AI video generators, and supports prompt-block fusion, micro-detail, and best-practice safety checks. Contribute your own plugins, block libraries, or submit improvements via pull request!*
