import vapoursynth as vs
core = vs.get_core()

# Ask the user for the video file
#video_file = input("Enter the path to your video file: ")

# --- Load the source video:
clip = core.ffms2.Source(source='input.mp4')

# --- Upscale models:
clip = core.vsrealesrgan.RealESRGAN(clip, model='4xBox')
#clip = core.vsrealesrgan.RealESRGAN(clip)

# --- Output the result:
clip.set_output()


# --- // How to run // --------||
# vspipe --y4m esrgan.vpy - | ffmpeg -i pipe: output.mp4
