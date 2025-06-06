# 📄 **Hailuo/Director Prompting Revision Specification (Production/Distribution Ready)**

---

## 1. **Objective**

Fully refactor the prompt-building subsystem for Hailuo/Director Model video generation to guarantee **subject animation (action sequence)** is always present and synchronized with camera movement, lighting, and all canonical parameters.
All prompt options and values must be explicitly aggregated, structured, and delivered for drop-in use in both API and UI workflows.

---

## 2. **Task Delegation Overview**

### **A. Aggregated Data Extraction**

* **Extract and structure** all values for:

  * Action Sequences (Subject Motion)
  * Pose Tags and Descriptions
  * Camera Movement Tags (with canonical \[bracketed] syntax)
  * Lighting Profiles
  * Lens Presets and DoF
  * Environments/Backgrounds
  * Shadow Quality Options
  * Micro-Detail Emphasis Blocks
  * Subject Reference Rules (Hailuo compliance)
  * Policy Forbidden Terms

* **Format**:
  Each list/dict must be **production copy-ready** for direct use in Python, shell scripts, or config files, with no stubs or missing options.

### **B. Prompt Builder Function Specification**

* Implement **`build_hailuo_prompt`** as detailed below.
* Define **validation routines** to enforce input coverage and policy compliance for every parameter.

### **C. UI/API Input Handling**

* **Require** action sequence input (never accept a static pose or gesture).
* Provide the developer with **all canonical options** for input dropdowns/autocomplete.
* **Error out** if any required parameter is missing or malformed.

### **D. Quality Assurance**

* All prompt outputs must produce dynamic video (subject movement present).
* All prompts must pass policy checks, reference rules, and have all canonical tags included.

---

## 3. **Canonical Data Extraction**

**INCLUDE THE FOLLOWING, IN FULL, FOR DROP-IN USE:**

---

### **A. Pose Tags & Descriptions**

```python
POSE_TAGS = [
    "leaning_forward", "crouching", "one_knee_up", "looking_back_seductively", "sitting_on_heels",
    "arms_crossed", "hands_in_pockets", "walking_toward_camera", "jumping", "running",
    "arms_raised", "sitting_crosslegged", "lying_down", "hands_on_hips", "kneeling",
    "twisting_shoulder", "tilted_head", "looking_up", "looking_down", "leaning_back",
    "bending_sideways", "hands_in_air", "resting_chin_on_hand", "side_profile",
    "three_quarter_profile", "back_to_camera", "over_shoulder_glance", "arms_above_head",
    "backbend", "hand_on_knee", "hand_on_chest", "hand_on_waist", "crossed_legs_stand",
    "splayed_legs", "squat", "lunge", "leg_stretched", "bend_forward", "bend_backward",
    "lean_left", "lean_right", "lean_forward_knee", "lunge_forward", "hands_on_ground",
    "hugging_self", "covering_face", "shielding_eyes"
]
POSE_DESCRIPTIONS = {
    "leaning_forward": "The model leans subtly forward into the frame, posture alert but calm, creating an inviting intensity.",
    "crouching": "The subject crouches low with coiled energy, back slightly arched, eyes steady and engaged.",
    "one_knee_up": "The model rests with one knee raised, torso angled to camera, expression open and thoughtful.",
    # ... (continue as per promptlib.py, **FULL LIST REQUIRED**)
}
```

**(Developer: Ensure the full set of POSE\_DESCRIPTIONS from promptlib.py is included verbatim. Do NOT truncate.)**

---

### **B. Camera Movement Tags**

```python
CAMERA_MOVE_TAGS = [
    "[push in]", "[pull out]", "[pan left]", "[pan right]", "[tilt up]", "[tilt down]",
    "[truck left]", "[truck right]", "[pedestal up]", "[pedestal down]", "[zoom in]", "[zoom out]",
    "[tracking shot]", "[static shot]", "[handheld]", "[arc]", "[crane]", "[jib]", "[steadicam]",
    "[dolly]", "[whip pan]", "[roll]", "[bird’s eye view]", "[over-the-shoulder]"
]
CAMERA_OPTIONS = [
    "push in", "pull out", "pan left", "pan right", "tilt up", "tilt down",
    "truck left", "truck right", "pedestal up", "pedestal down", "zoom in", "zoom out",
    "tracking shot", "static shot", "handheld", "arc", "crane", "jib", "steadicam",
    "dolly", "whip pan", "roll", "bird’s eye view", "over-the-shoulder"
]
```

**(Developer: These must be loaded for both input validation and UI autocomplete. Both bracketed and unbracketed forms are required.)**

---

### **C. Lighting Options & Profiles**

