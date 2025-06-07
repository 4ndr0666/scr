## 🟦 9. **Camera Movement**

**All canonical camera movement tags and combos (must be enclosed in `[ ... ]` for Hailuo/Director compliance):**

### **A. Singular Movement Tags**

| Tag                   | Description                                    |
| --------------------- | ---------------------------------------------- |
| `[push in]`           | Camera moves toward the subject (dolly in)     |
| `[pull out]`          | Camera moves away from the subject (dolly out) |
| `[pan left]`          | Horizontal pivot to the left                   |
| `[pan right]`         | Horizontal pivot to the right                  |
| `[tilt up]`           | Vertical pivot up                              |
| `[tilt down]`         | Vertical pivot down                            |
| `[truck left]`        | Camera slides physically left (lateral move)   |
| `[truck right]`       | Camera slides physically right                 |
| `[pedestal up]`       | Raise camera vertically                        |
| `[pedestal down]`     | Lower camera vertically                        |
| `[zoom in]`           | Increase focal length, tighter on subject      |
| `[zoom out]`          | Decrease focal length, wider view              |
| `[tracking shot]`     | Camera follows subject                         |
| `[static shot]`       | Camera remains fixed                           |
| `[handheld]`          | Simulates organic, unsteady movement           |
| `[arc]`               | Semi-circular or circular movement             |
| `[crane]` / `[jib]`   | Sweeping vertical/horizontal arc               |
| `[steadicam]`         | Ultra-smooth, stabilized tracking              |
| `[dolly]`             | Smooth forward/backward move (not zoom)        |
| `[whip pan]`          | Fast horizontal pan                            |
| `[roll]`              | Rotates camera around lens axis (Dutch angle)  |
| `[bird’s eye view]`   | Directly overhead                              |
| `[over-the-shoulder]` | Behind-character/POV shot                      |

---

### **B. Canonical Combo Tags (Multi-move Sequences)**

| Combo Name          | Tag Combination                          |
| ------------------- | ---------------------------------------- |
| Left circling shot  | `[truck left, pan right, tracking shot]` |
| Right circling shot | `[truck right, pan left, tracking shot]` |
| Left walking shot   | `[truck left, tracking shot]`            |
| Right walking shot  | `[truck right, tracking shot]`           |
| Upward tilt/push    | `[push in, pedestal up]`                 |
| Scenic shot         | `[truck left, pedestal up]`              |
| Stage shot right    | `[pan right, zoom in]`                   |
| Stage shot left     | `[pan left, zoom in]`                    |
| Downward tilt       | `[pedestal down, tilt up]`               |

---

### **C. Usage Notes**

* **Any of the above tags may be combined in comma-separated lists inside square brackets:**
  Example:

  > `Camera: [truck left, pan right, tracking shot].`
* **Sequenced movements can also be written in narrative order:**
  Example:

  > `A man picks up a book [pedestal up], then begins reading it [static].`
