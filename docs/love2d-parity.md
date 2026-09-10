# Thor2D / Love2D parity

Thor2D follows Love2D's module boundaries while exposing Odin-native types and
procedures. It is not Lua-compatible and never exposes Raylib or Box2D to game
code.

The browsable reference is [wiki/Main_Page.md](wiki/Main_Page.md) (LOVE-style
module pages), with [wiki/guides/Porting_From_LOVE.md](wiki/guides/Porting_From_LOVE.md)
as the side-by-side port table and
[wiki/Api_Reference.md](wiki/Api_Reference.md) as the full procedure index.
`scripts/gen_wiki.py --check` (run by `parity-check`) fails when a public proc
is missing from the wiki.

| Love2D area | Thor2D v0.8 status | Current coverage |
| --- | --- | --- |
| `love.load`, `love.update`, `love.draw` | Implemented | `Game` callbacks, fixed-step lifecycle, shutdown and headless execution |
| `love.event` | Implemented | Typed FIFO queue, callback, polling, wait, keyboard/text, mouse, window, gamepad, joystick, touch and file-drop events |
| `love.graphics` | Implemented full 2D (v0.10) | Primitives plus v0.8 color/background/font state, dimensions, pixel helpers, default filter, line join/style, persistent blend mode, tracked scissor, Print/Printf, Arc/Ellipse/Polygon/Points, textured transform draw, CPU instanced fallback; stencil/color-mask/depth/cull/wireframe return `.Unsupported` explicitly; v0.10 adds full ParticleSystem tuning, font metrics, Text append, quad/batch/canvas/shader completion, mesh accessors, CPU texture arrays, state getters, canvas readback |
| `love.image` | Implemented RGBA8 subset | CPU `Image_Data`, pixel access, texture creation, PNG export, plus v0.9 `Paste_Image`, `Map_Pixel`, in-memory `Encode_Image_PNG`, compressed sniffing + load where the GPU accepts it |
| `love.font` | Implemented core + global | File/memory fonts, measurement, drawing, reusable text objects, `Set_Font/Get_Font`, plus v0.9 `Image_Font` (LOVE image fonts, arbitrary glyph order) |
| `love.audio`, `love.sound` | Implemented dedicated desktop subset | Private miniaudio engine, enumerated/selectable playback devices, static/stream/queue sources, generated PCM, incremental decoder, SoundData clone/resampling/channel conversion, seek/tell/loop, volume/pitch/pan, spatial position/velocity/direction/cone/distance/doppler, listener, buses, volume/delay/filter/room-delay effects and microphone capture ring buffer, plus v0.8 master/position/velocity/distance-model getters, plus v0.9 LOVE effect-name query (echo/reverb wired, 6 others unsupported) |
| `love.keyboard`, `love.mouse` | Implemented + extras | Polling, repeat query, callbacks, wheel, delta, clipboard, cursor grab, relative-mode request, plus v0.8 key-repeat/text-input state, scancode helpers, mouse position setter, grab/relative/visibility getters, system cursors, plus v0.9 image cursors (draw-it-yourself) |
| `love.joystick`, `love.touch` | Implemented core | Gamepad availability/name/axes/buttons, device events, touch lifecycle, plus v0.8 joystick count, touch id list/pressure, plus v0.9 index list, synthetic GUIDs, axis/button counts, vibration; hats and remapping return `.Unsupported` |
| `love.math` | Implemented practical subset | Vectors, forward/inverse transforms, camera conversions, deterministic independent RNGs, noise, interpolation, color-space helpers, Bezier curves, convexity, ear-clipping triangulation, plus v0.8 seed/state access and `Random_Normal`, plus v0.9 full `Transform` object API (clone/apply/inverse/combine/set-transformation, degrees) |
| `love.physics` | Implemented core Box2D 3.x | Fixed-step worlds, static/kinematic/dynamic bodies, box/circle/segment/capsule/polygon/chain shapes, filters, sensors, contact impulses, seven supported joint kinds, AABB overlap, detailed raycast, circle shape cast, tags, forces/torques and public bounds debug draw, plus v0.8 meter scale and AABB distance, plus v0.9 runtime shape friction/restitution/density/sensor access; pulley/rope/friction/gear return `.Unsupported` (removed in Box2D 3.x) |
| `love.filesystem` | Implemented package model + writes | Source/save sandbox, normalized relative paths, save precedence, read/write/info, directory listing, identity, ZIP mount, in-place archive reads, seekable physical `File` handles, plus v0.8 create/remove/append/size/type queries, working/user/appdata dirs, fused check, line reader |
| `love.data` | Implemented foundation | Owned buffers, non-owning `Data_View`, copy/slice, deterministic primitive pack/unpack plus v0.8 `Get_Packed_Size`, Base64, hex, MD5/SHA family, JSON, CBOR, LZ4, ZLIB, GZIP and raw DEFLATE |
| `love.timer` | Implemented foundation | Delta, elapsed time, target FPS, average frame time and fixed-step backlog |
| `love.window` | Implemented desktop core | Size/title/fullscreen toggle, resize/focus/visibility, position, DPI, desktop mode query, minimized state, cursor visibility, mouse grab, plus v0.8 title/open/visible/focus/maximized getters, mode query, display enumeration, safe area, icon, explicit message-box/vsync gaps, plus v0.9 `Update_Window_Mode` |
| `love.system` | Implemented foundation | OS label, processor count, process arguments, locale, clipboard, URL opening, power-info stub, version/compat queries, mobile-future `Vibrate`, capability errors |
| `love.thread` | Implemented managed core | Odin workers, cooperative cancellation, state/error reporting, typed channels, timeout polling and Context-owned joins; workers cannot access Context/GPU/Raylib |
| `love.video` | Optional FFmpeg adapter (video-only) | Incremental FFmpeg demux/decode, RGBA frame conversion, play/pause/seek/loop, duration/position/frame metadata and safe texture replacement; builds without FFmpeg return `Capability_Unavailable` |

## v0.8 guarantees

The public API keeps the v0.2--v0.7 contracts except for the approved v0.8
additions (new types/procs only; `Begin_Blend/End_Blend` and
`Begin_Scissor/End_Scissor` stay as compat wrappers — prefer
`Set_Blend_Mode`/`Set_Scissor`). Examples import only
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

The v0.8 adapter intentionally keeps a few boundaries explicit: Mesh modes
other than indexed triangles use the tested CPU fallback, `Image_Data` is
currently RGBA8-only, FFmpeg video does not yet mix its own audio track,
stencil/color-mask/depth/cull/wireframe and GPU instancing return
`.Unsupported` (CPU fallbacks where drawable), pulley/rope/friction/gear
joints return `.Unsupported` (removed in Box2D 3.x), gamepad remapping returns
`.Unsupported`, and background asset loading remains a future worker service
rather than exposing a thread-unsafe `Context` to workers. Those areas have
public errors or fallback paths instead of silently partial resources.

The future editor remains a separate executable consuming `Project`, `Scene` and
stable `Asset_Id` values. It is not a runtime dependency.

| `enet` / `socket` (third-party in LOVE) | New v0.9 Thor2D net module | Non-blocking TCP+UDP surface (`TCP_Listen/Accept/Connect/Send/Receive`, `UDP_Open/Send_To/Receive_From`, `Net_Resolve`, `.Not_Ready` polling), loopback-tested, never blocks `Update` |
| editor tooling | v0.9 CLI scaffold | `tools/editor_v09` inspects/validates `project.json` (id, assets, scenes, entities); full editing remains future work |
