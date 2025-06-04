- This project is for FFMPEG and video manipulation.
- There are several iterations of the wrapper for historical purposes and to reference for optimiation.
- Use the following endpoints when sourcing through the web: [Filter Chains](https://alfg.dev/ffmpeg-commander/?video.preset=slow&video.pass=crf&video.bitrate=10M&video.frame_rate=60&video.faststart=true&video.size=1920&video.scaling=spline&audio.codec=none&filters.denoise=heavy), [Proper Encoding] (https://trac.ffmpeg.org/wiki/Encode/H.264), [Official Documentation](https://ffmpeg.org/documentation.html).
- Certainly. Below is a detailed plain-text instruction document you can paste into a coding-tuned model’s “custom instruction” field or context setup. It is purpose-built to rehydrate the context of your FFX project using only the content provided, so the model can operate with full awareness of the structure, principles, and current development state without requiring access to prior chat logs or additional documents.
- Module/Feature breakdown:
" 
The main purpose of this project is: Merge multiple video files losslessly or with fallback encoding if needed. Secure, stream-copy-first logic, with smart fallback encoding (lossless or fast).

**Features:**

* Secure temp file handling via `mktemp` and `trap`-driven cleanup
* Three encoding strategies:

  1. `-c copy` stream copy if compatible
  2. `-qp 0` lossless fallback (default)
  3. `-crf 15` fast fallback (`-q` flag)
* Optional `-f` to force overwrite
* Uses `.mp4` by default, configurable

**Supported options:**

* `-o <file>`: Set output name
* `-q`: Fast (CRF 15) mode
* `-f`: Force overwrite
* `-h`: Help/usage

---

### 🧪 Tests

Comprehensive BATS suite with:

* Argument/option parsing
* Stream copy tests
* Fallback lossless & fast encode
* Environment verification
* Error case handling
* Trap/cleanup verification

---

### 🧰 Dispatcher Core (ffxd-v3.2.sh)

**High-Level API Interface:**
Built on modular subcommands: `merge`, `probe`, `slowmo`, `looperang`, `process`

**Key Components:**

* Temp file helpers: `mk_tmp_out`, `register_temp_file`, `cleanup_all`
* Video/audio param generators: `get_video_opts`, `get_audio_opts`
* Audio filter generator: `generate_atempo` handles `atempo` chaining
* Output hygiene: `prepare_outdir` ensures directories are created before writing

**Subcommands:**

* `merge`: Concat files with filters if incompatible
* `slowmo`: Slows footage using `setpts=1/speed * PTS` and `atempo`
* `process`: Normalize resolution and fps
* `probe`: JSON metadata via ffprobe
* `looperang`: Creates a mirrored bounce animation

---

### 🔐 Security + Design Policies

* Absolute paths only (realpath enforced)
* No eval, no subshell injection
* Temporary resources cleaned on `INT`, `TERM`, `EXIT`
* No global state; all subcommands idempotent and composable
* Strict ShellCheck compliance in all scripts

---

### 🧱 Build/Install/Test (Makefile)

```
make install        # Install merge.sh to /usr/local/bin
make test           # Run BATS suite
make merge-fast     # Example run with fast fallback
make merge-lossless # Example run with lossless fallback
make clean          # Purge artifacts
```

---

### 🔐 SHA256 Checksum

Final validated package: `ffx`

```
89fcc0d41314300f941f8c943bd65473ca88530370808cae5a343258f483d21a
```
"
