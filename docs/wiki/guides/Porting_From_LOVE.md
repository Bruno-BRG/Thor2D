# Porting from LÖVE to Thor2D

Side-by-side reference for LOVE developers. Left is LOVE Lua, right is Thor2D
Odin (v0.8). All Thor2D snippets assume `import thor2d "thor2d"` and a
`ctx: ^thor2d.Context`.

## Lifecycle

```lua
-- LOVE
function love.load() end
function love.update(dt) end
function love.draw() end
```

```odin
// Thor2D
load :: proc(ctx: ^thor2d.Context) {}
update :: proc(ctx: ^thor2d.Context, dt: f32) {}
draw :: proc(ctx: ^thor2d.Context) {}
thor2d.Run(thor2d.Default_Config(), thor2d.Game{Load = load, Update = update, Draw = draw})
```

`Fixed_Update(ctx, dt)` runs at 60 Hz before `Update`; physics steps there too.

## Graphics state

| LOVE | Thor2D v0.8 |
| --- | --- |
| `love.graphics.setColor(r,g,b)` | `thor2d.Set_Color(ctx, thor2d.RGB(r,g,b))` |
| `love.graphics.getColor()` | `thor2d.Get_Color(ctx)` |
| `love.graphics.setBackgroundColor(...)` | `thor2d.Set_Background_Color(ctx, ...)` + `thor2d.Clear_Screen(ctx)` |
| `love.graphics.getDimensions()` | `thor2d.Get_Dimensions(ctx)` |
| `love.graphics.setBlendMode("alpha")` | `thor2d.Set_Blend_Mode(ctx, .Alpha)` |
| `love.graphics.setScissor(x,y,w,h)` | `thor2d.Set_Scissor(ctx, rect)` / `thor2d.Reset_Scissor(ctx)` |
| `love.graphics.print(s, x, y)` | `thor2d.Print(ctx, s, pos)` |
| `love.graphics.printf(s, x, y, w)` | `thor2d.Printf(ctx, s, rect, .Left)` |
| `love.graphics.arc("fill", x,y,r,a1,a2)` | `thor2d.Draw_Arc(ctx, pos, r, a1, a2, .Fill)` |
| `love.graphics.ellipse("line", ...)` | `thor2d.Draw_Ellipse(ctx, center, rx, ry, .Line)` |
| `love.graphics.polygon("fill", ...)` | `thor2d.Draw_Polygon(ctx, points, .Fill)` |
| `love.graphics.points(...)` | `thor2d.Draw_Points(ctx, points)` |
| `love.graphics.draw(img, x,y,r,sx,sy,ox,oy)` | `thor2d.Draw_Texture_Transform(ctx, tex, pos, r, scale, origin, shear)` |

Fill polygons use the built-in ear-clipping triangulator; arcs/ellipses are
CPU-tessellated polylines (segments capped at 128).

## Window / system

| LOVE | Thor2D v0.8 |
| --- | --- |
| `love.window.setTitle(t)` | `thor2d.Set_Window_Title(ctx, t)` + `thor2d.Window_Title(ctx)` getter |
| `love.window.getMode()` | `thor2d.Get_Window_Mode(ctx)` |
| `love.window.isVisible()` | `thor2d.Window_Is_Visible(ctx)` |
| `love.window.hasFocus()` | `thor2d.Window_Has_Focus(ctx)` |
| `love.window.maximize()` | `thor2d.Maximize_Window(ctx)` |
| `love.system.getPowerInfo()` | `thor2d.Get_Power_Info()` → `{State="nobattery", Percent=100}` on desktop |
| `love.system.showMessageBox()` | `thor2d.Show_Message_Box(ctx, ...)` → `.Unsupported` (explicit) |

`Set_VSync` stores the flag and returns `.Unsupported`: raylib sets vsync at
window creation only.

## Filesystem

