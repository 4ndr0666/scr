/* suckless-merge-hardened.c
 * Ψ-4ndr0666 Refined Video/Image Merger (v3.0.1)
 * - Fixed: Added <strings.h> for strcasecmp (POSIX compliance)
 * - Fixed: Added _DEFAULT_SOURCE for strict C99/glibc compatibility
 * - Shell-safe execution (no system() shell injection)
 * - Safe FFmpeg concat list generation
 * - Robust error handling & cleanup
 * - Enforces mp4/h264/aac/60fps/qp0
 *
 * Build: cc -Wall -Wextra -std=c99 -D_POSIX_C_SOURCE=200809L -o merge suckless-merge-hardened.c
 */

/* Feature test macros must come before any includes */
#define _POSIX_C_SOURCE 200809L
#define _DEFAULT_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <strings.h> /* Required for strcasecmp */
#include <stdarg.h>
#include <errno.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <limits.h>

#define TMPDIR_TEMPLATE "/tmp/smerge.XXXXXX"
#define IMAGE_DURATION "5"

/* Utility: Check if file is an image based on extension */
static int is_image(const char *f) {
    const char *ext = strrchr(f, '.');
    if (!ext) return 0;
    return !strcasecmp(ext, ".jpg") || !strcasecmp(ext, ".jpeg") ||
           !strcasecmp(ext, ".png") || !strcasecmp(ext, ".bmp")  ||
           !strcasecmp(ext, ".gif") || !strcasecmp(ext, ".webp") ||
           !strcasecmp(ext, ".tif") || !strcasecmp(ext, ".tiff");
}

/* Utility: Safe fork/exec wrapper to avoid shell injection */
static int run_ffmpeg(const char *arg0, ...) {
    va_list args;
    va_start(args, arg0);
    
    // First pass: count arguments
    int count = 1; // arg0
    while (va_arg(args, const char *) != NULL) count++;
    va_end(args);

    // Allocate arg array
    const char **argv = malloc(sizeof(char *) * (count + 1));
    if (!argv) {
        perror("malloc");
        return -1;
    }

    va_start(args, arg0);
    argv[0] = arg0;
    for (int i = 1; i < count; i++) {
        argv[i] = va_arg(args, const char *);
    }
    argv[count] = NULL;
    va_end(args);

    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        free(argv);
        return -1;
    } else if (pid == 0) {
        // Child
        // Redirect stdout/stderr to /dev/null for silence, or keep for debugging
        int devnull = fopen("/dev/null", "w") ? fileno(fopen("/dev/null", "w")) : -1;
        if (devnull != -1) {
            dup2(devnull, STDOUT_FILENO);
            dup2(devnull, STDERR_FILENO);
        }
        execvp(arg0, (char *const *)argv);
        perror("execvp");
        exit(127);
    }

    // Parent
    free(argv);
    int status;
    waitpid(pid, &status, 0);
    return WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : -1;
}

/* Check if file has audio stream using ffprobe */
static int has_audio(const char *f) {
    // ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 input
    int pipefd[2];
    if (pipe(pipefd) == -1) return 0;

    pid_t pid = fork();
    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);
        int devnull = fopen("/dev/null", "w") ? fileno(fopen("/dev/null", "w")) : -1;
        if (devnull != -1) dup2(devnull, STDERR_FILENO);

        execlp("ffprobe", "ffprobe", "-v", "error", "-select_streams", "a",
               "-show_entries", "stream=index", "-of", "csv=p=0", f, NULL);
        exit(1);
    }

    close(pipefd[1]);
    char buf[16];
    ssize_t n = read(pipefd[0], buf, sizeof(buf));
    close(pipefd[0]);
    waitpid(pid, NULL, 0);

    return (n > 0); // If we read anything, there is an audio stream index
}

/* Normalize input to temp file */
static int normalize(const char *in, const char *out) {
    if (is_image(in)) {
        // Image path: loop 1, t 5, anullsrc, scale, fps 60, x264, qp 0, aac
        return run_ffmpeg("ffmpeg", "-y", "-loop", "1", "-t", IMAGE_DURATION,
                          "-i", in, "-f", "lavfi", "-i", "anullsrc",
                          "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=60",
                          "-c:v", "libx264", "-qp", "0", "-preset", "ultrafast",
                          "-c:a", "aac", "-shortest", out, NULL);
    } else if (!has_audio(in)) {
        // Video no audio: add anullsrc
        return run_ffmpeg("ffmpeg", "-y", "-i", in, "-f", "lavfi", "-i", "anullsrc",
                          "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=60",
                          "-c:v", "libx264", "-qp", "0", "-preset", "ultrafast",
                          "-c:a", "aac", "-shortest", out, NULL);
    } else {
        // Normal video path
        return run_ffmpeg("ffmpeg", "-y", "-i", in,
                          "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=60",
                          "-c:v", "libx264", "-qp", "0", "-preset", "ultrafast",
                          "-c:a", "aac", out, NULL);
    }
}

/* Safely write filename to concat list with escaping */
static void write_list_entry(FILE *fp, const char *path) {
    fprintf(fp, "file '");
    for (const char *p = path; *p; p++) {
        if (*p == '\'') {
            fprintf(fp, "'\\''"); // Escape single quote for ffmpeg concat
        } else {
            fputc(*p, fp);
        }
    }
    fprintf(fp, "'\n");
}

/* Recursive directory removal for cleanup (avoids system("rm -rf")) */
static int remove_dir(const char *path) {
    return run_ffmpeg("rm", "-rf", path, NULL);
}

int main(int argc, char **argv) {
    char tmpdir[] = TMPDIR_TEMPLATE;
    char part[PATH_MAX];
    char list_path[PATH_MAX];
    FILE *fp;
    int i;

    if (argc < 3) {
        fprintf(stderr, "usage: %s output.mp4 input...\n", argv[0]);
        return 1;
    }

    if (!mkdtemp(tmpdir)) {
        perror("mkdtemp");
        return 1;
    }

    snprintf(list_path, sizeof(list_path), "%s/list.txt", tmpdir);
    fp = fopen(list_path, "w");
    if (!fp) {
        perror("fopen list");
        remove_dir(tmpdir);
        return 1;
    }

    printf("Processing %d files in %s...\n", argc - 2, tmpdir);

    for (i = 2; i < argc; i++) {
        snprintf(part, sizeof(part), "%s/p%d.mp4", tmpdir, i);
        printf("Normalizing: %s -> %s\n", argv[i], part);
        
        if (normalize(argv[i], part) != 0) {
            fprintf(stderr, "Error: Failed to normalize %s\n", argv[i]);
            fclose(fp);
            remove_dir(tmpdir);
            return 1;
        }
        write_list_entry(fp, part);
    }
    fclose(fp);

    /* Merge Step: Since we normalized, we can stream copy safely */
    printf("Merging to %s...\n", argv[1]);
    if (run_ffmpeg("ffmpeg", "-y", "-f", "concat", "-safe", "0", 
                   "-i", list_path, "-c", "copy", argv[1], NULL) != 0) {
        fprintf(stderr, "Error: Final merge failed.\n");
        remove_dir(tmpdir);
        return 1;
    }

    printf("Success: %s\n", argv[1]);
    remove_dir(tmpdir);
    return 0;
}
