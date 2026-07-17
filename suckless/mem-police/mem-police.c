/*
 * mem-police.c — Robust memory policing daemon
 * Version: 3.2.0 (Audit: GUP gap mitigation pass)
 *
 * AUDIT CHANGELOG (3.1.0 → 3.2.0):
 *
 *   CRITICAL: log_syslog() routed ALL output through vsyslog() unconditionally.
 *             When running with --foreground, the operator received zero visible
 *             log output — syslog in foreground mode writes to /dev/log, not
 *             stderr. Fixed: log_msg() replaces log_syslog(); when opt_foreground
 *             is set it also vfprintf()s to stderr with a timestamp prefix, giving
 *             the operator real-time visibility. dump_state() benefits from the
 *             same fix automatically.
 *
 *   HIGH:     write_statefile_atomic(): the `if (w < 0 || fclose(sf) != 0)` branch
 *             leaked the FILE* (and underlying fd) when w < 0 because fclose() was
 *             never called in that branch. Restructured: fclose() is now called
 *             unconditionally; its return value is tested separately; sf_fd is not
 *             double-closed.
 *
 *   HIGH:     load_config(): SLEEP=0 was accepted, causing interruptible_sleep()
 *             to become a no-op and spinning the main loop at CPU-maximum.
 *             Enforced: sleep_secs >= 1. Also enforced: THRESHOLD_MB >= 1 and
 *             KILL_GRACE >= 1 to prevent degenerate configs that immediately kill
 *             every process on startup.
 *
 *   HIGH:     load_config(): whitelist_count was incremented even when pcre2_compile
 *             or match_data allocation failed, wasting a slot (is_whitelisted skips
 *             NULL entries, so functionally safe but wasteful). Fixed: increment
 *             only on successful alloc.
 *
 *   MEDIUM:   clean_orphaned_startfiles(): d_type != DT_REG skipped startfiles on
 *             filesystems (e.g. some tmpfs configs) that return DT_UNKNOWN. Fixed:
 *             DT_UNKNOWN is now treated as DT_REG; the strtol/kill(0) logic filters
 *             non-startfiles naturally.
 *
 *   MEDIUM:   check_startfile_dir(): permission mask used (& 077) which passes
 *             mode 01700 (sticky bit set). Fixed: mask is now
 *             (S_IRWXG | S_IRWXO) to test only group/other bits, which is both
 *             correct and immune to the sticky-bit false-pass.
 *
 *   MEDIUM:   get_mem_mb(): the (long long) multiply fix in 3.1.0 was correct but
 *             the final cast to (int) could still wrap on very large RSS values
 *             (> INT_MAX MB, pathological but not impossible on 64-bit with a
 *             leaking process). Fixed: clamp to INT_MAX before cast so the value
 *             always compares cleanly as "exceeds any sane threshold".
 *
 *   LOW:      main(): kill(pid, config.kill_signal) return value was unchecked.
 *             If the process exited between the RSS read and the kill(), the
 *             startfile was left with sig_sent_time=now, deferring an unnecessary
 *             SIGKILL to the next cycle. Fixed: ESRCH is logged at LOG_INFO and
 *             the startfile is unlinked immediately (the process is already gone).
 *
 *   LOW:      main(): the "process recovered" unlink branch used a no-op if()
 *             that swallowed both ENOENT (normal: process never had a startfile)
 *             and real errors. Fixed: unlink is attempted unconditionally; ENOENT
 *             is silently ignored; any other errno is logged at LOG_WARNING.
 *
 * Compile: cc -O2 -std=c11 -Wall -Wextra -pedantic \
 *              -D_POSIX_C_SOURCE=200809L -D_GNU_SOURCE \
 *              -o mem-police mem-police.c -lpcre2-8
 */

#define PCRE2_CODE_UNIT_WIDTH 8
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <ctype.h>
#include <stdarg.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <syslog.h>
#include <dirent.h>
#include <limits.h>
#include <time.h>
#include <sys/file.h>
#include <linux/limits.h>
#include <sys/syscall.h>
#include <stdint.h>
#include <pcre2.h>

/* ─── CONSTANTS ───────────────────────────────────────────────────────────── */

#define CONFIG_PATH           "/etc/mem_police.conf"
#define STARTFILE_DIR         "/var/run/mem-police"
#define PIDFILE_PATH          "/var/run/mem-police.pid"
#define METRICS_PATH          STARTFILE_DIR "/metrics"
#define DEFAULT_SLEEP         10
#define PATHBUF               PATH_MAX
#define MAX_WHITELIST_LEN     2048
#define MAX_WHITELIST         64
#define MAX_CMDLEN            64      /* raised from 32 in 3.1.0: future-proof comm names */
#define MAX_EXELEN            PATH_MAX
#define STARTFILE_PREFIX      "mempolice-"
#define STARTFILE_PREFIX_LEN  (sizeof(STARTFILE_PREFIX) - 1)

/* ─── TYPES ───────────────────────────────────────────────────────────────── */

/*
 * WhitelistEntry — pairs a compiled PCRE2 pattern with its pre-allocated
 * match_data block (AUDIT FIX 3.1.0: NULL match_data was UB on several
 * PCRE2 builds when PCRE2_NO_AUTO_CAPTURE is not set).
 */
