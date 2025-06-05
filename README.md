# Cinematic Prompt Tools

This repository provides utilities for generating cinematic pose prompts for image and video models.

## Components

- **promptlib.py** – Python library with helper functions for constructing and evaluating prompts.
- **sora_prompt_builder.sh** – Command line interface that uses `promptlib.py` to create prompts.

## Requirements

- Bash and `shellcheck` for linting scripts
- Python 3.9 or higher
- Optional: `prompt_toolkit` and `wl-copy` for interactive mode and clipboard support

## Usage

### Generate a Prompt

```
./sora_prompt_builder.sh --pose crouching
```

### Interactive Mode

```
./sora_prompt_builder.sh --interactive
```

This mode offers autocompletion for pose tags and copies the final prompt to the clipboard when `--copy` is supplied.
Interactive mode requires the optional `prompt_toolkit` Python package and must be run from a terminal. If `prompt_toolkit` is missing, the script will exit with an explanatory message.

### Library Functions

Import the library in your Python code:

```python
from promptlib import prompt_orchestrator
result = prompt_orchestrator(pose_tag="crouching")
print(result["final_prompt"])
```

