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
import asyncio
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
    "IDENTITY_DRIFT_CONTROL": "MAXIMUM_LOCK (INHIBIT_AUTOMATIC_AI_SKIN-SMOOTHING_FILTERS,_ELIMINATE_FACIAL_BALANCING_OR_SYMMETRY_MODIFICATIONS,_BYPASS_DEFAULT_COMMERCIAL_TOUCH-UP_LAYERS.)",
    "STRUCTURAL_NON_DEVIATION": "HIGH",
    "STRUCTURAL_FIDELITY": "HIGH",
    "UNALTERABLE": [
        "EXACT_FACIAL_ID_GEOMETRY",
        "UN-BEAUTIFIED_FACIAL_BONE_CONTOURS",
        "EXACT_BODY_PROPORTIONS",
        "TRUE_BODYFAT_PERCENTAGE_DISTRIBUTION"
    ],
    "!INHIBIT": [
        "AUTOMATIC_SKIN-SMOOTHING_FILTERS",
        "FACIAL_BALANCING",
        "DEFAULT_COMMERCIAL_TOUCH-UP_LAYERS"
    ]
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
            "BODY_PROPORTION_ALTERATION"
        ]
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
    """Pick one random item from a completion list."""
    return random.choice(pool) if pool else ""


def _r_list(pool: list[str], k_min: int = 1, k_max: int = 4) -> list[str]:
    k = random.randint(k_min, min(k_max, len(pool)))
    return random.sample(pool, k)


