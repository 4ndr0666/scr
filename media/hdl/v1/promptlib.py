#!/usr/bin/env python3
# ==============================================================================
# INTEGRATED PARAMETER REGISTRY AND MATRIX LIBRARY (promptlib.py)
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
        "lithotomy_position":           "0.0,-0.7,-0.4",
        "trendelenburg_position":       "0.0,-1.0,-0.3",
        "reverse_trendelenburg":        "0.0,-1.0,0.3",
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
        "squat_full_deep":              "0.0,-0.95,0.0",
        "squat_parallel_utility":       "0.0,-0.7,0.0",
        "squat_wide_sumo":              "0.0,-0.65,0.0",
        "standing_wide_base":           "0.0,0.0,0.0",
        "standing_one_leg_left":        "-0.2,0.1,0.0",
        "standing_one_leg_right":       "0.2,0.1,0.0",
        "bending_waist_orthogonal":     "0.0,-0.5,0.5",
        "stooping_low":                 "0.0,-0.6,0.4",
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
}

# ==============================================================================
# CAMERA VIEWS MANIFEST
# ==============================================================================
VIEWS_MANIFEST = {
    "EXTREME CLOSE-UP (ECU/XCU)":                   "Fills frame with single feature — eye, mouth, hand",
    "CLOSE-UP (CU)":                                 "Head and shoulders only, tight on face",
    "MEDIUM CLOSE-UP (MCU)":                         "Chest and above — classic portrait framing",
    "MEDIUM SHOT (MS)":                              "Waist and above — standard conversational",
    "FULL SHOT (FS)":                                "Head to toe — full body in frame",
    "WIDE SHOT (WS/LS)":                             "Subject dwarfed by environment — context dominant",
    "EXTREME WIDE SHOT (EWS/XLS)":                  "Maximum environment — subject near invisible",
    "BIRDS EYE (BE)":                                "True overhead, 90° looking directly down",
    "AERIAL OBLIQUE (AO)":                           "45–70° downward from height — dramatic spatial context",
    "WORM EYE LOW ANGLE (WELA)":                     "Camera at ground level looking steeply upward",
    "LOW ANGLE DUTCH (LAD)":                         "Below subject, canted frame — power + disorientation",
    "HIGH ANGLE STANDARD (HAS)":                     "Above subject looking down at 20–45°",
    "SIDE CLOSE-UP (SCU)":                           "Lateral profile, chest level, slight downward tilt",
    "THREE_QUARTER DRAMATIC HIGH ANGLE (TQDH)":      "45° rotated, elevated 8ft, looking down",
    "FRONT FISH EYE (FE)":                           "Ultra-wide rectilinear distortion, full front",
    "FRONT EXTREME CLOSE-UP MACRO (ECUM/XCUM)":      "100mm macro, full rib cage, f/2.8, razor sharp",
    "OVER_SHOULDER (OS)":                            "Camera behind and above one shoulder, sees face",
    "DUTCH_ANGLE_45 (DA45)":                         "Frame canted 45° clockwise — tension, instability",
    "TRACKING_LATERAL (TL)":                         "Camera moves parallel to subject mid-motion",
    "REACTION SHOT (RS)":                            "Tight on face catching emotional response",
    "INSERT MACRO DETAIL (IMD)":                     "Object or body-part detail — hands, lips, fabric",
    "SPLIT DIOPTER (SD)":                            "Two focal planes sharp simultaneously",
    "RACK_FOCUS_PULL (RFP)":                         "Foreground sharp → background sharp, soft middle",
}

