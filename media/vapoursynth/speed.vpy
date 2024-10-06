svp_script_content = textwrap.dedent(f"""
import vapoursynth as vs
core = vs.core

# Load necessary plugins
core.std.LoadPlugin(r'{self.svp_plugins["lib1"]}')
core.std.LoadPlugin(r'{self.svp_plugins["lib2"]}')
core.std.LoadPlugin(r'{ffms2_plugin}')

# Load the video source
clip = core.ffms2.Source(r"{os.path.abspath(video.filepath)}")

# Ensure the format is set to YUV420P8
clip = clip.resize.Bicubic(format=vs.YUV420P8)

# Define the Super and Analyse parameters
super_params = dict(opt=0)
super = core.svp1.Super(clip, **super_params)

# Analyse motion vectors
analyse_params = dict(block=32, overlap=16)
vectors = core.svp1.Analyse(super["clip"], super["data"], clip, **analyse_params)

# Perform motion interpolation
smoothfps_params = dict(frate_num=int(clip.fps_num * {speed_factor}), frate_den=clip.fps_den)
smooth = core.svp2.SmoothFps(clip, super["clip"], super["data"], vectors["clip"], vectors["data"], **smoothfps_params)

# Ensure correct FPS assumption
smooth = core.std.AssumeFPS(smooth, fpsnum=int(clip.fps_num * {speed_factor}), fpsden=clip.fps_den)

# Set the final output of the VapourSynth script
smooth.set_output()

# Print the clip info for debugging
print("Clip info:", smooth)
""")
