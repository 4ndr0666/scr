# 4ndr0prompts 11.3.2 — Official HDL v8 schema integration

## Deliverable

`4ndr0prompts.html` is the FLOW9 11.3.1 canonical compiler, updated to integrate the normative `hdl-v8.schema.json` **inside the single-file app**. No external library or network request is required for validation. For IDE/CLI use, retain the accompanying standalone `hdl-v8.schema.json` beside exported HDL JSON files.

## Changes

1. Replaced the obsolete embedded `HDL_V8_JSON_SCHEMA` (legacy `!INIT_MEM_LOCK_PROTOCOL` / `!ENV_ATMOSPHERICS` roots) with the official seven-block schema, byte-equivalent when JSON-decoded to the supplied file.
2. Added an offline, deterministic schema-keyword validation engine implementing all assertion keywords exercised by the embedded project schema: `$ref`, `type`, `const`, `enum`, string and numeric ranges/patterns, object `properties` / `required` / `additionalProperties`, array items/prefix items/size/uniqueness, `allOf`, `anyOf`, `oneOf`, `not`, and `if/then/else`. This is **not** claimed as a full general-purpose Draft 2020-12 validator for arbitrary future schemas. The external JSON Schema Draft 2020-12 definition is normative.
3. Added the same-document semantic checks from `validate_hdl_v8.py`: photometry/finalization focus agreement, memory/material wardrobe agreement, and valid non-repeating per-panel overlays.
4. Inserted a **hard validation gate** into `HDLCanonical1131.build()`, which is shared by the active Nano Banana, HDL-tag, and HDL-JSON compiler routes. Invalid documents throw with exact field diagnostics instead of silently exporting contradictory structures.
5. Added a status indicator, **Validate HDL** and **Export Schema** controls next to the main dock's compiled output. The existing HDL Studio schema-export action now exports the official schema.
6. Added a separate read-only canonical preview and validation controls inside HDL Studio. The legacy HDL editor remains fully editable; it is not silently converted into the seven-block canonical format. The editor's explicit validation action rejects duplicate keys in pasted JSON before ordinary JSON parsing.
7. Preserved original HTML IDs, named functions, external import semantics, Google Flow/Veo compiler path, and saved-text passthrough. The public `HDLCanonical1131` API remains available.

## Scope and precedence

- **Official canonical output**: root `!INIT_MEM_LOCK` + root `!INIT_ATMOSPHERICS`, with `!INIT_BIO_DERMAL_MAPPING`, `!EXEC_COMPOSITION_MATRIX`, `!ENV_PHOTOMETRY`, `!EXEC_MATERIAL_PHYSICS`, and `!GLOBAL_NEGATIVE_BIAS` nested inside the latter. Optional modules retain their existing schema-defined locations.
- **Python generator and legacy HDL editor**: continue to use the separate legacy profile. No automatic incompatible migration is attempted.
- **Workflow video manifests**: Google Flow/Veo compilation is preserved; canonical still-image schema validation does not purport to validate a provider's video manifest format.
- **Runtime API**: `HDLV8Schema.schema`, `HDLV8Schema.validate(doc) -> {valid, errors}`, `HDLV8Schema.assert(doc)`, `HDLV8Schema.current()`, `HDLV8Schema.validateEditor()`.
- **JSON Schema Draft 2020-12**: validated by `validate_hdl_v8.py` with Python `jsonschema>=4.18` for external exported documents. The browser uses the embedded project-specific keyword engine for offline validation.

## Observed verification

| Verification | Result |
|---|---:|
| New live browser schema and adversarial integration | 53/53 PASS |
| Official schema external regression | 89/89 PASS |
| Live generated canonical documents vs Python Draft 2020-12 | 31/31 PASS |
| Inherited browser workflow | 32/32 PASS |
| Inherited focused editor and compiler | 14/14 PASS |
| Inherited cohort flows | 26/26 PASS |
| Extended state transitions, mobile and dialogs | 85/85 PASS |
| Canonical compiler cross-dialect invariants | 96/96 PASS |
| Dialog close/reopen race suite | 37/37 PASS |
| FLOW9 library runtime | 30/30 PASS |
| Legacy source IDs retained | 515/515 |
| Legacy named function declarations retained | 429/429 |
| All five inline script syntax checks | PASS |

These are observed results for the supplied, unmodified baseline plus this integration, not universal verification of downstream image-model behavior. Safari/Firefox, physical mobile devices, browser-specific `file://` policy, and external services were not independently exercised. An attempt to use `file://` in the sandbox's managed Chromium was blocked by its administrator policy; tests instead loaded the exact HTML through Chromium's `set_content` without fetching external scripts.

## Usage

1. Open `4ndr0prompts.html` in a browser that permits local HTML files.
2. Randomize or edit as before. The compiled output dock displays `HDL v8 · Schema valid`, or a diagnostic count if the generated canonical document violates the official contract.
3. Click **Validate HDL** to recheck the current live canonical build. Click **Export Schema** to save the authoritative JSON Schema file. The legacy HDL Studio offers independent canonical previews and JSON editor validation.
4. To run full external JSON Schema validation on an exported file, install `jsonschema>=4.18` and run `python validate_hdl_v8.py exported.json`. Place `hdl-v8.schema.json` next to exported documents to resolve their `$schema` URI.

The application and official schema are both available individually and included in the integrity-checked handoff bundle.