# ==============================================================================
# PHOTOGRAPHY STYLE MANIFEST
# ==============================================================================
STYLING_MANIFEST = {
    "HELMUT_NEWTON":                                    "Hard, confrontational, power-charged fashion — clinical flash",
    "STEVEN_KLEIN":                                     "Dark editorial surrealism — high contrast, theatrical",
    "GUY_BOURDIN":                                      "Hyper-saturated colour, fetishistic tension, graphic composition",
    "ELLEN_VON_UNWERTH":                                "Playful erotic energy, warm film grain, intimate candid",
    "PETRA_COLLINS":                                    "Dreamy pastel lo-fi, analog grain, teenage melancholy",
    "CASS_BIRD":                                        "Raw candid queer intimacy, natural light, grainy street",
    "ELLEN_VON_UNWERTH_AND_PETRA_COLLINS_AND_CASS_BIRD": "Combined: flash intimacy + pastel dreaming + raw candid",
    "ROXANNE_LOWIT":                                    "Backstage energy, unguarded moments, shallow flash DOF",
    "MARIO_SORRENTI":                                   "Intimate skincare aesthetic, natural skin, soft shadow",
    "DAVID_LACHAPELLE":                                 "Hyper-real pop surrealism, neon saturation, staged excess",
    "TIM_WALKER":                                       "Fantasy narrative, rich colour, theatrical sets, dreamy",
    "NADIA_LEE_COHEN":                                  "Retro-kitsch Americana, high-key pastel, deadpan irony",
    "DEBORAH_TURBEVILLE":                               "Haunting desolation, soft blur, faded feminine decay",
    "YELENA_YEMCHUK":                                   "Eastern European art-film noir, clinical cool, isolation",
    "DEBORAH_TURBEVILLE_AND_YELENA_YEMCHUK":            "Combined: decay aesthetics + clinical art-film isolation",
    "CORINNE_DAY":                                      "Heroin chic raw realism, underexposed snap, unglamourised",
    "NAN_GOLDIN":                                       "Diaristic flash, raw LGBTQ+ intimacy, grain and love",
    "LARRY_CLARK":                                      "Transgressive youth realism, handheld dirty flash",
    "DAIDO_MORIYAMA":                                   "High-contrast B&W, Tokyo street grain, bleached shadows",
    "HORST_P_HORST":                                    "1930s modernist elegance, dramatic shadow sculpture",
    "RICHARD_AVEDON":                                   "Clean white backdrop, psychological portrait tension",
    "HORST_P_HORST_AND_RICHARD_AVEDON":                 "Combined: shadow sculpture + psychological clean tension",
    "PETER_LINDBERGH":                                  "B&W naturalism, windswept, minimal retouching philosophy",
    "LEE_MILLER":                                       "Surrealist Dada feminine gaze, wartime documentary",
    "PETER_LINDBERGH_AND_LEE_MILLER":                   "Combined: B&W naturalism + surrealist feminine gaze",
    "MARIO_TESTINO":                                    "Glossy celebrity warmth, sun-drenched high fashion",
    "BRUCE_WEBER":                                      "Golden homoerotic American athleticism, warm soft light",
    "MARIO_TESTINO_AND_BRUCE_WEBER":                    "Combined: glossy celebrity warmth + athletic golden glow",
    "ANNIE_LEIBOVITZ":                                  "Epic conceptual portraiture, rich colour, high production",
    "TYLER_MITCHELL":                                   "Afrofuturist pastoral, soft natural warm tones",
    "CAMPBELL_ADDY":                                    "Celebration of Black identity, saturated warm editorial",
    "ANNIE_LEIBOVITZ_AND_TYLER_MITCHELL_AND_CAMPBELL_ADDY": "Combined: epic concept + pastoral warmth + identity celebration",
    "HERB_RITTS":                                       "Sculptural B&W bodies, Californian minimalism, clean curves",
    "EMMA_SUMMERTON":                                   "Cinematic narrative fashion, surreal storytelling, rich tone",
    "RYAN_MCGINLEY":                                    "Euphoric youth freedom, sunlit nudity, spontaneous motion",
    "JUERGEN_TELLER":                                   "Anti-fashion rawness, unflattering angles, lo-fi snapshot",
    "TERRY_RICHARDSON":                                 "Hard on-axis flash, snapshot aesthetic, hyper-saturated",
    "PAOLO_ROVERSI":                                    "Long-exposure dreamy blur, Polaroid softness, pastel dark",
    "NICK_KNIGHT":                                      "Digital experimental, colour-shifted, tech-fashion hybrid",
    "STEVEN_MEISEL":                                    "Versatile chameleon editorial, provocative concept-driven",
    "GLEN_LUCHFORD":                                    "Cinematic wide-angle tension, hyper-real skin, dark narrative",
    "SOLVE_SUNDSBO":                                    "Technical digital surrealism, scanner aesthetics, extreme",
    "INEZ_AND_VINOODH":                                 "High-gloss digital perfection, stark beauty, sharp shadows",
    "CRAIG_MCDEAN":                                     "Cool B&W minimalism, graphic lines, technical precision",
}

