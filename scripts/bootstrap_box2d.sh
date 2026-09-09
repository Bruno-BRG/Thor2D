#!/usr/bin/env bash
set -euo pipefail

THOR2D_ODIN_DIR="${THOR2D_ODIN_DIR:-${HOME}/.local/opt/odin-dev-2026-09}"
THOR2D_BOX2D_DIR="${THOR2D_ODIN_DIR}/vendor/box2d"
THOR2D_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -x "${THOR2D_ODIN_DIR}/odin" ]]; then
    printf 'Odin not found at %s. Run scripts/bootstrap_odin.sh first.\n' "${THOR2D_ODIN_DIR}" >&2
    exit 1
fi
if [[ ! -x "${THOR2D_BOX2D_DIR}/build_box2d.sh" ]]; then
    printf 'Box2D vendor source not found at %s.\n' "${THOR2D_BOX2D_DIR}" >&2
    exit 1
fi

cp "${THOR2D_ROOT}/scripts/box2d_bridge.odin" "${THOR2D_BOX2D_DIR}/thor2d_bridge.odin"
(cd "${THOR2D_BOX2D_DIR}" && ./build_box2d.sh)
printf 'Box2D 3.1.1 prepared at %s\n' "${THOR2D_BOX2D_DIR}"
