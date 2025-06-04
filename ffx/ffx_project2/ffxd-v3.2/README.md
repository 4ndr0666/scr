# ffxd

Minimalist bulk video compositor, merger, and repair tool.

## Requirements

- ffmpeg
- ffprobe
- POSIX-compatible shell
- mktemp
- findutils

## Usage

```
./ffxd-v3.2.sh merge [--composite] file1 file2 out.mp4
./ffxd-v3.2.sh process --bulk dir/
./ffxd-v3.2.sh composite file1 file2
```