def generate_random(n_panels: int | None = None, seed: int | None = None) -> dict:
    """
    Build a complete HDL schema by randomly sampling every field from promptlib.
    STATIC_MEM_LOCK and STATIC_FINALIZE are injected verbatim — never randomised.
    seed: optional integer for reproducible output.

    Schema nesting follows the required HDL spec: ALL execution blocks
    (!EXEC_COMPOSITION_MATRIX, !EXEC_BIO_DERMAL_MAP, !ENV_PHOTOMETRY,
    !EXEC_MATERIAL_PHYSICS, TEXT_RECON_ENGINE, !FINALIZE_OUTPUT) are nested
    INSIDE !ENV_ATMOSPHERICS, not at the top level.
    """
    if seed is not None:
        random.seed(seed)

    # ── PANELS ────────────────────────────────────────────────────────────────
    if n_panels is None:
        n_panels = random.randint(1, 9)

    # Panel values: ECU/macro panels get list descriptors; others get a pose key.
    # This mirrors the required schema where some panels carry multi-element lists.
    _macro_views = {
        "INSERT MACRO DETAIL (IMD)",
        "EXTREME MACRO DETAIL (XMD)",
        "HAND DETAIL MACRO (HDM)",
    }
    _list_views = {
        "SIDE CLOSE-UP (SCU)",
        "THREE_QUARTER DRAMATIC HIGH ANGLE (TQDH)",
        "FRONT EXTREME CLOSE-UP (ECU/XCU)",
        "FRONT EXTREME CLOSE-UP MACRO(ECUM/XCUM)",
    }

    matrix: dict[str, Any] = {"PANELS": str(n_panels)}
    used_views: set[str] = set()
    for _ in range(n_panels):
        remaining = [v for v in lib.VIEW_COMPLETIONS if v not in used_views]
        view = _r(remaining if remaining else lib.VIEW_COMPLETIONS)
        used_views.add(view)
        if view in _macro_views:
            matrix[view] = _r_list(lib.POSE_COMPLETIONS, 2, 4)
        elif view in _list_views:
            matrix[view] = _r_list(lib.POSE_COMPLETIONS, 2, 3)
        else:
            matrix[view] = _r(lib.POSE_COMPLETIONS)

    # ── BIO DERMAL MAP ────────────────────────────────────────────────────────
    bio_dermal = {
        "SKIN_TOPOGRAPHY_LOGIC": _r(lib.TOPO_COMPLETIONS),
        "SURFACE_MICRO_ELEMENTS": _r(list(lib.SKIN_MANIFEST["surface_micro"].keys())),
        "REFLECTANCE_MAP": _r(list(lib.SKIN_MANIFEST["reflectance"].keys())),
        "EXPRESSION": _r(list(lib.SKIN_MANIFEST["expressions"].keys())),
        "HAIR": _r(list(lib.SKIN_MANIFEST["hair"].keys())),
    }

    # ── ENV PHOTOMETRY ────────────────────────────────────────────────────────
    photometry = {
        "STYLE_OF": _r_list(lib.STYLE_COMPLETIONS, 1, 3),
        "HARDWARE_EMULATION": _r(lib.CAMERA_COMPLETIONS),
        "OPTICAL_HARDWARE": _r(lib.LENS_COMPLETIONS),
        "COLOR_SCIENCE_PROFILE": _r(lib.COLOR_COMPLETIONS),
        "OPTICAL_ABERRATIONS": _r(lib.OPTICS_COMPLETIONS),
        "APERTURE_SETTING": _r(lib.APERTURE_COMPLETIONS),
        "SHUTTER_AESTHETIC": _r(lib.SHUTTER_COMPLETIONS),
        "ILLUMINATION_AXIS": _r(lib.LIGHTING_COMPLETIONS),
        "KEY_LIGHT_CHARACTER": _r(lib.LIGHTING_COMPLETIONS),
        "FILL_LIGHT_CHARACTER": _r(lib.LIGHTING_COMPLETIONS),
        "SHADOW_PROFILE": _r(lib.LIGHTING_COMPLETIONS),
        "PHOTONIC_VECTORS": {
            "PHOTONIC_ENERGY": _r(lib.ENERGY_COMPLETIONS),
            "ENERGY_CONSERVATION_COMPLIANT": "TRANSPARENCY-FOCUSED",
            "RIM_LIGHT_SCATTERING_PASS": _r(["TRUE", "FALSE"]),
            "EPIDERMAL_TRANSLUCENCY_PASS": _r(["TRUE", "FALSE"]),
            "THROUGH_FABRIC_DIFFUSE_BOUNCE": _r(["TRUE", "FALSE"]),
            "PHOTON_TRANSMISSION_RATIO": _r(lib.LEVEL_COMPLETIONS),
            "MEAN_FREE_PATH_SCATTERING": _r(lib.LEVEL_COMPLETIONS),
            "BACKLIT_SUBSURFACE_GLOW": _r(lib.LEVEL_COMPLETIONS),
            "FRESNEL_REFLECTION_COEFFICIENT": _r(lib.LEVEL_COMPLETIONS),
            "SPECULAR_HIGHLIGHT_LOBE": _r(lib.LEVEL_COMPLETIONS),
            "LAMBERTIAN_DIFFUSE_REFLECTANCE": _r(lib.LEVEL_COMPLETIONS),
        },
    }

    ray_tracing = {
        "LIGHT_SOURCE_01": _r(lib.RAY_SOURCE_COMPLETIONS),
        "ORIGIN_COORDINATE": _r(lib.RAY_COORD_COMPLETIONS),
        "TARGET_COORDINATE": _r(lib.RAY_COORD_COMPLETIONS),
        "BEAM_ANGLE": _r(lib.RAY_ANGLE_COMPLETIONS),
        "LUMINOUS_INTENSITY": _r(lib.RAY_INTENSITY_COMPLETIONS),
        "FALLOFF_PROFILE": _r(lib.RAY_FALLOFF_COMPLETIONS),
        "BOUNCE_LIGHT_LOGIC": _r(lib.RAY_BOUNCE_COMPLETIONS),
    }

    material = {
        "WARDROBE_SPECIFICATION": _r(lib.WARDROBE_COMPLETIONS),
        "OPACITY": _r(lib.OPACITY_COMPLETIONS),
        "TEXTILE_SURFACE_SHEEN": _r(lib.SHEEN_COMPLETIONS),
        "DRAPE_AND_TENSION_LOGIC": {
            "MICRO_FIBER_DRAPE_PHYSICS": _r(lib.LEVEL_COMPLETIONS),
            "LOW_TENSILE_STRUCTURAL_DEFORMITY": _r(lib.LEVEL_COMPLETIONS),
            "GRAVITY_WEIGHTED_FOLDS": _r(lib.LEVEL_COMPLETIONS),
            "SUB_MICRON_WEAVE_DENSITY": _r(lib.LEVEL_COMPLETIONS),
            "LOW_DENIER_SSS_PASS": _r(["ON", "OFF"]),
            "SURFACE_ADHESION_COEFFICIENT": _r(lib.LEVEL_COMPLETIONS),
            "FULLY_SATURATED_WITH_ATMOSPHERIC_MOISTURE": _r(lib.BOOL_COMPLETIONS),
        },
    }

    # ── TEXT RECON ────────────────────────────────────────────────────────────
    text_recon = {
        "TEXT_STRING_LITERAL": _r(lib.TEXT_STRING_COMPLETIONS),
        "FONTTYPE_AESTHETIC": _r(lib.TEXT_FONT_COMPLETIONS),
        "LAYER_PLACEMENT": _r(lib.TEXT_PLACE_COMPLETIONS),
    }

    # ── ASSEMBLE — all execution blocks nest inside !ENV_ATMOSPHERICS ─────────
    env_atmospherics = {
        "LOCATION_SETTING": _r(lib.LOCATION_COMPLETIONS),
        "GLASS_SURFACE_METRICS": _r(lib.GLASS_COMPLETIONS),
        "PARTICULATE_SCATTERING": _r(lib.METEOROLOGY_COMPLETIONS),
        "WIND_VECTOR_FORCE": _r(lib.METEOROLOGY_COMPLETIONS),
        "COMPOSITION_DEPTH": {
            "FOREGROUND": _r(list(lib.DOF_MANIFEST["foreground"].keys())),
            "MIDGROUND": _r(list(lib.DOF_MANIFEST["midground"].keys())),
            # BACKGROUND is a list per required schema
            "BACKGROUND": _r_list(list(lib.DOF_MANIFEST["background"].keys()), 2, 5),
        },
        "!EXEC_COMPOSITION_MATRIX": matrix,
        "!EXEC_BIO_DERMAL_MAP": bio_dermal,
        "!ENV_PHOTOMETRY": photometry,
        "!ENV_RAY_TRACING_PHOTOMETRY": ray_tracing,
        "!EXEC_MATERIAL_PHYSICS": material,
        "TEXT_RECON_ENGINE": text_recon,
        "!FINALIZE_OUTPUT": copy.deepcopy(STATIC_FINALIZE),
    }

    return {
        "!INIT_MEM_LOCK_PROTOCOL": copy.deepcopy(STATIC_MEM_LOCK),
        "!ENV_ATMOSPHERICS": env_atmospherics,
    }


# ==============================================================================
# INTERACTIVE SECTION BUILDERS
# ==============================================================================

def build_mem_lock() -> dict:
    _header("MEM LOCK PROTOCOL (STATIC COMPLIANCE ENFORCED)")
    return copy.deepcopy(STATIC_MEM_LOCK)

def build_env_atmospherics(skip: bool = False) -> dict:
    if not skip:
        _header("ENV ATMOSPHERICS")
    return {
        "LOCATION_SETTING": _prompt(
            "LOCATION_SETTING",
            lib.LOCATION_COMPLETIONS,
            default="COMPACT_TILED_RESIDENTIAL_BATHROOM_WITH_VANITY_MIRROR",
            hint="library key or free description",
            skip=skip,
        ),
        "GLASS_SURFACE_METRICS": _prompt(
            "GLASS_SURFACE_METRICS",
            lib.GLASS_COMPLETIONS,
            default="PRISTINE,_HIGH_REFLECTANCE,_LIPSTICK_WRITING_MATCHING_UPLOADED_IMAGE_TEXT",
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
                default="SEATED_CASUALLY_ON_BATHROOM_COUNTER,_LEANING_FORWARD_TOWARD_MIRROR,_LEGS_RELAXED_OR_CROSSED",
                hint="subject action",
                skip=skip,
            ),
            # BACKGROUND is a list per required schema spec
            "BACKGROUND": _prompt_list(
                "BACKGROUND",
                list(lib.DOF_MANIFEST["background"].keys()),
                defaults=[
                    "COMPACT_TILED_RESIDENTIAL_BATHROOM_WITH_VANITY_MIRROR",
                    "INTIMATE_LATE-NIGHT_PRIVATE_MOMENT",
                    "FULLY_SATURATED_WITH_ATMOSPHERIC_MOISTURE",
                    "HIGH_COEFFICIENT_OF_SURFACE_ADHESION_AND_INVERSE_OPACITY",
                    "CLUTTERED_COUNTER_WITH_COSMETICS,_BRUSHES,_TOILETRIES"
                ],
                hint="comma-separated environment tokens",
                skip=skip,
            ),
        },
    }

