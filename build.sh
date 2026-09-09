#!/usr/bin/env bash
set -euo pipefail

THOR2D_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THOR2D_ODIN="${ODIN_BIN:-${HOME}/.local/opt/odin-dev-2026-09/odin}"

if [[ ! -x "${THOR2D_ODIN}" && "${1:-help}" != "deps" ]]; then
    printf 'Odin not found at %s. Run scripts/bootstrap_odin.sh or set ODIN_BIN.\n' "${THOR2D_ODIN}" >&2
    exit 1
fi

THOR2D_COLLECTION="-collection:thor2d=${THOR2D_ROOT}/src"

case "${1:-help}" in
    deps)
        "${THOR2D_ROOT}/scripts/bootstrap_odin.sh"
        THOR2D_ODIN_DIR="$(dirname "${THOR2D_ODIN}")" "${THOR2D_ROOT}/scripts/bootstrap_miniaudio.sh"
        THOR2D_ODIN_DIR="$(dirname "${THOR2D_ODIN}")" "${THOR2D_ROOT}/scripts/bootstrap_box2d.sh"
        ;;
    hello)
        mkdir -p "${THOR2D_ROOT}/bin"
        exec "${THOR2D_ODIN}" run "${THOR2D_ROOT}/examples/hello" "${THOR2D_COLLECTION}" -debug -out:"${THOR2D_ROOT}/bin/thor2d-hello"
        ;;
    pong)
        mkdir -p "${THOR2D_ROOT}/bin"
        exec "${THOR2D_ODIN}" run "${THOR2D_ROOT}/examples/pong" "${THOR2D_COLLECTION}" -debug -out:"${THOR2D_ROOT}/bin/thor2d-pong"
        ;;
    showcase)
        mkdir -p "${THOR2D_ROOT}/bin"
        exec "${THOR2D_ODIN}" run "${THOR2D_ROOT}/examples/showcase_v02" "${THOR2D_COLLECTION}" -debug -out:"${THOR2D_ROOT}/bin/thor2d-showcase-v02"
        ;;
    showcase-v04)
        mkdir -p "${THOR2D_ROOT}/bin"
        exec "${THOR2D_ODIN}" run "${THOR2D_ROOT}/examples/showcase_v04" "${THOR2D_COLLECTION}" -debug -out:"${THOR2D_ROOT}/bin/thor2d-showcase-v04"
        ;;
    project-run)
        target="${2:-${THOR2D_ROOT}/examples/platformer_v03}"
        if [[ "${target}" == *.thor ]]; then
            archive_path="${THOR2D_ROOT}/${target#"${THOR2D_ROOT}/"}"
            if [[ ! -f "${archive_path}" ]]; then
                printf 'Archive not found: %s\n' "${archive_path}" >&2
                exit 1
            fi
            python3 "${THOR2D_ROOT}/scripts/validate_package.py" "${archive_path}"
            package_dir="$(mktemp -d "${THOR2D_ROOT}/build/.run.XXXXXX")"
            trap 'rm -rf "${package_dir}"' EXIT
            executable_name="$(unzip -Z1 "${archive_path}" | rg '^thor2d-[^/]+$' | head -n1 || true)"
            if [[ -z "${executable_name}" ]]; then
                printf 'No executable found in package: %s\n' "${archive_path}" >&2
                exit 1
            fi
            unzip -p "${archive_path}" "${executable_name}" > "${package_dir}/${executable_name}"
            chmod u+x "${package_dir}/${executable_name}"
            set +e
            (cd "${package_dir}" && THOR2D_PACKAGE_ARCHIVE="${archive_path}" "./${executable_name}")
            status=$?
            set -e
            rm -rf "${package_dir}"
            trap - EXIT
            exit "${status}"
        fi
        mkdir -p "${THOR2D_ROOT}/bin"
        exec "${THOR2D_ODIN}" run "${THOR2D_ROOT}/${target#"${THOR2D_ROOT}/"}" "${THOR2D_COLLECTION}" -debug -out:"${THOR2D_ROOT}/bin/thor2d-project"
        ;;
    project-check)
        target="${2:-examples/platformer_v03}"
        if [[ "${target}" == *.thor ]]; then
            python3 "${THOR2D_ROOT}/scripts/validate_package.py" "${THOR2D_ROOT}/${target#"${THOR2D_ROOT}/"}"
            exit 0
        fi
        project_file="${THOR2D_ROOT}/${target#"${THOR2D_ROOT}/"}/project.json"
        if [[ ! -f "${project_file}" ]]; then
            printf 'Project manifest not found: %s\n' "${project_file}" >&2
            exit 1
        fi
        python3 "${THOR2D_ROOT}/scripts/validate_project.py" "${project_file}"
        ;;
    pack)
        target="${2:-examples/platformer_v03}"
        target_dir="${THOR2D_ROOT}/${target#"${THOR2D_ROOT}/"}"
        if [[ ! -d "${target_dir}" ]]; then
            printf 'Project directory not found: %s\n' "${target_dir}" >&2
            exit 1
        fi
        mkdir -p "${THOR2D_ROOT}/build"
        archive="${THOR2D_ROOT}/build/$(basename "${target_dir}").thor"
        rm -f "${archive}"
        staging="$(mktemp -d "${THOR2D_ROOT}/build/.pack.XXXXXX")"
        trap 'rm -rf "${staging}"' EXIT
        cp -a "${target_dir}/." "${staging}/"
        package_binary="thor2d-$(basename "${target_dir}" | tr '_' '-')"
        "${THOR2D_ODIN}" build "${target_dir}" "${THOR2D_COLLECTION}" -out:"${staging}/${package_binary}" -o:speed
        python3 "${THOR2D_ROOT}/scripts/create_package_manifest.py" "${staging}" "${staging}/thor2d-manifest.json"
        (cd "${staging}" && zip -qr "${archive}" .)
        rm -rf "${staging}"
        trap - EXIT
        printf 'Packed project: %s\n' "${archive}"
        ;;
    unpack)
        archive="${2:-build/platformer_v03.thor}"
        archive_path="${THOR2D_ROOT}/${archive#"${THOR2D_ROOT}/"}"
        if [[ ! -f "${archive_path}" ]]; then
            printf 'Archive not found: %s\n' "${archive_path}" >&2
            exit 1
        fi
        python3 "${THOR2D_ROOT}/scripts/validate_package.py" "${archive_path}"
        destination="${THOR2D_ROOT}/build/unpacked"
        mkdir -p "${destination}"
        unzip -oq "${archive_path}" -d "${destination}"
        printf 'Unpacked project: %s\n' "${destination}"
        ;;
    headless)
        target="${2:-examples/headless_simulation_v05}"
        "${THOR2D_ROOT}/build.sh" project-check "${target}"
        mkdir -p "${THOR2D_ROOT}/bin"
        exec "${THOR2D_ODIN}" run "${THOR2D_ROOT}/${target#"${THOR2D_ROOT}/"}" "${THOR2D_COLLECTION}" -debug -out:"${THOR2D_ROOT}/bin/thor2d-headless"
        ;;
    smoke)
        THOR2D_SMOKE=1 exec "${THOR2D_ODIN}" run "${THOR2D_ROOT}/examples/showcase_v04" "${THOR2D_COLLECTION}" -debug -out:"${THOR2D_ROOT}/bin/thor2d-smoke"
        ;;
    capabilities)
        "${THOR2D_ODIN}" run "${THOR2D_ROOT}/examples/capabilities_v05" "${THOR2D_COLLECTION}" -debug
        ;;
    parity-check)
        "${THOR2D_ROOT}/build.sh" check
        "${THOR2D_ROOT}/build.sh" test
        "${THOR2D_ROOT}/build.sh" project-check examples/platformer_v03
        python3 -m py_compile "${THOR2D_ROOT}/scripts/validate_project.py" "${THOR2D_ROOT}/scripts/create_package_manifest.py"
        if rg -n 'vendor:raylib|vendor:box2d|vendor:miniaudio|foreign import' "${THOR2D_ROOT}/examples"; then
            printf 'Native backend import found in examples.\n' >&2
            exit 1
        fi
        printf 'Thor2D parity checks passed.\n'
        ;;
    smoke-v05)
        THOR2D_SMOKE=1 exec "${THOR2D_ODIN}" run "${THOR2D_ROOT}/examples/audio_lab_v05" "${THOR2D_COLLECTION}" -debug -out:"${THOR2D_ROOT}/bin/thor2d-smoke-v05"
        ;;
    smoke-v06)
        THOR2D_SMOKE=1 exec "${THOR2D_ODIN}" run "${THOR2D_ROOT}/examples/showcase_v04" "${THOR2D_COLLECTION}" -debug -out:"${THOR2D_ROOT}/bin/thor2d-smoke-v06"
        ;;
    audio-check)
        THOR2D_SMOKE=1 exec "${THOR2D_ODIN}" run "${THOR2D_ROOT}/examples/audio_lab_v07" "${THOR2D_COLLECTION}" -debug -out:"${THOR2D_ROOT}/bin/thor2d-audio-check"
        ;;
    video-capabilities)
        exec "${THOR2D_ROOT}/scripts/check_ffmpeg.sh"
        ;;
    video-adapter)
        exec "${THOR2D_ROOT}/scripts/bootstrap_ffmpeg.sh"
        ;;
    video-build)
        "${THOR2D_ROOT}/scripts/bootstrap_ffmpeg.sh"
        mkdir -p "${THOR2D_ROOT}/bin"
        exec "${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/video_player_v07" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-video-player-v07-ffmpeg" -debug -define:THOR2D_FFMPEG=true
        ;;
    video-smoke)
        if ! command -v ffmpeg >/dev/null 2>&1; then
            printf 'Video smoke skipped: ffmpeg CLI is not installed.\n'
            exit 0
        fi
        "${THOR2D_ROOT}/build.sh" video-build
        mkdir -p "${THOR2D_ROOT}/build"
        ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc=size=64x48:rate=10 -t 0.4 -pix_fmt yuv420p -y "${THOR2D_ROOT}/build/thor2d-v07-smoke.mp4"
        THOR2D_VIDEO_PATH="${THOR2D_ROOT}/build/thor2d-v07-smoke.mp4" exec "${THOR2D_ROOT}/bin/thor2d-video-player-v07-ffmpeg"
        ;;
    smoke-v07)
        THOR2D_SMOKE=1 exec "${THOR2D_ODIN}" run "${THOR2D_ROOT}/examples/multimedia_showcase_v07" "${THOR2D_COLLECTION}" -debug -out:"${THOR2D_ROOT}/bin/thor2d-smoke-v07"
        ;;
    test)
        # Box2D owns process-global solver configuration; keep native physics
        # tests deterministic while pure Odin tests remain independent.
        exec "${THOR2D_ODIN}" test "${THOR2D_ROOT}/tests" "${THOR2D_COLLECTION}" -all-packages -debug -define:ODIN_TEST_THREADS=1
        ;;
    check)
        "${THOR2D_ODIN}" check "${THOR2D_ROOT}/src/thor2d" "${THOR2D_COLLECTION}" -no-entry-point -vet
        for example in hello pong showcase_v02 showcase_v04 platformer_v03 physics_lab project_scene headless_simulation_v05 capabilities_v05 audio_lab_v05 video_player_v05 physics_complete_v05 package_runner_v05 audio_lab_v07 audio_capture_v07 video_player_v07 multimedia_showcase_v07 async_assets_v07; do
            "${THOR2D_ODIN}" check "${THOR2D_ROOT}/examples/${example}" "${THOR2D_COLLECTION}" -vet
        done
        ;;
    build)
        mkdir -p "${THOR2D_ROOT}/bin"
        "${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/hello" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-hello" -o:speed
        "${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/pong" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-pong" -o:speed
        "${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/platformer_v03" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-platformer-v03" -o:speed
		"${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/showcase_v02" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-showcase-v02" -o:speed
		"${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/showcase_v04" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-showcase-v04" -o:speed
		"${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/headless_simulation_v05" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-headless-v05" -o:speed
		"${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/capabilities_v05" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-capabilities-v05" -o:speed
		"${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/audio_lab_v05" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-audio-lab-v05" -o:speed
		"${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/video_player_v05" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-video-player-v05" -o:speed
		"${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/physics_complete_v05" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-physics-v05" -o:speed
		"${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/package_runner_v05" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-package-runner-v05" -o:speed
		"${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/audio_lab_v07" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-audio-lab-v07" -o:speed
		"${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/audio_capture_v07" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-audio-capture-v07" -o:speed
		"${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/video_player_v07" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-video-player-v07" -o:speed
		"${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/multimedia_showcase_v07" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-multimedia-showcase-v07" -o:speed
		exec "${THOR2D_ODIN}" build "${THOR2D_ROOT}/examples/async_assets_v07" "${THOR2D_COLLECTION}" -out:"${THOR2D_ROOT}/bin/thor2d-async-assets-v07" -o:speed
        ;;
    *)
        cat <<'USAGE'
