/*
 * mem-police.c — Robust memory policing daemon
 * Version: 3.2.4 (gap-mitigation pass; canonical baseline = 3.1.0)
 *
 * CHANGELOG (3.2.3 → 3.2.4), closing the report-only findings of 3.2.3:
 *
 *   HIGH:     SIGHUP reload killed the daemon on any bad edit of the config
 *             (load_config() exit()ed on every parse error, so the previous
 *             good configuration was lost until systemd restarted the unit).
 *             Parsing now happens in parse_config(), which returns -1 instead
 *             of exiting and frees whatever it built.  Startup still exits on
 *             failure (load_config()); a reload goes through reload_config(),
 *             which parses into a scratch config and swaps it in only on
 *             success, so a bad reload logs an error and keeps the old policy.
 *
 *   HIGH:     If write_statefile_atomic() failed after a successful kill(), the
 *             on-disk state kept sig_sent_time=0, so the daemon re-sent the
 *             first signal every cycle and never escalated to SIGKILL.  The
 *             signal time is now also held in a small in-memory table keyed by
 *             (pid, process start time), consulted whenever the file does not
 *             carry it.  Entries are cleared on SIGKILL, on process exit or
 *             recovery, and pruned each cycle.
 *
 *   MEDIUM:   3.2.2 narrowed 3.1.0 by exiting when every WHITELIST pattern was
 *             invalid.  3.1.0 started in that case.  That behaviour is
 *             restored (with a WARNING naming the situation); a WHITELIST with
 *             no tokens at all is still an error, as in 3.1.0.
 *
 *   LOW:      need_reload / need_dump_state are now cleared BEFORE they are
 *             serviced.  Clearing afterwards lost a signal that arrived while
 *             the reload or dump was running.
 *
 * CHANGELOG (3.2.2 → 3.2.3), found by checking against mem-police.service and
 * the canonical /etc/mem_police.conf (SLEEP=30, ExecStart=... --foreground):
 *
 *   MEDIUM:   log_syslog(): the stderr echo added in 3.2.0 doubled every log
 *             line under the shipped unit, because journald stores both the
 *             syslog() copy and the stderr stream of a --foreground service.
 *             The echo is now skipped when stderr is the journal stream
 *             (JOURNAL_STREAM dev:ino matches fstat of fd 2); terminals, pipes
 *             and files still get it.
 *
 *   MEDIUM:   interruptible_sleep(): SIGHUP (reload) and SIGUSR1 (dump) set
 *             flags that are only serviced at the top of the main loop, so with
 *             SLEEP=30 they took up to 30 s to act.  The sleep now also ends
 *             when either flag is set.
 *
 * CHANGELOG (3.2.1 → 3.2.2):
 *
 *   MEDIUM:   interruptible_sleep(): `int ticks = secs * 10` was signed-integer
 *             overflow (undefined behaviour) for SLEEP > INT_MAX / 10, a value
 *             load_config() accepts.  Tick arithmetic is now long long.
 *
 *   LOW:      main(): stat()-then-fopen() on the per-PID startfile replaced by a
 *             direct fopen() (EAFP).  Behaviour is identical: ENOENT still means
 *             "no timer yet".
 *
 *   LOW:      mempolice_config_t.whitelist_entries[] and its only assignment in
 *             load_config() removed.  The array was write-only (never read).
 *
 * CHANGELOG (3.1.0 → 3.2.1):
 *
 *   CRITICAL: log_syslog() wrote only to syslog.  With --foreground the operator
 *             saw nothing on the terminal.  log_syslog() keeps its name and its
 *             syslog behaviour and, when opt_foreground is set, additionally
 *             writes the same message to stderr with an epoch-seconds prefix.
 *             dump_state() and every other caller benefit automatically.
 *
 *   HIGH:     write_statefile_atomic(): `if (w < 0 || fclose(sf) != 0)` skipped
 *             fclose() when fprintf() failed, leaking the FILE* and its fd.
 *             fclose() is now called unconditionally and checked separately.
 *
 *   HIGH:     load_config(): SLEEP=0 was accepted and turned the main loop into
 *             a CPU-saturating busy spin (interruptible_sleep(0) returns at once).
 *             SLEEP < 1 is now clamped to 1 with a LOG_WARNING; the config is
 *             still accepted, so no 3.1.0-valid configuration is rejected.
 *
 *   MEDIUM:   load_config(): THRESHOLD_MB=0 stays accepted (as in 3.1.0) but
 *             now logs a LOG_WARNING, because it polices every process.
 *
 *   HIGH:     load_config(): whitelist_count was incremented even when
 *             pcre2_compile or match_data allocation failed.  If EVERY pattern
 *             was invalid, 3.1.0 started with an effectively empty whitelist and
 *             would police critical processes, contradicting its own "WHITELIST
 *             is empty" guard.  Only usable entries are counted now, so that
 *             case hits the existing guard and the daemon refuses to start.
 *             (Deliberate narrowing on a safety path; see the GUP report.)
 *
 *   MEDIUM:   clean_orphaned_startfiles(): entries with d_type == DT_UNKNOWN
 *             (filesystems that do not fill d_type) were skipped.  They are now
 *             examined; the name/strtol/kill(0) filters reject non-startfiles.
 *
 *   LOW:      get_mem_mb(): the RSS-in-MB result is clamped to INT_MAX before
 *             the (int) cast so a wrapped negative value can never hide a
 *             process from policing.  (Defensive: INT_MAX MB is about 2 PiB,
 *             above any x86-64 user address space, so it is not reachable on
 *             current hardware.)
 *
 *   LOW:      main(): kill(pid, config.kill_signal) return value was unchecked.
 *             ESRCH (process already gone) is logged at LOG_INFO and the
 *             startfile is removed; other errors are logged at LOG_WARNING.
 *
 *   LOW:      main(): the "process recovered" branch swallowed every unlink()
 *             result.  Success is logged at LOG_INFO, ENOENT (the normal case)
 *             is ignored, and any other errno is logged at LOG_WARNING.
 *
 *   LOW:      _GNU_SOURCE is now guarded with #ifndef so that building with
 *             -D_GNU_SOURCE (as the Makefile and installer do) does not emit a
 *             "_GNU_SOURCE redefined" warning under -Wall -Wextra -pedantic.
 *
 * CHANGELOG (3.0 → 3.1.0), retained from the canonical 3.1.0 header:
 *
 *   CRITICAL: pcre2_match_8() was called with NULL match_data. Per the PCRE2
 *             API contract this is only safe when PCRE2_NO_AUTO_CAPTURE is set
 *             AND no substrings are needed. Passing NULL unconditionally is
 *             undefined on several PCRE2 builds and can segfault. Fixed:
 *             pcre2_match_data_8 is now allocated per-regex at compile time
 *             and stored alongside the compiled pattern.
 *
 *   CRITICAL: No whitelist coverage for Brave Beta. earlyoom carries an
 *             --avoid pattern for brave-beta; mem-police had no equivalent.
 *             The renderer at PID 2019551 (356 MB RSS, 30% CPU) would have
 *             been killed mid-session. The sample config and whitelist logic
 *             now use exe-path matching for /opt/brave.com/brave-beta/ paths.
 *
 *   HIGH:     signal() replaced with sigaction() throughout. signal() has
 *             implementation-defined SA_RESTART semantics on Linux; sleep()
 *             in the main loop was not reliably interrupted on SIGTERM.
 *
 *   HIGH:     Main-loop sleep() replaced with an interruptible nanosleep()
 *             loop that wakes immediately when keep_running clears, instead
 *             of blocking for up to sleep_secs after SIGTERM.
 *
 *   MEDIUM:   --help flag now handled correctly (clean exit, not FAILURE).
 *
 *   MEDIUM:   MAX_CMDLEN raised from 32 to 64. comm buffers throughout
 *             updated to match.
 *
 *   LOW:      get_mem_mb: resident * page_size cast to (long long) before
 *             multiplication to prevent overflow on large-RSS processes
 *             (e.g. Brave renderer at 356 MB RSS on a system where long
 *             is 32-bit).
 *
 * Compile: cc -O2 -std=c11 -Wall -Wextra -pedantic \
 *              -D_POSIX_C_SOURCE=200809L -D_GNU_SOURCE \
 *              -o mem-police mem-police.c -lpcre2-8
 */