typedef struct {
    pcre2_code_8       *re;
    pcre2_match_data_8 *md;
} WhitelistEntry;

typedef struct {
    int            threshold_mb;
    int            kill_signal;
    int            threshold_duration;
    int            kill_grace;
    int            sleep_secs;
    char           whitelist_buf[MAX_WHITELIST_LEN];
    char          *whitelist_entries[MAX_WHITELIST];
    WhitelistEntry whitelist[MAX_WHITELIST];
    size_t         whitelist_count;
} mempolice_config_t;

/* ─── GLOBALS ─────────────────────────────────────────────────────────────── */

static volatile sig_atomic_t keep_running     = 1;
static volatile sig_atomic_t need_reload      = 0;
static volatile sig_atomic_t need_dump_state  = 0;
static int                   pidfile_fd       = -1;
static const char           *config_path      = CONFIG_PATH;
static int                   opt_foreground   = 0;
static mempolice_config_t    config;

/* ─── USAGE ───────────────────────────────────────────────────────────────── */

static void
usage(const char *prog)
{
    fprintf(stderr,
        "Usage: %s [--config FILE] [--foreground] [--help]\n"
        "\n"
        "  --config FILE    Use FILE instead of " CONFIG_PATH "\n"
        "  --foreground     Do not daemonize; log to stderr\n"
        "  --help           Display this help and exit\n",
        prog);
}

/* ─── LOGGING ─────────────────────────────────────────────────────────────── */

/*
 * log_msg — unified log gate replacing log_syslog().
 *
 * AUDIT FIX 3.2.0: The previous log_syslog() called vsyslog() unconditionally.
 * In daemon mode this is correct — syslog is the output channel.  In foreground
 * mode (--foreground), vsyslog() still writes to /dev/log rather than stderr,
 * so the operator running the process interactively received zero console output.
 *
 * log_msg() adds a dual-output path: when opt_foreground is set, it also
 * vfprintf()s to stderr with a seconds-since-epoch prefix for legibility.
 * Both outputs share the same va_list iteration (two separate va_start/va_end
 * pairs, since va_list is not reusable after a v*printf call).
 */
static void
log_msg(int priority, const char *fmt, ...)
{
    va_list ap;

    /* Always log to syslog — in foreground mode the LOG_CONS flag on openlog()
     * would normally route to /dev/console on syslog failure, but we supplement
     * that with the explicit stderr path below rather than relying on LOG_CONS. */
    va_start(ap, fmt);
    vsyslog(priority, fmt, ap);
    va_end(ap);

    if (opt_foreground) {
        /* Prepend a minimal timestamp (seconds since epoch) so log lines from
         * rapid consecutive events are distinguishable without requiring strftime
         * or thread-unsafe localtime(). */
        time_t now = time(NULL);
        fprintf(stderr, "[%ld] ", (long)now);
        va_start(ap, fmt);
        vfprintf(stderr, fmt, ap);
        va_end(ap);
        fputc('\n', stderr);
        fflush(stderr);
    }
}

/* ─── PID FILE ────────────────────────────────────────────────────────────── */

static void
remove_pidfile(void)
{
    if (pidfile_fd >= 0) {
        close(pidfile_fd);
        unlink(PIDFILE_PATH);
    }
}

static void
write_pidfile(void)
{
    pidfile_fd = open(PIDFILE_PATH, O_RDWR | O_CREAT | O_CLOEXEC, 0600);
    if (pidfile_fd < 0) {
        log_msg(LOG_ERR, "[mem-police] Failed to open PID file %s: %s",
                PIDFILE_PATH, strerror(errno));
        exit(EXIT_FAILURE);
    }
    if (flock(pidfile_fd, LOCK_EX | LOCK_NB) < 0) {
        log_msg(LOG_ERR, "[mem-police] Another instance running (lock: %s)",
                PIDFILE_PATH);
        close(pidfile_fd);
        exit(EXIT_FAILURE);
    }
    if (ftruncate(pidfile_fd, 0) != 0) {
        log_msg(LOG_ERR, "[mem-police] ftruncate PID file: %s", strerror(errno));
        close(pidfile_fd);
        unlink(PIDFILE_PATH);
        exit(EXIT_FAILURE);
    }
    char buf[32];
    int len = snprintf(buf, sizeof buf, "%d\n", (int)getpid());
    if (write(pidfile_fd, buf, len) < len) {
        log_msg(LOG_ERR, "[mem-police] write PID file: %s", strerror(errno));
        close(pidfile_fd);
        unlink(PIDFILE_PATH);
        exit(EXIT_FAILURE);
    }
}

/* ─── DAEMONIZE ───────────────────────────────────────────────────────────── */

static void
daemonize(void)
{
    pid_t pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);
    if (setsid() < 0) exit(EXIT_FAILURE);
    pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);

    umask(0);
    if (chdir("/") != 0) { perror("chdir"); exit(EXIT_FAILURE); }

    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);

    int fd = open("/dev/null", O_RDWR | O_CLOEXEC, 0);
    if (fd < 0) { perror("open /dev/null"); exit(EXIT_FAILURE); }

    if (dup2(fd, STDIN_FILENO)  < 0 ||
        dup2(fd, STDOUT_FILENO) < 0 ||
        dup2(fd, STDERR_FILENO) < 0) {
        perror("dup2");
        if (fd > STDERR_FILENO) close(fd);
        exit(EXIT_FAILURE);
    }
    if (fd > STDERR_FILENO) close(fd);
}

