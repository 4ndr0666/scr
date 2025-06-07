## ✅ Hailuo/Director Model Prompt Parameter Aggregation

**Below is a comprehensive, source-bound aggregation of all possible parameters, options, and values described in:**

* `Hailuo AI tutorial.pdf`
* `I2V&T2V-01-Director Model Tutorial (with camera movement).pdf`
* **(Also cross-referenced with all session-canonical lists from `promptlib.py` for completeness and deduplication)**

---

### 1. **Subject Reference & Compliance** (`Hailuo AI tutorial.pdf`)

| Parameter            | Description/Rule                                            | Example/Options               |
| -------------------- | ----------------------------------------------------------- | ----------------------------- |
| **Face Count**       | Must be exactly one full, unobstructed face                 | "single subject"              |
| **Facial Lighting**  | Even, diffused (avoid facial shadows)                       | "neutral, soft studio light"  |
| **Image Resolution** | Minimum 512×512 px, maximum 20 MB file size                 | N/A                           |
| **Tags Required**    | Must specify `age_group`, `gender`                          | `adult, male`, `teen, female` |
| **Orientation**      | Frontal or slight 3/4; no extreme side profiles             | "frontal", "3/4 left"         |
| **Expression**       | Neutral (unless animated); no occlusions (e.g., sunglasses) | "neutral expression"          |

---

### 2. **Prompt Structure/Formulae** (`Hailuo AI tutorial.pdf`)

| Level            | Formula Syntax/Instruction                                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------- |
| **Basic**        | `{Subject} {Action/Animation}. {Lighting}. {Camera Movement/Angle}.`                                                |
| **Precise**      | `{Subject} {Action Sequence}, {Facial Lighting}, {Lens}, {Camera Movement}, {Background}, {Detail/Emphasis}`        |
| **Optimization** | Use explicit lens/camera movement. Describe *micro-details* (“skin pores”, “fabric weave”). Control all parameters. |

---

### 3. **Camera Movement Tags & Syntax** (`I2V&T2V-01-Director Model Tutorial`, `camera_movements.pdf`)

#### **Canonical Camera Movement Tag Table**

**All tags are enclosed in square brackets `[ ... ]` for prompt compliance.**

| Tag                   | Description                           | Can Combine/Sequence? | Example                               |
| --------------------- | ------------------------------------- | --------------------- | ------------------------------------- |
| `[push in]`           | Move camera toward subject (dolly in) | ✔                     | `[push in]A lamb stands in the snow.` |
| `[pull out]`          | Move away from subject                | ✔                     |                                       |
| `[pan left]`          | Horizontal pivot (left)               | ✔                     |                                       |
| `[pan right]`         | Horizontal pivot (right)              | ✔                     |                                       |
| `[tilt up]`           | Vertical pivot (up)                   | ✔                     |                                       |
| `[tilt down]`         | Vertical pivot (down)                 | ✔                     |                                       |
| `[truck left]`        | Slide camera left (lateral move)      | ✔                     |                                       |
| `[truck right]`       | Slide camera right                    | ✔                     |                                       |
| `[pedestal up]`       | Raise camera vertically               | ✔                     |                                       |
| `[pedestal down]`     | Lower camera vertically               | ✔                     |                                       |
| `[zoom in]`           | Focal length increases (tightens)     | ✔                     |                                       |
| `[zoom out]`          | Focal length decreases (widens)       | ✔                     |                                       |
| `[tracking shot]`     | Camera follows subject                | ✔                     |                                       |
| `[static shot]`       | Camera remains fixed                  |                       |                                       |
| `[handheld]`          | Simulates organic movement            |                       |                                       |
| `[arc]`               | Semicircular/circular movement        |                       |                                       |
| `[crane]` / `[jib]`   | Sweeping vertical/horizontal arc      |                       |                                       |
| `[steadicam]`         | Ultra-smooth, stabilized tracking     |                       |                                       |
| `[dolly]`             | Forward/backward move (not zoom)      |                       |                                       |
| `[whip pan]`          | Fast horizontal pan                   |                       |                                       |
| `[roll]`              | Rotate camera axis (Dutch angle)      |                       |                                       |
| `[bird’s eye view]`   | Directly overhead                     |                       |                                       |
| `[over-the-shoulder]` | Behind/above character                |                       |                                       |