#define PCRE2_CODE_UNIT_WIDTH 8
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
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
#define MAX_PENDING           64      /* in-memory signal records (see pending_*) */
#define MAX_CMDLEN            64      /* raised from 32: future-proof comm names */
#define MAX_EXELEN            PATH_MAX
#define STARTFILE_PREFIX      "mempolice-"
#define STARTFILE_PREFIX_LEN  (sizeof(STARTFILE_PREFIX) - 1)

/* ─── TYPES ───────────────────────────────────────────────────────────────── */

/*
 * WhitelistEntry — pairs a compiled PCRE2 pattern with its pre-allocated
 * match_data block.
 *
 * AUDIT FIX: The original code passed NULL as match_data to pcre2_match_8().
 * The PCRE2 documentation states: "If match_data is NULL, the function uses
 * an internal match_data block" only when the pattern was compiled with
 * PCRE2_NO_AUTO_CAPTURE — which this code does NOT set.  On several PCRE2
 * builds (particularly those compiled with PCRE2_DEBUG) this triggers an
 * assertion failure or segfault.  Each entry now owns its match_data block,
 * allocated once at pattern-compile time and freed at config unload.
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
static int                   opt_echo_stderr  = 0;   /* foreground AND stderr is not the journal */
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
 * stderr_is_journal — 1 when stderr is a stream into the systemd journal.
 *
 * systemd exports JOURNAL_STREAM="<st_dev>:<st_ino>" of the stdout/stderr
 * stream it connected to the journal.  Matching it against fstat(2) of fd 2
 * is exact: a shell started from inside a unit does not match once its stderr
 * is redirected.  Used so that a unit running `mem-police --foreground`
 * (see mem-police.service) does not log every message twice: once through
 * syslog() and once through the stderr stream, both of which journald stores.
 */
