#!/usr/bin/env python3
# ==============================================================================
# 4NDR0666OS INTEGRATED PARAMETER REGISTRY AND MATRIX LIBRARY (promptlib.py)
# SYSTEM PLATFORM CONFIGURATION AND SEGREGATED LOOKUP DICTIONARIES
# EXHAUSTIVE, UNABRIDGED SUPERSET EDITION - SYNTAX AND NESTING PARITY
# ==============================================================================

PARAMETERS = {
    "identity": {
        "Structural-fidelity": {
            "desc": "Geometry preservation",
            "layman": "Keep original shape",
            "vals": "0.1 to 1.0",
            "preset": "1.0",
        },
        "Anatomical-anchor": {
            "desc": "Reference point",
            "layman": "Fix body parts in place",
            "vals": "x,y,z coordinate",
            "preset": "0,0,0",
        },
        "Features-fixed": {
            "desc": "Deformation protection",
            "layman": "Prevent face/object warping",
            "vals": "on/off",
            "preset": "on",
        },
        "Identity-static": {
            "desc": "Drift prevention",
            "layman": "Keep the character looking the same",
            "vals": "high/medium/low",
            "preset": "high",
        },
        "Pigmentation-map-locked": {
            "desc": "Texture consistency",
            "layman": "Keep skin colors exact",
            "vals": "hex code or reference",
            "preset": "#FF69B4",
        },
        "Structural-non-deviation": {
            "desc": "Proportion enforcement",
            "layman": "Don't change scale",
            "vals": "0.0 to 1.0",
            "preset": "1.0",
        },
    },
    "lighting_physics": {
        "Photonic-anchor": {
            "desc": "Master Lighting Logic",
            "layman": "Base lighting profile",
            "vals": "flash/spotlight/golden_hour",
            "preset": "rim_light_scattering_pass",
        },
        "Fresnel-reflection-coefficient": {
            "desc": "Angular reflectivity",
            "layman": "Control light reflection at edges",
            "vals": "0.0 (dull) to 1.0 (mirror)",
            "preset": "0.3",
        },
        "Specular-highlight-lobe": {
            "desc": "Reflection spread",
            "layman": "Size of shiny spots",
            "vals": "0.1 (sharp) to 10.0 (blurred)",
            "preset": "2.0",
        },
        "Lambertian-diffuse-reflectance": {
            "desc": "Matte scattering",
            "layman": "How matte the surface is",
            "vals": "0.0 to 1.0",
            "preset": "0.2",
        },
        "Anisotropic-specular-reflection": {
            "desc": "Fibrous reflection",
            "layman": "Directional shine (like silk)",
            "vals": "rotation degree",
            "preset": "45",
        },
        "Mean-free-path-scattering": {
            "desc": "SSS depth",
            "layman": "How deep light goes into skin",
            "vals": "0mm to 50mm",
            "preset": "40",
        },
        "Photon-transmission-ratio": {
            "desc": "Transparency intensity",
            "layman": "How much light passes through",
            "vals": "0% to 100%",
            "preset": "70",
        },
        "Through-fabric-diffuse-bounce": {
            "desc": "Light transmission",
            "layman": "Light scattering through cloth",
            "vals": "on/off",
            "preset": "on",
        },
        "Rim-light-scattering-pass": {
            "desc": "Edge translucency",
            "layman": "Backlight glow on edges",
            "vals": "intensity 0 to 10",
            "preset": "8",
        },
    },
    "style_engine": {
        "Artistic-reference": {
            "desc": "Master painter/photographer",
            "layman": "Apply specific style",
            "vals": "Turbeville/Yemchuk/Caravaggio/Fragonard",
            "preset": "RAW_FLASH_PHOTOGRAPHY_DSLR",
        },
        "Atmospheric-moisture": {
            "desc": "Wet-look finish",
            "layman": "Saturate with moisture",
            "vals": "on/off",
            "preset": "on",
        },
        "Rendering-pipeline": {
            "desc": "Base engine logic",
            "layman": "How image is generated",
            "vals": "Octane/Standard/Chiaroscuro",
            "preset": "Octane",
        },
    },
    "fabric_denier": {
        "Micro-fiber-drape-physics": {
            "desc": "Thin material behavior",
            "layman": "Natural cloth movement",
            "vals": "weight in g/m2",
            "preset": "12",
        },
        "Low-tensile-structural-deformity": {
            "desc": "Deformation logic",
            "layman": "How easily it stretches",
            "vals": "elasticity 0.0 to 1.0",
            "preset": "0.7",
        },
        "Gravity-weighted-folds": {
            "desc": "Natural settling",
            "layman": "How fabric hangs",
            "vals": "fold intensity",
            "preset": "3",
        },
        "Sub-micron-weave-density": {
            "desc": "Fiber fidelity",
            "layman": "Tightness of the weave",
            "vals": "high/medium/low",
            "preset": "low",
        },
    },
    "composition": {
        "Spatial-anchor": {
            "desc": "Master Layout Logic",
            "layman": "Base composition frame",
            "vals": "triptych/6-panel/full-body",
            "preset": "six_panel_composite",
        },
        "Isometric-spatial-grid": {
            "desc": "Axis alignment",
            "layman": "Isometric grid layout",
            "vals": "on/off",
            "preset": "on",
        },
        "Orthographic-projection": {
            "desc": "Parallel ray logic",
            "layman": "Flat perspective",
            "vals": "on/off",
            "preset": "off",
        },
        "Foreground-depth-layer": {
            "desc": "Depth priority",
            "layman": "Near-field rendering",
            "vals": "0.0 to 1.0",
            "preset": "0.9",
        },
        "Spatial-density-uniform": {
            "desc": "Distribution balance",
            "layman": "Balanced object placement",
            "vals": "high/low",
            "preset": "high",
        },
        "Depth-of-field-control": {
            "desc": "Bokeh intensity",
            "layman": "Background blur",
            "vals": "f-stop 1.2 to 8.0",
            "preset": "f/2.8",
        },
    },
    "typography": {
        "Vector-precision-glyph": {
            "desc": "Vector pathing",
            "layman": "Sharp text edges",
            "vals": "on/off",
            "preset": "on",
        },
        "Typographic-clarity": {
            "desc": "Edge rendering",
            "layman": "High legibility",
            "vals": "1 to 10",
            "preset": "9",
        },
        "Baseline-aligned": {
            "desc": "Stabilization",
            "layman": "Align text horizontally",
            "vals": "on/off",
            "preset": "on",
        },
    },
    "constraints": {
        "Non-stylized-skin": {
            "desc": "Texture restriction",
            "layman": "Natural skin texture",
            "vals": "on/off",
            "preset": "on",
        },
        "No-structural-changes": {
            "desc": "Geometry lock",
            "layman": "Lock original proportions",
            "vals": "on/off",
            "preset": "on",
        },
    },
}

