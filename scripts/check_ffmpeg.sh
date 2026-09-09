#!/usr/bin/env bash
set -euo pipefail

if ! command -v pkg-config >/dev/null 2>&1; then
    printf 'FFmpeg: unavailable (pkg-config not installed)\n'
    exit 0
fi

modules=(libavformat libavcodec libavutil libswscale)
missing=0
for module in "${modules[@]}"; do
    if pkg-config --exists "${module}"; then
        printf '%s: %s\n' "${module}" "$(pkg-config --modversion "${module}")"
    else
        printf '%s: unavailable\n' "${module}"
        missing=1
    fi
done

if [[ "${missing}" -eq 0 ]]; then
    printf 'FFmpeg capability: detected; run ./build.sh video-adapter to build the private adapter.\n'
else
    printf 'FFmpeg capability: unavailable; Load_Video returns Capability_Unavailable.\n'
fi
