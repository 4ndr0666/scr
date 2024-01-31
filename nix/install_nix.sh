#!/bin/sh

# This script installs the Nix package manager on your system by
# downloading a binary distribution and running its installer script
# (which in turn creates and populates /nix).

{ # Prevent execution if this script was only partially downloaded
oops() {
    echo "$0:" "$@" >&2
    exit 1
}

umask 0022

tmpDir="$(mktemp -d -t nix-binary-tarball-unpack.XXXXXXXXXX || \
          oops "Can't create temporary directory for downloading the Nix binary tarball")"
cleanup() {
    rm -rf "$tmpDir"
}
trap cleanup EXIT INT QUIT TERM

require_util() {
    command -v "$1" > /dev/null 2>&1 ||
        oops "you do not have '$1' installed, which I need to $2"
}

case "$(uname -s).$(uname -m)" in
    Linux.x86_64)
        hash=9b2fc17c7fd21da2899e23a3b324b7445d41a2ce4d648dedb28cf88b2809e32f
        path=d3khcw5f81dakz9zsrfp8zn8kbgwpjhx/nix-2.19.2-x86_64-linux.tar.xz
        system=x86_64-linux
        ;;
    Linux.i?86)
        hash=039e97a3eb78b866029c89b8ec29d1c9182902b75534c3c85336d475d8643ef6
        path=fmwpdbfz8w0hvjl01ky7lxqhkldqibg8/nix-2.19.2-i686-linux.tar.xz
        system=i686-linux
        ;;
    Linux.aarch64)
        hash=72f15ff89ab82e25617688e99f37ddd0fbc003219ee08310a30d7f1f3c032543
        path=f21ppb2zhr0k4s18186k3l154izqi4ag/nix-2.19.2-aarch64-linux.tar.xz
        system=aarch64-linux
        ;;
    Linux.armv6l)
        hash=af807854df33c4a06ca1db4463f85372d1948d7f8f77f96bdcb01fc6051b4d5e
        path=y71w5qfvsx10y168kl2ndmhfqhv9cq03/nix-2.19.2-armv6l-linux.tar.xz
        system=armv6l-linux
        ;;
    Linux.armv7l)
        hash=06eaaa646e5c4dd5a889d8d2138911090e6891eee7f0fac13bc2fc2c2d34b881
        path=jqjpixx91ml9p33x71w262pginvqkkgm/nix-2.19.2-armv7l-linux.tar.xz
        system=armv7l-linux
        ;;
    Darwin.x86_64)
        hash=be057f85909dd23374738fdcdc8588cb3d43e363a5fa4bd18896011ba719be80
        path=vjx61fsid2w48flfwg6pmcjy7mcahahn/nix-2.19.2-x86_64-darwin.tar.xz
        system=x86_64-darwin
        ;;
    Darwin.arm64|Darwin.aarch64)
        hash=dc9a3b109f547b212bfe8bcda40de33790186b5ff8bc9775cdcee5b53422d665
        path=skr53zjr7hxhcjxnwpwds6qs9izsfl50/nix-2.19.2-aarch64-darwin.tar.xz
        system=aarch64-darwin
        ;;
    *) oops "sorry, there is no binary distribution of Nix for your platform";;
esac

# Use this command-line option to fetch the tarballs using nar-serve or Cachix
if [ "${1:-}" = "--tarball-url-prefix" ]; then
    if [ -z "${2:-}" ]; then
        oops "missing argument for --tarball-url-prefix"
    fi
    url=${2}/${path}
    shift 2
else
    url=https://releases.nixos.org/nix/nix-2.19.2/nix-2.19.2-$system.tar.xz
fi

tarball=$tmpDir/nix-2.19.2-$system.tar.xz

require_util tar "unpack the binary tarball"
if [ "$(uname -s)" != "Darwin" ]; then
    require_util xz "unpack the binary tarball"
fi

if command -v curl > /dev/null 2>&1; then
    fetch() { curl --fail -L "$1" -o "$2"; }
elif command -v wget > /dev/null 2>&1; then
    fetch() { wget "$1" -O "$2"; }
else
    oops "you don't have wget or curl installed, which I need to download the binary tarball"
fi

echo "downloading Nix 2.19.2 binary tarball for $system from '$url' to '$tmpDir'..."
fetch "$url" "$tarball" || oops "failed to download '$url'"

if command -v sha256sum > /dev/null 2>&1; then
    hash2="$(sha256sum -b "$tarball" | cut -c1-64)"
elif command -v shasum > /dev/null 2>&1; then
    hash2="$(shasum -a 256 -b "$tarball" | cut -c1-64)"
elif command -v openssl > /dev/null 2>&1; then
    hash2="$(openssl dgst -r -sha256 "$tarball" | cut -c1-64)"
else
    oops "cannot verify the SHA-256 hash of '$url'; you need one of 'shasum', 'sha256sum', or 'openssl'"
fi

if [ "$hash" != "$hash2" ]; then
    oops "SHA-256 hash mismatch in '$url'; expected $hash, got $hash2"
fi

unpack=$tmpDir/unpack
mkdir -p "$unpack"
tar -xJf "$tarball" -C "$unpack" || oops "failed to unpack '$url'"

script=$(echo "$unpack"/*/install)

[ -e "$script" ] || oops "installation script is missing from the binary tarball!"
export INVOKED_FROM_INSTALL_IN=1
"$script" "$@"

} # End of wrapping