MODERATION_BACKOFF_MAP = {
    "translucency": "opacity-gradient-index",
    "subsurface": "volumetric-depth-scattering",
    "dermal": "internal-structural-layer",
    "anatomical": "structural-topology-anchor",
    "skin": "epidermal-plane-mesh",
    "flesh": "organic-material-density",
    "sheer": "low-denier-permeability",
    "lingerie": "base-layer-technical-fabric",
}

# ==============================================================================
# EXHAUSTIVE KINEMATIC MANIFEST
# ==============================================================================
KINEMATIC_MANIFEST = {
    "structural_alignment": {
        "anatomic_neutral": "0.0,0.0,0.0",
        "supine_flat": "0.0,-1.0,0.0",
        "supine_head_elevated": "0.0,-0.9,0.1",
        "supine_legs_elevated": "0.0,-0.9,-0.1",
        "prone_flat": "0.0,1.0,0.0",
        "prone_head_turned_left": "-0.1,1.0,0.0",
        "prone_head_turned_right": "0.1,1.0,0.0",
        "fetal_position_left": "-0.5,-0.5,0.0",
        "fetal_position_right": "0.5,-0.5,0.0",
        "lateral_recumbent_left": "-1.0,0.0,0.0",
        "lateral_recumbent_right": "1.0,0.0,0.0",
        "spinal_extension_mild": "0.0,0.1,0.0",
        "spinal_extension_maximum": "0.0,0.4,0.0",
        "spinal_flexion_forward": "0.0,-0.3,0.1",
        "spinal_flexion_deep": "0.0,-0.6,0.3",
        "lateral_tilt_left": "-0.2,0.0,0.0",
        "lateral_tilt_right": "0.2,0.0,0.0",
        "axial_rotation_left": "0.0,0.0,-0.3",
        "axial_rotation_right": "0.0,0.0,0.3",
        "lithotomy_position": "0.0,-0.7,-0.4",
        "trendelenburg_position": "0.0,-1.0,-0.3",
        "reverse_trendelenburg": "0.0,-1.0,0.3",
    },
    "postural_dynamics": {
        "crouching_low_compression": "0.0,-0.8,0.0",
        "crouching_mid_balance": "0.0,-0.4,0.0",
        "crouching_high_stance": "0.0,-0.2,0.0",
        "kneeling_upright_neutral": "0.0,-0.6,0.0",
        "kneeling_low_heel_sit": "0.0,-0.9,0.0",
        "kneeling_single_left_up": "-0.1,-0.5,0.1",
        "kneeling_single_right_up": "0.1,-0.5,0.1",
        "seated_upright_erect": "0.0,-0.5,0.0",
        "seated_slouched_anterior": "0.0,-0.5,0.2",
        "seated_crossed_legs_flat": "0.0,-0.5,0.1",
        "seated_reclined_passive": "0.0,-0.6,-0.3",
        "squat_full_deep": "0.0,-0.95,0.0",
        "squat_parallel_utility": "0.0,-0.7,0.0",
        "squat_wide_sumo": "0.0,-0.65,0.0",
        "standing_wide_base": "0.0,0.0,0.0",
        "standing_one_leg_left": "-0.2,0.1,0.0",
        "standing_one_leg_right": "0.2,0.1,0.0",
        "bending_waist_orthogonal": "0.0,-0.5,0.5",
        "stooping_low": "0.0,-0.6,0.4",
    },
    "extremity_articulation_upper": {
        "arms_overhead_extended_maximum": "0.0,1.8,0.0",
        "arms_lateral_t_pose": "0.0,1.2,0.0",
        "arms_akimbo_assertive": "0.3,0.5,0.0",
        "arms_crossed_chest": "0.0,0.5,0.1",
        "hands_behind_head_interlocked": "0.0,1.4,0.0",
        "reaching_forward_sagittal": "0.0,0.5,0.8",
        "reaching_down_vertical": "0.0,-0.5,0.5",
        "abduction_shoulder_left_90": "-0.8,0.5,0.0",
        "abduction_shoulder_right_90": "0.8,0.5,0.0",
        "adduction_shoulder_left_cross": "0.4,0.3,0.2",
        "adduction_shoulder_right_cross": "-0.4,0.3,0.2",
        "elbow_flexion_left_maximum": "-0.2,0.4,0.2",
        "elbow_flexion_right_maximum": "0.2,0.4,0.2",
        "elbow_extension_left_straight": "-0.5,0.0,0.0",
        "elbow_extension_right_straight": "0.5,0.0,0.0",
        "wrist_flexion_bilateral": "0.0,0.2,0.1",
        "wrist_extension_bilateral": "0.0,0.2,-0.1",
        "forearm_pronation_left": "-0.1,0.3,0.0",
        "forearm_pronation_right": "0.1,0.3,0.0",
        "forearm_supination_left": "-0.1,0.2,0.0",
        "forearm_supination_right": "0.1,0.2,0.0",
        "hands_clenched_fists": "0.0,0.3,0.2",
        "hands_open_palms_up": "0.0,0.3,0.3",
    },
    "extremity_articulation_lower": {
        "hip_flexion_left_90": "-0.2,0.4,0.4",
        "hip_flexion_right_90": "0.2,0.4,0.4",
        "hip_extension_left_back": "-0.1,-0.2,-0.5",
        "hip_extension_right_back": "0.1,-0.2,-0.5",
        "hip_abduction_left_wide": "-0.6,0.0,0.0",
        "hip_abduction_right_wide": "0.6,0.0,0.0",
        "knee_flexion_left_90": "-0.2,-0.3,-0.3",
        "knee_flexion_right_90": "0.2,-0.3,-0.3",
        "knee_hyper_extension": "0.0,0.05,0.0",
        "ankle_dorsiflexion_left": "-0.1,-0.9,0.1",
        "ankle_dorsiflexion_right": "0.1,-0.9,0.1",
        "ankle_plantarflexion_left": "-0.1,-1.1,-0.1",
        "ankle_plantarflexion_right": "0.1,-1.1,-0.1",
        "foot_inversion_bilateral": "0.0,-1.0,0.0",
        "foot_eversion_bilateral": "0.0,-1.0,0.0",
    },
    "gait_and_locomotion": {
        "walking_slow_cadence": "0.0,0.0,0.3",
        "walking_brisk_stride": "0.0,0.0,0.8",
        "running_jog_sustained": "0.0,0.0,1.5",
        "sprinting_full_propulsion": "0.0,0.0,2.5",
        "stumbling_unbalanced_anterior": "0.2,0.0,0.4",
        "leaping_vertical_clearance": "0.0,1.5,1.0",
        "sidestepping_left": "-0.5,0.0,0.0",
        "sidestepping_right": "0.5,0.0,0.0",
        "backpedaling_rapid": "0.0,0.0,-0.8",
        "crawling_quadrupedal": "0.0,-0.7,0.4",
        "climbing_vertical_ladder": "0.0,0.8,0.2",
        "marching_high_knee": "0.0,0.2,0.6",
        "pacing_reflective": "0.0,0.0,0.2",
        "lunging_forward_left": "-0.2,-0.4,0.6",
        "lunging_forward_right": "0.2,-0.4,0.6",
        "sliding_lateral_low": "0.0,-0.3,0.5",
    },
    "facial_and_cephalic_orientation": {
        "facing_north_true": "0.0,0.0,1.0",
        "facing_south_true": "0.0,0.0,-1.0",
        "facing_east_true": "1.0,0.0,0.0",
        "facing_west_true": "-1.0,0.0,0.0",
        "tilting_up_superior": "0.0,0.5,0.0",
        "tilting_down_inferior": "0.0,-0.5,0.0",
        "head_rotation_left_90": "0.0,0.0,-1.0",
        "head_rotation_right_90": "0.0,0.0,1.0",
        "head_lateral_flexion_left": "-0.3,0.1,0.0",
        "head_lateral_flexion_right": "0.3,0.1,0.0",
        "jaw_depression_open": "0.0,-0.1,0.0",
        "head_protraction_anterior": "0.0,0.0,0.2",
        "head_retraction_posterior": "0.0,0.0,-0.1",
    },
    "kinetic_combat_and_athletic": {
        "boxer_guard_left_lead": "-0.2,0.4,0.3",
        "boxer_guard_right_lead": "0.2,0.4,0.3",
        "martial_arts_crane_stance": "0.0,0.5,0.0",
        "punch_straight_jab_left": "-0.5,0.6,0.9",
        "punch_straight_cross_right": "0.5,0.6,1.1",
        "kick_front_snap_right": "0.3,0.8,0.8",
        "kick_roundhouse_right": "0.8,0.5,0.5",
        "athletic_ready_split_stance": "0.0,-0.2,0.1",
        "swimming_freestyle_stroke": "0.0,0.1,1.4",
        "yoga_warrior_one": "0.0,-0.3,0.4",
        "yoga_warrior_two": "0.0,-0.3,0.0",
        "yoga_downward_dog": "0.0,-0.5,0.6",
        "yoga_tree_pose_left": "-0.3,0.4,0.0",
        "yoga_tree_pose_right": "0.3,0.4,0.0",
        "sprinter_starting_blocks": "0.0,-0.7,0.2",
        "diving_tuck_midair": "0.0,1.0,0.5",
    },
    "crouching_hiding_actions": {
        "hide_behind_stones_desert": "0.0,-0.5,0.6",
        "hide_behind_waterfall_stones": "0.0,-0.7,0.3",
        "running_towards_camera": "0.0,0.0,1.5",
        "running_away_from_camera": "0.0,0.0,-1.5",
    },
    "ergonomic_and_occupational": {
        "typing_keyboard_desk": "0.0,-0.1,0.3",
        "lifting_heavy_box_ground": "0.0,-0.7,0.4",
        "reaching_top_shelf": "0.0,1.6,0.4",
        "driving_steering_wheel": "0.0,0.0,0.4",
        "operating_machinery_standing": "0.0,0.0,0.5",
        "writing_surface_sitting": "0.0,-0.4,0.2",
        "carrying_shoulder_load": "0.2,0.3,0.1",
        "pushing_heavy_object_anterior": "0.0,-0.1,0.6",
        "pulling_heavy_rope_posterior": "0.0,-0.1,-0.6",
        "scrubbing_floor_kneeling": "0.0,-0.8,0.3",
        "filming_camera_eye_level": "0.0,0.4,0.2",
        "saluting_military_protocol": "0.3,1.2,0.1",
    },
}

