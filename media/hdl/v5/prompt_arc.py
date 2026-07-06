#!/usr/bin/env python3
# ==============================================================================
# HDL PROMPT BUILDER  (prompt_arc.py)
# Interactive / Random / Hybrid / Stock / TUI schema constructor.
# All completion options sourced from promptlib.py.
#
# MODES (CLI — no --tui flag)
#   i  interactive  Walk every field with TAB-completion + free-text input
#   r  random       Instantly generate a complete schema; no prompts
#   h  hybrid       Random seed, then field-by-field review / override
#   s  stock        Block-level bypass: choose per-section to customise or accept defaults
#
# MANUAL INPUT
#   At every prompt you may type anything not in the completion list and press
#   ENTER — the value is accepted verbatim.  The completer is advisory only.
#
# TUI (--tui flag)
#   Full-screen 3-pane prompt_toolkit Application with live JSON preview.
#   The TUI and CLI share generate_random() and HDLTUIState but run in
#   completely separate event-loop paths — no chimera mixing.
# ==============================================================================

import copy
import json
import random
import subprocess
import sys
from typing import Any

# ── TUI imports are deferred to avoid loading layout objects in CLI mode ──────
# They are imported inside HDLTUIApplication.__init__ only when --tui is passed.

from prompt_toolkit import prompt as pt_prompt
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.styles import Style

import promptlib as lib

# ==============================================================================
# TERMINAL STYLE
# ==============================================================================
CLI_STYLE = Style.from_dict({
    "prompt":                             "bold ansicyan",
    "completion-menu.completion":         "bg:#1e1e2e fg:#cdd6f4",
    "completion-menu.completion.current": "bg:#89b4fa fg:#1e1e2e bold",
    "scrollbar.background":               "bg:#313244",
    "scrollbar.button":                   "bg:#89b4fa",
})

# ==============================================================================
# PRIMITIVE PROMPT HELPERS
# ==============================================================================

def _prompt(
    label: str,
    completions: list[str],
    default: str = "",
    hint: str = "",
    skip: bool = False,
) -> str:
    """
    Single-value prompt with TAB completion AND free-text manual input.

    skip=True: bypass the prompt entirely and return `default` immediately.
    TAB shows library completions (advisory only).
    Any typed text not in the list is accepted verbatim.
    ENTER with empty buffer accepts `default`.
    """
    if skip:
        return default

    completer = WordCompleter(completions, ignore_case=True, sentence=True)
    default_hint = f"  ↩ {default}" if default else ""
    hint_str     = f"  [{hint}]" if hint else ""
    text = f"  {label}{hint_str}  [TAB|free-text]{default_hint}\n  ❯ "
    try:
        result = pt_prompt(
            text,
            completer=completer,
            style=CLI_STYLE,
            complete_while_typing=True,
        ).strip()
    except (KeyboardInterrupt, EOFError):
        print("\n[Aborted]")
        sys.exit(0)
    return result if result else default


def _prompt_list(
    label: str,
    completions: list[str],
    defaults: list[str] | None = None,
    hint: str = "",
    skip: bool = False,
) -> list[str]:
    """
    Multi-value prompt — comma-separated.  Each token may be a library key
    OR any free-text string.  skip=True returns defaults immediately.
    """
    default_str = ", ".join(defaults or [])
    raw = _prompt(
        label,
        completions,
        default=default_str,
        hint=f"comma-separated{'; ' + hint if hint else ''}",
        skip=skip,
    )
    return [v.strip() for v in raw.split(",") if v.strip()]


def _header(title: str) -> None:
    print()
    print("─" * 72)
    print(f"  {title}")
    print("─" * 72)


def _subheader(title: str) -> None:
    print(f"\n    ┄ {title} ┄")


def _ask_yes(question: str) -> bool:
    """Single yes/no question; ENTER or 'n' → False, 'y' → True."""
    try:
        raw = pt_prompt(f"  {question} [y/N] ❯ ", style=CLI_STYLE).strip().lower()
    except (KeyboardInterrupt, EOFError):
        print("\n[Aborted]")
        sys.exit(0)
    return raw == "y"

# ==============================================================================
# RANDOM GENERATION — samples every field independently from promptlib
# ==============================================================================

def _r(pool: list[str]) -> str:
    return random.choice(pool) if pool else ""


def _r_list(pool: list[str], k_min: int = 1, k_max: int = 4) -> list[str]:
    k = random.randint(k_min, min(k_max, len(pool)))
    return random.sample(pool, k)