| LOVE | Thor2D v0.8 |
| --- | --- |
| `love.filesystem.createDirectory(p)` | `thor2d.Create_Directory(fs, p)` |
| `love.filesystem.remove(p)` | `thor2d.Remove_Path(fs, p)` |
| `love.filesystem.append(p, d)` | `thor2d.Append_Save(fs, p, d)` |
| `love.filesystem.getInfo(p)` | `thor2d.Get_File_Info(fs, p)` + `Is_File/Is_Directory/File_Size` |
| `love.filesystem.isFused()` | `thor2d.Is_Fused(fs)` (true inside `.thor`) |
| `love.filesystem.lines(p)` | `thor2d.File_Lines(fs, p)` |

Sandbox rule unchanged: save dir is writable, source/archive are read-only.

## Physics (Box2D 2.x → 3.x)

Thor2D uses Box2D 3.1.1. Seven joint kinds work; four LOVE joints do not exist
upstream and return `.Unsupported` loudly:

```odin
joint, err := thor2d.Create_Physics_Joint(ctx, world, thor2d.Physics_Joint_Def{Kind = .Pulley, ..})
// err == .Unsupported on Box2D 3.x — no fake handle
```

| LOVE | Thor2D v0.8 |
| --- | --- |
| `love.physics.setMeter(s)` | `thor2d.Set_Meter(ctx, s)` / `Get_Meter(ctx)` (pixels stay canonical) |
| `love.physics.getDistance(f1, f2)` | `thor2d.Get_Physics_Distance(ctx, a, b)` (AABB approximation — documented) |
| `newDistanceJoint` … `newWheelJoint` | `thor2d.Create_Physics_Joint(ctx, world, def)` |
| `newPulley/Rope/Friction/GearJoint` | `.Unsupported` — see above |

## Input / audio / math

- `love.keyboard.setKeyRepeat` → `Set_Key_Repeat/Has_Key_Repeat`; scancodes via
  `Get_Key_From_Scancode/Get_Scancode_From_Key/Is_Scancode_Down`.
- `love.mouse.setPosition` → `Set_Mouse_Position`; cursors via
  `Set_System_Cursor(.Arrow/.IBeam/...)`; gamepad mapping getters return
  `.Unsupported` (raylib backend has no mapping DB).
- `love.audio.setVolume` → `Set_Master_Volume`; new getters
  `Get_Master_Volume/Get_Audio_Position/Get_Audio_Velocity/Get_Audio_Distance_Model`.
- `love.math.setRandomSeed/newRandomGenerator` → `Seed_Random_Generator`,
  `Get_Random_Seed/Set_Random_State`, `Random_Normal(mean, std)`.
- `love.data.pack` → fixed-width `Pack_U16/U32/U64/I32/F32` + `Get_Packed_Size`
  (no Lua format strings by design).

## Image /Math / physics extras (v0.9)

| LOVE | Thor2D v0.9 |
| --- | --- |
| `ImageData:paste(src, x, y)` | `thor2d.Paste_Image(&dst, &src, x, y)` (clipped, overlap-safe) |
| `ImageData:mapPixel(fn)` | `thor2d.Map_Pixel(&data, fn)` (`fn: proc(Color) -> Color`) |
| `ImageData:encode("png")` | `thor2d.Encode_Image_PNG(&data)` → `Byte_Buffer` (RGBA8-only, pure CPU) |
| `love.math.newTransform(x,y,a,sx,sy,ox,oy,kx,ky)` | `thor2d.Transform_Set_Transformation(&t, ...)` (**degrees**, not radians; shear → `.Unsupported`) |
| `Transform:clone/apply/inverse` | `thor2d.Clone_Transform` / `Transform_Apply` / `Transform_Inverse` / `Transform_Combine` |
| `Fixture:setFriction/setRestitution/setDensity` (+ getters) | `thor2d.Physics_Shape_Set_Friction/...` + `Physics_Shape_Friction/...` (Box2D 3.x, chains apply to all segments) |
| `Fixture:setSensor/isSensor` | `thor2d.Physics_Shape_Set_Sensor` (`.Unsupported` unless no-op; set at creation) / `Physics_Shape_Is_Sensor` |

## Joystick / mouse / window / runtime (v0.9)