# ==============================================================================
# EXHAUSTIVE LAYOUT MANIFEST
# ==============================================================================
LAYOUT_MANIFEST = {
    "geometric_grids": {
        "isometric_spatial_grid": "AXIS_ALIGNMENT: ISO_30_DEGREE",
        "orthographic_grid_flat": "AXIS_ALIGNMENT: PURE_ORTHO_XYZ",
        "axonometric_projection": "AXIS_ALIGNMENT: AXONO_VARIABLE",
        "oblique_cabinet_projection": "AXIS_ALIGNMENT: OBLIQUE_45_DEGREE",
        "military_top_down_grid": "AXIS_ALIGNMENT: MILITARY_OBLIQUE",
        "dimetric_structural_grid": "AXIS_ALIGNMENT: DIMETRIC_TRUE",
        "trimetric_skewed_grid": "AXIS_ALIGNMENT: TRIMETRIC_RANDOMIZED",
    },
    "compositional_frameworks": {
        "rule_of_thirds_intersections": "LAYOUT: THIRD_PLANE_CROSSING",
        "golden_spiral_fibonacci": "LAYOUT: FIBONACCI_LOGARITHMIC_ARC",
        "dynamic_symmetry_armatures": "LAYOUT: DIAGONAL_RECIPROCAL_MESH",
        "central_focal_point": "LAYOUT: RADIAL_CONVERGENCE_CENTER",
        "pyramidal_structural_stack": "LAYOUT: TRIANGULAR_BASE_WEIGHT",
        "diagonal_leading_lines": "LAYOUT: CORNER_TO_CORNER_TRANSIT",
        "s_curve_fluid_flow": "LAYOUT: SINUSOIDAL_PATHWAY_TRAVERSAL",
    },
    "depth_stratification": {
        "foreground_heavy_occlusion": "DEPTH: FOREGROUND_PRIORITY_MAX_0.9",
        "midground_focal_anchor": "DEPTH: MIDGROUND_TARGET_Z_0.5",
        "background_infinity_drop": "DEPTH: BACKGROUND_INFINITE_Z_0.0",
        "three_tier_parallax_stack": "DEPTH: TRIPLE_LAYER_PARALLAX",
        "atmospheric_fog_fade": "DEPTH: SCATTERING_GRADIENT_DENSITY",
        "shallow_depth_bokeh": "DEPTH: APERTURE_PLANE_BLUR",
        "deep_focus_infinite_plane": "DEPTH: PINHOLE_OMNIPRESENT_FOCUS",
    },
    "multi_panel_sequences": {
        "triptych_three_view": "LAYOUT: TRIPTYCH_3_VIEW_STUDIO",
        "six_panel_composite": "LAYOUT: SIX_PANEL_DRAMATIC_GRID",
        "nine_panel_sequence": "LAYOUT: NINE_PANEL_FILM_STILL_STORY",
    },
    "distribution_heuristics": {
        "spatial_density_uniform": "DISTRIBUTION: UNIFORM_BALANCE_HIGH",
        "spatial_density_sparse": "DISTRIBUTION: ISOLATED_CLUSTER_LOW",
        "fibonacci_phyllotaxis_cluster": "DISTRIBUTION: PHYLLOTAXIS_SPIRAL_RATIO",
        "gaussian_central_distribution": "DISTRIBUTION: NORMAL_CURVE_DENSITY",
        "fractal_noise_clumping": "DISTRIBUTION: PERLIN_NOISE_STRUCTURAL",
        "radial_burst_scatter": "DISTRIBUTION: CENTRIFUGAL_DISPERSION",
        "grid_snap_rigid_alignment": "DISTRIBUTION: MATRIX_BOUND_RESTRAINED",
    },
}