Thor2D development commands:
  ./build.sh deps    Install/check Odin and build the pinned Box2D dependency
  ./build.sh hello   Run the hello example
  ./build.sh pong    Run the Pong example
  ./build.sh showcase Run the v0.2 graphics showcase
  ./build.sh showcase-v04 Run the v0.4 API showcase
  ./build.sh project-run [dir] Run a project example
  ./build.sh project-check [dir] Validate project.json
  ./build.sh pack [dir] Pack a project into build/*.thor
  ./build.sh unpack [archive] Unpack a .thor archive
  ./build.sh headless [dir] Run a project with the null/headless backend
  ./build.sh capabilities Print runtime capability support
  ./build.sh parity-check Run v0.6 parity checks
  ./build.sh smoke-v05 Run the v0.5 smoke example
  ./build.sh smoke-v06 Run the v0.6 graphics/physics smoke example
  ./build.sh audio-check Run the dedicated miniaudio smoke example
  ./build.sh video-capabilities Probe optional FFmpeg libraries
  ./build.sh video-adapter Build the optional FFmpeg adapter when available
  ./build.sh video-build Compile the video example with FFmpeg enabled
  ./build.sh video-smoke Run the optional FFmpeg decode/seek smoke test
  ./build.sh smoke-v07 Run the v0.7 multimedia smoke example
  ./build.sh smoke Run the graphics smoke showcase
  ./build.sh test    Run framework tests
  ./build.sh check   Check the framework package
  ./build.sh build   Build a standalone hello binary

Set ODIN_BIN=/path/to/odin when Odin is installed elsewhere.
USAGE
        ;;
esac
