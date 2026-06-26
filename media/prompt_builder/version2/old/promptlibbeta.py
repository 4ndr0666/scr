#!/usr/bin/env python3
# ==============================================================================
# 4NDR0666OS INTEGRATED PARAMETER REGISTRY (promptlib.py)
# SYSTEM PLATFORM CONFIGURATION AND COMPREHENSIVE LOOKUP DICTIONARIES
# ==============================================================================

PARAMETERS = {
    "identity": {
        "Structural-fidelity": {"desc": "Geometry preservation", "layman": "Keep original shape", "vals": "0.1 to 1.0", "preset": "0.85"},
        "Anatomical-anchor": {"desc": "Reference point", "layman": "Fix body parts in place", "vals": "x,y,z coordinate", "preset": "0,0,0"},
        "Features-fixed": {"desc": "Deformation protection", "layman": "Prevent face/object warping", "vals": "on/off", "preset": "on"},
        "Identity-static": {"desc": "Drift prevention", "layman": "Keep the character looking the same", "vals": "high/medium/low", "preset": "high"},
        "Pigmentation-map-locked": {"desc": "Texture consistency", "layman": "Keep skin/surface colors exact", "vals": "hex code or reference", "preset": "#FF69B4"},
        "Structural-non-deviation": {"desc": "Proportion enforcement", "layman": "Don't change scale", "vals": "0.0 to 1.0", "preset": "1.0"}
    },
    "lighting_physics": {
        "Fresnel-reflection-coefficient": {"desc": "Angular reflectivity", "layman": "Control light reflection at edges", "vals": "0.0 (dull) to 1.0 (mirror)", "preset": "0.3"},
        "Specular-highlight-lobe": {"desc": "Reflection spread", "layman": "Size of shiny spots", "vals": "0.1 (sharp) to 10.0 (blurred)", "preset": "2.0"},
        "Lambertian-diffuse-reflectance": {"desc": "Matte scattering", "layman": "How matte the surface is", "vals": "0.0 to 1.0", "preset": "0.6"},
        "Anisotropic-specular-reflection": {"desc": "Fibrous reflection", "layman": "Directional shine (like silk)", "vals": "rotation degree", "preset": "45"},
        "Mean-free-path-scattering": {"desc": "SSS depth", "layman": "How deep light goes into skin", "vals": "0mm to 50mm", "preset": "25"},
        "Photon-transmission-ratio": {"desc": "Transparency intensity", "layman": "How much light passes through", "vals": "0% to 100%", "preset": "40"},
        "Through-fabric-diffuse-bounce": {"desc": "Light transmission", "layman": "Light scattering through cloth", "vals": "on/off", "preset": "on"},
        "Rim-light-scattering-pass": {"desc": "Edge translucency", "layman": "Backlight glow on edges", "vals": "intensity 0 to 10", "preset": "8"}
    },
    "fabric_denier": {
        "Micro-fiber-drape-physics": {"desc": "Thin material behavior", "layman": "Natural cloth movement", "vals": "weight in g/m2", "preset": "12"},
        "Low-tensile-structural-deformity": {"desc": "Deformation logic", "layman": "How easily it stretches", "vals": "elasticity 0.0 to 1.0", "preset": "0.7"},
        "Gravity-weighted-folds": {"desc": "Natural settling", "layman": "How fabric hangs", "vals": "fold intensity", "preset": "3"},
        "Sub-micron-weave-density": {"desc": "Fiber fidelity", "layman": "Tightness of the weave", "vals": "high/medium/low", "preset": "high"}
    },
    "composition": {
        "Isometric-spatial-grid": {"desc": "Axis alignment", "layman": "Isometric grid layout", "vals": "on/off", "preset": "on"},
        "Orthographic-projection": {"desc": "Parallel ray logic", "layman": "Flat perspective", "vals": "on/off", "preset": "off"},
        "Foreground-depth-layer": {"desc": "Depth priority", "layman": "Near-field rendering", "vals": "0.0 to 1.0", "preset": "0.9"},
        "Spatial-density-uniform": {"desc": "Distribution balance", "layman": "Balanced object placement", "vals": "high/low", "preset": "high"}
    },
    "typography": {
        "Vector-precision-glyph": {"desc": "Vector pathing", "layman": "Sharp text edges", "vals": "on/off", "preset": "on"},
        "Typographic-clarity": {"desc": "Edge rendering", "layman": "High legibility", "vals": "1 to 10", "preset": "9"},
        "Baseline-aligned": {"desc": "Stabilization", "layman": "Align text horizontally", "vals": "on/off", "preset": "on"}
    },
    "constraints": {
        "Non-stylized-skin": {"desc": "Texture restriction", "layman": "Natural skin texture", "vals": "on/off", "preset": "on"},
        "No-structural-changes": {"desc": "Geometry lock", "layman": "Lock original proportions", "vals": "on/off", "preset": "on"}
    }
}