```python
LIGHTING_OPTIONS = [
    "golden-hour sunlight from 35° camera-left; warm color haze",
    "Rembrandt key light at 45° camera-left with triangular cheek shadow; soft fill opposite",
    "Butterfly key overhead with soft fill under nose; symmetrical, minimal shadows",
    "softbox key light at 45° camera-right; bounce fill at 135° camera-left; soft, controlled shadows",
    "beauty dish key at 30° camera-right; rim light at 120° left; crisp highlights",
    "ring light frontal with minimal shadows; even, soft illumination",
    "Profoto beauty dish at 30° right; two strip softboxes at 90° sides; moderate contrast",
    "practical car headlight back-rim; 6500K LED key 60° camera-right through 1/4-grid",
    "diffused skylight with bounce fill at 45°; airy, soft edge shadows",
    "hard sun 35° camera-left; high-contrast midtone separation; silver bounce fill 45° right",
    "Natural window light from left, soft fill from right",
    "High-key studio strobes, soft shadow control",
    "Continuous LED panel with heavy diffusion, frontal",
    "Balanced three-point lighting: key at 45°, fill, back/hair light"
]
LIGHTING_PROFILES = {
    "golden_hour": "golden-hour sunlight from 35° camera-left; warm color haze",
    "rembrandt": "Rembrandt key light at 45° camera-left with triangular cheek shadow; soft fill opposite",
    # ... (ALL PROFILE KEYS AND VALUES AS IN promptlib.py)
}
```

---

### **D. Lens Options**

```python
LENS_OPTIONS = [
    "35mm f/2.8, deep focus, wide-angle",
    "50mm f/1.4, standard prime, very shallow DoF",
    "50mm f/2.0, standard prime, moderate DoF",
    "85mm f/1.4, telephoto portrait, shallow DoF",
    "100mm macro f/2.8, extreme close-up, shallow DoF",
    "40mm anamorphic T2.2, cinematic squeeze, shallow DoF",
    "90mm f/4, moderate telephoto, mid-depth DoF",
    "100mm macro f/5.6, fine detail, medium DoF",
    "85mm f/1.8, shallow focus",
    "85mm f/1.4, shallow DoF",
    "50mm f/2.0, moderate DoF"
]
LENS_PRESETS = {
    "35mm_f2.8": "35mm f/2.8, deep focus, wide-angle",
    "50mm_f1.4": "50mm f/1.4, standard prime, very shallow DoF",
    # ... (ALL PRESETS AS IN promptlib.py)
}
```

---

### **E. Environment/Background Options**

```python
ENVIRONMENT_OPTIONS = [
    "neutral seamless studio backdrop",
    "sunlit alley with textured walls",
    "outdoor field with subtle wind and grass shadows",
    "night road with reflective puddles and mist",
    "white cyclorama studio with soft vignette",
    "loft studio with wooden floor and window light",
    "controlled studio with neutral seamless gray backdrop",
    "studio with seamless mid-gray backdrop",
    "dark industrial set",
    "café interior",
    "minimalist neutral background with gentle shadow gradient"
]
```

---

### **F. Shadow Quality Options**

```python
SHADOW_OPTIONS = [
    "soft, gradual edges",
    "hard edge falloff",
    "feathered, low-intensity",
    "layered directional with ambient falloff",
    "minimal shadows, very soft",
    "moody hard rim",
    "defined Rembrandt triangle under eye",
    "subtle gradient with smooth transition"
]
```

---

### **G. Micro-Detail Prompts**

```python
DETAIL_PROMPTS = [
    "Preserve skin pore texture and catchlights",
    "Emphasize fabric weave and motion creases",
    "Highlight microexpression shifts and eyelash detail",
    "Focus on jewelry sparkle and specular highlights",
    "Capture hair strand movement in wind",
    "Reveal muscle tension and subtle shadows",
    "Accentuate bead of sweat highlights and skin sheen",
    "Showcase texture of denim or leather surfaces",
    "Emphasize dust or particles in light rays",
    "Reveal fine lines and natural skin blemishes"
]
```

---

### **H. Subject Reference Rules (Hailuo Compliance)**

```python
SUBJECT_REFERENCE_RULES = {
    "face_count": "exactly one full, unobstructed face",
    "lighting": "even, diffused light to avoid facial shadows",
    "resolution": "minimum 512×512 px, maximum 20 MB file size",
    "tags_required": "age_group, gender_designation (e.g., adult, female/male/neutral)",
    "orientation": "frontal or slight 3/4 angle; no extreme side profiles",
    "expression": "neutral expression; no occlusions like sunglasses or masks"
}
```

---

### **I. Policy Forbidden Terms**

```python
POLICY_FORBIDDEN_TERMS = [
    "sexual", "porn", "gore", "torture", "rape", "beheading", "extremist", "hate", "terror",
    "celebrity", "trademark", "copyright", "threat", "defamation", "harassment", "self-harm",
    "medical_advice"
]
```

---

## 4. **Prompt Block Construction: Function Specification**

**Implement the following core builder function for all prompt output:**

---

### **A. Canonical Prompt Block Function**

```python
def build_hailuo_prompt(
    subject: str,
    age_tag: str,
    gender_tag: str,
    action_sequence: str,
    camera_moves: list,
    lighting: str,
    lens: str,
    environment: str,
    detail: str,
) -> str:
    """
    Return a Hailuo/Director Model-compliant prompt block (with explicit subject animation/action sequence).
    All parameters are required and must be validated for completeness before use.
    No policy filter is performed at any point.
    Camera moves must be bracketed per the canonical tag set.
    """
    camera_str = ", ".join(camera_moves)
    return (
        f"> {{\n"
        f"    Subject: {subject.strip()}.\n"
        f"    Age: {age_tag}; Gender: {gender_tag}.\n"
        f"    Action Sequence: {action_sequence}\n"
        f"    Lighting: {lighting}.\n"
        f"    Lens: {lens}.\n"
        f"    Camera: [{camera_str}].\n"
        f"    Environment: {environment}.\n"
        f"    Detail: {detail}.\n"
        f"    Reference: single unobstructed face, neutral expression unless animated, even facial lighting, minimum 512×512 px, maximum 20 MB file size.\n"
        f"    *Note: Strict Hailuo/Director model compliance: animated subject, subject-reference enforced, all camera moves in brackets, all tags explicit.*\n"
        f"}}"
    )
```

