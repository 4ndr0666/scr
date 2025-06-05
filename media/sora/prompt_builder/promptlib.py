#!/usr/bin/env python3
"""Prompt generation library for cinematic pose workflows."""

from __future__ import annotations

# -----------------------------------------------------------------------------
# Module 0: Expanded POSE_TAGS (≈45 tags, pulled from Pose_prompting.pdf)
# -----------------------------------------------------------------------------
POSE_TAGS: list[str] = [
    "leaning_forward",
    "crouching",
    "one_knee_up",
    "looking_back_seductively",
    "sitting_on_heels",
    "arms_crossed",
    "hands_in_pockets",
    "walking_toward_camera",
    "jumping",
    "running",
    "arms_raised",
    "sitting_crosslegged",
    "lying_down",
    "hands_on_hips",
    "kneeling",
    "twisting_shoulder",
    "tilted_head",
    "looking_up",
    "looking_down",
    "leaning_back",
    "bending_sideways",
    "hands_in_air",
    "resting_chin_on_hand",
    "side_profile",
    "three_quarter_profile",
    "back_to_camera",
    "over_shoulder_glance",
    "arms_above_head",
    "backbend",
    "hand_on_knee",
    "hand_on_chest",
    "hand_on_waist",
    "crossed_legs_stand",
    "splayed_legs",
    "squat",
    "lunge",
    "leg_stretched",
    "bend_forward",
    "bend_backward",
    "lean_left",
    "lean_right",
    "lean_forward_knee",
    "lunge_forward",
    "hands_on_ground",
    "hugging_self",
    "covering_face",
    "shielding_eyes"
]

# -----------------------------------------------------------------------------
# Module 1: generate_prompt_variants
# -----------------------------------------------------------------------------
def generate_prompt_variants(subject_description: str) -> list[str]:
    """Create three stylistically distinct prompt variants.

    Args:
        subject_description: Base concept or scenario.

    Returns:
        List of three complete prompt candidates.
    """
    base = subject_description.lower()
    variants: list[str] = []

    # — Variant 1: Close-up + macro detail + Deakins light —
    variants.append(
        f"> {{\n"
        f"    {base.strip().capitalize()}.\n"
        "    Lighting: golden-hour sunlight from 35° camera-left, hard shadows; moody tone.\n"
        "    Lens: 85mm f/1.4, shallow DoF.\n"
        "    Camera: [push in, handheld sway].\n"
        "    Environment: minimal neutral backdrop with warm color haze.\n"
        "    Detail: preserve skin pores, fabric threading, and microexpression shifts.\n"
        "    *Note: cinematic references must be interpreted within each platform’s current capabilities.*\n"
        "}"
    )

    # — Variant 2: Wide shot + ambient fill light + dolly arc —
    variants.append(
        f"> {{\n"
        f"    {base.strip().capitalize()}.\n"
        "    Lighting: diffused skylight with bounce fill at 45°, soft edge shadows.\n"
        "    Lens: 35mm f/2.8, deep focus.\n"
        "    Camera: [arc, dolly left].\n"
        "    Environment: outdoor field with subtle wind, visible shadows on ground.\n"
        "    Detail: capture posture lines, hair flutter, layered fabric motion.\n"
        "    *Note: cinematic references must be interpreted within each platform’s current capabilities.*\n"
        "}"
    )

    # — Variant 3: Studio setup + stylized rim light + static —
    variants.append(
        f"> {{\n"
        f"    {base.strip().capitalize()}.\n"
        "    Lighting: beauty dish at 30° right, rim light at 120° left, high contrast.\n"
        "    Lens: 50mm f/2.0, mid-depth DoF.\n"
        "    Camera: [static shot].\n"
        "    Environment: controlled studio, gray seamless paper, low-key fill.\n"
        "    Detail: emphasis on symmetry, pose transitions, crisp facial features.\n"
        "    *Note: cinematic references must be interpreted within each platform’s current capabilities.*\n"
        "}"
    )

    return variants


