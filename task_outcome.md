This update adds optional foreground execution and a configurable config path to the mem-police daemon. A root privilege check now prevents accidental execution without proper permissions. The changelog and README describe the new options.

Implemented promptlib.py with modular prompt generation functions and a sora_prompt_builder.sh CLI.
Updated sora_prompt_builder.sh to support --copy, --dry-run, and --help flags while fixing the heredoc invocation.
Added --dry-run support to sora_prompt_builder.sh for previewing the Python command before execution.