static int
stderr_is_journal(void)
{
    const char *js = getenv("JOURNAL_STREAM");
    if (!js) return 0;

    char *end;
    errno = 0;
    unsigned long long dev = strtoull(js, &end, 10);
    if (errno != 0 || end == js || *end != ':') return 0;
    const char *ino_s = end + 1;
    errno = 0;
    unsigned long long ino = strtoull(ino_s, &end, 10);
    if (errno != 0 || end == ino_s || *end != '\0') return 0;

    struct stat st;
    if (fstat(STDERR_FILENO, &st) != 0) return 0;
    return (unsigned long long)st.st_dev == dev &&
           (unsigned long long)st.st_ino == ino;
}

/*
 * log_syslog — log to syslog, and also to stderr when running --foreground.
 *
 * Through 3.1.0 this function only called vsyslog(), so an operator running
 * with --foreground saw nothing on the terminal even though the usage text
 * promises "log to stderr".  The name and the syslog behaviour are unchanged;
 * when opt_echo_stderr is set the same message is also written to stderr with
 * a seconds-since-epoch prefix.  va_start/va_end is repeated for the second
 * output because a va_list cannot be reused after a v*printf call.
 *
 * AUDIT FIX 3.2.3: the echo is keyed on opt_echo_stderr (foreground AND stderr
 * not the journal) instead of opt_foreground, so the shipped systemd unit,
 * which runs --foreground, logs each message once.
 */
