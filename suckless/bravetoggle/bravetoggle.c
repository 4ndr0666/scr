/*
 * bravetoggle.c — Pause/resume Brave Browser via SIGSTOP/SIGCONT
 * Version: 1.1.0 (Telemetry-Corrected)
 *
 * AUDIT FINDINGS FROM LIVE PROCESS TABLE (bravetoggle v1.0.0 was broken):
 *
 *   CRITICAL: Binary is /opt/brave.com/brave-beta/brave.
 *             Kernel comm (from /proc/<pid>/comm) is "brave", NOT "brave-browser".
 *             v1.0.0 matched zero processes on this system — toggle was a no-op.
 *
 *   CRITICAL: The launcher at /opt/brave.com/brave-beta/brave-browser is a
 *             shell script; its comm reads "bash". Never target it by comm.
 *
 *   FIXED:    comm target changed from "brave-browser" to "brave".
 *
 *   NEW:      Type-aware signal ordering derived from --type= flags observed
 *             in the process table. Incorrect ordering causes GPU command-queue
 *             stalls and IPC deadlocks on Chromium's multi-process architecture.
 *
 *   STOP order (safest — drain IPC queues from leaves to root):
 *     1. renderer      (leaf; no children, highest memory consumers)
 *     2. utility       (StorageService, NetworkService, AudioService)
 *     3. gpu-process   (104 min CPU observed; stop after renderers to drain cmds)
 *     4. zygote        (parent of renderers; stop after all children)
 *     5. broker        (single lightweight process)
 *     6. main (root)   (last; owns the top-level IPC channel)
 *
 *   CONT order (exact reverse — restore scheduler from root to leaves):
 *     1. main → broker → zygote → gpu-process → utility → renderer
 *
 *   EXCLUDED: chrome_crashpad_han (truncated at 15 chars by kernel TASK_COMM_LEN)
 *             Crashpad manages its own fd locks; sending SIGSTOP to it before
 *             the browser corrupts the crash-report database advisory lock.
 *             earlyoom has brave-beta in its --avoid list; no interference.
 *
 * Build: gcc -O2 bravetoggle.c -o bravetoggle
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/types.h>
#include <limits.h>
#include <ctype.h>

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

/* ─── DYNAMIC ANSI COLORS ─────────────────────────────────────────────────── */

static const char *
get_color(const char *code)
{
    if (isatty(STDOUT_FILENO)) return code;
    return "";
}

#define YELLOW  get_color("\033[33m")
#define GREEN   get_color("\033[32m")
#define RED     get_color("\033[31m")
#define CYAN    get_color("\033[36m")
#define RESET   get_color("\033[0m")

/* ─── PROCESS TYPE CLASSIFICATION ────────────────────────────────────────────
 *
 * Chromium spawns every child with --type=<class> in its argv.
 * We read /proc/<pid>/cmdline to extract this field and assign a stop-order
 * priority.  Lower priority number = stopped first, resumed last.
 *
 * Priority table (stop order: ascending, resume order: descending):
 *   0  renderer      — leaf nodes, most numerous, highest RSS
 *   1  utility       — storage/network/audio mojom services
 *   2  gpu-process   — GPU rasterization; drain after renderers
 *   3  zygote        — fork-server parent of renderers
 *   4  broker        — lightweight sandbox broker
 *   5  (main)        — no --type flag; root of the process tree
 *
 * Crashpad handler is excluded entirely (different comm value).
 */

typedef enum {
    BTYPE_RENDERER  = 0,
    BTYPE_UTILITY   = 1,
    BTYPE_GPU       = 2,
    BTYPE_ZYGOTE    = 3,
    BTYPE_BROKER    = 4,
    BTYPE_MAIN      = 5,
    BTYPE__COUNT    = 6
} BraveType;

static const char * const TYPE_LABELS[BTYPE__COUNT] = {
    "renderer", "utility", "gpu-process", "zygote", "broker", "main"
};

