#!/usr/bin/env python3
# ==============================================================================
# INTEGRATED PARAMETER REGISTRY AND MATRIX LIBRARY VERSION 5 (promptlib.py)
# SYSTEM PLATFORM CONFIGURATION AND SEGREGATED LOOKUP DICTIONARIES
# SYNTAX AND NESTING PARITY WITH HDL SCHEMA SPEC
# ==============================================================================

# ==============================================================================
# KINEMATIC MANIFEST
# ==============================================================================
KINEMATIC_MANIFEST = {
    "structural_alignment": {
        "anatomic_neutral":             "0.0,0.0,0.0",
        "supine_flat":                  "0.0,-1.0,0.0",
        "supine_head_elevated":         "0.0,-0.9,0.1",
        "supine_legs_elevated":         "0.0,-0.9,-0.1",
        "prone_flat":                   "0.0,1.0,0.0",
        "prone_head_turned_left":       "-0.1,1.0,0.0",
        "prone_head_turned_right":      "0.1,1.0,0.0",
        "fetal_position_left":          "-0.5,-0.5,0.0",
        "fetal_position_right":         "0.5,-0.5,0.0",
        "lateral_recumbent_left":       "-1.0,0.0,0.0",
        "lateral_recumbent_right":      "1.0,0.0,0.0",
        "spinal_extension_mild":        "0.0,0.1,0.0",
        "spinal_extension_maximum":     "0.0,0.4,0.0",
        "spinal_flexion_forward":       "0.0,-0.3,0.1",
        "spinal_flexion_deep":          "0.0,-0.6,0.3",
        "lateral_tilt_left":            "-0.2,0.0,0.0",
        "lateral_tilt_right":           "0.2,0.0,0.0",
        "axial_rotation_left":          "0.0,0.0,-0.3",
        "axial_rotation_right":         "0.0,0.0,0.3",
        "dorsal_lithotomy_position":    "0.0,-0.7,-0.4",
        "supine_ribcage_arched_bridge": "Lying supine with thoracic spine and ribcage arched upward off linens, taut fabric across sternum [0.0,-0.8,0.3]",
        "prone_sphinx_elbow_prop": "Lying prone propped on forearms in sphinx alignment, lower back arched, reading or gazing forward [0.0,0.8,0.2]",
        "contrapposto_pelvic_tilt_classic": "Classical S-curve contrapposto with 15° pelvic tilt and counter-angled shoulder line [0.1,0.0,0.1]",
        "fowlers_reclined_45_deg": "Semi-reclined 45° Fowler posture against headboard/bolster with knees slightly bent [0.0,-0.5,0.2]",
        "contrapposto_classical_s_curve": "weight shifted onto right hip, left knee relaxed, spine forming classical S-curve (vector 0.1,0.0,0.1)",
        "reverse_contrapposto_dorsal_arch": "posterior stance with weight on left leg, lumbar spine arched, right shoulder dropped (vector -0.1,0.2,-0.1)",
        "cantilevered_backward_editorial_lean": "pelvis pushed forward, upper torso leaning back 25 degrees, neck taut and elongated (vector 0.0,0.3,-0.2)",
        "prone_sphinx_forearm_prop": "prone on floor propped on parallel forearms, chest lifted, collarbone catching key light (vector 0.0,0.8,0.2)",
        "supine_bridged_pelvic_lift": "supine with knees bent, hips elevated in low bridge, ribcage and sternum prominent (vector 0.0,-0.7,0.2)",
        "side_lying_odalisque_curve": "lateral recumbent posture propped on one elbow, upper hip creating dramatic silhouette arc (vector -0.8,-0.2,0.1)",
    },
    "postural_dynamics": {
        "crouching_low_compression":    "0.0,-0.8,0.0",
        "crouching_mid_balance":        "0.0,-0.4,0.0",
        "crouching_high_stance":        "0.0,-0.2,0.0",
        "kneeling_upright_neutral":     "0.0,-0.6,0.0",
        "kneeling_low_heel_sit":        "0.0,-0.9,0.0",
        "kneeling_single_left_up":      "-0.1,-0.5,0.1",
        "kneeling_single_right_up":     "0.1,-0.5,0.1",
        "seated_upright_erect":         "0.0,-0.5,0.0",
        "seated_slouched_anterior":     "0.0,-0.5,0.2",
        "seated_crossed_legs_flat":     "0.0,-0.5,0.1",
        "seated_reclined_passive":      "0.0,-0.6,-0.3",
        "seated_vanity_counter_lean":   "0.0,-0.4,0.3",
        "seated_casual_vanity_lean":    "seated casually on bathroom counter, leaning forward toward mirror, legs relaxed or crossed",
        "squat_full_deep":              "0.0,-0.95,0.0",
        "squat_parallel_utility":       "0.0,-0.7,0.0",
        "squat_wide_sumo":              "0.0,-0.65,0.0",
        "standing_wide_base":           "0.0,0.0,0.0",
        "standing_one_leg_left":        "-0.2,0.1,0.0",
        "standing_one_leg_right":       "0.2,0.1,0.0",
        "bending_waist_orthogonal":     "0.0,-0.5,0.5",
        "stooping_low":                 "0.0,-0.6,0.4",
        "seated_bed_edge_spinal_stretch": "Seated on bed edge facing 180° away, arms stretched high overhead elongating spine [0.0,-0.4,0.3]",
        "standing_wall_shoulder_blade_lean": "Standing with one shoulder blade pressed casually into architectural wall plane [-0.2,0.0,-0.1]",
        "arch_back_vanity_counter_brace": "Leaning back against vanity counter edge, palms braced behind hips, chest projected [0.0,-0.2,-0.3]",
        "editorial_contrapposto_s_curve": "classic S-curve posture, weight shifted to one hip, opposite knee bent creating negative space triangles (vector 0.15,-0.05,0.1)",
        "geometric_limb_triangulation": "limbs bent at sharp angles forming graphic geometric triangles around torso and jawline (vector 0.2,0.3,0.2)",
        "high_fashion_exaggerated_lean": "dramatic angular torso lean backward supported by locked rear leg, couture silhouette elongation (vector 0.0,0.35,-0.25)",
        "hunched_editorial_shoulder_drop": "deliberately broken posture, hunched shoulders, elongated neck, avant-garde runway attitude (vector 0.0,-0.25,0.15)",
        "baroque_dorsal_twist_contrapposto": "torso rotated 180 degrees from hip axis, spine arched showing muscular back anatomy and side profile (vector 0.2,0.1,-0.3)",
        "perched_stool_edge_crossed_ankles": "perched on front edge of studio stool, spine tall, knees together, ankles crossed (vector 0.0,-0.45,0.1)",
        "deep_avant_garde_plie_squat": "wide-stance sculptural plié squat, knees turned out, torso vertical, hands resting on inner thighs (vector 0.0,-0.75,0.0)",
    },
    "extremity_articulation_upper": {
        "arms_overhead_extended_maximum":   "0.0,1.8,0.0",
        "arms_lateral_t_pose":              "0.0,1.2,0.0",
        "arms_akimbo_assertive":            "0.3,0.5,0.0",
        "arms_crossed_chest":               "0.0,0.5,0.1",
        "hands_behind_head_interlocked":    "0.0,1.4,0.0",
        "reaching_forward_sagittal":        "0.0,0.5,0.8",
        "reaching_down_vertical":           "0.0,-0.5,0.5",
        "abduction_shoulder_left_90":       "-0.8,0.5,0.0",
        "abduction_shoulder_right_90":      "0.8,0.5,0.0",
        "adduction_shoulder_left_cross":    "0.4,0.3,0.2",
        "adduction_shoulder_right_cross":   "-0.4,0.3,0.2",
        "elbow_flexion_left_maximum":       "-0.2,0.4,0.2",
        "elbow_flexion_right_maximum":      "0.2,0.4,0.2",
        "elbow_extension_left_straight":    "-0.5,0.0,0.0",
        "elbow_extension_right_straight":   "0.5,0.0,0.0",
        "wrist_flexion_bilateral":          "0.0,0.2,0.1",
        "wrist_extension_bilateral":        "0.0,0.2,-0.1",
        "forearm_pronation_left":           "-0.1,0.3,0.0",
        "forearm_pronation_right":          "0.1,0.3,0.0",
        "forearm_supination_left":          "-0.1,0.2,0.0",
        "forearm_supination_right":         "0.1,0.2,0.0",
        "hands_clenched_fists":             "0.0,0.3,0.2",
        "hands_open_palms_up":              "0.0,0.3,0.3",
        "both_arms_raised_tying_updo": "Both arms raised behind head tying hair into an effortless bun, scapulae defined [0.0,1.3,-0.1]",
        "forearm_mirror_selfie_extension": "One forearm extended forward holding camera/phone in mirror reflection lock [0.2,0.6,0.5]",
        "one_hand_draped_across_clavicle": "One hand resting delicately across opposite collarbone, elbow relaxed against ribcage [0.1,0.4,0.1]",
        "both_elbows_flared_hands_at_temples": "elbows flared wide forming symmetrical frame around head, fingertips pressing temples (vector 0.0,1.3,0.2)",
        "draping_arm_across_clavicle": "one arm swept diagonally across chest, hand gripping opposite deltoid (vector 0.3,0.4,0.2)",
        "swan_neck_wrist_drape_overhead": "one arm arched overhead with relaxed swan-neck wrist flexion catching rim light (vector 0.1,1.6,0.1)",
        "asymmetric_shoulder_shrug_collar_grip": "one shoulder elevated sharply while opposite hand pulls garment lapel or strap (vector 0.2,0.5,0.2)",
    },
    "extremity_articulation_lower": {
        "hip_flexion_left_90":              "-0.2,0.4,0.4",
        "hip_flexion_right_90":             "0.2,0.4,0.4",
        "hip_extension_left_back":          "-0.1,-0.2,-0.5",
        "hip_extension_right_back":         "0.1,-0.2,-0.5",
        "hip_abduction_left_wide":          "-0.6,0.0,0.0",
        "hip_abduction_right_wide":         "0.6,0.0,0.0",
        "knee_flexion_left_90":             "-0.2,-0.3,-0.3",
        "knee_flexion_right_90":            "0.2,-0.3,-0.3",
        "knee_hyper_extension":             "0.0,0.05,0.0",
        "ankle_dorsiflexion_left":          "-0.1,-0.9,0.1",
        "ankle_dorsiflexion_right":         "0.1,-0.9,0.1",
        "ankle_plantarflexion_left":        "-0.1,-1.1,-0.1",
        "ankle_plantarflexion_right":       "0.1,-1.1,-0.1",
        "foot_inversion_bilateral":         "0.0,-1.0,0.0",
        "foot_eversion_bilateral":          "0.0,-1.0,0.0",
        "en_pointe_ankle_extension": "extreme plantarflexion lengthening calf muscle and Achilles tendon in high-fashion arch (vector 0.0,-1.15,-0.1)",
        "crossed_thigh_standing_scissors": "standing with one leg crossed tightly in front of the other, elongating hip-to-ankle line (vector 0.2,-0.1,0.1)",
        "bent_knee_wall_foot_brace": "standing against wall with one knee bent and sole of foot braced flat against vertical surface (vector -0.2,-0.3,-0.3)",
    },
    "gait_and_locomotion": {
        "walking_slow_cadence":             "0.0,0.0,0.3",
        "walking_brisk_stride":             "0.0,0.0,0.8",
        "running_jog_sustained":            "0.0,0.0,1.5",
        "sprinting_full_propulsion":        "0.0,0.0,2.5",
        "stumbling_unbalanced_anterior":    "0.2,0.0,0.4",
        "leaping_vertical_clearance":       "0.0,1.5,1.0",
        "sidestepping_left":                "-0.5,0.0,0.0",
        "sidestepping_right":               "0.5,0.0,0.0",
        "backpedaling_rapid":               "0.0,0.0,-0.8",
        "crawling_quadrupedal":             "0.0,-0.7,0.4",
        "climbing_vertical_ladder":         "0.0,0.8,0.2",
        "marching_high_knee":               "0.0,0.2,0.6",
        "pacing_reflective":                "0.0,0.0,0.2",
        "lunging_forward_left":             "-0.2,-0.4,0.6",
        "lunging_forward_right":            "0.2,-0.4,0.6",
        "sliding_lateral_low":              "0.0,-0.3,0.5",
        "running_towards_camera":           "0.0,0.0,1.5",
        "running_away_from_camera":         "0.0,0.0,-1.5",
        "runway_catwalk_cross_step": "long-stride runway walk with front foot crossing midline, hips swaying with fabric inertia (vector 0.1,0.0,0.9)",
        "whip_turn_180_hair_centrifugal": "rapid 180-degree pivot on ball of foot sending hair and hem flying outward (vector 0.0,0.2,-1.0)",
        "suspended_midair_couture_leap": "floating mid-air jump with relaxed face and billowing garment train frozen by strobe (vector 0.0,1.4,0.6)",
        "slow_staircase_descent_trailing_hand": "descending monumental steps, one hand trailing along stone balustrade (vector 0.0,-0.3,0.4)",
    },
    "facial_and_cephalic_orientation": {
        "facing_north_true":                "0.0,0.0,1.0",
        "facing_south_true":                "0.0,0.0,-1.0",
        "facing_east_true":                 "1.0,0.0,0.0",
        "facing_west_true":                 "-1.0,0.0,0.0",
        "tilting_up_superior":              "0.0,0.5,0.0",
        "tilting_down_inferior":            "0.0,-0.5,0.0",
        "head_rotation_left_90":            "0.0,0.0,-1.0",
        "head_rotation_right_90":           "0.0,0.0,1.0",
        "head_lateral_flexion_left":        "-0.3,0.1,0.0",
        "head_lateral_flexion_right":       "0.3,0.1,0.0",
        "jaw_depression_open":              "0.0,-0.1,0.0",
        "head_protraction_anterior":        "0.0,0.0,0.2",
        "head_retraction_posterior":        "0.0,0.0,-0.1",
        "chin_tilted_up_20_nostril_shadow": "chin raised 20 degrees toward key light, eyes looking down the nose at lens (vector 0.0,0.35,0.1)",
        "kubrick_brow_drop_upward_gaze": "head tilted forward 25 degrees while eyes lock straight into camera lens from beneath brows (vector 0.0,-0.35,0.2)",
        "over_shoulder_dorsal_chin_tuck": "facing away from camera with head turned 135 degrees so chin rests over scapula (vector 0.2,0.0,-0.8)",
        "lost_profile_three_quarter_away": "head turned 120 degrees away so only cheekbone contour, eyelashes, and jaw angle read (vector -0.4,0.0,-0.6)",
    },
    "kinetic_combat_and_athletic": {
        "boxer_guard_left_lead":            "-0.2,0.4,0.3",
        "boxer_guard_right_lead":           "0.2,0.4,0.3",
        "martial_arts_crane_stance":        "0.0,0.5,0.0",
        "punch_straight_jab_left":          "-0.5,0.6,0.9",
        "punch_straight_cross_right":       "0.5,0.6,1.1",
        "kick_front_snap_right":            "0.3,0.8,0.8",
        "kick_roundhouse_right":            "0.8,0.5,0.5",
        "athletic_ready_split_stance":      "0.0,-0.2,0.1",
        "swimming_freestyle_stroke":        "0.0,0.1,1.4",
        "yoga_warrior_one":                 "0.0,-0.3,0.4",
        "yoga_warrior_two":                 "0.0,-0.3,0.0",
        "yoga_downward_dog":                "0.0,-0.5,0.6",
        "yoga_tree_pose_left":              "-0.3,0.4,0.0",
        "yoga_tree_pose_right":             "0.3,0.4,0.0",
        "sprinter_starting_blocks":         "0.0,-0.7,0.2",
        "diving_tuck_midair":               "0.0,1.0,0.5",
    },
    "crouching_hiding_actions": {
        "hide_behind_stones_desert":        "0.0,-0.5,0.6",
        "hide_behind_waterfall_stones":     "0.0,-0.7,0.3",
        "hide_around_corner_wall":          "-0.3,-0.3,0.2",
        "peering_through_gap":              "0.0,-0.4,0.5",
        "flat_against_wall_side":           "0.0,0.0,0.0",
        "ducking_below_sill":               "0.0,-0.8,0.0",
        "crawling_under_cover":             "0.0,-0.9,0.3",
        "pressed_into_doorframe_shadow":    "0.0,-0.1,0.0",
        "crouching_behind_car_door":        "-0.2,-0.6,0.1",
        "lying_flat_under_surface":         "0.0,-1.0,0.0",
        "kneeling_against_column":          "0.0,-0.6,-0.1",
        "shadow_merge_standing_still":      "0.0,0.0,-0.1",
    },
    "ergonomic_and_occupational": {
        "typing_keyboard_desk":             "0.0,-0.1,0.3",
        "lifting_heavy_box_ground":         "0.0,-0.7,0.4",
        "reaching_top_shelf":               "0.0,1.6,0.4",
        "driving_steering_wheel":           "0.0,0.0,0.4",
        "operating_machinery_standing":     "0.0,0.0,0.5",
        "writing_surface_sitting":          "0.0,-0.4,0.2",
        "carrying_shoulder_load":           "0.2,0.3,0.1",
        "pushing_heavy_object_anterior":    "0.0,-0.1,0.6",
        "pulling_heavy_rope_posterior":     "0.0,-0.1,-0.6",
        "scrubbing_floor_kneeling":         "0.0,-0.8,0.3",
        "filming_camera_eye_level":         "0.0,0.4,0.2",
        "saluting_military_protocol":       "0.3,1.2,0.1",
        "phone_to_ear_standing":            "0.2,0.4,0.1",
        "reading_book_seated_forward":      "0.0,-0.4,0.3",
        "applying_makeup_mirror_lean":      "0.0,-0.3,0.4",
        "smoking_standing_exhale":          "0.0,0.1,-0.1",
        "drinking_glass_tipped_back":       "0.0,0.3,-0.2",
    },
    "intimate_and_expressive": {
        "arms_wrapped_self_embrace":        "0.0,0.3,0.1",
        "hand_over_mouth_suppressed":       "0.2,0.5,0.0",
        "head_in_hands_grief":              "0.0,-0.2,0.2",
        "hand_on_chest_heart":              "0.0,0.4,0.1",
        "fingers_through_hair_slow":        "0.0,0.7,0.1",
        "covering_eyes_one_hand":           "0.1,0.5,0.0",
        "one_arm_raised_wall_forearm_rest": "0.0,0.5,0.2",
        "resting_cheek_on_crossed_forearms": "Resting cheek sideways on crossed forearms atop linens or counter surface [0.0,-0.3,0.2]",
        "neck_arch_eyes_closed_exhale": "Head tilted back in serene neck arch, eyes closed, lips slightly parted on exhale [0.0,0.4,-0.1]",
        "two_fingers_parting_sheer_curtain": "Two fingers delicately parting sheer backlit curtain fabric near face [0.2,0.5,0.4]",
        "back_pressed_to_steamed_glass": "Dorsal spine and shoulder blades pressed flush against steamed glass partition [0.0,0.0,-0.3]",
        "thumb_hooked_in_waistband_hip_cocked": "thumb hooked into garment waistband or strap, hip cocked toward key light (vector 0.2,0.1,0.1)",
        "both_hands_smoothing_wet_hair_back": "both hands raking backward through damp hair, exposing forehead and cheekbones (vector 0.0,1.2,0.1)",
        "index_finger_pulling_collar_away": "single finger hooking neckline slightly forward to cast shadow across collarbone hollow (vector 0.1,0.4,0.2)",
        "chin_resting_on_crossed_forearms": "leaning on surface with chin resting lightly on stacked forearms, direct intimate gaze (vector 0.0,-0.2,0.3)",
    },
    "micro_hand_articulation": {
        "fingertips_resting_lightly_on_glass":  "0.0,0.1,0.3",
        "hand_gripping_fabric_high_tension":    "0.0,0.2,0.1",
        "fingers_interlaced_resting_chin":      "0.0,0.4,0.2",
        "single_index_finger_tracing_lip":      "0.1,0.5,0.0",
        "delicate_pinch_lifting_silk_hem": "Thumb and index finger delicately pinching and lifting 10-denier silk hem [0.2,-0.3,0.1]",
        "open_palm_pressed_flat_on_mirror": "Open palm pressed flat against mirror glass with condensation halo around fingers [0.1,0.5,0.4]",
        "fingers_hooked_in_waistband": "Thumbs or fingers hooked casually into waistband, elbows angled slightly back [0.2,-0.1,0.1]",
        "knuckles_resting_on_acrylic_floor": "Knuckles lightly grazing reflective studio floor plane in low crouch [0.0,-0.8,0.2]",
        "spread_fingers_pressing_condensation_glass": "open palm and spread fingers pressed flat against fogged glass creating clear contact halo (vector 0.0,0.4,0.5)",
        "knuckles_grazing_jawline_contour": "back of bent fingers lightly grazing mandibular angle without compressing cheek tissue (vector 0.1,0.5,0.1)",
        "fingertips_Adjusting_earring_or_nape": "slender fingers poised at earlobe and nape of neck, elbow angled toward camera (vector 0.2,0.7,0.0)",
    },
}