static void
log_syslog(int priority, const char *fmt, ...)
{
    va_list ap;

    /* Always log to syslog — in foreground mode the LOG_CONS flag on openlog()
     * would normally route to /dev/console on syslog failure, but we supplement
     * that with the explicit stderr path below rather than relying on LOG_CONS. */
    va_start(ap, fmt);
    vsyslog(priority, fmt, ap);
    va_end(ap);

    if (opt_echo_stderr) {
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
        log_syslog(LOG_ERR, "[mem-police] Failed to open PID file %s: %s",
                   PIDFILE_PATH, strerror(errno));
        exit(EXIT_FAILURE);
    }
    if (flock(pidfile_fd, LOCK_EX | LOCK_NB) < 0) {
        log_syslog(LOG_ERR, "[mem-police] Another instance running (lock: %s)",
                   PIDFILE_PATH);
        close(pidfile_fd);
        exit(EXIT_FAILURE);
    }
    if (ftruncate(pidfile_fd, 0) != 0) {
        log_syslog(LOG_ERR, "[mem-police] ftruncate PID file: %s", strerror(errno));
        close(pidfile_fd);
        unlink(PIDFILE_PATH);
        exit(EXIT_FAILURE);
    }
    char buf[32];
    int len = snprintf(buf, sizeof buf, "%d\n", (int)getpid());
    if (write(pidfile_fd, buf, len) < len) {
        log_syslog(LOG_ERR, "[mem-police] write PID file: %s", strerror(errno));
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
 *
 * AUDIT FIX: The original code used signal(2), which has implementation-
 * defined SA_RESTART semantics on Linux.  With SA_RESTART set (the glibc
 * default), sleep() in the main loop is restarted after SIGTERM, meaning
 * the daemon could take up to sleep_secs to actually stop.  We explicitly
 * clear SA_RESTART so that the nanosleep() interruptible loop (below) wakes
 * immediately on any signal.
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
                log_syslog(LOG_ERR, "[mem-police] mkdir(%s): %s",
                           STARTFILE_DIR, strerror(errno));
                exit(EXIT_FAILURE);
            }
        } else {
            log_syslog(LOG_ERR, "[mem-police] stat(%s): %s",
                       STARTFILE_DIR, strerror(errno));
            exit(EXIT_FAILURE);
        }
    } else {
        if (!S_ISDIR(st.st_mode) || (st.st_mode & 077) != 0) {
            log_syslog(LOG_ERR,
                "[mem-police] %s must be a 0700 directory", STARTFILE_DIR);
            exit(EXIT_FAILURE);
        }
        if (st.st_uid != 0) {
            log_syslog(LOG_ERR, "[mem-police] %s must be root-owned", STARTFILE_DIR);
            exit(EXIT_FAILURE);
        }
    }
}

