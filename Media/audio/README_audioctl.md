## Audioctl README.md
---

### Pulseaudio Requirements

**-Conflicts & Resolution**

1. Pipewire-pulse conflicts with pulseaudio and pipewire-pulse.socket must be cleared
in order for pulseaudio to function properly:

```bash
Packages (1) pipewire-pulse-1:1.2.3-1

Total Removed Size:  0.48 MiB

:: Do you want to remove these packages? [Y/n] y
:: Processing package changes...
Removed '/etc/systemd/user/sockets.target.wants/pipewire-pulse.socket'.
(1/1) removing pipewire-pulse                      [------------------------] 100%
:: Running post-transaction hooks...
(1/5) Reloading user manager configuration...
(2/5) Arming ConditionNeedsUpdate...
(3/5) Updating executables in /usr/bin...
(4/5) Compiling GSettings XML schema files...
(5/5) Removing old packages from pacman cache...
Removing old installed packages...
==> no candidate packages found for pruning
Removing old uninstalled packages...

==> finished: 1 packages removed (disk space saved: 194 KiB)
```

2. The pipewire.socket must be cleared as well:

```bash
Removed '/home/andro/.config/systemd/user/default.target.wants/pulseaudio.service'.
Removed '/home/andro/.config/systemd/user/sockets.target.wants/pulseaudio.socket'.
○ pulseaudio.service - Sound Service
     Loaded: loaded (/usr/lib/systemd/user/pulseaudio.service; disabled; preset: enabled)
     Active: inactive (dead)
TriggeredBy: ○ pulseaudio.socket
The following unit files have been enabled in global scope. This means
they will still be started automatically after a successful disablement
in user scope:
pulseaudio.socket
○ pulseaudio.socket - Sound System
     Loaded: loaded (/usr/lib/systemd/user/pulseaudio.socket; enabled; preset: enabled)
     Active: inactive (dead)
   Triggers: ● pulseaudio.service
     Listen: /run/user/1000/pulse/native (Stream)
The following unit files have been enabled in global scope. This means
they will still be started automatically after a successful disablement
in user scope:
pipewire.socket
○ pipewire.socket - PipeWire Multimedia System Sockets
     Loaded: loaded (/usr/lib/systemd/user/pipewire.socket; enabled; preset: enabled)
     Active: inactive (dead) since Mon 2024-08-26 21:37:47 CDT; 17min ago
   Duration: 5h 44min 19.016s
 Invocation: 7c86d7b613a44b0a8b375fcdfc013564
   Triggers: ● pipewire.service
     Listen: /run/user/1000/pipewire-0 (Stream)
             /run/user/1000/pipewire-0-manager (Stream)

Aug 26 15:53:28 theworkpc systemd[1267]: Listening on PipeWire Multimedia System Sockets.
Aug 26 21:37:47 theworkpc systemd[1267]: Closed PipeWire Multimedia System Sockets.
```

**-Pkgs and Dependencies**

3. This is the complete suite of pkgs required for Pulseaudio to work properly:

```bash
warning: pulseaudio-bluetooth-17.0-3 is up to date -- skipping
resolving dependencies...
looking for conflicting packages...

Packages (7) pulseaudio-17.0-3  pulseaudio-equalizer-17.0-3  pulseaudio-jack-17.0-3
             pulseaudio-lirc-17.0-3  pulseaudio-rtp-17.0-3  pulseaudio-zeroconf-17.0-3
             pulseaudio-support-1-10

Total Download Size:   1.33 MiB
Total Installed Size:  6.50 MiB

:: Proceed with installation? [Y/n]
```

**-Enhancements/Extras**

3. These are the additional addons for pulse audio:

```bash
Optional dependencies for pulseaudio-support
    pavucontrol: A GTK volume control tool for PulseAudio [installed]
    pavucontrol-qt: A QT volume control tool for PulseAudio
    pulseaudio-equalizer-ladspa: A GUI equalizer for PulseAudio
    pasystray: PulseAudio system tray
    paprefs: Configuration dialog for PulseAudio
    pulseaudio-ctl: Control PulseAudio volume from the shell or mapped eyboard shortcuts
 ```

 ### Contingencies
 
1, **-Scenario:** After step 2 from above you still have no audio server running.

              *Audioctl Option 10*:

```bash
❯ Connection failure: Connection refused
  pa_context_connect() failed: Connection refused
❯ pulseaudio --check
❯ pulsemixer
Failed to connect to pulseaudio: Connection refused
❯ pulseaudio --start
❯ pulsemixer
❯ ./audioctl
[INFO] Checking and restarting audio services...
[WARNING] Neither PipeWire nor PulseAudio is active.
[INFO] Executing custom sequence...
[INFO] Running custom sequence to load snd_hda_intel module.
insmod: ERROR: could not load module snd_hda_intel.ko: No such file or directory
modprobe: FATAL: Module snd_hda_intel is in use.
[ERROR] Failed to reload snd_hda_intel module.
[INFO] Exiting the tool.
❯ Server Name: pulseaudio
```

2. **-Scenario:** After scenario 1 you now have a dummy input and no sound
                  cards are available to choose or listed.
                *pulseaudio -vvvvv*:
```bash
❯ pulseaudio -k
E: [pulseaudio] main.c: Failed to kill daemon: No such process
❯ pulseaudio -vvvvv &
[1] 209502
I: [pulseaudio] main.c: setrlimit(RLIMIT_NICE, (31, 31)) failed: Operation not permitted
I: [pulseaudio] main.c: setrlimit(RLIMIT_RTPRIO, (9, 9)) failed: Operation not permitted
D: [pulseaudio] core-rtclock.c: Timer slack is set to 50 us.

  ~                                                                                             at  10:22:16 PM
❯ D: [pulseaudio] core-util.c: RealtimeKit worked.
I: [pulseaudio] core-util.c: Successfully gained nice level -11.
I: [pulseaudio] main.c: This is PulseAudio 17.0
D: [pulseaudio] main.c: Compilation CFLAGS: Not yet supported on meson
D: [pulseaudio] main.c: Running on host: Linux x86_64 6.10.6-zen1-1-zen #1 ZEN SMP PREEMPT_DYNAMIC Mon, 19 Aug 2024 17:02:05 +0000
D: [pulseaudio] main.c: Found 2 CPUs.
I: [pulseaudio] main.c: Page size is 4096 bytes
D: [pulseaudio] main.c: Compiled with Valgrind support: yes
D: [pulseaudio] main.c: Running in valgrind mode: no
D: [pulseaudio] main.c: Running in VM: no
D: [pulseaudio] main.c: Running from build tree: no
D: [pulseaudio] main.c: Optimized build: yes
D: [pulseaudio] main.c: All asserts enabled.
I: [pulseaudio] main.c: Machine ID is 35714edd3b294d4c90cf3bef9e327ae3.
I: [pulseaudio] main.c: Session ID is 3.
I: [pulseaudio] main.c: Using runtime directory /run/user/1000/pulse.
I: [pulseaudio] main.c: Using state directory /home/andro/.config/pulse.
I: [pulseaudio] main.c: Using modules directory /usr/lib/pulseaudio/modules.
I: [pulseaudio] main.c: Running in system mode: no
I: [pulseaudio] main.c: System supports high resolution timers
D: [pulseaudio] memblock.c: Using shared memfd memory pool with 1024 slots of size 64.0 KiB each, total size is 64.0 MiB, maximum usable slot size is 65472
I: [pulseaudio] cpu-x86.c: CPU flags: CMOV MMX SSE SSE2 SSE3 SSSE3 SSE4_1 SSE4_2
I: [pulseaudio] svolume_mmx.c: Initialising MMX optimized volume functions.
I: [pulseaudio] remap_mmx.c: Initialising MMX optimized remappers.
I: [pulseaudio] svolume_sse.c: Initialising SSE2 optimized volume functions.
I: [pulseaudio] remap_sse.c: Initialising SSE2 optimized remappers.
I: [pulseaudio] sconv_sse.c: Initialising SSE2 optimized conversions.
I: [pulseaudio] svolume_orc.c: Initialising ORC optimized volume functions.
D: [pulseaudio] database-tdb.c: Opened TDB database '/home/andro/.config/pulse/35714edd3b294d4c90cf3bef9e327ae3-device-volumes.tdb'
I: [pulseaudio] database.c: Successfully opened 'device-volumes' database file '/home/andro/.config/pulse/35714edd3b294d4c90cf3bef9e327ae3-device-volumes.tdb'.
I: [pulseaudio] module.c: Loaded "module-device-restore" (index: #0; argument: "").
D: [pulseaudio] database-tdb.c: Opened TDB database '/home/andro/.config/pulse/35714edd3b294d4c90cf3bef9e327ae3-stream-volumes.tdb'
I: [pulseaudio] database.c: Successfully opened 'stream-volumes' database file '/home/andro/.config/pulse/35714edd3b294d4c90cf3bef9e327ae3-stream-volumes.tdb'.
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Ext.StreamRestore1 added for object /org/pulseaudio/stream_restore1
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Ext.StreamRestore1.RestoreEntry added for object /org/pulseaudio/stream_restore1/entry0
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Ext.StreamRestore1.RestoreEntry added for object /org/pulseaudio/stream_restore1/entry1
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Ext.StreamRestore1.RestoreEntry added for object /org/pulseaudio/stream_restore1/entry2
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Ext.StreamRestore1.RestoreEntry added for object /org/pulseaudio/stream_restore1/entry3
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Ext.StreamRestore1.RestoreEntry added for object /org/pulseaudio/stream_restore1/entry4
I: [pulseaudio] module.c: Loaded "module-stream-restore" (index: #1; argument: "").
D: [pulseaudio] database-tdb.c: Opened TDB database '/home/andro/.config/pulse/35714edd3b294d4c90cf3bef9e327ae3-card-database.tdb'
I: [pulseaudio] database.c: Successfully opened 'card-database' database file '/home/andro/.config/pulse/35714edd3b294d4c90cf3bef9e327ae3-card-database.tdb'.
I: [pulseaudio] module.c: Loaded "module-card-restore" (index: #2; argument: "").
I: [pulseaudio] module.c: Loaded "module-augment-properties" (index: #3; argument: "").
I: [pulseaudio] module.c: Loaded "module-switch-on-port-available" (index: #4; argument: "").
D: [pulseaudio] module.c: Checking for existence of '/usr/lib/pulseaudio/modules/module-udev-detect.so': success
D: [pulseaudio] module-udev-detect.c: /dev/snd/controlC0 is accessible: yes
D: [pulseaudio] module-udev-detect.c: /devices/pci0000:00/0000:00:1b.0/sound/card0 is busy: yes
I: [pulseaudio] module-udev-detect.c: Found 1 cards.
I: [pulseaudio] module.c: Loaded "module-udev-detect" (index: #5; argument: "").
D: [pulseaudio] module.c: Checking for existence of '/usr/lib/pulseaudio/modules/module-jackdbus-detect.so': success
D: [pulseaudio] dbus-util.c: Successfully connected to D-Bus session bus dbe444911b26c66f8cc421a566cceb48 as :1.482
D: [pulseaudio] module-jackdbus-detect.c: jackdbus isn't running.
I: [pulseaudio] module.c: Loaded "module-jackdbus-detect" (index: #6; argument: "channels=2").
D: [pulseaudio] module.c: Checking for existence of '/usr/lib/pulseaudio/modules/module-bluetooth-policy.so': success
I: [pulseaudio] module.c: Loaded "module-bluetooth-policy" (index: #7; argument: "").
D: [pulseaudio] module.c: Checking for existence of '/usr/lib/pulseaudio/modules/module-bluetooth-discover.so': success
D: [pulseaudio] module.c: Checking for existence of '/usr/lib/pulseaudio/modules/module-bluez5-discover.so': success
I: [pulseaudio] a2dp-codec-util.c: GStreamer initialisation done
D: [pulseaudio] dbus-util.c: Successfully connected to D-Bus system bus b05426699c97ee9718ca4b3666cceb31 as :1.414
I: [pulseaudio] module.c: Loaded "module-bluez5-discover" (index: #9; argument: "").
I: [pulseaudio] module.c: Loaded "module-bluetooth-discover" (index: #8; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Memstats added for object /org/pulseaudio/core1/memstats
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module0
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module1
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module2
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module3
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module4
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module5
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module6
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module7
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module8
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module9
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module10
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1 added for object /org/pulseaudio/core1
I: [pulseaudio] module.c: Loaded "module-dbus-protocol" (index: #10; argument: "").
D: [pulseaudio] module.c: Checking for existence of '/usr/lib/pulseaudio/modules/module-esound-protocol-unix.so': failure
I: [pulseaudio] module.c: Loaded "module-native-protocol-unix" (index: #11; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module11
D: [pulseaudio] module.c: Checking for existence of '/usr/lib/pulseaudio/modules/module-gsettings.so': success
I: [pulseaudio] module.c: Loaded "module-gsettings" (index: #12; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module12
I: [pulseaudio] module-default-device-restore.c: Restoring default sink 'alsa_output.pci-0000_00_1b.0.stereo-fallback'.
I: [pulseaudio] core.c: configured_default_sink: (unset) -> alsa_output.pci-0000_00_1b.0.stereo-fallback
I: [pulseaudio] module-default-device-restore.c: Restoring default source 'alsa_output.pci-0000_00_1b.0.analog-stereo.monitor'.
I: [pulseaudio] core.c: configured_default_source: (unset) -> alsa_output.pci-0000_00_1b.0.analog-stereo.monitor
D: [pulseaudio] core-subscribe.c: Dropped redundant event due to change event.
I: [pulseaudio] module.c: Loaded "module-default-device-restore" (index: #13; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module13
D: [pulseaudio] module-always-sink.c: Autoloading null-sink as no other sinks detected.
I: [pulseaudio] module-device-restore.c: Restoring volume for sink auto_null: front-left: 13107 /  20%,   front-right: 13107 /  20%
I: [pulseaudio] module-device-restore.c: Restoring mute state for sink auto_null: unmuted
I: [pulseaudio] sink.c: Created sink 0 "auto_null" with sample spec s16le 2ch 44100Hz and channel map front-left,front-right
I: [pulseaudio] sink.c:     device.description = "Dummy Output"
I: [pulseaudio] sink.c:     device.class = "abstract"
I: [pulseaudio] sink.c:     device.icon_name = "audio-card"
I: [pulseaudio] module-device-restore.c: Restoring volume for source auto_null.monitor: front-left: 66026 / 101%,   front-right: 66026 / 101%
I: [pulseaudio] module-device-restore.c: Restoring mute state for source auto_null.monitor: unmuted
I: [pulseaudio] source.c: Created source 0 "auto_null.monitor" with sample spec s16le 2ch 44100Hz and channel map front-left,front-right
I: [pulseaudio] source.c:     device.description = "Monitor of Dummy Output"
I: [pulseaudio] source.c:     device.class = "monitor"
I: [pulseaudio] source.c:     device.icon_name = "audio-input-microphone"
D: [null-sink] module-null-sink.c: Thread starting up
D: [null-sink] util.c: RealtimeKit worked.
I: [null-sink] util.c: Successfully enabled SCHED_RR scheduling for thread, with priority 5.
D: [pulseaudio] sink.c: auto_null: state: INIT -> IDLE
D: [pulseaudio] source.c: auto_null.monitor: state: INIT -> IDLE
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Device added for object /org/pulseaudio/core1/source0
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Source added for object /org/pulseaudio/core1/source0
I: [pulseaudio] core.c: default_source: (unset) -> auto_null.monitor
D: [pulseaudio] core-subscribe.c: Dropped redundant event due to change event.
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Device added for object /org/pulseaudio/core1/sink0
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Sink added for object /org/pulseaudio/core1/sink0
I: [pulseaudio] core.c: default_sink: (unset) -> auto_null
D: [pulseaudio] core-subscribe.c: Dropped redundant event due to change event.
I: [pulseaudio] module.c: Loaded "module-null-sink" (index: #15; argument: "sink_name=auto_null sink_properties='device.description="Dummy Output"'").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module15
I: [pulseaudio] module.c: Loaded "module-always-sink" (index: #14; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module14
I: [pulseaudio] module.c: Loaded "module-intended-roles" (index: #16; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module16
D: [pulseaudio] module-suspend-on-idle.c: Sink auto_null becomes idle, timeout in 5 seconds.
I: [pulseaudio] module.c: Loaded "module-suspend-on-idle" (index: #17; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module17
D: [pulseaudio] module.c: Checking for existence of '/usr/lib/pulseaudio/modules/module-console-kit.so': failure
D: [pulseaudio] module.c: Checking for existence of '/usr/lib/pulseaudio/modules/module-systemd-login.so': success
I: [pulseaudio] client.c: Created 0 "Login Session 3"
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Client added for object /org/pulseaudio/core1/client0
D: [pulseaudio] module-systemd-login.c: Added new session 3
I: [pulseaudio] client.c: Created 1 "Login Session 2"
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Client added for object /org/pulseaudio/core1/client1
D: [pulseaudio] module-systemd-login.c: Added new session 2
I: [pulseaudio] module.c: Loaded "module-systemd-login" (index: #18; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module18
I: [pulseaudio] module.c: Loaded "module-position-event-sounds" (index: #19; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module19
D: [pulseaudio] stream-interaction.c: Using role 'phone' as trigger role.
D: [pulseaudio] stream-interaction.c: Using roles 'music' and 'video' as cork roles.
I: [pulseaudio] module.c: Loaded "module-role-cork" (index: #20; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module20
I: [pulseaudio] module.c: Loaded "module-filter-heuristics" (index: #21; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module21
I: [pulseaudio] module.c: Loaded "module-filter-apply" (index: #22; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module22
D: [pulseaudio] main.c: Got org.PulseAudio1!
D: [pulseaudio] main.c: Got org.pulseaudio.Server!
I: [pulseaudio] main.c: Daemon startup complete.
E: [pulseaudio] bluez5-util.c: GetManagedObjects() failed: org.freedesktop.systemd1.NoSuchUnit: Unit dbus-org.bluez.service not found.
I: [pulseaudio] client.c: Created 2 "Native client (UNIX socket client)"
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Client added for object /org/pulseaudio/core1/client2
D: [pulseaudio] protocol-native.c: Protocol version: remote 35, local 35
I: [pulseaudio] protocol-native.c: Got credentials: uid=1000 gid=1000 success=1
D: [pulseaudio] protocol-native.c: SHM possible: yes
D: [pulseaudio] protocol-native.c: Negotiated SHM: yes
D: [pulseaudio] protocol-native.c: Memfd possible: yes
D: [pulseaudio] protocol-native.c: Negotiated SHM type: shared memfd
D: [pulseaudio] memblock.c: Using shared memfd memory pool with 1024 slots of size 64.0 KiB each, total size is 64.0 MiB, maximum usable slot size is 65472
D: [pulseaudio] srbchannel.c: SHM block is 65472 bytes, ringbuffer capacity is 2 * 32712 bytes
D: [pulseaudio] protocol-native.c: Enabling srbchannel...
D: [pulseaudio] module-augment-properties.c: Looking for .desktop file for waybar
D: [pulseaudio] protocol-native.c: Client enabled srbchannel.
I: [pulseaudio] module-suspend-on-idle.c: Sink auto_null idle for too long, suspending ...
D: [pulseaudio] sink.c: auto_null: suspend_cause: (none) -> IDLE
D: [pulseaudio] sink.c: auto_null: state: IDLE -> SUSPENDED
D: [pulseaudio] source.c: auto_null.monitor: suspend_cause: (none) -> IDLE
D: [pulseaudio] source.c: auto_null.monitor: state: IDLE -> SUSPENDED
D: [pulseaudio] module-suspend-on-idle.c: State of monitor source 'auto_null.monitor' has changed, checking state of❯
```
                *Pacmd*:

