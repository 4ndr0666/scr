#!/usr/bin/env python3
import json
import promptlib_2 as pl

def flatten_keys(manifest_dict):
    keys = []
    for val in manifest_dict.values():
        if isinstance(val, dict):
            keys.extend(val.keys())
        else:
            keys.append(val)
    return keys

# Constructing the exact data model expected by the visualizer UI
manifest_registry = {
    "views": pl.VIEWS_MANIFEST,
    "kinematic": pl.KINEMATIC_MANIFEST,
    "layouts": {
        k: str(v.get("VIEWS", {})) if isinstance(v, dict) else str(v)
        for cat in pl.LAYOUT_MANIFEST.values()
        for k, v in cat.items()
    },
    "styling": list(pl.STYLING_MANIFEST.keys()),
    "lighting": pl.LIGHTING_PHYSICS_MANIFEST,
    "photonic": pl.PHOTONIC_ENERGY_MANIFEST,
    "ray": {
        "sources": pl.RAY_TRACING_MANIFEST["light_sources"],
        "coords": pl.RAY_TRACING_MANIFEST["coordinates"],
        "angles": pl.RAY_TRACING_MANIFEST["beam_angles"],
        "intensity": pl.RAY_TRACING_MANIFEST["intensity"],
        "falloff": pl.RAY_TRACING_MANIFEST["falloff"],
        "bounce": pl.RAY_TRACING_MANIFEST["bounce_logic"],
    },
    "camera": pl.CAMERA_BODY_MANIFEST,
    "lens": pl.LENS_MANIFEST,
    "color": flatten_keys(pl.COLOR_SCIENCE_MANIFEST),
    "optics": flatten_keys(pl.OPTICAL_ABERRATION_MANIFEST),
    "aperture": list(pl.APERTURE_MANIFEST.keys()),
    "shutter": pl.SHUTTER_COMPLETIONS,
    "levels": pl.LEVEL_COMPLETIONS,
    "wardrobe": list(pl.WARDROBE_MANIFEST.keys()),
    "opacity": list(pl.MATERIAL_MANIFEST["opacity"].keys()),
    "sheen": list(pl.MATERIAL_MANIFEST["textile_sheen"].keys()),
    "topo": pl.TOPO_COMPLETIONS,
    "skinMicro": list(pl.SKIN_MANIFEST["surface_micro"].keys()),
    "skinRef": list(pl.SKIN_MANIFEST["reflectance"].keys()),
    "skinExp": list(pl.SKIN_MANIFEST["expressions"].keys()),
    "skinHair": list(pl.SKIN_MANIFEST["hair"].keys()),
    "location": flatten_keys(pl.LOCATION_MANIFEST),
    "glass": list(pl.GLASS_SURFACE_MANIFEST.keys()),
    "meteo": flatten_keys(pl.METEOROLOGY_MANIFEST),
    "dofFg": list(pl.DOF_MANIFEST["foreground"].keys()),
    "dofMg": list(pl.DOF_MANIFEST["midground"].keys()),
    "dofBg": list(pl.DOF_MANIFEST["background"].keys()),
    "textStr": list(pl.TEXT_MANIFEST["strings"].keys()),
    "textFont": list(pl.TEXT_MANIFEST["font_aesthetics"].keys()),
    "textPlace": list(pl.TEXT_MANIFEST["placement"].keys()),
}

js_output = f"const M = {json.dumps(manifest_registry, indent=2)};\n"

with open("manifest_synced.js", "w", encoding="utf-8") as f:
    f.write(js_output)

print("[✓] Synchronized manifest registry exported to manifest_synced.js")
