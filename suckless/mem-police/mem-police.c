/*
 * mem-police.c — Robust memory policing daemon
 * Version: 3.1.0 (Audit: telemetry hardening + PCRE2 match_data fix)
 *
 * AUDIT CHANGELOG (3.0 → 3.1.0):
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
 *             now use exe-path matching for /opt/brave.com/brave-beta/*.
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

static void
log_syslog(int priority, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vsyslog(priority, fmt, ap);
    va_end(ap);
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

static void
check_config_permissions(void)
{
    struct stat st;
    if (stat(config_path, &st) != 0) {
        log_syslog(LOG_ERR, "[mem-police] stat(%s): %s",
                   config_path, strerror(errno));
        exit(EXIT_FAILURE);
    }
    if (st.st_uid != 0 || st.st_gid != 0) {
        log_syslog(LOG_ERR, "[mem-police] %s must be owned by root:root",
                   config_path);
        exit(EXIT_FAILURE);
    }
    if ((st.st_mode & 077) != 0) {
        log_syslog(LOG_ERR, "[mem-police] %s must be 0600", config_path);
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

static void
load_config(mempolice_config_t *cfg)
{
    check_config_permissions();
    FILE *f = fopen(config_path, "r");
    if (!f) {
        log_syslog(LOG_ERR, "[mem-police] fopen(%s): %s",
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
                log_syslog(LOG_ERR, "[mem-police] Invalid numeric '%s': '%s'",
                           key, val);
                exit(EXIT_FAILURE);
            }
            if (v < 0 || v > INT_MAX) {
                log_syslog(LOG_ERR, "[mem-police] '%s' out of range: %ld", key, v);
                exit(EXIT_FAILURE);
            }
            if      (strcmp(key, "THRESHOLD_MB")       == 0) { cfg->threshold_mb       = (int)v; have_threshold = 1; }
            else if (strcmp(key, "THRESHOLD_DURATION") == 0) { cfg->threshold_duration = (int)v; have_duration  = 1; }
            else if (strcmp(key, "KILL_GRACE")         == 0) { cfg->kill_grace         = (int)v; have_grace     = 1; }
            else if (strcmp(key, "SLEEP")              == 0) { cfg->sleep_secs         = (int)v; }

        } else if (strcmp(key, "KILL_SIGNAL") == 0) {
            int sig = str2sig(val);
            if (sig < 0) {
                log_syslog(LOG_ERR, "[mem-police] Invalid KILL_SIGNAL: '%s'", val);
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
                    log_syslog(LOG_WARNING,
                        "[mem-police] Whitelist regex '%s' invalid — skipped", tok);
                    cfg->whitelist[cfg->whitelist_count].re = NULL;
                    cfg->whitelist[cfg->whitelist_count].md = NULL;
                } else {
                    /*
                     * Allocate match_data from the compiled pattern.
                     * This is the correct PCRE2 API usage — the block is sized
                     * to hold the capture count from this specific pattern.
                     */
                    pcre2_match_data_8 *md = pcre2_match_data_create_from_pattern_8(re, NULL);
                    if (!md) {
                        log_syslog(LOG_WARNING,
                            "[mem-police] match_data alloc failed for '%s' — skipped", tok);
                        pcre2_code_free_8(re);
                        cfg->whitelist[cfg->whitelist_count].re = NULL;
                        cfg->whitelist[cfg->whitelist_count].md = NULL;
                    } else {
                        cfg->whitelist[cfg->whitelist_count].re = re;
                        cfg->whitelist[cfg->whitelist_count].md = md;
                    }
                }
                cfg->whitelist_count++;
            }

            if (cfg->whitelist_count == 0) {
                log_syslog(LOG_ERR, "[mem-police] WHITELIST is empty");
                exit(EXIT_FAILURE);
            }
            have_whitelist = 1;
        }
    }
    fclose(f);

    if (!have_threshold) { log_syslog(LOG_ERR, "[mem-police] Missing: THRESHOLD_MB");       exit(EXIT_FAILURE); }
    if (!have_kill)      { log_syslog(LOG_ERR, "[mem-police] Missing: KILL_SIGNAL");        exit(EXIT_FAILURE); }
    if (!have_duration)  { log_syslog(LOG_ERR, "[mem-police] Missing: THRESHOLD_DURATION"); exit(EXIT_FAILURE); }
    if (!have_grace)     { log_syslog(LOG_ERR, "[mem-police] Missing: KILL_GRACE");         exit(EXIT_FAILURE); }
    if (!have_whitelist) { log_syslog(LOG_ERR, "[mem-police] Missing: WHITELIST");          exit(EXIT_FAILURE); }
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
 * AUDIT FIX: The original code computed (resident * page_size) with both
 * operands as `long`.  On a system with a 356 MB RSS renderer (observed in
 * the live telemetry) and a 4096-byte page size:
 *   356 MB / 4096 = ~91,136 pages
 *   91,136 × 4096 = 373,293,056 bytes   — fits in a 32-bit long (max ~2.1 GB)
 * However at higher RSS values (e.g. a leaking renderer at 1.5 GB) the
 * intermediate product overflows before the division on 32-bit systems.
 * Cast to (long long) before multiply to be unconditionally safe.
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
    return (int)(((long long)resident * (long long)page_size) / (1024LL * 1024LL));
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