MODERATION_BACKOFF_MAP = {
    "translucency": "opacity-gradient-index",
    "subsurface": "volumetric-depth-scattering",
    "dermal": "internal-structural-layer",
    "anatomical": "structural-topology-anchor",
    "skin": "epidermal-plane-mesh",
    "flesh": "organic-material-density",
    "sheer": "low-denier-permeability",
    "lingerie": "base-layer-technical-fabric"
}

# Explicit Mappings to transform simple text commands into backend instructions
POSE_MANIFEST = {
    "anatomic_neutral": "0.0,0.0,0.0",
    "supine_flat": "0.0,-1.0,0.0",
    "prone_flat": "0.0,1.0,0.0",
    "crouching_low_compression": "0.0,-0.8,0.0",
    "crouching_mid_balance": "0.0,-0.4,0.0",
    "kneeling_upright_neutral": "0.0,-0.6,0.0",
    "seated_upright_erect": "0.0,-0.5,0.0",
    "standing_wide_base": "0.0,0.0,0.0"
}

LIGHTING_PHYSICS_MANIFEST = {
    "fresnel_edge_glare": "PHOTONIC_ENERGY: FRESNEL_ANGULAR_REFLECT_0.3",
    "specular_sharp_lobe": "PHOTONIC_ENERGY: SPECULAR_LOBE_SHARP_2.0",
    "lambertian_matte_scatter": "PHOTONIC_ENERGY: LAMBERTIAN_DIFFUSE_0.6",
    "anisotropic_silk_rotation": "PHOTONIC_ENERGY: ANISOTROPIC_FIBER_45_DEG",
    "subsurface_dermal_25mm": "PHOTONIC_ENERGY: VOLUMETRIC_DEPTH_25MM",
    "photon_transmission_40pct": "PHOTONIC_ENERGY: TRANSMISSION_RATIO_40_PERCENT",
    "fabric_diffuse_bounce": "PHOTONIC_ENERGY: SCATTER_THROUGH_WEAVE",
    "rim_light_glow_pass": "PHOTONIC_ENERGY: EDGE_TRANSLUCENCY_INTENSITY_8"
}

LAYOUT_MANIFEST = {
    "isometric_spatial_grid": "AXIS_ALIGNMENT: ISO_30_DEGREE",
    "orthographic_grid_flat": "AXIS_ALIGNMENT: PURE_ORTHO_XYZ",
    "foreground_depth_layer": "DEPTH: FOREGROUND_PRIORITY_MAX_0.9",
    "spatial_density_uniform": "DISTRIBUTION: UNIFORM_BALANCE_HIGH"
}

# Autocomplete Registries
POSE_COMPLETIONS = list(POSE_MANIFEST.keys())
LIGHTING_COMPLETIONS = list(LIGHTING_PHYSICS_MANIFEST.keys())
LAYOUT_COMPLETIONS = list(LAYOUT_MANIFEST.keys())

def resolve_tokens(user_input: str, target_index: dict) -> str:
    if not user_input:
        return "DEFAULT_IDENTITY_NULL"
    normalized = user_input.lower().strip().replace(" ", "_").replace("-", "_")
    
    if normalized in target_index:
        return target_index[normalized]
    for key, val in target_index.items():
        if key in normalized or normalized in key:
            return val
    return user_input