_MACRO_VIEWS = {
    "INSERT MACRO DETAIL (IMD)",
    "EXTREME MACRO DETAIL (XMD)",
    "HAND DETAIL MACRO (HDM)",
}
_LIST_VIEWS = {
    "SIDE CLOSE-UP (SCU)",
    "THREE_QUARTER DRAMATIC HIGH ANGLE (TQDH)",
    "FRONT EXTREME CLOSE-UP (ECU/XCU)",
    "FRONT EXTREME CLOSE-UP MACRO(ECUM/XCUM)",
}


def build_panel(index: int, skip: bool = False) -> dict:
    """
    Build one panel entry. Macro and angled views produce list values matching
    the required schema spec; all other views produce a single string value.
    Dynamically maps defaults based on the sequential index.
    """
    if not skip:
        _subheader(f"Panel {index}")

    # Map index to default canonical angle
    default_angles = {
        1: "FRONT MEDIUM CLOSE-UP (MCU)",
        2: "BIRDS EYE (BE)",
        3: "FRONT EXTREME CLOSE-UP (ECU/XCU)",
        4: "SIDE CLOSE-UP (SCU)",
        5: "THREE_QUARTER DRAMATIC HIGH ANGLE (TQDH)",
        6: "FRONT EXTREME CLOSE-UP MACRO(ECUM/XCUM)",
    }

    # Map index to default canonical pose/descriptors
    default_poses = {
        1: "LITHOTOMY_POSITION",
        2: "AERIAL_VIEW,_SLIGHTLY_IN_FRONT_OF_SUBJECT_LOOKING_DOWNWARD",
        3: ["FULL_LENGTH_OF_RIB_CAGE", "FINE_DETAILS", "FABRIC_WEAVE", "RAZOR_SHARP_FOCUS_ON_TEXTURED_SKIN"],
        4: ["~45°_ROTATED_CLOCKWISE", "CHEST_LEVEL", "SLIGHTLY_TILTED_DOWNWARD"],
        5: ["~45°_ROTATED_CLOCKWISE_AND_SLIGHTLY_TILTED_DOWNWARD_FROM_8FT"],
        6: ["FULL_LENGTH_OF_RIB_CAGE", "FABRIC_WEAVE", "RAZOR-SHARP_FOCUS_ON_GLISTENING_SWEATBEADS_AND_TEXTURED_SKIN", "SHALLOW_DEPTH_OF_FIELD", "100mm_MACRO_LENS_AT_f/2.8"],
    }

    # Fallbacks for panels generated beyond the canonical 6
    def_angle = default_angles.get(index, "FRONT MEDIUM CLOSE-UP (MCU)")
    def_pose = default_poses.get(index, "LITHOTOMY_POSITION")

    angle = _prompt(
        f"Panel {index} — camera angle / view label",
        lib.VIEW_COMPLETIONS,
        default=def_angle,
        hint="view",
        skip=skip,
    )

    if angle in _MACRO_VIEWS or angle in _LIST_VIEWS:
        # Provide sensible defaults if user switched angle away from the canonical index default
        if isinstance(def_pose, list):
            pose_default_list = def_pose
        else:
            pose_default_list = [def_pose]

        value = _prompt_list(
            f"Panel {index} — descriptors",
            lib.POSE_COMPLETIONS,
            defaults=pose_default_list,
            hint="comma-separated detail tokens or pose keys",
            skip=skip,
        )
    else:
        # If the default pose was a list but the view is now scalar, grab the first element
        if isinstance(def_pose, list):
            pose_default_str = def_pose[0]
        else:
            pose_default_str = def_pose

        value = _prompt(
            f"Panel {index} — kinetic / pose",
            lib.POSE_COMPLETIONS,
            default=pose_default_str,
            hint="pose",
            skip=skip,
        )

    return {angle: value}


def build_composition_matrix(skip: bool = False) -> dict:
    """
    If skip=True, return the canonical 6-panel default layout per required schema.
    Panel values mirror the spec: macro/angled views carry lists of descriptors.
    """
    if skip:
        return {
            "LAYOUT_PRESET": "LAYOUT: SIX_PANEL_COMPOSITE",
            "PANELS": "6",
            "FRONT MEDIUM CLOSE-UP (MCU)": "LITHOTOMY_POSITION",
            "BIRDS EYE (BE)": "AERIAL_VIEW,_SLIGHTLY_IN_FRONT_OF_SUBJECT_LOOKING_DOWNWARD",
            "FRONT EXTREME CLOSE-UP (ECU/XCU)": [
                "FULL_LENGTH_OF_RIB_CAGE",
                "FINE_DETAILS",
                "FABRIC_WEAVE",
                "RAZOR_SHARP_FOCUS_ON_TEXTURED_SKIN"
            ],
            "SIDE CLOSE-UP (SCU)": [
                "~45°_ROTATED_CLOCKWISE",
                "CHEST_LEVEL",
                "SLIGHTLY_TILTED_DOWNWARD"
            ],
            "THREE_QUARTER DRAMATIC HIGH ANGLE (TQDH)": [
                "~45°_ROTATED_CLOCKWISE_AND_SLIGHTLY_TILTED_DOWNWARD_FROM_8FT"
            ],
            "FRONT EXTREME CLOSE-UP MACRO(ECUM/XCUM)": [
                "FULL_LENGTH_OF_RIB_CAGE",
                "FABRIC_WEAVE",
                "RAZOR-SHARP_FOCUS_ON_GLISTENING_SWEATBEADS_AND_TEXTURED_SKIN",
                "SHALLOW_DEPTH_OF_FIELD",
                "100mm_MACRO_LENS_AT_f/2.8"
            ]
        }

    _header("COMPOSITION MATRIX")

    layout_choice = _prompt(
        "Layout preset  (ENTER to skip and define panels manually)",
        lib.LAYOUT_COMPLETIONS,
        default="",
        hint="optional preset",
    )

    if layout_choice and layout_choice in lib.FLAT_LAYOUT_INDEX:
        preset = lib.FLAT_LAYOUT_INDEX[layout_choice]
        n_panels = int(preset.get("PANELS", "6"))
        matrix = {"LAYOUT_PRESET": layout_choice, "PANELS": str(n_panels)}
    else:
        n_str = _prompt(
            "Number of panels",
            lib.PANEL_COUNT_COMPLETIONS,
            default="6",
            hint="1–9 or type a number",
        )
        try:
            n_panels = int(n_str)
        except ValueError:
            print(f"  [!] '{n_str}' is not a valid integer — defaulting to 6")
            n_panels = 6
        matrix = {"PANELS": str(n_panels)}

    for i in range(1, n_panels + 1):
        matrix.update(build_panel(i))

    return matrix


