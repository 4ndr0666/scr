## 🟦 6. **Expression**

**All allowed values for the Expression parameter:**

| Value                 | Description                                                                                |
| --------------------- | ------------------------------------------------------------------------------------------ |
| `neutral`             | Default: closed mouth, relaxed face, eyes visible                                          |
| *(Animated Sequence)* | May use specific animated expressions as per action/genre (see below)                      |
| *(None)*              | No hidden, occluded, or exaggerated cartoon expressions allowed unless explicitly animated |

**Detailed Rules:**

* **Static images:** Must be `neutral expression` unless action sequence requires otherwise.
* **Animated sequences:** May use controlled expressions (smile, surprise, wink, laugh, sigh, frown, etc.) but should be described explicitly in the action sequence (see Action Sequence parameter).
* **No sunglasses, masks, or facial occlusions permitted.**
* **Prompt usage examples:**

  > "Expression: neutral"
  > "Subject smiles gently, then laughs and returns to neutral expression" (in animated sequence)

**Summary:**

* Use `neutral` for stills.
* If animated, embed the expression in the Action Sequence (e.g., "Subject raises an eyebrow, then smiles warmly").
* *No occlusions or unprompted extreme expressions.*