```bash
❯ pacmd
I: [pulseaudio] main.c: Got signal SIGUSR2.
I: [pulseaudio] module.c: Loaded "module-cli-protocol-unix" (index: #23; argument: "").
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Module added for object /org/pulseaudio/core1/module23
I: [pulseaudio] client.c: Created 3 "UNIX socket client"
D: [pulseaudio] protocol-dbus.c: Interface org.PulseAudio.Core1.Client added for object /org/pulseaudio/core1/client3
Welcome to PulseAudio 17.0! Use "help" for usage information.
>>> stat
Memory blocks currently allocated: 1, size: 63.9 KiB.
Memory blocks allocated during the whole lifetime: 13, size: 753.0 KiB.
Memory blocks imported from other processes: 0, size: 0 B.
Memory blocks exported to other processes: 0, size: 0 B.
Total sample cache size: 0 B.
Default sample spec: s16le 2ch 44100Hz
Default channel map: front-left,front-right
Default sink name: auto_null
Default source name: auto_null.monitor
Memory blocks of type POOL: 1 allocated/13 accumulated.
Memory blocks of type POOL_EXTERNAL: 0 allocated/0 accumulated.
Memory blocks of type APPENDED: 0 allocated/0 accumulated.
Memory blocks of type USER: 0 allocated/0 accumulated.
Memory blocks of type FIXED: 0 allocated/0 accumulated.
Memory blocks of type IMPORTED: 0 allocated/0 accumulated.
>>> dump
### Configuration dump generated at Mon Aug 26 22:22:47 2024

load-module module-device-restore
load-module module-stream-restore
load-module module-card-restore
load-module module-augment-properties
load-module module-switch-on-port-available
load-module module-udev-detect
load-module module-jackdbus-detect channels=2
load-module module-bluetooth-policy
load-module module-bluetooth-discover
load-module module-bluez5-discover
load-module module-dbus-protocol
load-module module-native-protocol-unix
load-module module-gsettings
load-module module-default-device-restore
load-module module-always-sink
load-module module-null-sink sink_name=auto_null sink_properties='device.description="Dummy Output"'
load-module module-intended-roles
load-module module-suspend-on-idle
load-module module-systemd-login
load-module module-position-event-sounds
load-module module-role-cork
load-module module-filter-heuristics
load-module module-filter-apply
load-module module-cli-protocol-unix

set-sink-volume auto_null 0x3333
set-sink-mute auto_null no
suspend-sink auto_null yes

set-source-volume auto_null.monitor 0x101ea
set-source-mute auto_null.monitor no
suspend-source auto_null.monitor yes

set-default-sink auto_null
set-default-source auto_null.monitor

### EOF
>>>
```