def build_bio_dermal_map(skip: bool = False) -> dict:
    if not skip:
        _header("BIO DERMAL MAP")
    return {
        "SKIN_TOPOGRAPHY_LOGIC": _prompt(
            "SKIN_TOPOGRAPHY_LOGIC",
            lib.TOPO_COMPLETIONS,
            default="UNFILTERED_HUMAN_SKIN_TEXTURE_SHOWING_HYPER_REALISTIC_DETAILS",
            hint="topology or free description",
            skip=skip,
        ),
        "SURFACE_MICRO_ELEMENTS": _prompt(
            "SURFACE_MICRO_ELEMENTS",
            list(lib.SKIN_MANIFEST["surface_micro"].keys()),
            default="TRUE_VISIBLE_DERMAL_PORES,_FINE_GOOSEBUMPS_ON_ARMS,_MICRO_SWEATBEADS_CATCHING_SPECULAR_HIGHLIGHTS,_NATURAL_SKIN_FOLDS,_RAW_UN-AIRBRUSED_COMPLEXION",
            hint="micro elements",
            skip=skip,
        ),
        "REFLECTANCE_MAP": _prompt(
            "REFLECTANCE_MAP",
            list(lib.SKIN_MANIFEST["reflectance"].keys()),
            default="HIGH_SPECULAR_GLISTEN_ON_DAMP_SKIN_TISSUE_INTERACTING_DIRECTLY_WITH_THE_HARSH_FLASH_RAYS",
            hint="reflectance",
            skip=skip,
        ),
        "EXPRESSION": _prompt(
            "EXPRESSION",
            list(lib.SKIN_MANIFEST["expressions"].keys()),
            default="DETACHED,_REVULSION,_HER_TONGUE_IS_VISIBLE,_LICKING_HER_FINGER_CLEAN,_GLOSSY_LIPS,_DETAILED_SALIVA,_GAZE_FIXED_STEADILY_ON_REFLECTION_OR_CAMERA",
            hint="expression",
            skip=skip,
        ),
        "HAIR": _prompt(
            "HAIR",
            list(lib.SKIN_MANIFEST["hair"].keys()),
            default="PAINT_LADEN,_DISHEVELED",
            hint="hair state",
            skip=skip,
        ),
    }