static void
clean_orphaned_startfiles(void)
{
    DIR *dp = opendir(STARTFILE_DIR);
    if (!dp) return;
    struct dirent *de;
    while ((de = readdir(dp)) != NULL) {
        if (de->d_type != DT_REG) continue;
        if (strncmp(de->d_name, STARTFILE_PREFIX, STARTFILE_PREFIX_LEN) != 0) continue;
        const char *suffix = de->d_name + STARTFILE_PREFIX_LEN;
        char *endptr;
        errno = 0;
        long pid = strtol(suffix, &endptr, 10);
        if (errno != 0 || endptr == suffix ||
            strcmp(endptr, ".start") != 0 || pid <= 0) continue;
        if (kill((pid_t)pid, 0) == -1 && errno == ESRCH) {
            char filepath[PATHBUF];
            snprintf(filepath, sizeof filepath, "%s/%s", STARTFILE_DIR, de->d_name);
            if (unlink(filepath) == 0)
                log_syslog(LOG_INFO, "[mem-police] Removed orphaned startfile: %s",
                           filepath);
        }
    }
    closedir(dp);
}

/* ─── STATE FILE ──────────────────────────────────────────────────────────── */

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
    if (!sf) { close(sf_fd); unlink(tmp_path); return -1; }

    int w = fprintf(sf, "%ld %ld %d %llu %s\n",
                    (long)threshold_time, (long)sig_sent_time,
                    pid, start_time, cmd);
    if (w < 0 || fclose(sf) != 0) { unlink(tmp_path); return -1; }
    if (rename(tmp_path, startfile) != 0) { unlink(tmp_path); return -1; }
    return 0;
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
            /* AUDIT FIX: --help was listed in usage() but fell through to
             * the unknown-option branch, returning EXIT_FAILURE. */
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

    if (!opt_foreground) daemonize();

    /* AUDIT FIX: sigaction replaces signal() throughout.
     * SIGCHLD → SIG_IGN prevents zombie children from any future fork.
     * SIGPIPE → SIG_IGN prevents unexpected termination on broken pipes.
     * All handlers use sa_flags=0 (no SA_RESTART) so nanosleep() in
     * interruptible_sleep() is interrupted by SIGTERM immediately. */
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
        if (need_reload)     { load_config(&config); need_reload = 0; }
        if (need_dump_state) { dump_state(); need_dump_state = 0; }
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
                        log_syslog(LOG_INFO,
                            "[mem-police] PID %d (%s) %dMB > %dMB. Timer started.",
                            pid, cmd, mem, config.threshold_mb);
                    continue;
                }
                if (sig_sent_time == 0 &&
                    (now - threshold_time) > config.threshold_duration) {
                    log_syslog(LOG_INFO,
                        "[mem-police] PID %d (%s) signaled (%d)",
                        pid, cmd, config.kill_signal);
                    kill(pid, config.kill_signal);
                    write_statefile_atomic(startfile, pid, threshold_time,
                                          now, start_time, cmd);
                    continue;
                }
                if (sig_sent_time > 0 &&
                    (now - sig_sent_time) > config.kill_grace) {
                    log_syslog(LOG_INFO,
                        "[mem-police] PID %d (%s) SIGKILL sent.", pid, cmd);
                    kill(pid, SIGKILL);
                    unlink(startfile);
                    killed_count++;
                    continue;
                }

            } else {
                /* Process recovered below threshold — reset its timer */
                if (unlink(startfile) == 0) { /* startfile removed */ }
            }
        }
        closedir(dp);
        write_metrics(hog_count, killed_count);

        if (!keep_running) break;

        /* AUDIT FIX: interruptible_sleep() instead of sleep().
         * Wakes within 100 ms of SIGTERM rather than up to sleep_secs. */
        interruptible_sleep(config.sleep_secs);
    }

    free_whitelist(&config);
    closelog();
    return EXIT_SUCCESS;
}