#### **Preset Combos** (for circling, walking, stage, scenic, tilt, etc.)

| Name                   | Tag Combination                          |
| ---------------------- | ---------------------------------------- |
| Left circling shot     | `[truck left, pan right, tracking shot]` |
| Right circling shot    | `[truck right, pan left, tracking shot]` |
| Left walking shot      | `[truck left, tracking shot]`            |
| Right walking shot     | `[truck right, tracking shot]`           |
| Upward tilt/push       | `[push in, pedestal up]`                 |
| Scenic shot (lat+vert) | `[truck left, pedestal up]`              |
| Stage shot right       | `[pan right, zoom in]`                   |
| Stage shot left        | `[pan left, zoom in]`                    |
| Downward tilt          | `[pedestal down, tilt up]`               |

**→ Tags can be sequenced:**
Example: `A man picks up a book [pedestal up], then begins reading it [static].`

---

### 4. **Camera Shot/Framing Types** (`camera_movements.pdf`, `camera_settings.md`)

| Name                | Description                      |
| ------------------- | -------------------------------- |
| Close-Up (CU)       | Face/detail, max intimacy        |
| Medium Shot (MS)    | Waist-up, balance context/detail |
| Wide Shot (WS)      | Subject in full environment      |
| High Angle Shot     | Camera looks down on subject     |
| Low Angle Shot      | Camera looks up at subject       |
| Bird’s Eye View     | Directly overhead                |
| Dutch Angle         | Tilted for tension               |
| Over-the-Shoulder   | Behind-subject/POV framing       |
| Macro/Extreme CU    | Ultra-tight (skin, eye, detail)  |
| Three-Quarter Angle | Slightly turned for depth        |

---

### 5. **Lighting Styles & Profiles** (`photography.md`, `camera_settings.md`, `promptlib.py`)

| Name/Tag                | Description/Config                                                |
| ----------------------- | ----------------------------------------------------------------- |
| Golden-hour sunlight    | 35° camera-left, warm haze                                        |
| Rembrandt               | Key at 45° camera-left, triangle shadow, soft fill opposite       |
| Butterfly               | Key overhead, soft fill under nose, minimal shadows               |
| Softbox 45/135          | Key at 45° camera-right, bounce at 135° camera-left, soft shadows |
| Beauty dish             | Key at 30° camera-right, rim at 120° left, crisp highlights       |
| Ring light              | Frontal, minimal shadow                                           |
| High-key studio strobes | Soft shadow control                                               |
| Three-point             | Key at 45°, fill, back/hair light                                 |
| Natural window light    | From left, soft fill from right                                   |
| Hard sun                | 35° camera-left, high contrast, silver bounce 45° right           |
| Profoto                 | Beauty dish at 30° right, 2 strip softboxes at 90° sides          |
| Practical headlight     | Car headlight back-rim, 6500K LED key 60° camera-right            |
| Diffused skylight       | Bounce fill at 45°, airy, soft edges                              |
| Continuous LED          | Heavy diffusion, frontal                                          |

---

### 6. **Lens & DoF Options** (`photography.md`, `camera_settings.md`, `promptlib.py`)

| Lens                 | Spec                          | Depth of Field |
| -------------------- | ----------------------------- | -------------- |
| 35mm f/2.8           | Wide, deep focus              | Deep           |
| 50mm f/1.4           | Standard prime, very shallow  | Shallow        |
| 50mm f/2.0           | Standard prime, moderate      | Moderate       |
| 85mm f/1.4, f/1.8    | Telephoto portrait, shallow   | Shallow        |
| 100mm macro f/2.8    | Extreme CU, shallow           | Shallow        |
| 90mm f/4             | Moderate telephoto, mid-depth | Medium         |
| 40mm anamorphic T2.2 | Cinematic squeeze, shallow    | Shallow        |
| 100mm macro f/5.6    | Fine detail, medium DoF       | Medium         |