# -----------------------------------------------------------------------------
# Module 2: evaluate_realism
# -----------------------------------------------------------------------------
def evaluate_realism(prompt: str) -> tuple[int, str]:
    """Assign a success probability and explanation for cinematic realism."""
    score = 100
    notes: list[str] = []

    # Penalty: multiple simultaneous movements
    if prompt.count("[") > 1 and "," in prompt.split("[")[1]:
        score -= 8
        notes.append("Complex movement combo may reduce realism on Sora or Hailuo.")

    # Penalty: very shallow DoF with moving subject
    if "f/1.4" in prompt and ("tracking" in prompt or "push in" in prompt):
        score -= 6
        notes.append("Shallow DoF with motion may blur subject detail.")

    # Bonus: static + Deakins-style lighting
    if "[static shot]" in prompt and "golden-hour" in prompt:
        score += 4
        notes.append("Static frame with Deakins lighting is highly realistic.")

    # Penalty: overly detailed microfeatures with fast camera
    if "microexpression" in prompt and ("handheld" in prompt or "dolly" in prompt):
        score -= 5
        notes.append("Camera motion may compromise fidelity of fine facial details.")

    # Bonus: 35mm or 50mm lens in outdoor or studio scene
    if any(lens in prompt for lens in ["35mm", "50mm"]):
        score += 3
        notes.append(
            "Lens choice well-aligned with cinematic norms for this environment."
        )

    # Final adjustment to stay in 0–100 range
    score = max(50, min(score, 99))

    explanation = "; ".join(notes) if notes else "Well-balanced cinematic configuration."
    return score, explanation


# -----------------------------------------------------------------------------
# Module 3: tri_prompt_engine (depends on modules 1 and 2)
# -----------------------------------------------------------------------------
def tri_prompt_engine(subject_description: str) -> dict:
    """Generate and rank three cinematic prompt variants."""
    prompt_variants = generate_prompt_variants(subject_description)
    evaluations = []

    for prompt in prompt_variants:
        realism, notes = evaluate_realism(prompt)
        evaluations.append(
            {
                "prompt": prompt,
                "success": realism,
                "notes": notes,
            }
        )

    evaluations.sort(key=lambda x: x["success"], reverse=True)
    top_prompt = evaluations[0]["prompt"]

    return {
        "ranked_prompts": evaluations,
        "selected": top_prompt,
    }


