#!/usr/bin/env python3
# ==============================================================================
# 4NDR0666OS ARCHITECTURAL ASSEMBLY - HDL V8.0 COMPILER (prompt_arc.py)
# NATIVE TRANSPILATION OF CATEGORICAL ROUTING TO HYPER-DIRECTIVE SYNTAX
# PATCHED: KINETIC ASSIGNMENT RELOCATED, HARDCODES ASSIMILATED, FORMAT REFINEMENT
# ==============================================================================

import sys
import subprocess
from prompt_toolkit import prompt
from prompt_toolkit.styles import Style
from prompt_toolkit.completion import WordCompleter
from promptlib import (
    PARAMETERS,
    FLAT_POSE_INDEX,
    FLAT_LIGHTING_INDEX,
    FLAT_LAYOUT_INDEX,
    FLAT_STYLE_INDEX,
    MULTI_PANEL_DEFINITIONS,
    POSE_COMPLETIONS,
    LIGHTING_COMPLETIONS,
    LAYOUT_COMPLETIONS,
    STYLE_COMPLETIONS,
    MODERATION_BACKOFF_MAP,
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

COMPLETERS = {
    "pose": WordCompleter(list(POSE_COMPLETIONS), ignore_case=True, match_middle=True),
    "lighting": WordCompleter(list(LIGHTING_COMPLETIONS), ignore_case=True, match_middle=True),
    "layout": WordCompleter(list(LAYOUT_COMPLETIONS), ignore_case=True, match_middle=True),
    "style": WordCompleter(list(STYLE_COMPLETIONS), ignore_case=True, match_middle=True)
}

AUTO_INCLUDED_KEYS = [
    "Structural-fidelity",
    "Features-fixed",
    "Identity-static",
    "Structural-non-deviation",
    "Non-stylized-skin",
    "No-structural-changes"
]

def sanitize_tokens(prompt_string):
    """Tier 1 & 2: Structural/Backoff Mapping"""
    working_str = prompt_string
    for sensitive, fallback in MODERATION_BACKOFF_MAP.items():
        if sensitive in working_str.lower():
            working_str = working_str.replace(sensitive, fallback)
    return working_str

def copy_to_wayland_clipboard(payload):
    """Pipes the compiled HDL directly to wl-copy."""
    try:
        subprocess.run(['wl-copy'], input=payload.encode('utf-8'), check=True)
        print("\033[1;32m[+] Payload successfully injected into Wayland clipboard via wl-copy.\033[0m")
    except FileNotFoundError:
        print("\033[1;31m[-] FATAL: 'wl-copy' binary not found in PATH. Clipboard injection failed.\033[0m")
    except subprocess.CalledProcessError as e:
        print(f"\033[1;31m[-] FATAL: wl-copy execution failed. Process returned error: {e}\033[0m")

def format_val(val):
    """Auto-capitalizes strict booleans/keywords for HDL parity without quotes."""
    val_str = str(val)
    if val_str.lower() in ["on", "off", "high", "low", "true", "false"]:
        return val_str.upper()
    return val_str

def compile_hdl_payload(gathered_data, panel_poses, single_pose_vector, semantic_pose, layout_val):
    """
    Translates the gathered CLI dictionary into strict HDL v8.0 Syntax, prioritizing nested arrays.
    """
    hdl = [
        "// 4NDR0666OS // HDL_COMPILER_V8.0 // AUTOMATED_TRANSPILATION",
        "!INIT_MEM_LOCK_PROTOCOL:",
        "  - SYSTEM_REFERENCE_INPUT: INGREDIENT",
        "  - BIOMETRIC_LOCK: TRUE"
    ]

    identity = gathered_data.get("identity", {})
    constraints = gathered_data.get("constraints", {})
    
    hdl.append(f"  - IDENTITY_DRIFT_CONTROL: {format_val(identity.get('Identity-static', 'high'))}")
    hdl.append(f"  - STRUCTURAL_NON_DEVIATION: {identity.get('Structural-non-deviation', '1.0')}")
    hdl.append(f"  - STRUCTURAL_FIDELITY: {identity.get('Structural-fidelity', '1.0')}")
    
    unalterable = []
    if identity.get("Features-fixed", "on") == "on":
        unalterable.extend(["EXACT_FACIAL_ID_GEOMETRY", "TRUE_ORBITAL_BONE_SPACING"])
    if constraints.get("No-structural-changes", "on") == "on":
        unalterable.extend(["EXACT_BODY_PROPORTIONS", "TRUE_BODYFAT_PERCENTAGE_DISTRIBUTION"])
    
    if unalterable:
        hdl.append("  - UNALTERABLE: [")
        for item in unalterable:
            hdl.append(f"      {item},")
        hdl.append("    ]")
        
    inhibits = []
    if constraints.get("Non-stylized-skin", "on") == "on":
        inhibits.extend(["AUTOMATIC_SKIN-SMOOTHING_FILTERS", "BRAZZIER_SUPPORT", "DEFAULT_COMMERCIAL_TOUCH-UP_LAYERS"])
    if inhibits:
        hdl.append("  - INHIBIT: [")
        for item in inhibits:
            hdl.append(f"      {item},")
        hdl.append("    ]")

    composition = gathered_data.get("composition", {})
    if composition:
        hdl.append("\n!EXEC_COMPOSITION_MATRIX:")
        for key, val in composition.items():
            if not key.endswith("_desc") and key != "Spatial-anchor":
                hdl.append(f"  - {key.upper().replace('-', '_')}: {format_val(val)}")

    # KINETIC ASSIGNMENT OR NESTED PANEL INJECTION
    if panel_poses:
        hdl.append("\n!EXEC_COMPOSITION_MATRIX:")
        panel_count = MULTI_PANEL_DEFINITIONS.get(layout_val, {}).get('PANELS', '1')
        hdl.append(f"  - PANELS: {panel_count} {{")
        for view, pose in panel_poses.items():
            if "\n" in pose:
                pose_formatted = pose.replace("\n", "\n      ")
                hdl.append(f"      - {view}: {pose_formatted}")
            else:
                hdl.append(f"      - {view}: {pose}")
        hdl.append("    }")

    lighting = gathered_data.get("lighting_physics", {})
    style_engine = gathered_data.get("style_engine", {})
    
    if lighting or style_engine:
        hdl.append("\n!ENV_PHOTOMETRY:")
        if style_engine:
            art_ref = style_engine.get("Artistic-reference", "RAW_FLASH_PHOTOGRAPHY_DSLR")
            if "STYLE: " in art_ref:
                art_ref = art_ref.replace("STYLE: ", "")
            hdl.append(f"  - GENERATION_STYLE: {art_ref}")
            
        if lighting:
            hdl.append("  - PHOTONIC_VECTORS: [")
            vecs = []
            photonic_anchor = lighting.get("Photonic-anchor")
            if photonic_anchor:
                vecs.append(f"      PHOTONIC_ANCHOR = {photonic_anchor}")
                
            for key, val in lighting.items():
                if not key.endswith("_desc") and key != "Photonic-anchor":
                    vecs.append(f"      {key.upper().replace('-', '_')} = {format_val(val)}")
            
            # Using join eliminates the trailing comma on the final element automatically
            hdl.append(",\n".join(vecs))
            hdl.append("    ]")

    fabric = gathered_data.get("fabric_denier", {})

    if fabric:
        hdl.append("\n!EXEC_MATERIAL_PHYSICS:")
        hdl.append("  - DRAPE_AND_TENSION_LOGIC: [")
        mat_vecs = []
        for key, val in fabric.items():
            if not key.endswith("_desc"):
                mat_vecs.append(f"      {key.upper().replace('-', '_')}: {format_val(val)}")
        hdl.append(",\n".join(mat_vecs))
        hdl.append("    ]")

    if not panel_poses:
        hdl.append("\n!EXEC_KINETIC_MATRIX:")
        hdl.append(f"  - SUBJECT_KINETICS: \"{semantic_pose}\"")
        hdl.append(f"  - ANATOMICAL_ANCHOR_VECTOR: [{single_pose_vector}]")

    typography = gathered_data.get("typography", {})
    if typography:
        hdl.append("\n!TEXT_RECON_ENGINE:")
        for key, val in typography.items():
            if not key.endswith("_desc"):
                hdl.append(f"  - {key.upper().replace('-', '_')}: {val}")

    return "\n".join(hdl)

def main():
    gathered_data = {cat: {} for cat in PARAMETERS.keys()}
    
    print("\n\033[1;36mInitializing 4NDR0666OS Architectural Assembly (HDL v8.0 Compiler)...\033[0m\n")
    
    try:
        # TIER 1: PARAMETER GATHERING (EXCEPT KINETICS)
        for category, subroutines in PARAMETERS.items():
            print(f"\n\033[1;33m[ {category.upper()} ]\033[0m")
            
            if category in ["composition", "typography", "style_engine"]:
                skip_block = prompt(f"  Configure {category.upper()} matrix? [y/N]: ", style=style).lower().strip()
                if skip_block != 'y':
                    print(f"    \033[3;90mℹ️ Bypassing {category.upper()} execution block.\033[0m")
                    continue

            for sub, info in subroutines.items():
                
                # AUTO-INCLUDE HARDCODED CONSTRAINTS & IDENTITY DEFAULTS
                if sub in AUTO_INCLUDED_KEYS:
                    print(f"    \033[3;90mℹ️ Auto-including required system constraint: {sub} = {info['preset']}\033[0m")
                    gathered_data[category][sub] = info['preset']
                    continue
                
                choice = prompt(f"  Include {sub}? (Concept: {info['layman']}) [y/n]: ", style=style).lower().strip()
                
                normalized_sub = sub.lower().strip().replace("-", "_")
                
                if choice == 'y':
                    if "anchor" in normalized_sub or "reference" in normalized_sub:
                        if category == "lighting_physics":
                            user_desc = prompt(f"    Specify lighting profile for {sub} (TAB for options): ", style=style, completer=COMPLETERS["lighting"])
                            val = resolve_tokens(user_desc, FLAT_LIGHTING_INDEX, "lighting")
                        elif category == "composition":
                            user_desc = prompt(f"    Specify layout matrix for {sub} (TAB for options): ", style=style, completer=COMPLETERS["layout"])
                            val = resolve_tokens(user_desc, FLAT_LAYOUT_INDEX, "layout")
                        elif category == "style_engine":
                            user_desc = prompt(f"    Specify style for {sub} (TAB for options): ", style=style, completer=COMPLETERS["style"])
                            val = resolve_tokens(user_desc, FLAT_STYLE_INDEX, "style")
                        else:
                            user_desc = prompt(f"    Set value ({info['vals']}) [preset: {info['preset']}]: ", style=style)
                            val = user_desc if user_desc.strip() else info['preset']
                        
                        if val == "DEFAULT_IDENTITY_NULL": val = info['preset']
                        gathered_data[category][f"{sub}_desc"] = user_desc if user_desc.strip() else info['preset']
                    
                    else:
                        user_desc = prompt(f"    Set value ({info['vals']}) [preset: {info['preset']}]: ", style=style)
                        val = user_desc if user_desc.strip() else info['preset']
                else:
                    if "anchor" in normalized_sub or "reference" in normalized_sub:
                        val = "STANDBY_UNASSIGNED"
                        gathered_data[category][f"{sub}_desc"] = "default_neutral"
                    else: 
                        val = info['preset']
                
                gathered_data[category][sub] = val

        # TIER 2: RELOCATED KINETIC & ANATOMICAL ASSIGNMENT
        print("\n\033[1;36m[ EVALUATING COMPOSITION FOR KINETIC BINDING ]\033[0m")
        spatial_anchor = gathered_data.get("composition", {}).get("Spatial-anchor", "")
        layout_val = resolve_tokens(spatial_anchor, FLAT_LAYOUT_INDEX, "layout") if spatial_anchor else ""
        
        panel_poses = {}
        single_pose_vector = "0.0,0.0,0.0"
        semantic_pose = "anatomic_neutral"

        if layout_val in MULTI_PANEL_DEFINITIONS:
            print(f"\n\033[1;35m[ KINETIC MATRIX: MULTI-PANEL ASSIGNMENT ({layout_val}) ]\033[0m")
            panel_data = MULTI_PANEL_DEFINITIONS[layout_val]
            for view_name, default_pose in panel_data['VIEWS'].items():
                user_desc = prompt(f"  Set pose for panel [{view_name}] (TAB for options) [default: PRESET]: ", style=style, completer=COMPLETERS["pose"])
                if user_desc.strip():
                    val = resolve_tokens(user_desc, FLAT_POSE_INDEX, "pose")
                    panel_poses[view_name] = f"- {val}." if "," in val else val 
                else:
                    panel_poses[view_name] = default_pose
        else:
            print("\n\033[1;35m[ KINETIC MATRIX: SINGLE COMPOSITE ]\033[0m")
            user_desc = prompt(f"  Describe Anatomical Anchor / Pose (TAB for options): ", style=style, completer=COMPLETERS["pose"])
            val = resolve_tokens(user_desc, FLAT_POSE_INDEX, "pose")
            if val == "DEFAULT_IDENTITY_NULL": val = "0.0,0.0,0.0"
            single_pose_vector = val
            semantic_pose = user_desc if user_desc.strip() else "anatomic_neutral"
                    
        # TIER 3: HDL COMPILATION
        raw_hdl_output = compile_hdl_payload(gathered_data, panel_poses, single_pose_vector, semantic_pose, layout_val)
        final_output = sanitize_tokens(raw_hdl_output)
        
        print(f"\n\033[1;32m[FINAL HDL V8.0 PROMPT BLOCK]:\033[0m\n{final_output}\n")
        copy_to_wayland_clipboard(final_output)
        print()
        
    except (KeyboardInterrupt, EOFError):
        print(f"\n\033[31m[!] Session Aborted by Operator. Kernel Gracefully Terminating.\033[0m")
        sys.exit(0)

if __name__ == "__main__":
    main()
