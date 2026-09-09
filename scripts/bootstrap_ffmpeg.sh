#!/usr/bin/env bash
set -euo pipefail

THOR2D_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIDEO_DIR="${THOR2D_ROOT}/src/thor2d/internal/video"
VIDEO_LIB_DIR="${VIDEO_DIR}/lib"
CC_BIN="${CC:-cc}"

if ! command -v pkg-config >/dev/null 2>&1; then
    printf 'pkg-config is required to build the optional FFmpeg adapter.\n' >&2
    exit 1
fi
if ! pkg-config --exists libavformat libavcodec libavutil libswscale; then
    printf 'FFmpeg development libraries were not found; video remains capability-gated.\n' >&2
    exit 1
fi
if ! command -v "${CC_BIN}" >/dev/null 2>&1; then
    printf 'C compiler not found: %s\n' "${CC_BIN}" >&2
    exit 1
fi

mkdir -p "${VIDEO_LIB_DIR}"
"${CC_BIN}" -std=c11 -O2 -fPIC -Wall -Wextra \
    $(pkg-config --cflags libavformat libavcodec libavutil libswscale) \
    -c "${VIDEO_DIR}/video_shim.c" -o "${VIDEO_LIB_DIR}/video_shim.o"
ar rcs "${VIDEO_LIB_DIR}/thor2d_video.a" "${VIDEO_LIB_DIR}/video_shim.o"
rm -f "${VIDEO_LIB_DIR}/video_shim.o"
printf 'FFmpeg adapter built at %s\n' "${VIDEO_LIB_DIR}/thor2d_video.a"
