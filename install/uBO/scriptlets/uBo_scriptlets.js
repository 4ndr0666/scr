/// anti-tab-pause.js
// Prevents media players from auto-pausing when switching tabs or monitors.
// Usage: stream-hub.*##+js(anti-tab-pause)
(() => {
    'use strict';
    try {
        Object.defineProperty(Document.prototype, 'hidden', {
            get: () => false,
            configurable: true
        });
        Object.defineProperty(Document.prototype, 'visibilityState', {
            get: () => 'visible',
            configurable: true
        });
    } catch (_) {}

    const origAddEventListener = EventTarget.prototype.addEventListener;
    EventTarget.prototype.addEventListener = function(type, listener, options) {
        if (type === 'visibilitychange' || type === 'blur') {
            return;
        }
        return origAddEventListener.call(this, type, listener, options);
    };
})();

/// preserve-article-content.js
// Stubs paywall timers, scroll traps, and DOM-purging callbacks.
// Usage: news-site.com##+js(preserve-article-content, paywallGateInit)
(() => {
    'use strict';
    const targetTrap = '{{1}}';
    if (!targetTrap || targetTrap === '{{1}}') return;

    const defuse = () => {
        if (typeof window[targetTrap] !== 'undefined') {
            window[targetTrap] = function() {
                return true;
            };
        }
    };

    defuse();
    if (document.readyState === 'loading') {
        window.addEventListener('DOMContentLoaded', defuse, { once: true });
    }
})();

/// restore-clipboard.js
// Neutralizes copy/cut/paste locks, context menu disables, and forced selection styles.
// Usage: docs-wiki.org##+js(restore-clipboard)
(() => {
    'use strict';
    const allowEvent = (e) => {
        e.stopImmediatePropagation();
    };

    document.addEventListener('copy', allowEvent, true);
    document.addEventListener('cut', allowEvent, true);
    document.addEventListener('paste', allowEvent, true);
    window.addEventListener('contextmenu', allowEvent, true);
    document.addEventListener('selectstart', allowEvent, true);

    const restoreStyles = () => {
        const style = document.createElement('style');
        style.textContent = '*, *::before, *::after { user-select: auto !important; -webkit-user-select: auto !important; }';
        (document.head || document.documentElement).appendChild(style);
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', restoreStyles, { once: true });
    } else {
        restoreStyles();
    }
})();

/// stub-ad-verifier.js
// Spoofs generic ad blocker indicators and prevents navigation traps.
// Usage: ad-heavy.*##+js(stub-ad-verifier)
(() => {
    'use strict';
    window.canRunAds = true;
    window.isAdBlockActive = false;

    const blockedSubstrings = ['/adblock-detected', '/disable-adblocker', 'adblock', 'ad-blocker'];

    const shouldBlock = (url) => {
        const str = String(url).toLowerCase();
        return blockedSubstrings.some(token => str.includes(token));
    };

    const origAssign = window.location.assign;
    const origReplace = window.location.replace;

    window.location.assign = function(url) {
        if (shouldBlock(url)) return;
        return origAssign.call(window.location, url);
    };

    window.location.replace = function(url) {
        if (shouldBlock(url)) return;
        return origReplace.call(window.location, url);
    };
})();

/// defuse-debugger.js
// Defuses infinite `debugger;` loops triggered by DevTools detection scripts.
// Usage: obfuscated-host.com##+js(defuse-debugger)
(() => {
    'use strict';
    const origFunction = window.Function;
    window.Function = function(...args) {
        const body = args[args.length - 1];
        if (typeof body === 'string' && body.includes('debugger')) {
            return function() {};
        }
        return origFunction.apply(this, args);
    };
    window.Function.prototype = origFunction.prototype;
})();

/// unlock-scroll.js
// Restores viewport scrolling locked by modal backdrops on <html> and <body>.
// Usage: modal-trap.com##+js(unlock-scroll)
(() => {
    'use strict';
    const unlock = () => {
        const clean = (el) => {
            if (!el) return;
            el.style.setProperty('overflow', 'auto', 'important');
            el.style.setProperty('overflow-y', 'auto', 'important');
            el.style.setProperty('position', 'static', 'important');
            el.style.setProperty('height', 'auto', 'important');
        };
        clean(document.documentElement);
        clean(document.body);
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', unlock, { once: true });
    } else {
        unlock();
    }
    window.addEventListener('load', unlock, { once: true });
})();

/// spoof-local-storage.js
// Pre-seeds a localStorage key and locks it against site mutations.
// Usage: newsoutlet.*##+js(spoof-local-storage, read_articles_count, 0)
(() => {
    'use strict';
    const key = '{{1}}';
    const value = '{{2}}';
    if (!key || key === '{{1}}') return;

    try {
        window.localStorage.setItem(key, value);
        const origSetItem = Storage.prototype.setItem;
        Storage.prototype.setItem = function(k, v) {
            if (k === key) return;
            return origSetItem.apply(this, arguments);
        };
    } catch (_) {}
})();

/// kill-service-worker.js
// Unregisters persistent service workers and prevents future background registrations.
// Usage: spammynews.*,shadyportal.*##+js(kill-service-worker)
(() => {
    'use strict';
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.getRegistrations().then(registrations => {
            for (const reg of registrations) {
                reg.unregister();
            }
        });
        navigator.serviceWorker.register = () => Promise.reject(new Error('[uBO] ServiceWorker registration blocked'));
    }
})();

/// neutralize-eval-payload.js
// Intercepts eval() calls containing specific detection logic signatures.
// Usage: streamvid.*##+js(neutralize-eval-payload, detectAdBlock)
(() => {
    'use strict';
    const needle = '{{1}}';
    if (!needle || needle === '{{1}}') return;

    const origEval = window.eval;
    window.eval = function(code) {
        if (typeof code === 'string' && code.includes(needle)) {
            console.info(`[uBO] Defused eval payload containing: ${needle}`);
            return null;
        }
        return origEval.apply(this, arguments);
    };
})();

/// mock-analytics-sdk.js application/javascript
// Inert redirect mock to prevent crashes from missing telemetry libraries.
// Usage: ||cdn.trackingservice.com/sdk.js$script,redirect=mock-analytics-sdk.js
window.AnalyticsSDK = {
    init: () => true,
    track: () => {},
    sendEvent: () => {},
    page: () => {},
    identify: () => {},
    ready: (cb) => { if (typeof cb === 'function') cb(); }
};