def build_env_photometry(skip: bool = False) -> dict:
    if not skip:
        _header("ENV PHOTOMETRY")

    def _level(label: str, default: str = "MEDIUM") -> str:
        return _prompt(
            label,
            lib.LEVEL_COMPLETIONS,
            default=default,
            hint="HIGH/MEDIUM/LOW/ULTRA/OFF or free text",
            skip=skip,
        )

    return {
        "STYLE_OF": _prompt_list(
            "STYLE_OF",
            lib.STYLE_COMPLETIONS,
            defaults=["HELMUT_NEWTON"],
            hint="photographer style(s)",
            skip=skip,
        ),
        "HARDWARE_EMULATION": _prompt(
            "HARDWARE_EMULATION",
            lib.CAMERA_COMPLETIONS,
            default="FULL-FRAME_DSLR_SENSOR_CAMERA",
            hint="camera body or free description",
            skip=skip,
        ),
        "OPTICAL_HARDWARE": _prompt(
            "OPTICAL_HARDWARE",
            lib.LENS_COMPLETIONS,
            default="Canon EOS 5D Mark IV and a Canon EF 100mm",
            hint="lens or free description",
            skip=skip,
        ),
        "COLOR_SCIENCE_PROFILE": _prompt(
            "COLOR_SCIENCE_PROFILE",
            lib.COLOR_COMPLETIONS,
            default="ARRI_LogC4_AWG4",
            hint="cinema profile",
            skip=skip,
        ),
        "OPTICAL_ABERRATIONS": _prompt(
            "OPTICAL_ABERRATIONS",
            lib.OPTICS_COMPLETIONS,
            default="ANAMORPHIC_2X_SQUEEZE_BLUE_STREAK",
            hint="lens flaws",
            skip=skip,
        ),
        "APERTURE_SETTING": _prompt(
            "APERTURE_SETTING",
            lib.APERTURE_COMPLETIONS,
            default="f/2.8L (ENSURING_DEEP_TECHNICAL_SHARPNESS_ACROSS_BOTH_THE_FOREGROUND_AND_THE_MIDGROUND_SUBJECT_DETAILS",
            hint="f-stop or free text",
            skip=skip,
        ),
        "SHUTTER_AESTHETIC": _prompt(
            "SHUTTER_AESTHETIC",
            lib.SHUTTER_COMPLETIONS,
            default="Macro IS USM",
            hint="sync mode or free description",
            skip=skip,
        ),
        "ILLUMINATION_AXIS": _prompt(
            "ILLUMINATION_AXIS",
            lib.LIGHTING_COMPLETIONS,
            default="SINGLE_SOURCE,_HARD_ON-CAMERA_POP-UP_FLASH_ALIGNED_PARALLEL_TO_THE_LENS_AXIS",
            hint="light source or free description",
            skip=skip,
        ),
        "KEY_LIGHT_CHARACTER": _prompt(
            "KEY_LIGHT_CHARACTER",
            lib.LIGHTING_COMPLETIONS,
            default="INTENSE_DIRECT_5500K_CAMERA_FLASH_LUMINOSITY_(FORCING_CENTRAL_OVEREXPOSURE_BLOWOUT,_STARK_WHITE_SPECULAR_HIGHLIGHTS_ON_REFLECTIVE_SURFACES,_AND_AGGRESSIVE_INVERSE-SQUARE_FALLOFF",
            hint="key light",
            skip=skip,
        ),
        "FILL_LIGHT_CHARACTER": _prompt(
            "FILL_LIGHT_CHARACTER",
            lib.LIGHTING_COMPLETIONS,
            default="DIM_AMBIENT_TUNGSTEN_GLOW,_3200K_COLOR_TEMPERATURE_(RATIO: 0.04,_RESTRICTED_TO_THE_DEEP_BACKGROUND_RECESSES)",
            hint="fill light",
            skip=skip,
        ),
        "SHADOW_PROFILE": _prompt(
            "SHADOW_PROFILE",
            lib.LIGHTING_COMPLETIONS,
            default="RAZOR-SHARP,_JET-BLACK_DROP_SHADOWS_DIRECTLY_BEHIND_PHYSICAL_SUBJECT_CONTOURS_WITH_ZERO_PENUMBRA_BLENDING",
            hint="shadow character",
            skip=skip,
        ),
        "PHOTONIC_VECTORS": {
            "PHOTONIC_ENERGY": _prompt(
                "PHOTONIC_ENERGY",
                lib.ENERGY_COMPLETIONS,
                default="SUBSURFACE_SCATTERING",
                skip=skip,
            ),
            "ENERGY_CONSERVATION_COMPLIANT": _prompt(
                "ENERGY_CONSERVATION_COMPLIANT",
                lib.ENERGY_COMPLETIONS,
                default="TRANSPARENCY-FOCUSED",
                skip=skip,
            ),
            "RIM_LIGHT_SCATTERING_PASS": _level("RIM_LIGHT_SCATTERING_PASS", "TRUE"),
            "EPIDERMAL_TRANSLUCENCY_PASS": _level(
                "EPIDERMAL_TRANSLUCENCY_PASS", "TRUE"
            ),
            "THROUGH_FABRIC_DIFFUSE_BOUNCE": _level(
                "THROUGH_FABRIC_DIFFUSE_BOUNCE", "TRUE"
            ),
            "PHOTON_TRANSMISSION_RATIO": _level("PHOTON_TRANSMISSION_RATIO", "HIGH"),
            "MEAN_FREE_PATH_SCATTERING": _level("MEAN_FREE_PATH_SCATTERING", "MEDIUM"),
            "BACKLIT_SUBSURFACE_GLOW": _level("BACKLIT_SUBSURFACE_GLOW", "MEDIUM"),
            "FRESNEL_REFLECTION_COEFFICIENT": _level(
                "FRESNEL_REFLECTION_COEFFICIENT", "LOW"
            ),
            "SPECULAR_HIGHLIGHT_LOBE": _level("SPECULAR_HIGHLIGHT_LOBE", "LOW"),
            "LAMBERTIAN_DIFFUSE_REFLECTANCE": _level(
                "LAMBERTIAN_DIFFUSE_REFLECTANCE", "LOW"
            ),
        },
    }

def build_ray_tracing_photometry(skip: bool = False) -> dict:
    if not skip:
        _header("ENV RAY TRACING PHOTOMETRY")
    return {
        "LIGHT_SOURCE_01": _prompt("LIGHT_SOURCE_01", lib.RAY_SOURCE_COMPLETIONS, default="SINGLE_CONICAL_SPOTLIGHT", skip=skip),
        "ORIGIN_COORDINATE": _prompt("ORIGIN_COORDINATE", lib.RAY_COORD_COMPLETIONS, default="2.50,-4.50,16.00", skip=skip),
        "TARGET_COORDINATE": _prompt("TARGET_COORDINATE", lib.RAY_COORD_COMPLETIONS, default="-0.04,5.67,2.39", skip=skip),
        "BEAM_ANGLE": _prompt("BEAM_ANGLE", lib.RAY_ANGLE_COMPLETIONS, default="28_DEGREE_FOCUS", skip=skip),
        "LUMINOUS_INTENSITY": _prompt("LUMINOUS_INTENSITY", lib.RAY_INTENSITY_COMPLETIONS, default="110_PERCENT_SCALE", skip=skip),
        "FALLOFF_PROFILE": _prompt("FALLOFF_PROFILE", lib.RAY_FALLOFF_COMPLETIONS, default="AGGRESSIVE_INVERSE_SQUARE", skip=skip),
        "BOUNCE_LIGHT_LOGIC": _prompt("BOUNCE_LIGHT_LOGIC", lib.RAY_BOUNCE_COMPLETIONS, default="INFINITE_RECURSIVE_REFLECTION", skip=skip)
    }