# ==============================================================================
# MULTI-PANEL NESTED DEFINITIONS (FOR COMPILER INJECTION)
# ==============================================================================
MULTI_PANEL_DEFINITIONS = {
    "LAYOUT: SIX_PANEL_DRAMATIC_GRID": {
        "PANELS": "6",
        "VIEWS": {
            "FRONT MEDIUM CLOSE-UP (MCU)": "- LITHOTOMY_POSITION.",
            "BIRDS EYE (BE)": "AERIAL_VIEW; SLIGHTLY_IN_FRONT_OF_SUBJECT_LOOKING_DOWNWARD.",
            "FRONT EXTREME CLOSE-UP (ECU/XCU)": "[\n          FULL_LENGTH_OF_RIB_CAGE; TINE_DETAILS; FABRIC_WEAVE; RAZOR-SHARP_FOCUS_ON_TEXTURED_SKIN.\n      ],",
            "SIDE CLOSE-UP (SCU)": "[\n          ~45°_ROTATED_CLOCKWISE; CHEST_LEVEL; SLIGHTLY_TILTED_DOWNWARD. \n      ],",
            "THREE_QUARTER DRAMATIC HIGH ANGLE (TQDH)": "[\n          ~45°_ROTATED_CLOCKWISE_AND_SLIGHTLY_TILTED_DOWNWARD_FROM_8FT. \n      ],",
            "FRONT FISH EYE (FE)": "[\n          IMMERSIVE_SPATIAL_RELATIONSHIP; SHALLOW_DEPTH_OF_FIELD; FRAME_FILLED_FROM_SHOULDER_TO_SHOULDER.\n      ]"
        }
    },
    "LAYOUT: TRIPTYCH_3_VIEW_STUDIO": {
        "PANELS": "3",
        "VIEWS": {
            "FRONT FACING": "- ANATOMIC_NEUTRAL_FRONT.",
            "THREE QUARTER SIDE VIEW": "[\n          ~45°_ROTATED_CLOCKWISE; CHEST_LEVEL.\n      ],",
            "BACK VIEW": "- FULL_REAR_FACING."
        }
    },
    "LAYOUT: NINE_PANEL_FILM_STILL_STORY": {
        "PANELS": "9",
        "VIEWS": {
            "SEQUENCE_NARRATIVE": "[\n          CINEMATIC_FILM_STILLS; CHRONOLOGICAL_SUBJECT_TRACKING; SHALLOW_DEPTH_OF_FIELD.\n      ]"
        }
    }
}