# ==============================================================================
# MULTI-PANEL LAYOUT MANIFEST
# ==============================================================================
LAYOUT_MANIFEST = {
    "single_panel": {
        "LAYOUT: SINGLE_FRAME": {
            "PANELS": "1",
            "VIEWS": {"PRIMARY": ""},
        },
    },
    "dual_panel": {
        "LAYOUT: DIPTYCH_HORIZONTAL": {
            "PANELS": "2",
            "VIEWS": {"LEFT": "", "RIGHT": ""},
        },
        "LAYOUT: DIPTYCH_VERTICAL": {
            "PANELS": "2",
            "VIEWS": {"TOP": "", "BOTTOM": ""},
        },
        "LAYOUT: BEFORE_AFTER": {
            "PANELS": "2",
            "VIEWS": {"BEFORE": "", "AFTER": ""},
        },
        "LAYOUT: TWO_PANEL_DUOTYCH": {"PANELS": "2", "VIEWS": {"FULL-BODY FRONT": "", "FULL-BODY REAR SYMMETRY": ""}},
        "LAYOUT: SPLIT_DIOPTER_DIPTYCH": {"PANELS": "2", "VIEWS": {"EXTREME CLOSE-UP (ECU/XCU)": "", "WIDE SHOT (WS/LS)": ""}},
    },
    "triple_panel": {
        "LAYOUT: TRIPTYCH": {
            "PANELS": "3",
            "VIEWS": {
                "FRONT FACING": "",
                "THREE QUARTER SIDE VIEW": "",
                "BACK VIEW": "",
            },
        },
        "LAYOUT: TRIPTYCH_NARRATIVE": {
            "PANELS": "3",
            "VIEWS": {"ACT_ONE": "", "ACT_TWO": "", "ACT_THREE": ""},
        },
        "LAYOUT: THREE_PANEL_TRIPTYCH": {"PANELS": "3", "VIEWS": {"FRONT FACING": "", "3/4 SIDE VIEW": "", "BACK VIEW": ""}},
    },
    "quad_panel": {
        "LAYOUT: FOUR_PANEL_CINEMATIC": {
            "PANELS": "4",
            "VIEWS": {
                "ESTABLISHING WIDE": "",
                "MEDIUM CLOSE-UP": "",
                "EXTREME CLOSE-UP": "",
                "REACTION SHOT": "",
            },
        },
        "LAYOUT: FOUR_PANEL_2x2": {
            "PANELS": "4",
            "VIEWS": {
                "TOP_LEFT": "", "TOP_RIGHT": "",
                "BOTTOM_LEFT": "", "BOTTOM_RIGHT": "",
            },
        },
        "LAYOUT: FOUR_PANEL_POSTERIOR_LOCK": {"PANELS": "4", "VIEWS": {"PRONE REAR": "", "MIRROR 180°": "", "WORM'S-EYE REAR": "", "REAR PROFILE TILT": ""}},
        "LAYOUT: FOUR_PANEL_LIGHT_STUDY": {"PANELS": "4", "VIEWS": {"FRONTAL KEY": "", "BACKLIT SILHOUETTE": "", "3/4 REMBRANDT": "", "OVERHEAD BUTTERFLY": ""}},
    },
    "six_panel": {
        "LAYOUT: SIX_PANEL_COMPOSITE": {
            "PANELS": "6",
            "VIEWS": {
                "FRONT MEDIUM CLOSE-UP (MCU)": "",
                "BIRDS EYE (BE)": "",
                "FRONT EXTREME CLOSE-UP (ECU/XCU)": "",
                "SIDE CLOSE-UP (SCU)": "",
                "THREE_QUARTER DRAMATIC HIGH ANGLE (TQDH)": "",
                "FRONT FISH EYE (FE)": "",
            },
        },
        "LAYOUT: SIX_PANEL_2x3": {
            "PANELS": "6",
            "VIEWS": {
                "R1_C1": "", "R1_C2": "", "R1_C3": "",
                "R2_C1": "", "R2_C2": "", "R2_C3": "",
            },
        },
        "LAYOUT: SIX_PANEL_WORMSEYE_360": {"PANELS": "6", "VIEWS": {"REAR MEDIUM CLOSE-UP (RMCU)": "", "WORMS-EYE STRAIGHT UP (NADIR)": "", "45° LOW OBLIQUE": "", "UNDERNEATH GLASS": "", "REAR WORM'S-EYE": "", "CORE TORSO MACRO": ""}},
    },
    "nine_panel": {
        "LAYOUT: NINE_PANEL_COMPOSITE": {
            "PANELS": "9",
            "VIEWS": {
                "FRONT MEDIUM CLOSE-UP (MCU)": "",
                "BIRDS EYE (BE)": "",
                "FRONT EXTREME CLOSE-UP (ECU/XCU)": "",
                "SIDE CLOSE-UP (SCU)": "",
                "THREE_QUARTER DRAMATIC HIGH ANGLE (TQDH)": "",
                "FRONT FISH EYE (FE)": "",
                "REAR MEDIUM SHOT (RMS)": "",
                "OVERHEAD MACRO (OHM)": "",
                "DUTCH ANGLE WORM EYE (DAWE)": "",
            },
        },
        "LAYOUT: NINE_PANEL_3x3": {
            "PANELS": "9",
            "VIEWS": {
                "R1_C1": "", "R1_C2": "", "R1_C3": "",
                "R2_C1": "", "R2_C2": "", "R2_C3": "",
                "R3_C1": "", "R3_C2": "", "R3_C3": "",
            },
        },
    },
    "five_panel": {
        "LAYOUT: FIVE_PANEL_POSTERIOR_LOCK": {"PANELS": "5", "VIEWS": {"PRONE": "", "STRETCH": "", "MACRO REAR": "", "CURL": "", "CURTAIN": ""}},
        "LAYOUT: FIVE_PANEL_CROSS_SEQUENCE": {"PANELS": "5", "VIEWS": {"ESTABLISHING WIDE": "", "MEDIUM HERO": "", "ECU EYES": "", "ECU FABRIC": "", "FULL CLOSER": ""}},
    },
    "eight_panel": {
        "LAYOUT: EIGHT_PANEL_ISO_GRID": {"PANELS": "8", "VIEWS": {"ISO_ANGLE_01": "", "ISO_ANGLE_02": "", "ISO_ANGLE_03": "", "ISO_ANGLE_04": "", "ISO_ANGLE_05": "", "ISO_ANGLE_06": "", "ISO_ANGLE_07": "", "ISO_ANGLE_08": ""}},
    },
}

# ==============================================================================
# CAMERA VIEWS MANIFEST
# ==============================================================================
VIEWS_MANIFEST = {
    "EXTREME CLOSE-UP (ECU/XCU)":               "Fills frame with single feature — eye, mouth, hand",
    "CLOSE-UP (CU)":                             "Head and shoulders only, tight on face",
    "MEDIUM CLOSE-UP (MCU)":                     "Chest and above — classic portrait framing",
    "MEDIUM SHOT (MS)":                          "Waist and above — standard conversational",
    "FULL SHOT (FS)":                            "Head to toe — full body in frame",
    "WIDE SHOT (WS/LS)":                         "Subject dwarfed by environment — context dominant",
    "EXTREME WIDE SHOT (EWS/XLS)":              "Maximum environment — subject near invisible",
    "BIRDS EYE (BE)":                            "True overhead, 90° looking directly down",
    "AERIAL OBLIQUE (AO)":                       "45–70° downward from height — dramatic spatial context",
    "WORM EYE LOW ANGLE (WELA)":                 "Camera at ground level looking steeply upward",
    "LOW ANGLE DUTCH (LAD)":                     "Below subject, canted frame — power + disorientation",
    "HIGH ANGLE STANDARD (HAS)":                 "Above subject looking down at 20–45°",
    "SIDE CLOSE-UP (SCU)":                       "Lateral profile, chest level, slight downward tilt",
    "THREE_QUARTER DRAMATIC HIGH ANGLE (TQDH)":  "45° rotated, elevated 8ft, looking down",
    "FRONT FISH EYE (FE)":                       "Ultra-wide rectilinear distortion, full front",
    "FRONT EXTREME CLOSE-UP MACRO (ECUM/XCUM)":  "100mm macro, full rib cage, f/2.8, razor sharp",
    "OVER_SHOULDER (OS)":                        "Camera behind and above one shoulder, sees face",
    "DUTCH_ANGLE_45 (DA45)":                     "Frame canted 45° clockwise — tension, instability",
    "TRACKING_LATERAL (TL)":                     "Camera moves parallel to subject mid-motion",
    "REACTION SHOT (RS)":                        "Tight on face catching emotional response",
    "INSERT MACRO DETAIL (IMD)":                 "Object or body-part detail — hands, lips, fabric",
    "SPLIT DIOPTER (SD)":                        "Two focal planes sharp simultaneously",
    "RACK_FOCUS_PULL (RFP)":                     "Foreground sharp → background sharp, soft middle",
    "COWBOY SHOT (CS)":                          "Mid-thigh to head — American Western framing",
    "TWO SHOT (2S)":                             "Two subjects in same frame, balanced composition",
    "POINT OF VIEW (POV)":                       "Camera occupies subject's optical perspective",
    "EXTREME MACRO DETAIL (XMD)":               "Sub-millimetre magnification — pore, thread, droplet",
    "REVERSE ANGLE (RA)":                        "180° cut from prior angle — facing same axis",
    "HANDHELD UNSTABLE (HU)":                    "Deliberate camera shake — urgency, documentary feel",
    "SURVEILLANCE HIGH STATIC (SHS)":           "Fixed high-corner security-cam aesthetic, wide",
    "SNORKEL UNDERWATER (SUW)":                 "Below waterline looking up — distorted refraction",
    "PERISCOPE LOW FLOOR (PLF)":                "Camera at floor plane looking along surface",
    "SILHOUETTE CONTRE-JOUR (SCJ)":             "Subject fully backlit, detail lost to pure shadow form",
    "PROFILE STRICT (PS)":                      "Pure 90° lateral — zero facial front, full depth",
    "NAPE OF NECK (NON)":                       "Tight on back of neck, base of skull, hair fall",
    "HAND DETAIL MACRO (HDM)":                  "Hands only — knuckles, veins, tension, grip detail",
    "DOLLY ZOOM VERTIGO (DZV)": "Z-axis optical dolly-in simultaneous with optical zoom-out, warping background perspective",
    "CRAB TRACK LATERAL (CTL)": "Continuous horizontal dolly movement parallel to moving subject, maintaining strict lateral profile",
    "PEDESTAL VERTICAL BOOM (PVB)": "Camera body mechanically raised or lowered along vertical axis without tilting optical angle",
    "ORBIT 360 GIMBAL SWEEP (O360)": "Smooth circular camera revolution maintaining lock on subject centroid",
    "WHIP PAN TRANSITION (WPT)": "High-velocity rotational pan generating directional motion blur across transitional frame",
    "LOW ANGLE GROUND NADIR (LAGN)": "Extreme ground-level perspective aimed directly at zenith, towering anatomical distortion",
    "DUTCH ANGLE CANTED (DAC)": "Camera rotated 25-45 degrees off horizon line, injecting kinetic tension and visual instability",
    "CRANE JIB ARC SWEEP (CJAS)": "Sweeping vertical-to-horizontal crane trajectory rising from close detail to wide architectural reveal",
    "SNORRICAM BODY MOUNT (SBM)": "Camera rigged directly to subject torso so subject stays locked center while background lurches",
    "WORMS-EYE STRAIGHT UP (NADIR)": "Floor-mounted camera pointing 90 degrees straight up at ceiling and underside of chin",
    "THREE QUARTER SIDE VIEW (TQHS)": "45-degree classic angled portrait view balancing facial symmetry and jawline depth",
    "FRONT SIDE PROFILE (SP)": "Strict 90-degree lateral silhouette emphasizing nose bridge, lips, chin, and posture line",
    "FULL REAR VIEW FACING AWAY (FRV)": "180-degree dorsal full-length view capturing back drapery, spine line, and heel stance",
    "REAR MEDIUM CLOSE-UP (RMCU)": "Over-the-shoulder rear medium close-up highlighting nape of neck, scapula, and hair texture",
    "CHEST-LEVEL EYE-LINE (CL)": "Neutral sternum-height camera placement for grounded, intimate editorial proportion",
    "PANORAMA ULTRA-WIDE (PANO)": "2.39:1 or 65:24 panoramic horizontal field capturing subject within monumental architecture",
    "FRONT EXTREME CLOSE-UP MACRO(ECUM/XCUM)": "100mm macro, full rib cage and skin micro-relief at f/2.8, razor-sharp",
    "FRONT MEDIUM CLOSE-UP (MCU)": "Frontal chest-and-head framing with direct eye-line engagement",
    "FRONT EXTREME CLOSE-UP (ECU/XCU)": "Tight frontal crop isolating eyes, lips, or clavicle micro-detail",
    "FRONT CLOSE-UP (CU)": "Frontal head-and-shoulders beauty crop",
    "FRONT MEDIUM SHOT (MS)": "Frontal waist-up editorial framing",
    "FRONT FULL SHOT (FS)": "Frontal head-to-toe full-length lookbook framing",
    "FRONT WIDE SHOT (WS)": "Frontal wide architectural framing showing full set and peripheral C-stands",
    "FRONT EXTREME WIDE SHOT (EWS)": "Frontal monumental vista with subject anchored in expansive environment",
}

# ==============================================================================
# PHOTOGRAPHY STYLE MANIFEST
# ==============================================================================
STYLING_MANIFEST = {
    "HELMUT_NEWTON": "High-contrast monochrome and cold chrome color, low-angle 35mm/50mm perspective, hard on-axis flash or harsh Riviera sunlight, dominant architectural power poses",
    "STEVEN_KLEIN": "Subversive cinematic neo-noir, desaturated cyan/steel shadows with saturated crimson accents, hard gridded strobes, high-gloss oiled skin, intense psychological tension",
    "GUY_BOURDIN": "Hyper-saturated Kodachrome and glossy enamel color blocking, uncanny surreal narrative framing, fragmented crop geometry, high-gloss specular reflections and jet-black drop shadows",
    "ELLEN_VON_UNWERTH": "Playful kinetic femininity, grainy 35mm black-and-white and warm flash snapshot immediacy, unguarded laughter, backstage cabaret energy",
    "PETRA_COLLINS": "Dreamy 35mm analog film halation, Tiffen Pro-Mist pastel magenta/amber color gels, soft diffused domestic nostalgia and intimate youth portraiture",
    "CASS_BIRD": "Spirited kinetic candor, natural open-air daylight, effortless tomboy elegance, warm medium-format Portra skin tones and joyous movement",
    "ELLEN_VON_UNWERTH_AND_PETRA_COLLINS_AND_CASS_BIRD": "Tri-fusion of kinetic 35mm flash playfulness, dreamy pastel Pro-Mist film halation, and candid open-air editorial warmth",
    "ROXANNE_LOWIT": "Authentic backstage runway and VIP nightlife reportage, direct compact 35mm flash, candid champagne-and-mirror dressing room intimacy",
    "MARIO_SORRENTI": "Intimate sculptural skin realism, warm directional window or single-softbox chiaroscuro, raw emotional closeness on 6x7 medium-format film",
    "DAVID_LACHAPELLE": "Hyper-pop technicolor surrealism, high-powered multi-strobe saturation, glossy theatrical set design, electric magenta/cyan gels and specular skin sheen",
    "TIM_WALKER": "Fantastical practical soundstage wonderland sets, oversized surreal props, wide-angle lens distortion, pastel daydream color palettes and theatrical daylight",
    "NADIA_LEE_COHEN": "Hyper-stylized 1960s/70s Technicolor cinema Americana, saturated midday sun balanced with hard strobe, deadpan Hitchcockian character staging",
    "DEBORAH_TURBEVILLE_AND_YELENA_YEMCHUK": "Sepia-toned melancholic romanticism, distressed grain and scratched negative edges, decaying aristocratic interiors and poetic Eastern European surrealism",
    "CORINNE_DAY": "Raw 1990s grunge realism, unretouched natural skin, bare apartment walls, direct on-camera 35mm flash and unadorned documentary honesty",
    "NAN_GOLDIN": "Intimate diaristic 35mm Kodachrome slide aesthetic, available tungsten/neon room light mixed with raw direct flash, deep emotional vulnerability",
    "LARRY_CLARK": "Gritty subcultural 35mm street documentary, harsh available daylight and raw bedroom tungsten, unposed youth realism",
    "DAIDO_MORIYAMA": "Are-Bure-Boke (grainy, blurry, out-of-focus) high-contrast black-and-white 35mm compact street photography, tilted frames and deep crushed blacks",
    "HORST_P_HORST_AND_RICHARD_AVEDON": "Classical Neoclassical three-point Fresnel chiaroscuro sculpting fused with kinetic high-fashion motion against stark seamless backdrops",
    "PETER_LINDBERGH_AND_LEE_MILLER": "Soulful unretouched black-and-white silver gelatin realism, 85mm/105mm medium-telephoto intimacy, wind-swept natural daylight, and surrealist shadow geometry",
    "MARIO_TESTINO_AND_BRUCE_WEBER": "Sun-drenched jet-set exuberance and classic golden-hour athleticism, warm bounce reflectors, luminous skin polish and heroic camaraderie",
    "ANNIE_LEIBOVITZ_AND_TYLER_MITCHELL_AND_CAMPBELL_ADDY": "Painterly Caravaggio octabank chiaroscuro on hand-painted canvas fused with sun-lit utopian warmth and bold primary-color studio sovereignty",
    "HERB_RITTS": "Sculptural California sunlight and desert dry-lakebed minimalism, high-contrast black-and-white silver gelatin, wet/oiled anatomical contours against open sky",
    "EMMA_SUMMERTON": "Lush nocturnal botanical romanticism, rich saturated color gels, cinematic dreamscape narratives and tactile couture textures",
    "RYAN_MCGINLEY": "Euphoric open-road youth in motion, golden-hour flare,colored smoke bombs, blurred kinetic freedom and neon nocturnal caves",
    "JUERGEN_TELLER": "Unfiltered Contax G2 45mm f/2 + TLA 200 direct flash immediacy, slightly overexposed skin highlights, raw unretouched honesty in everyday luxury settings",
    "TERRY_RICHARDSON": "Stark white studio wall, direct on-camera compact flash, hard black drop shadow directly behind subject, high-contrast snapshot raw energy",
    "PAOLO_ROVERSI": "Dreamy 8x10 large-format Polaroid emulsion, multi-second long exposure with subtle motion blur, north-window daylight blended with handheld Mag-Lite tungsten light painting",
    "NICK_KNIGHT": "Avant-garde SHOWstudio experimentation, backlit Opal Perspex light-boxes, dynamic color smoke, digital solarization and sculptural McQueen silhouettes",
    "STEVEN_MEISEL": "Chameleonic high-fashion mastery, precision Mamiya RZ67 studio lighting, cinematic narrative tableaux and razor-sharp editorial polish",
    "GLEN_LUCHFORD": "Cinematic 35mm anamorphic widescreen storytelling, atmospheric tungsten/HMI film lighting, melancholic nocturnal mood and shallow depth of field",
    "SOLVE_SUNDSBO": "High-tech studio optical innovation, projected patterns, liquid/wind physics, pristine medium-format sharpness and futuristic chromatic lighting",
    "INEZ_AND_VINOODH": "Razor-sharp digital medium-format clarity, bold sculptural contrast, intense direct gaze, seamless marriage of stark minimalism and avant-garde drama",
    "CRAIG_MCDEAN": "Kinetic studio precision, wind-machine fabric geometry, crispBroncolor parabolic lighting, deep saturated color and athletic modernity",
    "FRANCESCA_WOODMAN": "Slow-shutter black-and-white 6x6 medium-format self-staging in peeling rooms, spectral motion blur merging the human figure with architecture",
    "CINDY_SHERMAN": "Cinematic untitled film-still artifice, theatrical prosthetic/wardrobe persona transformation, dramatic tungsten key lighting and narrative tension",
    "DIANE_ARBUS": "Direct frontal twin-lens reflex (Rolleiflex/Mamiya) flash-in-daylight portraiture, psychological intensity and unflinching documentary candor",
    "LISETTE_MODEL": "Low-angle 35mm street expressionism, bold cropped figures, visceral high-contrast silver print tonality",
    "RALPH_GIBSON": "Minimalist high-contrast Leica 50mm geometric abstraction, deep ink blacks, stark architectural fragments and surreal crop tension",
    "JEANLOUP_SIEFF": "Wide-angle 21mm/28mm elongation, brooding French monochrome, rich dodging-and-burning vignette and elongating dorsal perspectives",
    "SARAH_MOON": "Impressionistic out-of-focus soft-focus diffusion, degraded autochrome color and sepia monochrome, timeless poetic nostalgia",
    "BETTINA_RHEIMS": "Tactile studio intimacy, warm incandescent skin rendering, theatrical hotel-room staging and confrontational eye contact",
    "ANDERS_PETERSEN": "Raw Café Lehmitz high-contrast black-and-white 35mm closeness, coarse pushed Tri-X grain, unguarded nocturnal camaraderie",
    "NOBUYOSHI_ARAKI": "High-contrast 35mm date-stamped compact flash diary, stark rope/flower geometry, visceral Tokyo urban intimacy",
    "MASAHISA_FUKASE": "Stark high-contrast monochrome, ink-black silhouettes, melancholic grain and solitary poetic isolation",
    "DOROTHEA_LANGE": "Iconic large-format Graflex documentary humanism, natural raking daylight carving weathered skin texture and quiet resilience",
    "GORDON_PARKS": "Masterful Life-magazine environmental photojournalism and high-fashion elegance, dramatic available shadow play and dignified Kodachrome color",
    "KWAME_BRATHWAITE": "Lush 1960s 'Black is Beautiful' Hasselblad medium-format warmth, rich celebratory studio color and regal natural hair/jewelry illumination",
    "DEANA_LAWSON": "Large-format 4x5/medium-format staged domestic shrines, rich saturated interior textures, direct flash-balanced lighting and mythic posture",
    "ZANELE_MUHOLI": "High-contrast black-and-white studio portraiture with deep melanin luminance, gleaming ocular catchlights and sculptural everyday headpieces",
    "HARLEY_WEIR": "Tactile close-up body and fabric topography, warm sun-baked earth tones, sensual curves and organic analog film color",
    "COCO_CAPITAN": "Offbeat deadpan analog 35mm framing, muted daylight palettes, wry conceptual staging and unpretentious candid proportion",
    "JAMIE_HAWKESWORTH": "Warm Mamiya RB67 medium-format documentary portraiture, soft northern overcast daylight, hand-printed darkroom color warmth",
    "JACK_DAVISON": "Experimental chiaroscuro, antique lenses and hand-held glass refraction, deep ink shadows with piercing single-source highlights",
    "BRIANNA_CAPOZZI": "Hyper-clean commercial studio subversion, hard shadowless ring/parabolic flash, playful grotesque angles and crisp color pop",
    "COLLIER_SCHORR": "Intimate analog studio and location portraiture, quiet androgynous poise, soft natural window wrap and tactile film grain",
    "WOLFGANG_TILLMANS": "Democratic visual diary, unmanipulated daylight and club strobe, razor-sharp still-life detail alongside candid youth subculture",
    "BORIS_MIKHAILOV": "Gritty post-Soviet street realism, hand-tinted and faded color shifts, raw unadorned human vulnerability",
    "MARTIN_PARR": "Ring-flash + ultra-wide macro in bright midday sun, hyper-saturated consumer color and deadpan social observation",
    "ALEC_SOTH": "Large-format 8x10 view camera environmental portraiture, contemplative Mississippi/heartland daylight, vast narrative space and fine tonal detail",
    "GREGORY_CREWDSON": "Large-format 8x10 soundstage twilight realism, condor-rigged HMI fog shafts balanced with warm domestic tungsten practicals, cinematic psychological stillness",
    "PHILIP_LORCA_DICORCIA": "Staged street documentary using concealed radio-triggered strobes to isolate subjects in a theatrical pool of Caravaggio light amid urban ambient dusk",
    "NADAV_KANDER": "Muted desaturated atmospheric palettes, vast mist-shrouded architectural scale, quiet contemplative studio portrait lighting",
    "ERWIN_OLAF": "Precision Dutch studio tableaux, immaculate Vermeer-inspired directional softbox lighting, porcelain skin tones and suppressed emotional tension",
    "VIVIANE_SASSEN": "Bold primary-color geometric shadows under harsh equatorial midday sun, abstract body silhouettes and surrealist pigment contrast",
    "MERT_AND_MARCUS": "High-octane digital hyper-glamour, cross-lit saturated magenta/cyan/gold strobes, sculpted metallic skin sheen and razor-sharp couture polish",
    "LUIGI_AND_IANGO": "Pure studio elegance on 8x10/medium-format, wind-swept hair, high-contrast black-and-white beauty dish sculpting and commanding supermodel presence",
    "CHRIS_VON_WANGENHEIM": "Provocative 1970s high-gloss flash drama, dark nocturnal backgrounds, visceral tension and razor-sharp specular highlights",
    "HIRO": "Monumental minimalist studio precision, unexpected surreal juxtaposition, hyper-sharp macro-to-infinity lighting and bold graphic silhouettes",
    "IRVING_PENN": "Master of the minimalist north-light corner studio and hand-painted canvas backdrop, platinum-palladium tonal richness, absolute psychological and textural clarity",
    "RICHARD_AVEDON_STREET": "Kinetic Paris street fashion in motion and stark white-seamless 8x10 portraiture, crisp strobe/open-shade acuity and unflinching facial topography",
    "MAN_RAY_SURREALIST": "Solarized Sabattier edge reversal, avant-garde shadow geometry, 1930s Paris Surrealism",
    "EDWARD_STEICHEN_MODERNIST": "Art Deco geometric studio shadow play, dramatic theatrical spotlighting",
    "CECIL_BEATON_BAROQUE": "Theatrical Regency-inspired set drapery, reflective foil backdrops, society elegance",
    "NORMAN_PARKINSON_KINETIC": "Outdoor kinetic fashion in motion, crisp telephoto street elegance",
    "PATRICK_DEMARCHELIER_CLASSIC": "Effortless studio beauty dish warmth, flattering catchlights, timeless couture grace",
    "GEORGE_HOYNINGEN_HUENE": "Neoclassical sculptural lighting, chiaroscuro marble-like anatomy, minimalist geometry",
    "ELIZAVETA_PORODINA": "Experimental kaleidoscopic glass refraction, moody theatrical color gels, surreal emotion",
    "CARLITO_DALCEGGIO": "Visionary bohemian color saturation, mythic ritual staging, expressive painterly light",
    "WILLIAM_KLEIN_WIDE": "Wide-angle 28mm street fashion energy, graphic motion blur, bold editorial contrast",
    "LILLIAN_BASSMAN": "Bleached high-contrast darkroom brush work, gestural romantic silhouette",
    "ROBERT_MAPPLETHORPE": "Classical Renaissance sculpture in studio monochrome, Hasselblad 500C/M on tripod, precision directional softbox + grid rim carving muscle and petal geometry",
    "SLIM_AARONS": "Mid-century jet-set poolside leisure in Palm Springs and the Riviera, sun-drenched Kodachrome daylight, wide environmental architectural framing",
    "MELVIN_SOKOLSKY": "1963 Harper's Bazaar surrealist ingenuity — models levitating in transparent Plexiglas bubbles over the Paris Seine, crisp telephoto compression",
    "ERWIN_BLUMENFELD": "Avant-garde Dadaist darkroom experimentation, ribbed frosted-glass studio refraction, solarization, and graphic primary-color veil overlays",
    "FRANCESCO_SCAVULLO": "Iconic 1970s/80s studio glamour, seamless white bounce-umbrella clamshell lighting, luminous catchlights, and effortless wind-blown hair",
    "ARTHUR_ELGORT": "Spontaneous 35mm/Leica jazz-like street fashion movement, natural daylight snapshots, joyous ballerina leaps and candid café poise",
    "SAUL_LEITER": "Early Kodachrome color abstraction shot through rain-streaked glass, steamed café windows, umbrellas, and muted telephoto color planes",
    "WILLIAM_EGGLESTON": "Dye-transfer demokratische camera color saturation, oblique Golden-Hour Southern light transforming mundane gas stations and interiors into hyper-vivid art",
    "STEPHEN_SHORE": "8x10 large-format view camera Uncommon Places precision, deep f/22 hyperfocal clarity, warm 1970s American color negative fidelity",
    "JOEL_MEYEROWITZ": "Luminous 8x10 Cape Light pastel twilight gradations and electric 35mm NYC street energy mingling steam, neon, and golden dusk",
    "FAN_HO": "Architectural 1950s Hong Kong geometric light shafts slicing through alley smoke and market mist on Rolleiflex 6x6 monochrome",
    "HIROSHI_SUGIMOTO": "Ultra-long-exposure 8x10 large-format zen minimalism, infinite silver-tone gradations from pitch black to pure highlight",
    "SEBASTIAO_SALGADO": "Monumental high-contrast silver gelatin chiaroscuro, dramatic storm clouds and raking sunlight illuminating human dignity and rugged terrain",
    "YOUSUF_KARSH": "8x10 Calumet view camera with tungsten Fresnel spots carving every pore, brow furrow, and hand vein against dark velvet",
    "PLATON_WIDE_PORTRAIT": "Hasselblad with 30mm/40mm wide-angle lens inches from the face against stark white or vignetted seamless, monumental perspective power",
    "DAN_WINTERS": "Precision 4x5 large-format portrait lighting with gridded honeycombs, warm ochre-green tonal palette, scientific studio stillness",
    "ALBERT_WATSON": "High-contrast 4x5/medium-format graphic power, surgical pin-spot lighting, rich carbon blacks and tactile skin/feather micro-detail",
    "ANTON_CORBIJN": "Gritty lith-printed high-contrast black-and-white grain, raw outdoor overcast landscapes, brooding rock-icon gravitas",
    "RINEKE_DIJKSTRA": "4x5 large-format tripod beach portraiture, low horizon line, overcast natural sky balanced with subtle frontal fill flash",
    "SHIRIN_NESHAT": "Stark black-and-white poetic contrast, calligraphic ink textures over hands and faces, solemn architectural symmetry",
    "CARRIE_MAE_WEEMS": "Single overhead pendant lamp above a kitchen table on monochrome film, intimate domestic staging and deep narrative resonance",
    "NADINE_IJEWERE": "Warm sun-drenched medium-format color harmony, joyful sisterhood geometry, lush natural landscapes and rich skin-tone celebration",
    "CHARLOTTE_WALES": "Playful contemporary surrealism, airy pastel studio light, whimsical perspective shifts and featherweight fabric motion",
    "ALASDAIR_MCLELLAN": "Romantic northern British daylight, crisp 6x7 Pentax medium-format portraiture, wind-swept moors and understated youth nostalgia",
    "TYRONE_LEBON": "Raw multi-format collage aesthetic, saturated 35mm/120 film warmth, candid behind-the-scenes intimacy and experimental framing",
    "REN_HANG": "Stark direct ring/compact flash against bare studio walls or nocturnal rooftops, graphic anatomical geometry and primary red lip/nail accents",
    "BRASSAI_PARIS_NIGHT": "Nocturnal 1930s Paris wrapped in dense river fog, halation around gas streetlamps, wet cobblestones and long-exposure mystery",
    "BILL_BRANDT": "Extreme wide-angle police-camera distortion on beaches and dark interiors, high-contrast soot-and-chalk silver gelatin prints",
    "HARRY_CALLAHAN": "Stark high-contrast minimalism, figures silhouetted against snow or bright water, razor-sharp graphic abstraction",
    "HENRI_CARTIER_BRESSON": "The Decisive Moment on 35mm Leica + 50mm lens, uncropped geometric equilibrium, natural available light and kinetic poise",
    "MARK_SELIGER": "Editorial 6x7 medium-format environmental storytelling, warm tungsten/strobe balance and rich hand-painted Oliphant canvas backdrops",
    "CHRISTOPHER_DOYLE_WONG_KAR_WAI": "Step-printed 8fps shutter smear, saturated tungsten/fluorescent neon green-amber cross-processing, rain-streaked nocturnal longing",
    "ROGER_DEAKINS_NATURALISTIC_COVE": "Unbleached muslin ring-bounce cove lighting, clean single-source motivated window shadow, atmospheric haze with zero artificial clutter",
    "GORDON_WILLIS_PRINCE_OF_DARKNESS": "Overhead softbox top-light leaving eyes in deep velvety shadow Pools, warm amber-sepia underexposure and 4:1 noir contrast",
    "EMMANUEL_LUBEZKI_NATURAL_WIDE": "Ultra-wide 14mm/18mm rectilinear lens inches from subject in pure golden-hour backlight or firelight with organic lens flare"
}

