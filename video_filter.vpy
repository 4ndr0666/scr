from vapoursynth import core
import sys

input_video = sys.argv[1]
transformations = sys.argv[2]

# Load the video
video = core.lsmas.LWLibavSource(source=input_video)

# Apply the transformations
video = eval(transformations)

# Additional transformations

# Inverse Telecine (IVTC)
video = core.vivtc.VFM(video, order=1)
video = core.vivtc.VDecimate(video)

# Temporal Noise Reduction
video = core.tnlm.TNLMeans(video, ax=4, ay=4, az=2, s=3)

# Spatial Noise Reduction
video = core.knlm.KNLMeansCL(video, d=1, a=2, s=2, h=1.2)

# Debanding
video = core.f3kdb.Deband(video, range=15, y=64, cb=64, cr=64, grainy=0, grainc=0, output_depth=16)

# Sharpening
video = core.warp.AWarpSharp2(video, depth=10)

# Edge Enhancement
video = core.eedi3m.EEDI3(video, mthresh=20, lthresh=20, vcheck=3, nrad=2, mdis=20)

# Color Correction
video = core.resize.Bicubic(video, matrix_in_s="709", matrix_s="470bg")

# Subsampling
video = core.resize.Bicubic(video, format=vs.YUV420P16)

# Super Resolution
video = core.znedi3.nnedi3(video, field=3, dh=True, dw=True, qual=1)

# Binarization
video = core.f3kdb.Binarize(video, 128)

# Chroma Shift
video = core.misc.ChromaShift(video, c=-2)

# TemporalDegrain as an alternative to Deshake
video = core.mv.TemporalDegrain(video)

# Analyse as an alternative to Edge Detection
video = core.mv.Analyse(video)

# Inpainting
video = core.inpaint.Inpaint(video)

# Zooming
video = core.resize.Spline36(video, width=video.width*2, height=video.height*2)

# Set the output video
core.set_output(video)