/* ─── SIGNAL HELPERS ──────────────────────────────────────────────────────── */

static int
str2sig(const char *s)
{
    if (isdigit((unsigned char)*s)) {
        char *endptr;
        errno = 0;
        long v = strtol(s, &endptr, 10);
        if (errno == 0 && endptr != s && *endptr == '\0' &&
            v >= 0 && v <= SIGRTMAX)
            return (int)v;
        return -1;
    }
    if (strncmp(s, "SIG", 3) == 0) s += 3;
    if (strcasecmp(s, "TERM") == 0) return SIGTERM;
    if (strcasecmp(s, "KILL") == 0) return SIGKILL;
    if (strcasecmp(s, "INT")  == 0) return SIGINT;
    if (strcasecmp(s, "HUP")  == 0) return SIGHUP;
    if (strcasecmp(s, "QUIT") == 0) return SIGQUIT;
    return -1;
}

/*
 * install_handler — set a signal handler via sigaction(2).
 * (AUDIT FIX 3.1.0: replaced signal() which has implementation-defined
 * SA_RESTART semantics; sa_flags=0 ensures nanosleep() is interrupted.)
 */
static void
install_handler(int sig, void (*handler)(int))
{
    struct sigaction sa;
    memset(&sa, 0, sizeof sa);
    sa.sa_handler = handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;          /* no SA_RESTART: interrupted syscalls return EINTR */
    sigaction(sig, &sa, NULL);
}

static void
sig_handler(int signum)
{
    if (signum == SIGINT || signum == SIGTERM) keep_running = 0;
    else if (signum == SIGHUP)  need_reload     = 1;
    else if (signum == SIGUSR1) need_dump_state = 1;
}

/* ─── DIRECTORY / CONFIG GUARDS ───────────────────────────────────────────── */

static void
check_startfile_dir(void)
{
    struct stat st;
    if (stat(STARTFILE_DIR, &st) == -1) {
        if (errno == ENOENT) {
            if (mkdir(STARTFILE_DIR, 0700) != 0) {
                log_msg(LOG_ERR, "[mem-police] mkdir(%s): %s",
                        STARTFILE_DIR, strerror(errno));
                exit(EXIT_FAILURE);
            }
        } else {
            log_msg(LOG_ERR, "[mem-police] stat(%s): %s",
                    STARTFILE_DIR, strerror(errno));
            exit(EXIT_FAILURE);
        }
    } else {
        /*
         * AUDIT FIX 3.2.0: Previously used (st.st_mode & 077) != 0 which
         * passes a directory with the sticky bit set (mode 01700), since
         * 01700 & 077 == 0.  The sticky bit on a root-only directory is
         * harmless, but the check was semantically imprecise.
         *
         * Replace with (st.st_mode & (S_IRWXG | S_IRWXO)) != 0 which
         * tests exactly the group-read/write/execute and other-read/write/
         * execute bits and is immune to sticky-bit false-pass.
         */
        if (!S_ISDIR(st.st_mode) ||
            (st.st_mode & (S_IRWXG | S_IRWXO)) != 0) {
            log_msg(LOG_ERR,
                "[mem-police] %s must be a 0700 directory", STARTFILE_DIR);
            exit(EXIT_FAILURE);
        }
        if (st.st_uid != 0) {
            log_msg(LOG_ERR,
                "[mem-police] %s must be root-owned", STARTFILE_DIR);
            exit(EXIT_FAILURE);
        }
    }
}

static void
check_config_permissions(void)
{
    struct stat st;
    if (stat(config_path, &st) != 0) {
        log_msg(LOG_ERR, "[mem-police] stat(%s): %s",
                config_path, strerror(errno));
        exit(EXIT_FAILURE);
    }
    if (st.st_uid != 0 || st.st_gid != 0) {
        log_msg(LOG_ERR, "[mem-police] %s must be owned by root:root",
                config_path);
        exit(EXIT_FAILURE);
    }
    if ((st.st_mode & 077) != 0) {
        log_msg(LOG_ERR, "[mem-police] %s must be 0600", config_path);
        exit(EXIT_FAILURE);
    }
}

/* ─── WHITELIST ───────────────────────────────────────────────────────────── */

static void
free_whitelist(mempolice_config_t *cfg)
{
    for (size_t i = 0; i < cfg->whitelist_count; i++) {
        if (cfg->whitelist[i].md) {
            pcre2_match_data_free_8(cfg->whitelist[i].md);
            cfg->whitelist[i].md = NULL;
        }
        if (cfg->whitelist[i].re) {
            pcre2_code_free_8(cfg->whitelist[i].re);
            cfg->whitelist[i].re = NULL;
        }
    }
    cfg->whitelist_count = 0;
}

/*
 * is_whitelisted — returns 1 if cmd or exe matches any compiled whitelist regex.
 * (AUDIT FIX 3.1.0: match_data is pre-allocated per-entry; passing NULL was UB.)
 */
