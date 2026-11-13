// === Ψ-4ndr0666 SVPlayer Nerd Settings Snapshot & Injector ===
(async function svpNerdManager() {
  // 1. Export current settings from the live DOM so you never lose a key name
  window.svpExportSettings = () => {
    const dump = {};
    document.querySelectorAll('[id^="opt-"]').forEach(el => {
      const k = el.id.replace(/^opt-/, '').replace(/-/g, '.');
      dump[ el.getAttribute('name') || k ] = el.value;
    });
    console.log("Copy this object into NERD_OVERRIDES:", JSON.stringify(dump, null, 2));
    return dump;
  };

  // 2. Define your preferred Nerd Overrides (key: value)
  const NERD_OVERRIDES = {
    // Frame Rate Conversion (FRC) & Apple TV Nerd Tweaks
    "main.setup.frc.enabled": "1",
    "main.setup.frc.profile": "12",
    "frc.target.fps": "60",
    "frc.shader.11": "2",          // Standard/Sharp shader for A8 GPU
    "frc.mask.mode": "1",          // Artifact masking
    "frc.scene.mode": "1",         // Repeat frame on scene change
    "cast.buffer.size": "250"      // Match 250MiB RAM limit
  };

  console.log("[Ψ] Injecting SVPlayer Nerd Settings...");
  for (const [n, v] of Object.entries(NERD_OVERRIDES)) {
    await fetch("r/set-opt", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8" },
      body: new URLSearchParams({ n, v })
    });
    console.log(`[+] Set ${n} = ${v}`);
  }
  console.log("[Ψ] Done! Reloading settings state...");
  if (typeof updateAllSettings === "function") {
    fetch("r/settings").then(r => r.json()).then(updateAllSettings);
  }
})();
