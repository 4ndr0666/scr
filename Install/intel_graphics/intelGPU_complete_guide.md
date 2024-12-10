# Complete Building Guide For IntelGPUs 

---

**All Builds In This Guide**:

1. Intel Gmmlib

2. Libva

3. Libva-Tools

4. Intel VPL Dev Package

5. Intel VPL-Tools
    
**Dependencies**:

```bash
sudo pacman -S autoconf libtool libdrm xorg xorg-dev openbox libx11-dev libgl1-mesa-glx git cmake pkg-config meson libdrm-dev automake libtool
```

**Firmware** (if needed):

```bash
git clone git@github.com:intel-gpu/intel-gpu-firmware.git
cd intel-gpu-firmware
sudo mkdir -p /lib/modules/"$(uname -r)"/updates/i915/
sudo cp firmware/*.bin /lib/modules/"$(uname -r)"/updates/i915/
```

## Build Phase 1:    

### Intel Gmmlib

This is the base component for the next component in the stack, the Intel Media Driver:

```bash
git clone https://github.com/intel/gmmlib.git
cd gmmlib
mkdir build && cd build
cmake [-DCMAKE_BUILD_TYPE=Release | Debug | ReleaseInternal] ..
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j"$(nproc)" 
sudo make install
```

## Build Phase 2:

### Libva

```bash
git clone https://github.com/intel/libva.git
cd libva
mkdir build 
cd build 
meson .. -Dprefix=/usr -Dlibdir=/usr/lib/x86_64-linux-gnu
ninja
sudo ninja install
```

### Libva-Tools

```bash
git clone https://github.com/intel/libva-utils.git
cd libva-utils
mkdir build
cd build
meson .. 
ninja
sudo ninja install
```

Validate the environment with `vainfo`. The output should look similar to:  

```bash
sys@KBL:~/github/libva-utils$ vainfo
Trying display: drm
libva info: VA-API version 1.14.0
libva info: Trying to open /usr/lib/x86_64-linux-gnu/dri/iHD_drv_video.so
libva info: Found init function __vaDriverInit_1_14
libva info: va_openDriver() returns 0
vainfo: VA-API version: 1.18 (libva 2.18.0.pre1)
vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 22.3.1 ()
vainfo: Supported profile and entrypoints
      VAProfileMPEG2Simple            : VAEntrypointVLD
      VAProfileMPEG2Main              : VAEntrypointVLD
      VAProfileH264Main               : VAEntrypointVLD
      VAProfileH264Main               : VAEntrypointEncSliceLP
      VAProfileH264High               : VAEntrypointVLD
      VAProfileH264High               : VAEntrypointEncSliceLP
      VAProfileJPEGBaseline           : VAEntrypointVLD
      VAProfileJPEGBaseline           : VAEntrypointEncPicture
      VAProfileH264ConstrainedBaseline: VAEntrypointVLD
      VAProfileH264ConstrainedBaseline: VAEntrypointEncSliceLP
      VAProfileVP8Version0_3          : VAEntrypointVLD
      VAProfileHEVCMain               : VAEntrypointVLD
      VAProfileHEVCMain10             : VAEntrypointVLD
      VAProfileVP9Profile0            : VAEntrypointVLD
      VAProfileVP9Profile2            : VAEntrypointVLD
```

**Explicitly set these environment variables**:

```bash
export LIBVA_DRIVERS_PATH=<path-contains-iHD_drv_video.so>
export LIBVA_DRIVER_NAME=iHD
```

## Build Phase 3

### Intel VPL Development Package

```bash
git clone https://github.com/intel/libvpl
pushd libvpl
export VPL_INSTALL_DIR=`pwd`/../_vplinstall
sudo script/bootstrap
cmake -B _build -DCMAKE_INSTALL_PREFIX=$VPL_INSTALL_DIR
cmake --build _build
cmake --install _build
popd
```

### Intel VPL-Tools

```bash
git clone https://github.com/intel/libvpl-tools
pushd libvpl-tools
export VPL_INSTALL_DIR=`pwd`/../_vplinstall
sudo script/bootstrap
cmake -B _build -DCMAKE_PREFIX_PATH=$VPL_INSTALL_DIR
cmake --build _build
cmake --install _build --prefix $VPL_INSTALL_DIR
```