def build_material_physics(skip: bool = False) -> dict:
    if not skip:
        _header("MATERIAL PHYSICS")
    drape_opts = lib.LEVEL_COMPLETIONS
    sss_opts = ["ON", "OFF"] + lib.LEVEL_COMPLETIONS
    return {
        "WARDROBE_SPECIFICATION": _prompt(
            "WARDROBE_SPECIFICATION",
            lib.WARDROBE_COMPLETIONS,
            default="REALISTIC_SINGLE-LAYER_MATERIALS,_LOW-DENNIER,_WHITE_VINTAGE_SLIK_SLIP_DRESS_WITH_RAW_LACE_BORDER_TRIM_ALONG_THE_NEXT",
            hint="wardrobe key or free description",
            skip=skip,
        ),
        "OPACITY": _prompt(
            "OPACITY",
            lib.OPACITY_COMPLETIONS,
            default="FABRIC_TRANSPARENCY_SCALES_DYNAMICALLY_WITH_TENSION;_MATERIAL_SHIFTS_FROM_OPAQUE_WHIRE_TO_A_SEMI-TRANSLUCENT_APLHA_LAYER_WHERE_STRETCHED_TIGHT_ACROSS_PHYSICAL_PEAKS,_REVEALING_THE_MUTED_SKIN_TONES_UNDERNEATH",
            skip=skip,
        ),
        "TEXTILE_SURFACE_SHEEN": _prompt(
            "TEXTILE_SURFACE_SHEEN",
            lib.SHEEN_COMPLETIONS,
            default="ANSIOTROPIC_SILK_REFLECTION_MAPPING_DIRECT_FLASH_GLARE_ALONG_TIGHT_FABRIC_FOLDS_AND_FINE_MICRO-WRINKLES",
            skip=skip,
        ),
        "DRAPE_AND_TENSION_LOGIC": {
            "MICRO_FIBER_DRAPE_PHYSICS": _prompt(
                "MICRO_FIBER_DRAPE_PHYSICS", drape_opts, default="HIGH", skip=skip
            ),
            "LOW_TENSILE_STRUCTURAL_DEFORMITY": _prompt(
                "LOW_TENSILE_STRUCTURAL_DEFORMITY",
                drape_opts,
                default="MEDIUM",
                skip=skip,
            ),
            "GRAVITY_WEIGHTED_FOLDS": _prompt(
                "GRAVITY_WEIGHTED_FOLDS", drape_opts, default="LOW", skip=skip
            ),
            "SUB_MICRON_WEAVE_DENSITY": _prompt(
                "SUB_MICRON_WEAVE_DENSITY", drape_opts, default="LOW", skip=skip
            ),
            "LOW_DENIER_SSS_PASS": _prompt(
                "LOW_DENIER_SSS_PASS", sss_opts, default="ON", skip=skip
            ),
            "SURFACE_ADHESION_COEFFICIENT": _prompt(
                "SURFACE_ADHESION_COEFFICIENT", drape_opts, default="HIGH", skip=skip
            ),
            "FULLY_SATURATED_WITH_ATMOSPHERIC_MOISTURE": _prompt(
                "FULLY_SATURATED_WITH_ATMOSPHERIC_MOISTURE",
                lib.BOOL_COMPLETIONS,
                default="TRUE",
                skip=skip,
            ),
        },
    }

def build_text_recon(skip: bool = False) -> dict:
    if not skip:
        _header("TEXT RECON ENGINE")
    return {
        "TEXT_STRING_LITERAL": _prompt(
            "TEXT_STRING_LITERAL",
            lib.TEXT_STRING_COMPLETIONS,
            default="NO_TEXT",
            hint="key or type your own literal string",
            skip=skip,
        ),
        "FONTTYPE_AESTHETIC": _prompt(
            "FONTTYPE_AESTHETIC",
            lib.TEXT_FONT_COMPLETIONS,
            default="NO_TEXT",
            hint="font key or free description",
            skip=skip,
        ),
        "LAYER_PLACEMENT": _prompt(
            "LAYER_PLACEMENT",
            lib.TEXT_PLACE_COMPLETIONS,
            default="NO_TEXT",
            hint="placement key or free description",
            skip=skip,
        ),
    }

def build_finalize() -> dict:
    _header("FINALIZE OUTPUT (STATIC COMPLIANCE ENFORCED)")
    return copy.deepcopy(STATIC_FINALIZE)

# ==============================================================================
# FULL INTERACTIVE BUILD
# ==============================================================================


def run_interactive() -> dict:
    atmo = build_env_atmospherics(skip=False)
    atmo["!EXEC_COMPOSITION_MATRIX"] = build_composition_matrix(skip=False)
    atmo["!EXEC_BIO_DERMAL_MAP"] = build_bio_dermal_map(skip=False)
    atmo["!ENV_PHOTOMETRY"] = build_env_photometry(skip=False)
    atmo["!ENV_RAY_TRACING_PHOTOMETRY"] = build_ray_tracing_photometry(skip=False)
    atmo["!EXEC_MATERIAL_PHYSICS"] = build_material_physics(skip=False)
    atmo["TEXT_RECON_ENGINE"] = build_text_recon(skip=False)
    atmo["!FINALIZE_OUTPUT"] = build_finalize()

    return {
        "!INIT_MEM_LOCK_PROTOCOL": build_mem_lock(),
        "!ENV_ATMOSPHERICS": atmo,
    }


# ==============================================================================
# STOCK MODE — block-level bypass, one yes/no per section
# ==============================================================================


def run_stock() -> dict:
    _header(
        "STOCK MODE — press ENTER or 'n' to accept block defaults, 'y' to customise"
    )

    def _block(name: str, builder, **kwargs) -> Any:
        if _ask_yes(f"Customise {name}?"):
            return builder(skip=False, **kwargs)
        return builder(skip=True, **kwargs)

    atmo = _block("ENV ATMOSPHERICS", build_env_atmospherics)
    atmo["!EXEC_COMPOSITION_MATRIX"] = _block(
        "COMPOSITION MATRIX", build_composition_matrix
    )
    atmo["!EXEC_BIO_DERMAL_MAP"] = _block("BIO DERMAL MAP", build_bio_dermal_map)
    atmo["!ENV_PHOTOMETRY"] = _block("ENV PHOTOMETRY", build_env_photometry)
    atmo["!ENV_RAY_TRACING_PHOTOMETRY"] = _block("RAY TRACING PHOTOMETRY", build_ray_tracing_photometry)
    atmo["!EXEC_MATERIAL_PHYSICS"] = _block("MATERIAL PHYSICS", build_material_physics)
    atmo["TEXT_RECON_ENGINE"] = _block("TEXT RECON ENGINE", build_text_recon)
    atmo["!FINALIZE_OUTPUT"] = build_finalize()

    return {
        "!INIT_MEM_LOCK_PROTOCOL": build_mem_lock(),
        "!ENV_ATMOSPHERICS": atmo,
    }