# ==============================================================================
# EXHAUSTIVE STYLE MANIFEST
# ==============================================================================
STYLING_MANIFEST = {
    "Turbeville": "STYLE: GRAINY_DRAMATIC_FLASH_MACRO",
    "Yemchuk": "STYLE: MOODY_ETHEREAL_TEXTURE_FOCUSED",
    "Caravaggio": "STYLE: CHIAROSCURO_DRAMATIC_FIGURE_STUDY",
    "Fragonard": "STYLE: ROCOCO_CANDLELIT_INTIMACY",
    "cinematic_golden_hour": "STYLE: CINEMATIC_WARM_BLUE_GOLD_CONTRAST",
    "raw_candid_snapshot": "STYLE: RAW_FLASH_PHOTOGRAPHY_DSLR",
}

# ==============================================================================
# EXHAUSTIVE LIGHTING PHYSICS MANIFEST
# ==============================================================================
LIGHTING_PHYSICS_MANIFEST = {
    "fresnel_reflection_coefficient": "PHOTONIC_ENERGY: FRESNEL_ANGULAR_REFLECT_0.3",
    "specular_highlight_lobe": "PHOTONIC_ENERGY: SPECULAR_LOBE_SHARP_2.0",
    "lambertian_diffuse_reflectance": "PHOTONIC_ENERGY: LAMBERTIAN_DIFFUSE_0.6",
    "anisotropic_specular_reflection": "PHOTONIC_ENERGY: ANISOTROPIC_FIBER_45_DEG",
    "mean_free_path_scattering": "PHOTONIC_ENERGY: VOLUMETRIC_DEPTH_25MM",
    "photon_transmission_ratio": "PHOTONIC_ENERGY: TRANSMISSION_RATIO_40_PERCENT",
    "through_fabric_diffuse_bounce": "PHOTONIC_ENERGY: SCATTER_THROUGH_WEAVE",
    "rim_light_scattering_pass": "PHOTONIC_ENERGY: EDGE_TRANSLUCENCY_INTENSITY_8",
}

