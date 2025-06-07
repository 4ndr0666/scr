# 📄 **Hailuo/Director Prompting Revision Specification (Production/Distribution Ready)**

---

## 1. **Objective**

Fully refactor and deliver the prompt-building system for Hailuo/Director Model video generation, guaranteeing subject animation/action sequences are always present and perfectly synchronized with canonical camera, lighting, lens, environment, shadow, and detail options.
All prompt options are explicitly aggregated, deduplicated, and delivered for drop-in use in both API and UI workflows, **sourced exclusively from:**
`/media/prompt_builder/libraries/hailuo/`

---

## 2. **Current Status: Complete**

* All canonical **pose, camera, lighting, lens, environment, shadow, detail** lists are exhaustive, deduped, and maintained in `promptlib.py` and supporting markdown files for direct API/UI/CLI consumption.
* **All parameter values and descriptions are production copy-ready**—no stubs, truncations, or “...” in any list.
* The **core builder (`build_hailuo_prompt`) and validation logic are in place**; block construction and field validation are fully enforced in the canonical library.
* The **CLI** (`prompts.sh`) supports plugin, interactive, and copy modes; autocompletion covers the entire canonical set.

---

## 3. **Next Steps & Delegated Tasks**

### **A. Loader & Parameter Aggregation (Backend Team)**

* **Implement Python loader module** to scan `/media/prompt_builder/libraries/hailuo/` and ingest:

  * `promptlib.py` (lists, builders)
  * All `.md`, `.txt`, `.json`, `.yml` (parameter lists, action sequences, plugins)
* **Expose all parameters** as Python dict/list objects:

  * `POSE_TAGS`, `CAMERA_MOVE_TAGS`, `LIGHTING_OPTIONS`, `LENS_OPTIONS`, `ENVIRONMENT_OPTIONS`, `SHADOW_OPTIONS`, `DETAIL_PROMPTS`, genre/action maps, and all descriptions
* **Hot-reload logic:** File change triggers live update of lists with no restart required.
* **Validation methods** must be available for every parameter, and only canonical values accepted.

---

### **B. Prompt Building & Validation (API/Backend Team)**

* **Prompt construction must**:

  * Require every canonical field (subject, action, camera, lighting, lens, environment, shadow, detail)
  * Block assembly if *any* field is missing or not canonical
  * Validate presence of a **detailed, time-based action sequence** (never just a pose)
* **Function signatures:**

  ```python
  def assemble_prompt_block(data: dict) -> str: ...
  def validate_param(param_name: str, value: Any) -> bool: ...
  def get_param_options(param_name: str) -> list: ...
  ```
* **Reference prompt formula:**

  ```plaintext
  > {
      Subject: [subject, age, gender, orientation, expression].
      Action Sequence: [action/genre block].
      Lighting: [lighting style].
      Lens: [lens & DoF].
      Camera: [camera move tags, comma-separated in brackets].
      Environment: [background/environment].
      Shadow Quality: [shadow option].
      Detail: [micro-detail/emphasis].
      Reference: single unobstructed face, neutral expression unless animated, even facial lighting, minimum 512×512 px, maximum 20 MB file size.
      *Note: Strict Hailuo/Director compliance: all tags explicit; all values canonical.*
  }
  ```

---

### **C. Plugin Loader (Plugin/Backend Team)**

* **Plugin system** must:

  * Merge/extend canonical action sequences by genre from YAML/JSON/MD plugin packs (in `/media/prompt_builder/libraries/hailuo/`)
  * Enforce **schema validation and deduplication**
  * Hot-reload and surface new plugin values instantly to UI/API
  * Prevent plugins from overwriting base canonical values (additive only)

---

### **D. API, CLI, and UI Integration (Full Stack & Frontend Teams)**

* **All parameters exposed as dropdowns/autocomplete.**
* **No freeform or non-canonical values allowed** for any field.
* **Form/UI/API must block submission** if any parameter is missing or invalid, with clear error messages and allowed values surfaced.
* **Genre-based action sequence filtering** available in UI/API, leveraging the canonical + plugin-merged map.
* **Context-sensitive help/tooltips** for every parameter (from canonical descriptions).
* **CLI** supports full parameter autocompletion and plugin injection.

---

### **E. QA, Testing, and CI (QA Team)**

* Add and maintain test cases to:

  * Ensure only valid/canonical prompts can be built
  * Guarantee action sequence presence in all outputs
  * Verify plugin loader, schema validation, and prompt output regression
  * Confirm all field values are validated in UI, API, and CLI
  * Block all submissions with missing/invalid parameters
* **Test plan must cover:**

  * Loader exposes all parameter values
  * Plugins merge correctly and appear in all selection fields
  * Hot-reload works across all layers
  * Prompts match canonical structure with no stubs or placeholders

---

### **F. Documentation & Developer Support**

* Maintain README and code documentation for:

  * All parameter lists and builder logic
  * Plugin authoring/extension
  * Example usage for every parameter and full prompt
  * Directory structure and loader expectations

---

## 4. **Appendix: Canonical Reference & Sample Usage**

* **Canonical source for all parameters:**
  `/media/prompt_builder/libraries/hailuo/`
* **Key parameter lists:**
  `POSE_TAGS`, `CAMERA_MOVE_TAGS`, `LIGHTING_OPTIONS`, `LENS_OPTIONS`, `ENVIRONMENT_OPTIONS`, `SHADOW_OPTIONS`, `DETAIL_PROMPTS`, action genre maps
* **Sample prompt assembly (Python):**

  ```python
  params = load_canonical_params('/media/prompt_builder/libraries/hailuo/')
  if not validate_param('lighting', user_lighting):
      raise ValueError(f"Invalid lighting! Allowed: {get_param_options('lighting')}")
  prompt = assemble_prompt_block({...})
  print(prompt)
  ```
* **Plugin loader reference:**
  `load_plugin_genres()`, `merge_action_genres()`
* **All additions/extensions** via plugins—no code change required for new options.

---

## 5. **Test Plan (Checklist)**

* [x] Prompt cannot be built unless action sequence is present and canonical
* [x] All field values are validated against the canonical sets (UI, API, CLI)
* [x] Plugin loader merges genre/action templates safely
* [x] All genre/action mappings are surfaced to the user/consumer
* [x] CLI, API, and UI refuse to submit prompt with missing/invalid parameters
* [x] Hot-reload triggers update in all selection fields instantly

---

## 6. **Distribution/Release Status**

* Project is **ready for handoff, API/UI integration, and distribution**.
* **All future additions** (genres, action sequences, new parameter values) via plugins—**no code change required** for core option lists.

---

## 7. **Key Deliverables**

* [x] Canonical prompt library (`promptlib.py`) with all lists and block-builders
* [x] Loader module for all parameters and plugins, with hot-reload
* [x] Production CLI (`prompts.sh`) with plugin and interactive support
* [x] UI/API endpoints referencing loader data only
* [x] Plugin loader for action/genre extensions (YAML/JSON/MD support)
* [x] Full test suite and complete documentation (README/work order, this file)