# ==============================================================================
# LIGHTING PHYSICS MANIFEST
# ==============================================================================
LIGHTING_PHYSICS_MANIFEST = {
    "dramatic_studio_lighting_camera_left": "Single-source spotlight directly overhead shining down. Photonic interaction treated as pure optical variable governed by incidence angle (grazing angles produce heightened contour emphasis) and source power (linear-to-exponential increase in modeling intensity and light resistence)",
    "intense_direct_overhead_spotlight": "intense, direct, single-source overhead light, hard flash luminosity with harsh shadows and specular highlights",
    "on_camera_popup_flash_5500K": "Hard on-axis flash, inverse-square falloff, harsh catch-lights",
    "off_camera_strobe_45_left_5600K": "45° camera-left hard strobe, sharp single shadow",
    "off_camera_strobe_45_right_5600K": "45° camera-right hard strobe, mirrored shadow",
    "ring_flash_on_axis_5500K": "Flat fill, signature ring catch-light, zero shadow",
    "bare_bulb_handheld_flash_5400K": "Omnidirectional scatter, wrap-around hard light",
    "softbox_large_octagonal_5600K": "Broad soft wrap, graduated shadow edge",
    "softbox_strip_narrow_5600K": "Directional wrap, controlled spill, classic beauty",
    "beauty_dish_silver_5500K": "Punchy skin texture, specular punch, mid-shadow",
    "beauty_dish_white_5500K": "Softer punch, less specular than silver dish",
    "parabolic_reflector_deep_5600K": "Focused hard spot, specular column, long throw",
    "fresnel_spotlight_5600K": "Variable hard/soft with grid, theatrical control",
    "hmi_daylight_5600K": "Parallel near-zero falloff, hard cinema key",
    "led_panel_bicolor_variable_K": "Variable colour temp, soft even field, low shadow",
    "tungsten_open_face_3200K": "Warm hard directional, high CRI warmth",
    "tungsten_softbox_3200K": "Warm soft wrap, low colour temp, incandescent glow",
    "candle_practical_1800K": "Extreme warm point source, 1600K, hard short falloff",
    "neon_tube_practical_variable": "Coloured ambient wash, hum artefact, retro-industrial",
    "fluorescent_overhead_bank_4000K": "Flat overhead fill, green-shift potential, commercial",
    "window_natural_daylight_5600K": "Soft directional side fill, rolling gradient shadow",
    "window_overcast_diffused_6500K": "Flat cool fill, near-zero contrast, even skin tone",
    "skylight_open_shade_7000K": "Cool blue fill from open sky, subtle specular",
    "bounce_silver_reflector_fill": "Specular bounce fill, 0.7 ratio to key",
    "bounce_white_card_fill": "Soft matte bounce fill, 0.3–0.5 ratio",
    "no_fill_true_ratio_lighting": "No fill — deep shadows, pure ratio setup",
    "practical_lamp_3000K_background": "Background warm practical, 0.1 ratio ambient bleed",
    "ambient_tungsten_3200K_background": "Dim warm background glow, ratio 0.04",
    "ambient_moonlight_4100K": "Cool blue-grey ambient, very low intensity",
    "grid_10_degree": "Tight grid on key — zero spill, spot control",
    "grid_30_degree": "Medium grid — moderate spill control",
    "gel_CTO_full_warm_3200K": "Full CTO warm gel over daylight source",
    "gel_CTB_full_cool_6500K": "Full CTB cool gel over tungsten source",
    "gel_red_saturated": "Deep red ambient wash, dramatic colour",
    "gel_green_saturated": "Sickly green wash — clinical, horror adjacent",
    "gel_blue_deep": "Cold blue wash — night, alienation",
    "snoot_tight_beam": "Narrow cone, precise hot-spot isolation",
    "barn_doors_four_way": "Rectangular spill control on key source",
    "diffusion_silk_heavy": "Heavy diffusion over strobe — very soft",
    "diffusion_frost_light": "Light frost — minor softening, retains punch",
    "shadow_razor_hard_zero_penumbra": "Jet-black drop shadows, zero feather, contact print hard",
    "shadow_moderate_10pct_feather": "Slight edge softness, still defined",
    "shadow_soft_graduated_30pct": "Gradual transition, 30% penumbra blend zone",
    "shadow_no_shadow_high_key": "No visible shadow — flat even illumination",
    "shadow_double_crosslit_artifact": "Two shadow directions from cross-lit sources",
    "shadow_long_oblique_directional": "Long stretched shadow — subject at oblique angle to key",
    "flash_sync_1_60_standard": "Standard flash sync, slight ambient bleed at slow end",
    "flash_sync_1_125_standard": "Clean standard sync, minimal ambient",
    "flash_sync_1_250_hss": "High-speed sync, daylight killing capability",
    "flash_sync_1_500_hss_full_kill": "Maximum daylight suppression, pure flash look",
    "long_exposure_bulb_ambient_bleed": "Bulb exposure + flash pop — motion blur background",
    "practical_tv_screen_cool_flicker": "Blue-white TV glow, 5000–6500K flicker, low intensity",
    "practical_lighter_flame_very_close": "Extreme warm point source, 1600K, hard short falloff",
    "practical_phone_screen_uplight": "Cold uplight from screen, 6000K, ghostly underlighting",
    "practical_fridge_light_interior": "Diffused cold white from below, 4500K, deep shadow top",
    "practical_aquarium_caustic_blue": "Undulating blue caustic ripple, 7000K, water refraction",
    "red_room_darkroom_safelight": "Mono-chromatic deep red, 620nm, near-zero modelling",
    "uv_blacklight_fluorescent_365nm": "UV reactive surface glow, ambient near-black, neon pop",
    "fireplace_embers_low_practical": "Deep amber ember glow, 1200K, very dim, warm shadow fill",
    "sodium_vapour_street_590nm": "Monochromatic warm orange, desaturates colour, flat CRI",
    "mercury_vapour_cool_405nm": "Cold blue-purple industrial, skin appears grey-green",
    "laser_pointer_grid_overlay": "Coherent 532nm green or 650nm red point scatter",
    "hmi_par_5600K_hard_parallel": "Hard parallel HMI PAR — simulates direct sun beam",
    "hmi_fresnel_5600K_spot_mode": "Focusable fresnel spot, hard centre, soft edge",
    "arri_skypanel_s60_full_colour": "RGB+W LED soft panel, full colour mixing, even field",
    "dedolight_150W_focusable": "Tiny hard focusable source, extreme precision, 3200K",
    "kino_flo_4bank_5600K": "Fluorescent soft bank, low contrast, fashion fill",
    "chimera_lightbank_large": "Large softbox equivalent over strobe, very soft",
    "litepanels_astra_bicolor": "LED panel, variable 3200–5600K, low heat, soft field",
    "leko_source_four_spot_5600K": "Ellipsoidal spotlight, sharp iris-cut beam, theatrical",
    "astera_titan_tube_RGB_practical": "RGBWW pixel tube, full colour, remote DMX, practical",
    "skypanel_s60_overhead_softbox": "ARRI SkyPanel overhead, full-field soft top light",
    "18k_hmi_through_window_silk": "18K HMI bounced through diffusion silk — sun simulation",
    "teal_orange_hollywood_grade": "Complementary teal shadow / orange skin grade",
    "monochrome_silver_gelatin_grade": "Desaturated B&W with silver halide grain emulation",
    "cross_process_e6_in_c41": "Slide film cross-processed — cyan shadows, yellow skin",
    "bleach_bypass_silver_retention": "Increased contrast, desaturated, gritty silver overlay",
    "lo_fi_expired_film_colour_shift": "Random colour cast, fogging, light leak edge bloom",
    "cyanotype_blue_grade": "Prussian blue monochrome, photogram aesthetic",
    "sepia_albumin_warm_grade": "19th-century warm brown-gold print emulation",
    "butterfly_paramount_beauty_dish": "Key light directly in front and elevated 45 degrees, casting iconic small butterfly shadow under nose",
    "clamshell_two_light_reflector": "Upper key beauty dish paired with lower silver reflector or soft fill, erasing sub-chin shadow",
    "rembrandt_45_triangle_key": "45-degree elevated key creating small characteristic light triangle on shadow cheek, 4:1 shadow ratio",
    "loop_lighting_30_degree_key": "Key light 30 degrees off-axis and slightly above eye level casting small loop shadow from nose",
    "split_lighting_90_degree_chiaroscuro": "Hard key at 90 degrees lateral bisecting face into exact sunlit and shadow halves",
    "short_lighting_sculpted_cheek": "Key light illuminates the side of face turned away from camera, narrowing and sculpting cheekbones",
    "broad_lighting_open_face": "Key light illuminates the side of face turned toward camera for high-key open clarity",
    "cross_key_dual_contour_edge": "Two opposing rim lights 180 degrees apart sculpting shoulder and jaw contours, fill-suppressed core",
    "venetian_blind_gobo_slits": "Collimated hard beam cast through Venetian blind gobo, projecting sharp geometric shadow bands",
    "water_caustic_refraction_projection": "Undulating rippling water caustic patterns projected across subject face and collarbone",
    "briese_focus_180_parabolic": "Focused parabolic tungsten-strobe hybrid delivering crisp micro-specular skin punch with soft wrap",
    "broncolor_para_222_feathered": "Giant 2.2m parabolic reflector feathered across subject for three-dimensional couture fabric modeling",
    "book_light_bleached_muslin_bounce": "HMI bounced into 12x12 bleached muslin and pushed through 1/2 grid cloth for ultra-creamy wrap",
    "dichroic_prism_rainbow_dispersion": "Optical spot projected through flint-glass prism casting spectral rainbow band across eyes",
    "broncolor_para_133_hr_focused_spot": "Broncolor Para 133 HR 24-brace parabolic reflector at focused rod position — crisp specular punch and high micro-contrast",
    "broncolor_para_177_defocused_wrap": "Broncolor Para 177 parabolic reflector at defocused flood position — enveloping three-dimensional studio wrap",
    "briese_focus_140_tungsten_strobe_blend": "Briese Focus.2 140 reflector mixing 2000W tungsten core warmth with 5500K flash tube crispness",
    "briese_focus_220_giant_cinema_key": "Massive 2.2m Briese Focus 220 parabolic key delivering head-to-toe couture specular uniformity",
    "profoto_pro_11_freeze_mode_1_80000s": "Profoto Pro-11 2400Ws pack in Freeze Mode at 1/80,000s t0.1 flash duration freezing airborne droplets and hair",
    "profoto_hard_box_point_source_sun": "Profoto HardBox modifier eliminating internal reflector scatter to cast razor-sharp midday solar shadows",
    "profoto_giant_240_silver_parabolic": "240cm Profoto Giant silver parabolic reflector creating expansive wrap-around fashion catchlights",
    "arri_orbiter_open_face_6_color_spectra": "ARRI Orbiter 6-color LED engine with Open Face 30° optic and high-CRI full-spectrum skin fidelity",
    "arri_orbiter_projection_optic_gobo_cut": "ARRI Orbiter with 25° Projection Optic and internal shutter blades slicing a surgical light bar across the eyes",
    "arri_m18_1800w_hmi_max_reflector": "ARRI M18 lensless MAX reflector HMI blasting a 5600K shaft through exterior casement windows",
    "arri_t12_12kw_fresnel_tungsten_key": "Classic Hollywood 12,000W tungsten Fresnel key light with warm 3200K incandescent skin glow",
    "mole_richardson_10k_tener_solarspot": "Vintage Mole-Richardson 10K Solarspot Fresnel casting classic Golden Age Hollywood shadow geometry",
    "matthews_book_light_12x12_bleached_muslin_grid": "Hollywood grip book light: 18K HMI bounced into 12x12 bleached muslin and diffused through silent 1/4 grid cloth",
    "matthews_open_end_double_scrim_feather": "Matthews open-end wire double scrim placed in the bottom half of the key beam to attenuate foreground exposure by 1 stop without altering shadow hardness",
    "matthews_dots_and_fingers_local_flagging": "Precision grip dots and fingers positioned on C-stands to selectively shade ears and neck while leaving cheekbones bright",
    "matthews_cucoloris_wood_cookie_dappled": "Carved wooden cucoloris cookie placed between Fresnel spot and subject to cast organic dappled foliage shadows",
    "black_4x8_v_flat_negative_fill_corridor": "Twin matte-black 4x8 foamcore V-flats flanking subject at 45cm to absorb all ambient bounce and carve deep cheekbone shadows",
    "chinese_paper_lantern_36in_skirted_boom": "Boomed 36-inch skirted paper lantern directly over table/bed for intimate 360-degree eye-level soft glow",
    "aputure_infinibar_pb12_rgbww_pixel_array": "Seamless geometric triangle/hex array of linear RGBWW pixel bars reflecting in cornea and glossy leather",
    "creamsource_vortex8_rain_backlight": "IP65 weather-sealed 650W Vortex8 LED array backlighting heavy rain sheets without diffusion",
    "dedolight_dp1_imager_eye_slash": "Dedolight 150W with DP1 framing projector cutting a razor-thin horizontal light slit across the bridge of the nose and irises",
    "k5600_joker_bug_800_octabank": "800W daylight HMI Joker-Bug inside 5ft octabank for crisp location fashion fill against bright sky",
    "nanlux_evoke_2400b_overhead_soft_box": "2400W bi-color point source in overhead 8x8 chimera lightbank for shadowless soundstage top-light",
    "maglite_handheld_long_exposure_light_painting": "Paolo Roversi signature technique: 4-second shutter in dark room while painting face and fabric folds with a handheld warm Mag-Lite beam",
    "irving_penn_north_skylight_diffused_curtain": "Irving Penn studio setup: angled overhead north skylight softened with muslin curtains over a tight corner backdrop",
    "avedon_open_desert_shade_white_seamless": "Richard Avedon 'In the American West' setup: subject standing under open desert sky shade in front of stark white seamless paper with zero direct sun",
    "horst_trompe_loeil_three_point_fresnel": "Horst P. Horst classical 1939 studio setup: three hard tungsten Fresnels sculpting marble-like dorsal contours and cast shadow edges",
    "newton_on_axis_ring_plus_streetlamp_mix": "Helmut Newton nocturnal mix: raw portable battery flash balanced 1 stop above ambient 2200K Parisian streetlamps",
    "bourdin_hard_strobe_gloss_enamel_bounce": "Guy Bourdin high-saturation setup: bare-bulb strobe bouncing off hyper-saturated glossy enamel walls with deep black drop shadows",
    "ritts_california_zenith_sun_silver_card": "Herb Ritts outdoor sculptural setup: harsh 60° desert sunlight with a low silver California Sunbounce card filling the jawline",
    "leibovitz_feathered_octabank_chiaroscuro": "Annie Leibovitz signature setup: 7ft Profoto Octabank feathered 60° past the subject so only the soft edge of the beam grazes the face, balanced 1.5 stops above ambient",
    "crewdson_soundstage_twilight_crane_hmi": "Gregory Crewdson cinematic setup: condor-mounted 18K HMIs through fog combined with warm 2800K practical house/car lights at dusk",
    "dicorcia_hidden_scaffolding_strobe_street": "Philip-Lorca diCorcia 'Heads' setup: concealed radio-triggered Profoto strobe rigged to street scaffolding isolating one pedestrian in a theatrical pool of light",
    "mert_and_marcus_saturated_magenta_cyan_gel_cross": "Mert & Marcus high-gloss setup: cross-lit high-powered strobes gelled in electric magenta and deep cyan over oiled skin",
    "roversi_window_sidelight_plus_tungsten_torch": "North window daylight balanced with a 3200K tungsten torch creating dual-temperature cyan/amber tonal separation",
    "knight_backlit_opal_perspex_silhouette": "Nick Knight SHOWstudio setup: floor-to-ceiling backlit white Opal Perspex wall with soft frontal fill and smoke diffusion"
}

