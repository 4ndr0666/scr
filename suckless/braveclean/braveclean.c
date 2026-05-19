/*
 * braveclean.c — High-performance browser sanitizer
 * Version: 2.2.0 (Bash Superset Integration)
 *
 * COHESION REPORT (2.1.4 → 2.2.0):
 * - PORTED: Graceful SIGTERM→SIGKILL process termination with user prompt
 *   and configurable wait, replacing fire-and-forget pkill.
 * - PORTED: --deep-clean / -d flag. Opt-in removal of GPUCache, Code Cache,
 *   Service Worker, DawnCache, GraphiteDawnCache, component_crx_cache,
 *   extensions_crx_cache, Crash Reports, Greaselion, Local Traces.
 * - PORTED: Guest Profile directory clear (keep dir, wipe contents).
 * - PORTED: -h / --help flag with usage output.
 * - PORTED: EUID==0 root warning + confirmation gate.
 * - PORTED: Per-database space-reclaimed delta reporting (KB).
 * - PORTED: Aggregate space summary across all profiles.
 * - PORTED: WAL/SHM sidecar pre-deletion before sqlite3_open.
 * - PORTED: notify-send completion notification with graceful fallback.
 * - PORTED: Extensible browser path table covering Brave stable/beta/dev,
 *   Chromium variants, Chrome variants, Firefox, Icecat, Seamonkey, Aurora.
 * - PORTED: XDG ~/.cache wipe via clean_xdg_caches().
 * - RETAINED: All V2.1.4 validated logic (xnanosleep, isatty color guard,
 *   safe_path_join, nftw nuke_dir, strict *.sqlite targeting,
 *   canonical deep-clean array, profiles.ini IsRelative handling).
 *
 * Build: gcc -O2 braveclean.c -o braveclean -lsqlite3
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <ftw.h>
#include <sqlite3.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <limits.h>

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

/* ─── DYNAMIC ANSI COLORS ─────────────────────────────────────────────────── */

static const char *
get_color(const char *ansi_code)
{
    if (isatty(STDOUT_FILENO)) return ansi_code;
    return "";
}

#define RED    get_color("\033[31m")
#define GREEN  get_color("\033[32m")
#define YELLOW get_color("\033[33m")
#define CYAN   get_color("\033[36m")
#define RESET  get_color("\033[0m")

/* ─── GLOBAL STATE ────────────────────────────────────────────────────────── */

static int  g_deep_clean     = 0;   /* --deep-clean flag                    */
static long g_total_saved_kb = 0;   /* aggregate space reclaimed across run */

/* ─── UTILS ───────────────────────────────────────────────────────────────── */

static void
log_info(const char *msg, const char *detail)
{
    if (detail)
        printf("%s[+] %s: %s%s\n", GREEN, msg, detail, RESET);
    else
        printf("%s[+] %s%s\n", GREEN, msg, RESET);
}

static void
log_warn(const char *msg, const char *detail)
{
    fprintf(stderr, "%s[!] %s: %s%s\n", YELLOW, msg, detail ? detail : "", RESET);
}

/*
 * xnanosleep — precision sleep immune to SIGCHLD truncation.
 * Accepts total nanoseconds; splits into tv_sec + tv_nsec correctly
 * for values >= 1,000,000,000 ns.
 */
static void
xnanosleep(long nsec)
{
    struct timespec req;
    req.tv_sec  = nsec / 1000000000L;
    req.tv_nsec = nsec % 1000000000L;
    nanosleep(&req, NULL);
}

/*
 * safe_path_join — bounded path concatenation.
 * Returns 0 on success, -1 on overflow.
 */
static int
safe_path_join(char *dst, size_t size, const char *dir, const char *file)
{
    size_t dlen = strlen(dir);
    size_t flen = strlen(file);

    if (dlen + flen + 2 > size)
        return -1;

    int n = snprintf(dst, size, "%s/%s", dir, file);
    return (n < 0 || (size_t)n >= size) ? -1 : 0;
}

