/*
 * suckless-bclean.c — Minimal browser cleaner for Brave, Chrome, Chromium, Firefox
 *
 * Build: cc -Wall -Wextra -std=c99 -O2 -lsqlite3 -o suckless-bclean suckless-bclean.c
 */

#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sqlite3.h>
#include <errno.h>

#define MAXPATH 4096

static int
path_join(char *dst, size_t size, const char *a, const char *b)
{
	int n = snprintf(dst, size, "%s/%s", a, b);
	if (n < 0 || (size_t)n >= size) {
		fprintf(stderr, "path too long, skipping: %s/%s\n", a, b);
		return -1;
	}
	return 0;
}

static int
is_dir(const char *path)
{
    struct stat st;
    return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

static int
endswith(const char *str, const char *suffix)
{
    size_t lstr = strlen(str), lsuf = strlen(suffix);
    return lstr >= lsuf && strcmp(str + lstr - lsuf, suffix) == 0;
}

/* Run a command with execvp(), waiting for it to finish. */
static int
run(char *const argv[])
{
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        return 1;
    } else if (pid == 0) {
        execvp(argv[0], argv);
        _exit(127); // exec failed
    }
    int status;
    if (waitpid(pid, &status, 0) < 0)
        return 1;
    return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}

/* Remove a directory recursively using fork+exec of rm -rf */
static void
remove_dir(const char *path)
{
    char *const argv[] = {"rm", "-rf", (char *)path, NULL};
    if (run(argv) != 0)
        fprintf(stderr, "rm -rf failed: %s\n", path);
}

/* Vacuum, REINDEX, OPTIMIZE all .sqlite files in dir using libsqlite3 */
static void
vacuum_sqlite(const char *dbpath)
{
    sqlite3 *db = 0;
    if (sqlite3_open(dbpath, &db) != SQLITE_OK) {
        fprintf(stderr, "Cannot open: %s (%s)\n", dbpath, sqlite3_errmsg(db));
        return;
    }
    const char *sql =
        "PRAGMA journal_mode=DELETE;"
        "VACUUM;"
        "REINDEX;"
        "PRAGMA optimize;";
    if (sqlite3_exec(db, sql, 0, 0, 0) != SQLITE_OK)
        fprintf(stderr, "sqlite3 vacuum failed: %s\n", dbpath);
    else
        printf("Vacuumed: %s\n", dbpath);
    sqlite3_close(db);
}

/* Scan a directory for *.sqlite files and vacuum them */
static void
vacuum_directory(const char *dir)
{
    DIR *dp = opendir(dir);
    struct dirent *e;
    char path[MAXPATH];
    if (!dp) return;
    while ((e = readdir(dp))) {
        if (e->d_name[0] == '.') continue;
        if (!endswith(e->d_name, ".sqlite")) continue;
        snprintf(path, sizeof(path), "%s/%s", dir, e->d_name);
        vacuum_sqlite(path);
    }
    closedir(dp);
}

/* Clean extra cache directories (always, since deep-clean is default) */
static void
deep_clean(const char *root, const char *const dirs[])
{
    char path[MAXPATH];
    for (int i = 0; dirs[i]; i++) {
        snprintf(path, sizeof(path), "%s/%s", root, dirs[i]);
        if (is_dir(path)) {
            printf("Removing: %s\n", path);
            remove_dir(path);
        }
    }
}

/* Scan for Chrome/Brave/Chromium profiles: "Default", "Profile *" */
static void
scan_profiles(const char *base)
{
    DIR *dp = opendir(base);
    struct dirent *e;
    char path[MAXPATH];
    if (!dp) return;
    while ((e = readdir(dp))) {
        if (e->d_name[0] == '.') continue;
        if (strncmp(e->d_name, "Default", 7) != 0 &&
            strncmp(e->d_name, "Profile", 7) != 0) continue;
        snprintf(path, sizeof(path), "%s/%s", base, e->d_name);
        if (is_dir(path)) {
            printf("Profile: %s\n", path);
            vacuum_directory(path);
        }
    }
    closedir(dp);
}

/* Parse Firefox profiles.ini and vacuum each profile directory */
static void
firefox_profiles(const char *ff_dir)
{
    char ini[MAXPATH];
    snprintf(ini, sizeof(ini), "%s/profiles.ini", ff_dir);
    FILE *fp = fopen(ini, "r");
    if (!fp) return;
    char line[512], profile[MAXPATH];
    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, "Path=", 5) == 0) {
            char *rel = line + 5;
            rel[strcspn(rel, "\r\n")] = 0; // trim newline
            snprintf(profile, sizeof(profile), "%s/%s", ff_dir, rel);
            if (is_dir(profile)) {
                printf("Firefox profile: %s\n", profile);
                vacuum_directory(profile);
            }
        }
    }
    fclose(fp);
}

/* Kill browser by process name (pkill) */
static void
kill_browser(const char *name)
{
    pid_t pid = fork();
    if (pid == 0) {
        execlp("pkill", "pkill", "-TERM", "-u", getenv("USER"), name, (char *)0);
        _exit(127);
    }
    waitpid(pid, 0, 0);
    sleep(1);
    pid = fork();
    if (pid == 0) {
        execlp("pkill", "pkill", "-KILL", "-u", getenv("USER"), name, (char *)0);
        _exit(127);
    }
    waitpid(pid, 0, 0);
}

int
main(void)
{
    const char *home = getenv("HOME");
    if (!home) {
        fprintf(stderr, "HOME not set\n");
        return 1;
    }

    struct { const char *name, *path, *proc, **deep_dirs; } browsers[] = {
        // Browser        config path                  process   deep-clean dirs
        {"Brave",   ".config/BraveSoftware/Brave-Browser", "brave", (const char *[]){
            "GPUCache", "Code Cache", "Service Worker", "ShaderCache", "GrShaderCache", 0}},
        {"Chromium", ".config/chromium",                  "chromium", (const char *[]){
            "GPUCache", "Code Cache", "Service Worker", "ShaderCache", "GrShaderCache", 0}},
        {"Chrome",   ".config/google-chrome",             "chrome",   (const char *[]){
            "GPUCache", "Code Cache", "Service Worker", "ShaderCache", "GrShaderCache", 0}},
        {0}
    };

    /* Handle Chrome/Chromium/Brave */
    for (int i = 0; browsers[i].name; i++) {
        char dir[MAXPATH];
        snprintf(dir, sizeof(dir), "%s/%s", home, browsers[i].path);
        if (!is_dir(dir)) continue;
        printf("== %s ==\n", browsers[i].name);
        kill_browser(browsers[i].proc);
        scan_profiles(dir);
        deep_clean(dir, browsers[i].deep_dirs);
    }

    /* Firefox (special handling for profiles.ini) */
    char ff_dir[MAXPATH];
    snprintf(ff_dir, sizeof(ff_dir), "%s/.mozilla/firefox", home);
    if (is_dir(ff_dir)) {
        printf("== Firefox ==\n");
        kill_browser("firefox");
        firefox_profiles(ff_dir);
        // Deep-clean: delete cache2 directory
        char cache2[MAXPATH];
        snprintf(cache2, sizeof(cache2), "%s/cache2", ff_dir);
        if (is_dir(cache2)) {
            printf("Removing: %s\n", cache2);
            remove_dir(cache2);
        }
    }

    printf("All browser profiles cleaned.\n");
    return 0;
}