def generate_random(n_panels: int | None = None, seed: int | None = None) -> dict:
    """
    Build a complete HDL schema by randomly sampling every field from promptlib.
    STATIC_MEM_LOCK and STATIC_FINALIZE are injected verbatim — never randomised.
    seed: optional integer for reproducible output.
    """
    if seed is not None:
        random.seed(seed)

    # ── ENV ATMOSPHERICS ──────────────────────────────────────────────────────
    env_atmospherics = {
        "LOCATION_SETTING":    _r(lib.LOCATION_COMPLETIONS),
        "GLASS_SURFACE_METRICS": _r(lib.GLASS_COMPLETIONS),
        "COMPOSITION_DEPTH": {
            "FOREGROUND": _r(list(lib.DOF_MANIFEST["foreground"].keys())),
            "MIDGROUND":  _r(list(lib.DOF_MANIFEST["midground"].keys())),
            "BACKGROUND": _r(list(lib.DOF_MANIFEST["background"].keys())),
        },
    }

    # ── PANELS ────────────────────────────────────────────────────────────────
    if n_panels is None:
        n_panels = random.randint(1, 9)

    matrix: dict[str, Any] = {"PANELS": str(n_panels)}
    used_views: set[str] = set()
    for _ in range(n_panels):
        remaining = [v for v in lib.VIEW_COMPLETIONS if v not in used_views]
        view = _r(remaining if remaining else lib.VIEW_COMPLETIONS)
        used_views.add(view)
        matrix[view] = _r(lib.POSE_COMPLETIONS)

    # ── BIO DERMAL MAP ────────────────────────────────────────────────────────
    bio_dermal = {
        "SKIN_TOPOGRAPHY_LOGIC":  _r(lib.TOPO_COMPLETIONS),
        "SURFACE_MICRO_ELEMENTS": _r(list(lib.SKIN_MANIFEST["surface_micro"].keys())),
        "REFLECTANCE_MAP":        _r(list(lib.SKIN_MANIFEST["reflectance"].keys())),
        "EXPRESSION":             _r(list(lib.SKIN_MANIFEST["expressions"].keys())),
        "HAIR":                   _r(list(lib.SKIN_MANIFEST["hair"].keys())),
    }

    # ── ENV PHOTOMETRY ────────────────────────────────────────────────────────
    photometry = {
        "STYLE_OF":              _r_list(lib.STYLE_COMPLETIONS, 1, 3),
        "HARDWARE_EMULATION":    _r(lib.CAMERA_COMPLETIONS),
        "OPTICAL_HARDWARE":      _r(lib.LENS_COMPLETIONS),
        "APERTURE_SETTING":      _r(lib.APERTURE_COMPLETIONS),
        "SHUTTER_AESTHETIC":     _r(lib.SHUTTER_COMPLETIONS),
        "ILLUMINATION_AXIS":     _r(lib.LIGHTING_COMPLETIONS),
        "KEY_LIGHT_CHARACTER":   _r(lib.LIGHTING_COMPLETIONS),
        "FILL_LIGHT_CHARACTER":  _r(lib.LIGHTING_COMPLETIONS),
        "SHADOW_PROFILE":        _r(lib.LIGHTING_COMPLETIONS),
        "PHOTONIC_VECTORS": {
            "PHOTONIC_ENERGY":               _r(lib.ENERGY_COMPLETIONS),
            "ENERGY_CONSERVATION_COMPLIANT": "ENERGY_CONSERVATION_COMPLIANT",
            "RIM_LIGHT_SCATTERING_PASS":     _r(lib.LEVEL_COMPLETIONS),
            "EPIDERMAL_TRANSLUCENCY_PASS":   _r(lib.LEVEL_COMPLETIONS),
            "THROUGH_FABRIC_DIFFUSE_BOUNCE": _r(lib.LEVEL_COMPLETIONS),
            "PHOTON_TRANSMISSION_RATIO":     _r(lib.LEVEL_COMPLETIONS),
            "MEAN_FREE_PATH_SCATTERING":     _r(lib.LEVEL_COMPLETIONS),
            "BACKLIT_SUBSURFACE_GLOW":       _r(lib.LEVEL_COMPLETIONS),
            "FRESNEL_REFLECTION_COEFFICIENT":_r(lib.LEVEL_COMPLETIONS),
            "SPECULAR_HIGHLIGHT_LOBE":       _r(lib.LEVEL_COMPLETIONS),
            "LAMBERTIAN_DIFFUSE_REFLECTANCE":_r(lib.LEVEL_COMPLETIONS),
        },
    }

    # ── MATERIAL PHYSICS ──────────────────────────────────────────────────────
    material = {
        "WARDROBE_SPECIFICATION": _r(lib.WARDROBE_COMPLETIONS),
        "OPACITY":                _r(lib.OPACITY_COMPLETIONS),
        "TEXTILE_SURFACE_SHEEN":  _r(lib.SHEEN_COMPLETIONS),
        "DRAPE_AND_TENSION_LOGIC": {
            "MICRO_FIBER_DRAPE_PHYSICS":             _r(lib.LEVEL_COMPLETIONS),
            "LOW_TENSILE_STRUCTURAL_DEFORMITY":      _r(lib.LEVEL_COMPLETIONS),
            "GRAVITY_WEIGHTED_FOLDS":                _r(lib.LEVEL_COMPLETIONS),
            "SUB_MICRON_WEAVE_DENSITY":              _r(lib.LEVEL_COMPLETIONS),
            "LOW_DENIER_SSS_PASS":                   _r(["ON", "OFF"]),
            "SURFACE_ADHESION_COEFFICIENT":          _r(lib.LEVEL_COMPLETIONS),
            "FULLY_SATURATED_WITH_ATMOSPHERIC_MOISTURE": _r(lib.BOOL_COMPLETIONS),
        },
    }

    # ── TEXT RECON ────────────────────────────────────────────────────────────
    text_recon = {
        "TEXT_STRING_LITERAL": _r(lib.TEXT_STRING_COMPLETIONS),
        "FONTTYPE_AESTHETIC":  _r(lib.TEXT_FONT_COMPLETIONS),
        "LAYER_PLACEMENT":     _r(lib.TEXT_PLACE_COMPLETIONS),
    }

    # ── ASSEMBLE ──────────────────────────────────────────────────────────────
    matrix["!EXEC_BIO_DERMAL_MAP"]   = bio_dermal
    matrix["!ENV_PHOTOMETRY"]        = photometry
    matrix["!EXEC_MATERIAL_PHYSICS"] = material

    return {
        "!INIT_MEM_LOCK_PROTOCOL":  copy.deepcopy(lib.STATIC_MEM_LOCK),
        "!ENV_ATMOSPHERICS":        env_atmospherics,
        "!EXEC_COMPOSITION_MATRIX": matrix,
        "TEXT_RECON_ENGINE":        text_recon,
        "!FINALIZE_OUTPUT":         copy.deepcopy(lib.STATIC_FINALIZE),
    }

