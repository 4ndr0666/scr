# Audioctl

## Dependencies

-Required Deps:

```bash
yay -S pipewire wireplumber pipewire-audio pipewire-alsa pipewire-pulse sof-firmware
```

## SystemD

```bash
sc-enable pipwire-pulse.service + socket
sc-disable pulseaudio.service + socket
```

## The Manual Reset

```bash
pulseaudio -k
pulseaudio -vvvvv &
```

## PacMD

```bash
set-sink-volume auto_null 0x3333
set-sink-mute auto_null no
suspend-sink auto_null yes
set-source-volume auto_null.monitor 0x101ea
set-source-mute auto_null.monitor no
suspend-source auto_null.monitor yes
set-default-sink auto_null
set-default-source auto_null.monitor
```