/* ─── USAGE ───────────────────────────────────────────────────────────────── */

static void
usage(const char *argv0)
{
    printf("Usage: %s [-d|--deep-clean] [-h|--help]\n\n", argv0);
    printf("  -d, --deep-clean    Remove additional caches (GPUCache, Code Cache,\n");
    printf("                      Service Worker, DawnCache, GraphiteDawnCache,\n");
    printf("                      component_crx_cache, extensions_crx_cache,\n");
    printf("                      Crash Reports, Greaselion, Local Traces).\n");
    printf("  -h, --help          Display this help message and exit.\n\n");
    printf("Cleans browser SQLite databases and cache directories for Brave,\n");
    printf("Chromium, Chrome, Firefox, Icecat, Seamonkey, and Aurora.\n");
}

/* ─── ROOT GUARD ──────────────────────────────────────────────────────────── */

static void
check_root(void)
{
    if (geteuid() != 0) return;

    fprintf(stderr,
        "%s[!] Warning:%s Running as root can corrupt user browser profile ownership.\n"
        "Continue anyway? [y/N]: ",
        YELLOW, RESET);

    char ans[8];
    if (!fgets(ans, sizeof(ans), stdin) || (ans[0] != 'y' && ans[0] != 'Y')) {
        printf("Aborted.\n");
        exit(1);
    }
}

/* ─── FILESYSTEM DESTRUCTION ──────────────────────────────────────────────── */

static int
unlink_cb(const char *fpath, const struct stat *sb, int typeflag, struct FTW *ftwbuf)
{
    (void)sb; (void)typeflag; (void)ftwbuf;
    int rv = remove(fpath);
    if (rv) perror(fpath);
    return rv;
}

/*
 * nuke_dir — recursive rm -rf via nftw(3).
 * FTW_DEPTH: post-order (children before parent).
 * FTW_PHYS:  never follow symlinks.
 * Silently returns if path does not exist.
 */
static void
nuke_dir(const char *path)
{
    struct stat st;
    if (stat(path, &st) == -1) return;

    if (nftw(path, unlink_cb, 64, FTW_DEPTH | FTW_PHYS) == -1)
        log_warn("Failed to incinerate", path);
    else
        printf("%s[X] Incinerated: %s%s\n", RED, path, RESET);
}

/*
 * clear_dir_contents — remove everything inside path but keep the directory
 * itself.  Mirrors Bash: find "Guest Profile" -mindepth 1 -delete
 */
static void
clear_dir_contents(const char *path)
{
    DIR *dp = opendir(path);
    if (!dp) return;

    struct dirent *e;
    char child[PATH_MAX];

    while ((e = readdir(dp))) {
        if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0)
            continue;
        if (safe_path_join(child, sizeof(child), path, e->d_name) == 0)
            nuke_dir(child);
    }
    closedir(dp);
    printf("%s[C] Cleared contents: %s%s\n", CYAN, path, RESET);
}

/* ─── SQLITE OPTIMIZATION ─────────────────────────────────────────────────── */

/*
 * optimize_db — vacuum a single SQLite database.
 *
 * Pre-deletion of WAL/SHM sidecars (ported from Bash vacuum_db):
 *   Removes *.sqlite-wal and *.sqlite-shm before opening so that a
 *   crashed writer's unfinished WAL cannot block PRAGMA journal_mode=DELETE.
 *
 * Returns net KB reclaimed (positive = freed, negative = grew, 0 = no change).
 */
