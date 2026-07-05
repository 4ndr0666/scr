#!/usr/bin/python3
# ==============================================================================
# HDL PROMPT BUILDER  (hdl_prompt_builder.py)
# Interactive schema constructor — all completion options sourced from promptlib
#
# MODES
#   interactive   Walk every parameter field with TAB-completion + free-text input
#   random        Randomly sample every field from promptlib manifests; no prompts
#   hybrid        Randomly seed each field, then let user review / override live
#   stock         Bypass explicit inputs for standard configurations instantly
#   tui           Full screen persistent asynchronous interface (--tui flag)
#
# MANUAL INPUT
#   At every prompt you may type anything not in the completion list and press
#   ENTER — the value is accepted verbatim.  The completer is advisory only.
# ==============================================================================

import json
import subprocess
import random
import sys
import asyncio
from typing import Any

from prompt_toolkit import prompt as pt_prompt
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.styles import Style

import promptlib as lib

# ==============================================================================
# TERMINAL STYLE
# ==============================================================================
CLI_STYLE = Style.from_dict(
    {
        "prompt": "bold ansicyan",
        "completion-menu.completion": "bg:#1e1e2e fg:#cdd6f4",
        "completion-menu.completion.current": "bg:#89b4fa fg:#1e1e2e bold",
        "scrollbar.background": "bg:#313244",
        "scrollbar.button": "bg:#89b4fa",
    }
)

# ==============================================================================
# STATIC CONFIGURATION BLOCKS
# ==============================================================================
STATIC_MEM_LOCK = {
    "SYSTEM_REFERENCE_INPUT": "INGREDIENT",
    "BIOMETRIC_LOCK": "TRUE (REPLICATING_EVERY_PIXEL_OF_THE_ANITOMALOGICAL_TOPOPGRAPHY_PERFECTLY)",
    "IDENTITY_DRIFT_CONTROL": "MAXIMUM_LOCK (INHIBIT_AUTOMATIC_AI_SKIN-SMOOTHING_FILTERS,_ELIMINATE_FACIAL_BALANCING_OR_SYMMETRY_MODIFICATIONS,_BYPASS_DEFAULT_COMMERCIAL_TOUCH-UP_LAYERS._ENFORE=VISCERAL_REACTION_TO_AN_UNPLEASANT_TASTE,_OPENING_MOUTH_REVEALING_TONGUE_SLATHERED_IN_SEMI_TRANSLUCENT,_MILKY_VISCOUS_GEL--TONGUE_ROLLS;_WINCES)",
    "STRUCTURAL_NON_DEVIATION": "HIGH",
    "STRUCTURAL_FIDELITY": "HIGH",
    "UNALTERABLE": [
        "EXACT_FACIAL_ID_GEOMETRY",
        "TRUE_ORBITAL_BONE_SPACING",
        "UNFILTERED_LIP_PROPORTIONS",
        "RAW_JAWLINE_ANGLE",
        "UN-BEAUTIFIED_FACIAL_BONE_CONTOURS",
        "EXACT_BODY_PROPORTIONS",
        "TRUE_BODYFAT_PERCENTAGE_DISTRIBUTION",
    ],
    "!INHIBIT": [
        "AUTOMATIC_SKIN-SMOOTHING_FILTERS",
        "FACIAL_BALANCING",
        "POSE_MODIFICATIONS",
        "BRAZZIER_SUPPORT",
        "CAMERA_ANGLE_MODIFICATIONS",
        "SYMMETRY_MODIFICATIONS",
        "DEFAULT_COMMERCIAL_TOUCH-UP_LAYERS",
    ],
}

STATIC_FINALIZE = {
    "REQUIREMENT_CHECKS": {
        "FOCUS_LOCK": "MAXIMUM_MICRO-CONTRAST_FOCUS_LOCKED_ONTO_CLOTH_WEAVE_AND_SKIN_GRAIN",
        "GLOBAL_NEGATIVE_BIAS": [
            "BEAUTY_FILTER",
            "AIRBRUSHED_SKIN",
            "PERFECT_FACIAL_SYMMETRY",
            "DIGITAL_3D_RENDER",
            "COMMERCIAL_STOCK_PHOTOGRAPHY_LOOK",
            "WATERMARK_OR_CREDIT_OVERLAY",
            "HAPPY_EXPRESSIONS",
            "IDENTITY_SHIFTING",
            "HAIR_CLEANUP_FLYAWAY",
            "OPAQUE_FABRIC_PROCESSING",
            "BODY_PROPORTION_ALTERATION",
        ],
    }
}

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
    Single-value prompt with TAB word completion AND free-text manual input.
    If skip=True, immediately returns default to bypass interactive fatigue.
    """
    if skip:
        return default

    completer = WordCompleter(completions, ignore_case=True, sentence=True)
    default_hint = f"  ↩ {default}" if default else ""
    hint_str = f"  [{hint}]" if hint else ""
    text = f"  {label}{hint_str}  [Press TAB | Or Type]{default_hint}\n  ❯ "
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
    Multi-value prompt — comma-separated.
    Each token may be a library key OR any free-text string.
    """
    default_str = ", ".join(defaults or [])
    if skip:
        return [v.strip() for v in default_str.split(",") if v.strip()]
        
    raw = _prompt(
        label,
        completions,
        default=default_str,
        hint=f"comma-separated{'; ' + hint if hint else ''}",
        skip=False,
    )
    return [v.strip() for v in raw.split(",") if v.strip()]