# ==============================================================================
# HYBRID MODE — random seed, then field-by-field review / override
# ==============================================================================


def _pool_for_path(path: str) -> list[str]:
    """Map a dotted field path to the most relevant completion list."""
    p = path.lower()
    if "style_of" in p:
        return lib.STYLE_COMPLETIONS
    if "hardware_emulation" in p:
        return lib.CAMERA_COMPLETIONS
    if "optical_hardware" in p:
        return lib.LENS_COMPLETIONS
    if "aperture" in p:
        return lib.APERTURE_COMPLETIONS
    if "shutter" in p:
        return lib.SHUTTER_COMPLETIONS
    if any(
        k in p for k in ("illumination", "key_light", "fill_light", "shadow_profile")
    ):
        return lib.LIGHTING_COMPLETIONS
    if "photonic_energy" in p or "energy_conservation" in p:
        return lib.ENERGY_COMPLETIONS
    if "wardrobe" in p:
        return lib.WARDROBE_COMPLETIONS
    if "opacity" in p:
        return lib.OPACITY_COMPLETIONS
    if "sheen" in p:
        return lib.SHEEN_COMPLETIONS
    if "expression" in p:
        return list(lib.SKIN_MANIFEST["expressions"].keys())
    if "hair" in p:
        return list(lib.SKIN_MANIFEST["hair"].keys())
    if "reflectance" in p:
        return list(lib.SKIN_MANIFEST["reflectance"].keys())
    if "surface_micro" in p:
        return list(lib.SKIN_MANIFEST["surface_micro"].keys())
    if "skin_topography" in p:
        return lib.TOPO_COMPLETIONS
    if "location" in p:
        return lib.LOCATION_COMPLETIONS
    if "glass" in p:
        return lib.GLASS_COMPLETIONS
    if "foreground" in p:
        return list(lib.DOF_MANIFEST["foreground"].keys())
    if "midground" in p:
        return list(lib.DOF_MANIFEST["midground"].keys())
    if "background" in p:
        return list(lib.DOF_MANIFEST["background"].keys())
    if "text_string" in p:
        return lib.TEXT_STRING_COMPLETIONS
    if "fonttype" in p:
        return lib.TEXT_FONT_COMPLETIONS
    if "layer_placement" in p:
        return lib.TEXT_PLACE_COMPLETIONS
    if "focus_lock" in p:
        return lib.FOCUS_COMPLETIONS
    if "negative_bias" in p:
        return lib.NEG_BIAS_COMPLETIONS
    if "unalterable" in p:
        return lib.UNALTERABLE_COMPLETIONS
    if "inhibit" in p:
        return lib.INHIBIT_COMPLETIONS
    if "identity_drift" in p:
        return lib.LOCK_COMPLETIONS
    if "fidelity" in p or "non_deviation" in p:
        return lib.FIDELITY_COMPLETIONS
    if "color_science" in p:
        return lib.COLOR_COMPLETIONS
    if "optics" in p or "aberration" in p:
        return lib.OPTICS_COMPLETIONS
    if "meteorology" in p or "weather" in p or "wind" in p:
        return lib.METEOROLOGY_COMPLETIONS
    if "light_source" in p:
        return lib.RAY_SOURCE_COMPLETIONS
    if "coordinate" in p:
        return lib.RAY_COORD_COMPLETIONS
    if "beam_angle" in p:
        return lib.RAY_ANGLE_COMPLETIONS
    if "luminous" in p or "intensity" in p:
        return lib.RAY_INTENSITY_COMPLETIONS
    if "falloff" in p:
        return lib.RAY_FALLOFF_COMPLETIONS
    if "bounce_light" in p:
        return lib.RAY_BOUNCE_COMPLETIONS
    if any(
        k in p
        for k in (
            "rim_light",
            "epidermal",
            "fabric_diffuse",
            "photon_trans",
            "mean_free",
            "backlit",
            "fresnel",
            "specular_lobe",
            "lambertian",
        )
    ):
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
        completions,
        default="",
        hint="ENTER = keep random value",
    )
    if not raw:
        return current_value
    if is_list:
        return [v.strip() for v in raw.split(",") if v.strip()]
    return raw