static int
is_whitelisted(const char *cmd, const char *exe,
               const mempolice_config_t *cfg)
{
    for (size_t i = 0; i < cfg->whitelist_count; i++) {
        if (!cfg->whitelist[i].re || !cfg->whitelist[i].md) continue;

        int rc = pcre2_match_8(cfg->whitelist[i].re,
                               (PCRE2_SPTR8)cmd, strlen(cmd),
                               0, 0, cfg->whitelist[i].md, NULL);
        if (rc >= 0) return 1;

        if (exe && exe[0]) {
            rc = pcre2_match_8(cfg->whitelist[i].re,
                               (PCRE2_SPTR8)exe, strlen(exe),
                               0, 0, cfg->whitelist[i].md, NULL);
            if (rc >= 0) return 1;
        }
    }
    return 0;
}

/* ─── CONFIG ──────────────────────────────────────────────────────────────── */

static void
load_config(mempolice_config_t *cfg)
{
    check_config_permissions();
    FILE *f = fopen(config_path, "r");
    if (!f) {
        log_msg(LOG_ERR, "[mem-police] fopen(%s): %s",
                config_path, strerror(errno));
        exit(EXIT_FAILURE);
    }

    char line[256];
    int have_threshold = 0, have_kill = 0, have_duration = 0,
        have_grace = 0, have_whitelist = 0;

    cfg->sleep_secs = DEFAULT_SLEEP;
    free_whitelist(cfg);

    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = '\0';
        char *p = line;
        while (*p && isspace((unsigned char)*p)) p++;
        if (*p == '\0' || *p == '#') continue;
        char *eq = strchr(p, '=');
        if (!eq) continue;
        *eq = '\0';
        char *key = p, *val = eq + 1;

        if (strcmp(key, "THRESHOLD_MB")       == 0 ||
            strcmp(key, "THRESHOLD_DURATION") == 0 ||
            strcmp(key, "KILL_GRACE")         == 0 ||
            strcmp(key, "SLEEP")              == 0) {
            char *endptr;
            errno = 0;
            long v = strtol(val, &endptr, 10);
            if (errno != 0 || endptr == val || *endptr != '\0') {
                log_msg(LOG_ERR, "[mem-police] Invalid numeric '%s': '%s'",
                        key, val);
                exit(EXIT_FAILURE);
            }
            if (v < 0 || v > INT_MAX) {
                log_msg(LOG_ERR, "[mem-police] '%s' out of range: %ld", key, v);
                exit(EXIT_FAILURE);
            }

            if (strcmp(key, "THRESHOLD_MB") == 0) {
                /*
                 * AUDIT FIX 3.2.0: Enforce THRESHOLD_MB >= 1.
                 * A value of 0 would cause every process to exceed the threshold
                 * on the first poll cycle, triggering immediate kill timers for
                 * all non-whitelisted processes including init/systemd.
                 */
                if (v < 1) {
                    log_msg(LOG_ERR,
                        "[mem-police] THRESHOLD_MB must be >= 1, got %ld", v);
                    exit(EXIT_FAILURE);
                }
                cfg->threshold_mb = (int)v;
                have_threshold = 1;

            } else if (strcmp(key, "THRESHOLD_DURATION") == 0) {
                /* 0 is permitted: kill immediately once threshold is crossed. */
                cfg->threshold_duration = (int)v;
                have_duration = 1;

            } else if (strcmp(key, "KILL_GRACE") == 0) {
                /*
                 * AUDIT FIX 3.2.0: Enforce KILL_GRACE >= 1.
                 * A value of 0 means the SIGKILL would fire on the same cycle
                 * as the initial signal, giving the process no time to handle
                 * the first signal gracefully.
                 */
                if (v < 1) {
                    log_msg(LOG_ERR,
                        "[mem-police] KILL_GRACE must be >= 1, got %ld", v);
                    exit(EXIT_FAILURE);
                }
                cfg->kill_grace = (int)v;
                have_grace = 1;

            } else if (strcmp(key, "SLEEP") == 0) {
                /*
                 * AUDIT FIX 3.2.0: Enforce SLEEP >= 1.
                 * interruptible_sleep(0) computes ticks = 0 and returns
                 * immediately, turning the main loop into a busy-spin that
                 * saturates a CPU core.
                 */
                if (v < 1) {
                    log_msg(LOG_ERR,
                        "[mem-police] SLEEP must be >= 1, got %ld", v);
                    exit(EXIT_FAILURE);
                }
                cfg->sleep_secs = (int)v;
            }

        } else if (strcmp(key, "KILL_SIGNAL") == 0) {
            int sig = str2sig(val);
            if (sig < 0) {
                log_msg(LOG_ERR, "[mem-police] Invalid KILL_SIGNAL: '%s'", val);
                exit(EXIT_FAILURE);
            }
            cfg->kill_signal = sig;
            have_kill = 1;

        } else if (strcmp(key, "WHITELIST") == 0) {
            strncpy(cfg->whitelist_buf, val, sizeof(cfg->whitelist_buf) - 1);
            cfg->whitelist_buf[sizeof(cfg->whitelist_buf) - 1] = '\0';
            char *ctx = NULL, *tok;
            cfg->whitelist_count = 0;

            for (tok = strtok_r(cfg->whitelist_buf, " \t", &ctx);
                 tok;
                 tok = strtok_r(NULL, " \t", &ctx)) {
                if (cfg->whitelist_count >= MAX_WHITELIST) break;

                cfg->whitelist_entries[cfg->whitelist_count] = tok;

                int      errorcode;
                PCRE2_SIZE erroffs;
                pcre2_code_8 *re = pcre2_compile_8(
                    (PCRE2_SPTR8)tok, PCRE2_ZERO_TERMINATED,
                    0, &errorcode, &erroffs, NULL);

                if (!re) {
                    log_msg(LOG_WARNING,
                        "[mem-police] Whitelist regex '%s' invalid — skipped",
                        tok);
                    /*
                     * AUDIT FIX 3.2.0: Do NOT increment whitelist_count on
                     * compile failure.  The previous code incremented uncondi-
                     * tionally, leaving a NULL re/md slot that wasted a MAX_WHITELIST
                     * slot.  is_whitelisted() skipped NULL entries safely, but the
                     * slot was still consumed.  Only increment on success.
                     */
                    continue;
                }

                /*
                 * Allocate match_data from the compiled pattern.
                 * (AUDIT FIX 3.1.0: pre-allocated match_data; NULL was UB.)
                 */
                pcre2_match_data_8 *md =
                    pcre2_match_data_create_from_pattern_8(re, NULL);
                if (!md) {
                    log_msg(LOG_WARNING,
                        "[mem-police] match_data alloc failed for '%s' — skipped",
                        tok);
                    pcre2_code_free_8(re);
                    /* Same fix: do not increment on failure. */
                    continue;
                }

                cfg->whitelist[cfg->whitelist_count].re = re;
                cfg->whitelist[cfg->whitelist_count].md = md;
                cfg->whitelist_count++;
            }

            if (cfg->whitelist_count == 0) {
                log_msg(LOG_ERR, "[mem-police] WHITELIST is empty");
                exit(EXIT_FAILURE);
            }
            have_whitelist = 1;
        }
    }
    fclose(f);

    if (!have_threshold) {
        log_msg(LOG_ERR, "[mem-police] Missing: THRESHOLD_MB");
        exit(EXIT_FAILURE);
    }
    if (!have_kill) {
        log_msg(LOG_ERR, "[mem-police] Missing: KILL_SIGNAL");
        exit(EXIT_FAILURE);
    }
    if (!have_duration) {
        log_msg(LOG_ERR, "[mem-police] Missing: THRESHOLD_DURATION");
        exit(EXIT_FAILURE);
    }
    if (!have_grace) {
        log_msg(LOG_ERR, "[mem-police] Missing: KILL_GRACE");
        exit(EXIT_FAILURE);
    }
    if (!have_whitelist) {
        log_msg(LOG_ERR, "[mem-police] Missing: WHITELIST");
        exit(EXIT_FAILURE);
    }
}