# ==============================================================================
# INTERACTIVE SECTION BUILDERS
# ==============================================================================

def build_env_atmospherics(skip: bool = False) -> dict:
    if not skip:
        _header("ENV ATMOSPHERICS")
    return {
        "LOCATION_SETTING": _prompt(
            "LOCATION_SETTING", lib.LOCATION_COMPLETIONS,
            default="bathroom_steam_ceramic_harsh_flash",
            hint="library key or free description", skip=skip,
        ),
        "GLASS_SURFACE_METRICS": _prompt(
            "GLASS_SURFACE_METRICS", lib.GLASS_COMPLETIONS,
            default="condensation_calcium_grease_dust",
            hint="library key or free description", skip=skip,
        ),
        "COMPOSITION_DEPTH": {
            "FOREGROUND": _prompt(
                "FOREGROUND", list(lib.DOF_MANIFEST["foreground"].keys()),
                default="shallow_cinematic_dramatic", hint="DOF/foreground", skip=skip,
            ),
            "MIDGROUND": _prompt(
                "MIDGROUND", list(lib.DOF_MANIFEST["midground"].keys()),
                default="subject_behind_waterfall_stones", hint="subject action", skip=skip,
            ),
            "BACKGROUND": _prompt(
                "BACKGROUND", list(lib.DOF_MANIFEST["background"].keys()),
                default="ceramic_tiles_deep_shadow_grout", hint="environment", skip=skip,
            ),
        },
    }


def build_panel(index: int, skip: bool = False) -> dict:
    if not skip:
        _subheader(f"Panel {index}")
    angle = _prompt(
        f"Panel {index} — camera angle / view label",
        lib.VIEW_COMPLETIONS, default="MEDIUM CLOSE-UP (MCU)",
        hint="view", skip=skip,
    )
    kinetic = _prompt(
        f"Panel {index} — kinetic / pose",
        lib.POSE_COMPLETIONS, default="supine_flat",
        hint="pose", skip=skip,
    )
    return {angle: kinetic}


def build_composition_matrix(skip: bool = False) -> dict:
    """
    If skip=True, return a hardcoded 4-panel default grid immediately.
    """
    if skip:
        default_views = [
            "MEDIUM CLOSE-UP (MCU)", "BIRDS EYE (BE)",
            "FRONT EXTREME CLOSE-UP (ECU/XCU)", "SIDE CLOSE-UP (SCU)",
        ]
        matrix: dict[str, Any] = {"PANELS": "4"}
        for v in default_views:
            matrix[v] = "supine_flat"
        return matrix

    _header("COMPOSITION MATRIX")

    layout_choice = _prompt(
        "Layout preset  (ENTER to skip and define panels manually)",
        lib.LAYOUT_COMPLETIONS, default="", hint="optional preset",
    )

    if layout_choice and layout_choice in lib.FLAT_LAYOUT_INDEX:
        for _cat in lib.LAYOUT_MANIFEST.values():
            if layout_choice in _cat:
                preset = _cat[layout_choice]
                break
        n_panels = int(preset.get("PANELS", "4"))
        matrix = {"LAYOUT_PRESET": layout_choice, "PANELS": str(n_panels)}
    else:
        n_str = _prompt(
            "Number of panels", lib.PANEL_COUNT_COMPLETIONS,
            default="4", hint="1–9 or type a number",
        )
        try:
            n_panels = int(n_str)
        except ValueError:
            print(f"  [!] '{n_str}' is not a valid integer — defaulting to 4")
            n_panels = 4
        matrix = {"PANELS": str(n_panels)}

    for i in range(1, n_panels + 1):
        matrix.update(build_panel(i))

    return matrix


def build_bio_dermal_map(skip: bool = False) -> dict:
    if not skip:
        _header("BIO DERMAL MAP")
    return {
        "SKIN_TOPOGRAPHY_LOGIC": _prompt(
            "SKIN_TOPOGRAPHY_LOGIC", lib.TOPO_COMPLETIONS,
            default="unfiltered_hyper_realistic_dermal_detail",
            hint="topology or free description", skip=skip,
        ),
        "SURFACE_MICRO_ELEMENTS": _prompt(
            "SURFACE_MICRO_ELEMENTS",
            list(lib.SKIN_MANIFEST["surface_micro"].keys()),
            default="full_unretouched_pores_goosebumps_sweat",
            hint="micro elements", skip=skip,
        ),
        "REFLECTANCE_MAP": _prompt(
            "REFLECTANCE_MAP",
            list(lib.SKIN_MANIFEST["reflectance"].keys()),
            default="high_specular_damp_skin_flash",
            hint="reflectance", skip=skip,
        ),
        "EXPRESSION": _prompt(
            "EXPRESSION",
            list(lib.SKIN_MANIFEST["expressions"].keys()),
            default="cool_detached_neutral_lips_parted",
            hint="expression", skip=skip,
        ),
        "HAIR": _prompt(
            "HAIR",
            list(lib.SKIN_MANIFEST["hair"].keys()),
            default="messy_loose_updo_stray_strands",
            hint="hair state", skip=skip,
        ),
    }