# ==============================================================================
# LIGHTING PHYSICS MANIFEST
# ==============================================================================
LIGHTING_PHYSICS_MANIFEST = {
    # ── Key Light Sources ──────────────────────────────────────────────────────
    "on_camera_popup_flash_5500K":              "Hard on-axis flash, inverse-square falloff, harsh catch-lights",
    "off_camera_strobe_45_left_5600K":          "45° camera-left hard strobe, sharp single shadow",
    "off_camera_strobe_45_right_5600K":         "45° camera-right hard strobe, mirrored shadow",
    "ring_flash_on_axis_5500K":                 "Flat fill, signature ring catch-light, zero shadow",
    "bare_bulb_handheld_flash_5400K":           "Omnidirectional scatter, wrap-around hard light",
    "softbox_large_octagonal_5600K":            "Broad soft wrap, graduated shadow edge",
    "softbox_strip_narrow_5600K":               "Directional wrap, controlled spill, classic beauty",
    "beauty_dish_silver_5500K":                 "Punchy skin texture, specular punch, mid-shadow",
    "beauty_dish_white_5500K":                  "Softer punch, less specular than silver dish",
    "parabolic_reflector_deep_5600K":           "Focused hard spot, specular column, long throw",
    "fresnel_spotlight_5600K":                  "Variable hard/soft with grid, theatrical control",
    "hmi_daylight_5600K":                       "Parallel near-zero falloff, hard cinema key",
    "led_panel_bicolor_variable_K":             "Variable colour temp, soft even field, low shadow",
    "tungsten_open_face_3200K":                 "Warm hard directional, high CRI warmth",
    "tungsten_softbox_3200K":                   "Warm soft wrap, low colour temp, incandescent glow",
    "candle_practical_1800K":                   "Extreme warm flicker, very soft falloff, romantic",
    "neon_tube_practical_variable":             "Coloured ambient wash, hum artefact, retro-industrial",
    "fluorescent_overhead_bank_4000K":          "Flat overhead fill, green-shift potential, commercial",
    # ── Ambient / Fill ─────────────────────────────────────────────────────────
    "window_natural_daylight_5600K":            "Soft directional side fill, rolling gradient shadow",
    "window_overcast_diffused_6500K":           "Flat cool fill, near-zero contrast, even skin tone",
    "skylight_open_shade_7000K":                "Cool blue fill from open sky, subtle specular",
    "bounce_silver_reflector_fill":             "Specular bounce fill, 0.7 ratio to key",
    "bounce_white_card_fill":                   "Soft matte bounce fill, 0.3–0.5 ratio",
    "no_fill_true_ratio_lighting":              "No fill — deep shadows, pure ratio setup",
    "practical_lamp_3000K_background":          "Background warm practical, 0.1 ratio ambient bleed",
    "ambient_tungsten_3200K_background":        "Dim warm background glow, ratio 0.04",
    "ambient_moonlight_4100K":                  "Cool blue-grey ambient, very low intensity",
    # ── Modifier Flags ─────────────────────────────────────────────────────────
    "grid_10_degree":                           "Tight grid on key — zero spill, spot control",
    "grid_30_degree":                           "Medium grid — moderate spill control",
    "gel_CTO_full_warm_3200K":                  "Full CTO warm gel over daylight source",
    "gel_CTB_full_cool_6500K":                  "Full CTB cool gel over tungsten source",
    "gel_red_saturated":                        "Deep red ambient wash, dramatic colour",
    "gel_green_saturated":                      "Sickly green wash — clinical, horror adjacent",
    "gel_blue_deep":                            "Cold blue wash — night, alienation",
    "snoot_tight_beam":                         "Narrow cone, precise hot-spot isolation",
    "barn_doors_four_way":                      "Rectangular spill control on key source",
    "diffusion_silk_heavy":                     "Heavy diffusion over strobe — very soft",
    "diffusion_frost_light":                    "Light frost — minor softening, retains punch",
    # ── Shadow Profile ─────────────────────────────────────────────────────────
    "shadow_razor_hard_zero_penumbra":          "Jet-black drop shadows, zero feather, contact print hard",
    "shadow_moderate_10pct_feather":            "Slight edge softness, still defined",
    "shadow_soft_graduated_30pct":              "Gradual transition, 30% penumbra blend zone",
    "shadow_no_shadow_high_key":                "No visible shadow — flat even illumination",
    "shadow_double_crosslit_artifact":          "Two shadow directions from cross-lit sources",
    "shadow_long_oblique_directional":          "Long stretched shadow — subject at oblique angle to key",
    # ── Flash Sync & Shutter ───────────────────────────────────────────────────
    "flash_sync_1_60_standard":                 "Standard flash sync, slight ambient bleed at slow end",
    "flash_sync_1_125_standard":                "Clean standard sync, minimal ambient",
    "flash_sync_1_250_hss":                     "High-speed sync, daylight killing capability",
    "flash_sync_1_500_hss_full_kill":           "Maximum daylight suppression, pure flash look",
    "long_exposure_bulb_ambient_bleed":         "Bulb exposure + flash pop — motion blur background",
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
    "ASHIKHMIN_SHIRLEY_ANISOTROPIC":        "Anisotropic specular — fabric, brushed metal, hair",
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
}

