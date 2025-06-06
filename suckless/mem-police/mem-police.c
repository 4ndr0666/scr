/*
 * mem-police.c — Robust memory policing daemon
 * Compile: cc -O2 -std=c11 -Wall -Wextra -pedantic -D_POSIX_C_SOURCE=200809L -o mem-police mem-police.c
 * Requires: /etc/mem_police.conf, /var/run/mem-police (0700, root), creates /var/run/mem-police.pid
 * See prior comments for config example.
 */

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

#define CONFIG_PATH           "/etc/mem_police.conf"
#define STARTFILE_DIR         "/var/run/mem-police"
#define PIDFILE_PATH          "/var/run/mem-police.pid"
#define DEFAULT_SLEEP         30
#define PATHBUF               PATH_MAX
#define MAX_WHITELIST_LEN     2048
#define MAX_WHITELIST         64
#define MAX_CMDLEN            32
#define STARTFILE_PREFIX      "mempolice-"
#define STARTFILE_PREFIX_LEN  (sizeof(STARTFILE_PREFIX) - 1)

typedef struct {
    int threshold_mb;
    int kill_signal;
    int threshold_duration;
    int kill_grace;
    int sleep_secs;
    char whitelist_buf[MAX_WHITELIST_LEN];
    char *whitelist_entries[MAX_WHITELIST];
    size_t whitelist_count;
} mempolice_config_t;

static volatile sig_atomic_t keep_running = 1;
static int pidfile_fd = -1;
static const char *config_path = CONFIG_PATH;
static int opt_foreground = 0;

static void usage(const char *prog) {
    fprintf(stderr, "Usage: %s [--config FILE] [--foreground] [--help]\n", prog);
}

static void log_syslog(int priority, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsyslog(priority, fmt, ap);
    va_end(ap);
}

static void remove_pidfile(void) {
    if (pidfile_fd >= 0) {
        close(pidfile_fd);
        unlink(PIDFILE_PATH);
    }
}

static void write_pidfile(void) {
    pidfile_fd = open(PIDFILE_PATH, O_RDWR | O_CREAT | O_CLOEXEC, 0600); // permissions: 0600 for security
    if (pidfile_fd < 0) {
        log_syslog(LOG_ERR, "[mem-police] Failed to open PID file %s: %s", PIDFILE_PATH, strerror(errno));
        exit(EXIT_FAILURE);
    }
    if (flock(pidfile_fd, LOCK_EX | LOCK_NB) < 0) {
        log_syslog(LOG_ERR, "[mem-police] Another instance is already running (could not lock %s)", PIDFILE_PATH);
        close(pidfile_fd);
        exit(EXIT_FAILURE);
    }
    if (ftruncate(pidfile_fd, 0) != 0) {
        log_syslog(LOG_ERR, "[mem-police] Failed to truncate PID file: %s", strerror(errno));
        close(pidfile_fd);
        unlink(PIDFILE_PATH);
        exit(EXIT_FAILURE);
    }
    char buf[32];
    int len = snprintf(buf, sizeof buf, "%d\n", (int)getpid());
    if (write(pidfile_fd, buf, len) < len) {
        log_syslog(LOG_ERR, "[mem-police] Failed to write PID file: %s", strerror(errno));
        close(pidfile_fd);
        unlink(PIDFILE_PATH);
        exit(EXIT_FAILURE);
    }
    // Keep pidfile_fd open for lock duration.
}

static void daemonize(void) {
    pid_t pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);
    if (setsid() < 0) exit(EXIT_FAILURE);
    pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);

    umask(0);
    if (chdir("/") != 0) {
        perror("chdir");
        exit(EXIT_FAILURE);
    }

    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);

    int fd = open("/dev/null", O_RDWR | O_CLOEXEC, 0);
    if (fd != -1) {
        if (dup2(fd, STDIN_FILENO) < 0 ||
            dup2(fd, STDOUT_FILENO) < 0 ||
            dup2(fd, STDERR_FILENO) < 0) {
            perror("dup2");
            if (fd > STDERR_FILENO) close(fd);
            exit(EXIT_FAILURE);
        }
        if (fd > STDERR_FILENO) close(fd);
    } else {
        perror("open /dev/null");
        exit(EXIT_FAILURE);
    }
}