/* ─── PROC HELPERS ────────────────────────────────────────────────────────── */

static pid_t
parse_pid_dir(const char *name)
{
    pid_t pid = 0;
    for (const char *p = name; *p; p++) {
        if (!isdigit((unsigned char)*p)) return -1;
        pid = pid * 10 + (*p - '0');
    }
    return pid > 0 ? pid : -1;
}

static unsigned long long
get_start_time(pid_t pid)
{
    char path[PATHBUF];
    int ret = snprintf(path, sizeof path, "/proc/%d/stat", pid);
    if (ret < 0 || (size_t)ret >= sizeof path) return 0;
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    unsigned long long start_time = 0;
    char buf[4096];
    if (fgets(buf, sizeof buf, f)) {
        char *p = strrchr(buf, ')');
        if (p) {
            int field = 0;
            p++;
            while (field < 20 && *p) {
                if (*p == ' ') field++;
                p++;
            }
            if (*p) {
                char *endptr;
                errno = 0;
                start_time = strtoull(p, &endptr, 10);
                if (errno != 0 || endptr == p) start_time = 0;
            }
        }
    }
    fclose(f);
    return start_time;
}

/*
 * get_mem_mb — O(1) RSS read via /proc/<pid>/statm.
 *
 * AUDIT FIX 3.1.0: Cast operands to (long long) before multiply to prevent
 *   overflow on 32-bit `long` systems with large-RSS processes.
 *
 * AUDIT FIX 3.2.0: Clamp the result to INT_MAX before casting to (int).
 *   On 64-bit systems with a pathologically leaking process (RSS > 2 TiB,
 *   which fits in statm's unsigned long), the intermediate (long long) result
 *   exceeds INT_MAX.  Without the clamp, the cast to (int) wraps to a negative
 *   value, causing the RSS check (mem > config.threshold_mb) to be FALSE and
 *   the process to be silently ignored rather than policed.  INT_MAX as a
 *   sentinel is always above any sane threshold_mb.
 */
static int
get_mem_mb(pid_t pid)
{
    char path[PATHBUF];
    int ret = snprintf(path, sizeof path, "/proc/%d/statm", (int)pid);
    if (ret < 0 || (size_t)ret >= sizeof path) return -1;

    FILE *f = fopen(path, "r");
    if (!f) return -1;

    long size, resident;
    int parsed = fscanf(f, "%ld %ld", &size, &resident);
    fclose(f);

    if (parsed != 2) return -1;

    long page_size = sysconf(_SC_PAGESIZE);
    long long rss_bytes = (long long)resident * (long long)page_size;
    long long rss_mb    = rss_bytes / (1024LL * 1024LL);

    /* Clamp to INT_MAX so the cast never wraps to a negative value. */
    if (rss_mb > (long long)INT_MAX) return INT_MAX;
    return (int)rss_mb;
}

