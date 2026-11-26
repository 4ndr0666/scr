# 4ndr0prompts HDL v8 — Project schema

**Profile:** canonical HDL JSON exported by the 4ndr0prompts 11.3.1 compiler.  
**Standard:** JSON Schema Draft 2020-12.  
**Normative filename:** `hdl-v8.schema.json`.

This is a project-authored normative schema, based on the seven-block HDL structure and the deployed 11.3.1 compiler. It is not presented as an external/industry-certified standard.

## The seven HDL blocks

The HDL document has two top-level sections and five required children of the atmosphere envelope:

| # | Name | Location |
|---|---|---|
| 1 | `!INIT_MEM_LOCK` | root |
| 2 | `!INIT_ATMOSPHERICS` | root |
| 3 | `!INIT_BIO_DERMAL_MAPPING` | inside `!INIT_ATMOSPHERICS` |
| 4 | `!EXEC_COMPOSITION_MATRIX` | inside `!INIT_ATMOSPHERICS` |
| 5 | `!ENV_PHOTOMETRY` | inside `!INIT_ATMOSPHERICS` |
| 6 | `!EXEC_MATERIAL_PHYSICS` | inside `!INIT_ATMOSPHERICS` |
| 7 | `!GLOBAL_NEGATIVE_BIAS` | inside `!INIT_ATMOSPHERICS` |

`LOCATION_SETTING` is a required atmosphere attribute. Optional fields supported by the 11.3.1 compiler include `!INIT_GEOMETRIC_SEED`, `COMPOSITION_DEPTH`, `TEXT_RECON_ENGINE`, `!FINALIZE_OUTPUT`, `!EXEC_GOOGLE_FLOW_ENGINE`, atmosphere and photometry metadata, and per-panel kinematic/lighting overlays.

## Contract behavior

- The root accepts only `$schema`, `!INIT_MEM_LOCK`, and `!INIT_ATMOSPHERICS`. Legacy root aliases and duplicate top-level optics/photometry/material blocks **fail**.
- Each nested core module is restricted to recognized parameter names (additional unrecognized fields fail). The optional Flow metadata carrier permits unconstrained content only for the provider-specific `AUDIO` and `INGREDIENTS` fields.
- `PANELS` is a string from `"1"` through `"9"`. The schema requires **exactly** `PANEL_1` through `PANEL_n` with no missing or extra panels.
- Vectors use numeric `[x, y, z]` triples. Light beam angles, penumbra, distance and temperature have numeric constraints. The original example's `LUMINOUS_INTENSITY_PCT: "110%"` and the runtime's `INTENSITY_PCT: 110` are individually supported, but not simultaneously.
- Dermal micro-elements and global negative bias are arrays; material drape physics is an object. `BIOMETRIC_LOCK` may be the deployed string or `false` for product mode.
- Catalog identifiers and text are not frozen to a closed enum, so PromptLib can grow without silently deleting earlier accepted values.
- `$schema` inside an HDL document (if present) must equal `"./hdl-v8.schema.json"`. Place the schema **beside the exported JSON file** to resolve this relative reference in compliant tooling.

## Direct validation

Install Python's JSON Schema validator:

```bash
python -m pip install 'jsonschema>=4.18'
python validate_hdl_v8.py hdl-v8.seven-block.example.json
python validate_hdl_v8.py hdl-v8.example.json
```

`validate_hdl_v8.py` checks structural conformance **and** same-document constraints that Draft 2020-12 alone cannot express: matching photometry/finalization focus, matching memory/material wardrobe locks, dangling per-panel references, repeated panel override IDs, duplicate JSON member names, and invalid JSON syntax. It does not rewrite input files.

## Python generator lineage: separate legacy profile

The supplied `prompt_arc.py` is a related but **different representation**, with original top-level keys `!INIT_MEM_LOCK_PROTOCOL` and `!ENV_ATMOSPHERICS` and nested `!EXEC_BIO_DERMAL_MAP` and `!ENV_RAY_TRACING_PHOTOMETRY`. Its native output is **not** interchangeable with the canonical browser output. In particular, the native `SURFACE_MICRO_ELEMENTS` is a string, while canonical HDL uses an array. Therefore:

```bash
python validate_hdl_v8.py --legacy hdl-v8.prompt-arc-native.example.json
```

This uses `hdl-v8.prompt-arc-legacy.schema.json`, which validates the source representation without weakening the official canonical schema. Validation is not a migration. To emit canonical HDL from the Python generator, perform an explicit, tested mapping of old names and ray tracing into the canonical scene/photometry authority.

## Regression evidence

- `test_hdl_v8_schema.py`: **89/89 passed** — 7-block and full-compiler examples, malformed documents, block-nesting errors, panel counts, duplicate JSON keys, cross-module semantic conflicts, and 27 seeded Python-native fixtures (each tested for legacy acceptance and canonical rejection), plus stock mode.
- `test_hdl_v8_browser.py`: **31/31 passed** — 27 live Chromium random outputs across 9 layout families, one manual override, one product-mode payload, one optional Flow payload, and zero page errors.
- `hdl-v8_browser_validation.json` contains the browser case-by-case record.

Both tests were executed against the 11.3.1 released HTML and the supplied upgraded `prompt_arc.py`/`promptlib.py` without changing either.

## Deliberate boundaries

Structural validation alone cannot determine that a scene description semantically matches `LOCATION_MANIFEST_KEY`, prove physical camera/lens mount compatibility, or guarantee that photometric vectors correspond to an actual ray tracer. Catalog grounding, physically valid light-vector normalization, external model behavior, and cross-dialect prose equivalence require domain/runtime verification. The optional Google Flow `AUDIO` and `INGREDIENTS` payloads also require provider-specific schemas.
