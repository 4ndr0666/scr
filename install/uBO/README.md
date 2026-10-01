# Custom uBlock Origin Scriptlets & Redirect Resources

A curated library of custom scriptlets and redirect stubs for [uBlock Origin (uBO)](https://github.com/gorhill/uBlock), engineered to defuse hostile browser behaviors, neutralize anti-adblock mechanisms, bypass content blockers, and redirect problematic telemetry scripts.

---

## Table of Contents
- [Inventory & Filter Mapping](#inventory--filter-mapping)
- [Scriptlet Functionalities](#scriptlet-functionalities)
- [Native Built-in Resources Comparison](#native-built-in-resources-comparison)
- [Setup & Deployment](#setup--deployment)
- [Targeting Syntax & Domain Matching](#targeting-syntax--domain-matching)
- [Security & Trust Architecture](#security--trust-architecture)
- [Debugging & Diagnostics](#debugging--diagnostics)

---

## Inventory & Filter Mapping

| Identifier | Type | Example Rule Syntax | Primary Purpose |
| :--- | :--- | :--- | :--- |
| `anti-tab-pause.js` | Scriptlet | `stream-hub.*##+js(anti-tab-pause)` | Prevents media pausing on tab/window blur |
| `preserve-article-content.js` | Scriptlet | `news-site.com##+js(preserve-article-content, paywallGateInit)` | Stubs functions that purge or mask article text |
| `restore-clipboard.js` | Scriptlet | `docs-wiki.org##+js(restore-clipboard)` | Strips copy/cut/paste locks and context menu hooks |
| `stub-ad-verifier.js` | Scriptlet | `ad-heavy.*##+js(stub-ad-verifier)` | Spoofs global ad flags and halts redirect loops |
| `defuse-debugger.js` | Scriptlet | `obfuscated-host.com##+js(defuse-debugger)` | Defuses infinite `debugger;` loops freezing DevTools |
| `unlock-scroll.js` | Scriptlet | `modal-trap.com##+js(unlock-scroll)` | Re-enables viewport scroll locked by modal overlays |
| `spoof-local-storage.js` | Scriptlet | `newsoutlet.*##+js(spoof-local-storage, read_articles_count, 0)` | Overrides and locks localStorage keys to bypass paywall meters |
| `kill-service-worker.js` | Scriptlet | `spammynews.*,shadyportal.*##+js(kill-service-worker)` | Clears active service workers and suppresses future registrations |
| `neutralize-eval-payload.js` | Scriptlet | `streamvid.*##+js(neutralize-eval-payload, detectAdBlock)` | Drops targeted obfuscated logic passed into window.eval() |
| `mock-analytics-sdk.js` | Redirect | `\|\|cdn.tracker.com/sdk.js$script,redirect=mock-analytics-sdk.js` | Inert mock avoiding uncaught tracking exceptions |

---

## Scriptlet Functionalities

### 1. `anti-tab-pause.js`
* **Mechanism:** Freezes `document.hidden` permanently to `false` and `document.visibilityState` to `'visible'` via prototype getters. Overrides `EventTarget.prototype.addEventListener` to filter out incoming `visibilitychange` and `blur` listeners.
* **Intended Use:** Video lecture portals, webinars, streaming sites, and browser players that interrupt playback when you switch monitors, switch tabs, or minimize the browser window.

### 2. `preserve-article-content.js`
* **Mechanism:** Accepts a dynamic function name parameter via uBO's `{{1}}` argument token. Intercepts the window object at initial load and DOM readiness to replace the target extraction/cleanup routine with an inert no-op callback.
* **Intended Use:** News publications that deliver full article text in the initial DOM response but subsequently clear the container or trigger paywall traps via timed JavaScript callbacks.

### 3. `restore-clipboard.js`
* **Mechanism:** Hooks into capture-phase listeners (`true`) for `copy`, `cut`, `paste`, `contextmenu`, and `selectstart` to execute `stopImmediatePropagation()`. Injects a high-specificity style element forcing `user-select: auto !important` across all DOM nodes and pseudo-elements.
* **Intended Use:** Reference sites, documentation hubs, and code repositories that disable right-click inspect, suppress standard keyboard copy combos, or append unwanted tracking text to your clipboard.

### 4. `stub-ad-verifier.js`
* **Mechanism:** Spoofs classic anti-adblock variables (`window.canRunAds = true`, `window.isAdBlockActive = false`) and wraps `window.location.assign` and `window.location.replace` to drop navigation attempts whose targets include common warning path signatures (`/adblock-detected`, `/disable-adblocker`).
* **Intended Use:** Download gateways, URL shorteners, and content vaults that scan for ad blockers and immediately redirect away from the target page.

### 5. `defuse-debugger.js`
* **Mechanism:** Wraps `window.Function` to parse the incoming constructor string. If the compiled function body contains the `debugger` keyword, the call is swapped with an empty function before return.
* **Intended Use:** Obfuscated, adversarial scripts that deploy timed execution loops containing `debugger;` statements to deliberately crash or lock developer inspection windows.

### 6. `unlock-scroll.js`
* **Mechanism:** Strips `overflow: hidden`, fixed heights, and locking layout positions directly from `document.documentElement` and `document.body` after page render.
* **Intended Use:** Overcoming "scroll freezing" that lingers after you cosmetically remove modal backdrops or login prompts using uBO element-hiding rules (`##.modal-backdrop:remove()`).

### 7. `spoof-local-storage.js`
* **Mechanism:** Pre-populates a designated `localStorage` key with an arbitrary value (`{{1}}` and `{{2}}`), then overrides `Storage.prototype.setItem` so scripts cannot overwrite or increment the value during the session.
* **Intended Use:** Metered paywalls that track "free articles read" counters or sites tracking modal view timestamps in local storage.

### 8. `kill-service-worker.js`
* **Mechanism:** Iterates through `navigator.serviceWorker.getRegistrations()`, unregisters every active worker, and stubs `navigator.serviceWorker.register` with a rejected promise.
* **Intended Use:** Spam hubs and malicious sites that abuse persistent service workers to serve desktop push notifications, hijack offline routing, or cache ad scripts across browser sessions.

### 9. `neutralize-eval-payload.js`
* **Mechanism:** Intercepts `window.eval` and checks string code blocks against a dynamic substring token (`{{1}}`). If matched, the payload is neutralized without interrupting subsequent eval calls.
* **Intended Use:** Streaming engines and download hubs that dynamically construct polymorphic anti-adblock routines and execute them dynamically through eval loops.

### 10. `mock-analytics-sdk.js`
* **Mechanism:** Returns a compliant, inert JavaScript object mapping common telemetry and measurement interfaces (`init`, `track`, `sendEvent`, `page`, `identify`, `ready`).
* **Intended Use:** Used via network redirection (`redirect=`) when outright blocking a script triggers unhandled promise rejections or breaks site initialization routines.

---

## Native Built-in Resources Comparison

Before writing or loading custom scriptlets, check whether uBO already provides a battle-tested built-in native equivalent:

| Custom Scriptlet | Built-in uBO Alternative | Native Syntax Example | Notes |
| :--- | :--- | :--- | :--- |
| `spoof-local-storage.js` | `set-local-storage-item` | `example.com##+js(set-local-storage-item, promoSeen, true)` | Built-in sets values on load; custom scriptlet freezes mutations via `setItem`. |
| `preserve-article-content.js` | `set-constant` | `example.com##+js(set-constant, paywallTrap, true)` | Built-in replaces global constants with primitive values. |
| `mock-analytics-sdk.js` | `google-analytics_analytics.js` | `\|\|google-analytics.com/analytics.js$script,redirect=google-analytics_analytics.js` | Native stock redirects exist for Google Analytics, GTM, and Amplitude. |
| *(Network Null)* | `noop.js` / `empty` | `\|\|telemetry.com/api$xhr,redirect=empty` | Native stubs for 200 OK empty JS payloads or XHR/Fetch endpoints. |

---

## Setup & Deployment

### 1. Host the Resource File
Host your combined resource scriptlet file on an accessible HTTP/HTTPS endpoint (e.g., GitHub Gist, personal domain, or VPS).

> **Gist Tip:** Ensure your raw URL omits the commit hash so uBO fetches the latest revisions seamlessly:  
> `https://gist.githubusercontent.com/<username>/<gist_id>/raw/<filename>.txt`

### 2. Configure Advanced Settings in uBO
1. Open the **uBlock Origin Dashboard** -> Navigate to **Settings**.
2. Enable **"I am an advanced user"** and click the **cog icon** (...).
3. Locate the `userResourcesLocation` directive and assign your raw URL:
   ```text
   userResourcesLocation https://gist.githubusercontent.com/<user>/<gist_id>/raw/<filename>.txt
   ```
   *(Multiple resource locations must reside on the **same line**, delimited by a single space).*
4. Verify that `trustedListPrefixes` includes `user-`:
   ```text
   trustedListPrefixes ublock- user-
   ```
5. Click **Apply changes** at the top of the interface.

### 3. Flush Cache & Sync
1. Switch to the **Filter lists** tab.
2. Click **Purge all caches** (or hold `Shift` and click the clock icon adjacent to **uBlock filters**).
3. Click **Update now**.

### 4. Deploy Filter Rules
Add your domain-specific execution rules to the **My filters** tab and click **Apply changes**.

---

## Targeting Syntax & Domain Matching

uBO cosmetic and scriptlet injection filters employ precise domain matching rules. Misunderstanding wildcard placement will cause rules to fail silently.

### Syntax Rules & Behavioral Boundaries

| Pattern | Validity | Target Scope |
| :--- | :---: | :--- |
| `example.com##+js(...)` | **Valid** | Targets `example.com` and **all** subdomains (`sub.example.com`, `a.b.example.com`). |
| `example.*##+js(...)` | **Valid** | Matches all TLD variations (`example.com`, `example.org`, `example.io`) + all their subdomains. |
| `site1.com,site2.org##+js(...)` | **Valid** | Targets multiple domains simultaneously on one line. |
| `site1.*,site2.net##+js(...)` | **Valid** | Combines TLD wildcards with explicit domains. |
| `host.*,~auth.host.*##+js(...)` | **Valid** | Matches all TLDs of `host` except the authentication subdomain. |
| `*.example.com##+js(...)` | **Invalid** | **Do not use.** Leading sub-domain wildcards are not supported by uBO. Use `example.com` directly. |
| `##+js(...)` or `*##+js(...)` | **Restricted** | **Global injection.** Strongly discouraged for intrusive scriptlets. |

### Why Global Scriptlet Injection is Discouraged
* **App Breakage:** Overwriting `visibilityState` or trapping keyboard listeners globally breaks interactive web apps like Google Docs, Figma, Spotify Web, and online banking platforms.
* **Performance Footprint:** Injecting scriptlet closures and patching browser prototypes on every iframe and page load creates unnecessary DOM hydration latency.
* **Target with Precision:** Always prefer multi-domain comma lists (`site1.com,site2.com`) or TLD wildcards (`host.*`).

---

## Security & Trust Architecture

Scriptlets execute directly inside the host site's execution context. To safeguard users, uBO implements strict trust verification boundaries:

* **The `trustedListPrefixes` Requirement:** Scriptlet injection (`##+js(...)`) requires that the calling filter list be trusted. Filters entered in the **My filters** panel carry the internal `user-` token. If `user-` is removed from `trustedListPrefixes`, all custom scriptlet injections will fail silently.
* **Remote File Integrity:** Never populate `userResourcesLocation` with unvetted, dynamic endpoints you do not control. If an external resource endpoint is compromised, malicious code can be injected into any origin matched by your rules.
* **Origin Shielding:** Unlike browser userscripts running under extensions like Violentmonkey, uBO scriptlets run under standard web-page privileges and cannot bypass browser CORS or sandbox boundaries independently.

---

## Debugging & Diagnostics

When an injected scriptlet or redirect rule fails to execute as expected:

1. **Verify Network Retrieval:**  
   Open the browser Developer Tools Network panel while updating filters in uBO. Confirm that your resource URL returns an HTTP `200 OK` status and not a `404` or `403`.
2. **Inspect the uBO Logger:**  
   Click the **Logger icon** (list icon) in the uBO popover, then refresh the target webpage.  
   * Successful scriptlet injections appear highlighted with a `+js(...)` marker.  
   * If highlighted in red or missing, ensure the rule is saved in **My filters** and that `trustedListPrefixes` contains `user-`.
3. **Trace Execution via DevTools Console:**  
   Add temporary logging directly inside your custom scriptlet:
   ```javascript
   console.log('%c[uBO Active]', 'color: cyan; font-weight: bold;', window.location.hostname);
   ```
   If the log does not print, the scriptlet was either not pulled from cache, or the domain failed to match the rule pattern.
4. **Cache Reset Procedure:**  
   If you push an update to your Gist or hosting server, force uBO to pull the latest version:  
   **Filter lists** tab -> Hold `Shift` -> Click the **clock/update icon** next to *uBlock filters* -> Click **Update now**.
