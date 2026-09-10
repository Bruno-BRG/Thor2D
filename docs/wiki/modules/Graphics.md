# thor2d.Graphics

LOVE equivalent: `love.graphics`. Sources: `graphics.odin`, `graphics_state.odin`, `transforms.odin`, `effects.odin`.

## Description

Immediate-mode 2D drawing over the private raylib backend. State (`Set_Color`,
background, font, blend, scissor) lives on `Context` so headless runs stay
deterministic. `Color` channels are `u8` (0–255), unlike LOVE 0–1 floats.

## Types

`Texture`, `Canvas`, `Quad`, `Shader`, `Sprite_Batch`, `Particle_System`,
`Mesh`, `Mesh_Vertex`, `Mesh_Draw_Mode`, `Texture_Array`, `Blend_Mode`,
`Texture_Filter`, `Texture_Wrap`, `Text_Align`, `Text_Layout`, `Font`, `Text`,
`Image_Data`, `Draw_Mode`, `Arc_Type`, `Line_Join`, `Line_Style`,
`Color_Mask`, `Cull_Mode`, `Winding`, `Graphics_Stats`, `System_Limits`,
`Renderer_Info`.

## Functions

### State

- `Set_Color(ctx, color)` / `Get_Color(ctx)` — LOVE `setColor/getColor`.
- `Set_Background_Color(ctx, color)` / `Get_Background_Color(ctx)` — LOVE `setBackgroundColor/getBackgroundColor`.
- `Clear(ctx, color)` — explicit clear; `Clear_Screen(ctx)` — clear to background (LOVE no-arg `clear`).
- `Set_Font(ctx, font)` / `Get_Font(ctx)` / `Reset_Graphics_State(ctx)` — LOVE `setFont/getFont`.
- `Get_Dimensions(ctx)` / `Get_Width(ctx)` / `Get_Height(ctx)` — LOVE `getDimensions/getWidth/getHeight`.
- `From_Pixels(ctx, v)` / `To_Pixels(ctx, v)` — LOVE `fromPixels/toPixels` (DPI scale; identity at 1x).
- `Set_Default_Filter(ctx, min, mag)` / `Get_Default_Filter(ctx)` — LOVE `setDefaultFilter`.
- `Set_Line_Join(ctx, j)` / `Get_Line_Join(ctx)`, `Set_Line_Style(ctx, s)` / `Get_Line_Style(ctx)` — LOVE line join/style (stored; backend draws smooth lines).
- `Set_Line_Width/Get_Line_Width(ctx, width)` and `Set_Point_Size/Get_Point_Size(ctx, size)` — persistent line/point sizes; defaults are 1 and 2, and values are retained in headless mode.
- `Set_Blend_Mode(ctx, mode)` / `Get_Blend_Mode(ctx)` / `Reset_Blend_Mode(ctx)` — LOVE `setBlendMode/getBlendMode`. Legacy `Begin_Blend/End_Blend` remain as scoped compat wrappers.
- `Set_Scissor(ctx, rect)` / `Get_Scissor(ctx)` / `Intersect_Scissor(ctx, rect)` / `Reset_Scissor(ctx)` — LOVE `setScissor/getScissor/intersectScissor`. Legacy `Begin_Scissor/End_Scissor` bypass tracking; prefer `Set_Scissor`.
- `Set_Color_Mask(ctx, mask)` → `.Unsupported` (stored + returned by `Get_Color_Mask`); LOVE `setColorMask`.
- `Set_Stencil_Test(ctx, enabled)` / `Clear_Stencil(ctx)` → `.Unsupported`; LOVE stencil.
- `Set_Depth_Mode`, `Set_Cull_Mode` / `Get_Cull_Mode`, `Set_Wireframe` / `Is_Wireframe` — 2D desktop; non-default modes return `.Unsupported`.
- `Get_Graphics_Stats(ctx)` / `Get_System_Limits(ctx)` / `Is_Graphics_Supported(ctx, feature)` — LOVE `getStats/getSystemLimits/getSupported`. Raylib reports per-frame draw-call count, live canvas/mesh counts, and estimated RGBA8 texture memory; headless returns zero metrics.
- `Flush_Batch(ctx)`, `Present_Screen(ctx)` — no-ops for port compatibility (backend draws immediately; `End_Frame` presents).
- `Replace_Transform(ctx, t)`, `Transform_Point_Graphics`, `Inverse_Transform_Point` — LOVE `replaceTransform/transformPoint/inverseTransformPoint`; affine matrices, including shear, are applied exactly. `Push_Transform/Pop_Transform/Translate/Rotate/Scale/Reset_Transform` update both the public state and backend; all stack operations are also safe in headless mode.

