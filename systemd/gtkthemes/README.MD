### One-Shot Services for Non-Persistent Commands

For commands that run only once at session start (like “gtkthemes” and “wallpaper”), you may choose to create oneshot systemd units. For example:

**GTK Themes Service Example (`~/.config/systemd/user/gtkthemes.service`):**

```ini
[Unit]
Description=Apply GTK Themes and Icons

[Service]
Type=oneshot
ExecStart=/home/yourusername/.config/wayfire/scripts/gtkthemes
RemainAfterExit=yes

[Install]
WantedBy=default.target
```

Similarly, you can create one for setting the wallpaper if desired. These oneshot units are useful because they run once at startup and then remain “active” (i.e. RemainAfterExit=yes) so that dependencies can be set.