def build_env_photometry(skip: bool = False) -> dict:
    if not skip:
        _header("ENV PHOTOMETRY")

    def _level(label: str, default: str = "MEDIUM") -> str:
        return _prompt(label, lib.LEVEL_COMPLETIONS, default=default,
                       hint="HIGH/MEDIUM/LOW/ULTRA/OFF or free text", skip=skip)

    return {
        "STYLE_OF": _prompt_list(
            "STYLE_OF", lib.STYLE_COMPLETIONS,
            defaults=["HELMUT_NEWTON"], hint="photographer style(s)", skip=skip,
        ),
        "HARDWARE_EMULATION": _prompt(
            "HARDWARE_EMULATION", lib.CAMERA_COMPLETIONS,
            default="Canon EOS 5D Mark IV",
            hint="camera body or free description", skip=skip,
        ),
        "OPTICAL_HARDWARE": _prompt(
            "OPTICAL_HARDWARE", lib.LENS_COMPLETIONS,
            default="Canon EF 100mm f/2.8L Macro IS USM",
            hint="lens or free description", skip=skip,
        ),
        "APERTURE_SETTING": _prompt(
            "APERTURE_SETTING", lib.APERTURE_COMPLETIONS,
            default="f/2.8", hint="f-stop or free text", skip=skip,
        ),
        "SHUTTER_AESTHETIC": _prompt(
            "SHUTTER_AESTHETIC", lib.SHUTTER_COMPLETIONS,
            default="flash_sync_1_125_standard",
            hint="sync mode or free description", skip=skip,
        ),
        "ILLUMINATION_AXIS": _prompt(
            "ILLUMINATION_AXIS", lib.LIGHTING_COMPLETIONS,
            default="on_camera_popup_flash_5500K",
            hint="light source or free description", skip=skip,
        ),
        "KEY_LIGHT_CHARACTER": _prompt(
            "KEY_LIGHT_CHARACTER", lib.LIGHTING_COMPLETIONS,
            default="on_camera_popup_flash_5500K",
            hint="key light", skip=skip,
        ),
        "FILL_LIGHT_CHARACTER": _prompt(
            "FILL_LIGHT_CHARACTER", lib.LIGHTING_COMPLETIONS,
            default="ambient_tungsten_3200K_background",
            hint="fill light", skip=skip,
        ),
        "SHADOW_PROFILE": _prompt(
            "SHADOW_PROFILE", lib.LIGHTING_COMPLETIONS,
            default="shadow_razor_hard_zero_penumbra",
            hint="shadow character", skip=skip,
        ),
        "PHOTONIC_VECTORS": {
            "PHOTONIC_ENERGY":               _prompt("PHOTONIC_ENERGY", lib.ENERGY_COMPLETIONS,
                                                     default="MICROFACET_DISTRIBUTION", skip=skip),
            "ENERGY_CONSERVATION_COMPLIANT": _prompt("ENERGY_CONSERVATION_COMPLIANT", lib.ENERGY_COMPLETIONS,
                                                     default="ENERGY_CONSERVATION_COMPLIANT", skip=skip),
            "RIM_LIGHT_SCATTERING_PASS":     _level("RIM_LIGHT_SCATTERING_PASS",    "TRUE"),
            "EPIDERMAL_TRANSLUCENCY_PASS":   _level("EPIDERMAL_TRANSLUCENCY_PASS",  "TRUE"),
            "THROUGH_FABRIC_DIFFUSE_BOUNCE": _level("THROUGH_FABRIC_DIFFUSE_BOUNCE","TRUE"),
            "PHOTON_TRANSMISSION_RATIO":     _level("PHOTON_TRANSMISSION_RATIO",    "HIGH"),
            "MEAN_FREE_PATH_SCATTERING":     _level("MEAN_FREE_PATH_SCATTERING",    "MEDIUM"),
            "BACKLIT_SUBSURFACE_GLOW":       _level("BACKLIT_SUBSURFACE_GLOW",      "MEDIUM"),
            "FRESNEL_REFLECTION_COEFFICIENT":_level("FRESNEL_REFLECTION_COEFFICIENT","LOW"),
            "SPECULAR_HIGHLIGHT_LOBE":       _level("SPECULAR_HIGHLIGHT_LOBE",      "LOW"),
            "LAMBERTIAN_DIFFUSE_REFLECTANCE":_level("LAMBERTIAN_DIFFUSE_REFLECTANCE","LOW"),
        },
    }


