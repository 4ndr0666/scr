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


def build_bio_dermal_map(skip: bool = False) -> dict:
    if not skip: _header("BIO DERMAL MAP")
    topo_pool = [
        "unfiltered_hyper_realistic_dermal_detail",
        "high_magnification_sebaceous_follicles",
        "wet_skin_condensation_texture",
        "dry_aged_deep_crease_mapping",
        "sun_damaged_hyperpigmentation",
        "young_unretouched_fine_pore_mapping",
    ]
    return {
        "SKIN_TOPOGRAPHY_LOGIC": _prompt(
            "SKIN_TOPOGRAPHY_LOGIC",
            topo_pool,
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
            default="COOL,_DETACHED,_NEUTRAL_EXPRESSION;_JAW_SLIGHTLY_RELAXED,_LIPS_SUBTLY_PARTED,_GAZE_FIXED_STEADILY_ON_CAMERA_LENS",
            hint="expression",
            skip=skip,
        ),
        "HAIR": _prompt(
            "HAIR",
            list(lib.SKIN_MANIFEST["hair"].keys()),
            default="MESSY,_LOOSE_AND_DISHEVELED_WITH_STRAY_HAIR_STRANDS_FALLING_NATURALLY_ACROSS_CHEEKS_AND_NECK",
            hint="hair state",
            skip=skip,
        ),
    }


def build_env_photometry(skip: bool = False) -> dict:
    if not skip: _header("ENV PHOTOMETRY")
    shutter_pool = [
        "flash_sync_1_60_standard",
        "flash_sync_1_125_standard",
        "flash_sync_1_250_hss",
        "flash_sync_1_500_hss_full_kill",
        "long_exposure_bulb_ambient_bleed",
    ]

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
            defaults=["DAVID_LACHAPELLE"],
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
            default="anamorphic_2x_squeeze_blue_streak",
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
            shutter_pool,
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
            "EPIDERMAL_TRANSLUCENCY_PASS": _level("EPIDERMAL_TRANSLUCENCY_PASS", "TRUE"),
            "THROUGH_FABRIC_DIFFUSE_BOUNCE": _level("THROUGH_FABRIC_DIFFUSE_BOUNCE", "TRUE"),
            "PHOTON_TRANSMISSION_RATIO": _level("PHOTON_TRANSMISSION_RATIO", "HIGH"),
            "MEAN_FREE_PATH_SCATTERING": _level("MEAN_FREE_PATH_SCATTERING", "MEDIUM"),
            "BACKLIT_SUBSURFACE_GLOW": _level("BACKLIT_SUBSURFACE_GLOW", "MEDIUM"),
            "FRESNEL_REFLECTION_COEFFICIENT": _level("FRESNEL_REFLECTION_COEFFICIENT", "LOW"),
            "SPECULAR_HIGHLIGHT_LOBE": _level("SPECULAR_HIGHLIGHT_LOBE", "LOW"),
            "LAMBERTIAN_DIFFUSE_REFLECTANCE": _level("LAMBERTIAN_DIFFUSE_REFLECTANCE", "LOW"),
        },
    }


def build_material_physics(skip: bool = False) -> dict:
    if not skip: _header("MATERIAL PHYSICS")
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
                "LOW_TENSILE_STRUCTURAL_DEFORMITY", drape_opts, default="MEDIUM", skip=skip
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
    if not skip: _header("TEXT RECON ENGINE")
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
    return STATIC_FINALIZE


# ==============================================================================
# HYBRID MODE — random seed, then field-by-field review / override
# ==============================================================================