# ==============================================================================
# HARDWARE MANIFEST — CAMERA BODIES
# ==============================================================================
CAMERA_BODY_MANIFEST = {
    # ── Full Frame DSLR ────────────────────────────────────────────────────────
    "Canon EOS 5D Mark IV":         "36×24mm CMOS, 30.4MP, DIGIC 7, Dual Pixel AF",
    "Canon EOS 5D Mark III":        "36×24mm CMOS, 22.3MP, DIGIC 5+, classic film-era output",
    "Canon EOS R5":                 "45MP BSI CMOS, IBIS, 8K RAW, Dual Pixel CMOS AF II",
    "Canon EOS-1D X Mark III":      "20.1MP, 16fps, CFexpress, pro sport/studio hybrid",
    "Nikon D850":                   "45.7MP BSI CMOS, 153pt AF, tilting LCD, clean ISO",
    "Nikon D800":                   "36.3MP FX, legendary landscape/studio resolution",
    "Nikon Z7 II":                  "45.7MP BSI, IBIS, Z-mount mirrorless, dual card",
    "Sony A7R V":                   "61MP BSI Exmor R, AI-AF, 5-axis IBIS, compact FF",
    "Sony A7 III":                  "24.2MP BSI, dual native ISO, versatile hybrid",
    "Sony A1":                      "50MP, 30fps, 8K video, global shutter option",
    # ── Medium Format ──────────────────────────────────────────────────────────
    "Hasselblad X2D 100C":          "100MP BSI, 5-axis IBIS, no AA filter, natural colour",
    "Phase One IQ4 150MP":          "150MP CMOS back, 16-bit RAW, trichromatic option",
    "Fujifilm GFX 100S":            "102MP BSI CMOS, IBIS, compact MF, superb film sims",
    "Fujifilm GFX 50R":             "51.4MP MF, rangefinder body, rich tonal gradation",
    "Pentax 645Z":                  "51.4MP CMOS, weather-sealed, DSLR-style MF, tilting",
    # ── Leica & Rangefinder ────────────────────────────────────────────────────
    "Leica M11":                    "60MP BSI, frameless base plate, timeless rangefinder",
    "Leica M10-R":                  "40MP, optical rangefinder, no EVF, pure analogue feel",
    "Leica SL2-S":                  "24.6MP, contrast AF, rugged L-mount, cinema hybrid",
    # ── Film — 35mm ───────────────────────────────────────────────────────────
    "35mm Film — Kodak Portra 400": "Natural skin tones, fine grain, wide latitude",
    "35mm Film — Kodak Portra 800": "Pushed warmth, visible grain, low-light latitude",
    "35mm Film — Kodak Ektar 100":  "Hyper-saturated, fine grain, vibrant primaries",
    "35mm Film — Fujifilm Superia 1600": "High-ISO grain, pushed green bias, club/night",
    "35mm Film — Fujifilm Pro 400H": "Soft pastel skin, wide highlight latitude, feminine",
    "35mm Film — Ilford HP5 Plus (B&W)": "Classic B&W, pushed to 3200 gritty, versatile",
    "35mm Film — Ilford Delta 3200": "Extreme grain, B&W, pushed high-ISO documentary",
    "35mm Film — Kodak Tri-X 400 (B&W)": "Iconic B&W, rich grain, high contrast heritage",
    "35mm Film — Cinestill 800T":   "Tungsten-balanced, halation glow, cinema in 35mm",
    "35mm Film — Lomography Color 100": "Toy-camera cross-process, saturated, lo-fi",
    # ── Film — Medium Format ───────────────────────────────────────────────────
    "120mm Film — Kodak Portra 400 MF": "MF Portra, enormous tonal range, fine grain at 6×7",
    "120mm Film — Ilford FP4 125 (B&W)": "Fine grain B&W, long tonal scale, architectural",
    "120mm Film — Fujifilm FP-100C (Instant)": "Peel-apart instant, warm tones, unique surface",
    # ── Instant ───────────────────────────────────────────────────────────────
    "Polaroid 600 Series":          "Square format instant, soft vignette, slow emulsion",
    "Polaroid SX-70":               "Folding SLR instant, legendary soft focus rendering",
    "Impossible Project I-1":       "Modern Polaroid, controlled colour, ring flash built-in",
}