# ==============================================================================
# FLATTENED INDICES FOR O(1) LOOKUPS AND COMPLETIONS
# ==============================================================================
FLAT_POSE_INDEX = {}
for category_data in KINEMATIC_MANIFEST.values():
    for pose_key, vector_string in category_data.items():
        FLAT_POSE_INDEX[pose_key] = vector_string

FLAT_LAYOUT_INDEX = {}
for category_data in LAYOUT_MANIFEST.values():
    for layout_key, layout_string in category_data.items():
        FLAT_LAYOUT_INDEX[layout_key] = layout_string

FLAT_LIGHTING_INDEX = {}
for light_key, light_string in LIGHTING_PHYSICS_MANIFEST.items():
    FLAT_LIGHTING_INDEX[light_key] = light_string

FLAT_STYLE_INDEX = {}
for style_key, style_string in STYLING_MANIFEST.items():
    FLAT_STYLE_INDEX[style_key] = style_string

POSE_COMPLETIONS = list(FLAT_POSE_INDEX.keys())
LAYOUT_COMPLETIONS = list(FLAT_LAYOUT_INDEX.keys())
LIGHTING_COMPLETIONS = list(FLAT_LIGHTING_INDEX.keys())
STYLE_COMPLETIONS = list(FLAT_STYLE_INDEX.keys())


def resolve_tokens(user_input: str, target_index: dict, token_type: str) -> str:
    if not user_input or not user_input.strip():
        return "DEFAULT_IDENTITY_NULL"

    normalized = user_input.lower().strip().replace(" ", "_").replace("-", "_")

    # Coordinate array override check for poses
    if "," in normalized and token_type == "pose":
        parts = normalized.split(",")
        if len(parts) == 3:
            try:
                floats = [float(p.strip()) for p in parts]
                return f"{floats[0]},{floats[1]},{floats[2]}"
            except ValueError:
                pass

    if normalized in target_index:
        return target_index[normalized]

    for key, val in target_index.items():
        if key.startswith(normalized) or normalized.startswith(key):
            return val

    return user_input
