#!/usr/bin/env bash
set -euo pipefail

THOR2D_ODIN_VERSION="dev-2026-09"
THOR2D_ODIN_SHA256="167c3e1d7056419dad2e04bb3bd98715b7ff286d4c125f3c5a5ee337c6254283"
THOR2D_ODIN_DIR="${THOR2D_ODIN_DIR:-$HOME/.local/opt/odin-${THOR2D_ODIN_VERSION}}"
THOR2D_ODIN_ARCHIVE="${TMPDIR:-/tmp}/odin-linux-amd64-${THOR2D_ODIN_VERSION}.tar.gz"
THOR2D_ODIN_URL="https://github.com/odin-lang/Odin/releases/download/${THOR2D_ODIN_VERSION}/odin-linux-amd64-${THOR2D_ODIN_VERSION}.tar.gz"

if [[ -x "${THOR2D_ODIN_DIR}/odin" ]]; then
    "${THOR2D_ODIN_DIR}/odin" version
    exit 0
fi

mkdir -p "${THOR2D_ODIN_DIR}"
curl -fL --retry 3 -o "${THOR2D_ODIN_ARCHIVE}" "${THOR2D_ODIN_URL}"
echo "${THOR2D_ODIN_SHA256}  ${THOR2D_ODIN_ARCHIVE}" | sha256sum -c -
tar -xzf "${THOR2D_ODIN_ARCHIVE}" -C "${THOR2D_ODIN_DIR}" --strip-components=1

"${THOR2D_ODIN_DIR}/odin" version
printf 'Odin installed at %s\n' "${THOR2D_ODIN_DIR}"
printf 'The bundled vendor:raylib package is ready for Thor2D.\n'
