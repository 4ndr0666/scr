# ⊰ 💀 • ⦑ Hydra-Kill: Engine Manifest ⦒ • 💀 ⊱

**Hydra-Kill** is the specialized sterilization core of the **GDV-saver** ecosystem. It is engineered to neutralize the "Hydra" (Google's dynamic re-hydration scripts) that attempt to re-animate or corrupt static HTML exports of Gemini experiments.

## ⬢ Core Objectives

* **Static Solidification**: Converts a living, breathing dynamic DOM into a frozen, high-fidelity artifact.
* **Script Termination**: Recursively identifies and purges `<script>` nodes and module preloads to ensure zero execution upon local opening.
* **Attribute Scrubbing**: Removes Google-specific event triggers (`jsaction`, `jscontroller`, `jsdata`) that cause "Hydration Mismatch" errors.
* **Sandboxing**: Force-injects security headers into remaining `iframes` to prevent cross-origin leakage or execution in a local context.

## ⬢ Integration Architecture

The engine is encapsulated within the `HydraEngine` singleton for modular usage:

```javascript
// Initialization
await HydraEngine.initialize(documentClone);

// Finalization & Export
const artifact = await HydraEngine.executeExport(document);

```

## ⬢ Operational Sequence (The 4-Step Purge)

1. **Node Traversal**: A `TreeWalker` executes a depth-first search of the entire DOM tree.
2. **Logic Decapitation**: All nodes identified as executable (JS/Preload) are detached.
3. **Attribute Sterilization**: Inline handlers and private Google framework attributes are stripped.
4. **Shadow Flattening**: Shadow DOM boundaries are collapsed into the light DOM to ensure visibility in standard HTML viewers.

## 🛡️ Security Protocol

Hydra-Kill operates under a **Zero-Reentry** mandate. Once the engine completes its cycle, the resulting file contains no active logic, preventing the exported page from "calling home" or attempting to fetch updated data from Google's servers.

---