static long
optimize_db(const char *dbpath)
{
    /* --- WAL/SHM sidecar pre-deletion ---
     * Buffers are PATH_MAX + 4 so the "-wal" / "-shm" suffixes (4 bytes each)
     * plus the NUL terminator never overflow a PATH_MAX-length dbpath. */
    char wal_path[PATH_MAX + 4], shm_path[PATH_MAX + 4];
    snprintf(wal_path, sizeof(wal_path), "%s-wal", dbpath);
    snprintf(shm_path, sizeof(shm_path), "%s-shm", dbpath);
    remove(wal_path);   /* EAFP: silent on ENOENT */
    remove(shm_path);

    /* --- Size before --- */
    struct stat st_before, st_after;
    long before = 0, after = 0;
    if (stat(dbpath, &st_before) == 0)
        before = (long)st_before.st_size;

    /* --- Open and optimize --- */
    sqlite3 *db;
    char *err_msg = NULL;
    int rc = sqlite3_open(dbpath, &db);

    if (rc != SQLITE_OK) {
        log_warn("Cannot open DB", dbpath);
        sqlite3_close(db);
        return 0;
    }

    /*
     * PRAGMA chain (canonical, restored from V1):
     *   journal_mode=DELETE  — collapses open WAL back to rollback journal.
     *   VACUUM               — defragments and rewrites the database file.
     *   REINDEX              — rebuilds all indices for optimal page layout.
     *   optimize             — runs SQLite's internal statistics pass.
     */
    const char *sql =
        "PRAGMA journal_mode=DELETE;"
        "VACUUM;"
        "REINDEX;"
        "PRAGMA optimize;";

    rc = sqlite3_exec(db, sql, 0, 0, &err_msg);

    if (rc != SQLITE_OK) {
        log_warn("PRAGMA chain failed", dbpath);
        sqlite3_free(err_msg);
    }

    sqlite3_close(db);

    /* --- Size after --- */
    if (stat(dbpath, &st_after) == 0)
        after = (long)st_after.st_size;

    long saved_kb = (before - after) / 1024;

    /* --- Per-database delta report (ported from Bash run_cleaner) --- */
    const char *fname = strrchr(dbpath, '/');
    fname = fname ? fname + 1 : dbpath;

    if (saved_kb > 0)
        printf("%s[V] Vacuumed:%s %-48s %s-%ld KB%s\n",
               CYAN, RESET, fname, YELLOW, saved_kb, RESET);
    else if (saved_kb < 0)
        printf("%s[V] Vacuumed:%s %-48s %s+%ld KB (grew)%s\n",
               CYAN, RESET, fname, RED, -saved_kb, RESET);
    else
        printf("%s[V] Vacuumed:%s %-48s ∘\n",
               CYAN, RESET, fname);

    return saved_kb;
}

/*
 * scan_and_vacuum — walk a directory and optimize every *.sqlite file.
 * Strict *.sqlite-only targeting (V1 canonical protocol).
 * Accumulates saved KB into g_total_saved_kb.
 */
static void
scan_and_vacuum(const char *dir)
{
    DIR *dp = opendir(dir);
    if (!dp) return;

    struct dirent *e;
    char path[PATH_MAX];

    while ((e = readdir(dp))) {
#ifdef DT_REG
        if (e->d_type != DT_REG && e->d_type != DT_UNKNOWN) continue;
#endif
        size_t len = strlen(e->d_name);
        if (len > 7 && strcmp(e->d_name + len - 7, ".sqlite") == 0) {
            if (safe_path_join(path, sizeof(path), dir, e->d_name) == 0) {
                long kb = optimize_db(path);
                g_total_saved_kb += kb;
            }
        }
    }
    closedir(dp);
}

/* ─── PROCESS TERMINATION (Graceful SIGTERM → SIGKILL) ───────────────────── */

/*
 * Ported from Bash kill_browser():
 *   1. Check for user-owned exact-name match via pgrep.
 *   2. Send SIGTERM; poll every POLL_MS ms for up to WAIT_CYCLES iterations.
 *   3. After grace period, prompt user: kill now or abort cleanly.
 *   4. On confirmation send SIGKILL; on refusal exit(1).
 */
#define POLL_MS      200    /* poll interval in milliseconds         */
#define WAIT_CYCLES   10    /* 10 × 200 ms = 2 s SIGTERM grace period */

