import json
# Assuming the file in source 2 is named promptlib.py
from promptlib import *

def get_keys(manifest):
    return list(manifest.keys())

def get_nested_keys(manifest):
    keys = []
    for cat in manifest.values():
        keys.extend(cat.keys())
    return keys

# Constructing the exact structure expected by the HTML UI
m_object = {
    "views": VIEWS_MANIFEST,
    "kinematic": KINEMATIC_MANIFEST,
    "layouts": {k: str(v) for cat in LAYOUT_MANIFEST.values() for k, v in cat.items()},
    "styling": get_keys(STYLING_MANIFEST),
    "lighting": LIGHTING_PHYSICS_MANIFEST,
    "photonic": PHOTONIC_ENERGY_MANIFEST,
    "ray": RAY_TRACING_MANIFEST,
    "camera": CAMERA_BODY_MANIFEST,
    "lens": LENS_MANIFEST,
    "color": get_nested_keys(COLOR_SCIENCE_MANIFEST),
    "optics": get_nested_keys(OPTICAL_ABERRATION_MANIFEST),
    "aperture": get_keys(APERTURE_MANIFEST),
    # Hardcoded fallback lists from the original JS
    "shutter": ["FLASH_SYNC_1_60_STANDARD", "FLASH_SYNC_1_125_STANDARD", "FLASH_SYNC_1_250_HSS", "FLASH_SYNC_1_500_HSS_FULL_KILL", "LONG_EXPOSURE_BULB_AMBIENT_BLEED"],
    "levels": ["ULTRA", "HIGH", "MEDIUM", "LOW", "OFF"],
    "wardrobe": get_keys(WARDROBE_MANIFEST),
    "opacity": get_keys(MATERIAL_MANIFEST["opacity"]),
    "sheen": get_keys(MATERIAL_MANIFEST["textile_sheen"]),
    "topo": get_keys(SKIN_MANIFEST["surface_micro"]),
    "skinMicro": get_keys(SKIN_MANIFEST["surface_micro"]),
    "skinRef": get_keys(SKIN_MANIFEST["reflectance"]),
    "skinExp": get_keys(SKIN_MANIFEST["expressions"]),
    "skinHair": get_keys(SKIN_MANIFEST["hair"]),
    "location": get_nested_keys(LOCATION_MANIFEST),
    "glass": get_keys(GLASS_SURFACE_MANIFEST),
    "meteo": get_nested_keys(METEOROLOGY_MANIFEST),
    "dofFg": get_keys(DOF_MANIFEST["foreground"]),
    "dofMg": get_keys(DOF_MANIFEST["midground"]),
    "dofBg": get_keys(DOF_MANIFEST["background"]),
    "textStr": get_keys(TEXT_MANIFEST["strings"]),
    "textFont": get_keys(TEXT_MANIFEST["font_aesthetics"]),
    "textPlace": get_keys(TEXT_MANIFEST["placement"])
}

# Output the canonical JS block
js_output = f"const M = {json.dumps(m_object, indent=2)};"
print(js_output)
