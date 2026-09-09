#!/usr/bin/env bash
set -euo pipefail

THOR2D_ODIN_DIR="${THOR2D_ODIN_DIR:-${HOME}/.local/opt/odin-dev-2026-09}"
MINIAUDIO_DIR="${THOR2D_ODIN_DIR}/vendor/miniaudio"

if [[ ! -x "${THOR2D_ODIN_DIR}/odin" ]]; then
    printf 'Odin not found at %s.\n' "${THOR2D_ODIN_DIR}" >&2
    exit 1
fi
if [[ ! -f "${MINIAUDIO_DIR}/src/miniaudio.c" || ! -f "${MINIAUDIO_DIR}/src/miniaudio.h" ]]; then
    printf 'miniaudio vendor source not found at %s.\n' "${MINIAUDIO_DIR}" >&2
    exit 1
fi

mkdir -p "${MINIAUDIO_DIR}/lib"
cc_bin="${CC:-cc}"
ar_bin="${AR:-ar}"
"${cc_bin}" -std=c99 -O2 -Os -fPIC -c "${MINIAUDIO_DIR}/src/miniaudio.c" -o "${MINIAUDIO_DIR}/src/miniaudio.o"
"${ar_bin}" rcs "${MINIAUDIO_DIR}/lib/miniaudio.a" "${MINIAUDIO_DIR}/src/miniaudio.o"
rm -f "${MINIAUDIO_DIR}/src/miniaudio.o"
printf 'miniaudio %s prepared at %s\n' "0.11.24" "${MINIAUDIO_DIR}/lib/miniaudio.a"
