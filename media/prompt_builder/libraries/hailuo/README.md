# Hailuo Parameter Library

This directory contains the canonical parameter lists used by the prompt builder.
All values are sourced directly from official Hailuo documentation.

## Usage Examples

Load parameters using the canonical loader:

```python
from canonical_loader import load_canonical_params
loader = load_canonical_params("/media/prompt_builder/libraries/hailuo/")
options = loader.get_param_options("lighting")
```

Load a prompt plugin and assemble a prompt block:

```python
from plugin_loader import load_prompt_plugin_categorized
from canonical_loader import load_canonical_params
from pathlib import Path

loader = load_canonical_params("/media/prompt_builder/libraries/hailuo/")
plugin = load_prompt_plugin_categorized(Path("plugins/hailuo_prompts1.md"))

example = {
    "subject": "adult female, frontal, neutral expression",
    "age_tag": "adult",
    "gender_tag": "female",
    "action_sequence": "waves to camera",
    "camera_moves": ["[push in]"],
    "lighting": loader.get_param_options("lighting")[0],
    "lens": loader.get_param_options("lens")[0],
    "environment": loader.get_param_options("environment")[0],
    "shadow": loader.get_param_options("shadow")[0],
    "detail": loader.get_param_options("detail")[0],
}
prompt = loader.assemble_prompt_block(example)
print(prompt)
```

## Available Parameter Lists

- `subject_reference.md`
- `face_count.md`
- `age_group.md`
- `gender.md`
- `expression.md`
- `orientation.md`
- `pose_tag.md`
- `camera_movement.md`
- `camera_shot-framing.md`
- `lens_and_depth-of-field.md`
- `lighting_style.md`
- `background_environment.md`
- `shadow_quality.md`
- `detail_micro-emphasis.md`
- `action_sequence.md`

Each file documents the valid values for its respective parameter.

## Authoring a Plugin Pack

Plugins extend the base library with additional prompt blocks. Create a markdown
file with headings matching the categories (`pose`, `lighting`, `lens`,
`camera_move`, `environment`, `shadow`, `detail`). Under each heading, quote each
block with double quotes:

```markdown
## pose
"leaning_forward
> The model leans forward slightly."
```

Load your plugin with `plugin_loader.py` or pass it to `prompts.sh --plugin`.

## Integration Points

- **CLI**: `prompts.sh` uses `canonical_loader.py` and `plugin_loader.py` for
  validation and selection.
- **API/UI**: Import `canonical_loader.py` to fetch canonical lists and validate
  incoming values. Plugins can be loaded at runtime using `plugin_loader.py`.