---

### 7. **Action Sequence Genres & Examples** (`Hailuo AI tutorial.pdf`, `promptlib.py`)

**(All can be used for subject motion/action blocks)**

| Genre        | Example Action Sequences                                                |
| ------------ | ----------------------------------------------------------------------- |
| General      | Walks, waves, sits, crouches, jumps, spins, stretches, turns, etc.      |
| Expressive   | Smiles, laughs, raises eyebrow, winks, shrugs, sighs                    |
| Fashion      | Runway poses, spins, arms on hips, hands on head, leans, walks runway   |
| Sports       | Sprints, squats, stretches, jumps, victory poses                        |
| Corporate    | Adjusts collar, gestures, nods, presents product, folds arms, points    |
| Cinematic    | Pauses, looks around, reacts with emotion, sighs, leans in, claps, bows |
| Fantasy      | Draws sword, leaps, casts spell, kneels, salutes, points                |
| Horror       | Turns in fear, covers mouth, shivers, disappears, steps backward        |
| Romance      | Blows kiss, smiles, hugs, draws heart, leans in, looks shy              |
| Documentary  | Reads, walks, checks watch, drinks coffee, rides bicycle                |
| Dance        | Spins, claps, bows, sways, leaps, jazz hands                            |
| Animation    | Jumps, spins, waves, falls, dances, claps, skips, puppy runs            |
| Environment  | Stands in wind/rain/fog, twirls umbrella, squints in sun                |
| Group        | Walks together, laughs, high-fives, shakes hands, turns, walks away     |
| Professional | Presents, points at chart, gestures, speaks, introduces, bows           |

---

### 8. **Pose Tags & Descriptions** (Summarized; full list in session)

