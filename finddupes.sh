#!/usr/bin/env bash

time find . ! -empty -type f -print0 | xargs -0 -P"$(nproc)" -I{} sha256sum "{}" | sort | uniq -w64 -dD
#time find . ! -empty -type f -exec sha256sum {} + | sort | uniq -w32 -dD