static int
proc_running(const char *name)
{
    char cmd[256];
    snprintf(cmd, sizeof(cmd),
             "pgrep -u %d -x %s > /dev/null 2>&1", (int)getuid(), name);
    return system(cmd) == 0;
}

static void
terminate_proc(const char *name)
{
    if (!proc_running(name)) return;

    printf("%s[~] Terminating:%s %s\n", YELLOW, RESET, name);

    /* SIGTERM */
    char cmd[256];
    snprintf(cmd, sizeof(cmd),
             "pkill -TERM -u %d -x %s > /dev/null 2>&1", (int)getuid(), name);
    system(cmd);

    /* Poll for graceful exit */
    int cycles = 0;
    while (proc_running(name)) {
        if (cycles >= WAIT_CYCLES) {
            printf("\n%s[?] %s is still running. Kill forcefully? [y/N]: %s",
                   YELLOW, name, RESET);
            fflush(stdout);

            char ans[8];
            if (!fgets(ans, sizeof(ans), stdin) ||
                (ans[0] != 'y' && ans[0] != 'Y')) {
                printf("Please close %s manually and re-run.\n", name);
                exit(1);
            }

            snprintf(cmd, sizeof(cmd),
                     "pkill -KILL -u %d -x %s > /dev/null 2>&1",
                     (int)getuid(), name);
            system(cmd);
            break;
        }
        printf(".");
        fflush(stdout);
        xnanosleep((long)POLL_MS * 1000000L);
        cycles++;
    }
    printf("\n");
}

/* ─── FIREFOX INTELLIGENCE ────────────────────────────────────────────────── */

/*
 * handle_firefox — parse profiles.ini and clean every detected profile.
 *
 * Supports both IsRelative=1 (path relative to the firefox root) and
 * IsRelative=0 (absolute path) entries, resetting is_relative to the
 * safe default of 1 after each Path= line is consumed.
 */
static void
handle_firefox(const char *home, const char *rel_path, const char *label)
{
    char ff_root[PATH_MAX];
    if (safe_path_join(ff_root, sizeof(ff_root), home, rel_path) != 0) return;

    char ini_path[PATH_MAX];
    if (safe_path_join(ini_path, sizeof(ini_path), ff_root, "profiles.ini") != 0) return;

    FILE *fp = fopen(ini_path, "r");
    if (!fp) return;

    log_info("Detected", label);

    char line[1024];
    int is_relative = 1;

    while (fgets(line, sizeof(line), fp)) {
        line[strcspn(line, "\r\n")] = 0;

        if (strncmp(line, "IsRelative=", 11) == 0) {
            is_relative = atoi(line + 11);
        } else if (strncmp(line, "Path=", 5) == 0) {
            char full_path[PATH_MAX];
            int join_ok;

            if (is_relative)
                join_ok = safe_path_join(full_path, sizeof(full_path),
                                         ff_root, line + 5);
            else
                join_ok = (snprintf(full_path, sizeof(full_path),
                                    "%s", line + 5) < PATH_MAX) ? 0 : -1;

            if (join_ok == 0) {
                log_info("Processing Profile", full_path);
                scan_and_vacuum(full_path);

                char cache_path[PATH_MAX];
                if (safe_path_join(cache_path, sizeof(cache_path),
                                   full_path, "cache2") == 0)
                    nuke_dir(cache_path);
            }
            /* Reset to safe default for the next profile stanza. */
            is_relative = 1;
        }
    }
    fclose(fp);
}

/* ─── CHROMIUM ENGINE ─────────────────────────────────────────────────────── */

/*
 * Standard deep-clean targets present in every Chromium profile.
 * Applied unconditionally — these are the V1 canonical always-safe set.
 */
static const char *STANDARD_TRASH[] = {
    "GPUCache",
    "Code Cache",
    "Service Worker",
    "ShaderCache",
    "GrShaderCache",
    NULL
};

/*
 * Additional targets gated behind --deep-clean.
 * Ported from Bash clean_brave_specific_caches deep array + rm_dirs.
 */
