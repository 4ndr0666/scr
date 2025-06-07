# 📄 **Hailuo/Director Prompting Revision & Canonical Integration Work Order (Production/Distribution Ready)**

---

## 1. **Objective**

Deliver a single-source, fully canonical prompt-building system for Hailuo/Director Model video generation.
**Every subject animation, action sequence, camera, lighting, lens, environment, shadow, and detail option is sourced exclusively from:**
`/media/prompt_builder/libraries/hailuo/`
No parameter value or option is permitted outside this directory.

---

## 2. **Current Status: Canonical Data & Loader Complete**

* Canonical **pose, camera movement, lighting, lens, environment, shadow, detail lists** are exhaustive, deduped, and maintained in `promptlib.py` and supporting markdown files for direct API/UI/CLI use.
* The **core builder** (`build_hailuo_prompt`) and field validation logic are enforced in the canonical library.
* **Dynamic plugin loader** is available for runtime genre/action sequence extension via YAML/JSON/Markdown.
* **Hot reload**: All parameter changes (including plugins) are surfaced instantly, no restart required.

---

## 3. **Integration Requirements**

### **A. Loader/Backend Integration**

* Use `canonical_loader.py` as the *exclusive parameter source*:

  * Instantiate:

    ```python
    from canonical_loader import load_canonical_params
    loader = load_canonical_params("/media/prompt_builder/libraries/hailuo/")
    ```
  * Get options for any field:

    ```python
    lighting_options = loader.get_param_options("lighting")
    ```
  * Validate values:

    ```python
    loader.validate_param("camera_move", ["push in", "pedestal up"])
    ```
  * Assemble prompt blocks:

    ```python
    prompt = loader.assemble_prompt_block({...})
    ```

* Loader watches for file changes and reloads all lists automatically.

---

### **B. Prompt Building & Enforcement (API, UI, CLI)**

* **All prompt fields (subject, age, gender, action, pose, camera, lighting, lens, environment, shadow, detail)** must be **selected from loader lists**.
* **No freeform values or “other” allowed** for any canonical parameter.
* **Prompt cannot be built or submitted unless:**

  * Every field is present
  * All values are canonical (via loader)
  * Action sequence is detailed, not just a pose
  * If validation fails: return error listing allowed values

---

### **C. Plugin System**

* Use or extend `plugin_loader.py` to load new genre/action/pose/lighting/etc. plugins from markdown, YAML, or JSON in the canonical directory.
* Plugins are merged, deduped, and hot-reloaded at runtime—**no restart required**.
* Plugins cannot overwrite or mutate canonical base values; they may *only* extend.

---

### **D. UI & API Requirements**

* Every selectable parameter field must **draw its options from loader**.
* **Autocomplete, dropdowns, and multi-select** must use loader results—no hardcoded lists.
* Block/alert on any field value that isn’t canonical.
* Provide context-sensitive help/tooltips (using `promptlib.py` descriptions where available).
* Genre-based action sequence filtering is required in the UI/API.
* Plugin-provided values must appear in selection lists seamlessly.

---

### **E. CLI Requirements**

* CLI prompt builder (`prompts.sh`):

  * Uses loader/plugin output for completions and validation.
  * No prompt can be output/copied if any parameter is missing/invalid.
  * Supports plugin injection and live reloading.

---

### **F. QA & Test Plan**

* Tests must cover:

  * Loader returns correct, deduped canonical values
  * Invalid values are blocked with proper error messaging
  * Prompt assembly requires all fields to be present and canonical
  * Plugins are loaded and merged live, with new options available instantly
  * API, UI, CLI all surface the canonical options and enforce validation

---

### **G. Documentation & Support**

* Maintain or update `/media/prompt_builder/libraries/hailuo/README.md`:

  * Usage examples for loader, plugin, and prompt assembly
  * All available parameter lists
  * How to author a plugin pack (YAML/JSON/MD)
  * Integration points for UI/API/CLI

---

### **H. Acceptance Criteria**

* [x] **Canonical loader is in place and hot-reloads**
* [x] **All parameter values are sourced exclusively from canonical files**
* [x] **All prompt-building is validated and enforced via loader**
* [x] **Plugin extension system is active and robust**
* [x] **No codebase changes are needed for future parameter/option additions**
* [x] **Full test coverage and documentation are available**

---

## 4. **Deliverables**

* [x] `canonical_loader.py` — parameter loader and validator with hot-reload
* [x] `promptlib.py` — master canonical parameter library and builder logic
* [x] `plugin_loader.py` — dynamic plugin/extension loader
* [x] `prompts.sh` — CLI with loader and plugin integration
* [x] Complete API/CLI/UI wiring to loader for all parameter options and validation
* [x] README with examples, field docs, and plugin authoring guide
* [x] Test suite and validation scripts

---

## 5. **Sample Usage Block (Python)**

```python
from canonical_loader import load_canonical_params

loader = load_canonical_params("/media/prompt_builder/libraries/hailuo/")
data = {
    "subject": "adult female, frontal, neutral expression",
    "age_tag": "adult",
    "gender_tag": "female",
    "action_sequence": "Subject stands, raises right arm to wave, smiles warmly.",
    "camera_moves": ["push in", "pedestal up"],
    "lighting": "Rembrandt key light at 45° camera-left with triangular cheek shadow; soft fill opposite",
    "lens": "85mm f/1.4, telephoto portrait, shallow DoF",
    "environment": "neutral seamless studio backdrop",
    "shadow": "soft, gradual edges",
    "detail": "Preserve skin pore texture and catchlights"
}
prompt = loader.assemble_prompt_block(data)
print(prompt)
```

---

**This document is the master handoff for dev, QA, UI, and product managers.
All teams must adhere strictly to canonical sourcing and validation.