* **leaning\_forward**: The model leans subtly forward, alert but calm.
* **crouching**: Low, coiled energy, back slightly arched.
* **one\_knee\_up**: One knee raised, torso angled, thoughtful.
* **looking\_back\_seductively**: Over-shoulder, lips parted, soft jaw.
* **sitting\_on\_heels**: Centered, poised, spine aligned.
* **arms\_crossed**, **hands\_in\_pockets**, **walking\_toward\_camera**, **jumping**, **running**…
  *(Full list available via `promptlib.py`'s `POSE_TAGS` and `POSE_DESCRIPTIONS`.)*

---

### 9. **Background/Environment Options**

| Option                                  | Example Use           |
| --------------------------------------- | --------------------- |
| Neutral seamless studio backdrop        | Most default shots    |
| Sunlit alley with textured walls        | Outdoor, street style |
| Night road with reflective puddles/mist | Night scenes          |
| White cyclorama studio                  | High-key, fashion     |
| Loft studio, window light               | Editorial, natural    |
| Minimalist gradient, gray, or white     | Beauty/fashion        |
| Café, dark industrial set               | Contextual shots      |

---

### 10. **Shadow Quality**

| Option                      | Description                    |
| --------------------------- | ------------------------------ |
| Soft, gradual edges         | For beauty, fashion, portrait  |
| Hard edge falloff           | Dramatic, high-contrast scenes |
| Feathered, low-intensity    | Subtle, editorial lighting     |
| Layered directional/ambient | Cinematic, Deakins style       |
| Minimal/very soft           | Macro, skin detail             |
| Moody hard rim              | For rim-lit effects            |

---

### 11. **Detail/Micro-Emphasis**

| Option                               | Example Application        |
| ------------------------------------ | -------------------------- |
| Skin pore texture, catchlights       | Beauty, macro, CU          |
| Fabric weave, motion creases         | Fashion, textile, movement |
| Hair strand movement in wind         | Environmental              |
| Microexpression, eyelash detail      | Portrait, emotional shots  |
| Jewelry sparkle, specular highlights | Fashion, accessories       |
| Bead of sweat highlights, skin sheen | Sports, high energy        |
| Denim/leather surfaces, dust in rays | Editorial, atmospheric     |

---

### 12. **Policy/Prohibited Terms** (for strict compliance)

* **Forbidden:** sexual, porn, gore, torture, rape, beheading, extremist, hate, terror, celebrity, trademark, copyright, threat, defamation, harassment, self-harm, medical advice

---

## **Tables: Parameter Values for Prompt Construction**

### **A. Subject Reference & Tags**

| Field       | Allowed Values / Notes           |
| ----------- | -------------------------------- |
| Age Group   | adult, teen, child, elderly      |
| Gender      | male, female, neutral            |
| Face Count  | 1 (must be unobstructed)         |
| Orientation | frontal, 3/4 left, 3/4 right     |
| Expression  | neutral (unless action sequence) |

---

### **B. Camera Movements**

| Tag                 | Description                        | Combine/Sequence |
| ------------------- | ---------------------------------- | ---------------- |
| See section 3 above | All canonical tags (with brackets) | ✔                |

---

### **C. Camera Shot Types**

| Shot Type     | Description                 |
| ------------- | --------------------------- |
| See section 4 | All canonical framing types |

---

### **D. Lighting Options**

| Name/Tag      | Configuration/Description |
| ------------- | ------------------------- |
| See section 5 | Full lighting setup list  |

---

### **E. Lens/DoF**

| Lens/Setting  | Description                  |
| ------------- | ---------------------------- |
| See section 6 | All standard primes & macros |

---

### **F. Action Sequence Genres**

| Genre         | Example Sequence   |
| ------------- | ------------------ |
| See section 7 | Full canonical map |

---

### **G. Pose Tags**

| Tag/Name      | Short Description                     |
| ------------- | ------------------------------------- |
| See section 8 | Use POSE\_TAGS and POSE\_DESCRIPTIONS |

---

### **H. Background/Environment**

| Option        | Description                     |
| ------------- | ------------------------------- |
| See section 9 | All main backdrops/environments |

---

### **I. Shadow Quality**

| Option         | Description                |
| -------------- | -------------------------- |
| See section 10 | For micro-contrast or mood |

---

### **J. Detail Emphasis**

| Option         | Description                         |
| -------------- | ----------------------------------- |
| See section 11 | Micro-details, skin, fabric, motion |

---

### **K. Prohibited Terms**

| Forbidden      | Reason/Enforcement              |
| -------------- | ------------------------------- |
| See section 12 | Strict filtering in all prompts |

---

### **L. Prompt Formula/Template (for API/UI use)**

```plaintext
> {
    Subject: [description, e.g., 'adult female, frontal, neutral expression'].
    Age: [age group]; Gender: [gender].
    Action Sequence: [detailed animation/movement, from genre list].
    Lighting: [profile, e.g., 'Rembrandt key light at 45° camera-left...'].
    Lens: [choice, e.g., '85mm f/1.4, shallow DoF'].
    Camera: [[movement tags in brackets, comma-separated]].
    Environment: [background, e.g., 'neutral seamless studio backdrop'].
    Detail: [micro-detail, e.g., 'Preserve skin pore texture and catchlights'].
    Reference: single unobstructed face, neutral expression unless animated, even facial lighting, minimum 512×512 px, maximum 20 MB file size.
    *Note: Strict Hailuo/Director model compliance: animated subject, subject-reference enforced, all camera moves in brackets, all tags explicit.*
}
```

---

**All values above are directly canonical for Hailuo/Director prompt creation.**
If you need CSV, JSON, or shell-parsable versions of any table, request format.
If you need **all possible values for a single parameter (e.g., all camera movements, all lighting options, all action genres),** specify and I’ll produce an explicit export.