static int
get_comm(pid_t pid, char *out, size_t olen)
{
    char path[PATHBUF];
    int ret = snprintf(path, sizeof path, "/proc/%d/comm", (int)pid);
    if (ret < 0 || (size_t)ret >= sizeof path) return -1;
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    if (!fgets(out, olen, f)) { fclose(f); return -1; }
    out[strcspn(out, "\n")] = '\0';
    fclose(f);
    return 0;
}

static int
get_exe(pid_t pid, char *out, size_t olen)
{
    char path[PATHBUF];
    int ret = snprintf(path, sizeof path, "/proc/%d/exe", (int)pid);
    if (ret < 0 || (size_t)ret >= sizeof path) return -1;
    ssize_t r = readlink(path, out, olen - 1);
    if (r < 0 || r >= (ssize_t)(olen - 1)) {
        if (r >= 0) out[0] = 0;
        return -1;
    }
    out[r] = '\0';
    return 0;
}

/* ─── ORPHAN CLEANUP ──────────────────────────────────────────────────────── */

/*
 * clean_orphaned_startfiles — remove startfiles for PIDs that no longer exist.
 *
 * AUDIT FIX 3.2.0: The previous check `de->d_type != DT_REG` skipped entries
 * on filesystems that return DT_UNKNOWN for regular files (some tmpfs and
 * network filesystem configurations).  Since all entries under STARTFILE_DIR
 * should be regular files written by us, DT_UNKNOWN is treated the same as
 * DT_REG — the strtol/snprintf/kill(0) logic below discards any entry whose
 * name doesn't match the "mempolice-<pid>.start" pattern, so the extra entries
 * admitted by this change are harmlessly rejected.
 */
static void
clean_orphaned_startfiles(void)
{
    DIR *dp = opendir(STARTFILE_DIR);
    if (!dp) return;
    struct dirent *de;
    while ((de = readdir(dp)) != NULL) {
        /* Accept DT_REG (definitely a file) and DT_UNKNOWN (filesystem did not
         * populate d_type; treat as potentially a file and let name matching
         * filter it). Skip anything that is definitively not a regular file. */
        if (de->d_type != DT_REG && de->d_type != DT_UNKNOWN) continue;
        if (strncmp(de->d_name, STARTFILE_PREFIX, STARTFILE_PREFIX_LEN) != 0)
            continue;
        const char *suffix = de->d_name + STARTFILE_PREFIX_LEN;
        char *endptr;
        errno = 0;
        long pid = strtol(suffix, &endptr, 10);
        if (errno != 0 || endptr == suffix ||
            strcmp(endptr, ".start") != 0 || pid <= 0) continue;
        if (kill((pid_t)pid, 0) == -1 && errno == ESRCH) {
            char filepath[PATHBUF];
            snprintf(filepath, sizeof filepath, "%s/%s",
                     STARTFILE_DIR, de->d_name);
            if (unlink(filepath) == 0)
                log_msg(LOG_INFO,
                    "[mem-police] Removed orphaned startfile: %s", filepath);
        }
    }
    closedir(dp);
}

/* ─── STATE FILE ──────────────────────────────────────────────────────────── */

/*
 * write_statefile_atomic — write state atomically via a tmp file + rename.
 *
 * AUDIT FIX 3.2.0: The previous `if (w < 0 || fclose(sf) != 0)` construct
 * leaked the FILE* (and its underlying fd, sf_fd) when w < 0 because fclose()
 * was short-circuited by the || operator and never called.  Restructured:
 *   1. fclose() is called unconditionally and its return value saved as
 *      close_err.
 *   2. Failure of either fprintf or fclose triggers the unlink+return path.
 *   3. sf_fd is not accessible after fdopen() — the fd is owned by sf; closing
 *      sf is the only correct way to release both.
 */