static int str2sig(const char *s) {
    if (isdigit((unsigned char)*s)) {
        long sig_long;
        char *endptr;
        errno = 0;
        sig_long = strtol(s, &endptr, 10);
        if (errno == 0 && endptr != s && *endptr == '\0' && sig_long >= 0 && sig_long <= SIGRTMAX)
            return (int)sig_long;
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

static void check_startfile_dir(void) {
    struct stat st;
    if (stat(STARTFILE_DIR, &st) == -1) {
        if (errno == ENOENT) {
            if (mkdir(STARTFILE_DIR, 0700) != 0) {
                log_syslog(LOG_ERR, "[mem-police] Failed to create %s: %s", STARTFILE_DIR, strerror(errno));
                exit(EXIT_FAILURE);
            }
        } else {
            log_syslog(LOG_ERR, "[mem-police] stat(%s): %s", STARTFILE_DIR, strerror(errno));
            exit(EXIT_FAILURE);
        }
    } else {
        if (!S_ISDIR(st.st_mode) || (st.st_mode & 077) != 0) {
            log_syslog(LOG_ERR, "[mem-police] %s is not a secure directory (must be 0700, owned by root)", STARTFILE_DIR);
            exit(EXIT_FAILURE);
        }
        if (st.st_uid != 0) {
            log_syslog(LOG_ERR, "[mem-police] %s must be owned by root", STARTFILE_DIR);
            exit(EXIT_FAILURE);
        }
    }
}

static void check_config_permissions(void) {
    struct stat st;
    if (stat(config_path, &st) != 0) {
        log_syslog(LOG_ERR, "[mem-police] Cannot stat %s: %s", config_path, strerror(errno));
        exit(EXIT_FAILURE);
    }
    if (st.st_uid != 0 || st.st_gid != 0) {
        log_syslog(LOG_ERR, "[mem-police] Config file %s must be owned by root:root", config_path);
        exit(EXIT_FAILURE);
    }
    if ((st.st_mode & 077) != 0) {
        log_syslog(LOG_ERR, "[mem-police] Config file %s permissions too open (must be 0600 or stricter)", config_path);
        exit(EXIT_FAILURE);
    }
}

static void load_config(mempolice_config_t *cfg) {
    check_config_permissions();
    FILE *f = fopen(config_path, "r");
    if (!f) {
        log_syslog(LOG_ERR, "[mem-police] fopen(%s): %s", config_path, strerror(errno));
        exit(EXIT_FAILURE);
    }
    char line[256];
    int have_threshold = 0, have_kill = 0, have_duration = 0, have_grace = 0, have_whitelist = 0;
    cfg->sleep_secs = DEFAULT_SLEEP; cfg->whitelist_count = 0;

    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = '\0';
        char *p = line;
        while (*p && isspace((unsigned char)*p)) p++;
        if (*p == '\0' || *p == '#') continue;
        char *eq_pos = strchr(p, '=');
        if (!eq_pos) continue;
        *eq_pos = '\0';
        char *key = p;
        char *val = eq_pos + 1;

        if (strcmp(key, "THRESHOLD_MB") == 0 ||
            strcmp(key, "THRESHOLD_DURATION") == 0 ||
            strcmp(key, "KILL_GRACE") == 0 ||
            strcmp(key, "SLEEP") == 0) {
            long val_long;
            char *endptr;
            errno = 0;
            val_long = strtol(val, &endptr, 10);
            if (errno != 0 || endptr == val || *endptr != '\0') {
                log_syslog(LOG_ERR, "[mem-police] Invalid numeric value for %s: '%s'", key, val);
                exit(EXIT_FAILURE);
            }
            if (val_long < 0 || val_long > INT_MAX) {
                log_syslog(LOG_ERR, "[mem-police] Value for %s out of range: %ld", key, val_long);
                exit(EXIT_FAILURE);
            }
            if (strcmp(key, "THRESHOLD_MB") == 0) {
                cfg->threshold_mb = (int)val_long; have_threshold = 1;
            } else if (strcmp(key, "THRESHOLD_DURATION") == 0) {
                cfg->threshold_duration = (int)val_long; have_duration = 1;
            } else if (strcmp(key, "KILL_GRACE") == 0) {
                cfg->kill_grace = (int)val_long; have_grace = 1;
            } else if (strcmp(key, "SLEEP") == 0) {
                cfg->sleep_secs = (int)val_long;
            }
        } else if (strcmp(key, "KILL_SIGNAL") == 0) {
            int sig = str2sig(val);
            if (sig < 0) {
                log_syslog(LOG_ERR, "[mem-police] Invalid KILL_SIGNAL value: '%s'", val);
                exit(EXIT_FAILURE);
            }
            cfg->kill_signal = sig; have_kill = 1;
        } else if (strcmp(key, "WHITELIST") == 0) {
            strncpy(cfg->whitelist_buf, val, sizeof(cfg->whitelist_buf) - 1);
            cfg->whitelist_buf[sizeof(cfg->whitelist_buf) - 1] = '\0';
            char *ctx = NULL, *tok;
            cfg->whitelist_count = 0;
            for (tok = strtok_r(cfg->whitelist_buf, " \t", &ctx);
                 tok;
                 tok = strtok_r(NULL, " \t", &ctx)) {
                if (cfg->whitelist_count < MAX_WHITELIST) {
                    cfg->whitelist_entries[cfg->whitelist_count++] = tok;
                } else {
                    log_syslog(LOG_WARNING, "[mem-police] Whitelist truncated: maximum %d entries supported. Ignoring '%s'.", MAX_WHITELIST, tok);
                }
            }
            if (cfg->whitelist_count == 0) {
                log_syslog(LOG_ERR, "[mem-police] WHITELIST is empty!");
                exit(EXIT_FAILURE);
            }
            have_whitelist = 1;
        }
    }
    fclose(f);

    if (!have_threshold) log_syslog(LOG_ERR, "[mem-police] Missing required config: THRESHOLD_MB"), exit(EXIT_FAILURE);
    if (!have_kill) log_syslog(LOG_ERR, "[mem-police] Missing required config: KILL_SIGNAL"), exit(EXIT_FAILURE);
    if (!have_duration) log_syslog(LOG_ERR, "[mem-police] Missing required config: THRESHOLD_DURATION"), exit(EXIT_FAILURE);
    if (!have_grace) log_syslog(LOG_ERR, "[mem-police] Missing required config: KILL_GRACE"), exit(EXIT_FAILURE);
    if (!have_whitelist) log_syslog(LOG_ERR, "[mem-police] Missing required config: WHITELIST"), exit(EXIT_FAILURE);
}

static int is_whitelisted(const char *cmd, const mempolice_config_t *cfg) {
    for (size_t i = 0; i < cfg->whitelist_count; i++) {
        if (strcasecmp(cmd, cfg->whitelist_entries[i]) == 0)
            return 1;
    }
    return 0;
}

static pid_t parse_pid_dir(const char *name) {
    pid_t pid = 0;
    for (const char *p = name; *p; p++) {
        if (!isdigit((unsigned char)*p)) return -1;
        pid = pid * 10 + (*p - '0');
    }
    return pid > 0 ? pid : -1;
}

/*
 * get_start_time: Extract process start_time from /proc/[pid]/stat (field 22)
 * Robustly finds the last ')' after the command name (which may contain spaces/parentheses).
 * Skips 20 space-separated fields after that to reach start_time.
 * Now uses strtoull for robust conversion.
 */
static unsigned long long get_start_time(pid_t pid) {
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
            // Skip 20 spaces after last ')'
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

static int get_mem_mb(pid_t pid) {
    char path[PATHBUF];
    int ret = snprintf(path, sizeof path, "/proc/%d/status", (int)pid);
    if (ret < 0 || (size_t)ret >= sizeof path) return -1;
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    char buf[256];
    int mem = -1;
    while (fgets(buf, sizeof buf, f)) {
        if (strncmp(buf, "VmRSS:", 6) == 0) {
            char *num_start = buf + 6;
            while (num_start && isspace((unsigned char)*num_start)) num_start++;
            long kb;
            char *endptr;
            errno = 0;
            kb = strtol(num_start, &endptr, 10);
            if (errno == 0 && endptr != num_start &&
                (*endptr == ' ' || *endptr == '\t' || *endptr == '\n' || *endptr == '\0'))
                mem = (int)(kb / 1024);
            break;
        }
    }
    fclose(f);
    return mem;
}

static int get_comm(pid_t pid, char *out, size_t olen) {
    char path[PATHBUF];
    int ret = snprintf(path, sizeof path, "/proc/%d/comm", (int)pid);
    if (ret < 0 || (size_t)ret >= sizeof path) return -1;
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    if (!fgets(out, olen, f)) {
        fclose(f);
        return -1;
    }
    out[strcspn(out, "\n")] = '\0';
    fclose(f);
    return 0;
}

static void clean_orphaned_startfiles(void) {
    DIR *dp = opendir(STARTFILE_DIR);
    if (!dp) {
        log_syslog(LOG_WARNING, "[mem-police] opendir(%s): %s", STARTFILE_DIR, strerror(errno));
        return;
    }
    struct dirent *de;
    while ((de = readdir(dp)) != NULL) {
        if (de->d_type != DT_REG)
            continue;
        if (strncmp(de->d_name, STARTFILE_PREFIX, STARTFILE_PREFIX_LEN) != 0)
            continue;
        const char *suffix = de->d_name + STARTFILE_PREFIX_LEN;
        char *endptr;
        errno = 0;
        long pid = strtol(suffix, &endptr, 10);
        if (errno != 0 || endptr == suffix || strcmp(endptr, ".start") != 0 || pid <= 0)
            continue;
        if (kill((pid_t)pid, 0) == -1 && errno == ESRCH) {
            char filepath[PATHBUF];
            int ret = snprintf(filepath, sizeof filepath, "%s/%s", STARTFILE_DIR, de->d_name);
            if (ret < 0 || (size_t)ret >= sizeof filepath) continue;
            if (unlink(filepath) == 0)
                log_syslog(LOG_INFO, "[mem-police] Removed orphaned startfile: %s", filepath);
        }
    }
    closedir(dp);
}

static void sig_handler(int signum) {
    keep_running = 0;
    log_syslog(LOG_INFO, "[mem-police] Caught signal %d, shutting down...", signum);
}

static int write_statefile_atomic(const char *startfile, pid_t pid, time_t threshold_time, time_t sig_sent_time,
                                  unsigned long long start_time, const char *cmd) {
    char tmp_path[PATHBUF];
    int ret = snprintf(tmp_path, sizeof tmp_path, "%s.tmp", startfile);
    if (ret < 0 || (size_t)ret >= sizeof tmp_path) return -1;
    int sf_fd = open(tmp_path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
    if (sf_fd == -1) {
        log_syslog(LOG_WARNING, "[mem-police] Failed to open temp state file %s: %s", tmp_path, strerror(errno));
        return -1;
    }
    FILE *sf = fdopen(sf_fd, "w");
    if (!sf) {
        log_syslog(LOG_WARNING, "[mem-police] fdopen failed for %s: %s", tmp_path, strerror(errno));
        close(sf_fd); unlink(tmp_path);
        return -1;
    }
    int w = fprintf(sf, "%ld %ld %d %llu %s\n", (long)threshold_time, (long)sig_sent_time, pid, start_time, cmd);
    if (w < 0 || fclose(sf) != 0) {
        log_syslog(LOG_WARNING, "[mem-police] Failed to close temp state file %s: %s", tmp_path, strerror(errno));
        unlink(tmp_path); return -1;
    }
    if (rename(tmp_path, startfile) != 0) {
        log_syslog(LOG_WARNING, "[mem-police] Failed to rename temp state file %s to %s: %s", tmp_path, startfile, strerror(errno));
        unlink(tmp_path); return -1;
    }
    return 0;
}

int main(int argc, char *argv[]) {
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
            usage(argv[0]);
            return 0;
        } else {
            usage(argv[0]);
            return EXIT_FAILURE;
        }
    }

    if (geteuid() != 0) {
        log_syslog(LOG_ERR, "[mem-police] must be run as root");
        return EXIT_FAILURE;
    }

    if (!opt_foreground)
        daemonize();
    signal(SIGCHLD, SIG_IGN);
    write_pidfile();
    atexit(remove_pidfile);

    mempolice_config_t config;
    load_config(&config);
    check_startfile_dir();

    signal(SIGINT,  sig_handler);
    signal(SIGTERM, sig_handler);
    signal(SIGPIPE, SIG_IGN);

    for (;;) {
        if (!keep_running) break;
        clean_orphaned_startfiles();

        DIR *dp = opendir("/proc");
        if (!dp) {
            log_syslog(LOG_ERR, "[mem-police] opendir(/proc): %s", strerror(errno));
            exit(EXIT_FAILURE);
        }
        time_t now = time(NULL);
        struct dirent *de;
        while ((de = readdir(dp)) != NULL) {
            if (!keep_running) break;
            pid_t pid = parse_pid_dir(de->d_name);
            if (pid < 0) continue;
            char cmd[MAX_CMDLEN];
            if (get_comm(pid, cmd, sizeof cmd) < 0) continue;
            if (is_whitelisted(cmd, &config)) continue;
            int mem = get_mem_mb(pid);
            if (mem < 0) continue;
            unsigned long long start_time = get_start_time(pid);
            if (!start_time) continue;
            char startfile[PATHBUF];
            int ret_path = snprintf(startfile, sizeof startfile, "%s/%s%d.start", STARTFILE_DIR, STARTFILE_PREFIX, (int)pid);
            if (ret_path < 0 || (size_t)ret_path >= sizeof startfile) continue;

            if (mem > config.threshold_mb) {
                time_t threshold_time = 0, sig_sent_time = 0;
                int file_pid = 0;
                unsigned long long file_start_time = 0;
                char file_cmd[MAX_CMDLEN] = "";
                int state_valid = 0;
                struct stat st;
                if (stat(startfile, &st) == 0) {
                    FILE *sf = fopen(startfile, "r");
                    if (sf) {
                        int r = fscanf(sf, "%ld %ld %d %llu", &threshold_time, &sig_sent_time, &file_pid, &file_start_time);
                        if (r == 4) {
                            int c;
                            while ((c = fgetc(sf)) != EOF && isspace((unsigned char)c) && c != '\n');
                            if (c != EOF) {
                                ungetc(c, sf);
                                if (fgets(file_cmd, sizeof(file_cmd), sf)) {
                                    file_cmd[strcspn(file_cmd, "\n")] = '\0';
                                    if (file_pid == pid && file_start_time == start_time && strcmp(file_cmd, cmd) == 0)
                                        state_valid = 1;
                                    else {
                                        log_syslog(LOG_WARNING, "[mem-police] Invalid/stale state file for PID %d (%s), removing: %s", pid, cmd, startfile);
                                        unlink(startfile);
                                    }
                                }
                            }
                        } else {
                            log_syslog(LOG_WARNING, "[mem-police] Invalid state file format for PID %d (%s), removing: %s", pid, cmd, startfile);
                            unlink(startfile);
                        }
                        fclose(sf);
                    }
                }
                // --- State logic ---
                if (!state_valid) {
                    if (write_statefile_atomic(startfile, pid, now, 0L, start_time, cmd) == 0)
                        log_syslog(LOG_INFO, "[mem-police] PID %d (%s) memory %dMB > threshold %dMB. Timer started.", pid, cmd, mem, config.threshold_mb);
                    continue;
                }
                if (sig_sent_time == 0 && (now - threshold_time) > config.threshold_duration) {
                    log_syslog(LOG_INFO, "[mem-police] PID %d (%s) memory %dMB > threshold %dMB for >%d secs. Sending signal %d.", pid, cmd, mem, config.threshold_mb, config.threshold_duration, config.kill_signal);
                    if (kill(pid, config.kill_signal) < 0)
                        log_syslog(LOG_WARNING, "[mem-police] kill(%d, %d) failed: %s", pid, config.kill_signal, strerror(errno));
                    write_statefile_atomic(startfile, pid, threshold_time, now, start_time, cmd);
                    continue;
                }
                if (sig_sent_time > 0 && (now - sig_sent_time) > config.kill_grace) {
                    log_syslog(LOG_INFO, "[mem-police] PID %d (%s) did not terminate after signal %d. Grace period >%d secs expired. Sending SIGKILL.", pid, cmd, config.kill_signal, config.kill_grace);
                    if (kill(pid, SIGKILL) < 0)
                        log_syslog(LOG_WARNING, "[mem-police] kill(%d, SIGKILL) failed: %s", pid, strerror(errno));
                    unlink(startfile);
                    continue;
                }
            } else {
                if (unlink(startfile) == 0) {
                    // Optionally log removal
                } else if (errno != ENOENT) {
                    log_syslog(LOG_WARNING, "[mem-police] Failed to remove state file %s: %s", startfile, strerror(errno));
                }
            }
        }
        closedir(dp);
        if (!keep_running) break;
        sleep(config.sleep_secs);
    }
    log_syslog(LOG_INFO, "[mem-police] Shutdown complete.");
    closelog();
    return 0;
}
