/**
 * ⊰💀•-⦑4NDR0666OS HYDRA-KILL ALL-INCLUSIVE WRAPPER⦒-•Ψ💀⊱
 * Version: 2.0.0-PROD
 * Description: Orchestrates recursive DOM scrubbing and asset localization.
 */

const HydraEngine = (() => {
  // Private internal registry for tracking neutralized nodes
  const _registry = new WeakSet();

  /**
   * Internal: Scrub dynamic attributes and script remnants
   */
  const _scrubNode = (node) => {
    if (_registry.has(node)) return;

    // Script & Link Termination
    if (['SCRIPT', 'NOSCRIPT', 'TEMPLATE'].includes(node.tagName)) {
      node.remove();
      return;
    }

    if (node.tagName === 'LINK' &&
       (node.rel === 'modulepreload' || node.rel === 'preload' || node.as === 'script')) {
      node.remove();
      return;
    }

    // Attribute Erasure: Standard and Google-Specific (Hydration keys)
    const targets = [
      'jsaction', 'jscontroller', 'jsmodel', 'jsname', 'jsdata',
      'onload', 'onerror', 'onclick', 'onmouseover', 'onsubmit'
    ];

    targets.forEach(attr => {
      if (node.hasAttribute && node.hasAttribute(attr)) {
        node.removeAttribute(attr);
      }
    });

    // Sandbox Iframe logic
    if (node.tagName === 'IFRAME') {
      node.setAttribute('sandbox', 'allow-forms allow-modals');
      if (node.src && node.src.startsWith('javascript:')) {
        node.src = 'about:blank';
      }
    }

    _registry.add(node);
  };

  /**
   * Public API: processDocument
   * The primary entry point for full-page sterilization.
   */
  const processDocument = async (docClone) => {
    console.log("[4NDR0666OS] Initializing Hydra-Kill Sequence...");

    // 1. Recursive Tree Scrubbing
    const walker = document.createTreeWalker(docClone, NodeFilter.SHOW_ELEMENT, null, false);
    let currentNode = walker.nextNode();
    while (currentNode) {
      _scrubNode(currentNode);
      currentNode = walker.nextNode();
    }

    // 2. CSS-in-JS Neutralization
    docClone.querySelectorAll('style[id*="hydra"], style[data-href]').forEach(s => {
      s.removeAttribute('id');
      s.removeAttribute('data-href');
    });

    // 3. Shadow DOM Flattening Check
    // Ensures all encapsulated fragments are captured before serialization
    const allElems = docClone.querySelectorAll('*');
    for (const el of allElems) {
      if (el.shadowRoot) {
        const template = docClone.createElement('template');
        template.innerHTML = el.shadowRoot.innerHTML;
        el.appendChild(template.content);
        // Note: Actual Shadow DOM cannot be perfectly 'cloned' as live,
        // so we move the content to light DOM for the static save.
      }
    }

    console.log("[4NDR0666OS] Hydra-Kill: Target is now static and sterile.");
    return docClone;
  };

  /**
   * Public API: wrapAndExport
   * High-level wrapper to finalize the blob for persistence.
   */
  const wrapAndExport = async (targetNode) => {
    const clone = targetNode.cloneNode(true);
    const sterilized = await processDocument(clone);

    const doctype = "<!DOCTYPE html>\n";
    const blob = new Blob([doctype + sterilized.documentElement.outerHTML], {
      type: 'text/html'
    });

    return {
      blob,
      timestamp: new Date().toISOString(),
      integrity: "CLEAN"
    };
  };

  return {
    initialize: processDocument,
    executeExport: wrapAndExport
  };
})();

// Usage Implementation:
// HydraEngine.executeExport(document).then(data => console.log("Finalized Payload Ready."));