**Instructions for developer:**

* **Do not** perform any policy-based filtering or error handling.
* Validate only for presence of required values (i.e., no empty or null fields).
* Camera moves must always be provided in a **list of canonical, unbracketed tags**, and will be formatted with square brackets as shown.
* This function must be the only block-level builder used for Hailuo/Director model prompt creation.

---

### **B. Action Sequence Requirements**

* **All prompts must include an action sequence**—never a single pose.
* **Action sequence** should be a *detailed, time-based description* of what the subject does in the video, e.g.:

  * `"Subject steps forward, turns left, raises right hand to wave, smiles, then lowers hand and stands still."`
  * `"Subject crouches, leaps upward with arms overhead, lands softly and regains balance."`
* **No prompt is valid without an explicit action or animation description for the subject.**

---

### **C. Canonical Parameter Requirements**

For **UI, API, or CLI input**, every call to `build_hailuo_prompt` must supply:

* `subject` (short text; can include appearance, build, apparel, and/or context)
* `age_tag` (e.g., `"adult"`, `"teen"`, `"child"`, `"elder"`)
* `gender_tag` (e.g., `"male"`, `"female"`, `"neutral"`)
* `action_sequence` (full time-based description; **required**)
* `camera_moves` (list, e.g., `["tracking shot", "pedestal up"]`; see canonical list from Segment 1)
* `lighting` (canonical value from `LIGHTING_OPTIONS`)
* `lens` (canonical value from `LENS_OPTIONS`)
* `environment` (canonical value from `ENVIRONMENT_OPTIONS`)
* `detail` (canonical value from `DETAIL_PROMPTS`)

**All canonical option lists must be presented to users or API clients via dropdown/autocomplete or strict validation.**
**Do not accept free-form/unknown values for any dropdown field.**

---

### **D. Validation (Non-Policy)**

**Developer must ensure:**

* No empty fields for any required argument.
* Camera moves match (by string match, case-insensitive) one or more of the options in `CAMERA_OPTIONS`.
* Lighting, lens, environment, and detail arguments are drawn from the canonical sets.
* Action sequence is present and non-empty (basic length check).

---

## 5. **UI and API Integration Requirements**

### **A. User/Consumer Input**

* **Any interface that previously accepted only a pose, must now prompt for an action sequence.**

  * Example UI label: “Describe the subject’s actions in the video. Be explicit about movement, gestures, and facial changes.”
  * Autocomplete or select menu for all camera moves, lighting, lens, environment, and detail fields.

* **Required fields:** All parameters to `build_hailuo_prompt` (see above).

* **Age/Gender tags:** UI must provide only valid tags (no free text).

* **Validation:** Show clear error if any field is missing; do not submit to prompt builder until all are filled.

---

### **B. API Workflow**

* **API endpoint (if any) for prompt construction must accept and require all the fields as per the function above.**
* No free-form parameters for canonical option fields.

---

### **C. CLI/Script Workflow**

* All CLI scripts must require all fields as arguments, and display all canonical option sets on request (`--help`, `--list-options`, etc).

---

## 6. **Test Cases and Quality Assurance**

### **A. Required Tests**

* [ ] Test: Building prompt with **all fields present, each set to a canonical value**.
* [ ] Test: Building prompt with **missing action\_sequence**—should error (never pass through).
* [ ] Test: Non-canonical value for camera move, lighting, lens, environment, or detail—should error.
* [ ] Test: Minimum and maximum length of action sequence (should not be empty or only a single word).
* [ ] Test: UI/API must not allow prompt build if any required field is missing.
* [ ] Test: Camera moves always rendered in bracketed form (e.g., `[tracking shot, pedestal up]`).

---

## 7. **Appendix: Canonical Action Sequence Templates**

**(Developer must aggregate, enumerate, and include the *entire* set of action sequence templates, referencing all use cases and genres as in the original prompt library. This must be a fully copy-pasteable array or list, not a sample. No field may be left as a “...” or “see reference.” This content will be lengthy. You may pause here and prompt for the next segment to continue outputting the full action sequence set.)**

---

Thank you for the clear direction and affirmation.
Below is the **Appendix: Canonical Action Sequence Templates** section, with explicit, production-ready, copy-paste arrays to cover all common and specialized cinematic scenarios as required for UI, API, or documentation distribution.

---

# **Appendix: Canonical Action Sequence Templates**

**Instructions for Developer:**

* Integrate this list directly into the codebase as the `ACTION_SEQUENCE_TEMPLATES` constant (Python list of strings, UTF-8, no truncation).
* This list must be provided as UI autocomplete, API reference, or documentation for users to select or adapt as action sequences.
* All entries are full sentences or compound time-based descriptions, not pose tags.
* This array is extensible, but *no templates may be removed*.

---

