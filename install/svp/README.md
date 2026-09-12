# Apple TV SVPlayer Config for SVPcast

This configuration optimizes SVPlayer on Apple TV when streaming real-time interpolated video over a local network via SVPcast (from an Arch Linux host or other desktop PC).

## The Problem with Desktop Configs on Apple TV
Standard desktop `mpv.conf` configurations (like 1GB+ caches or forced disk caching) will ruin playback on an Apple TV for three reasons:
1. **Aggressive RAM Limits:** tvOS strictly manages memory. Allocating a massive 1GB buffer to MPV will often cause tvOS to throttle or forcefully crash the SVPlayer app.
2. **Flash Storage Bottlenecks:** Using `cache-on-disk=yes` forces continuous read/write cycles to the Apple TV's internal eMMC storage. This causes severe I/O stuttering and unnecessarily degrades the flash memory.
3. **Network Jitter:** Using `cache-pause=no` forces the player to push through network drops instead of gracefully buffering, completely breaking the motion interpolation sync.

## The Optimized Configuration

In the SVPlayer Apple TV app, navigate to **Settings > mpv.conf** and apply the following parameters:

```text
# Enable caching but keep it strictly in Apple TV RAM
cache=yes
cache-on-disk=no           

# Allow the player to pause and buffer during Wi-Fi hiccups
cache-pause=yes            
cache-pause-initial=yes    

# tvOS-safe memory limits (plenty for HLS streams)
cache-secs=15              
demuxer-max-bytes=250MiB   
demuxer-max-back-bytes=50MiB

```

## Playback Notes

* **Startup Delay:** Because the host machine is encoding HLS chunks on the fly, allow a few seconds when starting a video for the Apple TV to fill its 250MiB buffer.
* **Seeking:** Fast-forwarding or rewinding will always be inherently sluggish compared to a local file. The host PC must dump the current buffer, jump to the new timestamp, and begin interpolating/encoding a fresh stream.
