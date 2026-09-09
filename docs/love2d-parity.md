# Thor2D / Love2D parity

Thor2D follows Love2D's module boundaries while exposing Odin-native types and
procedures. It is not Lua-compatible and never exposes Raylib or Box2D to game
code.

| Love2D area | Thor2D v0.7 status | Current coverage |
| --- | --- | --- |
| `love.load`, `love.update`, `love.draw` | Implemented | `Game` callbacks, fixed-step lifecycle, shutdown and headless execution |
| `love.event` | Implemented | Typed FIFO queue, callback, polling, wait, keyboard/text, mouse, window, gamepad, joystick, touch and file-drop events |
| `love.graphics` | Implemented practical 2D | Primitives, textures, Canvas, Quad, Shader, reusable Text, text layout, SpriteBatch, particles, camera, inverse transforms, screenshot/ImageData, scissor, blend, texture filter/wrap, line width, point size, shader float arrays/matrices and GPU Mesh with UV/color/normal attributes |
| `love.image` | Implemented RGBA8 subset | CPU `Image_Data`, pixel access, texture creation and PNG export |
| `love.font` | Implemented core | File/memory fonts, measurement, drawing and reusable text objects |
| `love.audio`, `love.sound` | Implemented dedicated desktop subset | Private miniaudio engine, enumerated/selectable playback devices, static/stream/queue sources, generated PCM, incremental decoder, SoundData clone/resampling/channel conversion, seek/tell/loop, volume/pitch/pan, spatial position/velocity/direction/cone/distance/doppler, listener, buses, volume/delay/filter/room-delay effects and microphone capture ring buffer |
| `love.keyboard`, `love.mouse` | Implemented core | Polling, repeat query, callbacks, wheel, delta, clipboard, cursor grab and relative-mode request |
| `love.joystick`, `love.touch` | Implemented core | Gamepad availability/name/axes/buttons, device events and touch lifecycle |
| `love.math` | Implemented practical subset | Vectors, forward/inverse transforms, camera conversions, deterministic independent RNGs, noise, interpolation, color-space helpers, Bezier curves, convexity and ear-clipping triangulation |
| `love.physics` | Implemented core Box2D | Fixed-step worlds, static/kinematic/dynamic bodies, box/circle/segment/capsule/polygon/chain shapes, filters, sensors, contact impulses, seven supported joint kinds, AABB overlap, detailed raycast, circle shape cast, tags, forces/torques and public bounds debug draw; pulley/rope joints are not adapted |
| `love.filesystem` | Implemented core package model | Source/save sandbox, normalized relative paths, save precedence, read/write/info, directory listing, identity, ZIP mount, in-place archive reads and seekable physical `File` handles |
| `love.data` | Implemented foundation | Owned buffers, non-owning `Data_View`, copy/slice, deterministic primitive pack/unpack, Base64, hex, MD5/SHA family, JSON, CBOR, LZ4, ZLIB, GZIP and raw DEFLATE |
| `love.timer` | Implemented foundation | Delta, elapsed time, target FPS, average frame time and fixed-step backlog |
| `love.window` | Implemented desktop core | Size/title/fullscreen toggle, resize/focus/visibility, position, DPI, desktop mode query, minimized state, cursor visibility and mouse grab |
| `love.system` | Implemented foundation | OS label, processor count, process arguments, locale, clipboard, URL opening and capability errors |
| `love.thread` | Implemented managed core | Odin workers, cooperative cancellation, state/error reporting, typed channels, timeout polling and Context-owned joins; workers cannot access Context/GPU/Raylib |
| `love.video` | Optional FFmpeg adapter | Incremental FFmpeg demux/decode, RGBA frame conversion, play/pause/seek/loop, duration/position/frame metadata and safe texture replacement; builds without FFmpeg return `Capability_Unavailable` |

## v0.7 guarantees

The public API keeps the v0.2--v0.6 contracts. Examples import only
`thor2d`; Raylib remains in `src/thor2d/internal/raylib`, Box2D remains behind
the private adapter, and a registered worker is joined during `Destroy`.

The project runner validates the `.thor` manifest, schema, file sizes and
SHA-256 entries before starting. It extracts only the executable to a temporary
location, mounts the original archive as a read-only source, and applies the
lookup order save directory → project directory → archive. Asset APIs read
through that same order, so a packaged game does not need to unpack its assets.

`Query_Capability` is deliberately conservative. GPU Mesh is reported only by
a live non-headless backend that exposes the required GPU path. Video is
capability-gated by the build: the default binary does not link FFmpeg, while
the private adapter is enabled with `-define:THOR2D_FFMPEG=true`. Audio
capability checks reflect the actual miniaudio device and supported effect
nodes; capture is false when the host has no input device. Playback device
selection is refused while sources, buses, effects, decoders or capture are
active so handles are never invalidated silently.

## Known boundary

This matrix marks a capability as implemented only when the corresponding
public implementation and unit coverage exist. A graphical or hardware feature
that is not portable is returned as `Error.Unsupported` or
`Error.Capability_Unavailable`; Thor2D never returns a fake resource handle.

The v0.7 adapter intentionally keeps a few boundaries explicit: Mesh modes
other than indexed triangles use the tested CPU fallback, `Image_Data` is
currently RGBA8-only, FFmpeg video does not yet mix its own audio track, and
background asset loading remains a future worker service rather than exposing
a thread-unsafe `Context` to workers. Those areas have public errors or
fallback paths instead of silently partial resources.

The future editor remains a separate executable consuming `Project`, `Scene` and
stable `Asset_Id` values. It is not a runtime dependency.