# -----------------------------------------------------------------------------
# Module 4: fuse_pose_lighting_camera
# -----------------------------------------------------------------------------
def fuse_pose_lighting_camera(
    pose_tag: str,
    lighting_mode: str = "deakins",
    movement_tags: list[str] | None = None,
) -> str:
    """Fuse cinematic prompt from pose, lighting, and camera movement."""
    if movement_tags is None:
        movement_tags = ["push in", "handheld sway"]

    pose_map = {
        "leaning_forward": "Model leans slightly toward the camera, posture engaged and expressive.",
        "crouching": "Model crouches low with poised tension, heels slightly lifted.",
        "sitting_on_heels": "Subject rests neatly on heels, upright spine and soft shoulders.",
        "looking_back_seductively": "Model glances over their shoulder, expression unreadable yet inviting.",
        "arms_crossed": "Arms crossed over chest, gaze forward with determined expression.",
        "hands_in_pockets": "Hands rest casually in pockets, shoulders relaxed, gaze steady.",
        "walking_toward_camera": "Model walks confidently toward the camera, stride measured.",
        "jumping": "Subject in mid-air jump, legs tucked slightly, expression dynamic.",
        "running": "Athlete runs toward camera, full stride and intense focus.",
        "arms_raised": "Arms raised overhead, body stretched, expression triumphant.",
        "sitting_crosslegged": "Model sits cross-legged, back straight, hands resting on knees.",
        "lying_down": "Subject lies on back, arms softly outstretched, gaze upward.",
        "hands_on_hips": "Hands rest on hips, body weight shifted to one leg, confident stance.",
        "kneeling": "Kneels on one or both knees, posture upright, gaze forward.",
        "twisting_shoulder": "Torso twisted, shoulder turned toward camera, gaze over opposite shoulder.",
        "tilted_head": "Head tilted slightly to one side, subtle smile.",
        "looking_up": "Gazes upward with a hopeful expression, chin lifted.",
        "looking_down": "Gazes downward with a contemplative expression.",
        "leaning_back": "Leans back against an invisible surface, arms crossed casually.",
        "bending_sideways": "Torso bends sideways, arm extended along body, dynamic curve.",
        "hands_in_air": "Both hands lifted in the air, fingers splayed, dynamic pose.",
        "resting_chin_on_hand": "Chin rests on hand, elbow on knee or hip, pensive look.",
        "side_profile": "Shows a clean side-profile, head turned exactly 90°, gaze forward.",
        "three_quarter_profile": "Three-quarter angle to camera, revealing facial features and depth.",
        "back_to_camera": "Back facing camera, head turned partially to reveal profile.",
        "over_shoulder_glance": "Glances over shoulder, eyes toward camera, subtle expression.",
        "arms_above_head": "Arms stretched above head, body elongated, expression serene.",
        "backbend": "Performs a backbend with chest open and arms reaching back.",
        "hand_on_knee": "One hand resting on knee, opposite leg bent, casual stance.",
        "hand_on_chest": "Hand placed gently on chest, gaze forward, emotional connection.",
        "hand_on_waist": "Hand on waist, elbow pointed out, confident pose.",
        "crossed_legs_stand": "Stands with legs crossed at ankles, arms relaxed by sides.",
        "splayed_legs": "Stands with legs apart, hands on hips, power stance.",
        "squat": "Performs a low squat, knees bent deeply, eyes focused.",
        "lunge": "Executes a forward lunge, back leg straight, front knee bent.",
        "leg_stretched": "One leg stretched forward, body leaning slightly, dynamic stretch.",
        "bend_forward": "Bends forward at waist, arms hanging toward ground, hair falling.",
        "bend_backward": "Bends backward at waist, arms lifted overhead, open chest.",
        "lean_left": "Leans body to the left, right foot planted firmly, relaxed expression.",
        "lean_right": "Leans body to the right, left foot planted firmly, relaxed expression.",
        "lean_forward_knee": "Leans forward on one knee, opposite leg extended, intensity in eyes.",
        "lunge_forward": "Lunges forward aggressively, torso low, arms braced forward.",
        "hands_on_ground": "Both hands placed on ground, body in plank-like position.",
        "hugging_self": "Arms wrapped around torso, slight lean inward, cozy vibe.",
        "covering_face": "One hand covering part of face, eyes peeking through, mysterious.",
        "shielding_eyes": "Hand raised to forehead to shield eyes, gaze into distance."
    }

    lighting_profiles = {
        "deakins": "natural golden-hour light from 35° camera-left; contrast-rich with diffuse falloff",
        "studio": "softbox key light at 45° right; bounce fill at 135°; soft, controlled shadows",
    }

    lens_choice = "50mm f/2.0" if "studio" in lighting_mode else "85mm f/1.4"
    environment = (
        "sunlit alley with textured walls"
        if lighting_mode == "deakins"
        else "neutral seamless studio backdrop"
    )
    shadow_quality = (
        "feathered, low-intensity"
        if lighting_mode == "studio"
        else "natural hard edge falloff"
    )

    pose_description = pose_map.get(
        pose_tag, "Subject holds a grounded, balanced pose."
    )

    return (
        f"> {{\n"
        f"    {pose_description}\n"
        f"    Lighting: {lighting_profiles[lighting_mode]}.\n"
        f"    Lens: {lens_choice}, shallow depth of field.\n"
        f"    Camera: [{', '.join(movement_tags)}].\n"
        f"    Environment: {environment}.\n"
        f"    Shadow Quality: {shadow_quality}.\n"
        "    Detail: Emphasize skin texture, light-fabric translucency, and posture tension.\n"
        "    *Note: cinematic references must be interpreted within each platform’s current capabilities.*\n"
        "}"
    )