def _review_field(key: str, current_value: Any, completions: list[str]) -> Any:
    """
    Show the randomly-generated value and ask whether to keep or replace it.
    Returns either the original value or whatever the user types.
    """
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
    Walk through the randomly-generated schema and offer field-level overrides.
    Only leaf string/list values are reviewable; nested dicts recurse.
    """
    _header("HYBRID REVIEW — override any field or press ENTER to keep random value")

    def _walk(node: Any, path: str = "") -> Any:
        # Silently skip review for static blocks
        if "!INIT_MEM_LOCK_PROTOCOL" in path or "!FINALIZE_OUTPUT" in path:
            return node

        if isinstance(node, dict):
            return {k: _walk(v, f"{path}.{k}") for k, v in node.items()}
        if isinstance(node, list):
            # Infer best completion pool from path segment keywords
            pool = _pool_for_path(path)
            return _review_field(path.lstrip("."), node, pool)
        if isinstance(node, str):
            pool = _pool_for_path(path)
            return _review_field(path.lstrip("."), node, pool)
        return node

    return _walk(schema)


def _pool_for_path(path: str) -> list[str]:
    """
    Map a dotted field path to the most relevant completion list.
    Falls back to an empty list (free-text only) for unknown paths.
    """
    p = path.lower()
    if "style_of" in p:
        return lib.STYLE_COMPLETIONS
    if "hardware_emulation" in p:
        return lib.CAMERA_COMPLETIONS
    if "optical_hardware" in p:
        return lib.LENS_COMPLETIONS
    if "aperture" in p:
        return lib.APERTURE_COMPLETIONS
    if (
        "illumination" in p
        or "key_light" in p
        or "fill_light" in p
        or "shadow_profile" in p
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
    if "meteorology" in p or "wind" in p or "scattering" in p:
        return lib.METEOROLOGY_COMPLETIONS
    # Photonic scalar flags
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


# ==============================================================================
# OUTPUT HELPERS
# ==============================================================================


def _write_and_print(schema: dict, output_path: str, suppress_print: bool = False) -> None:
    json_str = json.dumps(schema, indent=2, ensure_ascii=False)

    with open(output_path, "w", encoding="utf-8") as fh:
        fh.write(json_str)

    try:
        process = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, text=True)
        process.communicate(input=json_str, timeout=2.0)
    except FileNotFoundError:
        if not suppress_print: print("  [!] 'wl-copy' not found. Please install it.")
    except subprocess.TimeoutExpired:
        process.kill()
        process.communicate()
        if not suppress_print: print("  [!] 'wl-copy' timed out.")
    except Exception as e:
        if not suppress_print: print(f"  [!] Clipboard error: {e}")

    if not suppress_print:
        print()
        print("═" * 72)
        print(f"  ✓ HDL prompt: {output_path}")
        print("═" * 72)
        print()
        print(json_str)


# ==============================================================================
# MODE SELECTION MENU
# ==============================================================================


def _mode_menu() -> str:
    print()
    print("                      4NDR0TOOLS // HDL PROMPT")
    print("=" * 72)
    print("" * 72)
    print("  [i]  Interactive Mode — Review and select every individual parameter")
    print("  [s]  Stock Mode       — Bypass explicit inputs for standard defaults")
    print("  [r]  Random Mode      — Prints complete prompt using random values")
    print("  [h]  Hybrid Mode      — Presents random values for interactive review")
    print("-" * 72)
    print("" * 72)
    print("         [TAB] pre-set options.        [Type] manual input.")
    print("         [ENTER] ↩ default option.     [Ctrl-C] quit.")
    print("-" * 72)
    mode = _prompt(
        "Selection:", ["Interactive", "Stock", "Random", "Hybrid"], default="Interactive"
    )
    return mode.strip().lower()[:1]


# ==============================================================================
# INTERACTIVE / STOCK FULL BUILD
# ==============================================================================


def run_interactive() -> dict:
    # 1. Build the parent wrapper first
    env_atmospherics = build_env_atmospherics(skip=False)
    
    # 2. Nest downstream child blocks inside the parent
    env_atmospherics["!EXEC_COMPOSITION_MATRIX"] = build_composition_matrix(skip=False)
    env_atmospherics["!EXEC_BIO_DERMAL_MAP"] = build_bio_dermal_map(skip=False)
    env_atmospherics["!ENV_PHOTOMETRY"] = build_env_photometry(skip=False)
    env_atmospherics["!EXEC_MATERIAL_PHYSICS"] = build_material_physics(skip=False)
    env_atmospherics["TEXT_RECON_ENGINE"] = build_text_recon(skip=False)
    env_atmospherics["!FINALIZE_OUTPUT"] = build_finalize()

    return {
        "!INIT_MEM_LOCK_PROTOCOL": build_mem_lock(),
        "!ENV_ATMOSPHERICS": env_atmospherics,
    }


def run_stock() -> dict:
    _header("STOCK MODE — Bypass or customize blocks")
    
    def _ask_skip(block_name: str) -> bool:
        resp = _prompt(f"Customize {block_name}?", ["yes", "no"], default="no", hint="yes/no")
        return resp.lower() != "yes"

    # 1. Build the parent wrapper
    env_atmospherics = build_env_atmospherics(skip=_ask_skip("ENV ATMOSPHERICS"))

    # 2. Nest downstream child blocks
    env_atmospherics["!EXEC_COMPOSITION_MATRIX"] = build_composition_matrix(skip=_ask_skip("COMPOSITION MATRIX"))
    env_atmospherics["!EXEC_BIO_DERMAL_MAP"] = build_bio_dermal_map(skip=_ask_skip("BIO DERMAL MAP"))
    env_atmospherics["!ENV_PHOTOMETRY"] = build_env_photometry(skip=_ask_skip("ENV PHOTOMETRY"))
    env_atmospherics["!EXEC_MATERIAL_PHYSICS"] = build_material_physics(skip=_ask_skip("MATERIAL PHYSICS"))
    env_atmospherics["TEXT_RECON_ENGINE"] = build_text_recon(skip=_ask_skip("TEXT RECON ENGINE"))
    env_atmospherics["!FINALIZE_OUTPUT"] = build_finalize()

    return {
        "!INIT_MEM_LOCK_PROTOCOL": build_mem_lock(),
        "!ENV_ATMOSPHERICS": env_atmospherics,
    }


# ==============================================================================
# TUI SUBSYSTEM (--tui)
# ==============================================================================

class HDLTUIState:
    def __init__(self):
        self.data = generate_random(n_panels=1)

    def update_val(self, path: list, new_value: Any):
        d = self.data
        for k in path[:-1]:
            d = d[k]
        d[path[-1]] = new_value

    def to_json(self):
        return json.dumps(self.data, indent=2, ensure_ascii=False)


def run_tui():
    from prompt_toolkit.application import Application
    from prompt_toolkit.key_binding import KeyBindings
    from prompt_toolkit.layout.containers import HSplit, VSplit, Window, DynamicContainer
    from prompt_toolkit.layout.controls import FormattedTextControl
    from prompt_toolkit.layout.layout import Layout
    from prompt_toolkit.widgets import RadioList, TextArea
    from pygments.lexers.data import JsonLexer
    from prompt_toolkit.lexers import PygmentsLexer

    tui_state = HDLTUIState()
    
    json_output_area = TextArea(
        text=tui_state.to_json(),
        lexer=PygmentsLexer(JsonLexer),
        read_only=True,
        scrollbar=True,
    )

    def update_output_pane():
        json_output_area.text = tui_state.to_json()

    def build_form(node, path):
        fields = []
        if isinstance(node, dict):
            for k, v in node.items():
                fields.append(Window(content=FormattedTextControl(f"\n{k}"), height=2))
                fields.extend(build_form(v, path + [k]))
        elif isinstance(node, list):
            pool = _pool_for_path(".".join(path))
            completer = WordCompleter(pool, ignore_case=True, sentence=True) if pool else None

            def make_handler(p):
                def handler(buff):
                    tui_state.update_val(p, [v.strip() for v in buff.text.split(",") if v.strip()])
                    update_output_pane()
                return handler

            ta = TextArea(text=", ".join(node), completer=completer, multiline=False)
            ta.buffer.on_text_changed += make_handler(path)
            fields.append(ta)
        elif isinstance(node, str):
            pool = _pool_for_path(".".join(path))
            completer = WordCompleter(pool, ignore_case=True, sentence=True) if pool else None

            def make_handler(p):
                def handler(buff):
                    tui_state.update_val(p, buff.text)
                    update_output_pane()
                return handler

            ta = TextArea(text=node, completer=completer, multiline=False)
            ta.buffer.on_text_changed += make_handler(path)
            fields.append(ta)
        return fields

    def get_editor_content():
        selected_key = navigator.current_value
        if not selected_key:
            return Window()
        
        node = tui_state.data.get(selected_key)
        fields = []
        fields.append(Window(content=FormattedTextControl(f"--- Editing: {selected_key} ---"), height=2))
        fields.extend(build_form(node, [selected_key]))
        return HSplit(fields)

    def on_nav_change(radio_list):
        pass # The dynamic container polls get_editor_content

    navigator = RadioList(
        values=[(k, k) for k in tui_state.data.keys()]
    )

    editor_container = DynamicContainer(get_editor_content)
    
    status_bar = FormattedTextControl(" [Tab] Switch Pane | [F2] Randomize | [F5] Export/Save | [Ctrl+Q] Exit ")
    status_window = Window(content=status_bar, height=1, style="reverse")

    root_container = HSplit([
        VSplit([
            HSplit([Window(content=FormattedTextControl("NAVIGATOR"), height=1, style="bold"), navigator], width=30),
            Window(width=1, char="|"),
            HSplit([Window(content=FormattedTextControl("FORM EDITOR"), height=1, style="bold"), editor_container], width=50),
            Window(width=1, char="|"),
            HSplit([Window(content=FormattedTextControl("LIVE JSON OUTPUT"), height=1, style="bold"), json_output_area]),
        ]),
        status_window
    ])

    kb = KeyBindings()

    @kb.add("tab")
    def _(event):
        layout.focus_next()

    @kb.add("c-q")
    def _(event):
        event.app.exit()

    @kb.add("f2")
    def _(event):
        tui_state.data = generate_random(n_panels=1)
        navigator.values = [(k, k) for k in tui_state.data.keys()]
        update_output_pane()
        status_bar.text = " [F2] State Randomized "

    @kb.add("f5")
    def _(event):
        _write_and_print(tui_state.data, "hdl_output.json", suppress_print=True)
        status_bar.text = " [F5] Saved to hdl_output.json & Clipboard "

    layout = Layout(root_container)
    app = Application(layout=layout, key_bindings=kb, full_screen=True)
    
    # asyncio run
    app.run()


# ==============================================================================
# ENTRY POINT
# ==============================================================================


def main() -> None:
    if "--tui" in sys.argv:
        run_tui()
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
            skip=False,
        )
        n = int(n_str) if n_str.isdigit() else None
        schema = generate_random(n_panels=n)
        _write_and_print(schema, "hdl_output.json")

    elif mode == "h":
        # ── HYBRID ────────────────────────────────────────────────────────────
        n_str = _prompt(
            "Number of panels for random seed  (ENTER for random 1–9)",
            lib.PANEL_COUNT_COMPLETIONS,
            default="",
            hint="optional",
            skip=False,
        )
        n = int(n_str) if n_str.isdigit() else None
        seed_schema = generate_random(n_panels=n)
        schema = run_hybrid(seed_schema)
        _write_and_print(schema, "hdl_output.json")

    elif mode == "s":
        # ── STOCK ─────────────────────────────────────────────────────────────
        schema = run_stock()
        _write_and_print(schema, "hdl_output.json")

    else:
        # ── INTERACTIVE (default) ─────────────────────────────────────────────
        schema = run_interactive()
        _write_and_print(schema, "hdl_prompt.json")


if __name__ == "__main__":
    main()