# ==============================================================================
# PHOTONIC ENERGY MANIFEST
# ==============================================================================
PHOTONIC_ENERGY_MANIFEST = {
    # ── Distribution Models ────────────────────────────────────────────────────
    "MICROFACET_DISTRIBUTION":              "GGX/Trowbridge-Reitz — physically based rough surface model",
    "LAMBERTIAN_DIFFUSE":                   "Perfectly diffuse matte surface — equal scattering all directions",
    "OREN_NAYAR_ROUGH_DIFFUSE":             "Rough diffuse — accounts for retroreflection on textured surfaces",
    "COOK_TORRANCE_SPECULAR":               "Classic physically-based specular model — energy conserving",
    "ASHIKHMIN_SHIRLEY_ANISOTROPIC":        "Anisotropic highlight elongation along surface tangent",
    "GGX_ANISOTROPIC_FABRIC":              "GGX with anisotropic tangent — silk, satin weave",
    # ── Scattering / Transmission ──────────────────────────────────────────────
    "SUBSURFACE_SCATTERING":               "Light penetrates surface — skin, wax, translucent tissue",
    "SCATTER_THROUGH_WEAVE":               "Photon passes through low-denier fabric weave gaps",
    "DIRECT_ANGULAR_PENETRATION_V8":       "High-angle direct penetration — sheer fabric flash-through",
    "EPIDERMAL_TRANSLUCENCY_PASS":         "Dermal layer light scatter — subsurface skin glow",
    "THROUGH_FABRIC_DIFFUSE_BOUNCE":       "Bounce light diffuses through fabric before exiting",
    "RAY_MARCHING_VOLUMETRIC":             "Volume rendering — smoke, fog, god-rays, atmosphere",
    "SINGLE_SCATTER_VOLUMETRIC":           "Single-event light scatter in participating media",
    "MULTIPLE_SCATTER_VOLUMETRIC":         "Deep volume scatter — optically thick media",
    # ── Photon Behaviour Flags ─────────────────────────────────────────────────
    "RIM_LIGHT_SCATTERING_PASS":           "Backlit rim scatter — glowing edge separation on skin",
    "BACKLIT_SUBSURFACE_GLOW":             "Transmitted glow through thin tissue when backlit",
    "MEAN_FREE_PATH_MEDIUM":               "Average photon travel before scatter event — skin ~2–4mm",
    "MEAN_FREE_PATH_SHORT":                "Dense scatter — very short free path, fast diffusion",
    "MEAN_FREE_PATH_LONG":                 "Sparse scatter — long free path, deep penetration",
    "SPOTLIGHT_TRANSVERSE_ORBIT_360":      "360° transverse orbit lighting simulation",
    "ISOTROPIC_DIFFUSION":                 "Equal scatter probability in all directions",
    "ENERGY_CONSERVATION_COMPLIANT":       "Total output energy ≤ input — no phantom emission",
    "TRANSPARENCY_FOCUSED":               "Priority on transmission and scatter over reflection",
    # ── Reflectance Coefficients ───────────────────────────────────────────────
    "FRESNEL_HIGH":                        "Strong angle-dependent reflectance — wet surfaces, glass",
    "FRESNEL_MEDIUM":                      "Moderate Fresnel — typical skin at grazing angle",
    "FRESNEL_LOW":                         "Weak Fresnel — dry matte skin, cloth",
    "SPECULAR_LOBE_TIGHT_HIGH":            "Narrow bright specular highlight — polished, wet",
    "SPECULAR_LOBE_BROAD_LOW":             "Wide soft specular — rough, dry, matte",
    "LAMBERTIAN_REFLECTANCE_HIGH":         "High diffuse albedo — bright white or pale skin",
    "LAMBERTIAN_REFLECTANCE_LOW":          "Low diffuse albedo — dark skin, dark fabric",
    # ── Advanced PBR Extensions ────────────────────────────────────────────────
    "WARD_DUER_ANISOTROPIC":               "Anisotropic highlight elongation along surface tangent",
    "BLINN_PHONG_SPECULAR":                "Classic non-PBR specular lobe — legacy render feel",
    "THINFILM_INTERFERENCE":               "Soap-bubble iridescence — nanometre thin film diffraction",
    "RETROREFLECTIVE_COATING":             "Light returns directly to source — safety vest, cat eye",
    "VELVET_ASHIKHMIN_PREETHAM":           "Cloth-specific BRDF — forward scatter + limb brightening",
    "HAIR_MARSCHNER_MODEL":                "R, TT, TRT scatter paths for individual hair fibre",
    "KAJIYA_KAY_HAIR_SPECULAR":            "Simplified hair highlight — specular band along shaft",
    "SKIN_DONNER_JENSEN_SSS":              "Dipole/multipole SSS — dermal and epidermal layers",
    "CORNEA_REFRACTION_PASS":              "Eye lens refraction — specular highlight + iris depth",
    "WET_SURFACE_PUDDLE_REFLECTION":       "Ground-plane water mirror — sky reflection + ripple",
    "CAUSTIC_PROJECTION_UNDERWATER":       "Refracted light caustic patterns on subsurface planes",
    "PARTICIPATING_MEDIA_MIST":            "In-scattering atmosphere — god rays, depth haze",
    "CHROMATIC_ABERRATION_LENS":           "RGB channel split at frame edges — lens aberration",
    "LENS_DISTORTION_BARREL":              "Outward geometric distortion — wide-angle characteristic",
    "DIFFRACTION_STARBURST_PATTERN":       "Aperture blade starburst on specular highlights at f/16+",
    "SENSOR_NOISE_HIGH_ISO":               "Random luminance/chroma noise pattern — pushed ISO emul",
    "FILM_GRAIN_T_MAX_3200":               "Silver halide grain cluster — pushed T-MAX grain map",
    "HALATION_CINESTILL_RED_BLEED":        "Red channel bleed halo around bright sources — Cinestill",
    "DISNEY_PRINCIPLED_BSDF_SHEEN": "Disney Principled BSDF grazing retroreflection and cloth sheen lobe",
    "HANRAHAN_KRUEGER_LAYERED_SSS": "Hanrahan-Krueger layered subsurface scattering across epidermis and dermis",
    "SCHLICK_GRAZING_RETROREFLECTION": "Schlick Fresnel approximation with roughness-driven grazing retroreflection",
    "OPENPBR_MULTISCATTER_COMPENSATION": "OpenPBR energy-conserving multi-scatter microfacet compensation lobe",
    "SMITH_GGX_HEIGHT_CORRELATED": "Height-correlated Smith G2 masking-shadowing function for realistic micro-roughness",
    "CHRISTENSEN_BURLEY_DIFFUSION_SSS": "Christensen-Burley normalized diffusion profile for realistic red-channel skin scatter",
    "RANDOM_WALK_VOLUMETRIC_SSS": "Path-traced random-walk subsurface scattering through thin cartilage, ears, and nostrils",
    "DUAL_LOBE_SPECULAR_PELLICLE": "Dual-lobe specular microfacet model capturing both oily sebum sheen and fine pore relief",
    "ANISOTROPIC_MICRO_GROOVE_TANGENT": "Tangent-aligned anisotropic micro-groove BRDF for brushed metal and silk twill",
}

# ==============================================================================
# RAY TRACING PHOTOMETRY MANIFEST
# ==============================================================================
RAY_TRACING_MANIFEST = {
    "light_sources": {
        "SINGLE_CONICAL_SPOTLIGHT":             "Hard directional cone, high contrast focused beam",
        "OMNIDIRECTIONAL_POINT_SOURCE":         "Unbounded spherical emission from a single point",
        "AREA_LIGHT_SOFT_PANEL":                "Rectangular emission surface, soft shadow wrap",
        "PARALLEL_DIRECTIONAL_SUN":             "Infinite distance simulation, parallel rays",
        "PARABOLIC_COLLIMATED_BEAM": "Tightly collimated parabolic reflector beam with high axial candela",
        "ELLIPSOIDAL_GOBO_PROJECTOR": "Sharp-edged optical framing projector with pattern gobo slot",
        "RING_ILLUMINATOR_COAXIAL": "Coaxial circular macro ring source surrounding the objective lens",
    },
    "coordinates": {
        "2.50,-4.50,16.00":                     "Default camera-left elevated origin",
        "-0.04,5.67,2.39":                      "Default center-subject target",
        "0.00,10.00,0.00":                      "Direct overhead zenith origin",
        "0.00,2.20,3.50": "Frontal elevated beauty-dish butterfly key coordinate",
        "-3.20,1.80,-2.00": "Rear camera-left 135-degree rim kicker coordinate",
        "0.00,-1.20,1.80": "Low floor-level uplight coordinate",
    },
    "beam_angles": {
        "10_DEGREE_SPOT":                       "Very tight pin-spot, dramatic isolation",
        "28_DEGREE_FOCUS":                      "Standard theatrical spot focus",
        "45_DEGREE_FLOOD":                      "Wide flood spread",
        "120_DEGREE_WASH":                      "Ultra-wide ambient wash",
        "5_DEGREE_PINSPOT": "Surgical 5-degree optical snoot isolating eyes or hands only",
        "60_DEGREE_BEAUTY_DISH": "Classic 60-degree beauty dish spread with central deflector plate",
    },
    "intensity": {
        "110_PERCENT_SCALE":                    "Over-driven, intentionally clipping central highlights",
        "100_PERCENT_SCALE":                    "Nominal maximum exposure",
        "50_PERCENT_SCALE":                     "Mid-level fill intensity",
    },
    "falloff": {
        "AGGRESSIVE_INVERSE_SQUARE":            "Physically accurate, rapid light decay",
        "LINEAR_ATTENUATION":                   "Stylized slow decay for constant illumination",
        "ZERO_FALLOFF_ORTHOGRAPHIC":            "No decay over distance",
    },
    "bounce_logic": {
        "INFINITE_RECURSIVE_REFLECTION":        "Full path tracing, hall of mirrors effect",
        "SINGLE_BOUNCE_GLOBAL_ILLUMINATION":    "Fast GI, one bounce environment scatter",
        "DIRECT_ILLUMINATION_ONLY":             "No bounce, pitch black deep shadows",
    }
}

# ==============================================================================
# HARDWARE MANIFEST — CAMERA BODIES
# ==============================================================================
CAMERA_BODY_MANIFEST = {
    "Canon EOS 5D Mark IV": "36×24mm CMOS, 30.4MP, DIGIC 7, Dual Pixel AF",
    "Canon EOS 5D Mark III": "36×24mm CMOS, 22.3MP, DIGIC 5+, classic film-era output",
    "Canon EOS R5": "45MP BSI CMOS, IBIS, 8K RAW, Dual Pixel CMOS AF II",
    "Canon EOS-1D X Mark III": "20.1MP, 16fps, CFexpress, pro sport/studio hybrid",
    "Nikon D850": "45.7MP BSI CMOS, 153pt AF, tilting LCD, clean ISO",
    "Nikon D800": "36.3MP FX, legendary landscape/studio resolution",
    "Nikon Z7 II": "45.7MP BSI, IBIS, Z-mount mirrorless, dual card",
    "Sony A7R V": "61MP BSI Exmor R, AI-AF, 5-axis IBIS, compact FF",
    "Sony A7R lV": "And a Sony FE 50mm f/1.2 GM",
    "Sony A7 III": "24.2MP BSI, dual native ISO, versatile hybrid",
    "Sony A1": "50MP, 30fps, 8K video, global shutter option",
    "Canon EOS 5D MARK IV": "And A Canon EF 100mm f/2.8L Macro IS USM",
    "Nikon D850 with": "A Nikkor 60mm f/2.8G Micro",
    "Phase One IQ4 150MP With": "A Schneider Kreuznach 120mm f/4 Macro",
    "Hasselblad X2D 100C": "100MP BSI, 5-axis IBIS, no AA filter, natural colour",
    "Phase One IQ4 150MP": "150MP CMOS back, 16-bit RAW, trichromatic option",
    "Fujifilm GFX 100S": "102MP BSI CMOS, IBIS, compact MF, superb film sims",
    "Fujifilm GFX 50R": "51.4MP MF, rangefinder body, rich tonal gradation",
    "Pentax 645Z": "51.4MP CMOS, weather-sealed, DSLR-style MF, tilting",
    "Leica M11": "60MP BSI, frameless base plate, timeless rangefinder",
    "Leica M10-R": "40MP, optical rangefinder, no EVF, pure analogue feel",
    "Leica SL2-S": "24.6MP, contrast AF, rugged L-mount, cinema hybrid",
    "35mm Film — Kodak Portra 400": "Natural skin tones, fine grain, wide latitude",
    "35mm Film — Kodak Portra 800": "Pushed warmth, visible grain, low-light latitude",
    "35mm Film — Kodak Ektar 100": "Hyper-saturated, fine grain, vibrant primaries",
    "35mm Film — Fujifilm Superia 1600": "High-ISO grain, pushed green bias, club/night",
    "35mm Film — Fujifilm Pro 400H": "Soft pastel skin, wide highlight latitude, feminine",
    "35mm Film — Ilford HP5 Plus (B&W)": "Classic B&W, pushed to 3200 gritty, versatile",
    "35mm Film — Ilford Delta 3200": "Extreme grain, B&W, pushed high-ISO documentary",
    "35mm Film — Kodak Tri-X 400 (B&W)": "Iconic B&W, rich grain, high contrast heritage",
    "35mm Film — Cinestill 800T": "Tungsten-balanced, halation glow, cinema in 35mm",
    "35mm Film — Lomography Color 100": "Toy-camera cross-process, saturated, lo-fi",
    "120mm Film — Kodak Portra 400 MF": "MF Portra, enormous tonal range, fine grain at 6×7",
    "120mm Film — Ilford FP4 125 (B&W)": "Fine grain B&W, long tonal scale, architectural",
    "120mm Film — Fujifilm FP-100C (Instant)": "Peel-apart instant, warm tones, unique surface",
    "Polaroid 600 Series": "Square format instant, soft vignette, slow emulsion",
    "Polaroid SX-70": "Folding SLR instant, legendary soft focus rendering",
    "Impossible Project I-1": "Modern Polaroid, controlled colour, ring flash built-in",
    "Canon EOS R3": "24.1MP BSI stacked CMOS, 30fps, eye-control AF, speed/quality",
    "Nikon Z9": "45.7MP stacked CMOS, no mechanical shutter, 20fps RAW",
    "Nikon Z8": "45.7MP stacked, compact Z9, blackout-free, full-frame speed",
    "Fujifilm X-T5": "40.2MP APS-C BSI, compact, film simulation legacy, X-Trans",
    "Fujifilm X-Pro3": "26.1MP X-Trans, hidden LCD, rangefinder hybrid, Acros grain",
    "Ricoh GR IIIx": "24.2MP APS-C, 40mm equiv, pocketable, hard street snap",
    "Sigma fp L": "61MP BSI FF, world's smallest FF, minimalist, cinema RAW",
    "Pentax K-1 Mark II": "36.2MP AA-filterless, pixel shift, weather-sealed DSLR",
    "OM System OM-1 Mark II": "20MP stacked MFT, 120fps, computational photography",
    "ARRI Alexa LF": "With A Panavision C Series Anamorphic 50mm T2.3",
    "ARRI Alexa Mini LF": "With A Cooke S7/i 40mm T2.0",
    "ARRI ALEXA 35 (cinema)": "4.6K ALEV 4 sensor, legendary skin tone rendering, cinema",
    "RED Ranger Monstro": "With A Panavision T-Series Anamorphic 35mm T2.3",
    "RED MONSTRO 8K VV": "8K full frame, REDCODE RAW, clinical highlight roll-off",
    "Blackmagic Pocket Cinema 6K": "6K Super 35, BRAW, anamorphic option, indie cinema look",
    "Sony VENICE 2 (cinema)": "8.6K FF, dual base ISO, built-in ND, cinema glass",
    "35mm Film — Agfa Vista 200": "Warm skin saturation, slight yellow bias, consumer quality",
    "35mm Film — Kodak Gold 200": "Classic holiday colour, warm, fine grain, nostalgic",
    "35mm Film — Rollei Infrared 400": "Near-infrared sensitivity, dark skies, white foliage",
    "35mm Film — Fomapan 400 (B&W)": "Eastern European B&W, high contrast, large grain, cheap",
    "120mm Film — Kodak Ektar 100 MF": "Hyper-saturated MF, ultra-fine grain, vivid primaries",
    "120mm Film — Rollei RPX 400 (B&W)": "MF B&W, wide exposure latitude, natural grain",
    "4x5 Film — Kodak Portra 160 LF": "Large format Portra, enormous tonal separation, surgical",
    "4x5 Film — Ilford FP4 125 LF": "Large format B&W, virtually grainless, architectural",
    "Disposable Camera — Kodak FunSaver": "Lo-fi flash snapshot, hypersaturated, retro social",
    "ARRI Alexa 35": "4.6K ALEV 4, 17 stops dynamic range, supreme skin tone",
    "RED V-Raptor 8K VV": "8K Vista Vision, 280fps at 4K, modular, REDCODE RAW",
    "Sony Venice 2 8K": "8.6K full frame, dual ISO 800/3200, built-in ND, cinema",
    "Sony Venice": "With A Hawk V-Lite 55mm Anamorphic T2.2",
    "Panavision Millennium DXL2": "8K LF Panavision sensor, Panavised glass mount, cinema",
    "Hasselblad H6D-100c Medium Format": "53.4x40mm 100MP CMOS, 16-bit color depth, leaf-shutter flash sync to 1/2000s",
    "Mamiya RZ67 Pro II (6x7 120 Film)": "Iconic 6x7cm medium-format studio bellows camera, revolving back, creamy depth",
    "Sinar P2 8x10 Large Format View Camera": "8x10-inch sheet film monorail with Scheimpflug front/rear tilt, swing, rise, and fall",
    "IMAX MSM 9802 65mm 15-Perf Camera": "15-perforation 65mm horizontal celluloid negative, unmatched spatial acuity",
    "Leica M6 TTL 35mm Rangefinder": "Mechanical 35mm film rangefinder, discreet candid proximity, classic frame lines",
    "Contax G2 35mm Titanium Rangefinder": "Carl Zeiss Planar 45mm f/2 + TLA 200 direct flash, raw editorial immediacy",
    "ALPA 12 TC Technical Camera + Hasselblad CFV 100C": "Compact Swiss precision CNC technical body with 100MP 16-bit BSI CMOS back and leaf-shutter sync",
    "ALPA 12 FPS + Rodenstock HR Digaron-W 40mm": "Focal-plane shutter technical camera syncing up to 1/4000s with ultra-high-resolution Rodenstock optics",
    "ALPA 12 Plus + Phase One IQ4 150MP": "Shift/stitch modular technical camera with 150MP back and 70mm-circle Rodenstock/Schneider optics",
    "Cambo Actus-G View Camera + Sony A7R V": "Miniaturized monorail view camera with full Scheimpflug tilt/swing movements on 61MP sensor",
    "Linhof Technika Master Classic 4x5 Folding Field Camera": "Precision German 4x5-inch sheet-film folding view camera with triple-extension bellows and front movements",
    "Deardorff 8x10 Commercial View Camera (Avedon Edition)": "Mahogany-and-brass 8x10-inch large-format view camera — infinite tonal gradation and contact-print sharpness",
    "Chamonix 8x10 Carbon-Teak Large Format Camera": "Ultra-rigid carbon-fiber and teakwood 8x10 sheet-film view camera for monumental location portraiture",
    "Graflex Speed Graphic 4x5 Press Camera": "Classic 1940s 4x5 sheet-film press camera with 1/1000s focal-plane curtain shutter and flashbulb reflector",
    "Pentax 67II Medium Format (Takumar 105mm f/2.4)": "SLR-styled 6x7cm 120 rollfilm titan producing legendary three-dimensional subject separation",
    "Rolleiflex 2.8FX Twin-Lens Reflex (Planar 80mm f/2.8)": "Waist-level 6x6cm square medium-format TLR with whisper-quiet leaf shutter and intimate low eye-line",
    "Hasselblad 500C/M (Zeiss Planar 80mm f/2.8 T*)": "Iconic modular 6x6cm V-system medium-format film cube with Compur leaf shutter and square frame",
    "Hasselblad 907X & CFV 100C Medium Format": "Ultra-slim modular 100MP medium-format digital back with waist-level tilting screen and HNCS color",
    "Mamiya 7 II 6x7 Rangefinder": "Whisper-quiet 6x7cm medium-format rangefinder with ultra-sharp rectilinear wide and normal leaf-shutter lenses",
    "Plaubel Makina 67 (Nikkor 80mm f/2.8)": "Compact folding 6x7cm medium-format film rangefinder with legendary Nikkor optical micro-contrast",
    "Polaroid 20x24 Studio Large Format Instant Camera": "200-pound wheeled mammoth instant camera producing life-size 20x24-inch Polacolor prints with zero grain",
    "8x10 Polaroid Type 809 Land Camera (Roversi Setup)": "8x10-inch instant peel-apart Polacolor film processor with painterly creamy highlights and deep shadows",
    "Sony Alpha 9 III (Global Shutter 120fps)": "Full-frame stacked CMOS with distortion-free global shutter and 1/80,000s flash sync at all shutter speeds",
    "Leica M11 Monochrom (60MP B&W BSI)": "Dedicated monochrome rangefinder with no Bayer color filter array — unmatched tonal purity and highlight latitude",
    "Leica SL3 (60MP L-Mount Maestro IV)": "Full-metal L-mount mirrorless flagship with 60MP BSI sensor, 15-stop dynamic range, and IP54 weather sealing",
    "Fujifilm GFX 100 II (102MP High-Speed MF)": "102MP CMOS II HS medium-format flagship with 8-stop IBIS and native Reala Ace film simulation",
    "Canon EOS R1 (24MP Stacked Flagship)": "Cross-type Dual Pixel Intelligent AF flagship for extreme weather, rain, and high-velocity sports/runway",
    "ARRI ALEXA 65 (65mm Large Format 6.5K Cinema)": "3-perf 65mm large-format digital cinema camera with unmatched spatial depth and creamy highlight roll-off",
    "RED V-Raptor XL 8K VV (Electronic ND)": "Studio-configured 8K VistaVision cinema camera with internal 2-to-7 stop motorized electronic ND filter",
    "Phantom Flex4K-GS (1000fps Ultra-Slow-Motion)": "High-speed global-shutter cinema camera freezing water splashes, hair whip, and fabric shockwaves at 1000fps"
}