# ==============================================================================
# HARDWARE MANIFEST — LENSES
# ==============================================================================
LENS_MANIFEST = {
    # ── Canon EF / RF ──────────────────────────────────────────────────────────
    "Canon EF 100mm f/2.8L Macro IS USM":   "1:1 macro, IS, L-series, clinically sharp close-up",
    "Canon EF 85mm f/1.2L II USM":          "Legendary subject isolation, creamy bokeh, fast AF",
    "Canon EF 85mm f/1.4L IS USM":          "Sharp wide open, IS, modern 85mm portrait king",
    "Canon EF 50mm f/1.2L USM":             "Natural perspective, classic bokeh rendition",
    "Canon EF 35mm f/1.4L II USM":          "Wide open sharpness, environmental portrait",
    "Canon EF 24-70mm f/2.8L II USM":       "Workhorse zoom, constant f/2.8, sharp throughout",
    "Canon EF 70-200mm f/2.8L IS III USM":  "Reach + bokeh, press/sport/portrait compression",
    "Canon RF 85mm f/1.2L USM DS":          "Dual Sensing ND coating, reduced bokeh fringing",
    # ── Nikon F / Z ───────────────────────────────────────────────────────────
    "Nikon AF-S 85mm f/1.4G":              "3D pop bokeh, world-class portrait rendering",
    "Nikon AF-S 105mm f/1.4E ED":          "Exceptional resolution + subject separation at f/1.4",
    "Nikon AF-S 58mm f/1.4G":             "Micro-contrast perfection, spherical 3D rendering",
    "Nikon AF-S Micro 105mm f/2.8G VR":   "Macro + portrait, VR stabilised, exceptional sharpness",
    "Nikon Z 85mm f/1.2 S":               "Best-in-class Z-mount portrait, near-perfect rendering",
    # ── Sony FE ───────────────────────────────────────────────────────────────
    "Sony FE 85mm f/1.4 GM":              "G Master sharpness, 11-blade circular bokeh",
    "Sony FE 135mm f/1.8 GM":             "Stunning compression, bokeh smoothness, razor sharp",
    "Sony FE 50mm f/1.2 GM":             "Perfect 50mm — sharp, small, beautiful rendering",
    "Sony FE 90mm f/2.8 Macro G OSS":    "1:1 macro, OSS stabilised, clinical sharpness",
    # ── Sigma Art ─────────────────────────────────────────────────────────────
    "Sigma 85mm f/1.4 DG DN Art":         "Third-party portrait king, exceptional value, sharp",
    "Sigma 35mm f/1.4 DG HSM Art":        "Wide portrait, superb sharpness wide open",
    "Sigma 105mm f/2.8 DG DN Macro Art":  "Macro + portrait dual-use, exceptional optical quality",
    "Sigma 50mm f/1.4 DG HSM Art":        "Technical masterpiece 50mm, heavy but superb",
    # ── Zeiss ─────────────────────────────────────────────────────────────────
    "Zeiss Otus 85mm f/1.4":              "Near-perfect optical resolution, clinical Zeiss rendering",
    "Zeiss Otus 55mm f/1.4":              "Scientifically sharp 50mm, manual focus masterpiece",
    "Zeiss Milvus 135mm f/2":             "Dramatic compression, Zeiss micro-contrast, manual",
    "Zeiss Loxia 50mm f/2":               "Compact FE portrait, clinical Zeiss quality compact",
    # ── Voigtländer / Manual ──────────────────────────────────────────────────
    "Voigtländer 40mm f/1.2 Nokton":      "Compact fast lens, smooth rendering, unique character",
    "Voigtländer 75mm f/1.5 Nokton II":   "Leica M portrait, smooth transitional bokeh",
    "Leica Summilux 50mm f/1.4 ASPH":     "Legendary Leica character, precise micro-contrast",
    "Leica APO-Summicron 75mm f/2 ASPH":  "Near-perfect optical correction, unmatched clarity",
    # ── Vintage / Character Lenses ────────────────────────────────────────────
    "Helios 44-2 58mm f/2 (Swirly Bokeh)": "Soviet swirly bokeh, character imperfection, cult lens",
    "Meyer-Optik Trioplan 100mm f/2.8 (Soap Bubble Bokeh)": "Soap bubble OOF circles, dreamy rendering",
    "Petzval 85mm f/2.2 Art Lens":        "Swirly field, sharp centre, 19th century optical character",
    "Nikkor 105mm f/2.5 AI (Vintage)":    "Classic portrait rendering, warm, smooth, legendary",
    # ── Tilt-Shift / Speciality ───────────────────────────────────────────────
    "Canon TS-E 90mm f/2.8L Macro":       "Tilt-shift perspective correction + selective focus plane",
    "Canon TS-E 135mm f/4L Macro":        "Long tilt-shift, architectural + beauty macro",
    "Laowa 100mm f/2.8 2X Ultra Macro":   "2:1 macro magnification, manual, hyper detail",
}

# ==============================================================================
# APERTURE MANIFEST
# ==============================================================================
APERTURE_MANIFEST = {
    "f/1.0":  "Maximum light, extreme subject isolation, diffraction-free at this extreme",
    "f/1.2":  "Near-maximum aperture, razor-thin DOF, character bokeh wide open",
    "f/1.4":  "Classic fast portrait aperture, one eye sharp, beautiful subject separation",
    "f/1.8":  "Excellent sharpness/bokeh balance, most versatile portrait aperture",
    "f/2.0":  "Strong subject isolation, improved mid-frame sharpness over f/1.8",
    "f/2.8":  "Standard fast zoom maximum, deep technical sharpness, significant DOF",
    "f/4.0":  "Group portrait aperture, both eyes and nose sharp in 3/4 profile",
    "f/5.6":  "Landscape/studio standard, front to 3m sharp at 85mm FF",
    "f/8.0":  "Classic studio aperture, full face and hair sharp at 1.5m",
    "f/11":   "Maximum sharpness zone for most lenses, front to 6m at 50mm",
    "f/16":   "Deep focus environmental portrait, near hyperfocal",
    "f/22":   "Hyperfocal zone, diffraction softening visible, creative deep focus",
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
    "white_mesh_crop_top":                          "Open weave, full skin visibility, no opacity",
    "cream_knit_sweater_oversized":                 "Heavy texture, opaque, off-shoulder slip potential",
    # ── Black / Dark ───────────────────────────────────────────────────────────
    "black_sheer_organza_blouse_open":              "Fully unbuttoned, ultra-sheer black, dark transparency",
    "black_bodycon_bandage_dress":                  "High tension, zero drape, contouring fabric physics",
    "black_velvet_slip_dress":                      "Anisotropic velvet sheen, opaque deep black",
    "black_leather_jacket_open":                    "Over nothing, heavy drape, specular highlight on grain",
    "black_fishnet_bodysuit":                       "Open lattice, full skin visibility, patterned transparency",
    "dark_denim_jacket_open_distressed":            "Distressed, raw hem, worn texture, heavy drape",
    # ── Neutral / Raw ─────────────────────────────────────────────────────────
    "raw_linen_shift_unstructured":                 "Natural beige, looser weave, environmental drape",
    "oversized_vintage_t_shirt_distressed":         "Distressed, off-shoulder, screen-printed faded graphic",
    "grey_cotton_jersey_bodysuit":                  "Low denier jersey, full coverage but form-fitted",
    "nude_seamless_bodysuit":                       "Flesh-tone illusion of nudity, technical fabric mapping",
    # ── Speciality Physics ────────────────────────────────────────────────────
    "wet_white_cotton_fully_saturated":             "White cotton soaked through — near-complete transparency",
    "wet_silk_fully_saturated_adhesion":            "Silk plastered to skin, adhesion coefficient HIGH",
    "bare_skin_no_wardrobe":                        "No fabric — full skin physics, no textile render",
}