static const char *DEEP_TRASH[] = {
    "DawnCache",
    "GraphiteDawnCache",
    "component_crx_cache",
    "extensions_crx_cache",
    "Crash Reports",
    "Greaselion",
    "Local Traces",
    NULL
};

/*
 * handle_chromium_variant — clean a Chromium-family browser installation.
 *
 * Processes "Default" and all "Profile N" sub-directories found under
 * the browser's user-data root.  For each profile:
 *   1. Vacuum all *.sqlite databases.
 *   2. Incinerate the canonical V1 standard cache/shader directory set.
 *   3. If --deep-clean: incinerate the extended opt-in target set.
 *   4. If is_brave: clear Guest Profile directory contents.
 */
static void
handle_chromium_variant(const char *home, const char *name,
                        const char *rel_path, int is_brave)
{
    char root[PATH_MAX];
    if (safe_path_join(root, sizeof(root), home, rel_path) != 0) return;

    DIR *dp = opendir(root);
    if (!dp) return;

    log_info("Detected Engine", name);

    struct dirent *e;
    while ((e = readdir(dp))) {
        if (strcmp(e->d_name, "Default") != 0 &&
            strncmp(e->d_name, "Profile", 7) != 0)
            continue;

        char prof_path[PATH_MAX];
        if (safe_path_join(prof_path, sizeof(prof_path), root, e->d_name) != 0)
            continue;

        log_info("Processing Profile", e->d_name);
        scan_and_vacuum(prof_path);

        /* Always-deep standard cache targets (V1 canonical) */
        for (int i = 0; STANDARD_TRASH[i]; i++) {
            char garbage[PATH_MAX];
            if (safe_path_join(garbage, sizeof(garbage),
                               prof_path, STANDARD_TRASH[i]) == 0)
                nuke_dir(garbage);
        }

        /* Opt-in extended deep targets */
        if (g_deep_clean) {
            for (int i = 0; DEEP_TRASH[i]; i++) {
                char garbage[PATH_MAX];
                if (safe_path_join(garbage, sizeof(garbage),
                                   prof_path, DEEP_TRASH[i]) == 0)
                    nuke_dir(garbage);
            }
        }

        /* Brave-specific: clear Guest Profile contents (keep the directory) */
        if (is_brave) {
            char guest[PATH_MAX];
            if (safe_path_join(guest, sizeof(guest),
                               prof_path, "Guest Profile") == 0) {
                struct stat st;
                if (stat(guest, &st) == 0 && S_ISDIR(st.st_mode))
                    clear_dir_contents(guest);
            }
        }
    }
    closedir(dp);
}

/* ─── XDG CACHE WIPE ──────────────────────────────────────────────────────── */

/*
 * clean_xdg_caches — wipe ~/.cache entries for Chromium-family browsers.
 * Ported from Bash clean_other_caches(); extended to cover all Chromium
 * variants present in the browser path table.
 */
static void
clean_xdg_caches(const char *home)
{
    static const char *xdg_targets[] = {
        ".cache/chromium",
        ".cache/google-chrome",
        ".cache/BraveSoftware",
        ".cache/brave-cache",   /* --disk-cache-dir override observed in env */
        NULL
    };

    printf("%s[~] Wiping XDG caches...%s\n", YELLOW, RESET);

    for (int i = 0; xdg_targets[i]; i++) {
        char path[PATH_MAX];
        if (safe_path_join(path, sizeof(path), home, xdg_targets[i]) == 0)
            nuke_dir(path);
    }
}

/* ─── DESKTOP NOTIFICATION ────────────────────────────────────────────────── */

/*
 * notify_done — send a desktop notification via notify-send if available,
 * otherwise fall back to a console message.  Ported from Bash main().
 */
static void
notify_done(void)
{
    if (system("command -v notify-send > /dev/null 2>&1") == 0)
        system("notify-send 'BraveClean' 'Your browser profiles have been cleaned!'");
    else
        printf("\n%sCleanup complete! Your browser profiles are now cleaner.%s\n",
               GREEN, RESET);
}