/* ─── PID RECORD ─────────────────────────────────────────────────────────── */

#define MAX_PIDS 512

typedef struct {
    pid_t     pid;
    BraveType type;
} BraveProc;

typedef struct {
    BraveProc procs[MAX_PIDS];
    int       count;
} ProcSet;

/* ─── /proc HELPERS ──────────────────────────────────────────────────────── */

/*
 * proc_read_field — scan /proc/<pid>/status for a "Key:" line and return
 * the value string (trimmed of leading whitespace) in buf.
 * Returns 0 on success, -1 if not found.
 */
static int
proc_read_field(pid_t pid, const char *key, char *buf, size_t bufsz)
{
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/status", (int)pid);

    FILE *fp = fopen(path, "r");
    if (!fp) return -1;

    char line[256];
    size_t klen = strlen(key);
    int found = -1;

    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, key, klen) == 0 && line[klen] == ':') {
            char *p = line + klen + 1;
            while (*p == ' ' || *p == '\t') p++;
            /* strip trailing newline */
            size_t len = strlen(p);
            while (len > 0 && (p[len-1] == '\n' || p[len-1] == '\r'))
                p[--len] = 0;
            snprintf(buf, bufsz, "%s", p);
            found = 0;
            break;
        }
    }
    fclose(fp);
    return found;
}

/* pid_state — returns the State char from /proc/<pid>/status, or 0. */
static char
pid_state(pid_t pid)
{
    char buf[64];
    if (proc_read_field(pid, "State", buf, sizeof(buf)) != 0) return 0;
    return buf[0];
}

/* pid_uid — returns the real UID from /proc/<pid>/status, or (uid_t)-1. */
static uid_t
pid_uid(pid_t pid)
{
    char buf[64];
    if (proc_read_field(pid, "Uid", buf, sizeof(buf)) != 0) return (uid_t)-1;
    return (uid_t)atoi(buf);
}

/* pid_ppid — returns PPid from /proc/<pid>/status, or -1. */
static pid_t
pid_ppid(pid_t pid)
{
    char buf[64];
    if (proc_read_field(pid, "PPid", buf, sizeof(buf)) != 0) return -1;
    return (pid_t)atoi(buf);
}

/*
 * comm_matches — returns 1 if /proc/<pid>/comm equals target exactly.
 *
 * TELEMETRY NOTE: The actual Brave binary comm is "brave" (the shell wrapper
 * brave-browser has comm "bash").  TASK_COMM_LEN is 16 bytes (15 + NUL), so
 * "chrome_crashpad_handler" is truncated to "chrome_crashpad_han" in comm —
 * it will never match "brave" and is automatically excluded.
 */
static int
comm_matches(pid_t pid, const char *target)
{
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/comm", (int)pid);

    FILE *fp = fopen(path, "r");
    if (!fp) return 0;

    char comm[64];
    int matched = 0;
    if (fgets(comm, sizeof(comm), fp)) {
        comm[strcspn(comm, "\r\n")] = 0;
        matched = (strcmp(comm, target) == 0);
    }
    fclose(fp);
    return matched;
}

/*
 * classify_type — read /proc/<pid>/cmdline and extract the --type=<val>
 * argument to determine which Chromium process class this PID belongs to.
 *
 * Returns BTYPE_MAIN if no --type= argument is found (the root browser
 * process is the only one launched without this flag).
 */