# ==============================================================================
# SKIN TOPOGRAPHY MANIFEST
# ==============================================================================
SKIN_MANIFEST = {
    "expressions": {
        "cool_detached_neutral_lips_parted":        "Jaw relaxed, lips parted 2mm, gaze camera/mirror",
        "vacant_dissociative_mid_distance":         "Eyes unfocused, pupils mid-distance, emotionally absent",
        "micro_tension_brow_suppressed":            "Controlled suppression — slight brow tension, jaw set",
        "eyes_closed_meditative":                   "Downward withdrawn, eyelids at 60%, emotionally sealed",
        "downward_gaze_introspective":              "Eyes at floor, private thought, not engaging lens",
        "confrontational_direct_brow_relaxed":      "Full eye contact, brow calm, jaw set, jaw relaxed",
        "slight_mouth_corner_tension":              "Near-smile tension without commitment, ambiguous",
        "upper_lip_micro_curl":                     "One-sided lip micro-expression, contempt or smirk",
        "open_mouth_exhale_lips_wet":               "Open jaw 8mm, visible wet inner lip, exhale breath",
    },
    "hair": {
        "messy_loose_updo_stray_strands":           "Uncombined updo, strands across cheeks and neck",
        "soaked_wet_plastered_flat":                "Hair saturated, flat against scalp, dripping ends",
        "down_dishevelled_tangled_partial_cover":   "Unbrushed, tangled, partially covering one eye",
        "short_cropped_damp_sweat":                 "Short crop, damp, showing scalp texture, flat",
        "severe_pulled_back_high_tension":          "Slicked back high bun, zero stray, tight tension",
        "half_up_half_down_clip_one_side":          "One side clipped, other falling loose across shoulder",
        "long_loose_windswept_across_face":         "Wind-blown coverage of face, one eye hidden",
        "braided_tight_cornrows":                   "Tight to scalp, strong geometric scalp line mapping",
        "natural_coily_textured_volume":            "Unmanipulated natural texture, full volume, shrinkage",
    },
    "reflectance": {
        "high_specular_damp_skin_flash":            "Glisten on damp skin from flash — wet specular dominant",
        "oiled_skin_broad_low_roughness":           "Oiled — wide specular lobe, near-zero roughness",
        "matte_dry_zero_specular":                  "Completely dry matte — no specular return",
        "mixed_wet_dry_zonal":                      "Specular only on forehead, nose bridge, clavicle",
        "sss_dominant_translucent_rim":             "Subsurface dominant — glowing rim, soft specular cap",
    },
    "surface_micro": {
        "full_unretouched_pores_goosebumps_sweat":  "Pores, goosebumps, micro sweat beads, natural folds",
        "micro_sweat_pooling_clavicle":             "Sweat pooling in clavicle hollow, follicle mapping",
        "dry_flake_lips_under_eye_creases":         "Dry lip texture, under-eye tissue, forehead depth",
        "goosebump_shoulder_arm_only":              "Goosebump texture isolated to shoulder/arm region",
        "acne_unretouched_visible_texture":         "Active or healing acne — unfiltered, scarring visible",
        "freckles_sun_damage_hyper_pigmentation":   "Natural freckling, sun spots, uneven pigmentation",
        "body_hair_natural_visible":                "Natural visible body hair — arms, legs, abdomen",
        "stretch_marks_natural":                    "Natural stretch marks at hip and breast — authentic",
        "vein_visibility_subsurface":               "Subsurface veins visible at inner forearm/wrist",
    },
}

