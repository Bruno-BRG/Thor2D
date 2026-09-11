# Thor2D dependencies

The v0.7 multimedia slice is validated on Linux AMD64 with:

| Dependency | Version/source | Reproducibility data |
| --- | --- | --- |
| Odin | `dev-2026-09` | SHA-256 pinned in `scripts/bootstrap_odin.sh` |
| Raylib | Odin `vendor:raylib` | supplied by the pinned Odin distribution; used only by the private backend |
| Box2D | `3.1.1` | built by Odin's `vendor/box2d/build_box2d.sh`; the AVX2 archive used locally is `85c2440e945d31b08db2bfe1d724bfe93147ded99ddf8d1fe9bd17987731f305` |
| zlib/LZ4 | bundled Odin vendor packages | used for ZLIB, GZIP, raw DEFLATE and LZ4 data codecs |
| miniaudio | Odin `vendor:miniaudio` `0.11.24` | compiled by `scripts/bootstrap_miniaudio.sh` into the pinned Odin vendor tree; used by the private audio backend |
| FFmpeg | optional system adapter | `scripts/check_ffmpeg.sh` probes `libavformat`, `libavcodec`, `libavutil` and `libswscale`; `scripts/bootstrap_ffmpeg.sh` builds the private `thor2d_video.a` shim, and it is linked only with `-define:THOR2D_FFMPEG=true` |

Run `./build.sh deps` to install/check Odin, install Thor2D's private Box2D
bridge into the pinned Odin vendor directory, and build the native Box2D
archive. The Windows archive names are selected by Odin's vendor binding but
are not validated on this Linux host yet.

Windows archive names are selected by Odin's vendor binding. Build Windows
projects with the Windows Odin toolchain and matching vendor libraries;
`build.sh deps` is intentionally a Linux bootstrap script.

The bridge source lives at `scripts/box2d_bridge.odin`. The package
`src/thor2d/internal/box2d` exposes only the private adapter surface to the
framework, keeping generated Box2D types out of game code.

Raylib remains responsible for window, input and graphics. Thor2D does not
initialize Raylib's audio device: static/stream/queue playback, buses, filters,
spatial controls, decoder and capture are owned by the private miniaudio
adapter. The public API deliberately exposes neither Raylib nor miniaudio
types. FFmpeg is deliberately optional, capability-gated at build time, and
never a hidden runtime process.