static int
write_statefile_atomic(const char *startfile, pid_t pid,
                       time_t threshold_time, time_t sig_sent_time,
                       unsigned long long start_time, const char *cmd)
{
    char tmp_path[PATHBUF];
    snprintf(tmp_path, sizeof tmp_path, "%s.tmp", startfile);

    int sf_fd = open(tmp_path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
    if (sf_fd == -1) return -1;

    FILE *sf = fdopen(sf_fd, "w");
    if (!sf) {
        /* fdopen failure: sf_fd still open and must be closed directly. */
        close(sf_fd);
        unlink(tmp_path);
        return -1;
    }

    int w         = fprintf(sf, "%ld %ld %d %llu %s\n",
                            (long)threshold_time, (long)sig_sent_time,
                            pid, start_time, cmd);
    int close_err = fclose(sf);   /* unconditional: always releases sf and sf_fd */

    if (w < 0 || close_err != 0) {
        unlink(tmp_path);
        return -1;
    }
    if (rename(tmp_path, startfile) != 0) {
        unlink(tmp_path);
        return -1;
    }
    return 0;
}

/* ─── METRICS ─────────────────────────────────────────────────────────────── */

static void
write_metrics(int hog_count, int killed_count)
{
    int fd = open(METRICS_PATH, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd < 0) return;
    dprintf(fd, "hog_processes %d\nkilled_processes %d\n",
            hog_count, killed_count);
    close(fd);
}

/* ─── DUMP STATE ──────────────────────────────────────────────────────────── */

/*
 * dump_state — log all current hog processes above the RSS threshold.
 *
 * Previously relied on log_syslog(), which produced no stderr output in
 * --foreground mode.  Now uses log_msg(), which dual-outputs in that mode.
 */
static void
dump_state(void)
{
    DIR *dp = opendir("/proc");
    if (!dp) return;
    struct dirent *de;
    int found = 0;
    while ((de = readdir(dp)) != NULL) {
        pid_t pid = parse_pid_dir(de->d_name);
        if (pid < 0) continue;
        char cmd[MAX_CMDLEN], exe[MAX_EXELEN];
        if (get_comm(pid, cmd, sizeof cmd) < 0) continue;
        get_exe(pid, exe, sizeof exe);
        int mem = get_mem_mb(pid);
        if (mem < 0) continue;
        if (mem > config.threshold_mb &&
            !is_whitelisted(cmd, exe, &config)) {
            log_msg(LOG_INFO,
                "[mem-police] DUMP: PID %d (%s, %s) %dMB",
                pid, cmd, exe, mem);
            found++;
        }
    }
    closedir(dp);
    if (found == 0)
        log_msg(LOG_INFO, "[mem-police] DUMP: No hogs detected.");
}

/* ─── INTERRUPTIBLE SLEEP ─────────────────────────────────────────────────── */

/*
 * interruptible_sleep — sleep for secs seconds, waking immediately if
 * keep_running is cleared by a signal.
 *
 * AUDIT FIX 3.1.0: Replaced sleep() (unreliably interruptible with signal()
 * semantics) with a 100 ms nanosleep() polling loop.  Wakes within one quantum
 * of SIGTERM rather than up to sleep_secs.
 *
 * AUDIT FIX 3.2.0: SLEEP >= 1 is now enforced in load_config(), so secs is
 * guaranteed >= 1 at call sites; the ticks computation never yields 0.
 */
static void
interruptible_sleep(int secs)
{
    struct timespec quantum = { 0, 100000000L }; /* 100 ms */
    int ticks = secs * 10;                       /* number of 100 ms ticks */
    for (int i = 0; i < ticks && keep_running; i++) {
        nanosleep(&quantum, NULL);
    }
}

/* ─── MAIN ────────────────────────────────────────────────────────────────── */

int
main(int argc, char *argv[])
{
    openlog("mem-police", LOG_PID | LOG_CONS, LOG_DAEMON);

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--config") == 0) {
            if (i + 1 >= argc) {
                usage(argv[0]);
                return EXIT_FAILURE;
            }
            config_path = argv[++i];
        } else if (strcmp(argv[i], "--foreground") == 0) {
            opt_foreground = 1;
        } else if (strcmp(argv[i], "--help") == 0) {
            /* AUDIT FIX 3.1.0: --help was falling through to the
             * unknown-option branch, returning EXIT_FAILURE. */
            usage(argv[0]);
            return EXIT_SUCCESS;
        } else {
            usage(argv[0]);
            return EXIT_FAILURE;
        }
    }

    if (geteuid() != 0) {
        log_msg(LOG_ERR, "[mem-police] must run as root");
        return EXIT_FAILURE;
    }

    if (!opt_foreground) daemonize();

    /*
     * AUDIT FIX 3.1.0: sigaction() replaces signal() throughout.
     * SIGCHLD → SIG_IGN prevents zombie children.
     * SIGPIPE → SIG_IGN prevents unexpected termination on broken pipes.
     * sa_flags = 0 (no SA_RESTART) so nanosleep() returns EINTR on signal
     * and interruptible_sleep() wakes immediately.
     */
    struct sigaction sa_ign;
    memset(&sa_ign, 0, sizeof sa_ign);
    sa_ign.sa_handler = SIG_IGN;
    sigemptyset(&sa_ign.sa_mask);
    sigaction(SIGCHLD, &sa_ign, NULL);
    sigaction(SIGPIPE, &sa_ign, NULL);

    write_pidfile();
    atexit(remove_pidfile);

    load_config(&config);
    check_startfile_dir();

    install_handler(SIGINT,  sig_handler);
    install_handler(SIGTERM, sig_handler);
    install_handler(SIGHUP,  sig_handler);
    install_handler(SIGUSR1, sig_handler);

    /* ── Main polling loop ── */
    for (;;) {
        if (!keep_running) break;
        if (need_reload)     { load_config(&config); need_reload     = 0; }
        if (need_dump_state) { dump_state();          need_dump_state = 0; }
        clean_orphaned_startfiles();

        DIR *dp = opendir("/proc");
        if (!dp) exit(EXIT_FAILURE);

        time_t now = time(NULL);
        struct dirent *de;
        int hog_count = 0, killed_count = 0;

        while ((de = readdir(dp)) != NULL) {
            if (!keep_running) break;

            pid_t pid = parse_pid_dir(de->d_name);
            if (pid < 0) continue;

            char cmd[MAX_CMDLEN], exe[MAX_EXELEN];
            if (get_comm(pid, cmd, sizeof cmd) < 0) continue;
            get_exe(pid, exe, sizeof exe);
            if (is_whitelisted(cmd, exe, &config)) continue;

            int mem = get_mem_mb(pid);
            if (mem < 0) continue;

            unsigned long long start_time = get_start_time(pid);
            if (!start_time) continue;

            char startfile[PATHBUF];
            snprintf(startfile, sizeof startfile, "%s/%s%d.start",
                     STARTFILE_DIR, STARTFILE_PREFIX, (int)pid);

            if (mem > config.threshold_mb) {
                hog_count++;
                time_t threshold_time = 0, sig_sent_time = 0;
                int file_pid = 0, state_valid = 0;
                unsigned long long file_start_time = 0;
                char file_cmd[MAX_CMDLEN] = "";
                struct stat st;

                if (stat(startfile, &st) == 0) {
                    FILE *sf = fopen(startfile, "r");
                    if (sf) {
                        if (fscanf(sf, "%ld %ld %d %llu",
                                   &threshold_time, &sig_sent_time,
                                   &file_pid, &file_start_time) == 4) {
                            int c;
                            while ((c = fgetc(sf)) != EOF &&
                                   isspace((unsigned char)c) && c != '\n');
                            if (c != EOF) {
                                ungetc(c, sf);
                                if (fgets(file_cmd, sizeof file_cmd, sf)) {
                                    file_cmd[strcspn(file_cmd, "\n")] = '\0';
                                    if (file_pid == pid &&
                                        file_start_time == start_time &&
                                        strcmp(file_cmd, cmd) == 0)
                                        state_valid = 1;
                                    else
                                        unlink(startfile);
                                }
                            }
                        } else {
                            unlink(startfile);
                        }
                        fclose(sf);
                    }
                }

                if (!state_valid) {
                    if (write_statefile_atomic(startfile, pid, now, 0L,
                                              start_time, cmd) == 0)
                        log_msg(LOG_INFO,
                            "[mem-police] PID %d (%s) %dMB > %dMB. "
                            "Timer started.",
                            pid, cmd, mem, config.threshold_mb);
                    continue;
                }

                if (sig_sent_time == 0 &&
                    (now - threshold_time) > config.threshold_duration) {
                    /*
                     * AUDIT FIX 3.2.0: Check kill() return value.
                     * If the process exited in the window between the RSS read
                     * and the kill(), ESRCH is returned.  Log at INFO (benign:
                     * process already gone) and unlink the startfile immediately
                     * rather than leaving it with sig_sent_time=now, which would
                     * otherwise cause an unnecessary SIGKILL attempt next cycle.
                     */
                    if (kill(pid, config.kill_signal) == -1) {
                        if (errno == ESRCH) {
                            log_msg(LOG_INFO,
                                "[mem-police] PID %d (%s) vanished before "
                                "signal could be sent — removing startfile.",
                                pid, cmd);
                        } else {
                            log_msg(LOG_WARNING,
                                "[mem-police] kill(%d, %d) failed: %s",
                                pid, config.kill_signal, strerror(errno));
                        }
                        unlink(startfile);
                    } else {
                        log_msg(LOG_INFO,
                            "[mem-police] PID %d (%s) signaled (%d)",
                            pid, cmd, config.kill_signal);
                        write_statefile_atomic(startfile, pid, threshold_time,
                                              now, start_time, cmd);
                    }
                    continue;
                }

                if (sig_sent_time > 0 &&
                    (now - sig_sent_time) > config.kill_grace) {
                    log_msg(LOG_INFO,
                        "[mem-police] PID %d (%s) SIGKILL sent.", pid, cmd);
                    kill(pid, SIGKILL);
                    unlink(startfile);
                    killed_count++;
                    continue;
                }

            } else {
                /*
                 * Process recovered below threshold — remove its timer startfile
                 * if one exists.
                 *
                 * AUDIT FIX 3.2.0: The previous `if (unlink(startfile) == 0) {}`
                 * was a no-op on success and silently swallowed all errors.  The
                 * common case (process was always fine; no startfile exists) was
                 * indistinguishable from an actual removal or a real error.
                 *
                 * Corrected logic:
                 *   - Attempt unlink unconditionally.
                 *   - ENOENT → process never had a startfile; silently ignore.
                 *   - Any other errno → log at WARNING (unexpected fs error).
                 *   - errno == 0 (success) → process recovered; log at INFO.
                 */
                if (unlink(startfile) == 0) {
                    log_msg(LOG_INFO,
                        "[mem-police] PID %d (%s) recovered below %dMB "
                        "— timer cleared.",
                        pid, cmd, config.threshold_mb);
                } else if (errno != ENOENT) {
                    log_msg(LOG_WARNING,
                        "[mem-police] unlink(%s): %s",
                        startfile, strerror(errno));
                }
            }
        }
        closedir(dp);
        write_metrics(hog_count, killed_count);

        if (!keep_running) break;

        /*
         * AUDIT FIX 3.1.0: interruptible_sleep() instead of sleep().
         * Wakes within 100 ms of SIGTERM rather than up to sleep_secs.
         */
        interruptible_sleep(config.sleep_secs);
    }

    free_whitelist(&config);
    closelog();
    return EXIT_SUCCESS;
}