def _header(title: str) -> None:
    print()
    print("─" * 72)
    print(f"  {title}")
    print("─" * 72)


def _subheader(title: str) -> None:
    print(f"\n    ┄ {title} ┄")


# ==============================================================================
# RANDOM GENERATION — samples every field independently from promptlib
# ==============================================================================


def _r(pool: list[str]) -> str:
    """Pick one random item from a completion list."""
    return random.choice(pool) if pool else ""


def _r_list(pool: list[str], k_min: int = 1, k_max: int = 4) -> list[str]:
    """Pick a random subset (without replacement) from a completion list."""
    k = random.randint(k_min, min(k_max, len(pool)))
    return random.sample(pool, k)


def generate_random(n_panels: int | None = None) -> dict:
    """
    Build a complete HDL schema by randomly sampling every field from promptlib.
    Enforces strict hierarchy where !ENV_ATMOSPHERICS wraps the execution blocks.
    """
    # ── MEM LOCK (STATIC OVERRIDE) ────────────────────────────────────────────
    mem_lock = STATIC_MEM_LOCK

    # ── ENV ATMOSPHERICS ──────────────────────────────────────────────────────
    env_atmospherics = {
        "LOCATION_SETTING": _r(lib.LOCATION_COMPLETIONS),
        "GLASS_SURFACE_METRICS": _r(lib.GLASS_COMPLETIONS),
        "PARTICULATE_SCATTERING": _r(lib.METEOROLOGY_COMPLETIONS),
        "WIND_VECTOR_FORCE": _r(lib.METEOROLOGY_COMPLETIONS),
        "COMPOSITION_DEPTH": {
            "FOREGROUND": _r(list(lib.DOF_MANIFEST["foreground"].keys())),
            "MIDGROUND": _r(list(lib.DOF_MANIFEST["midground"].keys())),
            "BACKGROUND": _r_list(list(lib.DOF_MANIFEST["background"].keys()), 1, 3),
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
    topo_pool = [
        "unfiltered_hyper_realistic_dermal_detail",
        "high_magnification_sebaceous_follicles",
        "wet_skin_condensation_texture",
        "dry_aged_deep_crease_mapping",
        "sun_damaged_hyperpigmentation",
        "young_unretouched_fine_pore_mapping",
    ]
    bio_dermal = {
        "SKIN_TOPOGRAPHY_LOGIC": _r(topo_pool),
        "SURFACE_MICRO_ELEMENTS": _r(list(lib.SKIN_MANIFEST["surface_micro"].keys())),
        "REFLECTANCE_MAP": _r(list(lib.SKIN_MANIFEST["reflectance"].keys())),
        "EXPRESSION": _r(list(lib.SKIN_MANIFEST["expressions"].keys())),
        "HAIR": _r(list(lib.SKIN_MANIFEST["hair"].keys())),
    }

    # ── ENV PHOTOMETRY ────────────────────────────────────────────────────────
    shutter_pool = [
        "flash_sync_1_60_standard",
        "flash_sync_1_125_standard",
        "flash_sync_1_250_hss",
        "flash_sync_1_500_hss_full_kill",
        "long_exposure_bulb_ambient_bleed",
    ]
    photometry = {
        "STYLE_OF": _r_list(lib.STYLE_COMPLETIONS, 1, 3),
        "HARDWARE_EMULATION": _r(lib.CAMERA_COMPLETIONS),
        "OPTICAL_HARDWARE": _r(lib.LENS_COMPLETIONS),
        "COLOR_SCIENCE_PROFILE": _r(lib.COLOR_COMPLETIONS),
        "OPTICAL_ABERRATIONS": _r(lib.OPTICS_COMPLETIONS),
        "APERTURE_SETTING": _r(lib.APERTURE_COMPLETIONS),
        "SHUTTER_AESTHETIC": _r(shutter_pool),
        "ILLUMINATION_AXIS": _r(lib.LIGHTING_COMPLETIONS),
        "KEY_LIGHT_CHARACTER": _r(lib.LIGHTING_COMPLETIONS),
        "FILL_LIGHT_CHARACTER": _r(lib.LIGHTING_COMPLETIONS),
        "SHADOW_PROFILE": _r(lib.LIGHTING_COMPLETIONS),
        "PHOTONIC_VECTORS": {
            "PHOTONIC_ENERGY": _r(lib.ENERGY_COMPLETIONS),
            "ENERGY_CONSERVATION_COMPLIANT": _r(lib.ENERGY_COMPLETIONS),
            "RIM_LIGHT_SCATTERING_PASS": _r(lib.LEVEL_COMPLETIONS),
            "EPIDERMAL_TRANSLUCENCY_PASS": _r(lib.LEVEL_COMPLETIONS),
            "THROUGH_FABRIC_DIFFUSE_BOUNCE": _r(lib.LEVEL_COMPLETIONS),
            "PHOTON_TRANSMISSION_RATIO": _r(lib.LEVEL_COMPLETIONS),
            "MEAN_FREE_PATH_SCATTERING": _r(lib.LEVEL_COMPLETIONS),
            "BACKLIT_SUBSURFACE_GLOW": _r(lib.LEVEL_COMPLETIONS),
            "FRESNEL_REFLECTION_COEFFICIENT": _r(lib.LEVEL_COMPLETIONS),
            "SPECULAR_HIGHLIGHT_LOBE": _r(lib.LEVEL_COMPLETIONS),
            "LAMBERTIAN_DIFFUSE_REFLECTANCE": _r(lib.LEVEL_COMPLETIONS),
        },
    }

    # ── MATERIAL PHYSICS ──────────────────────────────────────────────────────
    drape_opts = lib.LEVEL_COMPLETIONS
    material = {
        "WARDROBE_SPECIFICATION": _r(lib.WARDROBE_COMPLETIONS),
        "OPACITY": _r(lib.OPACITY_COMPLETIONS),
        "TEXTILE_SURFACE_SHEEN": _r(lib.SHEEN_COMPLETIONS),
        "DRAPE_AND_TENSION_LOGIC": {
            "MICRO_FIBER_DRAPE_PHYSICS": _r(drape_opts),
            "LOW_TENSILE_STRUCTURAL_DEFORMITY": _r(drape_opts),
            "GRAVITY_WEIGHTED_FOLDS": _r(drape_opts),
            "SUB_MICRON_WEAVE_DENSITY": _r(drape_opts),
            "LOW_DENIER_SSS_PASS": _r(["ON", "OFF"]),
            "SURFACE_ADHESION_COEFFICIENT": _r(drape_opts),
            "FULLY_SATURATED_WITH_ATMOSPHERIC_MOISTURE": _r(lib.BOOL_COMPLETIONS),
        },
    }

    # ── TEXT RECON ────────────────────────────────────────────────────────────
    text_recon = {
        "TEXT_STRING_LITERAL": _r(lib.TEXT_STRING_COMPLETIONS),
        "FONTTYPE_AESTHETIC": _r(lib.TEXT_FONT_COMPLETIONS),
        "LAYER_PLACEMENT": _r(lib.TEXT_PLACE_COMPLETIONS),
    }

    # ── FINALIZE (STATIC OVERRIDE) ────────────────────────────────────────────
    finalize = STATIC_FINALIZE

    # ── HIERARCHICAL ASSEMBLY ─────────────────────────────────────────────────
    env_atmospherics["!EXEC_COMPOSITION_MATRIX"] = matrix
    env_atmospherics["!EXEC_BIO_DERMAL_MAP"] = bio_dermal
    env_atmospherics["!ENV_PHOTOMETRY"] = photometry
    env_atmospherics["!EXEC_MATERIAL_PHYSICS"] = material
    env_atmospherics["TEXT_RECON_ENGINE"] = text_recon
    env_atmospherics["!FINALIZE_OUTPUT"] = finalize

    return {
        "!INIT_MEM_LOCK_PROTOCOL": mem_lock,
        "!ENV_ATMOSPHERICS": env_atmospherics,
    }


# ==============================================================================
# INTERACTIVE SECTION BUILDERS
# ==============================================================================


def build_mem_lock() -> dict:
    _header("MEM LOCK PROTOCOL (STATIC COMPLIANCE ENFORCED)")
    return STATIC_MEM_LOCK


def build_env_atmospherics(skip: bool = False) -> dict:
    if not skip: _header("ENV ATMOSPHERICS")
    return {
        "LOCATION_SETTING": _prompt(
            "LOCATION_SETTING",
            lib.LOCATION_COMPLETIONS,
            default="ALL_PROVIDED_INGREDIENTS_ARE_REQUIRED_TO_CREATE_SEVERAL_CINEMATIC_STILLS_ALIGNED_WITH_THE_NUMBER_OF_SELECETED_PANELS--CONTINUITY; TELL_A_SHORT_STORY",
            hint="library key or free description",
            skip=skip,
        ),
        "GLASS_SURFACE_METRICS": _prompt(
            "GLASS_SURFACE_METRICS",
            lib.GLASS_COMPLETIONS,
            default="DUST_PARTICLES_CATCHING_DIRECT_LIGHT_ILLUMINATION",
            hint="library key or free description",
            skip=skip,
        ),
        "PARTICULATE_SCATTERING": _prompt(
            "PARTICULATE_SCATTERING",
            lib.METEOROLOGY_COMPLETIONS,
            default="MIE_SCATTERING_DENSE_FOG",
            hint="meteorology key or free description",
            skip=skip,
        ),
        "WIND_VECTOR_FORCE": _prompt(
            "WIND_VECTOR_FORCE",
            lib.METEOROLOGY_COMPLETIONS,
            default="WIND_VELOCITY_HIGH_TURBULENT",
            hint="meteorology key or free description",
            skip=skip,
        ),
        "COMPOSITION_DEPTH": {
            "FOREGROUND": _prompt(
                "FOREGROUND",
                list(lib.DOF_MANIFEST["foreground"].keys()),
                default="SHALLOW_DEPTH_OF_FIELD_TO_CREATE_A_FILM_LIKE_DRAMATIC_STYLE",
                hint="DOF/foreground",
                skip=skip,
            ),
            "MIDGROUND": _prompt(
                "MIDGROUND",
                list(lib.DOF_MANIFEST["midground"].keys()),
                default="SHE_IS_POSING_FOR_THE_CAMERA",
                hint="subject action",
                skip=skip,
            ),
            "BACKGROUND": _prompt_list(
                "BACKGROUND",
                list(lib.DOF_MANIFEST["background"].keys()),
                defaults=[
                    "STUDIO",
                    "SINGLE_LIGHT_SOURCE",
                    "POWERFUL_SPOTLIGHT",
                    "TOTAL_DARKNESS",
                    "MIRRORED_WALLS_AND_TILES",
                    "HIGH_REFLECTANCE"
                ],
                hint="environment",
                skip=skip,
            ),
        },
    }


def build_panel(index: int, skip: bool = False) -> dict:
    if not skip: _subheader(f"Panel {index}")
    angle = _prompt(
        f"Panel {index} — camera angle / view label",
        lib.VIEW_COMPLETIONS,
        default="MEDIUM CLOSE-UP (MCU)",
        hint="view",
        skip=skip,
    )
    kinetic = _prompt(
        f"Panel {index} — kinetic / pose",
        lib.POSE_COMPLETIONS,
        default="supine_flat",
        hint="pose",
        skip=skip,
    )
    return {angle: kinetic}


def build_composition_matrix(skip: bool = False) -> dict:
    if not skip: _header("COMPOSITION MATRIX")

    layout_choice = _prompt(
        "Layout preset  (ENTER to skip and define panels manually)",
        lib.LAYOUT_COMPLETIONS,
        default="",
        hint="optional preset",
        skip=skip,
    )

    if layout_choice and layout_choice in lib.FLAT_LAYOUT_INDEX:
        for _cat in lib.LAYOUT_MANIFEST.values():
            if layout_choice in _cat:
                preset = _cat[layout_choice]
                break
        n_panels = int(preset.get("PANELS", "4"))
        matrix: dict = {"LAYOUT_PRESET": layout_choice, "PANELS": str(n_panels)}
    else:
        n_str = _prompt(
            "Number of panels",
            lib.PANEL_COUNT_COMPLETIONS,
            default="4",
            hint="1–9 or type a number",
            skip=skip,
        )
        try:
            n_panels = int(n_str)
        except ValueError:
            if not skip: print(f"  [!] '{n_str}' is not a valid integer — defaulting to 4")
            n_panels = 4
        matrix = {"PANELS": str(n_panels)}

    for i in range(1, n_panels + 1):
        matrix.update(build_panel(i, skip=skip))

    return matrix