static BraveType
classify_type(pid_t pid)
{
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/cmdline", (int)pid);

    FILE *fp = fopen(path, "r");
    if (!fp) return BTYPE_MAIN;

    /*
     * cmdline uses NUL-separated argv[].  Read the whole thing and scan
     * for the "--type=" token.  We replace interior NULs with spaces so
     * strstr works across the whole buffer.
     */
    char buf[4096];
    size_t n = fread(buf, 1, sizeof(buf) - 1, fp);
    fclose(fp);
    buf[n] = 0;

    /* Replace NUL separators with spaces for strstr */
    for (size_t i = 0; i < n; i++) {
        if (buf[i] == '\0') buf[i] = ' ';
    }

    char *p = strstr(buf, "--type=");
    if (!p) return BTYPE_MAIN;

    p += 7; /* skip "--type=" */

    if (strncmp(p, "renderer",   8) == 0) return BTYPE_RENDERER;
    if (strncmp(p, "utility",    7) == 0) return BTYPE_UTILITY;
    if (strncmp(p, "gpu-process",11) == 0) return BTYPE_GPU;
    if (strncmp(p, "zygote",     6) == 0) return BTYPE_ZYGOTE;
    if (strncmp(p, "broker",     6) == 0) return BTYPE_BROKER;

    return BTYPE_MAIN;
}

/* ─── PID COLLECTION ──────────────────────────────────────────────────────── */

/*
 * collect_brave_procs — walk /proc and collect all PIDs owned by the current
 * user whose comm is exactly "brave".
 *
 * The shell-script launcher (/opt/brave.com/brave-beta/brave-browser) has
 * comm "bash" and is excluded automatically.  The crashpad handler has comm
 * "chrome_crashpad_han" (kernel-truncated) and is also excluded.
 */
static ProcSet
collect_brave_procs(void)
{
    ProcSet set = { .count = 0 };
    uid_t   my_uid = getuid();

    DIR *dp = opendir("/proc");
    if (!dp) return set;

    struct dirent *e;
    while ((e = readdir(dp)) && set.count < MAX_PIDS) {
        if (!isdigit((unsigned char)e->d_name[0])) continue;

        pid_t pid = (pid_t)atoi(e->d_name);
        if (pid <= 0)                     continue;
        if (pid_uid(pid) != my_uid)       continue;
        if (!comm_matches(pid, "brave"))  continue;

        set.procs[set.count].pid  = pid;
        set.procs[set.count].type = classify_type(pid);
        set.count++;
    }
    closedir(dp);
    return set;
}

/*
 * find_main_pid — the main browser process is the one with no --type= flag
 * (BTYPE_MAIN) whose parent is not also a "brave" process.
 * Falls back to the first BTYPE_MAIN entry, then to procs[0].
 */
static pid_t
find_main_pid(const ProcSet *set)
{
    /* Build a fast lookup table of all brave PIDs */
    pid_t brave_pids[MAX_PIDS];
    for (int i = 0; i < set->count; i++)
        brave_pids[i] = set->procs[i].pid;

    for (int i = 0; i < set->count; i++) {
        if (set->procs[i].type != BTYPE_MAIN) continue;

        pid_t ppid = pid_ppid(set->procs[i].pid);
        int parent_is_brave = 0;
        for (int j = 0; j < set->count; j++) {
            if (brave_pids[j] == ppid) { parent_is_brave = 1; break; }
        }
        if (!parent_is_brave) return set->procs[i].pid;
    }

    /* Fallback: first BTYPE_MAIN */
    for (int i = 0; i < set->count; i++)
        if (set->procs[i].type == BTYPE_MAIN) return set->procs[i].pid;

    return set->count > 0 ? set->procs[0].pid : -1;
}

/* ─── SIGNAL DISPATCH ────────────────────────────────────────────────────────
 *
 * send_by_type — deliver sig to all processes of a given BraveType.
 */
static void
send_by_type(const ProcSet *set, BraveType t, int sig)
{
    for (int i = 0; i < set->count; i++) {
        if (set->procs[i].type == t)
            kill(set->procs[i].pid, sig);
    }
}

/*
 * count_by_type — return number of processes of a given BraveType.
 */
static int
count_by_type(const ProcSet *set, BraveType t)
{
    int n = 0;
    for (int i = 0; i < set->count; i++)
        if (set->procs[i].type == t) n++;
    return n;
}

