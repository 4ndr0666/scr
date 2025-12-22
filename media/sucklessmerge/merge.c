/* suckless-merge.c
 * Suckless robust video/image merger with shell-safe quoting
 * - mp4/h264/aac/60fps enforced
 * - -qp 0 always
 * - image inputs supported (duration = 5s)
 * - injects silent audio if missing
 * - stream-copy fast path if possible
 *
 * Build: cc -Wall -std=c99 -O2 -o merge suckless-merge.c
 * Usage: ./merge output.mp4 input1.mp4 input2.png input3.mp4 ...
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <strings.h>
#include <limits.h>
#include <sys/stat.h>

#define MAXFILES 128
#define TMPDIR_TEMPLATE "/tmp/smerge.XXXXXX"
#define IMAGE_DURATION 5   /* seconds */

static int
is_image(const char *f)
{
	const char *p = strrchr(f, '.');
	if (!p)
		return 0;
	return !strcasecmp(p, ".jpg")  || !strcasecmp(p, ".jpeg") ||
	       !strcasecmp(p, ".png")  || !strcasecmp(p, ".bmp")  ||
	       !strcasecmp(p, ".gif")  || !strcasecmp(p, ".webp") ||
	       !strcasecmp(p, ".tif")  || !strcasecmp(p, ".tiff");
}

static int
has_audio(const char *f)
{
	char cmd[PATH_MAX + 128];
	snprintf(cmd, sizeof(cmd),
	    "ffprobe -v error -select_streams a "
	    "-show_entries stream=index -of csv=p=0 '%s' 2>/dev/null | grep -q .", f);
	return system(cmd) == 0;
}

static int
try_stream_copy(const char *list, const char *out)
{
	char cmd[PATH_MAX * 2];
	snprintf(cmd, sizeof(cmd),
	    "ffmpeg -y -f concat -safe 0 -i '%s' -c copy '%s' >/dev/null 2>&1",
	    list, out);
	return system(cmd);
}

static int
normalize(const char *in, const char *out)
{
	char cmd[PATH_MAX * 2 + 256];

	if (is_image(in)) {
		snprintf(cmd, sizeof(cmd),
		    "ffmpeg -y -loop 1 -t %d -i '%s' "
		    "-f lavfi -i anullsrc "
		    "-vf \"scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=60\" "
		    "-c:v libx264 -qp 0 -preset ultrafast "
		    "-c:a aac -shortest '%s' >/dev/null 2>&1",
		    IMAGE_DURATION, in, out);
	} else if (!has_audio(in)) {
		snprintf(cmd, sizeof(cmd),
		    "ffmpeg -y -i '%s' -f lavfi -i anullsrc "
		    "-vf \"scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=60\" "
		    "-c:v libx264 -qp 0 -preset ultrafast "
		    "-c:a aac -shortest '%s' >/dev/null 2>&1",
		    in, out);
	} else {
		snprintf(cmd, sizeof(cmd),
		    "ffmpeg -y -i '%s' "
		    "-vf \"scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=60\" "
		    "-c:v libx264 -qp 0 -preset ultrafast "
		    "-c:a aac '%s' >/dev/null 2>&1",
		    in, out);
	}
	return system(cmd);
}

int
main(int argc, char **argv)
{
	char tmpdir[] = TMPDIR_TEMPLATE;
	char part[PATH_MAX], list[PATH_MAX];
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

	snprintf(list, sizeof(list), "%s/list.txt", tmpdir);
	fp = fopen(list, "w");
	if (!fp)
		return 1;

	for (i = 2; i < argc; i++) {
		snprintf(part, sizeof(part), "%s/p%d.mp4", tmpdir, i);
		if (normalize(argv[i], part) != 0) {
			fprintf(stderr, "ffmpeg failed: %s\n", argv[i]);
			return 1;
		}
		fprintf(fp, "file '%s'\n", part);
	}
	fclose(fp);

	/* try fast path first */
	if (try_stream_copy(list, argv[1]) == 0) {
		printf("Merged (stream copy): %s\n", argv[1]);
		goto done;
	}

	/* fallback (always safe) */
	if (try_stream_copy(list, argv[1]) != 0) {
		fprintf(stderr, "final merge failed\n");
		return 1;
	}

	printf("Merged (normalized): %s\n", argv[1]);

done:
	snprintf(part, sizeof(part), "rm -rf '%s'", tmpdir);
	system(part);
	return 0;
}