### Drawing

- `Draw_Rect(ctx, rect, color)` / `Draw_Rect_Outline` — LOVE `rectangle`.
- `Draw_Circle(ctx, center, radius, color)` — LOVE `circle` (filled).
- `Draw_Line(ctx, a, b, thickness, color)` — LOVE `line`.
- `Draw_Arc(ctx, center, radius, a1, a2, mode, type, segments, color)` — LOVE `arc` (CPU-tessellated, ≤128 segments; fill emits solid triangles, while the type controls the outline).
- `Draw_Ellipse(ctx, center, rx, ry, mode, segments, color)` — LOVE `ellipse` (fill emits a solid triangle fan; line emits the tessellated outline).
- `Draw_Polygon(ctx, points, mode, color)` — LOVE `polygon` (fill uses the ear-clip `Triangulate_Polygon` result as solid backend triangles).
- `Draw_Points(ctx, points, color)` — LOVE `points`.
- `Draw_Text(ctx, text, pos, size, color)`, `Print(ctx, text, pos, color)`, `Printf(ctx, text, rect, align, color)` — LOVE `print/printf`.
- `Load_Texture(ctx, path)` / `Generate_Texture` / `Draw_Texture(ctx, ...)` / `Draw_Texture_Ex/Pro/Quad/Transform` — LOVE `newImage/draw`.
- `Create_Canvas/Set_Canvas/Reset_Canvas/Draw_Canvas` — LOVE `newCanvas/setCanvas`.
- `New_Quad/New_Quad_From_Texture/Draw_Texture_Quad` — LOVE `newQuad`.
- `Load_Shader/Begin_Shader/End_Shader/Set_Shader_*` — LOVE `newShader/setShader/Shader:send`.
- `Create_Mesh/Update_Mesh/Draw_Mesh/Draw_Mesh_Textured/Draw_Mesh_Instanced` — LOVE `newMesh` (+ `drawInstanced` CPU fallback; `.Instancing` capability is false).
- `Create_Sprite_Batch/Add/Draw/Clear/Unload` — LOVE `newSpriteBatch`.
- `Create_Particles/Emit/Update/Draw/Clear/Unload` — LOVE `newParticleSystem`.
- `Set_Particle_Emission_Rate` / `Get_Particle_Emission_Rate` — LOVE `setEmissionRate/getEmissionRate` (particles/second; clamped ≥ 0).
- `Set_Particle_Emitter_Lifetime` / `Get_Particle_Emitter_Lifetime` — LOVE `setEmitterLifetime/getEmitterLifetime`, except **0 means infinite** (LOVE uses -1; Thor2D uses 0 so the zero value is the common case). When a finite budget expires the system auto-stops; live particles keep simulating.
- `Set_Particle_Lifetime` / `Get_Particle_Lifetime` — LOVE `setParticleLifetime/getParticleLifetime` (min/max seconds).
- `Set_Particle_Direction` / `Get_Particle_Direction`, `Set_Particle_Spread` / `Get_Particle_Spread` — LOVE `setDirection/getDirection`, `setSpread/getSpread` (**radians**; emission angle uniform in `[direction - spread/2, direction + spread/2]`; default spread is full-circle).
- `Set_Particle_Speed` / `Get_Particle_Speed` — LOVE `setSpeed/getSpeed` (min/max px/s; default 20–100).
- `Set_Particle_Linear_Acceleration` / `Get_Particle_Linear_Acceleration` — LOVE `setLinearAcceleration/getLinearAcceleration` (min/max `Vec2`).
- `Set_Particle_Radial_Acceleration` / `Get_Particle_Radial_Acceleration` — LOVE `setRadialAcceleration/getRadialAcceleration` (away from the emitter at the local origin).
- `Set_Particle_Tangential_Acceleration` / `Get_Particle_Tangential_Acceleration` — LOVE `setTangentialAcceleration/getTangentialAcceleration` (perpendicular).
- `Set_Particle_Damping` / `Get_Particle_Damping` — LOVE `setLinearDamping/getLinearDamping` (constant deceleration opposing motion, clamped so velocity never flips sign).
- `Set_Particle_Gravity` / `Get_Particle_Gravity` — gravity vector (also settable at creation via `Particle_Config.Gravity`).
- `Set_Particle_Spin` / `Get_Particle_Spin` — LOVE `setSpin/getSpin` (**radians/second**).
- `Set_Particle_Sizes` / `Get_Particle_Size_Count` — LOVE `setSizes/getSizes` (max 8 stops, absolute pixels; interpolated evenly over lifetime; empty input is a no-op).
- `Set_Particle_Colors` / `Get_Particle_Color_Count` — LOVE `setColors/getColors` (max 8 stops, `u8` 0–255 channels; empty input is a no-op).
- `Set_Particle_Size` / `Get_Particle_Size`, `Set_Particle_Color` / `Get_Particle_Color` — single-value convenience: read/write the track *start* value, preserving the remaining stops.
- `Replace_Particle_Texture(ctx, ps, tex)` → `Error` — LOVE `setTexture`. `Texture{}` selects the textureless circle renderer. A non-zero texture must exist in the active backend (headless + real texture reports `.Invalid_Handle`, never a fake).
- `Start_Particles` / `Stop_Particles` / `Pause_Particles` / `Reset_Particles` — LOVE `start/stop/pause/reset`. **New systems start active** (Thor2D CType behavior: `Update` emits at the configured rate with no explicit start; call `Stop_Particles` after `Create` for LOVE's initially-stopped flow). `Stop` halts emission and resets the emitter budget (live particles decay); `Pause` freezes everything; `Reset` clears all particles back to stopped.
- `Is_Particles_Active` / `Is_Particles_Paused` / `Is_Particles_Stopped` / `Is_Particles_Empty` — LOVE `isActive/isPaused/isStopped` (+ empty query). Active means emitting-or-would-emit (`active && !paused`).
- `Get_Particle_Count` / `Get_Particle_Max` — LOVE `getCount/getBufferSize` (max is fixed at creation; there is no `setBufferSize`).
- `Clone_Particles(ctx, ps)` → `(Particle_System, Error)` — LOVE `clone`: inherits all tuning, tracks, texture and the RNG seed, but starts **stopped with zero live particles**; live particles are not copied. Invalid handles report `.Invalid_Handle`.
- Setters on invalid handles are silent no-ops; getters return zero values. Only `Clone_Particles` / `Replace_Particle_Texture` are fallible.
- The sim is pure CPU and headless-safe: headless systems simulate in a windowless backend state (draw stays a no-op; textures need a GPU backend). Headless systems must be `Unload_Particles`-ed explicitly. Particle arrays are reserved to `Max_Particles` at creation, so emission never allocates per frame. Per-particle accel/damping/spin coefficients are drawn at emit (uniform in min..max) from the system LCG seed (`0x9E3779B9` at creation), so identical config + update sequences evolve identically.
- Explicitly OUT (no quad array, no per-particle insert/remove, no serialization, no emission-area spawns, no rotation range): quads/insert/remove/serialize are omitted by design; spawn position is the emitter origin passed to `Draw_Particles`.
- `Create_Text/Set_Text/Draw_Text_Object/Unload_Text` — LOVE `newText`.
- `Take_Screenshot/Capture_Screenshot`, `Set_Line_Width/Set_Point_Size`, `Get_Renderer_Info` — LOVE `captureScreenshot`.

## Enums

`Draw_Mode` (Fill/Line), `Arc_Type` (Pie/Open/Closed), `Line_Join`, `Line_Style`, `Cull_Mode`, `Winding`.

## Examples

```odin
thor2d.Set_Color(ctx, thor2d.Red)
thor2d.Draw_Arc(ctx, thor2d.Vec2{400, 300}, 100, 0, 3.14159, .Fill)
thor2d.Draw_Polygon(ctx, []thor2d.Vec2{{0, 0}, {64, 0}, {32, 48}}, .Line)
thor2d.Print(ctx, "hello", thor2d.Vec2{10, 10})
```

## See Also

[Window](Window.md), [Font](Font.md), [Image](Image.md), [Math](Math.md).

## v0.9 P1 GPU-side gaps (supersedes the v0.8 bullets above)

- `Draw_Mesh_Instanced` — GPU path live: when the mesh owns resident GPU
  vertex buffers, all `count` copies are issued from the VBOs
  (`backend.Draw_Mesh_Instanced`) and the proc returns `.None`. Meshes
  without GPU buffers (GL 1.1, fan/strip/points modes) and headless contexts
  keep the CPU fallback loop with `.Unsupported`. `.Instancing` capability
  now mirrors `GPU_Mesh_Supported`. Rejected alternatives: single-call
  `rlgl.DrawVertexArrayElementsInstanced` (pixel-identical for this
  single-shared-transform API, plus ES 2.0 entry-point risk) and
  `rl.DrawMeshInstanced` (needs an `rl.Mesh`/`Material` conversion that
  duplicates the VBOs). A future per-instance-transform overload can adopt
  divisor attributes (`rlgl.SetVertexAttributeDivisor` exists).
- `Set_Color_Mask` — still `.Unsupported` (stored + `Get_Color_Mask`).
  Spike evidence: `rg -i "colormask|color_mask"` over `vendor/raylib`
  returns zero hits; raw OpenGL imports would bypass render-batch state
  tracking, so no path was added. `.Color_Mask` capability stays false.
- `Create_Canvas_Format(ctx, w, h, format, msaa)` — LOVE `newCanvas` with
  format. `Canvas_Format` (`RGBA8`, `RGBA16F`, `RGBA32F`, `Depth_Stencil`);
  only `.RGBA8` + `msaa == 0` creates a real canvas (raylib
  `LoadRenderTexture` is RGBA8 + depth). Anything else returns
  `.Unsupported`, never a fake. `Is_Canvas_Format_Supported(ctx, format)` is
  the per-format query (false for every format when headless).
- `Config.MSAA` (default 0) — any positive value requests 4x MSAA via
  `MSAA_4X_HINT` at window creation (raylib exposes only a 4x hint). Set
  before `Create`/`Run`; per-canvas MSAA does not exist, so
  `Create_Canvas_Format` with `msaa != 0` returns `.Unsupported`.

### Stencil (v0.9 spike)

Negative result, kept honest: `Set_Stencil_Test` / `Clear_Stencil` still
return `.Unsupported` and `.Stencil` stays false. Evidence: `rg -i stencil`
over `vendor/raylib` returns exactly one hit —
`rlgl.FramebufferAttachType.STENCIL`, an FBO attachment tag. The bindings
expose no stencil-test control (no enable/func/op/mask), no stencil clear,
and `LoadRenderTexture` builds its FBO with a depth renderbuffer only, so
there is no stencil buffer on the default framebuffer or canvases. A custom
stencil FBO (`LoadFramebuffer` + `FramebufferAttach`) would still leave no
test/clear API, so no path was added. Prefer this correct negative over a
hacky fake; revisit if raylib exposes stencil ops.

## v0.10 text/canvas/shader completion

LOVE sources: `love-api` `modules/graphics/types/{Font,Text,Quad,SpriteBatch,Canvas,Shader}.lua`.
Font metrics also live on [Font](Font.md). Colored-text runs, formatted
`addf/setf` with wrap limits, glyph transforms, array-texture layers,
`attachAttribute`, mipmaps and canvas slices stay out of scope.

- `Text_Add(ctx, text, value)` / `Text_Addf(ctx, text, format, args)` — LOVE
  `Text:add` (plain-text append; `Addf` formats via `core:fmt`, the Odin
  answer to Lua `string.format`). Appending `""` is a successful no-op.
- `Text_Clear(ctx, text)` — LOVE `Text:clear`. There was no prior clear path
  (`Set_Text` rejects empty input), so this has a dedicated backend entry.
- `Text_Font(ctx, text)` / `Text_Set_Font(ctx, text, font)` — LOVE
  `Text:getFont/setFont` (`Font{}` selects the default font; see
  [Font](Font.md)).
- `Quad_Viewport(quad)` / `Quad_Set_Viewport(quad, viewport, tex_w, tex_h)` /
  `Quad_Texture_Size(quad)` — LOVE `Quad:getViewport/setViewport/
  getTextureDimensions`. Quads are values (see `New_Quad`), so the setter
  returns the updated `Quad`; non-positive reference sizes keep the stored
  dims (LOVE's optional `sw/sh`). Pure CPU, no `ctx`.
- `Sprite_Batch_Set(ctx, batch, index, ...)` (mirrors `Add_Sprite` args) /
  `Sprite_Batch_Set_Color(ctx, batch, index, color)` (per-sprite recolor) /
  `Sprite_Batch_Count(ctx, batch)` — LOVE `SpriteBatch:set/setColor/
  getCount`. Indices are **0-based** in add order (LOVE ids are 1-based:
  subtract 1 when porting). Out-of-range sets report an error, never a
  silent no-op.
- `Sprite_Batch_Set_Draw_Range(ctx, batch, start, count)` /
  `Sprite_Batch_Draw_Range(ctx, batch)` — LOVE `SpriteBatch:setDrawRange`
  (0-based; `count < 0` draws to the end; reset with `(0, -1)`).
- `Canvas_Render_To(ctx, canvas, draw)` — LOVE `Canvas:renderTo`: targets the
  canvas, invokes `draw(ctx)`, resets. Nil-safe (`nil` ctx/proc is a no-op);
  an invalid canvas still invokes `draw` on the current target (matching
  `Set_Canvas`); headless set/reset steps are no-ops while `draw` runs.
- `Canvas_To_Image(ctx, canvas)` — LOVE `Canvas:newImageData` (full-canvas
  capture only). Real readback via `LoadImageFromTexture`, rows flipped to
  match `Draw_Canvas` orientation. Headless reports
  `.Capability_Unavailable` (like `Capture_Screenshot`); unknown handles
  report `.Invalid_Handle`. Caller frees with `Destroy_Image_Data`.
- `Canvas_MSAA(ctx, canvas)` — LOVE `Canvas:getMSAA`: the stored sample
  count, always `0` (no per-canvas MSAA in raylib; window-level MSAA comes
  from `Config.MSAA`).
- `Shader_Has_Uniform(ctx, shader, name)` — LOVE `Shader:hasUniform`, via
  `GetShaderLocation` (driver optimized-out uniforms report `false`, as in
  LOVE). `false` on bad handles/empty names.
- `Shader_Warnings(ctx, shader)` — LOVE `Shader:getWarnings`. Documented
  stub: raylib exposes no compile-log query and the backend retains no log,
  so this always returns `""` (a non-empty string would be a fake).

```odin
thor2d.Canvas_Render_To(ctx, canvas, proc(ctx: ^thor2d.Context) {
    thor2d.Clear(ctx, thor2d.Black)
    thor2d.Draw_Rect(ctx, thor2d.Rect{W = 64, H = 64}, thor2d.Red)
})
image, err := thor2d.Canvas_To_Image(ctx, canvas)
if err == .None {
    defer thor2d.Destroy_Image_Data(&image)
}
thor2d.Sprite_Batch_Set_Draw_Range(ctx, batch, 0, 2)
```

## v0.10 wave 5 mesh accessors + texture introspection + niche GPU

LOVE sources: `love-api` `modules/graphics/types/{Mesh,Texture}.lua` and the
graphics module (`getCanvas/getShader/isGammaCorrect/validateShader/
discard`). Mesh indices are **0-based** (LOVE ids are 1-based: subtract 1
when porting).

- `Mesh_Vertex_At(ctx, mesh, index)` / `Mesh_Vertex_Count(ctx, mesh)` /
  `Mesh_Set_Vertex(ctx, mesh, index, v)` — LOVE `Mesh:getVertex/
  getVertexCount/setVertex` (single-vertex subset). `Set` patches the CPU
  copy and re-uploads the GPU buffers, so both stay in sync. Out-of-range
  indices report `.Invalid_Data`; unknown meshes `.Invalid_Handle`.
- `Mesh_Draw_Mode_Of(ctx, mesh)` / `Mesh_Set_Draw_Mode(ctx, mesh, mode)` —
  LOVE `Mesh:getDrawMode/setDrawMode`. The setter rebuilds the GPU object;
  non-triangle modes draw via the CPU fallback (same rule `Create_Mesh`
  applies).
- `Mesh_Texture_Of(ctx, mesh)` / `Set_Mesh_Texture(ctx, mesh, tex)` — LOVE
  `Mesh:getTexture/setTexture` (`Texture{}` clears). `Draw_Mesh` shades from
  the bound texture on the GPU path; the CPU path stays flat-shaded (no UV
  rasterizer — the pre-existing `Draw_Mesh_Textured` limit). A stale binding
  (texture unloaded after binding) draws untextured.
- `Mesh_Set_Draw_Range(ctx, mesh, start, count)` /
  `Mesh_Draw_Range(ctx, mesh)` — LOVE `Mesh:setDrawRange/getDrawRange`
  (`count < 0` draws to the end; reset with `(0, -1)`; `(0, 0)` signals a bad
  handle). The subset slices the index list on the CPU path; on the GPU path
  the slice is drawn from a temporary element buffer (no driver offset
  semantics relied on; full draws keep the zero-upload path).
- `Texture_Is_Readable(ctx, tex)` — LOVE `Texture:isReadable`: always true
  for live textures (LOVE's unreadable depth/stencil canvases cannot be
  created — `Create_Canvas_Format` rejects non-RGBA8).
- `Texture_Mipmap_Count(ctx, tex)` — LOVE `Texture:getMipmapCount`: the real
  stored GL count — `1` for every live texture (the backend never generates
  mipmaps), `0` on bad handles.
- `Texture_Pixel_Size(ctx, tex)` — LOVE `Texture:getPixelDimensions`: equals
  `Texture_Size` (desktop DPI scale is 1, so density units are pixels).
- `Load_Texture_Array(ctx, paths)` / `Unload_Texture_Array(ctx, &arr)` /
  `Texture_Array_Layer_Count(arr)` / `Texture_Array_Layer(arr, layer)` /
  `Draw_Texture_Array_Layer(ctx, arr, layer, pos, tint)` — LOVE
  `newArrayImage` subset. Honest emulation, not a GPU array: raylib exposes
  no 2D array/volume texture API (`LoadTextureCubemap` is a 3D skybox
  samplerCube path with no 2D layer draw), so `Texture_Array` is an owned
  list of 2D layers drawn one at a time. Single owner: load once, unload
  once. `attachAttribute`, custom vertex formats, `setVertices` and the
  vertex map stay out of scope (one fixed backend format; indices are the
  map).
- `Discard_Canvas(ctx, canvas)` — LOVE `Canvas:discard`. Real no-op: the
  backend draws immediately with no deferred tile memory, so the handle is
  validated and `.None` returned.
- `Validate_Shader(ctx, shader)` — LOVE `graphics.validateShader`: `(true,
  "")` for live programs (the backend compiles at load, so registry
  presence means a live GPU program), `(false, reason)` otherwise.
- `Is_Gamma_Correct(ctx)` — LOVE `graphics.isGammaCorrect`: always `false`
  (no sRGB framebuffer pipeline; colors pass through unmodified; use
  `SRGB_To_Linear` / `Linear_To_SRGB` in `random.odin` for manual conversion).
- `Get_Active_Canvas(ctx)` / `Get_Active_Shader(ctx)` — LOVE
  `graphics.getCanvas/getShader` (`(…, false)` when rendering to
  screen / no shader active).
- `Get_Transform_Stack_Depth(ctx)` — the `Push/Pop_Transform` nesting depth
  (`0` headless, where pushes are no-ops).

Explicitly NOT done (no real mechanism; kept honest): array/cube/volume GPU
textures (no vendor API — emulated above), `Begin_Stencil_Mask` (an
alpha-blend "mask" cannot reproduce per-fragment test-fail discard
semantics pixel-correctly, so stencil stays `.Unsupported`), mipmap
generation/filter queries (no `GenTextureMipmaps` call, no per-texture
filter memory — both setters stay setter-only).

```odin
v, err := thor2d.Mesh_Vertex_At(ctx, mesh, 0)
thor2d.Set_Mesh_Texture(ctx, mesh, tex)
thor2d.Mesh_Set_Draw_Range(ctx, mesh, 0, 2)
thor2d.Draw_Texture_Array_Layer(ctx, arr, 1, thor2d.Vec2{100, 50})
valid, _ := thor2d.Validate_Shader(ctx, shader)
```