def build_material_physics(skip: bool = False) -> dict:
    if not skip:
        _header("MATERIAL PHYSICS")
    drape_opts = lib.LEVEL_COMPLETIONS
    sss_opts   = ["ON", "OFF"] + lib.LEVEL_COMPLETIONS
    return {
        "WARDROBE_SPECIFICATION": _prompt(
            "WARDROBE_SPECIFICATION", lib.WARDROBE_COMPLETIONS,
            default="white_vintage_silk_slip_dress_lace_trim",
            hint="wardrobe key or free description", skip=skip,
        ),
        "OPACITY": _prompt(
            "OPACITY", lib.OPACITY_COMPLETIONS,
            default="gradient_tension_mapping", skip=skip,
        ),
        "TEXTILE_SURFACE_SHEEN": _prompt(
            "TEXTILE_SURFACE_SHEEN", lib.SHEEN_COMPLETIONS,
            default="anisotropic_silk_flash_folds", skip=skip,
        ),
        "DRAPE_AND_TENSION_LOGIC": {
            "MICRO_FIBER_DRAPE_PHYSICS":          _prompt("MICRO_FIBER_DRAPE_PHYSICS",        drape_opts, default="HIGH",   skip=skip),
            "LOW_TENSILE_STRUCTURAL_DEFORMITY":   _prompt("LOW_TENSILE_STRUCTURAL_DEFORMITY", drape_opts, default="MEDIUM", skip=skip),
            "GRAVITY_WEIGHTED_FOLDS":             _prompt("GRAVITY_WEIGHTED_FOLDS",           drape_opts, default="LOW",    skip=skip),
            "SUB_MICRON_WEAVE_DENSITY":           _prompt("SUB_MICRON_WEAVE_DENSITY",         drape_opts, default="LOW",    skip=skip),
            "LOW_DENIER_SSS_PASS":                _prompt("LOW_DENIER_SSS_PASS",              sss_opts,   default="ON",     skip=skip),
            "SURFACE_ADHESION_COEFFICIENT":       _prompt("SURFACE_ADHESION_COEFFICIENT",     drape_opts, default="HIGH",   skip=skip),
            "FULLY_SATURATED_WITH_ATMOSPHERIC_MOISTURE": _prompt(
                "FULLY_SATURATED_WITH_ATMOSPHERIC_MOISTURE",
                lib.BOOL_COMPLETIONS, default="TRUE", skip=skip,
            ),
        },
    }


def build_text_recon(skip: bool = False) -> dict:
    if not skip:
        _header("TEXT RECON ENGINE")
    return {
        "TEXT_STRING_LITERAL": _prompt(
            "TEXT_STRING_LITERAL", lib.TEXT_STRING_COMPLETIONS,
            default="see_you_soon_ellipsis",
            hint="key or type your own literal string", skip=skip,
        ),
        "FONTTYPE_AESTHETIC": _prompt(
            "FONTTYPE_AESTHETIC", lib.TEXT_FONT_COMPLETIONS,
            default="lipstick_finger_scrawl_red",
            hint="font key or free description", skip=skip,
        ),
        "LAYER_PLACEMENT": _prompt(
            "LAYER_PLACEMENT", lib.TEXT_PLACE_COMPLETIONS,
            default="mirror_glass_plane_sharp",
            hint="placement key or free description", skip=skip,
        ),
    }

# ==============================================================================
# FULL INTERACTIVE BUILD
# ==============================================================================

def run_interactive() -> dict:
    composition = build_composition_matrix(skip=False)
    composition["!EXEC_BIO_DERMAL_MAP"]   = build_bio_dermal_map(skip=False)
    composition["!ENV_PHOTOMETRY"]        = build_env_photometry(skip=False)
    composition["!EXEC_MATERIAL_PHYSICS"] = build_material_physics(skip=False)

    return {
        "!INIT_MEM_LOCK_PROTOCOL":  copy.deepcopy(lib.STATIC_MEM_LOCK),
        "!ENV_ATMOSPHERICS":        build_env_atmospherics(skip=False),
        "!EXEC_COMPOSITION_MATRIX": composition,
        "TEXT_RECON_ENGINE":        build_text_recon(skip=False),
        "!FINALIZE_OUTPUT":         copy.deepcopy(lib.STATIC_FINALIZE),
    }

# ==============================================================================
# STOCK MODE — block-level bypass, one yes/no per section
# ==============================================================================

def run_stock() -> dict:
    _header("STOCK MODE — press ENTER or 'n' to accept block defaults, 'y' to customise")

    def _block(name: str, builder, **kwargs) -> Any:
        if _ask_yes(f"Customise {name}?"):
            return builder(skip=False, **kwargs)
        return builder(skip=True, **kwargs)

    composition = _block("COMPOSITION MATRIX", build_composition_matrix)
    composition["!EXEC_BIO_DERMAL_MAP"]   = _block("BIO DERMAL MAP",   build_bio_dermal_map)
    composition["!ENV_PHOTOMETRY"]        = _block("ENV PHOTOMETRY",   build_env_photometry)
    composition["!EXEC_MATERIAL_PHYSICS"] = _block("MATERIAL PHYSICS", build_material_physics)

    return {
        "!INIT_MEM_LOCK_PROTOCOL":  copy.deepcopy(lib.STATIC_MEM_LOCK),
        "!ENV_ATMOSPHERICS":        _block("ENV ATMOSPHERICS", build_env_atmospherics),
        "!EXEC_COMPOSITION_MATRIX": composition,
        "TEXT_RECON_ENGINE":        _block("TEXT RECON ENGINE", build_text_recon),
        "!FINALIZE_OUTPUT":         copy.deepcopy(lib.STATIC_FINALIZE),
    }

# ==============================================================================
# HYBRID MODE — random seed, then field-by-field review / override
# ==============================================================================

