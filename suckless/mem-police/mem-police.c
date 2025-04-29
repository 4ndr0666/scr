// File: mem-police.c
// Compile with:
//   cc -O2 -std=c11 -Wall -Wextra -pedantic -D_POSIX_C_SOURCE=200809L \
//      -o /usr/local/bin/mem-police mem-police.c

#include <sys/types.h>
#include <sys/stat.h>
#include <signal.h>
#include <dirent.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define CONFIG_PATH    "/etc/mem_police.conf"
#define STARTFILE_DIR  "/tmp"
#define DEFAULT_SLEEP  30
#define BUF_LEN        256

static int  threshold_mb = -1;
static int  kill_signal  = -1;
static int  kill_delay   = -1;
static int  sleep_secs   = DEFAULT_SLEEP;
static char *whitelist   = NULL;

/* strdup replacement */
static char *xstrdup(const char *s) {
    size_t len = strlen(s) + 1;
    char *p = malloc(len);
    if (p) memcpy(p, s, len);
    return p;
}

/* Secure bounded logger */
static void log_msg(const char *fmt, ...) {
    char buf[BUF_LEN];
    va_list ap;
    va_start(ap, fmt);
    int len = vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    if (len > 0 && (size_t)len < sizeof buf) {
        (void)write(STDOUT_FILENO, buf, (size_t)len);
    }
}

/* Load key=value from CONFIG_PATH */
static void load_config(void) {
    FILE *f = fopen(CONFIG_PATH, "r");
    if (!f) {
        log_msg("[!] fopen(%s): %s\n", CONFIG_PATH, strerror(errno));
        exit(1);
    }

    char line[BUF_LEN];
    while (fgets(line, sizeof line, f)) {
        const char *key = strtok(line, "=\n");
        const char *val = strtok(NULL, "=\n");
        if (!key || !val) continue;

        if      (strcmp(key, "THRESHOLD_MB") == 0) threshold_mb = atoi(val);
        else if (strcmp(key, "KILL_SIGNAL")  == 0) kill_signal  = atoi(val);
        else if (strcmp(key, "KILL_DELAY")   == 0) kill_delay   = atoi(val);
        else if (strcmp(key, "SLEEP")        == 0) sleep_secs   = atoi(val);
        else if (strcmp(key, "WHITELIST")    == 0) whitelist    = xstrdup(val);
    }
    fclose(f);

    if (threshold_mb < 0 || kill_signal < 0 || kill_delay < 0 || !whitelist) {
        log_msg("[!] Invalid config in %s\n", CONFIG_PATH);
        exit(1);
    }
}

/* Is this command whitelisted? */
static int is_whitelisted(const char *cmd) {
    char *copy = xstrdup(whitelist);
    if (!copy) return 0;

    char *ctx = NULL;
    char *tok = strtok_r(copy, " ", &ctx);
    while (tok) {
        if (strcmp(tok, cmd) == 0) {
            free(copy);
            return 1;
        }
        tok = strtok_r(NULL, " ", &ctx);
    }
    free(copy);
    return 0;
}

/* Return VmRSS in MB or -1 */
static int get_mem_mb(pid_t pid) {
    char path[PATH_MAX];
    snprintf(path, sizeof path, "/proc/%d/status", (int)pid);

    FILE *f = fopen(path, "r");
    if (!f) return -1;

    char buf[BUF_LEN];
    int  mem = -1;
    while (fgets(buf, sizeof buf, f)) {
        if (strncmp(buf, "VmRSS:", 6) == 0) {
            long kb = atol(buf + 6);
            mem = (int)(kb / 1024);
            break;
        }
    }
    fclose(f);
    return mem;
}

/* Read process name */
static int get_comm(pid_t pid, char *out, size_t olen) {
    char path[PATH_MAX];
    snprintf(path, sizeof path, "/proc/%d/comm", (int)pid);

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

int main(void) {
    load_config();

    for (;;) {
        DIR *dp = opendir("/proc");
        if (!dp) {
            log_msg("[!] opendir(/proc): %s\n", strerror(errno));
            exit(1);
        }

        time_t now = time(NULL);
        const struct dirent *de;
        while ((de = readdir(dp)) != NULL) {
            /* skip non-numeric dirs */
            pid_t pid = 0;
            for (const char *p = de->d_name; *p; p++) {
                if (!isdigit((unsigned char)*p)) { pid = 0; break; }
                pid = pid * 10 + (*p - '0');
            }
            if (pid <= 0) continue;

            char cmd[BUF_LEN];
            if (get_comm(pid, cmd, sizeof cmd) < 0)   continue;
            if (is_whitelisted(cmd))                 continue;

            int mem = get_mem_mb(pid);
            if (mem < 0)                             continue;

            char startfile[PATH_MAX];
            snprintf(startfile, sizeof startfile,
                     STARTFILE_DIR "/mempolice-%d.start", (int)pid);

            if (mem > threshold_mb) {
                struct stat st;
                if (stat(startfile, &st) != 0) {
                    /* first over-threshold */
                    FILE *sf = fopen(startfile, "w");
                    if (sf) {
                        fprintf(sf, "%ld\n", (long)now);
                        fclose(sf);
                        log_msg("[!] PID %d (%s) → timer start\n",
                                (int)pid, cmd);
                    }
                } else {
                    /* maybe kill */
                    FILE *sf = fopen(startfile, "r");
                    if (sf) {
                        long t0;
                        if (fscanf(sf, "%ld", &t0) == 1
                         && now - t0 > kill_delay) {
                            log_msg("[!] Killing PID %d (%s)\n",
                                    (int)pid, cmd);
                            kill(pid, kill_signal);
                            sleep(1);
                            if (kill(pid, 0) == 0) {
                                log_msg("[!] SIGKILL %d\n", (int)pid);
                                kill(pid, SIGKILL);
                            }
                            unlink(startfile);
                        }
                        fclose(sf);
                    }
                }
            } else {
                unlink(startfile);
            }
        }

        closedir(dp);
        sleep(sleep_secs);
    }
    return 0;
}
