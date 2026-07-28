# Niri Desktop Environment

> Use these commands to install niri with the DankMaterial Shell for a fairly out-of-the-box experience:

### Dependencies

```bash
sudo pacman -Syu niri xwayland-satellite xdg-desktop-portal-gnome xdg-desktop-portal-gtk alacritty dms-shell-niri matugen cava qt6-multimedia-ffmpeg
systemctl --user add-wants niri.service dms
```

> After running these commands, log out, choose Niri in your display manager, and log back in. Or, if not using a display manager, run niri-session on a TTY. The default niri config will run Waybar, so you might get two bars on screen. To fix this, stop Waybar with pkill waybar command, then open ~/.config/niri/config.kdl and delete the spawn-at-startup "waybar" line.

---

## Main Default Hotkeys

[#](#main-default-hotkeys "Permanent link")

When running on a TTY, the Mod key is Super. When running in a window, the Mod key is Alt.

The general system is: if a hotkey switches somewhere, then adding Ctrl will move the focused window or column there.

| Hotkey | Description |
| :--- | :--- |
| Mod+Shift+/ | Show a list of important niri hotkeys |
| Mod+T | Spawn `alacritty` (terminal) |
| Mod+D | Spawn `fuzzel` (application launcher) |
| Super+Alt+L | Spawn `swaylock` (screen locker) |
| Mod+Q | Close the focused window |
| Mod+H or Mod+← | Focus the column to the left |
| Mod+L or Mod+→ | Focus the column to the right |
| Mod+J or Mod+↓ | Focus the window below in a column |
| Mod+K or Mod+↑ | Focus the window above in a column |
| Mod+Ctrl+H or Mod+Ctrl+← | Move the focused column to the left |
| Mod+Ctrl+L or Mod+Ctrl+→ | Move the focused column to the right |
| Mod+Ctrl+J or Mod+Ctrl+↓ | Move the focused window below in a column |
| Mod+Ctrl+K or Mod+Ctrl+↑ | Move the focused window above in a column |
| Mod+Shift+H/J/K/L or Mod+Shift+←/↓/↑/→ | Focus the monitor to the side |
| Mod+Ctrl+Shift+H/J/K/L or Mod+Ctrl+Shift+←/↓/↑/→ | Move the focused column to the monitor to the side |
| Mod+U or Mod+PageDown | Switch to the workspace below |
| Mod+I or Mod+PageUp | Switch to the workspace above |
| Mod+Ctrl+U or Mod+Ctrl+PageDown | Move the focused column to the workspace below |
| Mod+Ctrl+I or Mod+Ctrl+PageUp | Move the focused column to the workspace above |
| Mod+Shift+U or Mod+Shift+PageDown | Move the focused workspace down |
| Mod+Shift+I or Mod+Shift+PageUp | Move the focused workspace up |
| Mod+[ | Consume or expel the focused window to the left |
| Mod+] | Consume or expel the focused window to the right |
| Mod+R and Mod+Shift+R | Toggle between preset column widths forward and back |
| Mod+M | Maximize window |
| Mod+C | Center column within view |
| Mod+- | Decrease column width by 10% |
| Mod+= | Increase column width by 10% |
| Mod+Shift+- | Decrease window height by 10% |
| Mod+Shift+= | Increase window height by 10% |
| Mod+Ctrl+R | Reset window height back to automatic |
| Mod+Shift+F | Toggle full-screen on the focused window |
| Mod+V | Move the focused window between the floating and the tiling layout |
| Mod+Shift+V | Switch focus between the floating and the tiling layout |
| PrtSc | Take an area screenshot. Select the area to screenshot with mouse, then press Space to save the screenshot, or Escape to cancel |
| Alt+PrtSc | Take a screenshot of the focused window to clipboard and to `~/Pictures/Screenshots/` |
| Ctrl+PrtSc | Take a screenshot of the focused monitor to clipboard and to `~/Pictures/Screenshots/` |
| Mod+Shift+E or Ctrl+Alt+Del | Exit niri |

---

## Example systemd Setup

When starting niri from a display manager like GDM, or otherwise through the `niri-session` binary, it runs as a systemd service. This provides the necessary systemd integration to run programs like `mako` and services like `xdg-desktop-portal` bound to the graphical session.

Here's an example on how you might set up [`mako`](https://github.com/emersion/mako), [`waybar`](https://github.com/Alexays/Waybar), [`swaybg`](https://github.com/swaywm/swaybg) and [`swayidle`](https://github.com/swaywm/swayidle) to run as systemd services with niri. Unlike [`spawn-at-startup`](Configuration%3A-Miscellaneous.html#spawn-at-startup), this lets you easily monitor their status and output, and restart or reload them.

1. Install them, i.e. `sudo dnf install mako waybar swaybg swayidle`
2. `mako` and `waybar` provide systemd units out of the box, so you can simply add them to the niri session:
   
   ```bash
   systemctl --user add-wants niri.service mako.service
   systemctl --user add-wants niri.service waybar.service
   ```
   
   This will create links in `~/.config/systemd/user/niri.service.wants/`, a special systemd folder for services that need to start together with `niri.service`.
   
3. `swaybg` does not provide a systemd unit, since you need to pass the background image as a command-line argument. So we will make our own. Create `~/.config/systemd/user/swaybg.service` with the following contents:
   
   ```ini
   [Unit]
   PartOf=graphical-session.target
   After=graphical-session.target
   Requisite=graphical-session.target

   [Service]
   ExecStart=/usr/bin/swaybg -m fill -i "%h/Pictures/LakeSide.png"
   Restart=on-failure
   ```
   
   Replace the image path with the one you want. `%h` is expanded to your home directory.
   
   After editing `swaybg.service`, run `systemctl --user daemon-reload` so systemd picks up the changes in the file.
   
   Now, add it to the niri session:
   
   ```bash
   systemctl --user add-wants niri.service swaybg.service
   ```
   
4. `swayidle` similarly does not provide a service, so we will also make our own. Create `~/.config/systemd/user/swayidle.service` with the following contents:
   
   ```ini
   [Unit]
   PartOf=graphical-session.target
   After=graphical-session.target
   Requisite=graphical-session.target

   [Service]
   ExecStart=/usr/bin/swayidle -w timeout 601 'niri msg action power-off-monitors' timeout 600 'swaylock -f' before-sleep 'swaylock -f'
   Restart=on-failure
   ```
   
   Then, run `systemctl --user daemon-reload` and add it to the niri session:
   
   ```bash
   systemctl --user add-wants niri.service swayidle.service
   ```

That's it! Now these three utilities will be started together with the niri session and stopped when it exits. You can also restart them with a command like `systemctl --user restart waybar.service`, for example after editing their config files.

To remove a service from niri startup, remove its symbolic link from `~/.config/systemd/user/niri.service.wants/`. Then, run `systemctl --user daemon-reload`.

### Running Programs Across Logout[#](#running-programs-across-logout "Permanent link")

When running niri as a session, exiting it (logging out) will kill all programs that you've started within. However, sometimes you want a program, like `tmux`, `dtach` or similar, to persist in this case. To do this, run it in a transient systemd scope:

```bash
systemd-run --user --scope tmux new-session
```

---

## IPC, niri msg

[](https://github.com/niri-wm/niri/edit/main/docs/wiki/IPC.md "Edit this page")

You can communicate with the running niri instance over an IPC socket. Check `niri msg --help` for available commands.

The `--json` flag prints the response in JSON, rather than formatted. For example, `niri msg --json outputs`.

> Tip
> 
> If you're getting parsing errors from `niri msg` after upgrading niri, make sure that you've restarted niri itself. You might be trying to run a newer `niri msg` against an older `niri` compositor.

### Event Stream[#](#event-stream "Permanent link")

[Since: 0.1.9](https://github.com/niri-wm/niri/releases/tag/v0.1.9)

While most niri IPC requests return a single response, the event stream request will make niri continuously stream events into the IPC connection until it is closed. This is useful for implementing various bars and indicators that update as soon as something happens, without continuous polling.

The event stream IPC is designed to give you the complete current state up-front, then follow up with updates to that state. This way, your state can never "desync" from niri, and you don't need to make any other IPC information requests.

Where reasonable, event stream state updates are atomic, though this is not always the case. For example, a window may end up with a workspace id for a workspace that had already been removed. This can happen if the corresponding workspaces-changed event arrives before the corresponding window-changed event.

To get a taste of the events, run `niri msg event-stream`. Though, this is more of a debug function than anything. You can get raw events from `niri msg --json event-stream`, or by connecting to the niri socket and requesting an event stream manually.

You can find the full list of events along with documentation [here](https://niri-wm.github.io/niri/niri_ipc/enum.Event.html).

### Programmatic Access[#](#programmatic-access "Permanent link")

`niri msg --json` is a thin wrapper over writing and reading to a socket. When implementing more complex scripts and modules, you're encouraged to access the socket directly.

Connect to the UNIX domain socket located at `$NIRI_SOCKET` in the filesystem. Write your request encoded in JSON on a single line, followed by a newline character, or by flushing and shutting down the write end of the connection. Read the reply as JSON, also on a single line.

You can use `socat` to test communicating with niri directly:

```bash
$ socat STDIO "$NIRI_SOCKET"
"FocusedWindow"
{"Ok":{"FocusedWindow":{"id":12,"title":"t socat STDIO /run/u ~","app_id":"Alacritty","workspace_id":6,"is_focused":true}}}
```

The reply is an `Ok` or an `Err` wrapping the same JSON object as you get from `niri msg --json`.

For more complex requests, you can use `socat` to find how `niri msg` formats them:

```bash
$ socat STDIO UNIX-LISTEN:temp.sock
# then, in a different terminal:
$ env NIRI_SOCKET=./temp.sock niri msg action focus-workspace 2
# then, look in the socat terminal:
{"Action":{"FocusWorkspace":{"reference":{"Index":2}}}}
```

You can find all available requests and response types in the [niri-ipc sub-crate documentation](https://niri-wm.github.io/niri/niri_ipc/).

### Backwards Compatibility[#](#backwards-compatibility "Permanent link")

The JSON output _should_ remain stable, as in:

- existing fields and enum variants should not be renamed
- non-optional existing fields should not be removed

However, new fields and enum variants will be added, so you should handle unknown fields or variants gracefully where reasonable.

The formatted/human-readable output (i.e. without `--json` flag) is **not** considered stable. Please prefer the JSON output for scripts, since I reserve the right to make any changes to the human-readable output.

The `niri-ipc` sub-crate (like other niri sub-crates) is _not_ API-stable in terms of the Rust semver; rather, it follows the version of niri itself. In particular, new struct fields and enum variants will be added.

---

## Xwayland-Satellite[#](#using-xwayland-satellite "Permanent link")

[Since: 25.08](https://github.com/niri-wm/niri/releases/tag/v25.08) Niri integrates with [xwayland-satellite](https://github.com/Supreeeme/xwayland-satellite) out of the box. Ensure xwayland-satellite >= 0.7 is installed and available in `$PATH`. With no further configuration, niri will create X11 sockets on disk, export `$DISPLAY`, and spawn xwayland-satellite on-demand when an X11 client connects. If xwayland-satellite dies, niri will automatically restart it.

If you had a custom config which manually started `xwayland-satellite` and set `$DISPLAY`, you should remove those customizations for the automatic integration to work.

To check that the integration works, verify that the niri output says something like `listening on X11 socket: :0`:

```bash
$ journalctl --user-unit=niri -b
systemd[2338]: Starting niri.service - A scrollable-tiling Wayland compositor...
niri[2474]: 2025-08-29T04:07:40.043402Z  INFO niri: starting version 25.05.1 (0.0.git.2345.d9833fc1)
(...)
niri[2474]: 2025-08-29T04:07:40.690512Z  INFO niri: listening on Wayland socket: wayland-1
niri[2474]: 2025-08-29T04:07:40.690520Z  INFO niri: IPC listening on: /run/user/1000/niri.wayland-1.2474.sock
niri[2474]: 2025-08-29T04:07:40.700137Z  INFO niri: listening on X11 socket: :0
systemd[2338]: Started niri.service - A scrollable-tiling Wayland compositor.
$ echo $DISPLAY
:0
```

![xwayland-satellite running Steam and Half-Life.](https://github.com/user-attachments/assets/57db8f96-40d4-4621-a389-373c169349a4)

We're using xwayland-satellite rather than Xwayland directly because [X11 is very cursed](FAQ.html#why-doesnt-niri-integrate-xwayland-like-other-compositors). xwayland-satellite takes on the bulk of the work dealing with the X11 peculiarities from us, giving niri normal Wayland windows to manage.

xwayland-satellite works well with most applications: Steam, games, Discord, even more exotic things like Ardour with wine Windows VST plugins. However, X11 apps that want to position windows or bars at specific screen coordinates won't behave correctly and will need a nested compositor to run. See sections below for how to do that.

## Using the labwc Wayland compositor[#](#using-the-labwc-wayland-compositor "Permanent link")

[Labwc](https://github.com/labwc/labwc) is a traditional stacking Wayland compositor with Xwayland. You can run it as a window, then run X11 apps inside.

1. Install labwc from your distribution packages.
2. Run it inside niri with the `labwc` command. It will open as a new window.
3. Run an X11 application on the X11 DISPLAY that it provides, e.g. `env DISPLAY=:0 glxgears`

![Labwc running X11 apps.](https://github.com/user-attachments/assets/aecbcecb-f0cb-4909-867f-09d34b5a2d7e)

## Directly running Xwayland in rootful mode[#](#directly-running-xwayland-in-rootful-mode "Permanent link")

This method involves invoking XWayland directly and running it as its own window, it also requires an extra X11 window manager running inside it.

![Xwayland running in rootful mode.](https://github.com/niri-wm/niri/assets/1794388/b64e96c4-a0bb-4316-94a0-ff445d4c7da7)

Here's how you do it:

1. Run `Xwayland` (just the binary on its own without flags). This will spawn a black window which you can resize and fullscreen (with Mod+Shift+F) for convenience. On older Xwayland versions the window will be screen-sized and non-resizable.
2. Run some X11 window manager in there, e.g. `env DISPLAY=:0 i3`. This way you can manage X11 windows inside the Xwayland instance.
3. Run an X11 application there, e.g. `env DISPLAY=:0 flatpak run com.valvesoftware.Steam`.

With fullscreen game inside a fullscreen Xwayland you get pretty much a normal gaming experience.

> Tip
> 
> If you don't run an X11 window manager, Xwayland will close and re-open its window every time all X11 windows close and a new one opens. To prevent this, start an X11 WM inside as mentioned above, or open some other long-running X11 window.

One caveat is that currently rootful Xwayland doesn't seem to share clipboard with the compositor. For textual data you can do it manually using [wl-clipboard](https://github.com/bugaevc/wl-clipboard), for example:

- `env DISPLAY=:0 xsel -ob | wl-copy` to copy from Xwayland to niri clipboard
- `wl-paste -n | env DISPLAY=:0 xsel -ib` to copy from niri to Xwayland clipboard

You can also bind these to hotkeys if you want:

```kdl
binds {
    Mod+Shift+C { spawn "sh" "-c" "env DISPLAY=:0 xsel -ob | wl-copy"; }
    Mod+Shift+V { spawn "sh" "-c" "wl-paste -n | env DISPLAY=:0 xsel -ib"; }
}
```

## Using xwayland-run to run Xwayland[#](#using-xwayland-run-to-run-xwayland "Permanent link")

[xwayland-run](https://gitlab.freedesktop.org/ofourdan/xwayland-run) is a helper utility to run an X11 client within a dedicated Xwayland rootful server. It takes care of starting Xwayland, setting the X11 DISPLAY environment variable, setting up xauth and running the specified X11 client using the newly started Xwayland instance. When the X11 client terminates, xwayland-run will automatically close the dedicated Xwayland server.

It works like this:

```bash
xwayland-run <Xwayland arguments> -- your-x11-app <X11 app arguments>
```

For example:

```bash
xwayland-run -geometry 800x600 -fullscreen -- wine wingame.exe
```

## Using the Cage Wayland compositor[#](#using-the-cage-wayland-compositor "Permanent link")

It is also possible to run the X11 application in [Cage](https://github.com/cage-kiosk/cage), which runs a nested Wayland session which also supports Xwayland, where the X11 application can run in.

Compared to the Xwayland rootful method, this does not require running an extra X11 window manager, and can be used with one command `cage -- /path/to/application`. However, it can also cause issues if multiple windows are launched inside Cage, since Cage is meant to be used in kiosks, every new window will be automatically full-screened and take over the previously opened window.

To use Cage you need to:

1. Install `cage`, it should be in most repositories.
2. Run `cage -- /path/to/application` and enjoy your X11 program on niri.

Optionally one can also modify the desktop entry for the application and add the `cage --` prefix to the `Exec` property. The Spotify Flatpak for example would look something like this:

```ini
[Desktop Entry]
Type=Application
Name=Spotify
GenericName=Online music streaming service
Comment=Access all of your favorite music
Icon=com.spotify.Client
Exec=cage -- flatpak run com.spotify.Client
Terminal=false
```

## Proton-GE native Wayland[#](#proton-ge-native-wayland "Permanent link")

It's possible to run some games as native Wayland clients, sidestepping the issues related to X11. You can do it with a custom version of Proton like [Proton-GE](https://github.com/GloriousEggroll/proton-ge-custom) by setting the `PROTON_ENABLE_WAYLAND=1` environmental variable in the game's launch parameters. Do note that for now this is an experimental feature, might not work with every game and might have its own issues.

```bash
PROTON_ENABLE_WAYLAND=1 %command%
```

---

## Configuration

[](https://github.com/niri-wm/niri/edit/main/docs/wiki/Configuration:-Introduction.md "Edit this page")

### Introduction

### Per-Section Documentation[#](#per-section-documentation "Permanent link")

You can find documentation for various sections of the config on these wiki pages:

- [`input {}`](Configuration%3A-Input.html)
- [`output "eDP-1" {}`](Configuration%3A-Outputs.html)
- [`binds {}`](Configuration%3A-Key-Bindings.html)
- [`switch-events {}`](Configuration%3A-Switch-Events.html)
- [`layout {}`](Configuration%3A-Layout.html)
- [top-level options](Configuration%3A-Miscellaneous.html)
- [`window-rule {}`](Configuration%3A-Window-Rules.html)
- [`layer-rule {}`](Configuration%3A-Layer-Rules.html)
- [`animations {}`](Configuration%3A-Animations.html)
- [`gestures {}`](Configuration%3A-Gestures.html)
- [`recent-windows {}`](Configuration%3A-Recent-Windows.html)
- [`debug {}`](Configuration%3A-Debug-Options.html)
- [`include "other.kdl"`](Configuration%3A-Include.html)

### Loading[#](#loading "Permanent link")

Niri will load configuration from `$XDG_CONFIG_HOME/niri/config.kdl` or `~/.config/niri/config.kdl`, falling back to `/etc/niri/config.kdl`. If both of these files are missing, niri will create `$XDG_CONFIG_HOME/niri/config.kdl` with the contents of [the default configuration file](https://github.com/niri-wm/niri/blob/main/resources/default-config.kdl), which are embedded into the niri binary at build time. Please use the default configuration file as the starting point for your custom configuration.

The configuration is live-reloaded. Simply edit and save the config file, and your changes will be applied. This includes key bindings, output settings like mode, window rules, and everything else.

You can run `niri validate` to parse the config and see any errors.

To use a different config file path, pass it in the `--config` or `-c` argument to `niri`.

You can also set `$NIRI_CONFIG` to the path of the config file. `--config` always takes precedence. If `--config` or `$NIRI_CONFIG` doesn't point to a real file, the config will not be loaded. If `$NIRI_CONFIG` is set to an empty string, it is ignored and the default config location is used instead.

### Syntax[#](#syntax "Permanent link")

The config is written in [KDL](https://kdl.dev/).

#### Comments[#](#comments "Permanent link")

Lines starting with `//` are comments; they are ignored.

Also, you can put `/-` in front of a section to comment out the entire section:

```kdl
/-output "eDP-1" {
    // Everything inside here is ignored.
    // The display won't be turned off
    // as the whole section is commented out.
    off
}
```

#### Flags[#](#flags "Permanent link")

Toggle options in niri are commonly represented as flags. Writing out the flag enables it, and omitting it or commenting it out disables it. For example:

```kdl
// "Focus follows mouse" is enabled.
input {
    focus-follows-mouse

    // Other settings...
}
```

```kdl
// "Focus follows mouse" is disabled.
input {
    // focus-follows-mouse

    // Other settings...
}
```

#### Sections[#](#sections "Permanent link")

Most sections cannot be repeated. For example:

```kdl
// This is valid: every section appears once.
input {
    keyboard {
        // ...
    }

    touchpad {
        // ...
    }
}
```

```kdl
// This is NOT valid: input section appears twice.
input {
    keyboard {
        // ...
    }
}

input {
    touchpad {
        // ...
    }
}
```

Exceptions are, for example, sections that configure different devices by name:

```kdl
output "eDP-1" {
    // ...
}

// This is valid: this section configures a different output.
output "HDMI-A-1" {
    // ...
}

// This is NOT valid: "eDP-1" already appeared above.
// It will either throw a config parsing error, or otherwise not work.
output "eDP-1" {
    // ...
}
```

### Defaults[#](#defaults "Permanent link")

Omitting most of the sections of the config file will leave you with the default values for that section. A notable exception is [`binds {}`](Configuration%3A-Key-Bindings.html): they do not get filled with defaults, so make sure you do not erase this section.

### Breaking Change Policy[#](#breaking-change-policy "Permanent link")

As a rule, niri updates should not break existing config files. (For example, the default config from niri v0.1.0 still parses fine on v25.02 as I'm writing this.)

Exceptions can be made for parsing bugs. For example, niri used to accept multiple binds to the same key, but this was not intended and did not do anything (the first bind was always used). A patch release changed niri from silently accepting this to causing a parsing failure. This is not a blanket rule, I will consider the potential impact of every breaking change like this before deciding to carry on with it.

Keep in mind that the breaking change policy applies only to niri releases. Commits between releases can and do occasionally break the config as new features are ironed out. However, I do try to limit these, since several people are running git builds.

---

## Input

[](https://github.com/niri-wm/niri/edit/main/docs/wiki/Configuration:-Input.md "Edit this page")

### Overview[#](#overview "Permanent link")

In this section you can configure input devices like keyboard and mouse, and some input-related options.

There's a section for each device type: `keyboard`, `touchpad`, `mouse`, `trackpoint`, `trackball`, `tablet`, `touch`. Settings in those sections will apply to every device of that type. Currently, there's no way to configure specific devices individually (but that is planned).

All settings at a glance:

```kdl
input {
    keyboard {
        xkb {
            // layout "us"
            // variant "colemak_dh_ortho"
            // options "compose:ralt,ctrl:nocaps"
            // model ""
            // rules ""
            // file "~/.config/keymap.xkb"
        }

        // repeat-delay 600
        // repeat-rate 25
        // track-layout "global"
        numlock
    }

    touchpad {
        // off
        tap
        // dwt
        // dwtp
        // drag false
        // drag-lock
        natural-scroll
        // accel-speed 0.2
        // accel-profile "flat"
        // scroll-factor 1.0
        // scroll-factor vertical=1.0 horizontal=-2.0
        // scroll-method "two-finger"
        // scroll-button 273
        // scroll-button-lock
        // tap-button-map "left-middle-right"
        // click-method "clickfinger"
        // left-handed
        // disabled-on-external-mouse
        // middle-emulation
    }

    mouse {
        // off
        // natural-scroll
        // accel-speed 0.2
        // accel-profile "flat"
        // scroll-factor 1.0
        // scroll-factor vertical=1.0 horizontal=-2.0
        // scroll-method "no-scroll"
        // scroll-button 273
        // scroll-button-lock
        // left-handed
        // middle-emulation
    }

    trackpoint {
        // off
        // natural-scroll
        // accel-speed 0.2
        // accel-profile "flat"
        // scroll-method "on-button-down"
        // scroll-button 273
        // scroll-button-lock
        // left-handed
        // middle-emulation
    }

    trackball {
        // off
        // natural-scroll
        // accel-speed 0.2
        // accel-profile "flat"
        // scroll-method "on-button-down"
        // scroll-button 273
        // scroll-button-lock
        // left-handed
        // middle-emulation
    }

    tablet {
        // off
        map-to-output "eDP-1"
        // map-to-focused-output
        // map-to-focused-window
        // left-handed
        // calibration-matrix 1.0 0.0 0.0 0.0 1.0 0.0
    }

    touch {
        // off
        map-to-output "eDP-1"
        // calibration-matrix 1.0 0.0 0.0 0.0 1.0 0.0
    }

    // disable-power-key-handling
    // warp-mouse-to-focus
    // focus-follows-mouse max-scroll-amount="0%"
    // workspace-auto-back-and-forth

    // mod-key "Super"
    // mod-key-nested "Alt"
}
```

### Keyboard[#](#keyboard "Permanent link")

#### Layout[#](#layout "Permanent link")

In the `xkb` section, you can set layout, variant, options, model and rules. These are passed directly to libxkbcommon, which is also used by most other Wayland compositors. See the `xkeyboard-config(7)` manual for more information.

```kdl
input {
    keyboard {
        xkb {
            layout "us"
            variant "colemak_dh_ortho"
            options "compose:ralt,ctrl:nocaps"
        }
    }
}
```

> Tip
> 
> [Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02)
> 
> Alternatively, you can directly set a path to a .xkb file containing an xkb keymap. This overrides all other xkb settings.

```kdl
input {
    keyboard {
        xkb {
            file "~/.config/keymap.xkb"
        }
    }
}
```

> Note
> 
> [Since: 25.08](https://github.com/niri-wm/niri/releases/tag/v25.08)
> 
> If the `xkb` section is empty (like it is by default), niri will fetch xkb settings from systemd-localed at `org.freedesktop.locale1` over D-Bus. This way, for example, system installers can dynamically set the niri keyboard layout. You can see this layout in `localectl` and change it with `localectl set-x11-keymap`, for example:

```bash
$ localectl set-x11-keymap "us" "" "colemak_dh_ortho" "compose:ralt,ctrl:nocaps"
$ localectl
System Locale: LANG=en_US.UTF-8                
                    LC_NUMERIC=ru_RU.UTF-8               
                    LC_TIME=ru_RU.UTF-8                  
                    LC_MONETARY=ru_RU.UTF-8              
                    LC_PAPER=ru_RU.UTF-8                 
                    LC_MEASUREMENT=ru_RU.UTF-8    
    VC Keymap: us-colemak_dh_ortho   
   X11 Layout: us   
   X11 Variant: colemak_dh_ortho   
   X11 Options: compose:ralt,ctrl:nocaps
```

By default, `localectl` will set the TTY keymap to the closest match of the XKB keymap. You can prevent that with a `--no-convert` flag, for example: `localectl set-x11-keymap --no-convert "us,ru"`.

These settings are picked up by some other programs too, like GDM.

When using multiple layouts, niri can remember the current layout globally (the default) or per-window. You can control this with the `track-layout` option.

- `global`: layout change is global for all windows.
- `window`: layout is tracked for each window individually.

```kdl
input {
    keyboard {
        track-layout "global"
    }
}
```

#### Repeat[#](#repeat "Permanent link")

Delay is in milliseconds before the keyboard repeat starts. Rate is in characters per second.

```kdl
input {
    keyboard {
        repeat-delay 600
        repeat-rate 25
    }
}
```

#### Num Lock[#](#num-lock "Permanent link")

[Since: 25.05](https://github.com/niri-wm/niri/releases/tag/v25.05)

Set the `numlock` flag to turn on Num Lock automatically at startup.

You might want to disable (comment out) `numlock` if you're using a laptop with a keyboard that overlays Num Lock keys on top of regular keys.

```kdl
input {
    keyboard {
        numlock
    }
}
```

### Pointing Devices[#](#pointing-devices "Permanent link")

Most settings for the pointing devices are passed directly to libinput. Other Wayland compositors also use libinput, so it's likely you will find the same settings there. For flags like `tap`, omit them or comment them out to disable the setting.

A few settings are common between input devices:

- `off`: if set, no events will be sent from this device.

A few settings are common between `touchpad`, `mouse`, `trackpoint`, and `trackball`:

- `natural-scroll`: if set, inverts the scrolling direction.
- `accel-speed`: pointer acceleration speed, valid values are from `-1.0` to `1.0` where the default is `0.0`.
- `accel-profile`: can be `adaptive` (the default) or `flat` (disables pointer acceleration).
- `scroll-method`: when to generate scroll events instead of pointer motion events, can be `no-scroll`, `two-finger`, `edge`, or `on-button-down`. The default and supported methods vary depending on the device type.
- `scroll-button`: [Since: 0.1.10](https://github.com/niri-wm/niri/releases/tag/v0.1.10) the button code used for the `on-button-down` scroll method. You can find it in `libinput debug-events`.
- `scroll-button-lock`: [Since: 25.08](https://github.com/niri-wm/niri/releases/tag/v25.08) when enabled, the button does not need to be held down. Pressing once engages scrolling, pressing a second time disengages it, and double click acts as single click of the the underlying button.
- `left-handed`: if set, changes the device to left-handed mode.
- `middle-emulation`: emulate a middle mouse click by pressing left and right mouse buttons at once.

Settings specific to `touchpad`s:

- `tap`: tap-to-click.
- `dwt`: disable-when-typing.
- `dwtp`: disable-when-trackpointing.
- `drag`: [Since: 25.05](https://github.com/niri-wm/niri/releases/tag/v25.05) can be `true` or `false`, controls if tap-and-drag is enabled.
- `drag-lock`: [Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02) if set, lifting the finger off for a short time while dragging will not drop the dragged item. See the [libinput documentation](https://wayland.freedesktop.org/libinput/doc/latest/tapping.html#tap-and-drag).
- `tap-button-map`: can be `left-right-middle` or `left-middle-right`, controls which button corresponds to a two-finger tap and a three-finger tap.
- `click-method`: can be `button-areas` or `clickfinger`, changes the [click method](https://wayland.freedesktop.org/libinput/doc/latest/clickpad-softbuttons.html).
- `disabled-on-external-mouse`: do not send events while external pointer device is plugged in.

Settings specific to `touchpad` and `mouse`:

- `scroll-factor`: [Since: 0.1.10](https://github.com/niri-wm/niri/releases/tag/v0.1.10) scales the scrolling speed by this value.
  
  [Since: 25.08](https://github.com/niri-wm/niri/releases/tag/v25.08) You can also override horizontal and vertical scroll factor separately like so: `scroll-factor horizontal=2.0 vertical=-1.0`

Settings specific to `tablet` and `touch`:

- `calibration-matrix`: set to six floating point numbers to change the calibration matrix. See the [`LIBINPUT_CALIBRATION_MATRIX` documentation](https://wayland.freedesktop.org/libinput/doc/latest/device-configuration-via-udev.html) for examples.
  - [Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02) for `tablet`
  - [Since: 25.11](https://github.com/niri-wm/niri/releases/tag/v25.11) for `touch`

Tablets and touchscreens are absolute pointing devices that can be mapped to a specific output like so:

```kdl
input {
    tablet {
        map-to-output "eDP-1"
    }

    touch {
        map-to-output "eDP-1"
    }
}
```

Valid output names are the same as the ones used for output configuration.

[Since: 0.1.7](https://github.com/niri-wm/niri/releases/tag/v0.1.7) When a tablet is not mapped to any output, it will map to the union of all connected outputs, without aspect ratio correction.

Settings specific to `tablet`:

- `map-to-focused-output`: [Since: 26.04](https://github.com/niri-wm/niri/releases/tag/v26.04) will map the tablet to the focused output, takes precedence over `map-to-output`.
  
- `map-to-focused-window`: Since: next release will map the tablet to the focused window's geometry, takes precedence over `map-to-focused-output` and `map-to-output`. Falls back to those when no window is focused (for example, in the overview).
  
  When the tablet is also mapped to a specific output via `map-to-output`, the `map-to-focused-window` flag will map the tablet to the active window on that output. If the tablet isn't mapped to any specific output, it will map the tablet to the current focused window regardless of where it is.

### General Settings[#](#general-settings "Permanent link")

These settings are not specific to a particular input device.

#### `disable-power-key-handling`[#](#disable-power-key-handling "Permanent link")

By default, niri will take over the power button to make it sleep instead of power off. Set this if you would like to configure the power button elsewhere (i.e. `logind.conf`).

```kdl
input {
    disable-power-key-handling
}
```

#### `warp-mouse-to-focus`[#](#warp-mouse-to-focus "Permanent link")

Makes the mouse warp to newly focused windows.

Does not make the cursor visible if it had been hidden.

```kdl
input {
    warp-mouse-to-focus
}
```

By default, the cursor warps _separately_ horizontally and vertically. I.e. if moving the mouse only horizontally is enough to put it inside the newly focused window, then the mouse will move only horizontally, and not vertically.

[Since: 25.05](https://github.com/niri-wm/niri/releases/tag/v25.05) You can customize this with the `mode` property.

- `mode="center-xy"`: warps by both X and Y coordinates together. So if the mouse was anywhere outside the newly focused window, it will warp to the center of the window.
- `mode="center-xy-always"`: warps by both X and Y coordinates together, even if the mouse was already somewhere inside the newly focused window.

```kdl
input {
    warp-mouse-to-focus mode="center-xy"
}
```

#### `focus-follows-mouse`[#](#focus-follows-mouse "Permanent link")

Focuses windows and outputs automatically when moving the mouse over them.

```kdl
input {
    focus-follows-mouse
}
```

[Since: 0.1.8](https://github.com/niri-wm/niri/releases/tag/v0.1.8) You can optionally set `max-scroll-amount`. Then, focus-follows-mouse won't focus a window if it will result in the view scrolling more than the set amount. The value is a percentage of the working area width.

```kdl
input {
    // Allow focus-follows-mouse when it results in scrolling at most 10% of the screen.
    focus-follows-mouse max-scroll-amount="10%"
}
```

```kdl
input {
    // Allow focus-follows-mouse only when it will not scroll the view.
    focus-follows-mouse max-scroll-amount="0%"
}
```

#### `workspace-auto-back-and-forth`[#](#workspace-auto-back-and-forth "Permanent link")

Normally, switching to the same workspace by index twice will do nothing (since you're already on that workspace). If this flag is enabled, switching to the same workspace by index twice will switch back to the previous workspace.

Niri will correctly switch to the workspace you came from, even if workspaces were reordered in the meantime.

```kdl
input {
    workspace-auto-back-and-forth
}
```

#### `mod-key`, `mod-key-nested`[#](#mod-key-mod-key-nested "Permanent link")

[Since: 25.05](https://github.com/niri-wm/niri/releases/tag/v25.05)

Customize the `Mod` key for [key bindings](Configuration%3A-Key-Bindings.html). Only valid modifiers are allowed, e.g. `Super`, `Alt`, `Mod3`, `Mod5`, `Ctrl`, `Shift`.

By default, `Mod` is equal to `Super` when running niri on a TTY, and to `Alt` when running niri as a nested winit window.

> Note
> 
> There are a lot of default bindings with Mod, none of them "make it through" to the underlying window. You probably don't want to set `mod-key` to Ctrl or Shift, since Ctrl is commonly used for app hotkeys, and Shift is used for, well, regular typing.

```kdl
// Switch the mod keys around: use Alt normally, and Super inside a nested window.
input {
    mod-key "Alt"
    mod-key-nested "Super"
}
```

---

## Layout

[](https://github.com/niri-wm/niri/edit/main/docs/wiki/Configuration:-Layout.md "Edit this page")

### Overview[#](#overview "Permanent link")

In the `layout {}` section you can change various settings that influence how windows are positioned and sized.

Here are the contents of this section at a glance:

```kdl
layout {
    gaps 16
    center-focused-column "never"
    always-center-single-column
    empty-workspace-above-first
    default-column-display "tabbed"
    background-color "#003300"

    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }

    default-column-width { proportion 0.5; }

    preset-window-heights {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }

    focus-ring {
        // off
        on
        width 4
        active-color "#7fc8ff"
        inactive-color "#505050"
        urgent-color "#9b0000"
        // active-gradient from="#80c8ff" to="#bbddff" angle=45
        // inactive-gradient from="#505050" to="#808080" angle=45 relative-to="workspace-view"
        // urgent-gradient from="#800" to="#a33" angle=45
    }

    border {
        off
        // on
        width 4
        active-color "#ffc87f"
        inactive-color "#505050"
        urgent-color "#9b0000"
        // active-gradient from="#ffbb66" to="#ffc880" angle=45 relative-to="workspace-view"
        // inactive-gradient from="#505050" to="#808080" angle=45 relative-to="workspace-view" in="srgb-linear"
        // urgent-gradient from="#800" to="#a33" angle=45
    }

    shadow {
        off
        // on
        softness 30
        spread 5
        offset x=0 y=5
        draw-behind-window true
        color "#00000070"
        // inactive-color "#00000054"
    }

    tab-indicator {
        // off
        on
        hide-when-single-tab
        place-within-column
        gap 5
        width 4
        length total-proportion=1.0
        position "right"
        gaps-between-tabs 2
        corner-radius 8
        active-color "red"
        inactive-color "gray"
        urgent-color "blue"
        // active-gradient from="#80c8ff" to="#bbddff" angle=45
        // inactive-gradient from="#505050" to="#808080" angle=45 relative-to="workspace-view"
        // urgent-gradient from="#800" to="#a33" angle=45
    }

    insert-hint {
        // off
        on
        color "#ffc87f80"
        // gradient from="#ffbb6680" to="#ffc88080" angle=45 relative-to="workspace-view"
    }

    struts {
        // left 64
        // right 64
        // top 64
        // bottom 64
    }
}
```

[Since: 25.11](https://github.com/niri-wm/niri/releases/tag/v25.11) You can override these settings for specific [outputs](Configuration%3A-Outputs.html#layout-config-overrides) and [named workspaces](Configuration%3A-Named-Workspaces.html#layout-config-overrides).

### `gaps`[#](#gaps "Permanent link")

Set gaps around (inside and outside) windows in logical pixels.

[Since: 0.1.7](https://github.com/niri-wm/niri/releases/tag/v0.1.7) You can use fractional values. The value will be rounded to physical pixels according to the scale factor of every output. For example, `gaps 0.5` on an output with `scale 2` will result in one physical-pixel wide gaps.

[Since: 0.1.8](https://github.com/niri-wm/niri/releases/tag/v0.1.8) You can emulate "inner" vs. "outer" gaps with negative `struts` values (see the struts section below).

```kdl
layout {
    gaps 16
}
```

### `center-focused-column`[#](#center-focused-column "Permanent link")

When to center a column when changing focus. This can be set to:

- `"never"`: no special centering, focusing an off-screen column will scroll it to the left or right edge of the screen. This is the default.
- `"always"`, the focused column will always be centered.
- `"on-overflow"`, focusing a column will center it if it doesn't fit on screen together with the previously focused column.

```kdl
layout {
    center-focused-column "always"
}
```

### `always-center-single-column`[#](#always-center-single-column "Permanent link")

[Since: 0.1.9](https://github.com/niri-wm/niri/releases/tag/v0.1.9)

If set, niri will always center a single column on a workspace, regardless of the `center-focused-column` option.

```kdl
layout {
    always-center-single-column
}
```

### `empty-workspace-above-first`[#](#empty-workspace-above-first "Permanent link")

[Since: 25.01](https://github.com/niri-wm/niri/releases/tag/v25.01)

If set, niri will always add an empty workspace at the very start, in addition to the empty workspace at the very end.

```kdl
layout {
    empty-workspace-above-first
}
```

### `default-column-display`[#](#default-column-display "Permanent link")

[Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02)

Sets the default display mode for new columns. Can be `normal` or `tabbed`.

```kdl
// Make all new columns tabbed by default.
layout {
    default-column-display "tabbed"

    // You may also want to hide the tab indicator
    // when there's only a single window in a column.
    tab-indicator {
        hide-when-single-tab
    }
}
```

### `preset-column-widths`[#](#preset-column-widths "Permanent link")

Set the widths that the `switch-preset-column-width` action (Mod+R) toggles between. [Since: 25.08](https://github.com/niri-wm/niri/releases/tag/v25.08) You can use the `switch-preset-column-width-back` action (Mod+Shift+R) to toggle in reverse.

`proportion` sets the width as a fraction of the output width, taking gaps into account. For example, you can perfectly fit four windows sized `proportion 0.25` on an output, regardless of the gaps setting. The default preset widths are 1⁄3, 1⁄2 and 2⁄3 of the output.

`fixed` sets the window width in logical pixels exactly.

```kdl
layout {
    // Cycle between 1/3, 1/2, 2/3 of the output, and a fixed 1280 logical pixels.
    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
        fixed 1280
    }
}
```

### `default-column-width`[#](#default-column-width "Permanent link")

Set the default width of the new windows.

The syntax is the same as in `preset-column-widths` above.

```kdl
layout {
    // Open new windows sized 1/3 of the output.
    default-column-width { proportion 0.33333; }
}
```

You can also leave the brackets empty, then the windows themselves will decide their initial width.

```kdl
layout {
    // New windows decide their initial width themselves.
    default-column-width {}
}
```

> Note
> 
> `default-column-width {}` causes niri to send a (0, H) size in the initial configure request.
> 
> This is a bit [unclearly defined](https://gitlab.freedesktop.org/wayland/wayland-protocols/-/issues/155) in the Wayland protocol, so some clients may misinterpret it. Either way, `default-column-width {}` is most useful for specific windows, in form of a [window rule](Configuration%3A-Window-Rules.html#default-column-width) with the same syntax.

### `preset-window-heights`[#](#preset-window-heights "Permanent link")

[Since: 0.1.9](https://github.com/niri-wm/niri/releases/tag/v0.1.9)

Set the heights that the `switch-preset-window-height` action (Mod+Ctrl+Shift+R) toggles between. [Since: 25.08](https://github.com/niri-wm/niri/releases/tag/v25.08) You can use the `switch-preset-window-height-back` action (not bound by default) to toggle in reverse.

`proportion` sets the height as a fraction of the output height, taking gaps into account. The default preset heights are 1⁄3, 1⁄2 and 2⁄3 of the output.

`fixed` sets the height in logical pixels exactly.

```kdl
layout {
    // Cycle between 1/3, 1/2, 2/3 of the output, and a fixed 720 logical pixels.
    preset-window-heights {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
        fixed 720
    }
}
```

### `focus-ring` and `border`[#](#focus-ring-and-border "Permanent link")

Focus ring and border are drawn around windows and indicate the active window. They are very similar and have the same options.

The difference is that the focus ring is drawn only around the active window, whereas borders are drawn around all windows and affect their sizes (windows shrink to make space for the borders).

| Focus Ring | Border |
| :--- | :--- |
| ![Screenshot showing a focused image in the center row using focus ring](img/focus-ring.png) | ![Screenshot showing a focused image in the center row using border, while top and bottom windows have the inactive color](img/border.png) |

> Tip
> 
> By default, focus ring and border are rendered as a solid background rectangle behind windows. That is, they will show up through semitransparent windows. This is because windows using client-side decorations can have an arbitrary shape.
> 
> If you don't like that, you should uncomment the [`prefer-no-csd` setting](Configuration%3A-Miscellaneous.html#prefer-no-csd) at the top level of the config. Niri will draw focus rings and borders _around_ windows that agree to omit their client-side decorations.
> 
> Alternatively, you can override this behavior with the [`draw-border-with-background` window rule](Configuration%3A-Window-Rules.html#draw-border-with-background).

Focus ring and border have the following options.

```kdl
layout {
    // focus-ring has the same options.
    border {
        // Uncomment this line to disable the border.
        // off

        // Width of the border in logical pixels.
        width 4

        active-color "#ffc87f"
        inactive-color "#505050"

        // Color of the border around windows that request your attention.
        urgent-color "#9b0000"

        // active-gradient from="#ffbb66" to="#ffc880" angle=45 relative-to="workspace-view"
        // inactive-gradient from="#505050" to="#808080" angle=45 relative-to="workspace-view" in="srgb-linear"
    }
}
```

#### Width[#](#width "Permanent link")

Set the thickness of the border in logical pixels.

[Since: 0.1.7](https://github.com/niri-wm/niri/releases/tag/v0.1.7) You can use fractional values. The value will be rounded to physical pixels according to the scale factor of every output. For example, `width 0.5` on an output with `scale 2` will result in one physical-pixel thick borders.

```kdl
layout {
    border {
        width 2
    }
}
```

#### Colors[#](#colors "Permanent link")

Colors can be set in a variety of ways:

- CSS named colors: `"red"`
- RGB hex: `"#rgb"`, `"#rgba"`, `"#rrggbb"`, `"#rrggbbaa"`
- CSS-like notation: `"rgb(255, 127, 0)"`, `"rgba()"`, `"hsl()"` and a few others.

`active-color` is the color of the focus ring / border around the active window, and `inactive-color` is the color of the focus ring / border around all other windows.

The _focus ring_ is only drawn around the active window on each monitor, so with a single monitor you will never see its `inactive-color`. You will see it if you have multiple monitors, though.

There's also a _deprecated_ syntax for setting colors with four numbers representing R, G, B and A: `active-color 127 200 255 255`.

#### Gradients[#](#gradients "Permanent link")

Similarly to colors, you can set `active-gradient` and `inactive-gradient`, which will take precedence.

Gradients are rendered the same as CSS [`linear-gradient(angle, from, to)`](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient). The angle works the same as in `linear-gradient`, and is optional, defaulting to `180` (top-to-bottom gradient). You can use any CSS linear-gradient tool on the web to set these up, like [css-gradient.com](https://www.css-gradient.com/).

```kdl
layout {
    focus-ring {
        active-gradient from="#80c8ff" to="#bbddff" angle=45
    }
}
```

Gradients can be colored relative to windows individually (the default), or to the whole view of the workspace. To do that, set `relative-to="workspace-view"`. Here's a visual example:

| Default | `relative-to="workspace-view"` |
| :--- | :--- |
| ![Screenshot displaying 4 windows, each with individual gradient borders](img/gradients-default.png) | ![Screenshot displaying 4 windows, with a shared gradient across their borders](img/gradients-relative-to-workspace-view.png) |

```kdl
layout {
    border {
        active-gradient from="#ffbb66" to="#ffc880" angle=45 relative-to="workspace-view"
        inactive-gradient from="#505050" to="#808080" angle=45 relative-to="workspace-view"
    }
}
```

[Since: 0.1.8](https://github.com/niri-wm/niri/releases/tag/v0.1.8) You can set the gradient interpolation color space using syntax like `in="srgb-linear"` or `in="oklch longer hue"`. Supported color spaces are:

- `srgb` (the default),
- `srgb-linear`,
- `oklab`,
- `oklch` with `shorter hue` or `longer hue` or `increasing hue` or `decreasing hue`.

They are rendered the same as CSS. For example, `active-gradient from="#f00f" to="#0f05" angle=45 in="oklch longer hue"` will look the same as CSS `linear-gradient(45deg in oklch longer hue, #f00f, #0f05)`.

![Screenshot showing a window with a border using a gradient in the oklch color space](img/gradients-oklch.png)

```kdl
layout {
    border {
        active-gradient from="#f00f" to="#0f05" angle=45 in="oklch longer hue"
    }
}
```

### `shadow`[#](#shadow "Permanent link")

[Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02)

Shadow rendered behind a window.

Set `on` to enable the shadow.

`softness` controls the shadow softness/size in logical pixels, same as [CSS box-shadow](https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow) _blur radius_. Setting `softness 0` will give you hard shadows.

`spread` is the distance to expand the window rectangle in logical pixels, same as CSS box-shadow spread. [Since: 25.05](https://github.com/niri-wm/niri/releases/tag/v25.05) Spread can be negative.

`offset` moves the shadow relative to the window in logical pixels, same as CSS box-shadow offset. For example, `offset x=2 y=2` will move the shadow 2 logical pixels downwards and to the right.

Set `draw-behind-window` to `true` to make shadows draw behind the window rather than just around it. Note that niri has no way of knowing about the CSD window corner radius. It has to assume that windows have square corners, leading to shadow artifacts inside the CSD rounded corners. This setting fixes those artifacts.

However, instead you may want to set `prefer-no-csd` and/or `geometry-corner-radius`. Then, niri will know the corner radius and draw the shadow correctly, without having to draw it behind the window. These will also remove client-side shadows if the window draws any.

`color` is the shadow color and opacity.

`inactive-color` lets you override the shadow color for inactive windows; by default, a more transparent `color` is used.

Shadow drawing will follow the window corner radius set with the [`geometry-corner-radius` window rule](Configuration%3A-Window-Rules.html#geometry-corner-radius).

> Note
> 
> Currently, shadow drawing only supports matching radius for all corners. If you set `geometry-corner-radius` to four values instead of one, the first (top-left) corner radius will be used for shadows.

```kdl
// Enable shadows.
layout {
    shadow {
        on
    }
}

// Also ask windows to omit client-side decorations, so that
// they don't draw their own window shadows.
prefer-no-csd
```

### `tab-indicator`[#](#tab-indicator "Permanent link")

[Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02)

Controls the appearance of the tab indicator that appears next to columns in tabbed display mode.

Set `off` to hide the tab indicator.

Set `hide-when-single-tab` to hide the indicator for tabbed columns that only have a single window.

Set `place-within-column` to put the tab indicator "within" the column, rather than outside. This will include it in column sizing and avoid overlaying adjacent columns.

`gap` sets the gap between the tab indicator and the window in logical pixels. The gap can be negative, this will put the tab indicator on top of the window.

`width` sets the thickness of the indicator in logical pixels.

`length` controls the length of the indicator. Set the `total-proportion` property to make tabs take up this much length relative to the window size. By default, the tab indicator has length equal to half of the window size, or `length total-proportion=0.5`.

`position` sets the position of the tab indicator relative to the window. It can be `left`, `right`, `top`, or `bottom`.

`gaps-between-tabs` controls the gap between individual tabs in logical pixels.

`corner-radius` sets the rounded corner radius for tabs in the indicator in logical pixels. When `gaps-between-tabs` is zero, only the first and the last tabs have rounded corners, otherwise all tabs do.

`active-color`, `inactive-color`, `urgent-color`, `active-gradient`, `inactive-gradient`, `urgent-gradient` let you override the colors for the tabs. They have the same semantics as the border and focus ring colors and gradients.

Tab colors are picked in this order:

1. Colors from the `tab-indicator` window rule, if set.
2. Colors from the `tab-indicator` layout options, if set (you're here).
3. If neither are set, niri picks the color matching the window border or focus ring, whichever one is active.

```kdl
// Make the tab indicator wider and match the window height,
// also put it at the top and within the column.
layout {
    tab-indicator {
        width 8
        gap 8
        length total-proportion=1.0
        position "top"
        place-within-column
    }
}
```

### `insert-hint`[#](#insert-hint "Permanent link")

[Since: 0.1.10](https://github.com/niri-wm/niri/releases/tag/v0.1.10)

Settings for the window insert position hint during an interactive window move.

`off` disables the insert hint altogether.

`color` and `gradient` let you change the color of the hint and have the same syntax as colors and gradients in border and focus ring.

```kdl
layout {
    insert-hint {
        // off
        color "#ffc87f80"
        gradient from="#ffbb6680" to="#ffc88080" angle=45 relative-to="workspace-view"
    }
}
```

### `struts`[#](#struts "Permanent link")

Struts shrink the area occupied by windows, similarly to layer-shell panels. You can think of them as a kind of outer gaps. They are set in logical pixels.

Left and right struts will cause the next window to the side to always peek out slightly. Top and bottom struts will simply add outer gaps in addition to the area occupied by layer-shell panels and regular gaps.

[Since: 0.1.7](https://github.com/niri-wm/niri/releases/tag/v0.1.7) You can use fractional values. The value will be rounded to physical pixels according to the scale factor of every output. For example, `top 0.5` on an output with `scale 2` will result in one physical-pixel wide top strut.

```kdl
layout {
    struts {
        left 64
        right 64
        top 64
        bottom 64
    }
}
```

![A screenshot illustrating the effects of struts, as explained in the second paragraph in this section](img/struts.png)

[Since: 0.1.8](https://github.com/niri-wm/niri/releases/tag/v0.1.8) You can use negative values. They will push the windows outwards, even outside the edges of the screen.

You can use negative struts with matching gaps value to emulate "inner" vs. "outer" gaps. For example, use this for inner gaps without outer gaps:

```kdl
layout {
    gaps 16

    struts {
        left -16
        right -16
        top -16
        bottom -16
    }
}
```

### `background-color`[#](#background-color "Permanent link")

[Since: 25.05](https://github.com/niri-wm/niri/releases/tag/v25.05)

Set the default background color that niri draws for workspaces. This is visible when you're not using any background tools like swaybg.

```kdl
layout {
    background-color "#003300"
}
```

You can also set the color per-output [in the output config](Configuration%3A-Outputs.html#layout-config-overrides).

---

## Window Rules

[](https://github.com/niri-wm/niri/edit/main/docs/wiki/Configuration:-Window-Rules.md "Edit this page")

### Overview[#](#overview "Permanent link")

Window rules let you adjust behavior for individual windows. They have `match` and `exclude` directives that control which windows the rule should apply to, and a number of properties that you can set.

Window rules are processed in order of appearance in the config file. This means that you can put more generic rules first, then override them for specific windows later. For example:

```kdl
// Set open-maximized to true for all windows.
window-rule {
    open-maximized true
}

// Then, for Alacritty, set open-maximized back to false.
window-rule {
    match app-id="Alacritty"
    open-maximized false
}
```

> Tip
> 
> In general, you cannot "unset" a property in a later rule, only set it to a different value. Use the `exclude` directives to avoid applying a rule for specific windows.

Here are all matchers and properties that a window rule could have:

```kdl
window-rule {
    match title="Firefox"
    match app-id="Alacritty"
    match is-active=true
    match is-focused=false
    match is-active-in-column=true
    match is-floating=true
    match is-window-cast-target=true
    match is-urgent=true
    match at-startup=true

    // Properties that apply once upon window opening.
    default-column-width { proportion 0.75; }
    default-window-height { fixed 500; }
    open-on-output "Some Company CoolMonitor 1234"
    open-on-workspace "chat"
    open-maximized true
    open-maximized-to-edges true
    open-fullscreen true
    open-floating true
    open-focused false

    // Properties that apply continuously.
    draw-border-with-background false
    opacity 0.5
    block-out-from "screencast"
    // block-out-from "screen-capture"
    variable-refresh-rate true
    default-column-display "tabbed"
    default-floating-position x=100 y=200 relative-to="bottom-left"
    scroll-factor 0.75

    focus-ring {
        // off
        on
        width 4
        active-color "#7fc8ff"
        inactive-color "#505050"
        urgent-color "#9b0000"
        // active-gradient from="#80c8ff" to="#bbddff" angle=45
        // inactive-gradient from="#505050" to="#808080" angle=45 relative-to="workspace-view"
        // urgent-gradient from="#800" to="#a33" angle=45
    }

    border {
        // Same as focus-ring.
    }

    shadow {
        // on
        off
        softness 40
        spread 5
        offset x=0 y=5
        draw-behind-window true
        color "#00000064"
        // inactive-color "#00000064"
    }

    tab-indicator {
        active-color "red"
        inactive-color "gray"
        urgent-color "blue"
        // active-gradient from="#80c8ff" to="#bbddff" angle=45
        // inactive-gradient from="#505050" to="#808080" angle=45 relative-to="workspace-view"
        // urgent-gradient from="#800" to="#a33" angle=45
    }

    geometry-corner-radius 12
    clip-to-geometry true
    tiled-state true
    baba-is-float true

    background-effect {
        xray true
        blur true
        noise 0.05
        saturation 3
    }

    popups {
        opacity 0.5
        geometry-corner-radius 15

        background-effect {
            xray true
            blur true
            noise 0.05
            saturation 3
        }
    }

    min-width 100
    max-width 200
    min-height 300
    max-height 300
}
```

### Window Matching[#](#window-matching "Permanent link")

Each window rule can have several `match` and `exclude` directives. In order for the rule to apply, a window needs to match _any_ of the `match` directives, and _none_ of the `exclude` directives.

```kdl
window-rule {
    // Match all Telegram windows...
    match app-id=r#"^org\.telegram\.desktop$"#

    // ...except the media viewer window.
    exclude title="^Media viewer$"

    // Properties to apply.
    open-on-output "HDMI-A-1"
}
```

Match and exclude directives have the same syntax. There can be multiple _matchers_ in one directive, then the window should match all of them for the directive to apply.

```kdl
window-rule {
    // Match Firefox windows with Gmail in title.
    match app-id="firefox" title="Gmail"
}

window-rule {
    // Match Firefox, but only when it is active...
    match app-id="firefox" is-active=true

    // ...or match Telegram...
    match app-id=r#"^org\.telegram\.desktop$"#

    // ...but don't match the Telegram media viewer.
    // If you open a tab in Firefox titled "Media viewer",
    // it will not be excluded because it doesn't match the app-id
    // of this exclude directive.
    exclude app-id=r#"^org\.telegram\.desktop$"# title="Media viewer"
}
```

Let's look at the matchers in more detail.

#### `title` and `app-id`[#](#title-and-app-id "Permanent link")

These are regular expressions that should match anywhere in the window title and app ID respectively. You can read about the supported regular expression syntax [here](https://docs.rs/regex/latest/regex/#syntax).

```kdl
// Match windows with title containing "Mozilla Firefox",
// or windows with app ID containing "Alacritty".
window-rule {
    match title="Mozilla Firefox"
    match app-id="Alacritty"
}
```

Raw KDL strings can be helpful for writing out regular expressions:

```kdl
window-rule {
    exclude app-id=r#"^org\.keepassxc\.KeePassXC$"#
}
```

You can find the title and the app ID of a window by running `niri msg pick-window` and clicking on the window in question.

> Tip
> 
> Another way to find the window title and app ID is to configure the `wlr/taskbar` module in [Waybar](https://github.com/Alexays/Waybar) to include them in the tooltip:
> 
> ```json
> "wlr/taskbar": {
>     "tooltip-format": "{title} | {app_id}",
> }
> ```

#### `is-active`[#](#is-active "Permanent link")

Can be `true` or `false`. Matches active windows (same windows that have the active border / focus ring color).

Every workspace on the focused monitor will have one active window. This means that you will usually have multiple active windows (one per workspace), and when you switch between workspaces, you can see two active windows at once.

```kdl
window-rule {
    match is-active=true
}
```

#### `is-focused`[#](#is-focused "Permanent link")

Can be `true` or `false`. Matches the window that has the keyboard focus.

Contrary to `is-active`, there can only be a single focused window. Also, when opening a layer-shell application launcher or pop-up menu, the keyboard focus goes to layer-shell. While layer-shell has the keyboard focus, windows will not match this rule.

```kdl
window-rule {
    match is-focused=true
}
```

#### `is-active-in-column`[#](#is-active-in-column "Permanent link")

[Since: 0.1.6](https://github.com/niri-wm/niri/releases/tag/v0.1.6)

Can be `true` or `false`. Matches the window that is the "active" window in its column.

Contrary to `is-active`, there is always one `is-active-in-column` window in each column. It is the window that was last focused in the column, i.e. the one that will gain focus if this column is focused.

[Since: 25.01](https://github.com/niri-wm/niri/releases/tag/v25.01) This rule will match `true` during the initial window opening.

```kdl
window-rule {
    match is-active-in-column=true
}
```

#### `is-floating`[#](#is-floating "Permanent link")

[Since: 25.01](https://github.com/niri-wm/niri/releases/tag/v25.01)

Can be `true` or `false`. Matches floating windows.

> Note
> 
> This matcher will apply only after the window is already open. This means that you cannot use it to change the window opening properties like `default-window-height` or `open-on-workspace`.

```kdl
window-rule {
    match is-floating=true
}
```

#### `is-window-cast-target`[#](#is-window-cast-target "Permanent link")

[Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02)

Can be `true` or `false`. Matches `true` for windows that are target of an ongoing window screencast.

> Note
> 
> This only matches individual-window screencasts. It will not match windows that happen to be visible in a monitor screencast, for example.

```kdl
// Indicate screencasted windows with red colors.
window-rule {
    match is-window-cast-target=true

    focus-ring {
        active-color "#f38ba8"
        inactive-color "#7d0d2d"
    }

    border {
        inactive-color "#7d0d2d"
    }

    shadow {
        color "#7d0d2d70"
    }

    tab-indicator {
        active-color "#f38ba8"
        inactive-color "#7d0d2d"
    }
}
```

Example:

![A screenshot showing that only the is-window-cast-target=true windows receive the special border colors](https://github.com/user-attachments/assets/375b381e-3a87-4e94-8676-44404971d893)

#### `is-urgent`[#](#is-urgent "Permanent link")

[Since: 25.05](https://github.com/niri-wm/niri/releases/tag/v25.05)

Can be `true` or `false`. Matches windows that request the user's attention.

```kdl
window-rule {
    match is-urgent=true
}
```

#### `at-startup`[#](#at-startup "Permanent link")

[Since: 0.1.6](https://github.com/niri-wm/niri/releases/tag/v0.1.6)

Can be `true` or `false`. Matches during the first 60 seconds after starting niri.

This is useful for properties like `open-on-output` which you may want to apply only right after starting niri.

```kdl
// Open windows on the HDMI-A-1 monitor at niri startup, but not afterwards.
window-rule {
    match at-startup=true
    open-on-output "HDMI-A-1"
}
```

### Window Opening Properties[#](#window-opening-properties "Permanent link")

These properties apply once, when a window first opens.

To be precise, they apply at the point when niri sends the initial configure request to the window.

#### `default-column-width`[#](#default-column-width "Permanent link")

Set the default width for the new window.

This works for floating windows too, despite the word "column" in the name.

```kdl
// Give Blender and GIMP some guaranteed width on opening.
window-rule {
    match app-id="^blender$"

    // GIMP app ID contains the version like "gimp-2.99",
    // so we only match the beginning (with ^) and not the end.
    match app-id="^gimp"

    default-column-width { fixed 1200; }
}
```

#### `default-window-height`[#](#default-window-height "Permanent link")

[Since: 25.01](https://github.com/niri-wm/niri/releases/tag/v25.01)

Set the default height for the new window.

```kdl
// Open the Firefox picture-in-picture window as floating with 480×270 size.
window-rule {
    match app-id="firefox$" title="^Picture-in-Picture$"

    open-floating true
    default-column-width { fixed 480; }
    default-window-height { fixed 270; }
}
```

#### `open-on-output`[#](#open-on-output "Permanent link")

Make the window open on a specific output.

If such an output does not exist, the window will open on the currently focused output as usual.

If the window opens on an output that is not currently focused, the window will not be automatically focused.

```kdl
// Open Firefox and Telegram (but not its Media Viewer)
// on a specific monitor.
window-rule {
    match app-id="firefox$"
    match app-id=r#"^org\.telegram\.desktop$"#
    exclude app-id=r#"^org\.telegram\.desktop$"# title="^Media viewer$"

    open-on-output "HDMI-A-1"
    // Or:
    // open-on-output "Some Company CoolMonitor 1234"
}
```

[Since: 0.1.9](https://github.com/niri-wm/niri/releases/tag/v0.1.9) `open-on-output` can now use monitor manufacturer, model, and serial. Before, it could only use the connector name.

#### `open-on-workspace`[#](#open-on-workspace "Permanent link")

[Since: 0.1.6](https://github.com/niri-wm/niri/releases/tag/v0.1.6)

Make the window open on a specific [named workspace](Configuration%3A-Named-Workspaces.html).

If such a workspace does not exist, the window will open on the currently focused workspace as usual.

If the window opens on an output that is not currently focused, the window will not be automatically focused.

```kdl
// Open Fractal on the "chat" workspace.
window-rule {
    match app-id=r#"^org\.gnome\.Fractal$"#

    open-on-workspace "chat"
}
```

#### `open-maximized`[#](#open-maximized "Permanent link")

Make the window open as a maximized column.

```kdl
// Maximize Firefox by default.
window-rule {
    match app-id="firefox$"

    open-maximized true
}
```

#### `open-maximized-to-edges`[#](#open-maximized-to-edges "Permanent link")

[Since: 25.11](https://github.com/niri-wm/niri/releases/tag/v25.11)

Make the window open [maximized to edges](Fullscreen-and-Maximize.html).

```kdl
window-rule {
    open-maximized-to-edges true
}
```

You can also set this to `false` to _prevent_ a window from opening maximized to edges.

```kdl
window-rule {
    open-maximized-to-edges false
}
```

#### `open-fullscreen`[#](#open-fullscreen "Permanent link")

Make the window open [fullscreen](Fullscreen-and-Maximize.html).

```kdl
window-rule {
    open-fullscreen true
}
```

You can also set this to `false` to _prevent_ a window from opening fullscreen.

```kdl
// Make the Telegram media viewer open in windowed mode.
window-rule {
    match app-id=r#"^org\.telegram\.desktop$"# title="^Media viewer$"

    open-fullscreen false
}
```

#### `open-floating`[#](#open-floating "Permanent link")

[Since: 25.01](https://github.com/niri-wm/niri/releases/tag/v25.01)

Make the window open in the floating layout.

```kdl
// Open the Firefox picture-in-picture window as floating.
window-rule {
    match app-id="firefox$" title="^Picture-in-Picture$"

    open-floating true
}
```

You can also set this to `false` to _prevent_ a window from opening in the floating layout.

```kdl
// Open all windows in the tiling layout, overriding any auto-floating logic.
window-rule {
    open-floating false
}
```

#### `open-focused`[#](#open-focused "Permanent link")

[Since: 25.01](https://github.com/niri-wm/niri/releases/tag/v25.01)

Set this to `false` to prevent this window from being automatically focused upon opening.

```kdl
// Don't give focus to the GIMP startup splash screen.
window-rule {
    match app-id="^gimp" title="^GIMP Startup$"

    open-focused false
}
```

You can also set this to `true` to focus the window, even if normally it wouldn't get auto-focused.

```kdl
// Always focus the KeePassXC-Browser unlock dialog.
//
// This dialog opens parented to the KeePassXC window rather than the browser,
// so it doesn't get auto-focused by default.
window-rule {
    match app-id=r#"^org\.keepassxc\.KeePassXC$"# title="^Unlock Database - KeePassXC$"

    open-focused true
}
```

### Dynamic Properties[#](#dynamic-properties "Permanent link")

These properties apply continuously to open windows.

#### `block-out-from`[#](#block-out-from "Permanent link")

You can block out windows from xdg-desktop-portal screencasts. They will be replaced with solid black rectangles.

This can be useful for password managers or messenger windows, etc. For layer-shell notification pop-ups and the like, you can use a [`block-out-from` layer rule](Configuration%3A-Layer-Rules.html#block-out-from).

![Screenshot showing a window visible normally, but blocked out on OBS.](img/block-out-from-screencast.png)

To preview and set up this rule, check the `preview-render` option in the debug section of the config.

> Caution
> 
> The window is **not** blocked out from third-party screenshot tools. If you open some screenshot tool with preview while screencasting, blocked out windows **will be visible** on the screencast.
> 
> The built-in screenshot UI is not affected by this problem though. If you open the screenshot UI while screencasting, you will be able to select the area to screenshot while seeing all windows normally, but on a screencast the selection UI will display with windows blocked out.

```kdl
// Block out password managers from screencasts.
window-rule {
    match app-id=r#"^org\.keepassxc\.KeePassXC$"#
    match app-id=r#"^org\.gnome\.World\.Secrets$"#

    block-out-from "screencast"
}
```

Alternatively, you can block out the window out of _all_ screen captures, including third-party screenshot tools. This way you avoid accidentally showing the window on a screencast when opening a third-party screenshot preview.

This setting will still let you use the interactive built-in screenshot UI, but it will block out the window from the fully automatic screenshot actions, such as `screenshot-screen` and `screenshot-window`. The reasoning is that with an interactive selection, you can make sure that you avoid screenshotting sensitive content.

```kdl
window-rule {
    block-out-from "screen-capture"
}
```

> Warning
> 
> Be careful when blocking out windows based on a dynamically changing window title.
> 
> For example, you might try to block out specific Firefox tabs like this:
> 
> ```kdl
> window-rule {
>     // Doesn't quite work! Try to block out the Gmail tab.
>     match app-id="firefox$" title="- Gmail "
> 
>     block-out-from "screencast"
> }
> ```
> 
> It will work, but when switching from a sensitive tab to a regular tab, the contents of the sensitive tab **will show up on a screencast** for an instant.
> 
> This is because window title (and app ID) are not double-buffered in the Wayland protocol, so they are not tied to specific window contents. There's no robust way for Firefox to synchronize visibly showing a different tab and changing the window title.

#### `opacity`[#](#opacity "Permanent link")

Set the opacity of the window. `0.0` is fully transparent, `1.0` is fully opaque. This is applied on top of the window's own opacity, so semitransparent windows will become even more transparent.

Opacity is applied to every surface of the window individually, so subsurfaces and pop-up menus will show window content behind them.

![Screenshot showing Adwaita Demo with a semitransparent pop-up menu.](img/opacity-popup.png)

Also, focus ring and border with background will show through semitransparent windows (see `prefer-no-csd` and the `draw-border-with-background` window rule below).

Opacity can be toggled on or off for a window using the [`toggle-window-rule-opacity`](Configuration%3A-Key-Bindings.html#toggle-window-rule-opacity) action.

```kdl
// Make inactive windows semitransparent.
window-rule {
    match is-active=false

    opacity 0.95
}
```

#### `variable-refresh-rate`[#](#variable-refresh-rate "Permanent link")

[Since: 0.1.9](https://github.com/niri-wm/niri/releases/tag/v0.1.9)

If set to true, whenever this window displays on an output with on-demand VRR, it will enable VRR on that output.

```kdl
// Configure some output with on-demand VRR.
output "HDMI-A-1" {
    variable-refresh-rate on-demand=true
}

// Enable on-demand VRR when mpv displays on the output.
window-rule {
    match app-id="^mpv$"

    variable-refresh-rate true
}
```

#### `default-column-display`[#](#default-column-display "Permanent link")

[Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02)

Set the default display mode for columns created from this window. Can be `normal` or `tabbed`.

This is used any time a window goes into its own column. For example: - Opening a new window. - Expelling a window into its own column. - Moving a window from the floating layout to the tiling layout.

```kdl
// Make Evince windows open as tabbed columns.
window-rule {
    match app-id="^evince$"

    default-column-display "tabbed"
}
```

#### `default-floating-position`[#](#default-floating-position "Permanent link")

[Since: 25.01](https://github.com/niri-wm/niri/releases/tag/v25.01)

Set the initial position for this window when it opens on, or moves to the floating layout.

Afterward, the window will remember its last floating position.

By default, new floating windows open at the center of the screen, and windows from the tiling layout open close to their visual screen position.

The position uses logical coordinates relative to the working area. By default, they are relative to the top-left corner of the working area, but you can change this by setting `relative-to` to one of these values: `top-left`, `top-right`, `bottom-left`, `bottom-right`, `top`, `bottom`, `left`, or `right`.

For example, if you have a bar at the top, then `x=0 y=0` will put the top-left corner of the window directly below the bar. If instead you write `x=0 y=0 relative-to="top-right"`, then the top-right corner of the window will align with the top-right corner of the workspace, also directly below the bar. When only one side is specified (e.g. top) the window will align to the center of that side.

The coordinates change direction based on `relative-to`. For example, by default (top-left), `x=100 y=200` will put the window 100 pixels to the right and 200 pixels down from the top-left corner. If you use `x=100 y=200 relative-to="bottom-left"`, it will put the window 100 pixels to the right and 200 pixels _up_ from the bottom-left corner.

```kdl
// Open the Firefox picture-in-picture window at the bottom-left corner of the screen
// with a small gap.
window-rule {
    match app-id="firefox$" title="^Picture-in-Picture$"

    default-floating-position x=32 y=32 relative-to="bottom-left"
}
```

You can use single-side `relative-to` to get a dropdown-like effect.

```kdl
// Example: a "dropdown" terminal.
window-rule {
    // Match by "dropdown" app ID.
    // You need to set this app ID when running your terminal, e.g.:
    // spawn "alacritty" "--class" "dropdown"
    match app-id="^dropdown$"

    // Open it as floating.
    open-floating true

    // Anchor to the top edge of the screen.
    default-floating-position x=0 y=0 relative-to="top"

    // Half of the screen high.
    default-window-height { proportion 0.5; }

    // 80% of the screen wide.
    default-column-width { proportion 0.8; }
}
```

#### `scroll-factor`[#](#scroll-factor "Permanent link")

[Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02)

Set a scroll factor for all scroll events sent to a window.

This will be multiplied with the scroll factor set for your input device in the [input section](Configuration%3A-Input.html#pointing-devices).

```kdl
// Make scrolling in Firefox a bit slower.
window-rule {
    match app-id="firefox$"

    scroll-factor 0.75
}
```

#### `draw-border-with-background`[#](#draw-border-with-background "Permanent link")

Override whether the border and the focus ring draw with a background.

Set this to `true` to draw them as solid colored rectangles even for windows which agreed to omit their client-side decorations. Set this to `false` to draw them as borders around the window even for windows which use client-side decorations.

This property can be useful for rectangular windows that do not support the xdg-decoration protocol.

| With Background | Without Background |
| :--- | :--- |
| ![A screenshot displaying a window with draw-border-with-background set to true](img/simple-egl-border-with-background.png) | ![A screenshot displaying a window with draw-border-with-background set to false](img/simple-egl-border-without-background.png) |

```kdl
window-rule {
    draw-border-with-background false
}
```

#### `focus-ring` and `border`[#](#focus-ring-and-border "Permanent link")

[Since: 0.1.6](https://github.com/niri-wm/niri/releases/tag/v0.1.6)

Override the focus ring and border options for the window.

These rules have the same options as the normal [`focus-ring` and `border` config in the layout section](Configuration%3A-Layout.html#focus-ring-and-border), so check the documentation there.

However, in addition to `off` to disable the border/focus ring, this window rule has an `on` flag that enables the border/focus ring for the window even if it was otherwise disabled. The `on` flag has precedence over the `off` flag, in case both are set.

```kdl
window-rule {
    focus-ring {
        off
        width 2
    }
}

window-rule {
    border {
        on
        width 8
    }
}
```

#### `shadow`[#](#shadow "Permanent link")

[Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02)

Override the shadow options for the window.

This rule has the same options as the normal [`shadow` config in the layout section](Configuration%3A-Layout.html#shadow), so check the documentation there.

However, in addition to `on` to enable the shadow, this window rule has an `off` flag that disables the shadow for the window even if it was otherwise enabled. The `on` flag has precedence over the `off` flag, in case both are set.

```kdl
// Turn on shadows for floating windows.
window-rule {
    match is-floating=true

    shadow {
        on
    }
}
```

#### `tab-indicator`[#](#tab-indicator "Permanent link")

[Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02)

Override the tab indicator options for the window.

Options in this rule match the same options as the normal [`tab-indicator` config in the layout section](Configuration%3A-Layout.html#tab-indicator), so check the documentation there.

```kdl
// Make KeePassXC tab have a dark red inactive color.
window-rule {
    match app-id=r#"^org\.keepassxc\.KeePassXC$"#

    tab-indicator {
        inactive-color "darkred"
    }
}
```

#### `geometry-corner-radius`[#](#geometry-corner-radius "Permanent link")

[Since: 0.1.6](https://github.com/niri-wm/niri/releases/tag/v0.1.6)

Set the corner radius of the window.

On its own, this setting will only affect the border and the focus ring—they will round their corners to match the geometry corner radius. If you'd like to force-round the corners of the window itself, set [`clip-to-geometry true`](#clip-to-geometry) in addition to this setting.

```kdl
window-rule {
    geometry-corner-radius 12
}
```

The radius is set in logical pixels, and controls the radius of the window itself, that is, the inner radius of the border:

![A screenshot showing a window with every corner rounded](img/geometry-corner-radius.png)

Instead of one radius, you can set four, for each corner. The order is the same as in CSS: top-left, top-right, bottom-right, bottom-left.

```kdl
window-rule {
    geometry-corner-radius 8 8 0 0
}
```

This way, you can match GTK 3 applications which have square bottom corners:

![A screenshot showing a window with only the top corners rounded](img/different-corner-radius.png)

#### `clip-to-geometry`[#](#clip-to-geometry "Permanent link")

[Since: 0.1.6](https://github.com/niri-wm/niri/releases/tag/v0.1.6)

Clips the window to its visual geometry.

This will cut out any client-side window shadows, and also round window corners according to `geometry-corner-radius`.

![A screenshot showing a window with rounded corners, clipped to the visual geometry](img/clip-to-geometry.png)

```kdl
window-rule {
    clip-to-geometry true
}
```

Enable border, set [`geometry-corner-radius`](#geometry-corner-radius) and `clip-to-geometry`, and you've got a classic setup:

![A screenshot showing a window with rounded corners, and a border](img/border-radius-clip.png)

```kdl
prefer-no-csd

layout {
    focus-ring {
        off
    }

    border {
        width 2
    }
}

window-rule {
    geometry-corner-radius 12
    clip-to-geometry true
}
```

#### `tiled-state`[#](#tiled-state "Permanent link")

[Since: 25.05](https://github.com/niri-wm/niri/releases/tag/v25.05)

Informs the window that it is tiled. Usually, windows will react by becoming rectangular and hiding their client-side shadows. Windows that snap their size to a grid (e.g. terminals like [foot](https://codeberg.org/dnkl/foot)) will usually disable this snapping when they are tiled.

By default, niri will set the tiled state to `true` together with [`prefer-no-csd`](Configuration%3A-Miscellaneous.html#prefer-no-csd) in order to improve behavior for apps that don't support server-side decorations. You can use this window rule to override this, for example to get rectangular windows with CSD.

```kdl
// Make tiled windows rectangular while using CSD.
window-rule {
    match is-floating=false

    tiled-state true
}
```

#### `baba-is-float`[#](#baba-is-float "Permanent link")

[Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02)

Make your windows FLOAT up and down.

This is an April Fools' 2025 feature.

```kdl
window-rule {
    match is-floating=true

    baba-is-float true
}
```

https://github.com/user-attachments/assets/3f4cb1a4-40b2-4766-98b7-eec014c19509

#### `background-effect`[#](#background-effect "Permanent link")

[Since: 26.04](https://github.com/niri-wm/niri/releases/tag/v26.04)

Override the background effect options for this window.

- `xray`: set to `true` to enable the xray effect, or `false` to disable it.
- `blur`: set to `true` to enable blur behind this window, or `false` to force-disable it.
- `noise`: amount of pixel noise added to the background (helps with color banding from blur).
- `saturation`: color saturation of the background (`0` is desaturated, `1` is normal, `2` is 200% saturation).

See the [window effects page](Window-Effects.html) for an overview of background effects.

```kdl
// Make floating windows use the regular blur (if enabled),
// while tiled windows keep using the efficient xray blur.
//
// Warning: non-xray blur is currently experimental and has known limitations.
// In particular, it doesn't work during window opening and closing animations.
window-rule {
    match is-floating=true

    background-effect {
        xray false
    }
}
```

#### `popups`[#](#popups "Permanent link")

[Since: 26.04](https://github.com/niri-wm/niri/releases/tag/v26.04)

Override properties for this window's pop-ups (menus and tooltips).

The properties work the same way as the corresponding window-rule properties, except that they apply to the window's pop-ups rather than to the window itself.

`opacity` is applied _on top_ of the layer surface's own opacity rule, so setting both will make pop-ups more transparent than the surface. Other properties apply independently.

> Note
> 
> This block affects only pop-ups created by the app via Wayland's [xdg-popup](https://wayland.app/protocols/xdg-shell#xdg_popup) (which should be most of them).
> 
> Examples of things that look like pop-ups that won't work:
> 
> - Fully emulated by the client, i.e. not a pop-up at all, the client just draws something that looks like a pop-up inside its window. These are common in game engines and in web apps, e.g. the right click menu in Google Docs or in Electron apps like Discord.
> - Uses a wl-subsurface instead of an xdg-popup. Common in older apps using GTK 3, notably Firefox still uses these for some menus. Subsurfaces are an indivisible part of a surface and they aren't usually pop-ups, so it wouldn't make sense for niri to apply these rules to them.
> 
> These emulated pop-ups come with other downsides: they cannot reliably extend outside their window, and if the app tries to do that, they will be clipped by rules such as `clip-to-geometry`. So most modern apps will correctly use xdg-popup, which is the intended way to show pop-ups on Wayland.
> 
> This block also does not affect input-method pop-ups, such as Fcitx.
> 
> For pop-ups created by your desktop shell or desktop components, use the corresponding [layer rule](Configuration%3A-Layer-Rules.html#popups).

```kdl
// Blur the background behind pop-up menus in Nautilus.
window-rule {
    match app-id="Nautilus"

    popups {
        // Matches the default libadwaita pop-up corner radius.
        geometry-corner-radius 15

        // Note: it'll look better to set background opacity
        // through your GTK theme CSS and not here.
        // This is just an example that makes it look obvious.
        opacity 0.5

        background-effect {
            blur true
        }
    }
}
```

Keep in mind that the background effect will look right only if the pop-up is shaped like a (rounded) rectangle, and the window correctly sets its Wayland geometry to exclude any shadows. For example, GTK 4 pop-ups with pointing arrows (`has-arrow=true` property) are _not_ rounded rectangles—the arrow sticks out—so if you enable blur, it will also stick out of the pop-up.

| Correct | Wrong |
| :--- | :--- |
| The pop-up is a rounded rectangle. Blur looks fine. | The pop-up is not a rounded rectangle. Blur extends above, where the arrow is. |
| ![](img/popup-no-arrow.png) | ![](img/popup-arrow.png) |

These pop-ups with custom shapes will need the app to implement the [ext-background-effect protocol](https://wayland.app/protocols/ext-background-effect-v1) to work properly.

#### Size Overrides[#](#size-overrides "Permanent link")

You can amend the window's minimum and maximum size in logical pixels.

Keep in mind that the window itself always has a final say in its size. These values instruct niri to never ask the window to be smaller than the minimum you set, or to be bigger than the maximum you set.

> Note
> 
> `max-height` will only apply to automatically-sized windows if it is equal to `min-height`. Either set it equal to `min-height`, or change the window height manually after opening it with `set-window-height`.
> 
> This is a limitation of niri's window height distribution algorithm.

```kdl
window-rule {
    min-width 100
    max-width 200
    min-height 300
    max-height 300
}
```

```kdl
// Fix OBS with server-side decorations missing a minimum width.
window-rule {
    match app-id=r#"^com\.obsproject\.Studio$"#

    min-width 876
}
```

---

# Layer Rules

[](https://github.com/niri-wm/niri/edit/main/docs/wiki/Configuration:-Layer-Rules.md "Edit this page")

### Overview[#](#overview "Permanent link")

[Since: 25.01](https://github.com/niri-wm/niri/releases/tag/v25.01)

Layer rules let you adjust behavior for individual layer-shell surfaces. They have `match` and `exclude` directives that control which layer-shell surfaces the rule should apply to, and a number of properties that you can set.

Layer rules are processed and work very similarly to window rules, just with different matchers and properties. Please read the [window rules wiki page](Configuration%3A-Window-Rules.html) to learn how matching works.

Here are all matchers and properties that a layer rule could have:

```kdl
layer-rule {
    match namespace="waybar"
    match at-startup=true
    match layer="top"

    // Properties that apply continuously.
    opacity 0.5
    block-out-from "screencast"
    // block-out-from "screen-capture"

    shadow {
        on
        // off
        softness 40
        spread 5
        offset x=0 y=5
        draw-behind-window true
        color "#00000064"
        // inactive-color "#00000064"
    }

    geometry-corner-radius 12
    place-within-backdrop true
    baba-is-float true

    background-effect {
        xray true
        blur true
        noise 0.05
        saturation 3
    }

    popups {
        opacity 0.5
        geometry-corner-radius 6

        background-effect {
            xray true
            blur true
            noise 0.05
            saturation 3
        }
    }
}
```

### Layer Surface Matching[#](#layer-surface-matching "Permanent link")

Let's look at the matchers in more detail.

#### `namespace`[#](#namespace "Permanent link")

This is a regular expression that should match anywhere in the surface namespace. You can read about the supported regular expression syntax [here](https://docs.rs/regex/latest/regex/#syntax).

```kdl
// Match surfaces with namespace containing "waybar",
layer-rule {
    match namespace="waybar"
}
```

You can find the namespaces of all open layer-shell surfaces by running `niri msg layers`.

#### `at-startup`[#](#at-startup "Permanent link")

Can be `true` or `false`. Matches during the first 60 seconds after starting niri.

```kdl
// Show layer-shell surfaces with 0.5 opacity at niri startup, but not afterwards.
layer-rule {
    match at-startup=true

    opacity 0.5
}
```

#### `layer`[#](#layer "Permanent link")

[Since: 26.04](https://github.com/niri-wm/niri/releases/tag/v26.04)

Matches surfaces on this layer-shell layer. Can be `"background"`, `"bottom"`, `"top"`, or `"overlay"`.

```kdl
// Make all overlay-layer surfaces FLOAT.
layer-rule {
    match layer="overlay"

    baba-is-float true
}
```

### Dynamic Properties[#](#dynamic-properties "Permanent link")

These properties apply continuously to open layer-shell surfaces.

#### `block-out-from`[#](#block-out-from "Permanent link")

You can block out surfaces from xdg-desktop-portal screencasts or all screen captures. They will be replaced with solid black rectangles.

This can be useful for notifications.

The same caveats and instructions apply as for the [`block-out-from` window rule](Configuration%3A-Window-Rules.html#block-out-from), so check the documentation there.

![Screenshot showing a notification visible normally, but blocked out on OBS.](img/layer-block-out-from-screencast.png)

```kdl
// Block out mako notifications from screencasts.
layer-rule {
    match namespace="^notifications$"

    block-out-from "screencast"
}
```

#### `opacity`[#](#opacity "Permanent link")

Set the opacity of the surface. `0.0` is fully transparent, `1.0` is fully opaque. This is applied on top of the surface's own opacity, so semitransparent surfaces will become even more transparent.

Opacity is applied to every child of the layer-shell surface individually, so subsurfaces and pop-up menus will show window content behind them.

```kdl
// Make fuzzel semitransparent.
layer-rule {
    match namespace="^launcher$"

    opacity 0.95
}
```

#### `shadow`[#](#shadow "Permanent link")

[Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02)

Override the shadow options for the surface.

These rules have the same options as the normal [`shadow` config in the layout section](Configuration%3A-Layout.html#shadow), so check the documentation there.

Unlike window shadows, layer surface shadows always need to be enabled with a layer rule. That is, enabling shadows in the layout config section won't automatically enable them for layer surfaces.

> Note
> 
> Layer surfaces have no way to tell niri about their _visual geometry_. For example, if a layer surface includes some invisible margins (like mako), niri has no way of knowing that, and will draw the shadow behind the entire surface, including the invisible margins.
> 
> So to use niri shadows, you'll need to configure layer-shell clients to remove their own margins or shadows.

```kdl
// Add a shadow for fuzzel.
layer-rule {
    match namespace="^launcher$"

    shadow {
        on
    }

    // Fuzzel defaults to 10 px rounded corners.
    geometry-corner-radius 10
}
```

#### `geometry-corner-radius`[#](#geometry-corner-radius "Permanent link")

[Since: 25.02](https://github.com/niri-wm/niri/releases/tag/v25.02)

Set the corner radius of the surface.

This setting will only affect the shadow—it will round its corners to match the geometry corner radius.

```kdl
layer-rule {
    match namespace="^launcher$"

    geometry-corner-radius 12
}
```

#### `place-within-backdrop`[#](#place-within-backdrop "Permanent link")

[Since: 25.05](https://github.com/niri-wm/niri/releases/tag/v25.05)

Set to `true` to place the surface into the backdrop visible in the [Overview](Overview.html) and between workspaces.

This will only work for _background_ layer surfaces that ignore exclusive zones (typical for wallpaper tools). Layers within the backdrop will ignore all input.

```kdl
// Put swaybg inside the overview backdrop.
layer-rule {
    match namespace="^wallpaper$"

    place-within-backdrop true
}
```

#### `baba-is-float`[#](#baba-is-float "Permanent link")

[Since: 25.05](https://github.com/niri-wm/niri/releases/tag/v25.05)

Make your layer surfaces FLOAT up and down.

This is a natural extension of the [April Fools' 2025 feature](Configuration%3A-Window-Rules.html#baba-is-float).

```kdl
// Make fuzzel FLOAT.
layer-rule {
    match namespace="^launcher$"

    baba-is-float true
}
```

#### `background-effect`[#](#background-effect "Permanent link")

[Since: 26.04](https://github.com/niri-wm/niri/releases/tag/v26.04)

Override the background effect options for this surface.

- `xray`: set to `true` to enable the xray effect, or `false` to disable it.
- `blur`: set to `true` to enable blur behind this surface, or `false` to force-disable it.
- `noise`: amount of pixel noise added to the background (helps with color banding from blur).
- `saturation`: color saturation of the background (`0` is desaturated, `1` is normal, `2` is 200% saturation).

See the [window effects page](Window-Effects.html) for an overview of background effects.

```kdl
// Make top and overlay layers use the regular blur (if enabled),
// while bottom and background layers keep using the efficient xray blur.
layer-rule {
    match layer="top"
    match layer="overlay"

    background-effect {
        xray false
    }
}
```

#### `popups`[#](#popups "Permanent link")

[Since: 26.04](https://github.com/niri-wm/niri/releases/tag/v26.04)

Override properties for this layer surface's pop-ups (e.g. a menu opened by clicking an item in Waybar).

The properties work the same way as the corresponding layer-rule properties, except that they apply to the layer surface's pop-ups rather than to the layer surface itself.

`opacity` is applied _on top_ of the layer surface's own opacity rule, so setting both will make pop-ups more transparent than the surface. Other properties apply independently.

> Note
> 
> This block affects only pop-ups created by the app via Wayland's [xdg-popup](https://wayland.app/protocols/xdg-shell#xdg_popup) (which should be most of them).
> 
> Some desktop shells will emulate pop-ups by drawing something that looks like a pop-up inside a regular layer surface. As far as niri is concerned, those are just layer surfaces and not pop-ups, so this block won't apply to them.
> 
> This block also does not affect input-method pop-ups, such as Fcitx.

```kdl
// Blur the background behind Waybar popup menus.
layer-rule {
    match namespace="^waybar$"

    popups {
        // Match the default GTK 3 popup corner radius.
        geometry-corner-radius 6
        opacity 0.85

        background-effect {
            blur true
        }
    }
}
```

Keep in mind that the background effect will look right only if the pop-up is shaped like a (rounded) rectangle, and the layer surface correctly sets its Wayland geometry to exclude any shadows. Pop-ups with custom shapes will need the app to implement the [ext-background-effect protocol](https://wayland.app/protocols/ext-background-effect-v1) to work properly.

---

## FAQ

[](https://github.com/niri-wm/niri/edit/main/docs/wiki/FAQ.md "Edit this page")

### How to disable client-side decorations/make windows rectangular?[#](#how-to-disable-client-side-decorationsmake-windows-rectangular "Permanent link")

Uncomment the [`prefer-no-csd` setting](Configuration%3A-Miscellaneous.html#prefer-no-csd) at the top level of the config, and then restart your apps. Then niri will ask windows to omit client-side decorations, and also inform them that they are being tiled (which makes some windows rectangular, even if they cannot omit the decorations).

Note that currently this will prevent edge window resize handles from showing up. You can still resize windows by holding Mod and the right mouse button.

### Why are transparent windows tinted? / Why is the border/focus ring showing up through semitransparent windows?[#](#why-are-transparent-windows-tinted-why-is-the-borderfocus-ring-showing-up-through-semitransparent-windows "Permanent link")

Uncomment the [`prefer-no-csd` setting](Configuration%3A-Miscellaneous.html#prefer-no-csd) at the top level of the config, and then restart your apps. Niri will draw focus rings and borders _around_ windows that agree to omit their client-side decorations.

By default, focus ring and border are rendered as a solid background rectangle behind windows. That is, they will show up through semitransparent windows. This is because windows using client-side decorations can have an arbitrary shape.

You can also override this behavior with the [`draw-border-with-background` window rule](Configuration%3A-Window-Rules.html#draw-border-with-background).

### How to enable rounded corners for all windows?[#](#how-to-enable-rounded-corners-for-all-windows "Permanent link")

Put this window rule in your config:

```kdl
window-rule {
    geometry-corner-radius 12
    clip-to-geometry true
}
```

For more information, check the [`geometry-corner-radius` window rule](Configuration%3A-Window-Rules.html#geometry-corner-radius).

### How to hide the "Important Hotkeys" pop-up at the start?[#](#how-to-hide-the-important-hotkeys-pop-up-at-the-start "Permanent link")

Put this into your config:

```kdl
hotkey-overlay {
    skip-at-startup
}
```

### How to fix lag on external monitors connected to a hybrid GPU laptop?[#](#how-to-fix-lag-on-external-monitors-connected-to-a-hybrid-gpu-laptop "Permanent link")

Hybrid GPU laptops (which have both an integrated and a discrete GPU) generally connect the external monitor port to the discrete GPU. Meanwhile, the built-in monitor is connected to the integrated GPU, and the integrated GPU is used for rendering by default.

This is good and expected because the integrated GPU uses significantly less battery compared to the discrete GPU. However, this means that niri has to render the external monitor contents on the integrated GPU, then copy them over to the discrete GPU for display. On some laptops this can cause lag and stuttering (it gets worse with monitor resolution and refresh rate).

If your laptop has a MUX switch—usually a GPU toggle in the UEFI settings—then you can switch it to use the discrete GPU, then niri will render on the discrete GPU, and the external monitor won't lag. Otherwise, you can try configuring niri to render on the discrete GPU via the [`render-drm-device`](Configuration%3A-Debug-Options.html#render-drm-device) debug option.

Keep in mind that using the discrete GPU for rendering will make the laptop's battery deplete much faster.

### How to run X11 apps like Steam or Discord?[#](#how-to-run-x11-apps-like-steam-or-discord "Permanent link")

To run X11 apps, you can use [xwayland-satellite](https://github.com/Supreeeme/xwayland-satellite). Check [the Xwayland wiki page](Xwayland.html) for instructions.

Keep in mind that you can run many Electron apps such as VSCode or Discord natively on Wayland by passing the right flags, as described [here](Application-Issues.html#electron-applications).

### Why doesn't niri integrate Xwayland like other compositors?[#](#why-doesnt-niri-integrate-xwayland-like-other-compositors "Permanent link")

A combination of factors:

- Integrating Xwayland is quite a bit of work, as the compositor needs to implement parts of an X11 window manager.
- You need to appease the X11 ideas of windowing, whereas for niri I want to have the best code for Wayland.
- niri doesn't have a good global coordinate system required by X11.
- You tend to get an endless stream of X11 bugs that take further time and effort away from other tasks.
- There aren't actually that many X11-only clients nowadays, and xwayland-satellite takes perfect care of most of those.
- niri isn't a Big Serious Desktop Environment which Must Support All Use Cases (and is Backed By Some Corporation).

All in all, the situation works out in favor of avoiding Xwayland integration.

[Since: 25.08](https://github.com/niri-wm/niri/releases/tag/v25.08) niri has seamless built-in xwayland-satellite integration that by and large works as well as built-in Xwayland in other compositors, solving the hurdle of having to set it up manually.

I wouldn't be too surprised if, down the road, xwayland-satellite becomes the standard way of integrating Xwayland into new compositors, since it takes on the bulk of the annoying work, and isolates the compositor from misbehaving clients.

### Can I enable blur behind semitransparent windows?[#](#can-i-enable-blur-behind-semitransparent-windows "Permanent link")

[Since: 26.04](https://github.com/niri-wm/niri/releases/tag/v26.04) Yes. See the [window effects](Window-Effects.html) wiki page.

### Can I make a window sticky / pinned / always on top / appear on all workspaces?[#](#can-i-make-a-window-sticky-pinned-always-on-top-appear-on-all-workspaces "Permanent link")

Not yet, follow/upvote [this issue](https://github.com/niri-wm/niri/issues/932).

You can emulate this with a script that uses the niri IPC. For example, [nirius](https://git.sr.ht/~tsdh/nirius) seems to have this feature (`toggle-follow-mode`).

### How do I make the Bitwarden window in Firefox open as floating?[#](#how-do-i-make-the-bitwarden-window-in-firefox-open-as-floating "Permanent link")

Firefox seems to first open the Bitwarden window with a generic Firefox title, and only later change the window title to Bitwarden, so you can't effectively target it with an `open-floating` window rule.

You'll need to use a script, for example [this one](https://github.com/niri-wm/niri/discussions/1599) or other ones (search niri issues and discussions for Bitwarden).

### Can I open a window directly in the current column / in the same column as another window?[#](#can-i-open-a-window-directly-in-the-current-column-in-the-same-column-as-another-window "Permanent link")

No, but you can script the behavior you want with the [niri IPC](IPC.html). Listen to the event stream for a new window opening, then call an action like `consume-or-expel-window-left`.

Adding this directly to niri is challenging:

- The act of "opening a window directly in some column" by itself is quite involved. Niri will have to compute the exact initial window size provided how other windows in a column would resize in response. This logic exists, but it isn't directly pluggable to the code computing a size for a new window. Then, it'll need to handle all sorts of edge cases like the column disappearing, or new windows getting added to the column, before the target window had a chance to appear.
- How do you indicate if a new window should spawn in an existing column (and in which one), as opposed to a new column? Different people seem to have different needs here (including very complex rules based on parent PID, etc.), and it's very unclear design-wise what kind of (simple) setting is actually needed and would be useful. See also [https://github.com/niri-wm/niri/discussions/1125](https://github.com/niri-wm/niri/discussions/1125).

### Why does moving the mouse against a monitor edge focus the next window, but only sometimes?[#](#why-does-moving-the-mouse-against-a-monitor-edge-focus-the-next-window-but-only-sometimes "Permanent link")

This can happen with [`focus-follows-mouse`](Configuration%3A-Input.html#focus-follows-mouse). When using client-side decorations, windows are supposed to have some margins outside their geometry for the mouse resizing handles. These margins "peek out" of the monitor edges since they're outside the window geometry, and `focus-follows-mouse` triggers when the mouse crosses them.

It doesn't always happen:

- Some toolkits don't put resize handles outside the window geometry. Then there's no input area outside, so nowhere for `focus-follows-mouse` to trigger.
- If the current window has its own margin for resizing, and it extends all the way to the monitor edge, then `focus-follows-mouse` won't trigger because the mouse will never leave the current window.

To fix this, you can:

- Use `focus-follows-mouse max-scroll-amount="0%"`, which will prevent `focus-follows-mouse` from triggering when it would cause scrolling.
- Set `prefer-no-csd` which will generally cause clients to remove those resizing margins.

### How do I recover from a dead screen locker / from a red screen?[#](#how-do-i-recover-from-a-dead-screen-locker-from-a-red-screen "Permanent link")

When your screen locker dies, you will be left with a red screen. This is niri's locked session background.

You can recover from this by spawning a new screen locker. One way is to switch to a different TTY (with a shortcut like Ctrl+Alt+F3) and spawning a screen locker to niri's Wayland display, e.g. `WAYLAND_DISPLAY=wayland-1 swaylock`.

Another way is to set `allow-when-locked=true` on your screen locker bind, then you can press it on the red screen to get a fresh screen locker.

```kdl
binds {
    Super+Alt+L allow-when-locked=true { spawn "swaylock"; }
}
```

### How do I change output configuration based on connected monitors?[#](#how-do-i-change-output-configuration-based-on-connected-monitors "Permanent link")

If you require different output configurations depending on what outputs are connected then you can use [Kanshi](https://gitlab.freedesktop.org/emersion/kanshi).

Kanshi has its own simple configuration and communicates with niri via IPC. You may want to launch kanshi from the niri config.kdl e.g. `spawn-at-startup "/usr/bin/kanshi"`

For example, if you wish to scale your laptop display differently when an external monitor is connected, you might use a Kanshi config like this:

```kdl
profile {
    output eDP-1 enable scale 1.0
}

profile {
    output HDMI-A-1 enable scale 1.0 position 0,0
    output eDP-1 enable scale 1.25 position 1920,0
}
```

### Why does Firefox or Thunderbird have 1 px smaller border?[#](#why-does-firefox-or-thunderbird-have-1-px-smaller-border "Permanent link")

They draw their own 1 px dark border around the window, which obscures one pixel of niri's border. If you don't like this, set the [`clip-to-geometry true` window rule](Configuration%3A-Window-Rules.html#clip-to-geometry).