# -----------------------------------------------------------------------------
# Module 5: generate_pose_prompt
# -----------------------------------------------------------------------------
def generate_pose_prompt(pose_tag: str) -> str:
    """Generate a standalone cinematic prompt from a pose tag."""
    pose_lookup = {
        "leaning_forward": (
            "The model leans subtly forward into the frame, posture alert but calm, creating an inviting intensity.",
            "85mm f/1.8, shallow focus",
            "[push in, handheld sway]",
        ),
        "crouching": (
            "The subject crouches low with coiled energy, back slightly arched, eyes steady and engaged.",
            "50mm f/2.0, moderate depth",
            "[arc, dolly left]",
        ),
        "one_knee_up": (
            "The model rests with one knee raised, torso angled to camera, expression open and thoughtful.",
            "35mm f/2.8, deep focus",
            "[pedestal down, zoom in]",
        ),
        "looking_back_seductively": (
            "The subject twists gently, casting a look over their shoulder, with parted lips and soft jawline tension.",
            "85mm f/1.4, shallow focus",
            "[push in]",
        ),
        "sitting_on_heels": (
            "Seated atop their heels, the model’s form is centered, spine aligned, conveying calm poise and stability.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "arms_crossed": (
            "Arms crossed over chest, gaze forward with determined expression.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "hands_in_pockets": (
            "Hands rest casually in pockets, shoulders relaxed, gaze steady.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "walking_toward_camera": (
            "Model walks confidently toward the camera, stride measured.",
            "50mm f/2.0, moderate focus",
            "[tracking shot]",
        ),
        "jumping": (
            "Subject in mid-air jump, legs tucked slightly, expression dynamic.",
            "85mm f/1.8",
            "[push in]",
        ),
        "running": (
            "Athlete runs toward camera, full stride and intense focus.",
            "85mm f/1.8",
            "[tracking shot]",
        ),
        "arms_raised": (
            "Arms raised overhead, body stretched, expression triumphant.",
            "50mm f/2.0",
            "[push in]",
        ),
        "sitting_crosslegged": (
            "Model sits cross-legged, back straight, hands resting on knees.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "lying_down": (
            "Subject lies on back, arms softly outstretched, gaze upward.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "hands_on_hips": (
            "Hands rest on hips, body weight shifted to one leg, confident stance.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "kneeling": (
            "Kneels on one or both knees, posture upright, gaze forward.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "twisting_shoulder": (
            "Torso twisted, shoulder turned toward camera, gaze over opposite shoulder.",
            "85mm f/1.8",
            "[push in]",
        ),
        "tilted_head": (
            "Head tilted slightly to one side, subtle smile.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "looking_up": (
            "Gazes upward with a hopeful expression, chin lifted.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "looking_down": (
            "Gazes downward with a contemplative expression.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "leaning_back": (
            "Leans back against an invisible surface, arms crossed casually.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "bending_sideways": (
            "Torso bends sideways, arm extended along body, dynamic curve.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "hands_in_air": (
            "Both hands lifted in the air, fingers splayed, dynamic pose.",
            "50mm f/2.0",
            "[push in]",
        ),
        "resting_chin_on_hand": (
            "Chin rests on hand, elbow on knee or hip, pensive look.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "side_profile": (
            "Shows a clean side-profile, head turned exactly 90°, gaze forward.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "three_quarter_profile": (
            "Three-quarter angle to camera, revealing facial features and depth.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "back_to_camera": (
            "Back facing camera, head turned partially to reveal profile.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "over_shoulder_glance": (
            "Glances over shoulder, eyes toward camera, subtle expression.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "arms_above_head": (
            "Arms stretched above head, body elongated, expression serene.",
            "50mm f/2.0",
            "[push in]",
        ),
        "backbend": (
            "Performs a backbend with chest open and arms reaching back.",
            "50mm f/2.0",
            "[push in]",
        ),
        "hand_on_knee": (
            "One hand resting on knee, opposite leg bent, casual stance.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "hand_on_chest": (
            "Hand placed gently on chest, gaze forward, emotional connection.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "hand_on_waist": (
            "Hand on waist, elbow pointed out, confident pose.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "crossed_legs_stand": (
            "Stands with legs crossed at ankles, arms relaxed by sides.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "splayed_legs": (
            "Stands with legs apart, hands on hips, power stance.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "squat": (
            "Performs a low squat, knees bent deeply, eyes focused.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "lunge": (
            "Executes a forward lunge, back leg straight, front knee bent.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "leg_stretched": (
            "One leg stretched forward, body leaning slightly, dynamic stretch.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "bend_forward": (
            "Bends forward at waist, arms hanging toward ground, hair falling.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "bend_backward": (
            "Bends backward at waist, arms lifted overhead, open chest.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "lean_left": (
            "Leans body to the left, right foot planted firmly, relaxed expression.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "lean_right": (
            "Leans body to the right, left foot planted firmly, relaxed expression.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "lean_forward_knee": (
            "Leans forward on one knee, opposite leg extended, intensity in eyes.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "lunge_forward": (
            "Lunges forward aggressively, torso low, arms braced forward.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "hands_on_ground": (
            "Both hands placed on ground, body in plank-like position.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "hugging_self": (
            "Arms wrapped around torso, slight lean inward, cozy vibe.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "covering_face": (
            "One hand covering part of face, eyes peeking through, mysterious.",
            "50mm f/2.0",
            "[static shot]",
        ),
        "shielding_eyes": (
            "Hand raised to forehead to shield eyes, gaze into distance.",
            "50mm f/2.0",
            "[static shot]",
        )
    }

    if pose_tag not in pose_lookup:
        return f"Unknown pose tag: '{pose_tag}'. Please choose a valid tag from the dataset."

    description, lens, movement = pose_lookup[pose_tag]

    return (
        f"> {{\n"
        f"    {description}\n"
        f"    Lighting: soft backlight at 120°, with faint warm edge glow.\n"
        f"    Lens: {lens}.\n"
        f"    Camera: {movement}.\n"
        f"    Environment: minimalist neutral background with gentle shadow gradient.\n"
        f"    Detail: Preserve collarbone contour, shadow curvature, and fabric drape.\n"
        f"    *Note: cinematic references must be interpreted within each platform’s current capabilities.*\n"
        f"}}"
    )