static int
check_config_permissions(void)
{
    struct stat st;
    if (stat(config_path, &st) != 0) {
        log_syslog(LOG_ERR, "[mem-police] stat(%s): %s",
                   config_path, strerror(errno));
        return -1;
    }
    if (st.st_uid != 0 || st.st_gid != 0) {
        log_syslog(LOG_ERR, "[mem-police] %s must be owned by root:root",
                   config_path);
        return -1;
    }
    if ((st.st_mode & 077) != 0) {
        log_syslog(LOG_ERR, "[mem-police] %s must be 0600", config_path);
        return -1;
    }
    return 0;
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
 *
 * AUDIT FIX: match_data is now a pre-allocated per-entry block rather than
 * NULL.  This is the only correct way to call pcre2_match_8 without
 * PCRE2_NO_AUTO_CAPTURE; passing NULL was triggering undefined behavior.
 */
static int
is_whitelisted(const char *cmd, const char *exe, const mempolice_config_t *cfg)
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

/*
 * parse_config — fill *cfg from config_path.  Returns 0 on success, -1 on any
 * error (already logged).  On failure *cfg holds no allocated whitelist
 * entries, so the caller never has to unwind a half-built configuration.
 */
static int
parse_config(mempolice_config_t *cfg)
{
    if (check_config_permissions() != 0) return -1;
    FILE *f = fopen(config_path, "r");
    if (!f) {
        log_syslog(LOG_ERR, "[mem-police] fopen(%s): %s",
                config_path, strerror(errno));
        return -1;
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
                log_syslog(LOG_ERR, "[mem-police] Invalid numeric '%s': '%s'",
                        key, val);
                goto fail;
            }
            if (v < 0 || v > INT_MAX) {
                log_syslog(LOG_ERR, "[mem-police] '%s' out of range: %ld", key, v);
                goto fail;
            }

            if (strcmp(key, "THRESHOLD_MB") == 0) {
                /* 0 is still accepted (as in 3.1.0) but polices every process. */
                if (v == 0)
                    log_syslog(LOG_WARNING,
                        "[mem-police] THRESHOLD_MB=0: every non-whitelisted "
                        "process is above the threshold");
                cfg->threshold_mb = (int)v;
                have_threshold = 1;

            } else if (strcmp(key, "THRESHOLD_DURATION") == 0) {
                cfg->threshold_duration = (int)v;
                have_duration = 1;

            } else if (strcmp(key, "KILL_GRACE") == 0) {
                cfg->kill_grace = (int)v;
                have_grace = 1;

            } else if (strcmp(key, "SLEEP") == 0) {
                /*
                 * interruptible_sleep(0) computes zero ticks and returns at
                 * once, turning the main loop into a CPU-saturating busy
                 * spin.  Clamp to 1 s rather than reject, so a configuration
                 * that 3.1.0 accepted is still accepted.
                 */
                if (v < 1) {
                    log_syslog(LOG_WARNING,
                        "[mem-police] SLEEP=%ld is below the 1 s minimum; "
                        "using 1", v);
                    v = 1;
                }
                cfg->sleep_secs = (int)v;
            }

        } else if (strcmp(key, "KILL_SIGNAL") == 0) {
            int sig = str2sig(val);
            if (sig < 0) {
                log_syslog(LOG_ERR, "[mem-police] Invalid KILL_SIGNAL: '%s'", val);
                goto fail;
            }
            cfg->kill_signal = sig;
            have_kill = 1;

        } else if (strcmp(key, "WHITELIST") == 0) {
            strncpy(cfg->whitelist_buf, val, sizeof(cfg->whitelist_buf) - 1);
            cfg->whitelist_buf[sizeof(cfg->whitelist_buf) - 1] = '\0';
            char *ctx = NULL, *tok;
            size_t tokens_seen = 0;
            free_whitelist(cfg);

            for (tok = strtok_r(cfg->whitelist_buf, " \t", &ctx);
                 tok;
                 tok = strtok_r(NULL, " \t", &ctx)) {
                if (cfg->whitelist_count >= MAX_WHITELIST) break;
                tokens_seen++;

                int      errorcode;
                PCRE2_SIZE erroffs;
                pcre2_code_8 *re = pcre2_compile_8(
                    (PCRE2_SPTR8)tok, PCRE2_ZERO_TERMINATED,
                    0, &errorcode, &erroffs, NULL);

                if (!re) {
                    log_syslog(LOG_WARNING,
                        "[mem-police] Whitelist regex '%s' invalid — skipped",
                        tok);
                    /*
                     * Do not count an unusable entry.  3.1.0 counted it, so a
                     * WHITELIST whose every pattern was invalid passed the
                     * "empty" guard below with no protection at all.
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
                    log_syslog(LOG_WARNING,
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

            if (tokens_seen == 0) {
                log_syslog(LOG_ERR, "[mem-police] WHITELIST is empty");
                goto fail;
            }
            if (cfg->whitelist_count == 0)
                log_syslog(LOG_WARNING,
                    "[mem-police] WHITELIST: no usable pattern (all %zu "
                    "invalid) — nothing is whitelisted", tokens_seen);
            have_whitelist = 1;
        }
    }
    fclose(f);
    f = NULL;

    if (!have_threshold) {
        log_syslog(LOG_ERR, "[mem-police] Missing: THRESHOLD_MB");
        goto fail;
    }
    if (!have_kill) {
        log_syslog(LOG_ERR, "[mem-police] Missing: KILL_SIGNAL");
        goto fail;
    }
    if (!have_duration) {
        log_syslog(LOG_ERR, "[mem-police] Missing: THRESHOLD_DURATION");
        goto fail;
    }
    if (!have_grace) {
        log_syslog(LOG_ERR, "[mem-police] Missing: KILL_GRACE");
        goto fail;
    }
    if (!have_whitelist) {
        log_syslog(LOG_ERR, "[mem-police] Missing: WHITELIST");
        goto fail;
    }
    return 0;

fail:
    if (f) fclose(f);
    free_whitelist(cfg);
    return -1;
}

/* load_config — startup path: any configuration error is fatal. */
static void
load_config(mempolice_config_t *cfg)
{
    if (parse_config(cfg) != 0) exit(EXIT_FAILURE);
}

/*
 * reload_config — SIGHUP path.  Parse into a scratch config and replace the
 * live one only on success; on failure the running policy is left untouched.
 */
static void
reload_config(mempolice_config_t *cfg)
{
    static mempolice_config_t next;
    memset(&next, 0, sizeof next);
    if (parse_config(&next) != 0) {
        log_syslog(LOG_ERR,
            "[mem-police] Reload failed — keeping previous configuration");
        return;
    }
    free_whitelist(cfg);
    *cfg = next;
    memset(&next, 0, sizeof next);   /* ownership of the regexes moved to *cfg */
    log_syslog(LOG_INFO, "[mem-police] Configuration reloaded");
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
                log_syslog(LOG_INFO,
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

/* ─── PENDING SIGNALS (in-memory fallback) ────────────────────────────────── */

/*
 * The startfile is the authoritative record of when the first signal was sent.
 * If it cannot be rewritten after a successful kill() (disk full, read-only
 * /var/run, ...), the daemon would otherwise forget the signal and never
 * escalate.  This table keeps (pid, start_time, sent) in memory for exactly
 * that case.  The start time is part of the key so a recycled PID never
 * inherits a stale entry.
 */
typedef struct {
    pid_t              pid;        /* 0 = free slot */
    unsigned long long start_time;
    time_t             sent;
} pending_signal_t;

static pending_signal_t pending_signals[MAX_PENDING];

static pending_signal_t *
pending_find(pid_t pid, unsigned long long start_time)
{
    for (size_t i = 0; i < MAX_PENDING; i++)
        if (pending_signals[i].pid == pid &&
            pending_signals[i].start_time == start_time)
            return &pending_signals[i];
    return NULL;
}

static void
pending_clear(pid_t pid, unsigned long long start_time)
{
    pending_signal_t *p = pending_find(pid, start_time);
    if (p) memset(p, 0, sizeof *p);
}

static void
pending_add(pid_t pid, unsigned long long start_time, time_t sent)
{
    pending_signal_t *p = pending_find(pid, start_time);
    for (size_t i = 0; !p && i < MAX_PENDING; i++)
        if (pending_signals[i].pid == 0) p = &pending_signals[i];
    if (!p) {
        log_syslog(LOG_ERR,
            "[mem-police] pending-signal table full; PID %d will be "
            "re-signaled instead of escalated", (int)pid);
        return;
    }
    p->pid = pid;
    p->start_time = start_time;
    p->sent = sent;
}

/* pending_prune — drop entries whose process has exited or been replaced. */
static void
pending_prune(void)
{
    for (size_t i = 0; i < MAX_PENDING; i++) {
        if (pending_signals[i].pid == 0) continue;
        if (get_start_time(pending_signals[i].pid) !=
            pending_signals[i].start_time)
            memset(&pending_signals[i], 0, sizeof pending_signals[i]);
    }
}

/* ─── METRICS ─────────────────────────────────────────────────────────────── */

static void
write_metrics(int hog_count, int killed_count)
{
    int fd = open(METRICS_PATH, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd < 0) return;
    dprintf(fd, "hog_processes %d\nkilled_processes %d\n", hog_count, killed_count);
    close(fd);
}

/* ─── DUMP STATE ──────────────────────────────────────────────────────────── */

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
        if (mem > config.threshold_mb && !is_whitelisted(cmd, exe, &config)) {
            log_syslog(LOG_INFO, "[mem-police] DUMP: PID %d (%s, %s) %dMB",
                       pid, cmd, exe, mem);
            found++;
        }
    }
    closedir(dp);
    if (found == 0)
        log_syslog(LOG_INFO, "[mem-police] DUMP: No hogs detected.");
}

/* ─── INTERRUPTIBLE SLEEP ─────────────────────────────────────────────────── */

/*
 * interruptible_sleep — sleep for secs seconds, waking immediately if
 * keep_running is cleared by a signal.
 *
 * AUDIT FIX: The original code used sleep(config.sleep_secs) in the main
 * loop.  With signal() (no SA_RESTART suppression), sleep() would be
 * restarted after SIGTERM on some glibc configurations, causing the daemon
 * to take up to sleep_secs to actually exit.  This nanosleep() loop checks
 * keep_running on every 100 ms quantum — responsive to signals while
 * still giving the OS meaningful idle time between polling cycles.
 *
 * AUDIT FIX 3.2.2: tick arithmetic is done in long long.  load_config()
 * accepts SLEEP up to INT_MAX, and `int ticks = secs * 10` overflowed (signed
 * overflow, undefined behaviour) for any SLEEP above INT_MAX / 10.
 *
 * AUDIT FIX 3.2.3: the loop also ends when SIGHUP (reload) or SIGUSR1 (dump)
 * has set its flag.  Those flags are only serviced at the top of the main loop,
 * so with SLEEP=30 (the canonical config) a reload or dump request waited up
 * to 30 s before taking effect.
 */
static void
interruptible_sleep(int secs)
{
    struct timespec quantum = { 0, 100000000L }; /* 100 ms */
    long long ticks = (long long)secs * 10;      /* number of 100 ms ticks */
    for (long long i = 0; i < ticks && keep_running &&
                          !need_reload && !need_dump_state; i++) {
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
        log_syslog(LOG_ERR, "[mem-police] must run as root");
        return EXIT_FAILURE;
    }

    opt_echo_stderr = opt_foreground && !stderr_is_journal();

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
        if (need_reload)     { need_reload     = 0; reload_config(&config); }
        if (need_dump_state) { need_dump_state = 0; dump_state(); }
        clean_orphaned_startfiles();
        pending_prune();

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

                /*
                 * AUDIT FIX 3.2.2 (EAFP): open the startfile directly.  The
                 * former stat()-then-fopen() pre-check was a TOCTOU window that
                 * added nothing: fopen() already fails with ENOENT when no timer
                 * exists yet, which falls through to "timer started" below.
                 */
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

                /*
                 * The startfile may have failed to record the signal time
                 * (see pending_*).  Prefer the in-memory record in that case.
                 */
                if (state_valid && sig_sent_time == 0) {
                    pending_signal_t *ps = pending_find(pid, start_time);
                    if (ps) sig_sent_time = ps->sent;
                }

                if (!state_valid) {
                    pending_clear(pid, start_time);
                    if (write_statefile_atomic(startfile, pid, now, 0L,
                                              start_time, cmd) == 0)
                        log_syslog(LOG_INFO,
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
                            log_syslog(LOG_INFO,
                                "[mem-police] PID %d (%s) vanished before "
                                "signal could be sent — removing startfile.",
                                pid, cmd);
                        } else {
                            log_syslog(LOG_WARNING,
                                "[mem-police] kill(%d, %d) failed: %s",
                                pid, config.kill_signal, strerror(errno));
                        }
                        unlink(startfile);
                        pending_clear(pid, start_time);
                    } else {
                        log_syslog(LOG_INFO,
                            "[mem-police] PID %d (%s) signaled (%d)",
                            pid, cmd, config.kill_signal);
                        if (write_statefile_atomic(startfile, pid,
                                                  threshold_time, now,
                                                  start_time, cmd) != 0) {
                            log_syslog(LOG_WARNING,
                                "[mem-police] PID %d: cannot record signal "
                                "time in %s (%s) — tracking in memory",
                                pid, startfile, strerror(errno));
                            pending_add(pid, start_time, now);
                        }
                    }
                    continue;
                }

                if (sig_sent_time > 0 &&
                    (now - sig_sent_time) > config.kill_grace) {
                    log_syslog(LOG_INFO,
                        "[mem-police] PID %d (%s) SIGKILL sent.", pid, cmd);
                    kill(pid, SIGKILL);
                    unlink(startfile);
                    pending_clear(pid, start_time);
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
                pending_clear(pid, start_time);
                if (unlink(startfile) == 0) {
                    log_syslog(LOG_INFO,
                        "[mem-police] PID %d (%s) recovered below %dMB "
                        "— timer cleared.",
                        pid, cmd, config.threshold_mb);
                } else if (errno != ENOENT) {
                    log_syslog(LOG_WARNING,
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
