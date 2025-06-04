- A brief description of the ffx modules:

```markdown
**Fix**

In my experience, the most common issue that causes corrupt playback or broken renderings is incorrect timestamps. If you know of a superior method to resolve please explain and propose your ideas. This is the only method I could fathom due to limited knowledge:
    - Rectify the incorrect timestamps for appropriate playback like this: "Non-monotonic DTS; previous: 203586, current: 127672; changing to 203587. This may result in incorrect timestamps in the output file".

**Probe**

The upscaling software I use only accepts files with a maximum resolution of 1080p. The purpose of the `probe` operation is to quickly parse relavent info so I can determine which files need to be downscaled with the `process` option. Help me continue to enhance and refine this option by addressing the following issues:
    - The container line invariably displays "movmp4m4a3gp3g2mj2" no matter the selected file. Correct this.
    - Adjust the "File Size" output so that it is human readable.

**Process**

This option aims to losslessly and precisely process any video file to a max of 1080p. The core tenants of such a function should:
    - Opt for processing methods that allow for source quality output or as close to it as possible such as direct copy where applicable.

**Merge**

As the heart of our script, it needs to successfully merge any and all selected video files of varying parameters and values into a single file that is appropriate for flawless playback in any media player. It should opt for merging methods that allow for source-quality renders or as close to it as possible via direct copy when applicable.  
```

- Use the following endpoints when sourcing through the web: [Filter Chains](https://alfg.dev/ffmpeg-commander/?video.preset=slow&video.pass=crf&video.bitrate=10M&video.frame_rate=60&video.faststart=true&video.size=1920&video.scaling=spline&audio.codec=none&filters.denoise=heavy), [Proper Encoding] (https://trac.ffmpeg.org/wiki/Encode/H.264), [Official Documentation](https://ffmpeg.org/documentation.html)