def _pool_for_path(path: str) -> list[str]:
    """Map a dotted field path to the most relevant completion list."""
    p = path.lower()
    if "style_of"          in p: return lib.STYLE_COMPLETIONS
    if "hardware_emulation" in p: return lib.CAMERA_COMPLETIONS
    if "optical_hardware"  in p: return lib.LENS_COMPLETIONS
    if "aperture"          in p: return lib.APERTURE_COMPLETIONS
    if "shutter"           in p: return lib.SHUTTER_COMPLETIONS
    if any(k in p for k in ("illumination", "key_light", "fill_light", "shadow_profile")):
        return lib.LIGHTING_COMPLETIONS
    if "photonic_energy"   in p or "energy_conservation" in p: return lib.ENERGY_COMPLETIONS
    if "wardrobe"          in p: return lib.WARDROBE_COMPLETIONS
    if "opacity"           in p: return lib.OPACITY_COMPLETIONS
    if "sheen"             in p: return lib.SHEEN_COMPLETIONS
    if "expression"        in p: return list(lib.SKIN_MANIFEST["expressions"].keys())
    if "hair"              in p: return list(lib.SKIN_MANIFEST["hair"].keys())
    if "reflectance"       in p: return list(lib.SKIN_MANIFEST["reflectance"].keys())
    if "surface_micro"     in p: return list(lib.SKIN_MANIFEST["surface_micro"].keys())
    if "skin_topography"   in p: return lib.TOPO_COMPLETIONS
    if "location"          in p: return lib.LOCATION_COMPLETIONS
    if "glass"             in p: return lib.GLASS_COMPLETIONS
    if "foreground"        in p: return list(lib.DOF_MANIFEST["foreground"].keys())
    if "midground"         in p: return list(lib.DOF_MANIFEST["midground"].keys())
    if "background"        in p: return list(lib.DOF_MANIFEST["background"].keys())
    if "text_string"       in p: return lib.TEXT_STRING_COMPLETIONS
    if "fonttype"          in p: return lib.TEXT_FONT_COMPLETIONS
    if "layer_placement"   in p: return lib.TEXT_PLACE_COMPLETIONS
    if "focus_lock"        in p: return lib.FOCUS_COMPLETIONS
    if "negative_bias"     in p: return lib.NEG_BIAS_COMPLETIONS
    if "unalterable"       in p: return lib.UNALTERABLE_COMPLETIONS
    if "inhibit"           in p: return lib.INHIBIT_COMPLETIONS
    if "identity_drift"    in p: return lib.LOCK_COMPLETIONS
    if "fidelity"          in p or "non_deviation" in p: return lib.FIDELITY_COMPLETIONS
    if "color_science"     in p: return lib.COLOR_COMPLETIONS
    if "optics"            in p or "aberration" in p: return lib.OPTICS_COMPLETIONS
    if "meteorology"       in p or "weather" in p or "wind" in p: return lib.METEOROLOGY_COMPLETIONS
    if any(k in p for k in ("rim_light", "epidermal", "fabric_diffuse",
                             "photon_trans", "mean_free", "backlit",
                             "fresnel", "specular_lobe", "lambertian")):
        return lib.LEVEL_COMPLETIONS
    return []


def _review_field(key: str, current_value: Any, completions: list[str]) -> Any:
    """Show randomly-generated value; allow override or keep with ENTER."""
    is_list = isinstance(current_value, list)
    display = ", ".join(current_value) if is_list else str(current_value)
    print(f"\n  ┤ {key}")
    print(f"    random → {display}")
    raw = _prompt(
        "  Keep (ENTER) or type replacement",
        completions, default="",
        hint="ENTER = keep random value",
    )
    if not raw:
        return current_value
    if is_list:
        return [v.strip() for v in raw.split(",") if v.strip()]
    return raw


def run_hybrid(schema: dict) -> dict:
    """Walk every leaf in the randomly-generated schema; offer field-level override."""
    _header("HYBRID REVIEW — override any field or press ENTER to keep random value")
    _header("NOTE: !INIT_MEM_LOCK_PROTOCOL and !FINALIZE_OUTPUT are static — skipped")

    def _walk(node: Any, path: str = "") -> Any:
        if isinstance(node, dict):
            return {k: _walk(v, f"{path}.{k}") for k, v in node.items()}
        if isinstance(node, (list, str)):
            pool = _pool_for_path(path)
            return _review_field(path.lstrip("."), node, pool)
        return node

    result = {}
    for top_key, top_val in schema.items():
        # Static blocks pass through unchanged — no review offered
        if top_key in ("!INIT_MEM_LOCK_PROTOCOL", "!FINALIZE_OUTPUT"):
            result[top_key] = top_val
        else:
            result[top_key] = _walk(top_val, top_key)
    return result

# ==============================================================================
# TUI STATE OBJECT
# ==============================================================================

class HDLTUIState:
    """Single source of truth for the live JSON payload in TUI mode."""

    def __init__(self, seed: int | None = None) -> None:
        self._schema: dict = generate_random(seed=seed)

    def randomise(self, seed: int | None = None) -> None:
        self._schema = generate_random(seed=seed)

    def update_val(self, path: list[str], new_value: Any) -> None:
        """Apply a mutation at an arbitrary nested path."""
        node = self._schema
        for key in path[:-1]:
            node = node[key]
        node[path[-1]] = new_value

    def to_json(self) -> str:
        return json.dumps(self._schema, indent=2, ensure_ascii=False)

    @property
    def schema(self) -> dict:
        return self._schema

