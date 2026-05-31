# 💀 WINE DEPLOYMENT & PREFIX HARDENING MANIFEST 💀
**OS Paradigm:** Arch Linux (Rolling Release)
**Target Vector:** Wine Compatibility Layer (New WoW64 Architecture)
**Objective:** Total Host Isolation & Zero-Trust Prefix Forging

## 1. THE ENVIRONMENTAL BASELINE (`.zprofile`)

By default, Wine contaminates the user's home directory with a scattered `~/.wine` instance. This is operationally unacceptable. We force all emulation layers into a unified, predictable directory structure using XDG standard paths.

Inject the following into your `.zprofile` or respective shell RC:

```bash
# Force Wine to isolate prefixes to the designated local share data structure
export WINEPREFIX="$XDG_DATA_HOME/wineprefixes/default"

```

*(Ensure `$XDG_DATA_HOME` is inherently mapped to `~/.local/share`)*

### ⚠️ CRITICAL ARCHITECTURAL DIRECTIVE: THE WOW64 PARADIGM ⚠️

**DO NOT, UNDER ANY CIRCUMSTANCES, EXPORT `WINEARCH="win32"`.**

Modern Arch Linux Wine packages operate on the **New WoW64** framework. This architecture executes 32-bit PE binaries natively within a unified 64-bit `wineserver` process space, completely eliminating the need for multilib host dependencies.
Injecting `WINEARCH="win32"` will cause a fatal architectural collision (`unsupported in wow64 mode`) and halt the bootstrap sequence. The environment natively translates 32-bit API calls.

---

## 2. THE FORCE-BOOTSTRAP SEQUENCE

A silent update (`wineboot -u`) is insufficient to forge a clean environment. To establish a new prefix, we must violently purge lingering IPC daemons, forcefully construct the skeletal tree, and inject the initialization sequence.

Execute this sequence linearly when deploying a new prefix:

```bash
# 1. Terminate all lingering Wine IPC sockets/daemons to prevent state-bleeding
wineserver -k

# 2. Forcibly forge the absolute path for the new prefix
mkdir -p "$WINEPREFIX"

# 3. Inject the core initialization sequence to construct the Windows API skeleton
WINEPREFIX="$WINEPREFIX" wineboot --init

```

*Note: The terminal will vomit a cascade of asynchronous errors (`err:ole`, `fixme`, `Failed to start RpcSs service`). This is the emulation layer blindly probing for native Windows NT services that do not exist in the sandbox. **Ignore the spew.** Wait for the terminal prompt to return.*

---

## 3. THE HARDENING PROTOCOL (Z: DRIVE CAUTERIZATION)

**The Vulnerability:** By default, Wine maps the Linux root directory (`/`) to the `Z:` drive within the emulated environment. A compromised Wine binary can traverse this mapping to read/write native host files (e.g., `/etc`, `~/.ssh`).

**The Mitigation:** We sever the global symlink and redirect the target to an isolated, unprivileged null-route/sandbox.

Execute immediately after the terminal prompt returns from the bootstrap sequence:

```bash
# 1. Forge the isolated host-side sandbox and restrict permissions to owner-only
mkdir -p ~/.wine_sandbox/virtual_z
chmod 700 ~/.wine_sandbox

# 2. Obliterate the global root mapping spawned by the bootstrap
rm -f "$WINEPREFIX/dosdevices/z:"

# 3. Bind the local Z: drive identifier to the hardened sandbox
ln -s ~/.wine_sandbox/virtual_z "$WINEPREFIX/dosdevices/z:"

```

---

## 4. CANONICAL VERIFICATION & AUDITING

Trust nothing. Verify the structural integrity of the namespace link before executing untrusted binaries.

```bash
ls -l "$WINEPREFIX/dosdevices/z:"

```

**Expected Result:**

```
lrwxrwxrwx 1 user user [size] [date] /home/user/.local/share/wineprefixes/default/dosdevices/z: -> /home/user/.wine_sandbox/virtual_z

```

If the symlink points to `/`, the system is exposed. Abort execution and re-run the Hardening Protocol.

---

## 5. TRADE-CRAFT: ISOLATION MATRICES

Never install disparate applications into the `default` prefix. Maintain compartmentalization by dynamically passing the variable upon execution.

**Example: Sandboxed Application Execution**

```bash
WINEPREFIX="$XDG_DATA_HOME/wineprefixes/target_app" wine /path/to/installer.exe

```

*Remember: Each unique prefix requires the Hardening Protocol to be run independently.*
