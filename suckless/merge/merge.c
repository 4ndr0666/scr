/* merge.c
 * Ψ-4ndr0666 Production Grade Video/Image Merger (v3.2.0)
 *
 * COHESION REPORT:
 * - Superset Verified: v3.2.0
 * - Removed redundant feature test macros (handled by Makefile)
 * - Gap Mitigation: Implemented Signal Handling for atomic tmpdir cleanup
 * - Replaced system() with fork/execvp matrix
 * - Implemented POSIX-compliant file descriptor tracking
 * - Optimized storage via CRF 18
 *
 * Build: make
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <strings.h>
#include <stdarg.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <limits.h>
#include <signal.h>
#include <dirent.h>

#define TMPDIR_TEMPLATE "/tmp/smerge.XXXXXX"
#define IMAGE_DURATION "5"
#define TARGET_RES "1920:1080"
#define FILTER_CHAIN "scale=" TARGET_RES ":force_original_aspect_ratio=decrease,pad=" TARGET_RES ":(ow-iw)/2:(oh-ih)/2,fps=60,format=yuv420p"

/* Global for signal handler cleanup */
static char g_tmpdir[PATH_MAX] = {0};
static char *g_output_stage;
static int g_output_owned;
static volatile sig_atomic_t g_signal;

/* --- CLEANUP LOGIC --- */

static int run_cmd(const char *arg0, ...);

static void cleanup(void) {
    if (g_output_stage) { if (g_output_owned) unlink(g_output_stage); free(g_output_stage); g_output_stage = NULL; }
    if (g_tmpdir[0]) {
        DIR *dir = opendir(g_tmpdir);
        if (dir) {
            struct dirent *entry;
            while ((entry = readdir(dir))) {
                char path[PATH_MAX];
                if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) continue;
                int n = snprintf(path, sizeof path, "%s/%s", g_tmpdir, entry->d_name);
                if (n > 0 && (size_t)n < sizeof path && unlink(path) && errno != ENOENT) perror("cleanup unlink");
            }
            closedir(dir);
        }
        if (rmdir(g_tmpdir) && errno != ENOENT) perror("cleanup rmdir");
        g_tmpdir[0] = 0;
    }
}

static void sig_handler(int signo) { g_signal = signo; }

static int wait_child(pid_t pid) {
    int status;
    for (;;) {
        if (g_signal) { kill(-pid, SIGTERM); kill(pid, SIGTERM); }
        pid_t result = waitpid(pid, &status, 0);
        if (result == pid) break;
        if (result < 0 && errno == EINTR) continue;
        if (result < 0) { perror("waitpid"); return -1; }
    }
    return !g_signal && WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : -1;
}

/* --- CORE UTILS --- */

static int is_image(const char *f) {
    const char *ext = strrchr(f, '.');
    if (!ext) return 0;
    return !strcasecmp(ext, ".jpg") || !strcasecmp(ext, ".jpeg") ||
           !strcasecmp(ext, ".png") || !strcasecmp(ext, ".bmp")  ||
           !strcasecmp(ext, ".gif") || !strcasecmp(ext, ".webp") ||
           !strcasecmp(ext, ".tif") || !strcasecmp(ext, ".tiff");
}

static int run_cmd(const char *arg0, ...) {
    va_list args;
    va_start(args, arg0);
    int count = 1;
    while (va_arg(args, const char *) != NULL) count++;
    va_end(args);

    const char **argv = malloc(sizeof(char *) * (count + 1));
    if (!argv) return -1;

    va_start(args, arg0);
    argv[0] = arg0;
    for (int i = 1; i < count; i++) argv[i] = va_arg(args, const char *);
    argv[count] = NULL;
    va_end(args);

    pid_t pid = fork();
    if (pid < 0) {
        free(argv);
        return -1;
    } else if (pid == 0) {
        setpgid(0, 0);
        signal(SIGINT, SIG_DFL); signal(SIGTERM, SIG_DFL); signal(SIGHUP, SIG_DFL);
        int null_fd = open("/dev/null", O_RDWR);
        if (null_fd == -1 || dup2(null_fd, STDIN_FILENO) == -1 || dup2(null_fd, STDOUT_FILENO) == -1) _exit(126);
        if (null_fd > STDERR_FILENO) close(null_fd);
        execvp(arg0, (char *const *)argv);
        _exit(127);
    }
    
    setpgid(pid, pid);
    free(argv);
    return wait_child(pid);
}

static int has_audio(const char *f) {
    int pipefd[2];
    if (pipe(pipefd)) { perror("pipe"); return -1; }
    pid_t pid = fork();
    if (pid < 0) { perror("fork"); close(pipefd[0]); close(pipefd[1]); return -1; }
    if (!pid) {
        setpgid(0, 0);
        signal(SIGINT, SIG_DFL); signal(SIGTERM, SIG_DFL); signal(SIGHUP, SIG_DFL);
        close(pipefd[0]);
        if (dup2(pipefd[1], STDOUT_FILENO) < 0) _exit(126);
        close(pipefd[1]);
        execlp("ffprobe", "ffprobe", "-v", "error", "-select_streams", "a:0",
               "-show_entries", "stream=index", "-of", "csv=p=0", f, (char *)NULL);
        _exit(127);
    }
    setpgid(pid, pid); close(pipefd[1]);
    char buf[128]; int found = 0;
    for (;;) {
        if (g_signal) { kill(-pid, SIGTERM); kill(pid, SIGTERM); }
        ssize_t n = read(pipefd[0], buf, sizeof buf);
        if (n > 0) { found = 1; continue; }
        if (n < 0 && errno == EINTR) continue;
        if (n < 0) { perror("probe read"); close(pipefd[0]); wait_child(pid); return -1; }
        break;
    }
    close(pipefd[0]);
    return wait_child(pid) ? -1 : found;
}

