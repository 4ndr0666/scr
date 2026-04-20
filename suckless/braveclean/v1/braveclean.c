/*
 * braveclean.c — High-performance browser sanitizer
 * Version: 2.1.2 (Protocol Restored)
 *
 * COHESION REPORT:
 * - CRITICAL FIX: Reverted unauthorized target expansion. Vacuum logic now 
 * strictly targets ONLY *.sqlite files, perfectly mirroring V1 behavior.
 * - CRITICAL FIX: Restored the exact deep-clean directory array from V1 
 * ("GPUCache", "Code Cache", "Service Worker", "ShaderCache", "GrShaderCache").
 * - Retained safe_path_join() and NFTW() for C-level memory safety and speed.
 *
 * Build: make
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <ftw.h>
#include <sqlite3.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <limits.h>

/* Fallback for systems without PATH_MAX */
#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define CYAN    "\033[36m"
#define RESET   "\033[0m"

/* --- UTILS --- */

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

static void
xnanosleep(long nsec)
{
    struct timespec req;
    req.tv_sec = 0;
    req.tv_nsec = nsec;
    nanosleep(&req, NULL);
}

/* * Safe Path Join
 * Prevents GCC -Wformat-truncation warnings by explicitly verifying lengths 
 */
static int
safe_path_join(char *dst, size_t size, const char *dir, const char *file)
{
    size_t dlen = strlen(dir);
    size_t flen = strlen(file);
    
    if (dlen + flen + 2 > size) {
        return -1;
    }
    
    int n = snprintf(dst, size, "%s/%s", dir, file);
    return (n < 0 || (size_t)n >= size) ? -1 : 0;
}

/* --- FILESYSTEM DESTRUCTION (Native NFTW) --- */

/* Callback for nftw to remove files/dirs */
static int 
unlink_cb(const char *fpath, const struct stat *sb, int typeflag, struct FTW *ftwbuf) 
{
    (void)sb; (void)typeflag; (void)ftwbuf;
    int rv = remove(fpath);
    if (rv) perror(fpath);
    return rv;
}

/* Recursive rm -rf implementation using native C API */
static void 
nuke_dir(const char *path) 
{
    struct stat st;
    if (stat(path, &st) == -1) return; 

    // FTW_DEPTH: Post-order traversal (children first)
    // FTW_PHYS: Do not follow symlinks
    if (nftw(path, unlink_cb, 64, FTW_DEPTH | FTW_PHYS) == -1) {
        log_warn("Failed to incinerate", path);
    } else {
        printf("%s[X] Incinerated: %s%s\n", RED, path, RESET);
    }
}

/* --- SQLITE OPTIMIZATION --- */

static void 
optimize_db(const char *dbpath) 
{
    sqlite3 *db;
    char *err_msg = 0;
    int rc = sqlite3_open(dbpath, &db);

    if (rc != SQLITE_OK) {
        log_warn("Cannot open DB", dbpath);
        sqlite3_close(db);
        return;
    }

    /* Restored exact PRAGMA chain from V1 canonical data */
    const char *sql = 
        "PRAGMA journal_mode=DELETE;"
        "VACUUM;"
        "REINDEX;"
        "PRAGMA optimize;";

    rc = sqlite3_exec(db, sql, 0, 0, &err_msg);
    
    if (rc != SQLITE_OK) {
        sqlite3_free(err_msg);
    } else {
        printf("%s[V] Vacuumed: %s%s\n", CYAN, dbpath, RESET);
    }

    sqlite3_close(db);
}

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
        // Protocol Restored: ONLY vacuum files explicitly ending in .sqlite
        size_t len = strlen(e->d_name);
        if (len > 7 && strcmp(e->d_name + len - 7, ".sqlite") == 0) {
            if (safe_path_join(path, sizeof(path), dir, e->d_name) == 0) {
                optimize_db(path);
            }
        }
    }
    closedir(dp);
}

/* --- FIREFOX INTELLIGENCE --- */