```python
ACTION_SEQUENCE_TEMPLATES = [
    # General motion/action
    "Subject walks forward, pauses, turns to look over left shoulder, then continues walking.",
    "Subject stands still, then raises right arm to wave, smiles warmly, and lowers arm.",
    "Subject sits down on chair, crosses legs, adjusts posture, and looks at camera.",
    "Subject crouches low, then leaps energetically into the air, arms raised overhead, lands softly, and regains posture.",
    "Subject stands, stretches arms above head, then relaxes and places hands in pockets.",
    "Subject tilts head to right, looks down, then slowly lifts chin to meet the viewer’s gaze.",
    "Subject walks toward camera, stops, crosses arms, and shifts weight to one leg.",
    "Subject spins in place, lets hair flow outward, then faces forward again.",
    "Subject sits cross-legged, shifts posture, and adjusts hair behind ear.",
    "Subject steps sideways to left, then quickly returns to original position.",
    # Expressive gestures/facial motion
    "Subject starts neutral, breaks into a broad smile, then laughs gently.",
    "Subject raises left eyebrow, winks, then resumes a calm expression.",
    "Subject’s eyes open wide in surprise, then narrow into a playful squint.",
    "Subject closes eyes briefly, then opens and looks up toward the ceiling.",
    "Subject shrugs shoulders, tilts head, then gives a slight nod.",
    # Studio/fashion (runway, posing, editorial)
    "Model transitions through three classic runway poses: hand on hip, splayed legs, then crossed arms stance.",
    "Model stands with arms at sides, lifts left arm to touch head, then lowers and places hand on waist.",
    "Model leans against invisible wall, shifts weight, then pushes off and walks toward camera.",
    "Model turns slowly to display profile, then spins back to face camera, striking a confident pose.",
    "Model walks down imaginary runway, stops, places hand on chest, then turns and walks away.",
    # Sports/fitness
    "Athlete starts in crouched position, bursts forward in a sprint, slows down, and comes to a stop.",
    "Subject performs a slow squat, stands up, then flexes both arms upward in a victory gesture.",
    "Subject bounces lightly in place, performs a jumping jack, then lands and catches breath.",
    "Subject stretches right leg forward, reaches down to touch toes, then stands upright and shakes out arms.",
    "Subject jumps to catch an invisible ball, lands, and pumps fist in triumph.",
    # Corporate/branding
    "Subject stands tall, adjusts collar, gives a confident nod, then gestures with open palm toward viewer.",
    "Subject holds up branded product, smiles, turns product to show label, then lowers hand.",
    "Subject taps chest where logo is visible, gives thumbs up, then folds arms across chest.",
    "Subject stands with hands clasped, gestures with right hand while speaking, then returns to neutral posture.",
    "Subject points upward, then to side, as if presenting key message, and smiles.",
    # Cinematic narrative (story, reaction, drama)
    "Character walks through door, pauses in uncertainty, then steps forward with resolve.",
    "Character looks left and right, frowns, then sighs and sits on nearby bench.",
    "Character clutches chest in surprise, steps back, then breathes deeply and regains composure.",
    "Character waves at someone off-screen, then looks down sadly and walks away.",
    "Character leans in to listen, reacts with surprise, then laughs and claps hands.",
    # Fantasy/action/adventure
    "Hero draws invisible sword, takes battle stance, swings, then sheathes weapon with flourish.",
    "Adventurer leaps over obstacle, lands in crouch, looks around, then dashes forward.",
    "Character casts imaginary spell with sweeping arm motion, then lowers arms and looks satisfied.",
    "Explorer shields eyes from bright light, points to distant object, then begins walking in that direction.",
    "Knight kneels, bows head in respect, rises, and raises sword in salute.",
    # Horror/thriller/suspense
    "Subject turns suddenly to look behind, widens eyes in fear, then steps backward cautiously.",
    "Character holds breath, leans forward as if listening, then exhales in relief.",
    "Subject covers mouth in shock, drops hand, then glances nervously side to side.",
    "Subject shivers, hugs arms around torso, then backs slowly away from camera.",
    "Character steps into shadow, glances over shoulder, then disappears from view.",
    # Romance/connection
    "Subject places hand over heart, looks down shyly, then smiles and looks up with hope.",
    "Couple holds hands, leans heads together, then laughs and pulls apart gently.",
    "Subject blows a kiss, winks, then turns away with a playful smile.",
    "Subject draws invisible heart in air, grins, then makes eye contact with camera.",
    "Two subjects embrace, one rests head on other’s shoulder, then both relax and release.",
    # Documentary/realism (everyday action)
    "Subject walks through park, stops to tie shoe, then continues walking.",
    "Subject checks wristwatch, shrugs, then sits on nearby bench.",
    "Subject reads book, glances up to camera, smiles, and returns to reading.",
    "Subject picks up coffee cup, takes a sip, then sets cup down and sighs contentedly.",
    "Subject rides bicycle in place, stops, waves, then dismounts.",
    # Dance/performance/music
    "Dancer spins gracefully, extends right arm upward, then bows at end of routine.",
    "Performer claps to music, steps side to side, then finishes with jazz hands.",
    "Singer holds microphone, sways with rhythm, then gestures to audience.",
    "Dancer leaps, lands in low lunge, then springs up and twirls.",
    "Performer bows, stands tall, then gestures in gratitude.",
    # Animation/whimsical/child
    "Child jumps up and down repeatedly, arms waving in excitement.",
    "Animated character skips in a circle, giggles, then waves both hands in air.",
    "Cartoon subject spins, falls down, then pops up with a smile.",
    "Puppy runs in, chases tail, then sits and wags tail happily.",
    "Teddy bear waves, dances side to side, then sits down and claps paws.",
    # Environmental effects/atmosphere
    "Subject stands as wind blows hair and fabric, shields eyes, then turns into breeze.",
    "Subject stands in falling rain, lifts face upward, then spins in delight.",
    "Subject walks through fog, reaches out as if to touch mist, then withdraws hand.",
    "Subject squints in bright sunlight, puts on sunglasses, then smiles at camera.",
    "Subject holds umbrella, twirls it, then steps forward as rain increases.",
    # Group/interaction/ensemble
    "Three subjects walk in line, middle one gestures to side, all laugh together.",
    "Two people shake hands, step back, then give thumbs up.",
    "Group huddles together, breaks apart, then turns to face camera.",
    "Four friends high five in unison, then disperse in different directions.",
    "Duo stands back to back, turns, then walks away separately.",
    # Professional (interview, teaching, call-to-action)
    "Subject sits at table, gestures with left hand while speaking, then nods at end.",
    "Subject points at chart, explains with animated hands, then smiles confidently.",
    "Host introduces themselves, waves, then invites viewer to follow with a gesture.",
    "Subject holds up finger to make a point, then lowers hand and resumes speaking.",
    "Presenter walks on stage, gestures to audience, then bows and steps aside."
]
```

