#!/usr/bin/env python3
# ==============================================================================
# 4NDR0666OS ARCHITECTURAL ASSEMBLY - MAIN EXECUTION LAYER (prompt_arc.py)
# COMPLETE BOUND CATEGORICAL ROUTING WITH SEPARATED COMPLETERS
# ==============================================================================

import sys
from prompt_toolkit import prompt
from prompt_toolkit.styles import Style
from prompt_toolkit.completion import WordCompleter

from promptlibbeta import (
    PARAMETERS,
    POSE_MANIFEST,
    LIGHTING_PHYSICS_MANIFEST,
    LAYOUT_MANIFEST,
    POSE_COMPLETIONS,
    LIGHTING_COMPLETIONS,
    LAYOUT_COMPLETIONS,
    resolve_tokens
)

style = Style.from_dict({
    "prompt": "fg:#15FFFF bold",
    "header": "fg:#15FFFF bold",
    "hint": "fg:#157d7d italic",
    "output": "fg:#EAEAEA",
    "completion-menu": "bg:#101827 fg:#15FFFF",
    "completion-menu.completion": "bg:#101827 fg:#157d7d",
    "completion-menu.completion.current": "bg:#070B14 fg:#15FFFF bold",
})

# Compile decoupled interface tab completion providers
pose_completer = WordCompleter(POSE_COMPLETIONS, ignore_case=True)
lighting_completer = WordCompleter(LIGHTING_COMPLETIONS, ignore_case=True)
layout_completer = WordCompleter(LAYOUT_COMPLETIONS, ignore_case=True)

def sanitize_tokens(prompt_string):
    from promptlibbeta import MODERATION_BACKOFF_MAP
    for sensitive, fallback in MODERATION_BACKOFF_MAP.items():
        if sensitive in prompt_string.lower():
            prompt_string = prompt_string.replace(sensitive, fallback)
    return prompt_string

def main():
    compiled_prompt = ["[REF_IMG: ingredient]"]
    
    print("\n\033[1;36mInitializing 4NDR0666OS Architectural Assembly (4ndr0pac.sh integrated)...\033[0m\n")
    
    for category, subroutines in PARAMETERS.items():
        print(f"\033[1;33m[ {category.upper()} ]\033[0m")
        for sub, info in subroutines.items():
            
            # Request explicit confirmation for the specific target sub-module
            choice = prompt(f"  Include {sub}? (Concept: {info['layman']}) [y/n]: ", style=style).lower().strip()
            print(f"    \033[3;36mℹ️ Impact: Adjusting '{sub}' controls {info['desc']}.\033[0m")
            
            if choice == 'y':
                # Route 1: Target Identity/Pose parameters strictly to POSE_MANIFEST
                if category == "identity" and "anchor" in sub.lower():
                    user_desc = prompt(f"    Describe stance for {sub} (TAB for manifest / or coords): ", style=style, completer=pose_completer)
                    val = resolve_tokens(user_desc, POSE_MANIFEST)
                
                # Route 2: Target Lighting parameters strictly to LIGHTING_PHYSICS_MANIFEST
                elif category == "lighting_physics":
                    user_desc = prompt(f"    Specify lighting behavior for {sub} (TAB for options): ", style=style, completer=lighting_completer)
                    val = resolve_tokens(user_desc, LIGHTING_PHYSICS_MANIFEST)
                    
                # Route 3: Target Composition parameters strictly to LAYOUT_MANIFEST
                elif category == "composition":
                    user_desc = prompt(f"    Specify composition layout for {sub} (TAB for options): ", style=style, completer=layout_completer)
                    val = resolve_tokens(user_desc, LAYOUT_MANIFEST)
                    
                # Route 4: Fallback for explicit parameters containing standard string values
                else:
                    user_desc = prompt(f"    Set value ({info['vals']}) [preset: {info['preset']}]: ", style=style)
                    val = user_desc if user_desc.strip() else info['preset']
            else:
                # Structural Isolation: Force strict category fallback states to prevent data corruption
                if category == "identity" and "anchor" in sub.lower():
                    val = "0.0,0.0,0.0"
                elif category == "lighting_physics":
                    val = "PHOTONIC_EMISSION_DISABLED"
                elif category == "composition":
                    val = "LAYOUT_AXIS_STANDBY"
                else:
                    val = info['preset']
            
            status = '(INCLUDED)' if choice == 'y' else '(MODIFIED)'
            compiled_prompt.append(f"[{category.upper()}_SUB]: {sub} | VALUE: {val} {status}")
                
    final_output = sanitize_tokens("\n".join(compiled_prompt))
    print(f"\n\033[1;32m[FINAL PROMPT BLOCK]:\033[0m\n{final_output}")

if __name__ == "__main__":
    main()