static void 
handle_firefox(const char *home) 
{
    char ff_root[PATH_MAX];
    if (safe_path_join(ff_root, sizeof(ff_root), home, ".mozilla/firefox") != 0) return;
    
    char ini_path[PATH_MAX];
    if (safe_path_join(ini_path, sizeof(ini_path), ff_root, "profiles.ini") != 0) return;

    FILE *fp = fopen(ini_path, "r");
    if (!fp) return;

    log_info("Detected Firefox/Mozilla", NULL);

    char line[1024];
    int is_relative = 1;

    while (fgets(line, sizeof(line), fp)) {
        line[strcspn(line, "\r\n")] = 0;

        if (strncmp(line, "IsRelative=", 11) == 0) {
            is_relative = atoi(line + 11);
        } else if (strncmp(line, "Path=", 5) == 0) {
            char full_path[PATH_MAX];
            int join_ok;
            
            if (is_relative) {
                join_ok = safe_path_join(full_path, sizeof(full_path), ff_root, line + 5);
            } else {
                join_ok = (snprintf(full_path, sizeof(full_path), "%s", line + 5) < PATH_MAX) ? 0 : -1;
            }
            
            if (join_ok == 0) {
                log_info("Processing Profile", full_path);
                scan_and_vacuum(full_path);
                
                char cache_path[PATH_MAX];
                if (safe_path_join(cache_path, sizeof(cache_path), full_path, "cache2") == 0) {
                    nuke_dir(cache_path);
                }
            }
            is_relative = 1; 
        }
    }
    fclose(fp);
}

/* --- CHROMIUM ENGINE --- */

static void 
handle_chromium_variant(const char *home, const char *name, const char *rel_path) 
{
    char root[PATH_MAX];
    if (safe_path_join(root, sizeof(root), home, rel_path) != 0) return;
    
    DIR *dp = opendir(root);
    if (!dp) return;

    log_info("Detected Engine", name);

    struct dirent *e;
    while ((e = readdir(dp))) {
        if (strcmp(e->d_name, "Default") == 0 || strncmp(e->d_name, "Profile", 7) == 0) {
            char prof_path[PATH_MAX];
            if (safe_path_join(prof_path, sizeof(prof_path), root, e->d_name) != 0) continue;
            
            log_info("Processing Profile", e->d_name);
            scan_and_vacuum(prof_path);

            // Protocol Restored: Exact canonical array from V1
            const char *trash[] = {"GPUCache", "Code Cache", "Service Worker", "ShaderCache", "GrShaderCache", NULL};
            for (int i=0; trash[i]; i++) {
                char garbage[PATH_MAX];
                if (safe_path_join(garbage, sizeof(garbage), prof_path, trash[i]) == 0) {
                    nuke_dir(garbage);
                }
            }
        }
    }
    closedir(dp);
}

/* --- PROCESS TERMINATION --- */

static void 
terminate_proc(const char *name) 
{
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "pkill -u %d -x %s > /dev/null 2>&1", getuid(), name);
    system(cmd); 
}

int 
main(void) 
{
    const char *home = getenv("HOME");
    if (!home) return 1;

    printf("%s[4NDR0666OS] Browser Necromancer Initialized%s\n", RED, RESET);

    // 1. Kill Phase
    const char *targets[] = {"firefox", "chrome", "chromium", "brave", NULL};
    for (int i=0; targets[i]; i++) terminate_proc(targets[i]);
    
    // Give OS time to release file locks (500ms)
    xnanosleep(500000000L); 

    // 2. Clean Phase
    handle_chromium_variant(home, "Brave", ".config/BraveSoftware/Brave-Browser");
    handle_chromium_variant(home, "Chromium", ".config/chromium");
    handle_chromium_variant(home, "Chrome", ".config/google-chrome");
    handle_firefox(home);

    printf("%s[4NDR0666OS] System Sanitized.%s\n", RED, RESET);
    return 0;
}