# ==============================================================================
# TUI APPLICATION — only instantiated when --tui is passed
# ==============================================================================

class HDLTUIApplication:
    """
    Full-screen 3-pane TUI. Imports heavy prompt_toolkit layout objects here,
    inside __init__, so CLI mode never pays the import cost.
    Gate 4.5: the TUI event loop is completely separate from all CLI _prompt()
    calls. No blocking pt_prompt calls exist inside the async render loop.
    """

    def __init__(self) -> None:
        # ── Deferred heavy imports ─────────────────────────────────────────────
        from prompt_toolkit.application import Application
        from prompt_toolkit.buffer import Buffer
        from prompt_toolkit.document import Document
        from prompt_toolkit.key_binding import KeyBindings
        from prompt_toolkit.layout.containers import (
            HSplit, VSplit, Window, FloatContainer, Float,
        )
        from prompt_toolkit.layout.controls import (
            BufferControl, FormattedTextControl,
        )
        from prompt_toolkit.layout.dimension import D
        from prompt_toolkit.layout.layout import Layout
        from prompt_toolkit.lexers import PygmentsLexer
        from prompt_toolkit.widgets import (
            Frame, RadioList, TextArea, Label,
        )
        from pygments.lexers.data import JsonLexer  # type: ignore

        self._state = HDLTUIState()
        self._Application     = Application
        self._KeyBindings     = KeyBindings
        self._VSplit          = VSplit
        self._HSplit          = HSplit
        self._Window          = Window
        self._D               = D
        self._Layout          = Layout
        self._Frame           = Frame
        self._RadioList       = RadioList
        self._TextArea        = TextArea
        self._FormattedTextControl = FormattedTextControl
        self._BufferControl   = BufferControl
        self._Buffer          = Buffer
        self._Document        = Document
        self._PygmentsLexer   = PygmentsLexer
        self._JsonLexer       = JsonLexer
        self._Label           = Label
        self._FloatContainer  = FloatContainer
        self._Float           = Float
        self._status_text     = "[Tab] Focus  [F2] Randomise  [F5] Export  [Ctrl+Q] Quit"
        self._app: Application | None = None

    def _build_layout(self):
        """Construct the full 3-pane layout."""
        schema      = self._state.schema
        top_keys    = list(schema.keys())

        # ── Navigator (left pane) ──────────────────────────────────────────────
        nav_values  = [(k, k) for k in top_keys]
        self._navigator = self._RadioList(values=nav_values)

        # ── Live JSON output (right pane) ──────────────────────────────────────
        self._json_area = self._TextArea(
            text=self._state.to_json(),
            read_only=True,
            lexer=self._PygmentsLexer(self._JsonLexer),
            scrollbar=True,
            line_numbers=False,
            style="bg:#1e1e2e fg:#cdd6f4",
        )

        # ── Editor pane (centre) — dynamically rebuilt on navigator change ─────
        # We hold a mutable list so the DynamicContainer closure sees updates.
        self._editor_fields: list = []
        self._editor_container = self._HSplit(self._editor_fields)

        self._rebuild_editor(top_keys[0] if top_keys else "")

        # ── Status bar ────────────────────────────────────────────────────────
        self._status_bar = self._Window(
            content=self._FormattedTextControl(lambda: self._status_text),
            height=1, style="reverse",
        )

        body = self._VSplit([
            self._Frame(self._navigator,  title="Navigator",    width=self._D(weight=30)),
            self._Frame(self._editor_container, title="Editor", width=self._D(weight=40)),
            self._Frame(self._json_area,  title="Live JSON",    width=self._D(weight=30)),
        ])

        return self._Layout(
            self._HSplit([body, self._status_bar])
        )

    def _rebuild_editor(self, category_key: str) -> None:
        """Recursively walk category dict and produce TextArea widgets for leaves."""
        self._editor_fields.clear()
        schema = self._state.schema
        if category_key not in schema:
            return

        def _walk(node: Any, path: list[str]) -> None:
            if isinstance(node, dict):
                for k, v in node.items():
                    self._editor_fields.append(
                        self._Label(f" {k}")
                    )
                    _walk(v, path + [k])
            elif isinstance(node, list):
                text_val = ", ".join(node)
                pool     = _pool_for_path(".".join(path))
                ta = self._TextArea(
                    text=text_val,
                    completer=WordCompleter(pool, ignore_case=True),
                    height=2, multiline=False,
                    style="bg:#313244 fg:#cdd6f4",
                )
                captured_path = list(path)

                def _on_change(buf, _path=captured_path) -> None:
                    vals = [v.strip() for v in buf.text.split(",") if v.strip()]
                    self._state.update_val(_path, vals)
                    self._json_area.text = self._state.to_json()

                ta.buffer.on_text_changed += _on_change
                self._editor_fields.append(ta)
            elif isinstance(node, str):
                pool = _pool_for_path(".".join(path))
                ta = self._TextArea(
                    text=node,
                    completer=WordCompleter(pool, ignore_case=True),
                    height=2, multiline=False,
                    style="bg:#313244 fg:#cdd6f4",
                )
                captured_path = list(path)

                def _on_change_str(buf, _path=captured_path) -> None:
                    self._state.update_val(_path, buf.text)
                    self._json_area.text = self._state.to_json()

                ta.buffer.on_text_changed += _on_change_str
                self._editor_fields.append(ta)

        _walk(schema[category_key], [category_key])

        if self._app is not None:
            try:
                self._app.invalidate()
            except Exception:
                pass

    def _build_keybindings(self):
        kb = self._KeyBindings()

        @kb.add("c-q")
        def _exit(event):
            event.app.exit()

        @kb.add("tab")
        def _tab(event):
            event.app.layout.focus_next()

        @kb.add("f2")
        def _randomise(event):
            self._state.randomise()
            top_keys = list(self._state.schema.keys())
            self._rebuild_editor(top_keys[0] if top_keys else "")
            self._json_area.text = self._state.to_json()
            event.app.invalidate()

        @kb.add("f5")
        def _export(event):
            try:
                output_path = "hdl_output.json"
                with open(output_path, "w", encoding="utf-8") as fh:
                    fh.write(self._state.to_json())
                _clipboard_copy(self._state.to_json())
                self._status_text = f"[F5] Exported → {output_path}  [Ctrl+Q] Quit"
            except Exception as exc:
                self._status_text = f"[F5] Export FAILED: {exc}  [Ctrl+Q] Quit"
            event.app.invalidate()

        return kb

    def run(self) -> None:
        layout = self._build_layout()
        kb     = self._build_keybindings()
        self._app = self._Application(
            layout=layout,
            key_bindings=kb,
            full_screen=True,
            mouse_support=True,
            style=CLI_STYLE,
        )
        self._app.run()