/*
 * dispatch_stop — signal all brave processes in safe stop order.
 *
 * Order: renderer → utility → gpu-process → zygote → broker → main
 *
 * Rationale: stopping the main process first would cause all children to
 * block on IPC calls to a parent that can never respond, creating a
 * distributed deadlock across the process group before SIGSTOP reaches them.
 * Stopping leaves first drains all in-flight IPC before the parent sleeps.
 */
static void
dispatch_stop(const ProcSet *set, pid_t main_pid)
{
    /* Stop-order priority 0..4 (leaf→root), then main */
    static const BraveType stop_order[] = {
        BTYPE_RENDERER, BTYPE_UTILITY, BTYPE_GPU, BTYPE_ZYGOTE, BTYPE_BROKER
    };

    for (int i = 0; i < (int)(sizeof(stop_order)/sizeof(stop_order[0])); i++) {
        int n = count_by_type(set, stop_order[i]);
        if (n > 0) {
            printf("%s[||] STOP %-12s × %d%s\n",
                   YELLOW, TYPE_LABELS[stop_order[i]], n, RESET);
            send_by_type(set, stop_order[i], SIGSTOP);
        }
    }
    /* Main last */
    printf("%s[||] STOP %-12s (pid %d)%s\n",
           YELLOW, "main", (int)main_pid, RESET);
    kill(main_pid, SIGSTOP);
}

/*
 * dispatch_cont — signal all brave processes in safe resume order.
 *
 * Order: main → broker → zygote → gpu-process → utility → renderer
 *
 * Rationale: the parent must be runnable before children can deliver
 * queued IPC responses.  GPU process is resumed before renderers so
 * the command queue is accepting submissions before renderers issue them.
 */
static void
dispatch_cont(const ProcSet *set, pid_t main_pid)
{
    static const BraveType cont_order[] = {
        BTYPE_BROKER, BTYPE_ZYGOTE, BTYPE_GPU, BTYPE_UTILITY, BTYPE_RENDERER
    };

    /* Main first */
    printf("%s[>]  CONT %-12s (pid %d)%s\n",
           GREEN, "main", (int)main_pid, RESET);
    kill(main_pid, SIGCONT);

    for (int i = 0; i < (int)(sizeof(cont_order)/sizeof(cont_order[0])); i++) {
        int n = count_by_type(set, cont_order[i]);
        if (n > 0) {
            printf("%s[>]  CONT %-12s × %d%s\n",
                   GREEN, TYPE_LABELS[cont_order[i]], n, RESET);
            send_by_type(set, cont_order[i], SIGCONT);
        }
    }
}

/* ─── ENTRY POINT ─────────────────────────────────────────────────────────── */

int
main(void)
{
    ProcSet set = collect_brave_procs();

    if (set.count == 0) {
        printf("%s[!] Brave is not running.%s\n", YELLOW, RESET);
        return 0;
    }

    pid_t main_pid = find_main_pid(&set);
    if (main_pid < 0) {
        fprintf(stderr, "%s[!] Could not identify main Brave process.%s\n",
                RED, RESET);
        return 1;
    }

    /* Print process inventory */
    printf("%s[i] Brave process inventory (%d total):%s\n",
           CYAN, set.count, RESET);
    for (int t = BTYPE__COUNT - 1; t >= 0; t--) {
        int n = count_by_type(&set, (BraveType)t);
        if (n > 0)
            printf("    %-14s × %d\n", TYPE_LABELS[t], n);
    }

    /*
     * T-state check on the main process only.
     * Reading /proc/<pid>/status is atomic — no pipeline race.
     */
    char state = pid_state(main_pid);

    if (state == 'T') {
        printf("%s[>] Resuming Brave (main pid %d)...%s\n",
               GREEN, (int)main_pid, RESET);
        dispatch_cont(&set, main_pid);
    } else {
        printf("%s[||] Pausing Brave (main pid %d)...%s\n",
               YELLOW, (int)main_pid, RESET);
        dispatch_stop(&set, main_pid);
    }

    return 0;
}