| LOVE | Thor2D v0.9 |
| --- | --- |
| `love.joystick.getJoysticks()` | `thor2d.Get_Joysticks(ctx)` — integer indices, not objects |
| `Joystick:getGUID/getName` | `thor2d.Get_Gamepad_GUID(ctx, i)` (synthetic `"thor2d-gamepad-<index>"`) / `Gamepad_Name` |
| `Joystick:getAxisCount/getButtonCount` | `thor2d.Get_Gamepad_Axis_Count/Get_Gamepad_Button_Count` |
| `Joystick:setVibration()` | `thor2d.Set_Gamepad_Vibration` / `Stop_Gamepad_Vibration` (1.0 s pulses) |
| `Joystick:getHat()` | `.Unsupported` (no hat API in backend) |
| `love.mouse.newCursor(image)` | `thor2d.Load_Cursor_From_Image` + draw-it-yourself via `Draw_Texture` |
| `love.window.setMode(w,h,flags)` | `thor2d.Update_Window_Mode(ctx, w, h, fs, resizable, vsync)` |
| `love.getVersion/isVersionCompatible` | `thor2d.Thor2D_Version()` / `Is_Version_Compatible()` |
| `love.errorhandler` / `love.lowmemory` | `Game.On_Error` (nil ctx on `Create` failure) / `Game.On_Low_Memory` (desktop no-op) |

## GPU / canvas (v0.9)

| LOVE | Thor2D v0.9 |
| --- | --- |
| `love.graphics.newCanvas(w, h)` | `thor2d.Create_Canvas_Format(ctx, w, h, .RGBA8, 0)` + `Is_Canvas_Format_Supported` (float/depth formats → `.Unsupported`) |
| `love.graphics.drawInstanced(mesh, n, …)` | `thor2d.Draw_Mesh_Instanced` (GPU-resident when `.Instancing`, else CPU fallback) |
| `love.graphics.setColorMask` / stencil funcs | `.Unsupported` — no color-mask/stencil API in backend (v0.9 spike documented in `Graphics.md`) |
| `love.window.setMode(w, h, {msaa=n})` | `Config.MSAA` (4x hint, creation-time only) |

## Fonts / images / audio / video (v0.9)

| LOVE | Thor2D v0.9 |
| --- | --- |
| `love.graphics.newImageFont(img, glyphs)` | `thor2d.Load_Image_Font` + `Draw/Measure_Text_Image_Font` (arbitrary glyph order; non-ASCII rejected) |
| `love.image.isCompressed(file)` | `thor2d.Is_Compressed_Image(data)` (PNG/JPEG are false by design) |
| `love.image.newCompressedData(file)` | `thor2d.Load_Compressed_Texture` (unrealizable format → `.Unsupported`) |
| `love.audio` effects (echo/reverb/…) | `Create_Audio_Effect(.Delay/.Reverb)`; other 6 LOVE types → `.Unsupported` (query: `Is_LOVE_Audio_Effect_Supported`) |
| video with audio track | video plays silently for now; `Video_Has_Audio` reports false until the FFmpeg shim demuxes audio |

## Networking / mobile / editor (v0.9)

LÖVE has no built-in networking (`enet`/`socket` are third-party); Thor2D v0.9
ships a small non-blocking TCP+UDP module instead.

| LOVE / mobile concept | Thor2D v0.9 |
| --- | --- |
| third-party `enet` / `luasocket` | `thor2d` net module: `TCP_Listen/Accept/Connect/Send/Receive/Close`, `UDP_Open/Send_To/Receive_From/Close`, `Net_Resolve`, `.Not_Ready` polling (see `modules/Net.md`, example `net_echo_v09`) |
| `love.system.vibrate()` | `thor2d.Vibrate(seconds)` (desktop `.Unsupported`, mobile-future) |
| display orientation / keep-screen-on | `thor2d.Get_Display_Orientation` (aspect-derived) / `Set_Display_Sleep_Enabled` (`.Unsupported`) |
| editor tooling | CLI inspector scaffold `tools/editor_v09` (validate + inspect `project.json`); full editing remains future work |

## Particles (v0.10)