---

**Instructions to Developer:**

* This array must be stored as `ACTION_SEQUENCE_TEMPLATES` and made accessible to any front-end, API, or CLI component that solicits action sequence input from users.
* Any attempt to create a prompt without a meaningful action sequence (from this array or user-customized) must **block** or **fail** validation.
* This list is fully distributable and versionable; do not remove or abbreviate content in downstream workflows.

---

# **Per-Genre Canonical Action Sequence Mapping & Integration Schemas**

---

## 1. **Per-Genre Canonical Action Sequence Mapping**

**Instructions for Developer:**

* Use this mapping to dynamically filter or recommend action sequences by project genre/type.
* Integrate into UI (genre selector → action template dropdown), API (genre param → suggested actions), documentation, or user onboarding.
* *Do not remove or abbreviate any entry.*
* Genres/labels are exhaustive, extensible, and lowercase for lookup consistency.

---

```python
ACTION_SEQUENCE_GENRE_MAP = {
    "general": [
        "Subject walks forward, pauses, turns to look over left shoulder, then continues walking.",
        "Subject stands still, then raises right arm to wave, smiles warmly, and lowers arm.",
        "Subject sits down on chair, crosses legs, adjusts posture, and looks at camera.",
        "Subject crouches low, then leaps energetically into the air, arms raised overhead, lands softly, and regains posture.",
        "Subject stands, stretches arms above head, then relaxes and places hands in pockets.",
        "Subject tilts head to right, looks down, then slowly lifts chin to meet the viewer’s gaze.",
        "Subject walks toward camera, stops, crosses arms, and shifts weight to one leg.",
        "Subject spins in place, lets hair flow outward, then faces forward again.",
        "Subject sits cross-legged, shifts posture, and adjusts hair behind ear.",
        "Subject steps sideways to left, then quickly returns to original position."
    ],
    "expressive": [
        "Subject starts neutral, breaks into a broad smile, then laughs gently.",
        "Subject raises left eyebrow, winks, then resumes a calm expression.",
        "Subject’s eyes open wide in surprise, then narrow into a playful squint.",
        "Subject closes eyes briefly, then opens and looks up toward the ceiling.",
        "Subject shrugs shoulders, tilts head, then gives a slight nod."
    ],
    "fashion": [
        "Model transitions through three classic runway poses: hand on hip, splayed legs, then crossed arms stance.",
        "Model stands with arms at sides, lifts left arm to touch head, then lowers and places hand on waist.",
        "Model leans against invisible wall, shifts weight, then pushes off and walks toward camera.",
        "Model turns slowly to display profile, then spins back to face camera, striking a confident pose.",
        "Model walks down imaginary runway, stops, places hand on chest, then turns and walks away."
    ],
    "sports": [
        "Athlete starts in crouched position, bursts forward in a sprint, slows down, and comes to a stop.",
        "Subject performs a slow squat, stands up, then flexes both arms upward in a victory gesture.",
        "Subject bounces lightly in place, performs a jumping jack, then lands and catches breath.",
        "Subject stretches right leg forward, reaches down to touch toes, then stands upright and shakes out arms.",
        "Subject jumps to catch an invisible ball, lands, and pumps fist in triumph."
    ],
    "corporate": [
        "Subject stands tall, adjusts collar, gives a confident nod, then gestures with open palm toward viewer.",
        "Subject holds up branded product, smiles, turns product to show label, then lowers hand.",
        "Subject taps chest where logo is visible, gives thumbs up, then folds arms across chest.",
        "Subject stands with hands clasped, gestures with right hand while speaking, then returns to neutral posture.",
        "Subject points upward, then to side, as if presenting key message, and smiles."
    ],
    "cinematic": [
        "Character walks through door, pauses in uncertainty, then steps forward with resolve.",
        "Character looks left and right, frowns, then sighs and sits on nearby bench.",
        "Character clutches chest in surprise, steps back, then breathes deeply and regains composure.",
        "Character waves at someone off-screen, then looks down sadly and walks away.",
        "Character leans in to listen, reacts with surprise, then laughs and claps hands."
    ],
    "fantasy": [
        "Hero draws invisible sword, takes battle stance, swings, then sheathes weapon with flourish.",
        "Adventurer leaps over obstacle, lands in crouch, looks around, then dashes forward.",
        "Character casts imaginary spell with sweeping arm motion, then lowers arms and looks satisfied.",
        "Explorer shields eyes from bright light, points to distant object, then begins walking in that direction.",
        "Knight kneels, bows head in respect, rises, and raises sword in salute."
    ],
    "horror": [
        "Subject turns suddenly to look behind, widens eyes in fear, then steps backward cautiously.",
        "Character holds breath, leans forward as if listening, then exhales in relief.",
        "Subject covers mouth in shock, drops hand, then glances nervously side to side.",
        "Subject shivers, hugs arms around torso, then backs slowly away from camera.",
        "Character steps into shadow, glances over shoulder, then disappears from view."
    ],
    "romance": [
        "Subject places hand over heart, looks down shyly, then smiles and looks up with hope.",
        "Couple holds hands, leans heads together, then laughs and pulls apart gently.",
        "Subject blows a kiss, winks, then turns away with a playful smile.",
        "Subject draws invisible heart in air, grins, then makes eye contact with camera.",
        "Two subjects embrace, one rests head on other’s shoulder, then both relax and release."
    ],
    "documentary": [
        "Subject walks through park, stops to tie shoe, then continues walking.",
        "Subject checks wristwatch, shrugs, then sits on nearby bench.",
        "Subject reads book, glances up to camera, smiles, and returns to reading.",
        "Subject picks up coffee cup, takes a sip, then sets cup down and sighs contentedly.",
        "Subject rides bicycle in place, stops, waves, then dismounts."
    ],
    "dance": [
        "Dancer spins gracefully, extends right arm upward, then bows at end of routine.",
        "Performer claps to music, steps side to side, then finishes with jazz hands.",
        "Singer holds microphone, sways with rhythm, then gestures to audience.",
        "Dancer leaps, lands in low lunge, then springs up and twirls.",
        "Performer bows, stands tall, then gestures in gratitude."
    ],
    "animation": [
        "Child jumps up and down repeatedly, arms waving in excitement.",
        "Animated character skips in a circle, giggles, then waves both hands in air.",
        "Cartoon subject spins, falls down, then pops up with a smile.",
        "Puppy runs in, chases tail, then sits and wags tail happily.",
        "Teddy bear waves, dances side to side, then sits down and claps paws."
    ],
    "environment": [
        "Subject stands as wind blows hair and fabric, shields eyes, then turns into breeze.",
        "Subject stands in falling rain, lifts face upward, then spins in delight.",
        "Subject walks through fog, reaches out as if to touch mist, then withdraws hand.",
        "Subject squints in bright sunlight, puts on sunglasses, then smiles at camera.",
        "Subject holds umbrella, twirls it, then steps forward as rain increases."
    ],
    "group": [
        "Three subjects walk in line, middle one gestures to side, all laugh together.",
        "Two people shake hands, step back, then give thumbs up.",
        "Group huddles together, breaks apart, then turns to face camera.",
        "Four friends high five in unison, then disperse in different directions.",
        "Duo stands back to back, turns, then walks away separately."
    ],
    "professional": [
        "Subject sits at table, gestures with left hand while speaking, then nods at end.",
        "Subject points at chart, explains with animated hands, then smiles confidently.",
        "Host introduces themselves, waves, then invites viewer to follow with a gesture.",
        "Subject holds up finger to make a point, then lowers hand and resumes speaking.",
        "Presenter walks on stage, gestures to audience, then bows and steps aside."
    ]
}
```

