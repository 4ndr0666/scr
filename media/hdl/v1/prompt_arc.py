#!/usr/bin/env python3
# ==============================================================================
# HDL PROMPT BUILDER  (hdl_prompt_builder.py)
# Interactive schema constructor — all completion options sourced from promptlib
#
# MODES
#   interactive   Walk every parameter field with TAB-completion + free-text input
#   random        Randomly sample every field from promptlib manifests; no prompts
#   hybrid        Randomly seed each field, then let user review / override live
#
# MANUAL INPUT
#   At every prompt you may type anything not in the completion list and press
#   ENTER — the value is accepted verbatim.  The completer is advisory only.
# ==============================================================================

import json
import subprocess
import random
import sys
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
# PRIMITIVE PROMPT HELPERS
# ==============================================================================


def _prompt(
    label: str,
    completions: list[str],
    default: str = "",
    hint: str = "",
) -> str:
    """
    Single-value prompt with TAB word completion AND free-text manual input.

    - TAB shows library completions (advisory).
    - Typing any text not in the list and pressing ENTER is accepted verbatim.
    - ENTER with an empty buffer accepts `default`.
    - The optional `hint` string is appended after the label for context.
    """
    completer = WordCompleter(completions, ignore_case=True, sentence=True)
    default_hint = f"  ↩ {default}" if default else ""
    hint_str = f"  [{hint}]" if hint else ""
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
) -> list[str]:
    """
    Multi-value prompt — comma-separated.
    Each token may be a library key OR any free-text string.
    """
    default_str = ", ".join(defaults or [])
    raw = _prompt(
        label,
        completions,
        default=default_str,
        hint=f"comma-separated{'; ' + hint if hint else ''}",
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
    Returns the same nested dict structure as the interactive builder.
    """
    # ── MEM LOCK ──────────────────────────────────────────────────────────────
    mem_lock = {
        "SYSTEM_REFERENCE_INPUT": _r(
            ["INGREDIENT", "SAME_WOMAN"]
        ),
        "BIOMETRIC_LOCK": "TRUE",
        "IDENTITY_DRIFT_CONTROL": _r_list(lib.LOCK_COMPLETIONS),
        "STRUCTURAL_NON_DEVIATION": "HIGH",
        "STRUCTURAL_FIDELITY": "HIGH",
        "UNALTERABLE": _r_list(lib.UNALTERABLE_COMPLETIONS, 4, 8),
        "!INHIBIT": _r_list(lib.INHIBIT_COMPLETIONS,     3, 7),
    }

    # ── ENV ATMOSPHERICS ──────────────────────────────────────────────────────
    env_atmospherics = {
        "LOCATION_SETTING": _r(lib.LOCATION_COMPLETIONS),
        "GLASS_SURFACE_METRICS": _r(lib.GLASS_COMPLETIONS),
        "COMPOSITION_DEPTH": {
            "FOREGROUND": _r(list(lib.DOF_MANIFEST["foreground"].keys())),
            "MIDGROUND": _r(list(lib.DOF_MANIFEST["midground"].keys())),
            "BACKGROUND": _r(list(lib.DOF_MANIFEST["background"].keys())),
        },
    }

    # ── PANELS ────────────────────────────────────────────────────────────────
    if n_panels is None:
        n_panels = random.randint(1, 9)

    matrix: dict[str, Any] = {"PANELS": str(n_panels)}
    used_views: set[str] = set()
    for _ in range(n_panels):
        # Prefer unique view labels per panel; fall back to full pool if exhausted
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

    # ── FINALIZE ──────────────────────────────────────────────────────────────
    finalize = {
        "REQUIREMENT_CHECKS": {
            "FOCUS_LOCK": _r(lib.FOCUS_COMPLETIONS),
            "GLOBAL_NEGATIVE_BIAS": _r_list(lib.NEG_BIAS_COMPLETIONS, 5, 12),
        }
    }

    # ── ASSEMBLE ──────────────────────────────────────────────────────────────
    matrix["!EXEC_BIO_DERMAL_MAP"] = bio_dermal
    matrix["!ENV_PHOTOMETRY"] = photometry
    matrix["!EXEC_MATERIAL_PHYSICS"] = material

    return {
        "!INIT_MEM_LOCK_PROTOCOL": mem_lock,
        "!ENV_ATMOSPHERICS": env_atmospherics,
        "!EXEC_COMPOSITION_MATRIX": matrix,
        "TEXT_RECON_ENGINE": text_recon,
        "!FINALIZE_OUTPUT": finalize,
    }


# ==============================================================================
# INTERACTIVE SECTION BUILDERS
# ==============================================================================


def build_mem_lock() -> dict:
    _header("MEM LOCK PROTOCOL")
    return {
        "SYSTEM_REFERENCE_INPUT": _prompt(
            "SYSTEM_REFERENCE_INPUT",
            ["INGREDIENT", "SAME_WOMAN"],
            default="INGREDIENT",
        ),
        "BIOMETRIC_LOCK": _prompt(
            "BIOMETRIC_LOCK", lib.BOOL_COMPLETIONS, default="TRUE (Replicating every pixel of the anitomalogical topgraphy perfectly)"
        ),
        "IDENTITY_DRIFT_CONTROL": _prompt(
            "IDENTITY_DRIFT_CONTROL", lib.LOCK_COMPLETIONS, default="MAXIMUM_LOCK (Inhibit automatic AI skin-smoothing filters, eliminate facial balancing or symmetry modifications, bypass default commercial touch-up layers. Enforce expression=visceral reaction to an unpleasant taste, opening mouth revealing tongue slathered in a semi-translucent, milky viscous gel--tongue rolls, winces)",
        ),
        "STRUCTURAL_NON_DEVIATION": _prompt(
            "STRUCTURAL_NON_DEVIATION", lib.FIDELITY_COMPLETIONS, default="HIGH"
        ),
        "STRUCTURAL_FIDELITY": _prompt(
            "STRUCTURAL_FIDELITY", lib.FIDELITY_COMPLETIONS, default="HIGH"
        ),
        "UNALTERABLE": _prompt_list(
            "UNALTERABLE",
            lib.UNALTERABLE_COMPLETIONS,
            defaults=[
                "EXACT_FACIAL_ID_GEOMETRY",
                "TRUE_ORBITAL_BONE_SPACING",
                "UNFILTERED_LIP_PROPORTIONS",
                "RAW_JAWLINE_ANGLE",
                "UN-BEAUTIFIED_FACIAL_BONE_CONTOURS",
                "EXACT_BODY_PROPORTIONS",
                "TRUE_BODYFAT_PERCENTAGE_DISTRIBUTION",
            ],
        ),
        "!INHIBIT": _prompt_list(
            "INHIBIT",
            lib.INHIBIT_COMPLETIONS,
            defaults=[
                "AUTOMATIC_SKIN-SMOOTHING_FILTERS",
                "FACIAL_BALANCING",
                "POSE_MODIFICATIONS",
                "BRAZZIER_SUPPORT",
                "CAMERA_ANGLE_MODIFICATIONS",
                "SYMMETRY_MODIFICATIONS",
                "DEFAULT_COMMERCIAL_TOUCH-UP_LAYERS",
            ],
        ),
    }


def build_env_atmospherics() -> dict:
    _header("ENV ATMOSPHERICS")
    return {
        "LOCATION_SETTING": _prompt(
            "LOCATION_SETTING",
            lib.LOCATION_COMPLETIONS,
            default="create a sequence of cinematic stills that tells a short story of the same woman",
            hint="library key or free description",
        ),
        "GLASS_SURFACE_METRICS": _prompt(
            "GLASS_SURFACE_METRICS",
            lib.GLASS_COMPLETIONS,
            default="dust particles catching direct light illumination",
            hint="library key or free description",
        ),
        "COMPOSITION_DEPTH": {
            "FOREGROUND": _prompt(
                "FOREGROUND",
                list(lib.DOF_MANIFEST["foreground"].keys()),
                default="shallow depth of field to create a film like dramatic style",
                hint="DOF/foreground",
            ),
            "MIDGROUND": _prompt(
                "MIDGROUND",
                list(lib.DOF_MANIFEST["midground"].keys()),
                default="she is posing for the camera",
                hint="subject action",
            ),
            "BACKGROUND": _prompt(
                "BACKGROUND",
                list(lib.DOF_MANIFEST["background"].keys()),
                default="spolight lit, clean mirrored walls, floor and ceiling showing high reflection",
                hint="environment",
            ),
        },
    }


def build_panel(index: int) -> dict:
    _subheader(f"Panel {index}")
    angle = _prompt(
        f"Panel {index} — camera angle / view label",
        lib.VIEW_COMPLETIONS,
        default="MEDIUM CLOSE-UP (MCU)",
        hint="view",
    )
    kinetic = _prompt(
        f"Panel {index} — kinetic / pose",
        lib.POSE_COMPLETIONS,
        default="supine_flat",
        hint="pose",
    )
    return {angle: kinetic}


def build_composition_matrix() -> dict:
    _header("COMPOSITION MATRIX")

    layout_choice = _prompt(
        "Layout preset  (ENTER to skip and define panels manually)",
        lib.LAYOUT_COMPLETIONS,
        default="",
        hint="optional preset",
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


def build_bio_dermal_map() -> dict:
    _header("BIO DERMAL MAP")
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
            default="unfiltered human skin texture showing hyper realistic details",
            hint="topology or free description",
        ),
        "SURFACE_MICRO_ELEMENTS": _prompt(
            "SURFACE_MICRO_ELEMENTS",
            list(lib.SKIN_MANIFEST["surface_micro"].keys()),
            default="true visible dermal pores, fine goosebumps on arms, micro sweat beads catching specular highlights, natural skin folds, raw un-airbrused complexion",
            hint="micro elements",
        ),
        "REFLECTANCE_MAP": _prompt(
            "REFLECTANCE_MAP",
            list(lib.SKIN_MANIFEST["reflectance"].keys()),
            default="high specular glisten on damp skin tissue interacting directly with the harsh flash rays",
            hint="reflectance",
        ),
        "EXPRESSION": _prompt(
            "EXPRESSION",
            list(lib.SKIN_MANIFEST["expressions"].keys()),
            default="cool, detached, neutral expression; jaw slightly relaxed, lips subtly parted, gaze fixed steadily on camera lens",
            hint="expression",
        ),
        "HAIR": _prompt(
            "HAIR",
            list(lib.SKIN_MANIFEST["hair"].keys()),
            default="messy, loose uncombed updo with stray hair strands falling naturally across cheeks and neck",
            hint="hair state",
        ),
    }


def build_env_photometry() -> dict:
    _header("ENV PHOTOMETRY")
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
        )

    return {
        "STYLE_OF": _prompt_list(
            "STYLE_OF",
            lib.STYLE_COMPLETIONS,
            defaults=["ELLEN_VON_UNWERTH + PETRA_COLLINS + CASS_BIRD"],
            hint="photographer style(s)",
        ),
        "HARDWARE_EMULATION": _prompt(
            "HARDWARE_EMULATION",
            lib.CAMERA_COMPLETIONS,
            default="Full-frame DSLR sensor camera",
            hint="camera body or free description",
        ),
        "OPTICAL_HARDWARE": _prompt(
            "OPTICAL_HARDWARE",
            lib.LENS_COMPLETIONS,
            default="Canon EOS 5D Mark IV and a Canon EF 100mm",
            hint="lens or free description",
        ),
        "APERTURE_SETTING": _prompt(
            "APERTURE_SETTING",
            lib.APERTURE_COMPLETIONS,
            default="f/2.8L (Ensuring deep technical sharpness across both the foreground and the midground subject details",
            hint="f-stop or free text",
        ),
        "SHUTTER_AESTHETIC": _prompt(
            "SHUTTER_AESTHETIC",
            shutter_pool,
            default="Macro IS USM",
            hint="sync mode or free description",
        ),
        "ILLUMINATION_AXIS": _prompt(
            "ILLUMINATION_AXIS",
            lib.LIGHTING_COMPLETIONS,
            default="single source, hard on-camera pop-up flash aligned parallel to the lens axis",
            hint="light source or free description",
        ),
        "KEY_LIGHT_CHARACTER": _prompt(
            "KEY_LIGHT_CHARACTER",
            lib.LIGHTING_COMPLETIONS,
            default="intense direct 5500K camera flash luminosity (forcing central overexposure blowout, stark white specular highlights on reflective surfaces, and aggressive inverse-square falloff",
            hint="key light",
        ),
        "FILL_LIGHT_CHARACTER": _prompt(
            "FILL_LIGHT_CHARACTER",
            lib.LIGHTING_COMPLETIONS,
            default="dim ambient tungsten glow, 3200K color temperature (ratio: 0.04, restricted to the deep background recesses)",
            hint="fill light",
        ),
        "SHADOW_PROFILE": _prompt(
            "SHADOW_PROFILE",
            lib.LIGHTING_COMPLETIONS,
            default="razor-sharp, jet-black drop shadows directly behind physical subject contours with zero penumbra blending",
            hint="shadow character",
        ),
        "PHOTONIC_VECTORS": {
            "PHOTONIC_ENERGY": _prompt(
                "PHOTONIC_ENERGY",
                lib.ENERGY_COMPLETIONS,
                default="SUBSURFACE_SCATTERING",
            ),
            "ENERGY_CONSERVATION_COMPLIANT": _prompt(
                "ENERGY_CONSERVATION_COMPLIANT",
                lib.ENERGY_COMPLETIONS,
                default="TRANSPARENCY-FOCUSED",
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


def build_material_physics() -> dict:
    _header("MATERIAL PHYSICS")
    drape_opts = lib.LEVEL_COMPLETIONS
    sss_opts = ["ON", "OFF"] + lib.LEVEL_COMPLETIONS
    return {
        "WARDROBE_SPECIFICATION": _prompt(
            "WARDROBE_SPECIFICATION",
            lib.WARDROBE_COMPLETIONS,
            default="realistic single-layer materials, low dennier, white vintage silk slip dress with raw lace border trim along the neck",
            hint="wardrobe key or free description",
        ),
        "OPACITY": _prompt(
            "OPACITY",
            lib.OPACITY_COMPLETIONS,
            default="fabric transparency scales dynamically with tension; material shifts from opaque color to a semi-translucent alpha layer where stretched tight across physical peaks, revealing the muted skin tones underneath",
        ),
        "TEXTILE_SURFACE_SHEEN": _prompt(
            "TEXTILE_SURFACE_SHEEN",
            lib.SHEEN_COMPLETIONS,
            default="anisotropic silk reflection mapping direct flash glare along tight fabric folds and fine micro-wrinkles",
        ),
        "DRAPE_AND_TENSION_LOGIC": {
            "MICRO_FIBER_DRAPE_PHYSICS": _prompt(
                "MICRO_FIBER_DRAPE_PHYSICS", drape_opts, default="HIGH"
            ),
            "LOW_TENSILE_STRUCTURAL_DEFORMITY": _prompt(
                "LOW_TENSILE_STRUCTURAL_DEFORMITY", drape_opts, default="MEDIUM"
            ),
            "GRAVITY_WEIGHTED_FOLDS": _prompt(
                "GRAVITY_WEIGHTED_FOLDS", drape_opts, default="LOW"
            ),
            "SUB_MICRON_WEAVE_DENSITY": _prompt(
                "SUB_MICRON_WEAVE_DENSITY", drape_opts, default="LOW"
            ),
            "LOW_DENIER_SSS_PASS": _prompt(
                "LOW_DENIER_SSS_PASS", sss_opts, default="ON"
            ),
            "SURFACE_ADHESION_COEFFICIENT": _prompt(
                "SURFACE_ADHESION_COEFFICIENT", drape_opts, default="HIGH"
            ),
            "FULLY_SATURATED_WITH_ATMOSPHERIC_MOISTURE": _prompt(
                "FULLY_SATURATED_WITH_ATMOSPHERIC_MOISTURE",
                lib.BOOL_COMPLETIONS,
                default="TRUE",
            ),
        },
    }


def build_text_recon() -> dict:
    _header("TEXT RECON ENGINE")
    return {
        "TEXT_STRING_LITERAL": _prompt(
            "TEXT_STRING_LITERAL",
            lib.TEXT_STRING_COMPLETIONS,
            default="see_you_soon_ellipsis",
            hint="key or type your own literal string",
        ),
        "FONTTYPE_AESTHETIC": _prompt(
            "FONTTYPE_AESTHETIC",
            lib.TEXT_FONT_COMPLETIONS,
            default="lipstick_finger_scrawl_red",
            hint="font key or free description",
        ),
        "LAYER_PLACEMENT": _prompt(
            "LAYER_PLACEMENT",
            lib.TEXT_PLACE_COMPLETIONS,
            default="mirror_glass_plane_sharp",
            hint="placement key or free description",
        ),
    }


def build_finalize() -> dict:
    _header("FINALIZE OUTPUT")
    return {
        "REQUIREMENT_CHECKS": {
            "FOCUS_LOCK": _prompt(
                "FOCUS_LOCK",
                lib.FOCUS_COMPLETIONS,
                default="maximum micro-contrast focus locked onto cloth weave and skin grain",
                hint="focus priority or free description",
            ),
            "GLOBAL_NEGATIVE_BIAS": _prompt_list(
                "GLOBAL_NEGATIVE_BIAS",
                lib.NEG_BIAS_COMPLETIONS,
                defaults=[
                    "STUDIO_SOFTBOX_LIGHTING",
                    "BEAUTY_FILTER",
                    "AIRBRUSHED_SKIN",
                    "PERFECT_FACIAL_SYMMETRY",
                    "DIGITAL_3D_RENDER",
                    "OPAQUE_FABRIC_PROCESSING",
                    "CLEAN_MINIMALIST_ARCHITECTURE",
                    "COMMERCIAL_STOCK_PHOTOGRAPHY_LOOK",
                    "HAPPY_EXPRESSIONS",
                    "IDENTITY_SHIFTING",
                    "DAYLIGHT",
                ],
                hint="bias tokens or free strings",
            ),
        }
    }


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


def _write_and_print(schema: dict, output_path: str) -> None:
    json_str = json.dumps(schema, indent=2, ensure_ascii=False)

    with open(output_path, "w", encoding="utf-8") as fh:
        fh.write(json_str)

    try:
        process = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, text=True)
        process.communicate(input=json_str)
    except FileNotFoundError:
        print("Error: 'wl-copy' not found. Please install it.")

    print()
    print("═" * 72)
    print(f"  ✓  HDL schema written → {output_path}")
    print("═" * 72)
    print()
    print(json_str)


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
    print("─" * 72)
    print("  TAB completes library keys at every prompt.")
    print("  Type anything not in the list → accepted verbatim as manual input.")
    print("  Ctrl-C exits at any point.")
    print("═" * 72)
    mode = _prompt(
        "Select mode", ["interactive", "random", "hybrid"], default="interactive"
    )
    return mode.strip().lower()[:1]  # 'i', 'r', or 'h'


# ==============================================================================
# INTERACTIVE FULL BUILD
# ==============================================================================


def run_interactive() -> dict:
    composition = build_composition_matrix()
    composition["!EXEC_BIO_DERMAL_MAP"] = build_bio_dermal_map()
    composition["!ENV_PHOTOMETRY"] = build_env_photometry()
    composition["!EXEC_MATERIAL_PHYSICS"] = build_material_physics()

    return {
        "!INIT_MEM_LOCK_PROTOCOL": build_mem_lock(),
        "!ENV_ATMOSPHERICS": build_env_atmospherics(),
        "!EXEC_COMPOSITION_MATRIX": composition,
        "TEXT_RECON_ENGINE": build_text_recon(),
        "!FINALIZE_OUTPUT": build_finalize(),
    }


# ==============================================================================
# ENTRY POINT
# ==============================================================================


def main() -> None:
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
        )
        n = int(n_str) if n_str.isdigit() else None
        seed_schema = generate_random(n_panels=n)
        schema = run_hybrid(seed_schema)
        _write_and_print(schema, "hdl_output.json")

    else:
        # ── INTERACTIVE (default) ─────────────────────────────────────────────
        schema = run_interactive()
        _write_and_print(schema, "hdl_output.json")


if __name__ == "__main__":
    main()