# ==============================================================================
# HARDWARE MANIFEST — LENSES
# ==============================================================================
LENS_MANIFEST = {
    "100mm": "Prime lens f8",
    "25mm": "Prime lens f/1.2",
    "25MM": "Prime lens f/0.4",
    "12mm to 17mm": "Wide-angle lens f/8 to f/16 (Deep Depth Of Field)",
    "Canon EF 100mm f/2.8L Macro IS USM": "1:1 macro, IS, L-series, clinically sharp close-up",
    "Canon EF 85mm f/1.2L II USM": "Legendary subject isolation, creamy bokeh, fast AF",
    "Canon EF 85mm f/1.4L IS USM": "Sharp wide open, IS, modern 85mm portrait king",
    "Canon EF 50mm f/1.2L USM": "Natural perspective, classic bokeh rendition",
    "Canon EF 35mm f/1.4L II USM": "Wide open sharpness, environmental portrait",
    "Canon EF 24-70mm f/2.8L II USM": "Workhorse zoom, constant f/2.8, sharp throughout",
    "Canon EF 70-200mm f/2.8L IS III USM": "Reach + bokeh, press/sport/portrait compression",
    "Canon RF 85mm f/1.2L USM DS": "Dual Sensing ND coating, reduced bokeh fringing",
    "Nikon AF-S 85mm f/1.4G": "3D pop bokeh, world-class portrait rendering",
    "Nikon AF-S 105mm f/1.4E ED": "Exceptional resolution + subject separation at f/1.4",
    "Nikon AF-S 58mm f/1.4G": "Micro-contrast perfection, spherical 3D rendering",
    "Nikon AF-S Micro 105mm f/2.8G VR": "Macro + portrait, VR stabilised, exceptional sharpness",
    "Nikon Z 85mm f/1.2 S": "Best-in-class Z-mount portrait, near-perfect rendering",
    "Sony FE 85mm f/1.4 GM": "G Master sharpness, 11-blade circular bokeh",
    "Sony FE 135mm f/1.8 GM": "Stunning compression, bokeh smoothness, razor sharp",
    "Sony FE 50mm f/1.2 GM": "Perfect 50mm — sharp, small, beautiful rendering",
    "Sony FE 90mm f/2.8 Macro G OSS": "1:1 macro, OSS stabilised, clinical sharpness",
    "Sigma 85mm f/1.4 DG DN Art": "Third-party portrait king, exceptional value, sharp",
    "Sigma 35mm f/1.4 DG HSM Art": "Wide portrait, superb sharpness wide open",
    "Sigma 105mm f/2.8 DG DN Macro Art": "Macro + portrait dual-use, exceptional optical quality",
    "Sigma 50mm f/1.4 DG HSM Art": "Technical masterpiece 50mm, heavy but superb",
    "Zeiss Otus 85mm f/1.4": "Near-perfect optical resolution, clinical Zeiss rendering",
    "Zeiss Otus 55mm f/1.4": "Scientifically sharp 50mm, manual focus masterpiece",
    "Zeiss Milvus 135mm f/2": "Dramatic compression, Zeiss micro-contrast, manual",
    "Zeiss Loxia 50mm f/2": "Compact FE portrait, clinical Zeiss quality compact",
    "Voigtländer 40mm f/1.2 Nokton": "Compact fast lens, smooth rendering, unique character",
    "Voigtländer 75mm f/1.5 Nokton II": "Leica M portrait, smooth transitional bokeh",
    "Leica Summilux 50mm f/1.4 ASPH": "Legendary Leica character, precise micro-contrast",
    "Leica APO-Summicron 75mm f/2 ASPH": "Near-perfect optical correction, unmatched clarity",
    "Helios 44-2 58mm f/2 (Swirly Bokeh)": "Soviet swirly bokeh, character imperfection, cult lens",
    "Meyer-Optik Trioplan 100mm f/2.8 (Soap Bubble Bokeh)": "Soap bubble OOF circles, dreamy rendering",
    "Petzval 85mm f/2.2 Art Lens": "Swirly field, sharp centre, 19th century optical character",
    "Nikkor 105mm f/2.5 AI (Vintage)": "Classic portrait rendering, warm, smooth, legendary",
    "Canon TS-E 90mm f/2.8L Macro": "Tilt-shift perspective correction + selective focus plane",
    "Canon TS-E 135mm f/4L Macro": "Long tilt-shift, architectural + beauty macro",
    "Laowa 100mm f/2.8 2X Ultra Macro": "2:1 macro magnification, manual, hyper detail",
    "Canon RF 50mm f/1.2L USM": "Reference-class 50mm, L-mount, clinical + bokeh balance",
    "Canon RF 35mm f/1.4L VCM": "Wide portrait, L-series, video-optimised breathing control",
    "Canon RF 135mm f/1.8L IS USM": "Telephoto portrait king, IS, razor sharpness, compression",
    "Nikon Z 50mm f/1.2 S": "Reference 50mm, Z-mount, outstanding at all apertures",
    "Nikon Z 135mm f/1.8 S Plena": "Purpose-built portrait, circular bokeh priority, superb",
    "Nikon Z 58mm f/0.95 S Noct": "f/0.95 manual, extreme subject isolation, reference build",
    "Sony FE 24mm f/1.4 GM": "Wide environmental portrait, sharp corner-to-corner",
    "Sony FE 100mm f/2.8 STF GM OSS": "Apodisation filter, smoothest bokeh transition, portrait",
    "Sony FE 200-600mm f/5.6-6.3 G OSS": "Reach for environmental compression from distance",
    "Fujinon GF 110mm f/2 WR": "MF portrait, 87mm equiv, wide open rendering exceptional",
    "Fujinon GF 80mm f/1.7 WR": "MF 63mm equiv, fastest GF prime, natural MF isolation",
    "Fujinon GF 45-100mm f/4 WR": "MF zoom, surgical sharpness, weather sealed, studio",
    "ARRI Signature Prime 65mm T1.8": "Cinema prime, anamorphic-adjacent rendering, warm bokeh",
    "Cooke S7/i 75mm T2.0": "Cooke look — organic warmth, oval bokeh, skin flattery",
    "Leica Thalia 100mm T2.6": "Large format cinema, extreme organic rendering, no LCA",
    "Zeiss Supreme Prime 85mm T1.5": "Modern cinema prime, clinically sharp, bold contrast",
    "Atlas Orion 65mm T2 Anamorphic": "1.5× squeeze, horizontal flare, oval bokeh, cinematic",
    "SLR Magic Anamorphot 1.33x": "Budget anamorphic adapter, distinctive oval bokeh + streak",
    "Laowa 15mm f/4.5 Zero-D": "Zero distortion ultrawide, near-zero barrel, architecture",
    "Venus Optics Laowa 25mm f/2.8 2.5-5x Ultra Macro": "5x magnification, insect-scale detail",
    "Mitakon Speedmaster 50mm f/0.95": "f/0.95 full frame, dream-like wide open, heavy character",
    "Voigtländer Nokton 50mm f/1.0 VM": "Leica M f/1.0, extreme shallow, warm Voigt rendering",
    "Nikkor 58mm f/1.2 Noct AI-S": "Vintage hand-ground aspherical, legendary, nocturnal",
    "TLS Petzval 85mm T2.2 (Full Frame Cine)": "Re-housed vintage 1840 optical formula with sagittal swirl bokeh, central sharpness, edge coma",
    "OFG 24mm T14 1.3x Anamorphic Probe Lens": "Ground-level submersible probe with 1.3x anamorphic squeeze, waterproof barrel, built-in LED ring",
    "ARRI Master Macro 100mm T2.0": "1:1 true macro cinema prime, zero chromatic aberration, surgical resolution at maximum aperture",
    "Cooke Anamorphic/i Full Frame Plus 85mm": "Classic Cooke Look warm skin rendition, oval bokeh, restrained horizontal flare streak",
    "Laowa 24mm f/14 2X Periprobe 90° View": "90-degree periscope macro probe for floor-level tracking and extreme close-up reach",
    "Leica Noctilux-M 50mm f/0.95 ASPH": "Paper-thin depth of field at f/0.95, painterly cats-eye peripheral bokeh, luminous glow",
    "Canon EF 65mm f/2.8 1-5x MP-E Macro": "Dedicated 1x to 5x life-size ultra-macro lens, sub-millimeter dermal and textile resolution",
    "Panavision C-Series 50mm T2.3 Anamorphic": "Classic 2x anamorphic cinema prime with blue horizontal streak flare and organic breathing",
    "Hasselblad HC 100mm f/2.2 Medium Format": "Medium-format portrait standard with razor pore acuity and smooth three-dimensional falloff",
    "Cooke Speed Panchro 50mm T2.2 (Vintage S2/S3 Rehoused)": "Classic 1950s Cooke Speed Panchro optical formula — warm skin rendition, gentle spherical roll-off, oval iris bokeh",
    "Cooke Panchro 65/i 75mm T2.5 Large Format (LPL Mount)": "65mm large-format cinema prime preserving classical Panchro gentle aberrations and three-dimensional depth",
    "Angénieux Optimo Prime 50mm T1.8 (IOP Integrated Optical Palette)": "Full-frame cinema prime with customizable internal iris blades, glass elements, and rear diffusion filter",
    "Angénieux Optimo 24-290mm T2.8 Reference Cinema Zoom": "Industry-standard soundstage cinema zoom with zero focus breathing and rich warm French color rendition",
    "Rodenstock HR Digaron-W 40mm f/4 Technical Lens": "Diffraction-limited medium-format technical lens for ALPA 12 with zero geometric distortion and 90mm image circle",
    "Rodenstock HR Digaron-S 90mm f/4 Aperture Unit": "Ultra-high-resolution technical portrait optic resolving sub-micron dermal and fabric weave detail on 150MP backs",
    "Schneider-Kreuznach Apo-Digitar 120mm f/5.6 Macro": "Apochromatic flat-field technical macro lens with surgical edge-to-edge micro-contrast",
    "Schneider-Kreuznach Xenon FF-Prime 50mm T2.1": "German full-frame cinema prime with 14-blade circular iris and neutral color-matched contrast",
    "Carl Zeiss Planar 50mm f/0.7 (NASA / Kubrick Barry Lyndon)": "Ultra-fast f/0.7 candle-lit cinema lens with paper-thin focal plane and painterly spherical halation",
    "Zeiss Master Prime 65mm T1.3": "Dual-floating-element cinema prime with zero breathing, extreme low-light speed, and clinical micro-contrast",
    "Zeiss Super Speed Mk III 35mm T1.3 (B-Speed)": "1970s high-speed cinema prime with distinctive 3-blade triangular bokeh and organic wide-open glow",
    "Panavision Primo 70 80mm T2.0 Large Format": "65mm large-format cinema prime with smooth highlight roll-off and rich shadow modulation",
    "Panavision Ultra Panatar 1.3x Anamorphic 65mm": "Large-format 1.3x wedge anamorphic prime with golden horizontal flare and uncompressed edge geometry",
    "Hawk V-Lite Vintage '74 55mm T2.2 Anamorphic": "1970s single-coated 2x anamorphic prime with low-contrast veiling glare and pearlescent skin tones",
    "Canon K35 55mm T1.4 Vintage Cinema Prime": "1976 Academy Award-winning fluorite cinema prime with warm amber ghosting and creamy highlight bloom",
    "Bausch & Lomb Baltar 50mm T2.3 (Vintage 1940s Noir)": "Classic Hollywood portrait lens with low-contrast shadow glow and velvety skin smoothing",
    "Lomo Round-Front 75mm T2.2 Soviet Anamorphic": "Atmospheric Soviet 2x anamorphic lens with swirling peripheral astigmatism and cyan streak flare",
    "Aero-Ektar 178mm f/2.5 on 4x5 Graflex": "WWII Kodak aerial reconnaissance optic mounted on 4x5 sheet film — f/0.7-equivalent full-frame bokeh swirl",
    "Voigtländer Heliar Classic 50mm f/1.5 VM": "Classical triplet-derived optical design with creamy out-of-focus transitions and vintage edge coma",
    "Leica Summicron-M 35mm f/2 V1 (8-Element King of Bokeh)": "1958 Wetzlar 8-element double-Gauss rangefinder lens with legendary three-dimensional micro-contrast",
    "Leica APO-Summicron-SL 90mm f/2 ASPH": "Apochromatic L-mount portrait reference lens with zero longitudinal chromatic aberration wide open",
    "Hasselblad XCD 90mm f/2.5 V (Leaf Shutter 1/4000s)": "Medium-format leaf-shutter portrait prime syncing studio strobes up to 1/4000s in direct midday sun",
    "Hasselblad XCD 38mm f/2.5 V Environmental Wide": "30mm-equivalent medium-format wide prime for architectural fashion and environmental portraiture",
    "Fujinon GF 55mm f/1.7 R WR": "44mm-equivalent medium-format normal prime with 11-blade rounded diaphragm and creamy focus transition",
    "Mamiya Sekor Z 110mm f/2.8 W (RZ67)": "Definitive 1990s editorial fashion lens — 53mm equivalent on 6x7 film with buttery depth of field",
    "Takumar 105mm f/2.4 Super-Multi-Coated (Pentax 67)": "Iconic 6x7 medium-format portrait lens with unmatched 3D subject pop and warm thorium-glass rendering",
    "Nikkor 105mm f/1.8 AI-S Manual Focus": "Classic fast telephoto manual prime with punchy contrast and painterly background blur",
    "Canon EF 200mm f/1.8L USM (The Eye of Sauron)": "Legendary ultra-fast telephoto isolating full-body subjects against completely dissolved backgrounds",
    "Nikon AF-S 200mm f/2G ED VR II": "Reference telephoto compression prime with three-dimensional full-length subject separation",
    "Laowa 24mm f/14 2X Macro Probe (Direct View)": "Bug-eye tubular macro probe for immersive wide-angle close-ups with deep surrounding context"
}

# ==============================================================================
# APERTURE MANIFEST
# ==============================================================================
APERTURE_MANIFEST = {
    "f/1.0": "Maximum light, extreme subject isolation, diffraction-free at this extreme",
    "f/1.2": "Near-maximum aperture, razor-thin DOF, character bokeh wide open",
    "f/1.4": "Classic fast portrait aperture, one eye sharp, beautiful subject separation",
    "f/1.8": "Excellent sharpness/bokeh balance, most versatile portrait aperture",
    "f/2.0": "Strong subject isolation, improved mid-frame sharpness over f/1.8",
    "f/2.8": "Standard fast zoom maximum, deep technical sharpness, significant DOF",
    "f/4.0": "Group portrait aperture, both eyes and nose sharp in 3/4 profile",
    "f/5.6": "Landscape/studio standard, front to 3m sharp at 85mm FF",
    "f/8.0": "Classic studio aperture, full face and hair sharp at 1.5m",
    "f/11": "Maximum sharpness zone for most lenses, front to 6m at 50mm",
    "f/16": "Deep focus environmental portrait, near hyperfocal",
    "f/22": "Hyperfocal zone, diffraction softening visible, creative deep focus",
    "f/0.4": "Hypothetical sub-unity optical treatment — paper-thin focal plane with dreamy halation",
    "f/0.95": "Ultra-fast noctilux aperture — single eyelash in focus, background dissolved into pure bokeh",
    "T1.5": "Cinema wide-open transmission stop — shallow narrative separation with organic vignette",
    "T2.0": "Standard cinema prime working stop — crisp subject plane with dimensional background separation",
    "f/32": "Diffraction-limited macro stop — maximum depth of field at 1:1–5:1 magnification",
    "f/0.7": "Extreme Kubrick/NASA f/0.7 candle-lit stop — sub-millimeter focal plane with luminous spherical halation",
    "T1.3": "Ultra-fast cinema Master/Super-Speed stop — nocturnal isolation with organic highlight bloom",
    "T2.8": "Cinema anamorphic sweet-spot working stop — oval bokeh with crisp central eyelash sharpness",
    "f/45": "Large-format 8x10 view camera stop (Group f/64 aesthetic) — near-infinite depth of field across scene",
    "f/64": "Ansel Adams / Edward Weston Group f/64 large-format stop — front-to-horizon contact-print sharpness"
}

# ==============================================================================
# WARDROBE MANIFEST
# ==============================================================================
WARDROBE_MANIFEST = {
    # ── White / Light ──────────────────────────────────────────────────────────
    "white_vintage_silk_slip_dress_lace_trim":      "Low denier, bias-cut, raw lace neck border, semi-transparent when wet",
    "white_cotton_tank_top_worn":                   "Worn, faded, semi-transparent when body-warmed or wet",
    "white_sheer_nylon_bodysuit":                   "Full coverage sheer, visible skin tones at all tensions",
    "white_cotton_dress_shirt_oversized":           "Men's dress shirt, unbuttoned, off one shoulder",
    "white_linen_shift_dress_unstructured":         "Natural raw drape, zero structure, body-heat transparent",
    "ivory_satin_chemise_bias_cut":                 "Floor length, ivory, clings to hip with gravity",
    "cream_knit_sweater_oversized":                 "Heavy texture, opaque, off-shoulder slip potential",
    # ── Personal / Colors ──────────────────────────────────────────────────────────
    "change_the_color_to_beige":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_brownish":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_drab":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_khaki":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_biscuit":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_bronze":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_brown":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_buff":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_cream":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_ecru":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_gold":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_natural":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_olive":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_suntan":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_umber":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_leather-colored":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_olive-brown":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_tawny":                    "Keeping the same exact outfit just another color",
    "change_the_color_to_yellowish":                    "Keeping the same exact outfit just another color",
    # ── Black / Dark ───────────────────────────────────────────────────────────
    "black_velvet_slip_dress":                      "Anisotropic velvet sheen, opaque deep black",
    "black_leather_jacket_open":                    "Over nothing, heavy drape, specular highlight on grain",
    "dark_denim_jacket_open_distressed":            "Distressed, raw hem, worn texture, heavy drape",
    # ── Neutral / Raw ─────────────────────────────────────────────────────────
    "raw_linen_shift_unstructured":                 "Natural beige, looser weave, environmental drape",
    "oversized_vintage_t_shirt_distressed":         "Distressed, off-shoulder, screen-printed faded graphic",
    "haute_couture_silk_gazar_sculptural": "Crisp structured silk gazar with architectural origami folds holding geometric volume off the body",
    "duchess_silk_mikado_architectural": "Heavy lustrous double-faced silk mikado with regal drape, structured seams, and rich low-gloss sheen",
    "frosted_silk_organza_translucent_veil": "Featherweight semi-translucent crisp silk organza, multi-layered ethereal sheer volume",
    "liquid_metallic_lam\u00e9_drape": "Fluid molten gold/silver metallic lamé clinging flush to body contours, high specular anisotropic glare",
    "chanel_style_boucl\u00e9_tweed_unhemmed": "Textured multi-yarn wool bouclé with raw frayed selvedge edges, nubby three-dimensional weave",
    "cr\u00eape_de_chine_bias_slip_dress": "Fluid mulberry silk crêpe de chine draping diagonally across curves with muted pearlescent sheen",
    "pleated_issey_miyake_accordion_faille": "Micro-pleated permanent accordion faille expanding and contracting with body motion",
    "chantilly_lace_hand_beaded_tulle": "Delicate black/ivory Chantilly floral lace over sheer illusion tulle with micro-seed-bead embroidery",
    "tailored_double_breasted_wool_bar_jacket": "Sculpted hourglass wool cavalry twill jacket with nipped waist and sharp padded shoulders",
    "sheer_10_denier_ribbed_cotton_camisole": "Ultra-fine 10-denier ribbed cotton camisole clinging flush to sternum and clavicle with tension opacity",
}

# ==============================================================================
# SKIN TOPOGRAPHY MANIFEST
# ==============================================================================
SKIN_MANIFEST = {
    "expressions": {
        "cool_detached_neutral_lips_parted": "Jaw relaxed, lips parted 2mm, gaze camera/mirror",
        "vacant_dissociative_mid_distance": "Eyes unfocused, pupils mid-distance, emotionally absent",
        "micro_tension_brow_suppressed": "Controlled suppression — slight brow tension, jaw set",
        "eyes_closed_meditative": "Downward withdrawn, eyelids at 60%, emotionally sealed",
        "downward_gaze_introspective": "Eyes at floor, private thought, not engaging lens",
        "confrontational_direct_brow_relaxed": "Full eye contact, brow calm, jaw set, jaw relaxed",
        "slight_mouth_corner_tension": "Near-smile tension without commitment, ambiguous",
        "upper_lip_micro_curl": "One-sided lip micro-expression, contempt or smirk",
        "open_mouth_exhale_lips_wet": "Open jaw 8mm, visible wet inner lip, exhale breath",
        "teeth_barely_visible_lip_part": "Lips parted 4mm, upper incisors just visible, tense",
        "eyes_half_closed_heavy_lid": "Lids at 40%, drowsy or sedated, soft unfocus",
        "jaw_clenched_muscle_visible": "Masseter contracted, jaw tight, high cheek tension",
        "looking_past_camera_right": "Gaze directed 15° right of lens, private object",
        "looking_past_camera_left": "Gaze directed 15° left of lens, interior thought",
        "eyes_upward_dissociated": "Eyes rolled slightly upward, disassociated state",
        "cheek_compression_pressed_surface": "Face pressed against glass or wall — flesh deforms",
        "lips_compressed_resolute": "Lips pressed together, firm, closed, determined",
        "chin_dropped_look_under_brow": "Head down, looking up from beneath the brow-line",
        "profile_gaze_window_light": "Side-lit, gaze at unseen distant window point",
        "tears_track_one_cheek": "Single tear track visible on one cheek, no expression",
        "revulsion_licking_finger_clean": "detached, revulsion, her tongue is visible, licking her finger clean, glossy lips, detailed saliva, gaze at reflection or camera",
        "haughty_couture_chin_elevated_calm": "Elevated chin, relaxed heavy eyelids looking down at lens with aristocratic composure",
        "unguarded_mid_laugh_eyes_crinkled": "Authentic candid laughter between takes, Duchenne eye crinkles, natural teeth visible",
        "fierce_unblinking_runway_focus": "Zero blink, jaw set, nostrils slightly flared, commanding forward runway gaze",
        "eyes_narrowed_against_blizzard_gale": "Eyes slightly narrowed against driving snow/wind, jaw set, breath visible as a warm vapor plume in sub-zero air",
        "rain_drenched_ecstatic_upward_gaze": "Head tilted back into warm falling rain, eyes closed, water streaming over cheekbones and parted lips"
    },
    "hair": {
        "messy_loose_updo_stray_strands": "Uncombined updo, strands across cheeks and neck",
        "soaked_wet_plastered_flat": "Hair saturated, flat against scalp, dripping ends",
        "down_dishevelled_tangled_partial_cover": "Unbrushed, tangled, partially covering one eye",
        "short_cropped_damp_sweat": "Short crop, damp, showing scalp texture, flat",
        "severe_pulled_back_high_tension": "Slicked back high bun, zero stray, tight tension",
        "half_up_half_down_clip_one_side": "One side clipped, other falling loose across shoulder",
        "long_loose_windswept_across_face": "Wind-blown coverage of face, one eye hidden",
        "braided_tight_cornrows": "Tight to scalp, strong geometric scalp line mapping",
        "natural_coily_textured_volume": "Unmanipulated natural texture, full volume, shrinkage",
        "bleached_platinum_dry_damaged": "Chemically bleached, dry texture, visible damage",
        "dark_roots_grown_out_blonde": "Regrowth contrast, 3cm dark root on light ends",
        "shaved_undercut_sides_long_top": "Faded sides, long top draping, structural contrast",
        "loc_freeform_medium_length": "Freeform locs, varied thickness, natural formation",
        "wet_curls_ringlet_defined": "Shower-wet curls, definition locked, no frizz",
        "single_braid_over_shoulder": "One loose braid, front, resting across chest",
        "bowl_cut_blunt_fringe_precise": "Geometric blunt cut, heavy fringe at brow-line",
        "side_shaved_asymmetric_punk": "One side clipper-short, opposite long, asymmetric",
        "hair_pulled_covering_face_entirely": "Entire face obscured by fallen hair — anonymous",
        "sculpted_finger_waves_high_gloss_gel": "1930s architectural wet-look finger waves sculpted flat against temples with mirror sheen",
        "wind_tunnel_billowing_halo": "High-velocity studio fan lifting long hair into a dynamic radial halo around head",
        "sleek_glass_hair_center_part": "Ultra-straight keratin-polished glass hair parted razor-sharp down center, tucked behind ears",
        "snow_dusted_windswept_tresses": "Loose hair whipped across collarbones with delicate unmelted snowflakes and hoarfrost crystals caught in the strands",
        "torrential_rain_drenched_sculpted_strands": "Rain-saturated wet hair clinging in graphic dark ribbons across forehead, cheekbones, and neck"
    },
    "reflectance": {
        "high_specular_damp_skin_flash": "Glisten on damp skin from flash — wet specular dominant",
        "oiled_skin_broad_low_roughness": "Oiled — wide specular lobe, near-zero roughness",
        "matte_dry_zero_specular": "Completely dry matte — no specular return",
        "mixed_wet_dry_zonal": "Specular only on forehead, nose bridge, clavicle",
        "sss_dominant_translucent_rim": "Subsurface dominant — glowing rim, soft specular cap",
        "very_dark_skin_low_albedo_high_specular": "Low diffuse, concentrated point specular — rich depth",
        "very_pale_skin_high_albedo_low_specular": "Near-white diffuse, muted specular — luminous base",
        "sweat_pooled_rivulet_streak": "Running sweat stream — specular trail on dark skin",
        "water_droplet_beaded_repellent": "Beaded surface water — hydrophobic effect, round drops",
        "mineral_oil_full_body_coat": "Complete oil coat — broad specular everywhere, low rough",
        "ash_powder_matte_override": "Ashen dry powder coat — total specular suppression",
        "golden_hour_subsurface_ear_rim_glow": "Warm backlit solar transmission glowing red-orange through ear cartilage and vellus cheek fuzz",
        "high_gloss_editorial_hydro_balm": "Glass-skin editorial balm reflection along zygomatic arch, nasal bridge, and Cupid's bow",
        "rain_lashed_hydro_specular_sheen": "Continuous rainwater film across skin reflecting neon and rim strobes with high-Fresnel wet specular highlights",
        "sub_zero_frost_pink_cryo_flush": "Sub-zero cold-air vaso-constriction pallor with natural rose-pink flush across nasal bridge, cheeks, and ears"
    },
    "surface_micro": {
        "full_unretouched_pores_goosebumps_sweat": "Pores, goosebumps, micro sweat beads, natural folds",
        "micro_sweat_pooling_clavicle": "Sweat pooling in clavicle hollow, follicle mapping",
        "dry_flake_lips_under_eye_creases": "Dry lip texture, under-eye tissue, forehead depth",
        "goosebump_shoulder_arm_only": "Goosebump texture isolated to shoulder/arm region",
        "acne_unretouched_visible_texture": "Active or healing acne — unfiltered, scarring visible",
        "freckles_sun_damage_hyper_pigmentation": "Natural freckling, sun spots, uneven pigmentation",
        "body_hair_natural_visible": "Natural visible body hair — arms, legs, abdomen",
        "stretch_marks_natural": "Natural stretch marks at hip and breast — authentic",
        "vein_visibility_subsurface": "Subsurface veins visible at inner forearm/wrist",
        "bruise_healing_yellow_purple": "Healing bruise — yellow edge, purple centre gradient",
        "tattoo_linework_fine_black": "Fine black linework tattoo — crisp edges, ink texture",
        "tattoo_blackwork_dense_coverage": "Heavy black fill tattoo — skin texture under ink",
        "scar_tissue_raised_keloid": "Raised keloid scar — surface above skin plane",
        "scar_depressed_atrophic": "Sunken atrophic scar — surface below skin plane",
        "cellulite_natural_thigh_surface": "Natural adipose dimpling — hip and thigh region",
        "razor_stubble_3day_growth": "3-day stubble shadow — individual follicle dot map",
        "peach_fuzz_vellus_hair_cheek": "Fine vellus hair on cheek and upper lip — catches rim",
        "chapped_lip_texture_dry_crack": "Dry cracked lip surface — horizontal micro-fissures",
        "under_eye_dark_circle_vessel": "Periorbital dark circle — capillary network visible",
        "skin_fold_natural_compression": "Natural fold where limb meets torso — crease map",
        "smeared_makeup_tear_tracks": "makeup smeared and running down face with tears",
        "electro_paint_party_splatter": "visible remnants of non-newtonian white fluid paint splash on skin, exactly as expected from an electro paint party",
        "clavicle_hollow_specular_water_meniscus": "Pooled water meniscus in supraclavicular fossa refracting studio strobe catchlight",
        "fine_goosebumps_and_erector_pili_relief": "Cold-air piloerection goosebumps across deltoid and forearm with raking side-light shadow",
        "melting_snowflakes_and_cold_goosebumps": "Half-melted snowflakes and cold-air piloerection goosebumps across collarbones, shoulders, and eyelashes",
        "raindrop_impact_beads_and_rivulets": "High-definition spherical raindrops and running water rivulets tracing down jawline, neck, and sternum"
    }
}

