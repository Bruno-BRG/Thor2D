# Thor2D

> An Odin-native 2D game framework inspired by the practical spirit of
> [LÖVE](https://love2d.org/) — with private, replaceable native backends.

Thor2D is a small, explicit runtime for building desktop 2D games in
[Odin](https://odin-lang.org/). It provides a simple game loop, typed callbacks,
graphics, audio, input, Box2D physics, ECS, project files, packaging and a real
headless mode without exposing Raylib, Box2D, miniaudio or FFmpeg to game code.

The public API is Odin-native rather than a Lua compatibility layer. The goal is
to make a game easy to start, easy to test and easy to move between the normal
windowed runtime and future editor/tooling workflows.

## Highlights

- **Simple runtime:** `Load`, `Fixed_Update`, `Update`, `Draw`, `Shutdown` and
  typed event callbacks.
- **2D graphics:** primitives, textures, fonts, text layout, cameras,
  transforms, Canvas, Quad, Shader, SpriteBatch, particles, screenshots and
  GPU Meshes with a safe CPU fallback.
- **Real gameplay foundation:** generational ECS, fixed-step Box2D worlds,
  bodies, shapes, chains, sensors, contacts, joints, queries and debug bounds.
- **Dedicated audio:** miniaudio-backed static, streaming and queue sources,
  generated PCM, SoundData, decoders, buses, filters, spatial controls and
  microphone capture when the host supports it.
- **Project workflow:** normalized sandboxed filesystem paths, save precedence,
  versioned manifests, SHA-256 validation and `.thor` ZIP packages.
- **Headless execution:** run deterministic game logic and simulations without
  opening a window or requiring a GPU.
- **Optional video:** an FFmpeg adapter with incremental decode, seek, looping
  and frame-to-texture conversion when explicitly enabled.

## Quick start

### Requirements

- Odin `dev-2026-09` or newer with the bundled `vendor:raylib` package.
- Linux AMD64 is the primary development target. Windows is kept as a planned
  build target.
- A desktop OpenGL environment for graphical examples.

The pinned Odin compiler can be installed with:

```sh
./build.sh deps
```

You can use another compiler with `ODIN_BIN=/path/to/odin`.

### Run an example

```sh
./build.sh hello
./build.sh pong
./build.sh showcase
./build.sh audio-check
./build.sh smoke-v07
```

The examples import only `thor2d`:

```odin
package game

import thor2d "thor2d"

draw :: proc(ctx: ^thor2d.Context) {
    thor2d.Clear(ctx, thor2d.Black)
    thor2d.Draw_Circle(ctx, thor2d.Vec2{100, 100}, 32, thor2d.Green)
}

main :: proc() {
    thor2d.Run(thor2d.Default_Config(), thor2d.Game{Draw = draw})
}
```

## Build, test and package

The main development gates are:

```sh
./build.sh check
./build.sh test
./build.sh build
./build.sh smoke
./build.sh smoke-v07
./build.sh parity-check
```

Projects can be validated, run, packaged and executed from the package without
extracting its assets:

```sh
./build.sh project-check examples/platformer_v03
./build.sh pack examples/platformer_v03
./build.sh project-run build/platformer_v03.thor
./build.sh unpack build/platformer_v03.thor
./build.sh headless examples/headless_simulation_v05
```

Every package includes a runtime version, file sizes and SHA-256 hashes. The
runtime resolves files in this order:

```text
save directory → project directory → mounted .thor archive
```

## Optional FFmpeg video

Video is deliberately capability-gated. The default build does not link
FFmpeg, so machines without its development libraries still build and run the
framework normally.

```sh
./build.sh video-capabilities
./build.sh video-adapter
./build.sh video-build
./build.sh video-smoke
```

When available, the private adapter supports incremental demux/decode, RGBA
frames, playback state, seeking, looping and safe texture replacement. If the
dependency or adapter is not enabled, `Load_Video` returns an explicit
capability error instead of creating a fake resource.

## Architecture

```text
Game code
    ↓
thor2d public API
    ├── runtime / events / timer / filesystem / project
    ├── graphics / image / font / math
    ├── audio / sound / input / physics / ECS
    └── threads / video / data
    ↓
Private adapters
    ├── Raylib + rlgl       window, input and graphics
    ├── Box2D 3.x           physics
    ├── miniaudio           audio
    └── FFmpeg              optional video
```

Native dependencies are kept behind `src/thor2d/internal`. A game should not
import those packages directly; this keeps the public API stable and makes
backend changes possible without rewriting game code.

## Examples

| Example | Demonstrates |
| --- | --- |
| `hello` | Minimal window and drawing |
| `pong` | Input, gameplay loop and collision basics |
| `showcase_v02` | Camera, Canvas, Quad, Shader, SpriteBatch and particles |
| `platformer_v03` | ECS, Box2D, fixed-step simulation and project manifest |
| `physics_lab` | Shapes, queries, sensors and debug physics |
| `audio_lab_v07` | Generated audio, source, bus, filter and panning |
| `audio_capture_v07` | Capability-gated microphone capture |
| `video_player_v07` | Optional FFmpeg load, seek and frame metadata |
| `multimedia_showcase_v07` | Windowed graphics and dedicated audio |
| `async_assets_v07` | Headless runtime lifecycle and project execution |
| `love_port_v08` | LOVE-port proof: color state, arc/ellipse/polygon/points, window getters |
| `net_echo_v09` | Non-blocking TCP/UDP loopback demo (headless-safe) |
| `particles_v10` | Full ParticleSystem tuning showcase |
| `net_echo_v09` | Headless TCP ping/echo round-trip on 127.0.0.1 (non-blocking net demo) |

## Compatibility status

Thor2D targets practical desktop parity with the main concepts of LÖVE's
`graphics`, `audio`, `sound`, `event`, `filesystem`, `data`, `physics`,
`thread`, `window`, `system`, `math` and optional `video` modules. It does not
copy Lua signatures and it does not promise identical behavior across every
platform or GPU.

The detailed implementation matrix, capability rules and known boundaries are
maintained in [docs/love2d-parity.md](docs/love2d-parity.md). The browsable
LOVE-style reference (module pages, porting table, full API index) lives in
[docs/wiki/Main_Page.md](docs/wiki/Main_Page.md). Dependency and
build details are in [docs/dependencies.md](docs/dependencies.md).

## Current boundaries

The v0.8 focus is LOVE-parity depth (graphics state, window/filesystem/input
getters, meter, audio/math/data getters) plus the wiki. Some capabilities
remain intentionally explicit:

- Stencil, color-mask, depth, cull, wireframe and GPU instancing have no
  dedicated backend path yet: setters store state and return
  `Error.Unsupported` instead of fake behavior.
- `Pulley`, `Rope`, `Friction` and `Gear` joints return `Error.Unsupported`:
  Box2D 3.x removed them upstream.
- Gamepad remapping returns `Error.Unsupported` (no mapping database).
- FFmpeg video audio-track mixing is not included yet.
- `Image_Data` currently uses RGBA8.
- Non-triangle Mesh modes use the tested CPU fallback.
- Background asset loading is not allowed to access `Context`, Raylib or the
  GPU from worker threads.
- Editor tooling, networking, mobile export and advanced DSP remain future
  work.

These limitations are reported through capability checks, `Error.Unsupported`
or `Error.Capability_Unavailable` where appropriate.

## License

Thor2D is currently an experimental project. A project license will be added
before the first stable release.