| LOVE | Thor2D v0.10 |
| --- | --- |
| `setEmissionRate/getEmissionRate` | `Set/Get_Particle_Emission_Rate` |
| `setEmitterLifetime` | `Set_Particle_Emitter_Lifetime` (0 = infinite, not -1) |
| `setParticleLifetime` | `Set/Get_Particle_Lifetime` |
| `setDirection/setSpread` | `Set_Particle_Direction/Spread` (radians) |
| `setSpeed` | `Set/Get_Particle_Speed` |
| `setLinearAcceleration` | `Set/Get_Particle_Linear_Acceleration` |
| `setRadialAcceleration` | `Set/Get_Particle_Radial_Acceleration` |
| `setTangentialAcceleration` | `Set/Get_Particle_Tangential_Acceleration` |
| `setLinearDamping` | `Set/Get_Particle_Damping` |
| `setSpin` | `Set/Get_Particle_Spin` (rad/s) |
| `setSizes/setColors` | `Set_Particle_Sizes/Colors` (u8 colors) |
| `setTexture` | `Replace_Particle_Texture` |
| `start/stop/pause/reset/isActive/isPaused/isStopped/clone` | `Start/Stop/Pause/Reset_Particles`, `Is_Particles_Active/Paused/Stopped`, `Clone_Particles` (clone starts stopped+empty; systems start active, unlike LOVE) |

Out of scope: quads, per-particle insert/remove, serialize, emission-area shapes.

## Physics callbacks + runtime (v0.10)