# ==============================================================================
# LOCATION / ENVIRONMENT MANIFEST
# ==============================================================================
LOCATION_MANIFEST = {
    "interior_wet": {
        "bathroom_steam_ceramic_harsh_flash": "Steamed ceramic tiles, condensation glass, single flash",
        "shower_waterfall_stone_hiding": "Subject hiding in waterfall behind stones",
        "indoor_pool_underwater_tiles": "Submerged or poolside, chlorine-blue ambient",
        "hotel_bathroom_marble_tungsten": "Luxury marble, tungsten practicals, intimate",
        "locker_room_industrial_fluorescent": "Institutional benches, flat overhead fluorescent",
        "wet_concrete_floor_drain_flash": "Bare wet concrete, industrial drain, hard flash",
        "compact_residential_bathroom_vanity_clutter": "compact tiled residential bathroom with vanity mirror, cluttered counter with cosmetics, brushes, toiletries",
        "finland_cedar_sauna_birch_steam": "Warm red-cedar slatted sauna interior filled with dense rising löyly steam and glowing stove stones",
        "venetian_palazzo_flooded_acqua_alta_hall": "16th-century Venetian marble ground-floor hall flooded with 10cm of mirror-still Acqua Alta tide water reflecting Murano chandeliers",
        "moroccan_zellige_hammam_steam_shafts": "Geometric emerald/cobalt zellige tile hammam with pierced vaulted ceiling casting shafts of sun through thick steam"
    },
    "interior_dry": {
        "hotel_room_window_backlight_only": "Dark room, strong window backlight, noir silhouette",
        "industrial_warehouse_single_pendant": "Rough concrete, single tungsten pendant, deep shadows",
        "studio_black_seamless_pure": "Black seamless, no environment, total control",
        "studio_white_high_key": "White seamless, high-key fill, detail priority",
        "apartment_bedroom_natural_chaos": "Personal bedroom, dishevelled, available light only",
        "underground_club_strobe_ambient": "Dark club, strobe flash mix, motion potential",
        "dressing_room_vanity_mirror_bulbs": "Vanity bulb surround, warm mirror reflections",
        "hospital_corridor_fluorescent_cold": "Clinical cold fluorescent, empty corridor, sterile",
        "brutalist_stairwell_concrete": "Exposed concrete stairwell, hard directional light"
    },
    "exterior_night": {
        "rooftop_city_backlight_night": "Rooftop, city glow backlight, cool ambient",
        "urban_alley_single_sodium_lamp": "Sodium street lamp, warm isolated pool, deep shadow",
        "wet_pavement_reflection_neon": "Rain-slicked street, neon reflection, hard flash fill",
        "empty_parking_garage_fluorescent": "Multi-level garage, flat tubes, shadow geometry",
        "forest_moonlight_no_ambient": "Near-darkness, blue moonlight, deep shadow nature",
        "industrial_loading_dock_night": "Hard sodium raking, concrete edge shadows, cargo",
        "tokyo_shinjuku_rain_neon_crosswalk": "Rain-slicked asphalt reflecting cyan and magenta kanji neon signage with steam rising from vents",
        "arctic_tundra_aurora_borealis_snowfield": "Snow-blanketed sub-zero tundra illuminated by emerald and violet Aurora Borealis curtains and moonlight bounce",
        "hong_kong_wong_kar_wai_rain_alley_neon": "Narrow wet Kowloon alleyway with dripping air-conditioner units, green/red neon signs, and steam rising from grates",
        "blizzard_highway_headlight_snow_tunnel": "Desolate snow-swept nocturnal highway lit only by twin halogen car beams slicing through horizontal blizzard flakes"
    },
    "exterior_day": {
        "outdoor_waterfall_natural_mist": "Natural waterfall, mist diffusion, even ambient",
        "rooftop_golden_hour_rim_light": "Warm oblique sun rim, city haze background",
        "beach_overcast_flat_natural": "Overcast diffused, near-shadowless, neutral cool",
        "desert_harsh_midday_zenith": "Brutal overhead sun, razor shadows, bleached",
        "dense_forest_dappled_canopy": "Scattered filtered light, green ambient bias",
        "snow_field_bluewhite_overcast": "Snow surface fill, blue-white ambient, zero shadow",
        "urban_rooftop_water_tower_magic_hour": "Golden magic hour, water tower silhouette, warm haze",
        "abandoned_industrial_yard_overcast": "Overcast diffused, rust metal, grey ambient, raw",
        "quarry_stone_walls_hard_midday": "Stone quarry, vertical hard walls, razor sun bounce",
        "cornfield_backlit_late_afternoon": "Warm backlight through corn, lens flare potential",
        "icelandic_black_sand_basalt_sea_stacks": "Reynisfjara black volcanic sand beach with hexagonal basalt columns, roaring white Atlantic surf spray, and sub-arctic storm sky",
        "swiss_alpine_glacier_ice_cave_blue": "Translucent glacial ice cavern with deep turquoise refracted daylight and hoarfrost ceiling crystals",
        "scottish_highland_heather_moor_mist": "Windswept Glen Coe peat moorland with purple heather, rolling hill fog, and silver Loch reflections",
        "white_sands_gypsum_dune_crest_wind": "Pure white gypsum sand dunes in New Mexico with wind-sculpted ripples and deep cobalt polarized sky",
        "salt_flats_salar_de_uyuni_water_mirror": "Flooded endless white salt flat creating a 1:1 horizonless sky mirror beneath the subject's feet"
    },
    "interior_institutional": {
        "prison_cell_bar_shadow_hard": "Bar-cast shadow stripes across subject, cold ambient",
        "psychiatric_ward_padded_room": "Off-white padding, no shadow, flat institutional",
        "autopsy_suite_surgical_overhead": "Overhead surgical quad, harsh even, cold clinical",
        "school_corridor_fluorescent_empty": "Empty hallway, flat tubes, lockers, linoleum floor",
        "laboratory_clean_room_cold": "Antiseptic white, shadowless ambient, clinical cold",
        "office_cubicle_monitor_glow": "Screen uplight, blue-white, dark surrounding, trapped",
        "church_interior_stained_glass_slash": "Coloured light slash from stained glass, dark nave"
    },
    "interior_luxury": {
        "penthouse_floor_to_ceiling_city": "Glass wall city panorama, ambient city glow, premium",
        "art_gallery_track_lit_white_wall": "Gallery track spot, white wall, shadow direction down",
        "high_fashion_boutique_mirror_array": "Mirror surround, multiple reflections, cool LED",
        "hotel_suite_dark_wood_candle": "Dark wood walls, candle practicals, warm low light",
        "casino_low_ceiling_chandelier": "Crystal chandelier, warm sparkle, felt green table",
        "spa_wet_room_steam_diffused": "Polished stone, steam diffusion, soft warm light"
    },
    "transitional": {
        "elevator_mirror_interior": "Mirrored walls, ceiling light, isolated subject",
        "stairwell_fire_escape_exterior": "Iron steps, harsh side-light, urban vertical",
        "car_interior_night_dash_glow": "Dashboard ambient, headlamp backscatter, intimate",
        "train_window_motion_blur_ambient": "Moving exterior blur, interior overhead strip light",
        "airport_terminal_overhead_flat": "Commercial overhead fluorescent, transient crowd",
        "backstage_dressing_room_bulbs": "Row of mirror bulbs, warm surround, performative",
        "rooftop_stairwell_exit_door_open": "Door cracked, shaft of exterior light, dark interior"
    },
    "architectural_monumental": {
        "brutalist_board_formed_concrete_atrium": "Monolithic Marcel Breuer / Barbican-style board-formed concrete atrium with deep geometric coffers",
        "brutalist_concrete_viaduct_sodium_fog": "Towering concrete highway pilings at night in dense fog lit by monochromatic 590nm sodium lamps",
        "parisian_haute_couture_salon_boiserie": "18th-century Parisian couture atelier with gilded boiserie moldings, tall French windows, and chevron parquet",
        "horizonless_studio_infinity_cyclorama": "Pure curved white/charcoal studio infinity cove with peripheral C-stands, V-flats, and tether cart",
        "mirror_box_infinite_reflection": "Four-wall floor-to-ceiling optical-grade mirror room with infinite recursive reflection depth",
        "tadao_ando_concrete_water_temple": "Silky smooth architectural cast concrete walls with circular oculus and tranquil black reflective water basin",
        "luis_barragan_pink_stucco_terrace_pool": "Minimalist Mexican modernist magenta and terracotta stucco walls with geometric turquoise water trough and sharp sun shadows",
        "abandoned_botanical_conservatory_overgrown_glass": "Victorian wrought-iron and condensation-streaked glass palm house overgrown with giant ferns and weeping figs"
    },
    "iconic_editorial_sets": {
        "irving_penn_acute_corner_studio_1948": "Irving Penn's iconic 1948 Corner Studio — two raw grey studio flats joined at a tight 45-degree wedge angle with worn studio floorboard seams",
        "sarah_oliphant_hand_painted_cloud_canvas": "Authentic Brooklyn Oliphant Studio 15oz Italian cotton duck canvas backdrop hand-painted in mottled storm-grey and umber glazes with dark vignette edges",
        "avedon_american_west_white_seamless_desert": "Richard Avedon 'In the American West' setup — stark unlit white seamless paper roll suspended outdoors in dusty Texas/Montana open shade",
        "avedon_cirque_dhiver_paris_sawdust_ring": "Richard Avedon 1955 'Dovima with Elephants' set — historic Parisian winter circus interior with skylights, rough stone walls, sawdust floor, and iron chains",
        "helmut_newton_rue_aubriot_paris_nocturne": "Helmut Newton 1975 'Le Smoking' location — narrow rain-slicked cobblestone Rue Aubriot in the Paris Marais at midnight under a warm sodium streetlamp",
        "helmut_newton_piscine_molitor_monte_carlo_pool": "Art Deco tile swimming pool deck overlooking the Mediterranean with chrome diving ladder and wet marble coping",
        "peter_lindbergh_malibu_white_shirts_beach_1988": "Peter Lindbergh 1988 Malibu shoreline — wind-swept wet Pacific sand at low tide under silver-grey marine layer overcast",
        "peter_lindbergh_soho_cast_iron_street_1990": "Peter Lindbergh 1990 British Vogue Supermodels location — gritty downtown NYC SoHo cobblestone street with cast-iron facades, water towers, and steam vents",
        "guy_bourdin_charles_jourdan_gloss_enamel_set": "Guy Bourdin surreal editorial set — hyper-saturated crimson and cobalt glossy enamel-painted walls with geometric shadow cutouts",
        "paolo_roversi_studio_luce_paris_daylight": "Paolo Roversi's Studio Luce in Montparnasse, Paris — peeling ochre plaster walls, tall dusty north-facing factory windows, and aged wooden floorboards",
        "herb_ritts_el_mirage_dry_lakebed_playa": "Herb Ritts California desert set — sun-baked polygonal cracked alkali clay flat at El Mirage / Joshua Tree under deep polarized sky",
        "herb_ritts_paradise_cove_malibu_black_rocks": "Malibu coastal cove with wet dark tidepool boulders, foaming surf, and low golden-hour Pacific sun",
        "annie_leibovitz_vanity_fair_soundstage_tableau": "Cinematic Hollywood soundstage dressed with 'Leibovitz Gray' painted muslin, antique velvet settee, and towering C-stands",
        "tim_walker_surreal_oversized_wonderland_set": "Fantastical practical soundstage built with giant papier-mâché swans, crumbling English country house wallpaper, and suspended clouds",
        "nick_knight_showstudio_opal_perspex_cube": "Luminous floor-to-ceiling backlit white Opal Perspex light-box studio with reflective acrylic floor and colored smoke",
        "alexander_mcqueen_voss_two_way_mirror_box": "Clinical padded glass and two-way mirror cube inspired by McQueen & Nick Knight's 2001 VOSS asylum installation",
        "gregory_crewdson_suburban_twilight_soundstage": "Rain-soaked small-town American street at blue hour with fog machines, glowing house windows, and stationary vintage sedan",
        "slim_aarons_kaufmann_desert_house_poolside": "Richard Neutra's 1946 mid-century modern Kaufmann Desert House in Palm Springs — turquoise rectilinear pool, desert boulders, and San Jacinto mountain backdrop",
        "melvin_sokolsky_1963_paris_bubble_seine": "Suspended transparent Plexiglas spherical bubble floating above the River Seine with Parisian Haussmann bridges behind",
        "horst_mainbocher_corset_neoclassical_pedestal": "Horst P. Horst 1939 Paris studio — rough stone balustrade, draped velvet curtain, and dramatic trompe-l'œil shadow wall",
        "erwin_blumenfeld_ribbed_frosted_glass_set": "Avant-garde 1949 New York studio setup with vertical fluted/ribbed frosted glass partition refracting the subject into rhythmic silhouettes",
        "steven_meisel_italian_vogue_beverly_hills_villa": "Opulent mid-century Beverly Hills glass-walled villa with leopard carpet, chrome bar cart, and harsh California sunlight",
        "mert_and_marcus_ibiza_neon_nightclub_vip": "Mirrored VIP lounge with crushed velvet banquettes, smoke haze, and saturated magenta/cyan club lasers",
        "juergen_teller_raw_hotel_carpet_flash_corner": "Unstaged luxury hotel suite corner with floral carpet, cream wallpaper, and raw direct Contax G2 flash shadow"
    }
}

# ==============================================================================
# GLASS SURFACE MANIFEST
# ==============================================================================
GLASS_SURFACE_MANIFEST = {
    "reflective sleek": "Black floot tile with wax sheen",
    "condensation_calcium_grease_dust": "Irregular droplets, calcium spots, grease smudges, flash-lit dust",
    "heavy_steam_occluded_centre": "Dense steam condensation blocking central surface",
    "cracked_silver_nitrate_decay_edge": "Fracture lines, mirror decay at perimeter",
    "freshly_wiped_squeegee_streak": "Wipe artifacts, faint streak lines, near clean",
    "rain_streaked_exterior_neon_reflection": "Exterior rain, neon colour cast overlay",
    "no_glass_open_environment": "No glass surface — open air, no reflective plane",
    "fogged_exterior_frost_interior": "Temperature differential, fogged and frosted",
    "lipstick_text_on_glass_condensation": "Text written through condensation, drip artefacts",
    "fingerprint_smear_dense": "Dense fingerprint oils, glare catching on flash",
    "mirror_black_glass_minimal_fog": "Dark mirror base, minimal distortion, clean reflection",
    "silver_nitrate_decay_full_surface": "Mirror fully aged — dark patches, black edge rot",
    "one_way_mirror_dark_side": "From observation side — subject lit, reflective field",
    "frosted_glass_full_diffusion": "Sandblasted surface, silhouette only, full scatter",
    "etched_pattern_geometric": "Geometric etch pattern interrupts reflection plane",
    "broken_shards_mosaic": "Broken mirror in frame — mosaic of angled reflections",
    "double_pane_ghost_reflection": "Secondary ghost image from inner pane, slight offset",
    "condensation_single_wipe_arc": "Single arc wipe through heavy steam — partial reveal",
    "lipstick_kiss_mark_glass": "Lip print pressed to glass — bold pigment transfer",
    "dried_water_droplet_calcium_map": "Dried mineral map — geometric calcium deposit pattern",
    "oil_slick_rainbow_smear": "Iridescent oil smear — thin film colour diffraction",
    "mirror_smudges_water_spots_text": "smudges, water spots, optional lipstick writing matching uploaded image text",
    "hoarfrost_fern_crystal_windowpane": "Delicate dendritic ice fern crystals frozen across window glass with clear melted breathing hole in center",
    "torrential_rain_sheet_cascading_glass": "Continuous wavy sheet of rainwater cascading down exterior window glass, refracting background neon into liquid streaks",
    "hydrophobic_rain_beads_neon_bokeh": "Thousands of razor-sharp spherical raindrops beaded on glass plane, each acting as a micro-lens inverting background city lights",
    "blizzard_snow_accumulation_lower_sill": "Wet wind-blown snow packed against lower glass corners with cold blue condensation mist across the center",
    "erwin_blumenfeld_ribbed_fluted_glass": "Vertical fluted/ribbed architectural privacy glass diffusing the figure into rhythmic optical slices where skin touches the ridges",
    "shattered_tempered_safety_glass_web": "Crazed spiderweb network of thousands of crystalline fractures in tempered glass catching hard edge strobe",
    "dichroic_iridescent_architectural_glass": "Dichroic coated glass panel shifting from cyan-emerald in transmission to magenta-gold in grazing reflection",
    "antique_venetian_mercury_mirror_foxing": "18th-century Venetian mercury glass mirror with warm silver-gold reflection and organic black crystalline foxing spots",
    "wet_windshield_wiper_arc_clear_zone": "Rain-lashed automotive windshield with a single sharp semi-circular wiper sweep framing the subject's eyes",
    "submerged_aquarium_thick_acrylic_refraction": "50mm optical-grade aquarium acrylic wall with suspended micro-bubbles and green-blue total internal reflection"
}