def run_hybrid(schema: dict) -> dict:
    """
    Walk every leaf in the randomly-generated schema; offer field-level override.
    Static blocks (!INIT_MEM_LOCK_PROTOCOL and !FINALIZE_OUTPUT) pass through unchanged.
    """
    _header("HYBRID REVIEW — override any field or press ENTER to keep random value")

    # Keys that must never be reviewed regardless of nesting depth
    _static_keys = {"!INIT_MEM_LOCK_PROTOCOL", "!FINALIZE_OUTPUT"}

    def _walk(node: Any, path: str = "", key: str = "") -> Any:
        if key in _static_keys:
            return node
        if isinstance(node, dict):
            return {k: _walk(v, f"{path}.{k}", k) for k, v in node.items()}
        if isinstance(node, (list, str)):
            pool = _pool_for_path(path)
            return _review_field(path.lstrip("."), node, pool)
        return node

    result = {}
    for top_key, top_val in schema.items():
        result[top_key] = _walk(top_val, top_key, top_key)
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
            HSplit,
            VSplit,
            Window,
            FloatContainer,
            Float,
        )
        from prompt_toolkit.layout.controls import (
            BufferControl,
            FormattedTextControl,
        )
        from prompt_toolkit.layout.dimension import D
        from prompt_toolkit.layout.layout import Layout
        from prompt_toolkit.lexers import PygmentsLexer
        from prompt_toolkit.widgets import (
            Frame,
            RadioList,
            TextArea,
            Label,
        )
        from pygments.lexers.data import JsonLexer  # type: ignore

        self._state = HDLTUIState()
        self._Application = Application
        self._KeyBindings = KeyBindings
        self._VSplit = VSplit
        self._HSplit = HSplit
        self._Window = Window
        self._D = D
        self._Layout = Layout
        self._Frame = Frame
        self._RadioList = RadioList
        self._TextArea = TextArea
        self._FormattedTextControl = FormattedTextControl
        self._BufferControl = BufferControl
        self._Buffer = Buffer
        self._Document = Document
        self._PygmentsLexer = PygmentsLexer
        self._JsonLexer = JsonLexer
        self._Label = Label
        self._FloatContainer = FloatContainer
        self._Float = Float
        self._status_text = "[Tab] Focus  [F2] Randomise  [F5] Export  [Ctrl+Q] Quit"
        self._app: Application | None = None

    def _build_layout(self):
        """Construct the full 3-pane layout."""
        schema = self._state.schema
        top_keys = list(schema.keys())

        # ── Navigator (left pane) ──────────────────────────────────────────────
        nav_values = [(k, k) for k in top_keys]
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
            height=1,
            style="reverse",
        )

        body = self._VSplit(
            [
                self._Frame(
                    self._navigator, title="Navigator", width=self._D(weight=30)
                ),
                self._Frame(
                    self._editor_container, title="Editor", width=self._D(weight=40)
                ),
                self._Frame(
                    self._json_area, title="Live JSON", width=self._D(weight=30)
                ),
            ]
        )

        return self._Layout(self._HSplit([body, self._status_bar]))

    def _rebuild_editor(self, category_key: str) -> None:
        """
        Recursively walk category dict and produce TextArea widgets for leaves.
        Static sub-keys (!INIT_MEM_LOCK_PROTOCOL, !FINALIZE_OUTPUT) are rendered
        read-only — their TextAreas have no on_text_changed hooks.
        """
        self._editor_fields.clear()
        schema = self._state.schema
        if category_key not in schema:
            return

        def _walk(node: Any, path: list[str]) -> None:
            if isinstance(node, dict):
                for k, v in node.items():
                    self._editor_fields.append(self._Label(f" {k}"))
                    _walk(v, path + [k])
            elif isinstance(node, list):
                text_val = ", ".join(node)
                pool = _pool_for_path(".".join(path))
                ta = self._TextArea(
                    text=text_val,
                    completer=WordCompleter(pool, ignore_case=True),
                    height=2,
                    multiline=False,
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
                    height=2,
                    multiline=False,
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
        import asyncio
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
                payload = self._state.to_json()
                with open(output_path, "w", encoding="utf-8") as fh:
                    fh.write(payload)
                
                # Gate 4.2 & 4.5: Non-blocking offload of I/O thread
                asyncio.create_task(asyncio.to_thread(_clipboard_copy, payload))
                
                self._status_text = f"[F5] Exported → {output_path}  [Ctrl+Q] Quit"
            except Exception as exc:
                self._status_text = f"[F5] Export FAILED: {exc}  [Ctrl+Q] Quit"
            event.app.invalidate()

        return kb

    def run(self) -> None:
        layout = self._build_layout()
        kb = self._build_keybindings()
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
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
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


def _write_and_print(schema: dict, output_path: str = "hdl_prompt.json") -> None:
    payload = json.dumps(schema, indent=2, ensure_ascii=False)
    with open(output_path, "w", encoding="utf-8") as fh:
        fh.write(payload)
    _clipboard_copy(payload)
    print()
    print("═" * 72)
    print(f"  ✓ HDL prompt: {output_path}")
    print("═" * 72)
    print()
    print(payload)


# ==============================================================================
# MODE SELECTION MENU
# ==============================================================================


def _mode_menu() -> str:
    print()
    print("                      4NDR0TOOLS // HDL PROMPT")
    print("=" * 72)
    print("" * 72)
    print("  [i]  Interactive Mode — Review every parameter")
    print(
        "  [r]  Random Mode      — Prints complete prompt instantly with random values"
    )
    print("  [h]  Hybrid Mode      — Random seed, interactive review / override")
    print("  [s]  Stock Mode       — Accept whole defaults or customise sections")
    print("─" * 72)
    print("" * 72)
    print("         [TAB] pre-set options.        [Type] manual input.")
    print("         [ENTER] ↩ default option.     [Ctrl-C] quit.")
    print("-" * 72)
    mode = _prompt(
        "Selection:",
        ["Interactive", "Random", "Hybrid", "Stock"],
        default="interactive",
    )
    return mode.strip().lower()[:1]  # 'i', 'r', 'h', or 's'


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
        # ── RANDOM ────────────────────────────────────────────────────────────
        _header("RANDOM GENERATION")
        n_str = _prompt(
            "Number of panels  (ENTER for random 1–9)",
            lib.PANEL_COUNT_COMPLETIONS,
            default="",
            hint="optional — leave blank for random",
        )
        seed_str = _prompt(
            "Seed  (ENTER for non-deterministic)",
            [],
            default="",
            hint="integer seed for reproducibility",
        )
        n = int(n_str) if n_str.isdigit() else None
        seed = int(seed_str) if seed_str.isdigit() else None
        schema = generate_random(n_panels=n, seed=seed)
        _write_and_print(schema, "hdl_prompt-random.json")

    elif mode == "h":
        # ── HYBRID ────────────────────────────────────────────────────────────
        n_str = _prompt(
            "Number of panels for random seed  (ENTER for random 1–9)",
            lib.PANEL_COUNT_COMPLETIONS,
            default="",
            hint="optional",
        )
        seed_str = _prompt(
            "Seed  (ENTER for non-deterministic)",
            [],
            default="",
            hint="integer seed for reproducibility",
        )
        n = int(n_str) if n_str.isdigit() else None
        seed = int(seed_str) if seed_str.isdigit() else None
        seed_schema = generate_random(n_panels=n, seed=seed)
        schema = run_hybrid(seed_schema)
        _write_and_print(schema, "hdl_prompt-hybrid.json")

    elif mode == "s":
        # ── STOCK ─────────────────────────────────────────────────────────────
        schema = run_stock()
        _write_and_print(schema, "hdl_prompt-stock.json")

    else:
        # ── INTERACTIVE (default) ─────────────────────────────────────────────
        schema = run_interactive()
        _write_and_print(schema, "hdl_interactive.json")


if __name__ == "__main__":
    main()