static int normalize(const char *in, const char *out) {
    int audio = is_image(in) ? 0 : has_audio(in);
    if (audio < 0 || g_signal) return -1;
    if (is_image(in)) {
        return run_cmd("ffmpeg", "-nostdin", "-hide_banner", "-v", "error", "-filter_threads", "1", "-y", "-loop", "1", "-t", IMAGE_DURATION,
                       "-i", in, "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
                       "-map", "0:v:0", "-map", "1:a:0", "-vf", FILTER_CHAIN, "-c:v", "libx264", "-crf", "18", 
                       "-preset", "ultrafast", "-threads", "2", "-c:a", "aac", "-ar", "48000", "-ac", "2", "-video_track_timescale", "90000", "-movflags", "+faststart", "-shortest", "-t", IMAGE_DURATION, out, (char *)NULL);
    } else if (!audio) {
        return run_cmd("ffmpeg", "-nostdin", "-hide_banner", "-v", "error", "-filter_threads", "1", "-y", "-i", in, "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
                       "-map", "0:v:0", "-map", "1:a:0", "-vf", FILTER_CHAIN, "-c:v", "libx264", "-crf", "18", 
                       "-preset", "ultrafast", "-threads", "2", "-c:a", "aac", "-ar", "48000", "-ac", "2", "-video_track_timescale", "90000", "-movflags", "+faststart", "-shortest", out, (char *)NULL);
    } else {
        return run_cmd("ffmpeg", "-nostdin", "-hide_banner", "-v", "error", "-filter_threads", "1", "-y", "-i", in, "-map", "0:v:0", "-map", "0:a:0", "-vf", FILTER_CHAIN,
                       "-c:v", "libx264", "-crf", "18", "-preset", "ultrafast",
                       "-threads", "2", "-c:a", "aac", "-ar", "48000", "-ac", "2", "-video_track_timescale", "90000", "-movflags", "+faststart", out, (char *)NULL);
    }
}

static void write_list_entry(FILE *fp, const char *path) {
    fprintf(fp, "file '");
    for (const char *p = path; *p; p++) {
        if (*p == '\'') fprintf(fp, "'\\''");
        else fputc(*p, fp);
    }
    fprintf(fp, "'\n");
}

int main(int argc, char **argv) {
    char part[PATH_MAX], list_path[PATH_MAX];
    FILE *fp;

    if (argc < 3) {
        fprintf(stderr, "usage: %s output.mp4 input...\n", argv[0]);
        return 1;
    }

    struct sigaction action;
    memset(&action, 0, sizeof action); action.sa_handler = sig_handler;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGINT, &action, NULL) || sigaction(SIGTERM, &action, NULL) || sigaction(SIGHUP, &action, NULL)) { perror("sigaction"); return 1; }
    if (atexit(cleanup)) { fprintf(stderr, "Cannot register cleanup\n"); return 1; }
    char tmpl[] = TMPDIR_TEMPLATE;
    if (!mkdtemp(tmpl)) { perror("mkdtemp"); return 1; }
    strncpy(g_tmpdir, tmpl, sizeof(g_tmpdir) - 1);
    


    snprintf(list_path, sizeof(list_path), "%s/list.txt", tmpl);
    
    if (!(fp = fopen(list_path, "w"))) { 
        cleanup(); 
        return 1; 
    }

    for (int i = 2; i < argc; i++) {
        snprintf(part, sizeof(part), "%s/p%d.mp4", tmpl, i);
        if (normalize(argv[i], part) != 0) {
            fprintf(stderr, "[!] Normalization Failure: %s\n", argv[i]);
            fclose(fp);
            cleanup();
            return 1;
        }
        write_list_entry(fp, part);
    }
    if (ferror(fp)) { perror("write concat list"); fclose(fp); return 1; }
    if (fclose(fp)) { perror("close concat list"); return 1; }
    if (g_signal) return 128 + g_signal;
    size_t output_len = strlen(argv[1]);
    g_output_stage = malloc(output_len + sizeof ".merge.XXXXXX");
    if (!g_output_stage) { perror("malloc"); return 1; }
    memcpy(g_output_stage, argv[1], output_len);
    strcpy(g_output_stage + output_len, ".merge.XXXXXX");
    int stage_fd = mkstemp(g_output_stage);
    if (stage_fd < 0) { perror("output staging"); return 1; }
    g_output_owned = 1;
    if (close(stage_fd)) { perror("close stage"); return 1; }

    if (run_cmd("ffmpeg", "-nostdin", "-hide_banner", "-v", "error", "-filter_threads", "1", "-y", "-f", "concat", "-safe", "0", 
                "-i", list_path, "-map", "0:v:0", "-map", "0:a:0", "-c", "copy", "-movflags", "+faststart", "-f", "mp4", g_output_stage, (char *)NULL) != 0) {
        fprintf(stderr, "[!] Merge Failure.\n");
        cleanup();
        return 1;
    }

    if (g_signal) return 128 + g_signal;
    struct stat result;
    if (stat(g_output_stage, &result) || result.st_size == 0) { fprintf(stderr, "Empty output\n"); return 1; }
    if (rename(g_output_stage, argv[1])) { perror("publish output"); return 1; }
    g_output_owned = 0;
    printf("[Ψ] Operation Complete: %s\n", argv[1]);
    cleanup();
    return 0;
}