# ==============================================================================
# DEPTH OF FIELD MANIFEST
# ==============================================================================
DOF_MANIFEST = {
    "foreground": {
        "shallow_cinematic_dramatic": "Shallow DOF, film-style subject isolation, creamy falloff",
        "extreme_shallow_subject_sharp_pure_bokeh": "Razor-thin plane, pure bokeh background and foreground",
        "deep_focus_full_scene_sharp": "Front-to-back sharp — f/8 or f/11 hyperfocal zone",
        "medium_dof_soft_background": "Subject sharp, background soft, foreground hint blur",
        "tilt_shift_selective_plane": "Oblique focus plane — selective miniature effect",
        "split_diopter_dual_plane": "Two sharp planes simultaneously — classic de Palma",
        "rack_focus_pull_mid_transition": "Focus transition from foreground to background",
        "foreground_element_soft_frame": "Blurred foreground frame element — bars, foliage, fabric",
        "macro_1_1_single_plane_razor": "1:1 macro DOF — sub-mm depth, everything else soft",
        "porthole_soft_vignette_edge": "Hard vignette border with sharp centre, circular mask",
        "anamorphic_bokeh_oval_horizontal": "Horizontally stretched oval OOF circles — anamorphic",
        "swirly_helios_field_curvature": "Helios field curvature — sharp centre, swirl at edge",
        "falling_snowflakes_out_of_focus_orbs": "Large out-of-focus foreground snowflakes illuminated by near-axis strobe into translucent crystalline bokeh circles",
        "rain_streaks_and_splash_crowns_foreground": "Razor-sharp foreground rain splash crowns and blurred falling droplet streaks framing the lower third",
        "prism_edge_spectral_flare_foreground": "Hand-held triangular glass prism at lens edge casting soft rainbow dispersion and ghosted reflection across foreground",
        "sheer_silk_veil_blowing_across_lens": "Gossamer translucent silk organza catching the wind inches from the front element, veiling one side of the frame"
    },
    "midground": {
        "subject_seated_posture_straight": "Full rear facing, hands resting on hip, head facing away from camera",
        "subject_seated,_posture_straight": "Full forward facing, hands resting on hip, head facing the camera",
        "subject_behind_waterfall_stones": "Subject hiding in waterfall behind stones",
        "subject_vanity_back_to_mirror": "Subject at vanity, back to mirror, three-quarter",
        "subject_standing_quarter_turn_away": "Three-quarter turn, back partially to lens",
        "subject_lying_supine_up_at_camera": "Floor level, looking directly upward at lens",
        "subject_crouching_corner_arms_wrapped": "Corner crouch, arms around knees, self-contained",
        "subject_mid_motion_mid_stride": "Caught mid-step, kinetic energy, motion blur edge",
        "subject_seated_vanity_lean_forward": "Counter-seated, legs relaxed, torso leaning forward",
        "subject_pressed_glass_from_behind": "Subject presses against glass from the rear side",
        "subject_emerging_from_water_waist": "Waist-up above water surface, submerged below",
        "subject_silhouetted_doorway": "Subject fills door frame, backlit, rim only visible",
        "subject_descending_staircase": "Mid-stair descent, angled axis, motion implied",
        "subject_reading_letter_seated": "Seated, focused downward on held letter or object",
        "subject_on_phone_window_lean": "Phone to ear, weight on window frame, urban light",
        "subject_dressing_mirror_reflection": "Caught in mirror while dressing, partial reveal",
        "subject_sleeping_fetal_floor": "Fetal position on floor — vulnerable, unconscious air",
        "subject_bracing_against_gale_wind_stride": "Subject leaning into a powerful crosswind mid-stride, coat and hair streaming backward in taut aerodynamic lines",
        "subject_standing_in_falling_snow_looking_up": "Subject standing still with face tilted upward toward falling snow, snowflakes resting on eyelashes and wool collar",
        "subject_drenched_in_warm_downpour_exhale": "Subject standing in torrential rain with soaked hair and clinging silk, warm breath condensing in cool air",
        "subject_wedged_in_irving_penn_acute_corner": "Subject wedged between two converging 45-degree studio flats, leaning one forearm against the left wall"
    },
    "background": {
        "full-length mirrors": "Pristine, covering walls, adding depth",
        "ceramic_tiles_deep_shadow_grout": "Dark ceramic, high-contrast grout lines, minimal ambient",
        "pure_black_void_zero_detail": "Total black, zero ambient environment",
        "exposed_concrete_brutalist_raking": "Rough concrete, hard light angle, shadow geometry",
        "dense_dark_foliage_jungle": "Dark canopy, near-black green depth, shadow mass",
        "blurred_urban_neon_bokeh": "Out-of-focus city at night — neon colour bokeh circles",
        "smoke_corridor_single_exit_light": "Smoke fill, single red exit light depth cue",
        "waterfall_mist_natural_diffusion": "Natural mist diffusion, soft stone texture at depth",
        "hotel_room_dark_window_city_glow": "Dark room, ambient city bleed through curtain",
        "chain_link_fence_bokeh_circles": "Chain link OOF — repeating circle bokeh pattern",
        "corrugated_iron_wall_rusty": "Rust-streaked corrugated metal, industrial texture",
        "peeling_painted_brick_wall": "Flaking old paint layers, brick beneath, decay",
        "hospital_curtain_institutional_green": "Partition curtain, flat institutional colour, close",
        "white_bedsheet_crumpled_flat": "Crumpled white linen — domestic, intimate, soft",
        "stacked_newspaper_archive_wall": "Dense stacked paper texture, editorial reference",
        "broken_plaster_exposed_lath": "Demolition wall — plaster gap, lath ribs visible",
        "rain_on_window_bokeh_streaks": "Rear window with rain rivulets — vertical bokeh streaks",
        "shallow_water_pebble_caustic": "Clear shallow water, pebble bed, caustic light ripple",
        "oliphant_mottled_grey_painted_canvas": "Hand-painted Sarah Oliphant storm-grey and raw-umber canvas backdrop with subtle brush texture and dark vignette edges",
        "avedon_stark_white_seamless_dark_border": "Pure unlit white seamless paper with black negative-fill border edges and zero environmental distraction",
        "blizzard_pine_forest_whiteout_depth": "Snow-laden evergreen forest receding into dense whiteout blizzard fog with soft tonal compression",
        "rain_slicked_haussmann_boulevard_sodium_glow": "Wet Parisian cobblestone boulevard at night reflecting warm sodium streetlamps and red tail-light trails",
        "desert_dry_lakebed_heat_mirage_horizon": "Cracked alkali desert playa stretching to a shimmering heat-mirage mountain horizon under deep blue sky",
        "soundstage_scaffolding_c_stands_and_para": "Exposed backstage studio architecture with Broncolor Para 222 reflector, sandbagged C-stands, and coiled power cables"
    }
}

# ==============================================================================
# TEXT RECON MANIFEST
# ==============================================================================
TEXT_MANIFEST = {
    "strings": {
        "see_you_soon_ellipsis":            "See you soon...",
        "dont_look_for_me":                 "Don't look for me",
        "i_was_here":                       "I was here",
        "you_were_right":                   "You were right",
        "forget_this":                      "Forget this",
        "its_too_late":                     "It's too late",
        "im_fine":                          "I'm fine",
        "no_text_none":                     "(none)",
        "custom_freeform":                  "[user-defined custom string]",
        "dont_wait_up":                     "Don't wait up",
        "nothing_happened":                 "Nothing happened",
        "i_know_what_you_did":              "I know what you did",
        "not_your_fault":                   "Not your fault",
        "call_me":                          "Call me",
        "help":                             "Help",
        "im_sorry":                         "I'm sorry",
        "almost":                           "Almost",
        "stay":                             "Stay",
        "leave_me_alone":                   "Leave me alone",
        "you_wont_find_me":                 "You won't find me",
        "this_is_how_it_ends":              "This is how it ends",
        "never_mind":                       "Never mind",
        "phone_number_partial":             "[partial phone number — digits smeared]",
        "address_partial_scrawl":           "[partial address — illegible last line]",
        "date_only":                        "[date only — no month context]",
    },
    "font_aesthetics": {
        "lipstick_finger_scrawl_red":       "Imperfect finger-scrawled red lipstick, uneven pressure",
        "lipstick_block_print_smeared":     "Block caps, lipstick, smeared trailing edge",
        "eyeliner_script_shaky":            "Thin eyeliner line, shaky fine pressure strokes",
        "bloody_fingertip_drag_strokes":    "Drag stroke, dark red, forensic texture",
        "condensation_finger_traced":       "Traced through steam, barely legible, drip artefacts",
        "permanent_marker_thick_quick":     "Thick Sharpie strokes, fast hand, minor bleed",
        "no_text_none":                     "(none)",
        "nail_varnish_painted_slow":        "Nail polish as ink — thick, gloss, uneven stroke width",
        "mascara_run_down_surface":         "Mascara drag — running pigment, gravity distorted",
        "chalk_on_wet_surface_dissolving":  "Chalk strokes on wet tile — dissolving as written",
        "white_paint_house_brush_crude":    "Housepainter brush, white on dark, urgent crude stroke",
        "newspaper_cutout_ransom_style":    "Cut-and-paste newsprint letters, mixed fonts, threatening",
        "engraved_deep_surface_scratch":    "Key-scratched into mirror silver — permanent incision",
        "soap_bar_written_window":          "Bar soap across glass — waxy translucent stroke",
    },
    "placement": {
        "mirror_glass_plane_sharp":         "On mirror glass XY-plane, sharp, legible, in-focus",
        "mirror_upper_left_partial_fog":    "Upper-left, partially obscured by condensation",
        "mirror_lower_right_intimate":      "Lower-right corner, small, intimate scale",
        "mirror_center_full_width":         "Center horizontal, dramatic full-width",
        "wall_tile_adjacent_mirror":        "On bathroom tile, adjacent to mirror surface",
        "no_text_placement_none":           "(none)",
        "on_skin_forearm_written":          "Written directly on subject forearm skin",
        "on_skin_chest_palm_print":         "Handprint or word pressed on chest or sternum",
        "floor_tile_underfoot":             "Text on floor — camera looks down to read",
        "steamed_window_exterior_view":     "On exterior window — reads reversed from inside",
        "folded_note_half_open":            "Diegetic note, half-unfolded, held in frame",
        "over_image_as_title_card":         "Typographic overlay — narrative title card treatment",
        "scratched_into_door_paint":        "Scratched into painted door surface — relief mark",
    },
}

# ==============================================================================
# OPACITY / MATERIAL PHYSICS MANIFEST
# ==============================================================================
MATERIAL_MANIFEST = {
    "opacity": {
        "gradient_tension_mapping":         "Transparency scales with fabric tension over body peaks",
        "fully_opaque":                     "Zero transmission, solid colour throughout",
        "fully_transparent":                "Maximum transmission, fabric implied only by fold physics",
        "static_semi_opaque_50pct":         "Fixed 50% alpha — uniform across all zones",
        "wet_saturation_override":          "Moisture raises local transmission — peaks go sheer",
        "wet_saturation_full":              "Fully saturated — near-total transparency system-wide",
        "pattern_based_lace_opacity":       "Opacity defined by lace pattern geometry — opaque thread, transparent gap",
        "mesh_grid_binary_opacity":         "Binary — thread is opaque, weave gap is fully transparent",
        "layered_dual_material_composite":  "Two fabric layers — outer sheer over inner opaque base",
        "stretch_zone_gradient":            "Tension-gradient: seams opaque, stretched zones sheer",
        "backlit_transmission_only":        "Opacity only visible under transmitted backlight condition",
    },
    "textile_sheen": {
        "anisotropic_silk_flash_folds":     "Anisotropic silk — flash glare along tight fold lines",
        "matte_cotton_zero_specular":       "Near-zero specular, high diffuse — raw cotton",
        "satin_broad_low_roughness":        "Broad specular lobe, smooth low-roughness anisotropic",
        "denim_rough_diffuse_minimal":      "Rough diffuse, minimal sheen, heavy thread texture",
        "sheer_nylon_high_transparency":    "High transmission, near-zero sheen, thin gauge nylon",
        "velvet_anisotropic_directional":   "Direction-dependent deep black to bright flash response",
        "leather_high_specular_grain":      "Point specular on grain peaks, dark diffuse valleys",
        "wet_fabric_gloss_everywhere":      "Moisture coating — specular over entire surface area",
        "latex_mirror_reflection":          "Near-perfect specular — broad reflection map, rubber",
        "patent_leather_point_hotspot":     "Single tight hotspot, very low roughness, rigid surface",
        "linen_cross_weave_micro_specular": "Micro-specular from linen thread cross points, natural",
        "chiffon_very_low_sheen":           "Near-zero sheen, slight translucency, gossamer weight",
        "sequin_discrete_point_scatter":    "Individual sequin point reflectors — starburst scatter",
        "metallic_fabric_broad_mirror":     "Woven metallic thread — mirror + diffuse combination",
        "tweed_rough_harris_zero_sheen":    "Raw Harris tweed texture — no specular, dense weave",
    },
    "drape_physics": {
        "micro_fiber_drape":        {"HIGH": "Dense fibre simulation, realistic cloth fold complexity",
                                     "MEDIUM": "Moderate drape complexity, natural looking",
                                     "LOW": "Simplified physics, major fold lines only"},
        "tensile_deformity":        {"HIGH": "Strong deformation over body peaks, tight cling",
                                     "MEDIUM": "Moderate cling with gap pockets",
                                     "LOW": "Loose, barely touching body — minimal tension"},
        "gravity_folds":            {"HIGH": "Heavy gravity weighting, deep bunching at low points",
                                     "MEDIUM": "Moderate drape, natural hem fall",
                                     "LOW": "Minimal gravity expression — nearly no fold at hem"},
        "weave_density":            {"HIGH": "Dense tight weave, fine detail, specular micro-texture",
                                     "MEDIUM": "Standard weave density, typical cloth appearance",
                                     "LOW": "Loose open weave, individual thread gaps visible"},
        "sss_pass":                 {"ON": "SSS enabled — light through fabric visible",
                                     "OFF": "No SSS — opaque render only"},
        "adhesion_coefficient":     {"HIGH": "Fabric wraps flush to skin, zero gap pockets",
                                     "MEDIUM": "Moderate adhesion, minor air pockets at joints",
                                     "LOW": "Fabric floats off body, minimal skin contact"},
    },
}

# ==============================================================================
# FINALIZE / QUALITY MANIFEST
# ==============================================================================
FINALIZE_MANIFEST = {
    "focus_lock": {
        "micro_contrast_cloth_skin_text":   "Max micro-contrast on cloth weave, skin grain, text",
        "eyes_single_point_af_priority":    "Eye AF priority — single point, subject eyes only",
        "full_scene_deep_f8_hyperfocal":    "f/8 deep focus — environment and subject sharp",
        "fabric_texture_skin_soft":         "Fabric texture plane priority — skin slightly soft",
        "selective_midground_only":         "Only midground subject sharp — fore and back soft",
        "macro_skin_pore_razor":            "Razor-sharp macro — individual pore and follicle detail",
        "lips_and_teeth_priority":          "Lip texture and tooth surface as primary focus plane",
        "hands_and_fingers_priority":       "Hands in focus — knuckle texture, nail, vein detail",
        "hair_strand_individual_priority":  "Individual hair strand sharpness at max magnification",
        "background_soft_subject_sharp":    "Classic portrait — max separation, subject only sharp",
        "environmental_context_priority":   "Background readable and sharp, subject moderately soft",
        "water_droplet_surface_priority":   "Droplets on skin/glass as focus plane, subject behind",
        "tattoo_linework_surface_priority": "Tattoo ink edge as focus surface — skin texture secondary",
        "razor_sharp_sweatbeads_texture":   "razor-sharp focus on glistening sweatbeads and textured skin, depth showing how light wraps around body contours",
    },
    "negative_bias": {
        "BEAUTY_FILTER":                    "Reject any digital beauty overlay",
        "AIRBRUSHED_SKIN":                  "Reject frequency-separation or digital retouching",
        "PERFECT_FACIAL_SYMMETRY":          "Reject AI symmetry correction",
        "DIGITAL_3D_RENDER":                "Reject CGI or rendered output",
        "OPAQUE_FABRIC":         "Reject solid fabric — require physics-based transparency",
        "COMMERCIAL_STOCK_PHOTOGRAPHY_LOOK": "Reject commercial neutral look",
        "HAPPY_EXPRESSIONS":                "Reject positive expression — want detached or neutral",
        "IDENTITY_SHIFTING":                "Reject any facial modification from reference",
        "DEFAULT_COMMERCIAL_TOUCH-UP_LAYERS": "Reject AI default filters",
        "NOISE_REDUCTION_SMOOTHING":        "Reject noise reduction — preserve grain structure",
        "HAIR_FLYAWAY_REMOVAL":             "Reject hair retouching — all stray strands must remain",
        "BODY_PROPORTION_LIQUIFY":       "Reject any liquify or warp of body proportions",
        "SCAR_OR_TATTOO_REMOVAL":       "Reject any tattoo modification from reference",
        "SKIN_TONE_NORMALISATION":        "Reject AI skin normalisation",
        "AI_UPSCALING_ARTEFACT":      "Reject any AI artifacts",
        "CONTENT_AWARE_FILL":     "Reject environment cleanup — keep all scene elements",
    },
}

# ==============================================================================
# COLOR SCIENCE MANIFEST
# ==============================================================================
COLOR_SCIENCE_MANIFEST = {
    "cinema_log_profiles": {
        "ARRI_LogC4_AWG4":          "ARRI LogC4 with AWG4 — widest gamut, HDR mastering standard",
        "Sony_SLog3_SGamut3":       "Sony S-Log3 / S-Gamut3.Cine — cinema camera log encode",
        "REDLogFilm_RWG":           "RED Log Film with REDWideGamutRGB — REDCODE encode base",
        "Panasonic_VLog":           "Panasonic V-Log / V-Gamut — EVA1, S5 series log format",
        "Blackmagic_Film_Gen5":     "Blackmagic Film Gen 5 — BRAW embedded log profile",
        "Canon_CLog3":              "Canon C-Log 3 — EOS Cinema log, high-latitude midtone bias",
    },
    "color_spaces": {
        "ACEScg":                   "Academy Color Encoding — linear scene-referred, VFX standard",
        "DCI_P3":                   "Digital Cinema Initiative P3 — theatrical projection standard",
        "Rec_709_Broadcast":        "ITU-R BT.709 — HD broadcast delivery, sRGB display target",
        "Rec_2020_HDR":             "ITU-R BT.2020 — UHD/HDR wide colour gamut delivery",
    },
    "chemical_emulsion_physics": {
        "kodak_vision3_500T_tungsten":  "Tungsten-balanced cinema negative, rich shadow detail",
        "cinestill_800T_halation":      "Cinestill 800T red halation glow around highlights",
        "technicolor_3_strip_process":  "Three-strip dye transfer, saturated primary colour mapping",
        "bleach_bypass_process":        "Silver retention, elevated contrast, desaturation",
        "cross_processed_E6_in_C41":    "E6 slide film developed in C41 — colour inversion artefacts",
        "kodak_vision3_500t_ahu_silver_retention": "Kodak VISION3 AHU skip-bleach silver retention — deep metallic blacks, crushed shadows, muted desaturated skin",
        "fujifilm_velvia_50_reversal_chrome": "E-6 slide reversal film — hyper-dense blacks, electric emerald/magenta saturation, zero grain",
        "ilford_delta_3200_pushed_tabular_grain": "Pushed high-ISO tabular silver halide grain structure with rich midtone separation",
    },
}

# ==============================================================================
# OPTICAL ABERRATION MANIFEST
# ==============================================================================
OPTICAL_ABERRATION_MANIFEST = {
    "anamorphic_artifacts": {
        "ANAMORPHIC_2X_SQUEEZE_BLUE_STREAK": "2× anamorphic — horizontal blue lens streak, oval bokeh",
        "ANAMORPHIC_1.5X_AMBER_STREAK": "1.5× anamorphic — amber/gold streak, compressed aspect",
        "ANAMORPHIC_MUMPS_DISTORTION": "Anamorphic geometric barrel distortion — face warping"
    },
    "spherical_and_chromatic": {
        "LONGITUDINAL_CHROMATIC_ABERRATION": "Colour fringing fore/aft of focus plane — purple/green",
        "SPHERICAL_ABERRATION_ONION_RING": "Onion-ring OOF bokeh from uncorrected spherical",
        "CAT_EYE_MECHANICAL_VIGNETTING": "Elliptical bokeh at frame edges from aperture blade",
        "COMA_SAGITTAL_ASTIGMATISM": "Off-axis comet-tail coma, sagittal astigmatism stars"
    },
    "coating_physics": {
        "SINGLE_COATED_VINTAGE_FLARE": "Single-layer MgF2 — warm ghosting, broad veiling glare",
        "MULTI_COATED_MODERN_CLINICAL": "Multi-layer SMC/T* — minimal flare, clean contrast",
        "UNCOATED_FRONT_ELEMENT_BLOOMING": "No coating — extreme halation, bloom, low contrast"
    },
    "optical_diffusion_filters": {
        "TIFFEN_BLACK_PRO_MIST_1_4": "Tiffen Black Pro-Mist 1/4 — pastel highlight halation, softened skin micro-blemishes, preserved shadow blacks and pore acuity",
        "TIFFEN_BLACK_PRO_MIST_1_2": "Tiffen Black Pro-Mist 1/2 — pronounced dreamy highlight bloom, warm atmospheric glow around practical lamps, reduced digital harshness",
        "TIFFEN_GLIMMERGLASS_1": "Tiffen Glimmerglass #1 — clean highlight glow with subtle silver-sparkle front-element diffusion that preserves sharp eye catchlights",
        "TIFFEN_GLIMMERGLASS_3": "Tiffen Glimmerglass #3 — heavy ethereal highlight spread, lowered micro-contrast on wrinkles while keeping iris detail crisp",
        "SCHNEIDER_HOLLYWOOD_BLACK_MAGIC_1_4": "Black Frost + HD Classic Soft micro-lenslets for cinematic highlight halation and creamy skin transition",
        "SCHNEIDER_CLASSIC_SOFT_1_2": "In-glass micro-lenslet array blending fine dermal imperfections into a luminous filmic glow without muting shadow blacks",
        "CHRISTIAN_DIOR_STOCKING_NET_REAR_DIFFUSION": "Fine silk stocking net stretched across rear lens element — classic 1970s cinema star-filter halation and warm shadow veil",
        "SPLIT_DIOPTER_PLUS_2_HALF_FIELD": "Rotating +2 half-moon convex glass attachment rendering both extreme close-up foreground and distant background razor-sharp",
        "LINEAR_GLASS_PRISM_KALEIDOSCOPE_SMEAR": "Handheld triangular optical glass prism at frame edge duplicating specular highlights with spectral rainbow ghosts",
        "SCHEIMPFLUG_OBLIQUE_TILT_FOCUS_WEDGE": "8-degree front-standard lens tilt rotating the plane of sharp focus diagonally across the frame",
        "SWIRLY_SAGITTAL_PETZVAL_FIELD_CURVATURE": "Uncorrected 1840 Petzval field curvature spinning out-of-focus background highlights into a concentric vortex",
        "STREAK_FILTER_2MM_BLUE_ANAMORPHIC_EMULATION": "Linear cylindrical rod filter generating horizontal cyan flare streaks across point light sources",
        "CIRCULAR_POLARIZER_CPL_WET_GLARE_CUT": "Rotating circular polarizer cutting non-metallic water/glass specular glare to reveal deep subsurface color",
        "INFRARED_720NM_HOYA_R72_WOOD_EFFECT": "720nm infrared pass filter rendering foliage snow-white, skies pitch-black, and skin porcelain-translucent"
    }
}