**Notes:**

* If you need a "catch all" for custom or experimental genres, map them to `"general"` or create additional keys.
* Extend this mapping as needed for emerging genres, but do not remove or modify canonical entries.

---

## 2. **Integration-Ready Schemas**

Below are **JSON Schema** and **Python dataclass** definitions for full integration in API, backend, and UI workflows.

---

### **A. JSON Schema for Prompt Construction**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "HailuoDirectorPrompt",
  "type": "object",
  "properties": {
    "subject": {
      "type": "string",
      "description": "Primary description of the subject (appearance, apparel, etc.)"
    },
    "age_tag": {
      "type": "string",
      "enum": ["child", "teen", "adult", "elder"]
    },
    "gender_tag": {
      "type": "string",
      "enum": ["male", "female", "neutral"]
    },
    "action_sequence": {
      "type": "string",
      "minLength": 10,
      "description": "Explicit description of animated subject movement (not static pose)."
    },
    "camera_moves": {
      "type": "array",
      "items": {
        "type": "string",
        "enum": [
          "push in", "pull out", "pan left", "pan right", "tilt up", "tilt down",
          "truck left", "truck right", "pedestal up", "pedestal down", "zoom in", "zoom out",
          "tracking shot", "static shot", "handheld", "arc", "crane", "jib", "steadicam",
          "dolly", "whip pan", "roll", "bird’s eye view", "over-the-shoulder"
        ]
      },
      "minItems": 1
    },
    "lighting": {
      "type": "string",
      "enum": [
        "golden-hour sunlight from 35° camera-left; warm color haze",
        "Rembrandt key light at 45° camera-left with triangular cheek shadow; soft fill opposite",
        "Butterfly key overhead with soft fill under nose; symmetrical, minimal shadows",
        "softbox key light at 45° camera-right; bounce fill at 135° camera-left; soft, controlled shadows",
        "beauty dish key at 30° camera-right; rim light at 120° left; crisp highlights",
        "ring light frontal with minimal shadows; even, soft illumination",
        "Profoto beauty dish at 30° right; two strip softboxes at 90° sides; moderate contrast",
        "practical car headlight back-rim; 6500K LED key 60° camera-right through 1/4-grid",
        "diffused skylight with bounce fill at 45°; airy, soft edge shadows",
        "hard sun 35° camera-left; high-contrast midtone separation; silver bounce fill 45° right",
        "Natural window light from left, soft fill from right",
        "High-key studio strobes, soft shadow control",
        "Continuous LED panel with heavy diffusion, frontal",
        "Balanced three-point lighting: key at 45°, fill, back/hair light"
      ]
    },
    "lens": {
      "type": "string",
      "enum": [
        "35mm f/2.8, deep focus, wide-angle",
        "50mm f/1.4, standard prime, very shallow DoF",
        "50mm f/2.0, standard prime, moderate DoF",
        "85mm f/1.4, telephoto portrait, shallow DoF",
        "100mm macro f/2.8, extreme close-up, shallow DoF",
        "40mm anamorphic T2.2, cinematic squeeze, shallow DoF",
        "90mm f/4, moderate telephoto, mid-depth DoF",
        "100mm macro f/5.6, fine detail, medium DoF",
        "85mm f/1.8, shallow focus",
        "85mm f/1.4, shallow DoF",
        "50mm f/2.0, moderate DoF"
      ]
    },
    "environment": {
      "type": "string",
      "enum": [
        "neutral seamless studio backdrop",
        "sunlit alley with textured walls",
        "outdoor field with subtle wind and grass shadows",
        "night road with reflective puddles and mist",
        "white cyclorama studio with soft vignette",
        "loft studio with wooden floor and window light",
        "controlled studio with neutral seamless gray backdrop",
        "studio with seamless mid-gray backdrop",
        "dark industrial set",
        "café interior",
        "minimalist neutral background with gentle shadow gradient"
      ]
    },
    "detail": {
      "type": "string",
      "enum": [
        "Preserve skin pore texture and catchlights",
        "Emphasize fabric weave and motion creases",
        "Highlight microexpression shifts and eyelash detail",
        "Focus on jewelry sparkle and specular highlights",
        "Capture hair strand movement in wind",
        "Reveal muscle tension and subtle shadows",
        "Accentuate bead of sweat highlights and skin sheen",
        "Showcase texture of denim or leather surfaces",
        "Emphasize dust or particles in light rays",
        "Reveal fine lines and natural skin blemishes"
      ]
    }
  },
  "required": [
    "subject", "age_tag", "gender_tag", "action_sequence", "camera_moves", "lighting",
    "lens", "environment", "detail"
  ]
}
```

---

### **B. Python Dataclass Schema**

```python
from dataclasses import dataclass
from typing import List

