# Capabilities

`Query_Capability(ctx, cap)` is conservative: `.Video` needs the FFmpeg build, `.Audio_Capture/Effects/Spatial/Decoder/Buses` reflect the live miniaudio backend, `.GPU_Mesh` needs a live non-headless GPU path, `.Stencil/.Instancing/.Color_Mask` are false in v0.8 (CPU fallbacks + `.Unsupported` instead of fake handles). `.System_Cursor/.Gamepad_Mapping` need a window. Headless contexts report `.Headless` only (+ archive mount).

v0.9 P1: `.Instancing` now mirrors live `GPU_Mesh` support (GPU-resident mesh VBOs; CPU fallback still reports `.Unsupported` per call). `.Stencil` and `.Color_Mask` stay false — vendor spikes found no backing API (no stencil-test/clear or color-mask in `vendor/raylib`; see `Graphics.md` "Stencil (v0.9 spike)"). New: `Is_Canvas_Format_Supported` per-format canvas query (`.RGBA8` only, false headless) and `Config.MSAA` window-creation hint (default 0).