| LOVE | Thor2D v0.10 |
| --- | --- |
| `World:setCallbacks(begin,end,pre,post)` | `Set_Physics_Callbacks` (post-step; sensors poll-only; pre can't disable) |
| `Body:getMass/getInertia/resetMassData` | `Physics_Body_Mass_Data` / `Physics_Body_Reset_Mass` |
| `Body:setActive/isActive/setBullet/setFixedRotation/setSleepingAllowed` | `Physics_Body_Set/Is_*` counterparts |
| `Body:getWorldPoint/getLocalPoint/getWorldVector/getLocalVector` | `Physics_Body_World/Local_Point/Vector` (radians) |
| `Fixture:setFilter/getFilter` | `Physics_Shape_Set_Filter` / `Physics_Shape_Filter` |
| `World:getBodyCount/getJointCount/getContactCount` | `Physics_World_*_Count` (+ `Bodies/Joints/Contacts` lists) |
| `Contact:setEnabled/setFriction/setRestitution` | `.Unsupported` (transient contacts in Box2D 3.x; use filters) |
| `Joint:getBodies/getType/getAnchors` | `Physics_Joint_Bodies/Type/Anchors` (world space) |
| `RevoluteJoint/PrismaticJoint` limits + motors | `Physics_Joint_Revolute/Prismatic_*` |

## Text / canvas / shader (v0.10)

| LOVE | Thor2D v0.10 |
| --- | --- |
| `Font:getAscent/getDescent/getBaseline/getHeight` | `Font_Ascent/Descent/Baseline/Line_Height` (proportional to em size) |
| `Font:setLineHeight/getLineHeight` | `Font_Set/Get_Line_Height` (multiplier) |
| `Font:hasGlyphs/getDPIScale` | `Font_Has_Glyphs` (best-effort) / `Font_DPI_Scale` |
| `Text:add/clear/getFont/setFont` | `Text_Add/Addf`, `Text_Clear`, `Text_Font/Set_Font` |
| `Quad:getViewport/setViewport/getTextureDimensions` | `Quad_Viewport/Set_Viewport/Texture_Size` (value semantics) |
| `SpriteBatch:set/setColor/getCount/setDrawRange` | `Sprite_Batch_Set/Set_Color/Count/Set_Draw_Range/Draw_Range` (**0-based**) |
| `Canvas:renderTo/newImageData/getMSAA` | `Canvas_Render_To`, `Canvas_To_Image`, `Canvas_MSAA` (always 0) |
| `Shader:hasUniform/getWarnings` | `Shader_Has_Uniform` (real) / `Shader_Warnings` (always `""`) |

## Audio total (v0.10)

| LOVE | Thor2D v0.10 |
| --- | --- |
| `Source:isLooping/getVolume/getPitch/getPosition/getVelocity/getDirection/getCone/getRolloff/isRelative/getChannelCount/getType` | `Audio_Source_Is_Looping/Get_Volume/…` (2D projection) |
| `love.audio.play/pause/stop()` (no args) | `Play/Pause/Stop_All_Audio` (→ affected count) |
| `love.audio.setOrientation/getOrientation` | `Set/Get_Audio_Orientation` (Vec2 pair, Z=0) |
| `love.audio.getDopplerScale` | `Get_Audio_Doppler` (+ per-source getter) |
| `love.audio.getRecordingDevices` / `RecordingDevice:*` | `Audio_Recording_Devices/…_Name/Is_Audio_Capturing/Audio_Capture_*` (indexed start → `.Unsupported`, default device only) |
| `SoundData:getSampleRate/getChannelCount/getBitDepth`, `Decoder:*` | `Sound_Data_*/Audio_Decoder_*` |

## Mesh / texture / state / video (v0.10)

| LOVE | Thor2D v0.10 |
| --- | --- |
| `Mesh:getVertex/setVertex/getVertexCount/getDrawMode/setDrawMode` | `Mesh_Vertex_At/Set_Vertex/Count/Draw_Mode_Of/Set_Draw_Mode` (**0-based**) |
| `Mesh:getTexture/setTexture/getDrawRange/setDrawRange` | `Mesh_Texture_Of/Set_Mesh_Texture`, `Mesh_Draw_Range/Set` (`(0,-1)` resets) |
| `Texture:isReadable/getMipmapCount/getPixelDimensions` | `Texture_Is_Readable` (always true) / `Texture_Mipmap_Count` (1) / `Texture_Pixel_Size` |
| `love.graphics.newArrayImage` | `Load_Texture_Array` + `Draw_Texture_Array_Layer` (CPU layer list, no GPU array) |
| `graphics.getCanvas/getShader/validateShader` | `Get_Active_Canvas/Shader`, `Validate_Shader` |
| `Canvas:discard` | `Discard_Canvas` (real no-op hint) |
| `graphics.isGammaCorrect` | always `false`; manual `SRGB_To_Linear`/`Linear_To_SRGB` |
| `Video:rewind/getFilename` + frame filter | `Video_Rewind`, `Video_Source_Path`, `Set_Video_Filter` (audio still unsupported) |

## File / math / threads / window / events (v0.10)

| LOVE | Thor2D v0.10 |
| --- | --- |
| `File:isOpen/isEOF/getSize/getFilename/getMode` | `File_Is_Open/Is_EOF/Size_Of/Name/Mode` |
| `File:read(line)` / `File:flush` / `File:setBuffer` | `File_Read_Line` / `File_Flush` (no-op, unbuffered) / only `.None` honored |
| `love.filesystem.newFileData` / memory mount | `New_File_Data` (+ `Name`/`Extension`) / `Mount_Archive_Memory` |
| `Transform:getMatrix/setMatrix` | `Get/Set_Matrix` (exact via override; TRS edits clear it) |
| `love.math.noise` 1/3/4-arg | `Random_Noise_1D/3D/4D` (lattice hash, no smoothing) |
| `BezierCurve:render/getSegment`, control points | `Bezier_Render/Segment`, `Get/Set_Control_Points`, `Degree` |
| `Channel:getCount/clear/hasRead` | `Channel_Get_Count/Clear/Has_Data` (`peek` unsupported; named registry wontfix) |
| `window.getFullscreenModes/getIcon/requestAttention/isDisplaySleepEnabled` | `Get_Fullscreen_Modes` / `Window_Has_Icon` / `Request_Attention` (unsupported) / `Is_Display_Sleep_Enabled` |
| `textinput/textedited/filedropped/directorydropped` | `Text_Input`/`Key_Text_Edited`/`File_Dropped`/`Directory_Dropped` events (table in `Event.md`) |
| `data.compress` level / base64 lines | `Compress_With_Level` / `Encode_Base64_Lines` |