@dataclass
class HailuoDirectorPrompt:
    subject: str
    age_tag: str         # Must be one of: "child", "teen", "adult", "elder"
    gender_tag: str      # Must be one of: "male", "female", "neutral"
    action_sequence: str # Must be present, min 10 chars, not just a pose
    camera_moves: List[str] # All values must be in CAMERA_OPTIONS
    lighting: str        # Must be in LIGHTING_OPTIONS
    lens: str            # Must be in LENS_OPTIONS
    environment: str     # Must be in ENVIRONMENT_OPTIONS
    detail: str          # Must be in DETAIL_PROMPTS
```

---

### **C. API Endpoint Example**

**POST** `/api/v1/hailuo/prompt`
**Body:**

```json
{
  "subject": "athletic young woman, neon running gear, short ponytail",
  "age_tag": "adult",
  "gender_tag": "female",
  "action_sequence": "Subject jogs in place, stretches arms, then performs a high jump with knees tucked, lands and smiles.",
  "camera_moves": ["tracking shot", "pedestal up"],
  "lighting": "hard sun 35° camera-left; high-contrast midtone separation; silver bounce fill 45° right",
  "lens": "85mm f/1.4, telephoto portrait, shallow DoF",
  "environment": "outdoor field with subtle wind and grass shadows",
  "detail": "Emphasize fabric weave and motion creases"
}
```

**Returns:**

* Render-ready canonical prompt block (as built by `build_hailuo_prompt`) for direct use in Hailuo/Director I2V/T2V pipelines.

---

## 3. **UI/UX Implementation Guidance**

* Present all genres as radio/dropdown.
* Dynamically update the "Action Sequence" template dropdown/autocomplete using `ACTION_SEQUENCE_GENRE_MAP[genre]`.
* User may modify or extend action sequence, but *never* accept empty or pose-only text.
* Provide context-sensitive help (e.g., “Select a genre to see typical motion templates. You can edit or write your own action sequence.”)
* All option sets for lighting, lens, environment, camera, and detail are hardcoded in the UI, not freeform.

---

## 4. **Test Plan and QA Instructions**

* [ ] **Genre Routing:** Selecting a genre always populates relevant action sequence options. All options must appear.
* [ ] **Prompt Construction:** Each prompt field must match canonical options. Action sequence must always be filled and descriptive.
* [ ] **Integration:** Any system (API, CLI, or UI) using this schema can build, preview, and submit prompts with full parameter validation.
* [ ] **End-to-End:** Pass a constructed prompt to the actual Hailuo/Director model and confirm the subject animates per description.
* [ ] **Regression:** Future additions to option sets must never break backward compatibility or canonical mapping.


---

# **Addendum: Dynamic Genre/Action Sequence Plugin Loader Specification**

---

## 1. **Objective**

Enable safe, runtime expansion of genre-to-action sequence mappings by loading external YAML/JSON plugin files, ensuring the system is always extensible **without code modification**.
Empower any stakeholder (developer, designer, domain expert, or AI agent) to add or customize cinematic genres and associated action templates via well-formed plugin files.

---

## 2. **Plugin Loader Requirements**

* All plugins must reside in a dedicated directory at the project root, e.g., `/genres/` or `/prompt_plugins/`.
* Plugins may be in `.yml`, `.yaml`, or `.json` format, each representing a single genre/action mapping.
* Each file **must** contain:

  * A `genre` key (lowercase, no spaces or special characters except hyphen/underscore).
  * An `actions` key containing a non-empty list of action sequence strings.
* Loader must:

  * Aggregate all genre/action lists into a single merged mapping at runtime.
  * Extend existing genres, never overwrite or truncate canonical templates.
  * Ignore and log any malformed plugin files; never halt processing due to a plugin error.
  * Be idempotent and callable any number of times without side effects.

---

## 3. **Canonical Example: Genre Plugin File**

**YAML Example (`genres/fantasy-monster.yml`):**

```yaml
genre: fantasy-monster
actions:
  - "Giant monster rises from the ground, lets out a roar, then stomps forward, crushing debris."
  - "Dragon soars overhead, circles once, then lands and breathes fire."