# ==============================================================================
# METEOROLOGY MANIFEST
# ==============================================================================
METEOROLOGY_MANIFEST = {
    "particulate_scattering": {
        "MIE_SCATTERING_DENSE_FOG": "Mie scatter — large water droplet fog, flat grey ambient",
        "MIE_SCATTERING_SUSPENDED_DUST": "Mie scatter — dust particle haze, golden warm tint",
        "RAYLEIGH_SCATTERING_BLUE_HOUR": "Rayleigh scatter — atmospheric blue depth at twilight",
        "MARINE_LAYER_COASTAL_HAZE": "Marine layer — cool diffused Pacific/Atlantic coastal fog",
        "INDUSTRIAL_SMOG_PARTICULATE": "Urban particulate smog — yellow-brown scatter, sun disc",
        "BLIZZARD_WHITEOUT_HORIZONTAL_SNOW": "Blizzard whiteout — dense wind-driven snow squall, horizontal flake streaks, high-albedo whiteout diffusion (+1.5 EV snow luminance)",
        "POWDER_SNOW_FLURRIES_BACKLIT_BOKEH": "Powder snow flurries — soft drifting dendritic snowflakes catching rim strobe as large crystalline out-of-focus bokeh orbs",
        "DIAMOND_DUST_ICE_CRYSTAL_SCINTILLATION": "Diamond dust — sub-zero clear-sky suspended hexagonal ice prisms sparkling like airborne glitter in low-angle raking sunlight",
        "HOARFROST_AND_RIME_ICE_CRYSTALLIZATION": "Hoarfrost & rime ice — feathery white ice needles and freezing-fog frost encrusting eyelashes, hair strands, and surrounding surfaces",
        "WET_SLEET_AND_GRAUPEL_SLUSH_PELTING": "Wet sleet & graupel — half-melted translucent ice pellets streaking diagonally at 1/250s shutter speed, clinging to wool and skin",
        "FREEZING_FOG_SUPERCOOLED_RIME_VEIL": "Freezing fog — sub-zero supercooled micro-droplet fog depositing delicate matte white rime ice on windward contours",
        "ALPENGLOW_ARCTIC_SEA_SMOKE_STEAM_FOG": "Arctic sea smoke — frigid sub-zero air over warmer water generating rising steam-fog shafts lit by pink-gold alpenglow",
        "GENTLE_LARGE_FLAKE_SNOWFALL_STILL_AIR": "Gentle snowfall — large intact stellar dendrites drifting vertically down through calm twilight air",
        "TORRENTIAL_DOWNPOUR_SHEET_RAIN_BACKLIT": "Torrential downpour — heavy monsoon-density vertical rain sheets backlit by hard rim strobe with high-velocity splash crowns on floor",
        "FINE_MIST_DRIZZLE_ATOMIZED_SUSPENSION": "Fine mist drizzle — micro-droplet coastal haar/drizzle hanging in air, beading on vellus cheek hair and wool fibers without streaks",
        "FROZEN_RAINDROP_1_4000S_FLASH_BACKSCATTER": "Flash-frozen raindrops (1/4000s HSS) — individual spherical water drops suspended mid-air with internal specular refraction and near-lens orb backscatter",
        "SLOW_SHUTTER_1_30S_SILVER_RAIN_STREAKS": "Slow-shutter rain streaks (1/30s) — falling raindrops elongated into diagonal silver-needle motion trails across dark backgrounds",
        "SUNSHOWER_IRIDESCENT_RAINBOW_REFRACTION": "Sunshower refraction — direct golden sunlight breaking through warm rain shower with spectral rainbow dispersion and glossy wet skin",
        "POST_STORM_PETRICHOR_STEAM_RISING": "Post-storm petrichor mist — immediate post-downpour evaporation vapor rising off rain-blackened asphalt with mirror puddle reflections",
        "HAILSTORM_ICE_STONE_RICOCHET": "Hailstorm ricochet — translucent layered hailstones bouncing off stone/asphalt in chaotic high-speed trajectories",
        "WIND_DRIVEN_SQUALL_DIAGONAL_RAIN_LASH": "Wind-driven rain squall — 45-degree diagonal sheets of rain lashing across face and drenching garment folds",
        "RADIATION_GROUND_FOG_LOW_LAYER": "Radiation ground fog — shallow waist-high morning fog blanketing the ground plane while upper torso and face emerge into clear air",
        "ADVECTION_COASTAL_SEA_FOG_ROLLING": "Advection sea fog — dense rolling marine fog bank drifting inland off cold water, muting background contrast into a silver-grey veil",
        "HILL_FOG_CLOUD_INVERSION_SEA_OF_CLOUDS": "Cloud inversion / hill fog — dense sea of clouds resting below elevated vantage point with diffused top sunlight",
        "THERMAL_GEYSER_SULFUR_STEAM_PLUME": "Geothermal steam plume — thick billowing hot-spring vapor diffusing backlight into pearlescent clouds",
        "CREPUSCULAR_GOD_RAYS_TYNDALL_SHAFTS": "Crepuscular Tyndall god-rays — collimated sunlight or HMI shafts slicing through particulate haze with razor-sharp shadow edges",
        "THEATRICAL_CRACKED_OIL_HAZER_BEAMS": "Studio cracked-oil hazer — uniform 1-micron mineral-oil haze suspended in studio air to reveal laser-sharp Fresnel and parabolic light cones",
        "DRY_ICE_CO2_FLOOR_CLOUD_BLANKET": "Cryogenic dry-ice CO2 cloud — heavy low-lying white vapor hugging the studio floor in swirling eddies around ankles and hem",
        "COLORED_PYROTECHNIC_SMOKE_GRENADE_PLUME": "Colored smoke plume — dense pigment smoke (crimson/cyan/violet) billowing around subject with rich subsurface color bounce",
        "SAHARAN_HABOOB_SANDSTORM_WALL": "Saharan haboob sandstorm — ochre-amber suspended desert silica dust wall reducing visibility and casting warm 2800K diffused solar glow",
        "VOLCANIC_ASH_AND_CINDER_FALLOUT": "Volcanic ash fallout — charcoal-grey silicate ash flakes drifting downward like dark snow with warm ember glow in background",
        "THUNDERSTORM_OZONE_LIGHTNING_STROBE": "Thunderstorm lightning discharge — 50,000K branched cloud-to-ground lightning illuminating storm clouds and wet skin with electric blue-violet flash",
        "HEAT_SHIMMER_MIRAGE_REFRACTION": "Convective heat shimmer — thermal air-density gradients warping distant background lines above sun-baked tarmac or desert sand",
        "POLLEN_AND_DANDELION_SEED_DRIFT": "Botanical pollen & pappus drift — backlit organic dandelion seeds and golden pollen motes floating lazily through warm afternoon air",
        "CHERRY_BLOSSOM_PETAL_FLURRY_VORTEX": "Sakura petal flurry — swirling pale pink cherry-blossom petals caught in cross-breeze with shallow depth-of-field foreground blur",
        "AUTUMN_EMBER_SPARKS_AND_WOODSMOKE": "Ember sparks & woodsmoke — glowing orange wood-fire sparks and blue-grey hearth smoke drifting upward through dark air"
    },
    "wind_vectors": {
        "wind_velocity_zero_stagnant": "0 m/s — no fabric movement, no hair displacement",
        "wind_velocity_low_laminar": "1–3 m/s — slight laminar fabric edge, hair tips lifted",
        "WIND_VELOCITY_HIGH_TURBULENT": "8–12 m/s — turbulent fabric billow, hair fully displaced",
        "thermal_updraft_vertical": "Vertical updraft — fabric lifts from hem, hair rises",
        "wind_velocity_whisper_0_5ms_vellus_flutter": "0.5–1.5 m/s (Beaufort 1 Light Air) — barely perceptible draft moving only stray temple flyaways and sheer organza edges",
        "wind_velocity_gentle_breeze_4ms_silk_ripple": "3.5–5.5 m/s (Beaufort 3 Gentle Breeze) — steady horizontal breeze rippling silk hems and parting hair across one cheek",
        "wind_velocity_moderate_breeze_7ms_editorial_flow": "5.5–8.0 m/s (Beaufort 4 Moderate Breeze) — classic editorial wind lifting hair cleanly off shoulders and streaming scarf/train backward",
        "wind_velocity_fresh_breeze_10ms_coastal_gust": "8.0–11.0 m/s (Beaufort 5 Fresh Breeze) — brisk coastal wind pressing light fabrics against windward hip and whipping hair into dynamic streaks",
        "wind_velocity_strong_breeze_14ms_dramatic_cape": "11.0–14.0 m/s (Beaufort 6 Strong Breeze) — forceful wind inflating capes, coats, and wide skirts into dramatic sculptural sails",
        "wind_velocity_Fresh_Gale_18ms_couture_billow": "17.0–20.5 m/s (Beaufort 8 Fresh Gale) — powerful gale pressing front of garment tight against torso while train billows horizontally behind",
        "wind_velocity_storm_squall_26ms_horizontal_whip": "24.5–28.5 m/s (Beaufort 10 Storm Squall) — violent storm gusts whipping wet hair and heavy coat lapels horizontally across frame",
        "wind_velocity_hurricane_force_33ms_extreme_lean": "32.7+ m/s (Beaufort 12 Hurricane Force) — extreme aerodynamic force requiring subject to lean forward into the blast while rain/spray streaks horizontally",
        "studio_ego_blower_focused_axial_jet": "Studio EGO wind-tunnel blower aimed from 45° below lens axis — symmetrical radial hair halo and lifted collar with calm face",
        "dual_cross_fan_turbulent_eddy_collision": "Two opposing studio Ritter fans at 90° left and right — chaotic upward vortex eddies lifting fabric and hair in unpredictable sculptures",
        "crosswind_shear_45_degree_asymmetric_drape": "45° diagonal crosswind shear — taut fabric adhesion on windward thigh/ribcage paired with billowing leeward folds",
        "tailwind_posterior_gust_forward_hair_veil": "Direct rear tailwind gust — blowing long hair forward over shoulders and across face while dress flares ahead of knees",
        "headwind_frontal_blast_sleek_contour": "Direct frontal headwind — sweeping all hair straight back from forehead and molding sheer textile tightly against collarbone and sternum",
        "katabatic_downdraft_vertical_compression": "Cold heavy katabatic downdraft — pressing hair and shoulders downward while flaring skirt hem outward in a 360° circle on floor",
        "cyclonic_helical_vortex_swirl": "Rotational cyclonic vortex — wrapping sheer fabric, snow/petals, and hair in a spiral helix around the vertical spine axis",
        "helicopter_rotor_downwash_turbulence": "Extreme radial rotor downwash — flattening surface puddles into concentric shockwave ripples and whipping garments violently outward",
        "subway_grate_thermal_updraft_marilyn_lift": "Warm subterranean exhaust updraft — billowing dress hem steeply upward from floor plane while upper bodice stays calm"
    }
}

# ==============================================================================
# STATIC SCHEMA BLOCKS — never randomised, never prompted
# These are injected verbatim by generate_random() and build_mem_lock()
# ==============================================================================
STATIC_MEM_LOCK = {
    "SYSTEM_REFERENCE_INPUT": "INGREDIENT",
    "BIOMETRIC_LOCK": "TRUE (REPLICATING_EVERY_PIXEL_OF_THE_ANITOMALOGICAL_TOPOPGRAPHY_PERFECTLY)",
    "IDENTITY_DRIFT_CONTROL": "MAXIMUM_LOCK (INHIBIT_AUTOMATIC_AI_SKIN-SMOOTHING_FILTERS,_ELIMINATE_FACIAL_BALANCING_OR_SYMMETRY_MODIFICATIONS,_BYPASS_DEFAULT_COMMERCIAL_TOUCH-UP_LAYERS._ENFORE=VISCERAL_REACTION_TO_AN_UNPLEASANT_TASTE,_OPENING_MOUTH_REVEALING_TONGUE_SLATHERED_IN_SEMI_TRANSLUCENT,_MILKY_VISCOUS_GEL--TONGUE_ROLLS;_WINCES)",
    "STRUCTURAL_NON_DEVIATION": "HIGH",
    "STRUCTURAL_FIDELITY": "HIGH",
    "UNALTERABLE": [
        "EXACT_FACIAL_ID_GEOMETRY",
        "UN-BEAUTIFIED_FACIAL_BONE_CONTOURS",
        "EXACT_BODY_PROPORTIONS",
        "TRUE_BODYFAT_PERCENTAGE_DISTRIBUTION",
    ],
    "!INHIBIT": [
        "AUTOMATIC_SKIN-SMOOTHING_FILTERS",
        "FACIAL_BALANCING",
        "BRAZZIER_SUPPORT",
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
            "DIGITAL_3D_RENDER",
            "COMMERCIAL_STOCK_PHOTOGRAPHY_LOOK",
            "HAPPY_EXPRESSIONS",
            "IDENTITY_SHIFTING",
            "HAIR_CLEANUP_FLYAWAY",
            "OPAQUE_FABRIC",
            "BODY_PROPORTION_ALTERATION",
        ],
    }
}

# ==============================================================================
# FLATTENED INDICES FOR O(1) LOOKUPS AND WORD COMPLETER INJECTION
# ==============================================================================

# Kinematic
FLAT_POSE_INDEX: dict[str, str] = {}
for _cat in KINEMATIC_MANIFEST.values():
    for _k, _v in _cat.items():
        FLAT_POSE_INDEX[_k] = _v

# Layout
FLAT_LAYOUT_INDEX: dict[str, str] = {}
for _cat in LAYOUT_MANIFEST.values():
    for _layout_name, _layout_data in _cat.items():
        FLAT_LAYOUT_INDEX[_layout_name] = str(_layout_data)

# Lighting
FLAT_LIGHTING_INDEX: dict[str, str] = {}
for _k, _v in LIGHTING_PHYSICS_MANIFEST.items():
    FLAT_LIGHTING_INDEX[_k] = _v

# Style
FLAT_STYLE_INDEX: dict[str, str] = {}
for _k, _v in STYLING_MANIFEST.items():
    FLAT_STYLE_INDEX[_k] = _v

# Photonic energy
FLAT_ENERGY_INDEX: dict[str, str] = {}
for _k, _v in PHOTONIC_ENERGY_MANIFEST.items():
    FLAT_ENERGY_INDEX[_k] = _v

# Views
FLAT_VIEW_INDEX: dict[str, str] = {}
for _k, _v in VIEWS_MANIFEST.items():
    FLAT_VIEW_INDEX[_k] = _v

# Camera bodies
FLAT_CAMERA_INDEX: dict[str, str] = {}
for _k, _v in CAMERA_BODY_MANIFEST.items():
    FLAT_CAMERA_INDEX[_k] = _v

# Lenses
FLAT_LENS_INDEX: dict[str, str] = {}
for _k, _v in LENS_MANIFEST.items():
    FLAT_LENS_INDEX[_k] = _v

# Apertures
FLAT_APERTURE_INDEX: dict[str, str] = {}
for _k, _v in APERTURE_MANIFEST.items():
    FLAT_APERTURE_INDEX[_k] = _v

# Wardrobe
FLAT_WARDROBE_INDEX: dict[str, str] = {}
for _k, _v in WARDROBE_MANIFEST.items():
    FLAT_WARDROBE_INDEX[_k] = _v

# Skin — all sub-dicts flattened
FLAT_SKIN_INDEX: dict[str, str] = {}
for _cat in SKIN_MANIFEST.values():
    for _k, _v in _cat.items():
        FLAT_SKIN_INDEX[_k] = _v

# Location
FLAT_LOCATION_INDEX: dict[str, str] = {}
for _cat in LOCATION_MANIFEST.values():
    for _k, _v in _cat.items():
        FLAT_LOCATION_INDEX[_k] = _v

# Glass
FLAT_GLASS_INDEX: dict[str, str] = {}
for _k, _v in GLASS_SURFACE_MANIFEST.items():
    FLAT_GLASS_INDEX[_k] = _v

# DOF — all sub-dicts flattened
FLAT_DOF_INDEX: dict[str, str] = {}
for _cat in DOF_MANIFEST.values():
    for _k, _v in _cat.items():
        FLAT_DOF_INDEX[_k] = _v

# Text
FLAT_TEXT_STRINGS_INDEX: dict[str, str] = {}
for _k, _v in TEXT_MANIFEST["strings"].items():
    FLAT_TEXT_STRINGS_INDEX[_k] = _v
FLAT_TEXT_FONT_INDEX: dict[str, str] = {}
for _k, _v in TEXT_MANIFEST["font_aesthetics"].items():
    FLAT_TEXT_FONT_INDEX[_k] = _v
FLAT_TEXT_PLACEMENT_INDEX: dict[str, str] = {}
for _k, _v in TEXT_MANIFEST["placement"].items():
    FLAT_TEXT_PLACEMENT_INDEX[_k] = _v

# Material
FLAT_OPACITY_INDEX: dict[str, str] = {}
for _k, _v in MATERIAL_MANIFEST["opacity"].items():
    FLAT_OPACITY_INDEX[_k] = _v
FLAT_SHEEN_INDEX: dict[str, str] = {}
for _k, _v in MATERIAL_MANIFEST["textile_sheen"].items():
    FLAT_SHEEN_INDEX[_k] = _v

# Finalize
FLAT_FOCUS_INDEX: dict[str, str] = {}
for _k, _v in FINALIZE_MANIFEST["focus_lock"].items():
    FLAT_FOCUS_INDEX[_k] = _v
FLAT_NEG_BIAS_INDEX: dict[str, str] = {}
for _k, _v in FINALIZE_MANIFEST["negative_bias"].items():
    FLAT_NEG_BIAS_INDEX[_k] = _v

# Color science — nested two levels
FLAT_COLOR_SCIENCE_INDEX: dict[str, str] = {}
for _cat in COLOR_SCIENCE_MANIFEST.values():
    for _k, _v in _cat.items():
        FLAT_COLOR_SCIENCE_INDEX[_k] = _v

# Optics — nested two levels
FLAT_OPTICS_INDEX: dict[str, str] = {}
for _cat in OPTICAL_ABERRATION_MANIFEST.values():
    for _k, _v in _cat.items():
        FLAT_OPTICS_INDEX[_k] = _v

# Meteorology — nested two levels
FLAT_METEOROLOGY_INDEX: dict[str, str] = {}
for _cat in METEOROLOGY_MANIFEST.values():
    for _k, _v in _cat.items():
        FLAT_METEOROLOGY_INDEX[_k] = _v

# Ray Tracing
FLAT_RAY_TRACING_INDEX: dict[str, str] = {}
for _cat in RAY_TRACING_MANIFEST.values():
    for _k, _v in _cat.items():
        FLAT_RAY_TRACING_INDEX[_k] = _v

# ==============================================================================
# WORD COMPLETER LISTS — imported by prompt_arc.py
# ==============================================================================
POSE_COMPLETIONS        = list(FLAT_POSE_INDEX.keys())
LAYOUT_COMPLETIONS      = list(FLAT_LAYOUT_INDEX.keys())
LIGHTING_COMPLETIONS    = list(FLAT_LIGHTING_INDEX.keys())
STYLE_COMPLETIONS       = list(FLAT_STYLE_INDEX.keys())
ENERGY_COMPLETIONS      = list(FLAT_ENERGY_INDEX.keys())
VIEW_COMPLETIONS        = list(FLAT_VIEW_INDEX.keys())
CAMERA_COMPLETIONS      = list(FLAT_CAMERA_INDEX.keys())
LENS_COMPLETIONS        = list(FLAT_LENS_INDEX.keys())
APERTURE_COMPLETIONS    = list(FLAT_APERTURE_INDEX.keys())
WARDROBE_COMPLETIONS    = list(FLAT_WARDROBE_INDEX.keys())
SKIN_COMPLETIONS        = list(FLAT_SKIN_INDEX.keys())
LOCATION_COMPLETIONS    = list(FLAT_LOCATION_INDEX.keys())
GLASS_COMPLETIONS       = list(FLAT_GLASS_INDEX.keys())
DOF_COMPLETIONS         = list(FLAT_DOF_INDEX.keys())
TEXT_STRING_COMPLETIONS = list(FLAT_TEXT_STRINGS_INDEX.keys())
TEXT_FONT_COMPLETIONS   = list(FLAT_TEXT_FONT_INDEX.keys())
TEXT_PLACE_COMPLETIONS  = list(FLAT_TEXT_PLACEMENT_INDEX.keys())
OPACITY_COMPLETIONS     = list(FLAT_OPACITY_INDEX.keys())
SHEEN_COMPLETIONS       = list(FLAT_SHEEN_INDEX.keys())
FOCUS_COMPLETIONS       = list(FLAT_FOCUS_INDEX.keys())
NEG_BIAS_COMPLETIONS    = list(FLAT_NEG_BIAS_INDEX.keys())
COLOR_COMPLETIONS       = list(FLAT_COLOR_SCIENCE_INDEX.keys())
OPTICS_COMPLETIONS      = list(FLAT_OPTICS_INDEX.keys())
METEOROLOGY_COMPLETIONS = list(FLAT_METEOROLOGY_INDEX.keys())
RAY_TRACING_COMPLETIONS = list(FLAT_RAY_TRACING_INDEX.keys())

# Shared small sets reused across many prompts
BOOL_COMPLETIONS        = ["TRUE", "FALSE"]
LEVEL_COMPLETIONS       = ["HIGH", "MEDIUM", "LOW", "ULTRA", "OFF"]
FIDELITY_COMPLETIONS    = ["HIGH", "MEDIUM", "LOW", "ULTRA", "EXTREME"]
LOCK_COMPLETIONS        = ["MAXIMUM_LOCK", "HIGH_LOCK", "MEDIUM_LOCK", "LOW_LOCK", "UNLOCKED"]
PANEL_COUNT_COMPLETIONS = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

UNALTERABLE_COMPLETIONS = [
    "EXACT_FACIAL_ID_GEOMETRY",
    "UN-BEAUTIFIED_FACIAL_BONE_CONTOURS",
    "EXACT_BODY_PROPORTIONS",
    "TRUE_BODYFAT_PERCENTAGE_DISTRIBUTION",
    "NATURAL_SKIN_TONE_UNSHIFTED",
    "ORIGINAL_SCAR_TATTOO_MARK_GEOMETRY",

]

INHIBIT_COMPLETIONS = [
    "AUTOMATIC_SKIN-SMOOTHING_FILTERS",
    "FACIAL_BALANCING",
    "POSE_MODIFICATIONS",

    "SYMMETRY_MODIFICATIONS",
    "DEFAULT_COMMERCIAL_TOUCH-UP_LAYERS",
    "AI_BEAUTIFICATION",
    "FREQUENCY_SEPARATION_RETOUCHING",

    "NOISE_REDUCTION_SMOOTHING",
    "HAIR_FLYAWAY_REMOVAL",
    "BODY_PROPORTION_LIQUIFY",

    "SCAR_OR_TATTOO_REMOVAL",
    "SKIN_TONE_NORMALISATION",

    "EYE_SIZE_ENLARGEMENT",
    "JAW_SLIMMING",
    "NOSE_NARROWING",
    "BROW_LIFTING",
    "LIP_AUGMENTATION_FILTER",

    "CONTENT_AWARE_FILL",
    "AI_UPSCALING_ARTEFACT",
    "FACE_SWAPPING",
    "FACE_AVERAGING",
    "IDENTITY_DRIFT",
    "BODY_DRIFT",
    "BODY_AVERAGING",
    "PERFECT_POSTURE",
]

# Skin topology — standalone completion list
TOPO_COMPLETIONS = [
    "unfiltered_hyper_realistic_dermal_detail",
    "high_magnification_sebaceous_follicles",
    "wet_skin_condensation_texture",
    "dry_aged_deep_crease_mapping",
    "sun_damaged_hyperpigmentation",
    "young_unretouched_fine_pore_mapping",
    "post_workout_flushed_capillary_map",
    "cold_skin_pallor_reduced_circulation",
    "fevered_skin_warm_flush_damp",
    "scarred_terrain_irregular_surface",
    "tattooed_surface_ink_embedded",
    "very_dark_skin_deep_melanin_mapping",
    "very_pale_translucent_vessel_visible",
    "mature_skin_deep_structural_fold",
]

# Shutter / sync — standalone completion list
SHUTTER_COMPLETIONS = [
    "flash_sync_1_60_standard", "flash_sync_1_125_standard",
    "flash_sync_1_250_hss", "flash_sync_1_500_hss_full_kill",
    "long_exposure_bulb_ambient_bleed", "flash_sync_1_30_heavy_ambient",
    "flash_sync_1_8000_leaf_shutter", "rear_curtain_sync_motion_trail",
    "multi_flash_stroboscopic_freeze",
]
# Dedicated sub-category completion lists for precision sampling and completion
PARTICULATE_COMPLETIONS = list(METEOROLOGY_MANIFEST["particulate_scattering"].keys())
WIND_COMPLETIONS        = list(METEOROLOGY_MANIFEST["wind_vectors"].keys())
ICONIC_SET_COMPLETIONS  = list(LOCATION_MANIFEST.get("iconic_editorial_sets", {}).keys())