# ==============================================================================
# LOCATION / ENVIRONMENT MANIFEST
# ==============================================================================
LOCATION_MANIFEST = {
    "interior_wet": {
        "bathroom_steam_ceramic_harsh_flash":           "Steamed ceramic tiles, condensation glass, single flash",
        "shower_waterfall_stone_hiding":                "Subject hiding in waterfall behind stones",
        "indoor_pool_underwater_tiles":                 "Submerged or poolside, chlorine-blue ambient",
        "hotel_bathroom_marble_tungsten":               "Luxury marble, tungsten practicals, intimate",
        "locker_room_industrial_fluorescent":           "Institutional benches, flat overhead fluorescent",
        "wet_concrete_floor_drain_flash":               "Bare wet concrete, industrial drain, hard flash",
    },
    "interior_dry": {
        "hotel_room_window_backlight_only":             "Dark room, strong window backlight, noir silhouette",
        "industrial_warehouse_single_pendant":          "Rough concrete, single tungsten pendant, deep shadows",
        "studio_black_seamless_pure":                   "Black seamless, no environment, total control",
        "studio_white_high_key":                        "White seamless, high-key fill, detail priority",
        "apartment_bedroom_natural_chaos":              "Personal bedroom, dishevelled, available light only",
        "underground_club_strobe_ambient":              "Dark club, strobe flash mix, motion potential",
        "dressing_room_vanity_mirror_bulbs":            "Vanity bulb surround, warm mirror reflections",
        "hospital_corridor_fluorescent_cold":           "Clinical cold fluorescent, empty corridor, sterile",
        "brutalist_stairwell_concrete":                 "Exposed concrete stairwell, hard directional light",
    },
    "exterior_night": {
        "rooftop_city_backlight_night":                 "Rooftop, city glow backlight, cool ambient",
        "urban_alley_single_sodium_lamp":               "Sodium street lamp, warm isolated pool, deep shadow",
        "wet_pavement_reflection_neon":                 "Rain-slicked street, neon reflection, hard flash fill",
        "empty_parking_garage_fluorescent":             "Multi-level garage, flat tubes, shadow geometry",
        "forest_moonlight_no_ambient":                  "Near-darkness, blue moonlight, deep shadow nature",
        "industrial_loading_dock_night":                "Hard sodium raking, concrete edge shadows, cargo",
    },
    "exterior_day": {
        "outdoor_waterfall_natural_mist":               "Natural waterfall, mist diffusion, even ambient",
        "rooftop_golden_hour_rim_light":                "Warm oblique sun rim, city haze background",
        "beach_overcast_flat_natural":                  "Overcast diffused, near-shadowless, neutral cool",
        "desert_harsh_midday_zenith":                   "Brutal overhead sun, razor shadows, bleached",
        "dense_forest_dappled_canopy":                  "Scattered filtered light, green ambient bias",
    },
}

# ==============================================================================
# GLASS SURFACE MANIFEST
# ==============================================================================
GLASS_SURFACE_MANIFEST = {
    "condensation_calcium_grease_dust":             "Irregular droplets, calcium spots, grease smudges, flash-lit dust",
    "heavy_steam_occluded_centre":                  "Dense steam condensation blocking central surface",
    "cracked_silver_nitrate_decay_edge":            "Fracture lines, mirror decay at perimeter",
    "freshly_wiped_squeegee_streak":                "Wipe artifacts, faint streak lines, near clean",
    "rain_streaked_exterior_neon_reflection":        "Exterior rain, neon colour cast overlay",
    "no_glass_open_environment":                    "No glass surface — open air, no reflective plane",
    "fogged_exterior_frost_interior":               "Temperature differential, fogged and frosted",
    "lipstick_text_on_glass_condensation":          "Text written through condensation, drip artefacts",
    "fingerprint_smear_dense":                      "Dense fingerprint oils, glare catching on flash",
    "mirror_black_glass_minimal_fog":               "Dark mirror base, minimal distortion, clean reflection",
}