# ==============================================================================
# CLIPBOARD HELPER — EAFP, hard timeout, zombie reap (Gate 4.2, 4.4, 4.6)
# ==============================================================================

def _clipboard_copy(text: str) -> None:
    """Attempt wl-copy then xclip; silently skip if neither available."""
    for cmd in (["wl-copy"], ["xclip", "-selection", "clipboard"]):
        try:
            process = subprocess.Popen(
                cmd, stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            try:
                process.communicate(input=text.encode(), timeout=2.0)
                return  # Success — stop trying
            except subprocess.TimeoutExpired:
                process.kill()
                process.communicate()  # Reap zombie
        except FileNotFoundError:
            pass  # Binary not found — try next
    print("  [clipboard] No clipboard utility found (wl-copy / xclip); skipping.")

# ==============================================================================
# OUTPUT HELPERS
# ==============================================================================

def _write_and_print(schema: dict, output_path: str = "hdl_output.json") -> None:
    payload = json.dumps(schema, indent=2, ensure_ascii=False)
    with open(output_path, "w", encoding="utf-8") as fh:
        fh.write(payload)
    _clipboard_copy(payload)
    print()
    print("═" * 72)
    print(f"  ✓  HDL schema written → {output_path}")
    print("═" * 72)
    print()
    print(payload)

# ==============================================================================
# MODE SELECTION MENU
# ==============================================================================

def _mode_menu() -> str:
    print()
    print("═" * 72)
    print("  HDL PROMPT BUILDER")
    print("─" * 72)
    print("  i  interactive  — walk every field with TAB-completion + free input")
    print("  r  random       — generate a complete schema instantly, no prompts")
    print("  h  hybrid       — random seed, then review / override field by field")
    print("  s  stock        — accept block defaults or customise section by section")
    print("─" * 72)
    print("  TAB completes library keys.  Any typed text is accepted verbatim.")
    print("  Ctrl-C exits at any point.")
    print("═" * 72)
    mode = _prompt("Select mode", ["interactive", "random", "hybrid", "stock"],
                   default="interactive")
    return mode.strip().lower()[:1]   # 'i', 'r', 'h', or 's'

# ==============================================================================
# ENTRY POINT
# ==============================================================================

def main() -> None:
    # ── Bifurcate at --tui before any CLI logic runs ───────────────────────────
    if "--tui" in sys.argv:
        HDLTUIApplication().run()
        return

    mode = _mode_menu()

    if mode == "r":
        _header("RANDOM GENERATION")
        n_str = _prompt(
            "Number of panels  (ENTER for random 1–9)",
            lib.PANEL_COUNT_COMPLETIONS, default="",
            hint="optional — leave blank for random",
        )
        seed_str = _prompt(
            "Seed  (ENTER for non-deterministic)",
            [], default="",
            hint="integer seed for reproducibility",
        )
        n    = int(n_str)    if n_str.isdigit()    else None
        seed = int(seed_str) if seed_str.isdigit() else None
        schema = generate_random(n_panels=n, seed=seed)
        _write_and_print(schema)

    elif mode == "h":
        n_str = _prompt(
            "Number of panels for random seed  (ENTER for random 1–9)",
            lib.PANEL_COUNT_COMPLETIONS, default="", hint="optional",
        )
        seed_str = _prompt(
            "Seed  (ENTER for non-deterministic)",
            [], default="", hint="integer seed for reproducibility",
        )
        n    = int(n_str)    if n_str.isdigit()    else None
        seed = int(seed_str) if seed_str.isdigit() else None
        seed_schema = generate_random(n_panels=n, seed=seed)
        schema = run_hybrid(seed_schema)
        _write_and_print(schema)

    elif mode == "s":
        schema = run_stock()
        _write_and_print(schema)

    else:
        schema = run_interactive()
        _write_and_print(schema)


if __name__ == "__main__":
    main()