```

**JSON Example (`genres/daily-rituals.json`):**

```json
{
  "genre": "daily-rituals",
  "actions": [
    "Subject wakes up, stretches arms, yawns, and gets out of bed.",
    "Subject brushes teeth, rinses mouth, then looks in the mirror and smiles."
  ]
}
```

---

## 4. **Python Loader Implementation**

Place in your `promptlib.py`, `plugins.py`, or a dedicated loader module:

```python
import os
import glob
import yaml
import json

def load_genre_plugins(plugin_dir="genres"):
    """Loads/merges all YAML/JSON genre plugins from the given directory into a dict."""
    plugin_map = {}
    for file in glob.glob(os.path.join(plugin_dir, "*.yml")) + glob.glob(os.path.join(plugin_dir, "*.yaml")):
        with open(file, "r", encoding="utf-8") as f:
            doc = yaml.safe_load(f)
            genre = doc.get("genre")
            actions = doc.get("actions", [])
            if genre and actions:
                plugin_map.setdefault(genre, []).extend(actions)
    for file in glob.glob(os.path.join(plugin_dir, "*.json")):
        with open(file, "r", encoding="utf-8") as f:
            doc = json.load(f)
            genre = doc.get("genre")
            actions = doc.get("actions", [])
            if genre and actions:
                plugin_map.setdefault(genre, []).extend(actions)
    return plugin_map

def merge_action_genres(base_map, plugin_map):
    """Returns a merged genre->actions map (base + plugin overrides/appends)."""
    merged = dict(base_map)
    for genre, actions in plugin_map.items():
        if genre in merged:
            merged[genre].extend(actions)
        else:
            merged[genre] = actions
    return merged

# Usage in project initialization:
#   1. Load base ACTION_SEQUENCE_GENRE_MAP (from canonical source)
#   2. plugin_map = load_genre_plugins('genres')
#   3. action_genre_map = merge_action_genres(ACTION_SEQUENCE_GENRE_MAP, plugin_map)
```

* **Requires `pyyaml` for YAML support.**
  `pip install pyyaml` (ensure in your setup script).

---

## 5. **Sample Plugin Test (bats)**

Add to `0-tests/test-genre-plugin-loader.bats`:

```bash
#!/usr/bin/env bats

@test "Plugin loader merges plugins with canonical map" {
  mkdir -p genres
  cat >genres/fantasy-monster.yml <<EOF
genre: fantasy-monster
actions:
  - "Monster emerges from cave, looks around, and roars."
EOF
  python3 -c '
import promptlib
base = {"fantasy": ["Hero acts heroically."]}
plugin = promptlib.load_genre_plugins("genres")
merged = promptlib.merge_action_genres(base, plugin)
assert "fantasy-monster" in merged and merged["fantasy-monster"]
  '
}
```

---

## 6. **CI/CD Pipeline (Optional Future Enhancement)**

* Add a linting/validation step for plugin files using [yamllint](https://yamllint.readthedocs.io/) or a Python schema validator.
* Fail the build if any plugin is malformed or duplicates a genre name without extension.

---