# ==============================================================================
# DEPTH OF FIELD MANIFEST
# ==============================================================================
DOF_MANIFEST = {
    "foreground": {
        "shallow_cinematic_dramatic":               "Shallow DOF, film-style subject isolation, creamy falloff",
        "extreme_shallow_subject_sharp_pure_bokeh": "Razor-thin plane, pure bokeh background and foreground",
        "deep_focus_full_scene_sharp":              "Front-to-back sharp — f/8 or f/11 hyperfocal zone",
        "medium_dof_soft_background":               "Subject sharp, background soft, foreground hint blur",
        "tilt_shift_selective_plane":               "Oblique focus plane — selective miniature effect",
        "split_diopter_dual_plane":                 "Two sharp planes simultaneously — classic de Palma",
        "rack_focus_pull_mid_transition":           "Focus transition from foreground to background",
    },
    "midground": {
        "subject_behind_waterfall_stones":          "Subject hiding in waterfall behind stones",
        "subject_vanity_back_to_mirror":            "Subject at vanity, back to mirror, three-quarter",
        "subject_standing_quarter_turn_away":       "Three-quarter turn, back partially to lens",
        "subject_lying_supine_up_at_camera":        "Floor level, looking directly upward at lens",
        "subject_crouching_corner_arms_wrapped":    "Corner crouch, arms around knees, self-contained",
        "subject_mid_motion_mid_stride":            "Caught mid-step, kinetic energy, motion blur edge",
        "subject_seated_vanity_lean_forward":       "Counter-seated, legs relaxed, torso leaning forward",
    },
    "background": {
        "ceramic_tiles_deep_shadow_grout":          "Dark ceramic, high-contrast grout lines, minimal ambient",
        "pure_black_void_zero_detail":              "Total black, zero ambient environment",
        "exposed_concrete_brutalist_raking":        "Rough concrete, hard light angle, shadow geometry",
        "dense_dark_foliage_jungle":                "Dark canopy, near-black green depth, shadow mass",
        "blurred_urban_neon_bokeh":                 "Out-of-focus city at night — neon colour bokeh circles",
        "smoke_corridor_single_exit_light":         "Smoke fill, single red exit light depth cue",
        "waterfall_mist_natural_diffusion":         "Natural mist diffusion, soft stone texture at depth",
        "hotel_room_dark_window_city_glow":         "Dark room, ambient city bleed through curtain",
    },
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
    },
    "font_aesthetics": {
        "lipstick_finger_scrawl_red":       "Imperfect finger-scrawled red lipstick, uneven pressure",
        "lipstick_block_print_smeared":     "Block caps, lipstick, smeared trailing edge",
        "eyeliner_script_shaky":            "Thin eyeliner line, shaky fine pressure strokes",
        "bloody_fingertip_drag_strokes":    "Drag stroke, dark red, forensic texture",
        "condensation_finger_traced":       "Traced through steam, barely legible, drip artefacts",
        "permanent_marker_thick_quick":     "Thick Sharpie strokes, fast hand, minor bleed",
        "no_text_none":                     "(none)",
    },
    "placement": {
        "mirror_glass_plane_sharp":         "On mirror glass XY-plane, sharp, legible, in-focus",
        "mirror_upper_left_partial_fog":    "Upper-left, partially obscured by condensation",
        "mirror_lower_right_intimate":      "Lower-right corner, small, intimate scale",
        "mirror_center_full_width":         "Center horizontal, dramatic full-width",
        "wall_tile_adjacent_mirror":        "On bathroom tile, adjacent to mirror surface",
        "no_text_placement_none":           "(none)",
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
    },
    "negative_bias": {
        "STUDIO_SOFTBOX_LIGHTING":          "Reject flat beauty softbox — want harsh flash only",
        "BEAUTY_FILTER":                    "Reject any digital beauty overlay",
        "AIRBRUSHED_SKIN":                  "Reject frequency-separation or digital retouching",
        "PERFECT_FACIAL_SYMMETRY":          "Reject AI symmetry correction",
        "DIGITAL_3D_RENDER":                "Reject CGI or rendered output",
        "OPAQUE_FABRIC_PROCESSING":         "Reject solid fabric — require physics-based transparency",
        "CLEAN_MINIMALIST_ARCHITECTURE":    "Reject styled interior — want raw industrial",
        "COMMERCIAL_STOCK_PHOTOGRAPHY_LOOK": "Reject commercial neutral look",
        "HAPPY_EXPRESSIONS":                "Reject positive expression — want detached or neutral",
        "IDENTITY_SHIFTING":                "Reject any facial modification from reference",
        "DAYLIGHT":                         "Reject natural daylight — want flash-dominated",
        "INSTAGRAM_GRADE":                  "Reject any social media colour grade",
        "VSCO_LUT":                         "Reject VSCO preset colour influence",
        "HDR_TONE_MAPPING":                 "Reject HDR or tone-mapping artefacts",
        "LENS_FLARE_OVERLAY":               "Reject added lens flare — flash hard, no haze",
        "VIGNETTE_FILTER":                  "Reject post-production vignette overlay",
        "SYMMETRY_MODIFICATIONS":           "Reject pose or body symmetry corrections",
        "POSE_MODIFICATIONS":               "Reject AI pose alteration from input reference",
        "CAMERA_ANGLE_MODIFICATIONS":       "Reject auto camera angle adjustment",
    },
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

# ==============================================================================
# WORD COMPLETER LISTS — imported by hdl_prompt_builder.py
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

# Shared small sets reused across many prompts
BOOL_COMPLETIONS        = ["TRUE", "FALSE"]
LEVEL_COMPLETIONS       = ["HIGH", "MEDIUM", "LOW", "ULTRA", "OFF"]
FIDELITY_COMPLETIONS    = ["HIGH", "MEDIUM", "LOW", "ULTRA", "EXTREME"]
LOCK_COMPLETIONS        = ["MAXIMUM_LOCK", "HIGH_LOCK", "MEDIUM_LOCK", "LOW_LOCK", "UNLOCKED"]
PANEL_COUNT_COMPLETIONS = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

UNALTERABLE_COMPLETIONS = [
    "EXACT_FACIAL_ID_GEOMETRY",
    "TRUE_ORBITAL_BONE_SPACING",
    "UNFILTERED_LIP_PROPORTIONS",
    "RAW_JAWLINE_ANGLE",
    "UN-BEAUTIFIED_FACIAL_BONE_CONTOURS",
    "EXACT_BODY_PROPORTIONS",
    "TRUE_BODYFAT_PERCENTAGE_DISTRIBUTION",
    "NATURAL_EAR_GEOMETRY",
    "AUTHENTIC_NASAL_BRIDGE_ANGLE",
    "UNMODIFIED_BROW_RIDGE_DEPTH",
]

INHIBIT_COMPLETIONS = [
    "AUTOMATIC_SKIN-SMOOTHING_FILTERS",
    "FACIAL_BALANCING",
    "POSE_MODIFICATIONS",
    "CAMERA_ANGLE_MODIFICATIONS",
    "SYMMETRY_MODIFICATIONS",
    "DEFAULT_COMMERCIAL_TOUCH-UP_LAYERS",
    "AI_BEAUTIFICATION",
    "FREQUENCY_SEPARATION_RETOUCHING",
    "DODGE_AND_BURN_DIGITAL",
    "LUT_GRADE_OVERLAYS",
]