# -----------------------------------------------------------------------------
# Module 6: apply_deakins_lighting
# -----------------------------------------------------------------------------
def apply_deakins_lighting(prompt: str) -> str:
    """Augment a cinematic prompt with Deakins-style lighting."""
    deakins_block = (
        "Lighting: golden-hour sunlight piercing from 35° camera-left, casting long shadows with soft core and hard edge.\n"
        "Shadow Quality: layered, directional, with visible ambient falloff.\n"
        "Atmosphere: subtle haze; background underexposed to emphasize midtone structure.\n"
        "Color: natural warmth with desaturated blacks and high contrast in skin zones."
    )

    import re

    updated = re.sub(r"(?i)(Lighting:.*?)\n", "", prompt)
    updated = re.sub(r"(?i)(Shadow Quality:.*?)\n", "", updated)

    return f"{updated.strip()}\n{deakins_block.strip()}\n*Note: Deakins lighting augmentation applied for cinematic realism.*"


# -----------------------------------------------------------------------------
# Module 7: prompt_orchestrator
# -----------------------------------------------------------------------------
def prompt_orchestrator(
    pose_tag: str | None = None,
    subject_description: str | None = None,
    use_deakins: bool = False,
) -> dict:
    """Master orchestration for cinematic prompt generation."""
    components: list[str] = []
    final = ""

    if pose_tag and not subject_description:
        components.append("pose_prompt")
        final = generate_pose_prompt(pose_tag)
    elif subject_description and not pose_tag:
        components.append("tri_prompt_engine")
        result = tri_prompt_engine(subject_description)
        final = result["selected"]
    elif pose_tag and subject_description:
        components.append("fusion_block")
        final = fuse_pose_lighting_camera(
            pose_tag=pose_tag,
            lighting_mode="deakins" if use_deakins else "studio",
            movement_tags=["arc", "dolly left"] if use_deakins else ["static shot"],
        )

    if use_deakins:
        components.append("deakins_lighting")
        final = apply_deakins_lighting(final)

    return {
        "final_prompt": final.strip(),
        "base_mode": (
            "pose_only"
            if pose_tag and not subject_description
            else (
                "description_only"
                if subject_description and not pose_tag
                else "hybrid_fusion"
            )
        ),
        "components_used": components,
    }


__all__ = [
    "generate_prompt_variants",
    "evaluate_realism",
    "tri_prompt_engine",
    "fuse_pose_lighting_camera",
    "generate_pose_prompt",
    "apply_deakins_lighting",
    "prompt_orchestrator",
    "POSE_TAGS",
]