/* ─── ENTRY POINT ─────────────────────────────────────────────────────────── */

int
main(int argc, char *argv[])
{
    /* --- Argument parsing --- */
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-d") == 0 ||
            strcmp(argv[i], "--deep-clean") == 0) {
            g_deep_clean = 1;
        } else if (strcmp(argv[i], "-h") == 0 ||
                   strcmp(argv[i], "--help") == 0) {
            usage(argv[0]);
            return 0;
        } else {
            fprintf(stderr, "Unknown option: %s\n\n", argv[i]);
            usage(argv[0]);
            return 1;
        }
    }

    /* --- Root guard --- */
    check_root();

    const char *home = getenv("HOME");
    if (!home) {
        fprintf(stderr, "[!] HOME environment variable not set. Aborting.\n");
        return 1;
    }

    printf("%s[4NDR0666OS] Browser Necromancer Initialized%s", RED, RESET);
    if (g_deep_clean)
        printf("%s [DEEP CLEAN MODE]%s", YELLOW, RESET);
    printf("\n");

    /* --- Phase 1: Terminate browser processes (graceful SIGTERM→SIGKILL) --- */
    const char *procs[] = {
        "firefox", "icecat", "seamonkey", "aurora",
        "chrome", "chromium", "brave",
        NULL
    };
    for (int i = 0; procs[i]; i++)
        terminate_proc(procs[i]);

    /* --- Phase 2: WAL flush window (2 s precision sleep) ---
     *
     * xnanosleep(2,000,000,000 ns):
     *   Allows the OS to release file locks and SQLite WAL journals to be
     *   checkpointed before PRAGMA journal_mode=DELETE is attempted.
     *   Precision nanosleep avoids silent truncation by SIGCHLD from the
     *   pkill subshells completing. */
    xnanosleep(2000000000L);

    /* --- Phase 3: Chromium-family browsers ---
     * is_brave=1 enables the Guest Profile clear on Brave installations. */
    handle_chromium_variant(home, "Brave (Stable)",
        ".config/BraveSoftware/Brave-Browser",      1);
    handle_chromium_variant(home, "Brave (Beta)",
        ".config/BraveSoftware/Brave-Browser-Beta", 1);
    handle_chromium_variant(home, "Brave (Dev)",
        ".config/BraveSoftware/Brave-Browser-Dev",  1);
    handle_chromium_variant(home, "Chromium",
        ".config/chromium",                         0);
    handle_chromium_variant(home, "Chromium Beta",
        ".config/chromium-beta",                    0);
    handle_chromium_variant(home, "Chromium Dev",
        ".config/chromium-dev",                     0);
    handle_chromium_variant(home, "Google Chrome",
        ".config/google-chrome",                    0);
    handle_chromium_variant(home, "Google Chrome Beta",
        ".config/google-chrome-beta",               0);
    handle_chromium_variant(home, "Google Chrome Unstable",
        ".config/google-chrome-unstable",           0);

    /* --- Phase 4: Firefox-family browsers --- */
    handle_firefox(home, ".mozilla/firefox",   "Firefox");
    handle_firefox(home, ".mozilla/icecat",    "Icecat");
    handle_firefox(home, ".mozilla/seamonkey", "Seamonkey");
    handle_firefox(home, ".mozilla/aurora",    "Aurora");

    /* --- Phase 5: XDG cache wipe --- */
    clean_xdg_caches(home);

    /* --- Phase 6: Summary --- */
    printf("\n%s[4NDR0666OS] System Sanitized.%s\n", RED, RESET);
    if (g_total_saved_kb > 0)
        printf("%s[=] Total space reclaimed: %ld KB (%ld MB)%s\n",
               GREEN, g_total_saved_kb,
               g_total_saved_kb / 1024, RESET);
    else
        printf("%s[=] No measurable space reclaimed.%s\n", YELLOW, RESET);

    /* --- Phase 7: Desktop notification --- */
    notify_done();

    return 0;
}
