package raylib_backend

import "core:c"
import math "core:math"
import "core:strings"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

Shader_Matrix :: #row_major matrix[4, 4]f32

Texture_Entry :: struct {
	handle: u64,
	value: rl.Texture2D,
}

Sound_Entry :: struct {
	handle: u64,
	value: rl.Sound,
}

Music_Entry :: struct {
	handle: u64,
	value: rl.Music,
	data: [dynamic]byte,
}

Audio_Stream_Entry :: struct {
	handle: u64,
	value: rl.AudioStream,
	channels: int,
	playing: bool,
}

Font_Entry :: struct {
	handle: u64,
	value: rl.Font,
	// v0.10 LOVE Font:setLineHeight multiplier (default 1.0). Honored by
	// Font_Line_Height queries, Measure_Text_Layout (via the public layer)
	// and multiline Text draw advance; raylib draws use native advance
	// unless the multiplier differs from 1.0.
	line_height: f32,
}

Text_Entry :: struct {
	handle: u64,
	font_handle: u64,
	value: string,
	size, spacing: f32,
}

Canvas_Entry :: struct {
	handle: u64,
	value: rl.RenderTexture2D,
	width, height: int,
	// v0.10 LOVE Canvas:getMSAA parity. Raylib canvases (LoadRenderTexture)
	// have no per-canvas MSAA control, so this is always 0; window-level
	// MSAA comes from Config.MSAA at creation time. Stored for the getter.
	msaa: int,
}

Shader_Entry :: struct {
	handle: u64,
	value: rl.Shader,
}

Sprite_Command :: struct {
	source, destination: rl.Rectangle,
	origin: rl.Vector2,
	rotation: f32,
	tint: rl.Color,
}

Sprite_Batch_Entry :: struct {
	handle: u64,
	texture_handle: u64,
	capacity: int,
	commands: [dynamic]Sprite_Command,
	// v0.10 LOVE SpriteBatch:setDrawRange subset. 0-based start; count < 0
	// draws everything from start (the default). Thor2D indices are 0-based;
	// LOVE sprite ids are 1-based (see the public wrapper docs).
	draw_start: int,
	draw_count: int,
}

Particle_Config_Internal :: struct {
	max_particles: int,
	lifetime_min, lifetime_max: f32,
	emission_rate: f32,
	gravity: rl.Vector2,
	start_size, end_size: f32,
	start_color, end_color: rl.Color,
	// v0.10 LOVE-parity tuning (ParticleSystem set*). Angles in radians,
	// spin in radians/second, matching LOVE units. The backend stores
	// radians; emit converts spin to degrees/second for Particle_State.
	direction, spread: f32,
	speed_min, speed_max: f32,
	linear_accel_min, linear_accel_max: rl.Vector2,
	radial_min, radial_max: f32,
	tangential_min, tangential_max: f32,
	damping_min, damping_max: f32,
	spin_min, spin_max: f32,
	// Emitter budget in seconds; <= 0 means infinite emission.
	emitter_lifetime: f32,
}

Particle_State :: struct {
	position, velocity: rl.Vector2,
	life, lifetime: f32,
	rotation, angular_velocity: f32,
	scale: f32,
	// v0.10 per-particle draws, fixed at emit (uniform in the min..max
	// ranges above) so live particles keep their own coefficients.
	linear_accel: rl.Vector2,
	radial_accel, tangential_accel, damping: f32,
}

Particle_System_Entry :: struct {
	handle: u64,
	texture_handle: u64,
	config: Particle_Config_Internal,
	particles: [dynamic]Particle_State,
	emission_remainder: f32,
	seed: u32,
	// v0.10 lifecycle: new systems start active (Thor2D CType behavior:
	// Update emits at the configured rate without an explicit start;
	// call Stop_Particles for LOVE's initially-stopped flow).
	active: bool,
	paused: bool,
	emitter_age: f32,
	// v0.10 appearance tracks (LOVE setSizes/setColors, max 8 stops).
	// Fixed arrays so Unload/Destroy need no extra cleanup.
	sizes: [8]f32,
	size_count: int,
	colors: [8]rl.Color,
	color_count: int,
}

Mesh_Vertex_Internal :: struct {
	position_x, position_y: f32,
	uv_x, uv_y: f32,
	normal_x, normal_y: f32,
	r, g, b, a: u8,
}

Mesh_Entry :: struct {
	handle: u64,
	vertices: [dynamic]Mesh_Vertex_Internal,
	indices: [dynamic]u32,
	positions: [dynamic]f32,
	texcoords: [dynamic]f32,
	normals: [dynamic]f32,
	colors: [dynamic]u8,
	gpu_vao, gpu_position, gpu_texcoord, gpu_normal, gpu_color, gpu_indices: c.uint,
	gpu_ready: bool,
	mode: int,
	// v0.10 LOVE Mesh parity: bound texture (Mesh:setTexture; 0 = none, so
	// Draw_Mesh draws untextured) and draw range (Mesh:setDrawRange; 0-based
	// start, count < 0 draws to the end — the default (0, -1) draws all).
	texture_handle: u64,
	draw_start: int,
	draw_count: int,
}

Texture_Cache_Entry :: struct {
	path: string,
	handle: u64,
	asset_id: u64,
}

Font_Cache_Entry :: struct {
	path: string,
	handle: u64,
	asset_id: u64,
}

Sound_Cache_Entry :: struct {
	path: string,
	handle: u64,
	asset_id: u64,
}

Raw_Event_Kind :: enum int {
	Quit,
	Key_Pressed,
	Key_Released,
	Text_Input,
	Mouse_Button_Pressed,
	Mouse_Button_Released,
	Mouse_Moved,
	Mouse_Wheel,
	Window_Resized,
	Focus_Changed,
	Window_Visible,
	Key_Text_Edited,
	Gamepad_Button_Pressed,
	Gamepad_Button_Released,
	Gamepad_Axis_Moved,
	Joystick_Added,
	Joystick_Removed,
	Joystick_Button_Pressed,
	Joystick_Button_Released,
	Joystick_Axis_Moved,
	Joystick_Hat_Moved,
	Touch_Pressed,
	Touch_Released,
	Touch_Moved,
	File_Dropped,
	Directory_Dropped,
}

Raw_Event :: struct {
	kind: Raw_Event_Kind,
	key: int,
	mouse_button: int,
	x, y: f32,
	dx, dy: f32,
	text: rune,
	width, height: int,
	focused: bool,
	visible: bool,
	device, button, axis, hat: int,
	value: f32,
	touch_id: int,
	path: string,
}

Transform_State :: struct {
	// Column-vector affine matrix in raylib's row-major representation.  The
	// matrix is authoritative so Replace_Transform preserves shear and other
	// affine combinations instead of decomposing them back to lossy TRS.
	matrix_value: rl.Matrix,
	translation: rl.Vector2,
	scale: rl.Vector2,
	rotation: f32,
}

Backend :: struct {
	textures: [dynamic]Texture_Entry,
	sounds: [dynamic]Sound_Entry,
	music: [dynamic]Music_Entry,
	audio_streams: [dynamic]Audio_Stream_Entry,
	fonts: [dynamic]Font_Entry,
	texts: [dynamic]Text_Entry,
	canvases: [dynamic]Canvas_Entry,
	shaders: [dynamic]Shader_Entry,
	sprite_batches: [dynamic]Sprite_Batch_Entry,
	particles: [dynamic]Particle_System_Entry,
	meshes: [dynamic]Mesh_Entry,
	texture_cache: [dynamic]Texture_Cache_Entry,
	font_cache: [dynamic]Font_Cache_Entry,
	sound_cache: [dynamic]Sound_Cache_Entry,
	events: [dynamic]Raw_Event,
	transforms: [dynamic]Transform_State,
	transform: Transform_State,
	camera_active: bool,
	canvas_active: bool,
	// v0.10 which canvas Set_Canvas targeted (0 when rendering to screen).
	// Needed by the Get_Active_Canvas parity query; canvas_active alone only
	// says THAT a canvas is targeted, not which one.
	canvas_handle: u64,
	shader_active: u64,
	next_handle: u64,
	next_asset_id: u64,
	audio_ready: bool,
	focused: bool,
	visible: bool,
	gamepads: [8]bool,
	touch_ids: [dynamic]int,
	frame_times: [60]f32,
	frame_time_cursor, frame_time_count: int,
	gpu_mesh_supported: bool,
	point_size: f32,
	line_width: f32,
	draw_calls: int,
	canvas_switches: int,
	// v0.9 requested MSAA samples (window creation hint only).
	msaa_samples: int,
	// v0.10 default-font (handle 0) line-height multiplier. Named fonts store
	// theirs on Font_Entry; the default font has no entry, so it lives here
	// (1.0 unless Font_Set_Line_Height_Multiplier changes it).
	default_font_line_height: f32,
}

Create :: proc(title: string, width, height, target_fps: int, resizable, vsync: bool, msaa_samples := 0) -> (rawptr, bool) {
	b := new(Backend)
	b.next_handle = 1
	b.next_asset_id = 1
	b.transform = identity_transform()
	b.point_size = 2
	b.line_width = 1
	b.msaa_samples = msaa_samples if msaa_samples > 0 else 0
	b.default_font_line_height = 1

	flags := rl.ConfigFlags{}
	if resizable {
		flags += {.WINDOW_RESIZABLE}
	}
	if vsync {
		flags += {.VSYNC_HINT}
	}
	if b.msaa_samples > 0 {
		// Raylib exposes a single 4x MSAA hint; any positive request maps
		// to it. Must precede InitWindow. v0.9: wired from Config.MSAA.
		flags += {.MSAA_4X_HINT}
	}
	rl.SetConfigFlags(flags)

	c_title, c_err := strings.clone_to_cstring(title, context.temp_allocator)
	if c_err != nil {
		free(b)
		return nil, false
	}
	rl.InitWindow(c.int(width), c.int(height), c_title)
	if !rl.IsWindowReady() {
		free(b)
		return nil, false
	}

	if target_fps > 0 {
		rl.SetTargetFPS(c.int(target_fps))
	}
	b.gpu_mesh_supported = rlgl.GetVersion() != rlgl.GlVersion.OPENGL_11
	b.focused = rl.IsWindowFocused()
	b.visible = !rl.IsWindowHidden()
	return rawptr(b), true
}

GPU_Mesh_Supported :: proc(state: rawptr) -> bool {
	return state != nil && (cast(^Backend)state).gpu_mesh_supported
}

Destroy :: proc(state: rawptr) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	if b.shader_active != 0 {
		rl.EndShaderMode()
		b.shader_active = 0
	}
	if b.canvas_active {
		rl.EndTextureMode()
		b.canvas_active = false
	}
	b.canvas_handle = 0
	if b.camera_active {
		rl.EndMode2D()
		b.camera_active = false
	}
	for entry in b.textures {
		rl.UnloadTexture(entry.value)
	}
	// Audio resources are owned by thor2d/internal/audio. The legacy fields
	// remain for source compatibility, but this backend never touches raudio.
	for entry in b.music {
		delete(entry.data)
	}
	for entry in b.fonts {
		rl.UnloadFont(entry.value)
	}
	for entry in b.texts {
		if len(entry.value) > 0 {
			delete(entry.value)
		}
	}
	for entry in b.canvases {
		rl.UnloadRenderTexture(entry.value)
	}
	for entry in b.shaders {
		rl.UnloadShader(entry.value)
	}
	for i := 0; i < len(b.sprite_batches); i += 1 {
		delete(b.sprite_batches[i].commands)
	}
	for i := 0; i < len(b.particles); i += 1 {
		delete(b.particles[i].particles)
	}
	for i := 0; i < len(b.meshes); i += 1 {
		if b.meshes[i].gpu_ready {
			unload_mesh_gpu(&b.meshes[i])
		}
		delete(b.meshes[i].vertices)
		delete(b.meshes[i].indices)
		delete(b.meshes[i].positions)
		delete(b.meshes[i].texcoords)
		delete(b.meshes[i].colors)
	}
	for entry in b.texture_cache {
		delete(entry.path)
	}
	for entry in b.font_cache {
		delete(entry.path)
	}
	for entry in b.sound_cache {
		delete(entry.path)
	}
	delete(b.textures)
	delete(b.sounds)
	delete(b.music)
	delete(b.audio_streams)
	delete(b.fonts)
	delete(b.texts)
	delete(b.canvases)
	delete(b.shaders)
	delete(b.sprite_batches)
	delete(b.particles)
	delete(b.meshes)
	delete(b.texture_cache)
	delete(b.font_cache)
	delete(b.sound_cache)
	for event in b.events {
		delete(event.path)
	}
	delete(b.events)
	delete(b.transforms)
	delete(b.touch_ids)
	rl.CloseWindow()
	free(b)
}

Is_Running :: proc(state: rawptr) -> bool {
	return state != nil && !rl.WindowShouldClose()
}

Poll_Events :: proc(state: rawptr) -> []Raw_Event {
	if state == nil {
		return nil
	}
	b := cast(^Backend)state
	for event in b.events {
		delete(event.path)
	}
	clear(&b.events)

	if rl.WindowShouldClose() {
		append(&b.events, Raw_Event{kind = .Quit})
	}

	for key := 0; key <= 348; key += 1 {
		if rl.IsKeyPressed(rl.KeyboardKey(key)) {
			append(&b.events, Raw_Event{kind = .Key_Pressed, key = key})
		}
		if rl.IsKeyReleased(rl.KeyboardKey(key)) {
			append(&b.events, Raw_Event{kind = .Key_Released, key = key})
		}
	}

	for {
		text := rl.GetCharPressed()
		if text == 0 {
			break
		}
		append(&b.events, Raw_Event{kind = .Text_Input, text = text})
	}

	for button := 0; button <= 6; button += 1 {
		if rl.IsMouseButtonPressed(rl.MouseButton(button)) {
			append(&b.events, Raw_Event{kind = .Mouse_Button_Pressed, mouse_button = button})
		}
		if rl.IsMouseButtonReleased(rl.MouseButton(button)) {
			append(&b.events, Raw_Event{kind = .Mouse_Button_Released, mouse_button = button})
		}
	}

	position := rl.GetMousePosition()
	delta := rl.GetMouseDelta()
	if delta.x != 0 || delta.y != 0 {
		append(&b.events, Raw_Event{kind = .Mouse_Moved, x = position.x, y = position.y, dx = delta.x, dy = delta.y})
	}
	wheel := rl.GetMouseWheelMoveV()
	if wheel.x != 0 || wheel.y != 0 {
		append(&b.events, Raw_Event{kind = .Mouse_Wheel, x = position.x, y = position.y, dx = wheel.x, dy = wheel.y})
	}

	if rl.IsWindowResized() {
		append(&b.events, Raw_Event{kind = .Window_Resized, width = int(rl.GetScreenWidth()), height = int(rl.GetScreenHeight())})
	}

	focused := rl.IsWindowFocused()
	if focused != b.focused {
		b.focused = focused
		append(&b.events, Raw_Event{kind = .Focus_Changed, focused = focused})
	}

	visible := !rl.IsWindowHidden()
	if visible != b.visible {
		b.visible = visible
		append(&b.events, Raw_Event{kind = .Window_Visible, visible = visible})
	}

	for device := 0; device < len(b.gamepads); device += 1 {
		available := rl.IsGamepadAvailable(c.int(device))
		if available && !b.gamepads[device] {
			append(&b.events, Raw_Event{kind = .Joystick_Added, device = device})
		}
		if !available && b.gamepads[device] {
			append(&b.events, Raw_Event{kind = .Joystick_Removed, device = device})
		}
		b.gamepads[device] = available
		if !available {
			continue
		}
		for button := 0; button < 18; button += 1 {
			if rl.IsGamepadButtonPressed(c.int(device), rl.GamepadButton(button)) {
				append(&b.events, Raw_Event{kind = .Gamepad_Button_Pressed, device = device, button = button})
			}
			if rl.IsGamepadButtonReleased(c.int(device), rl.GamepadButton(button)) {
				append(&b.events, Raw_Event{kind = .Gamepad_Button_Released, device = device, button = button})
			}
		}
		axis_count := int(rl.GetGamepadAxisCount(c.int(device)))
		for axis := 0; axis < axis_count && axis < 6; axis += 1 {
			value := rl.GetGamepadAxisMovement(c.int(device), rl.GamepadAxis(axis))
			if math.abs(value) > 0.001 {
				append(&b.events, Raw_Event{kind = .Gamepad_Axis_Moved, device = device, axis = axis, value = value})
			}
		}
	}

	current_touch_ids: [dynamic]int
	touch_count := int(rl.GetTouchPointCount())
	for index := 0; index < touch_count; index += 1 {
		id := int(rl.GetTouchPointId(c.int(index)))
		touch_position := rl.GetTouchPosition(c.int(index))
		was_present := false
		for previous in b.touch_ids {
			if previous == id {
				was_present = true
				break
			}
		}
		kind := Raw_Event_Kind.Touch_Moved
		if !was_present {
			kind = .Touch_Pressed
		}
		append(&current_touch_ids, id)
		append(&b.events, Raw_Event{kind = kind, touch_id = id, x = touch_position.x, y = touch_position.y})
	}
	for previous in b.touch_ids {
		still_present := false
		for current in current_touch_ids {
			if current == previous {
				still_present = true
				break
			}
		}
		if !still_present {
			append(&b.events, Raw_Event{kind = .Touch_Released, touch_id = previous})
		}
	}
	delete(b.touch_ids)
	b.touch_ids = current_touch_ids

	if rl.IsFileDropped() {
		files := rl.LoadDroppedFiles()
		for i := 0; i < int(files.count); i += 1 {
			path, clone_err := strings.clone(string(files.paths[i]))
			if clone_err == nil {
				append(&b.events, Raw_Event{kind = .File_Dropped, path = path})
			}
		}
		rl.UnloadDroppedFiles(files)
	}

	return b.events[:]
}

Begin_Frame :: proc(state: rawptr) {
	if state != nil {
		b := cast(^Backend)state
		frame_time := rl.GetFrameTime()
		b.frame_times[b.frame_time_cursor] = frame_time
		b.frame_time_cursor = (b.frame_time_cursor + 1) % len(b.frame_times)
		b.frame_time_count = min(b.frame_time_count + 1, len(b.frame_times))
		if b.shader_active != 0 {
			rl.EndShaderMode()
			b.shader_active = 0
		}
		if b.canvas_active {
			rl.EndTextureMode()
			b.canvas_active = false
		}
		b.canvas_handle = 0
		if b.camera_active {
			rl.EndMode2D()
			b.camera_active = false
		}
		b.transform = identity_transform()
		clear(&b.transforms)
		b.draw_calls = 0
		b.canvas_switches = 0
		rl.BeginDrawing()
	}
}

FPS :: proc(state: rawptr) -> int {
	if state == nil {
		return 0
	}
	return int(rl.GetFPS())
}

Average_Frame_Time :: proc(state: rawptr) -> f32 {
	if state == nil {
		return 0
	}
	b := cast(^Backend)state
	if b.frame_time_count == 0 {
		return 0
	}
	total: f32
	for i := 0; i < b.frame_time_count; i += 1 {
		total += b.frame_times[i]
	}
	return total / f32(b.frame_time_count)
}

Window_Position :: proc(state: rawptr) -> (x, y: int) {
	if state == nil {
		return 0, 0
	}
	position := rl.GetWindowPosition()
	return int(position.x), int(position.y)
}

Set_Window_Position :: proc(state: rawptr, x, y: int) {
	if state != nil {
		rl.SetWindowPosition(c.int(x), c.int(y))
	}
}

Window_DPI_Scale :: proc(state: rawptr) -> (x, y: f32) {
	if state == nil {
		return 0, 0
	}
	scale := rl.GetWindowScaleDPI()
	return scale.x, scale.y
}

Clipboard_Text :: proc(state: rawptr) -> string {
	if state == nil {
		return ""
	}
	return string(rl.GetClipboardText())
}

Set_Clipboard_Text :: proc(state: rawptr, value: string) {
	if state == nil {
		return
	}
	c_value, err := strings.clone_to_cstring(value, context.temp_allocator)
	if err == nil {
		rl.SetClipboardText(c_value)
	}
}

Open_URL :: proc(state: rawptr, value: string) -> bool {
	if state == nil {
		return false
	}
	c_value, err := strings.clone_to_cstring(value, context.temp_allocator)
	if err != nil {
		return false
	}
	rl.OpenURL(c_value)
	return true
}

Set_Mouse_Grab :: proc(state: rawptr, grab: bool) {
	if state == nil {
		return
	}
	if grab {
		rl.DisableCursor()
	} else {
		rl.EnableCursor()
	}
}

End_Frame :: proc(state: rawptr) {
	if state != nil {
		rl.EndDrawing()
	}
}

Delta_Time :: proc(state: rawptr) -> f32 {
	if state == nil {
		return 0
	}
	return rl.GetFrameTime()
}

Elapsed_Time :: proc(state: rawptr) -> f64 {
	if state == nil {
		return 0
	}
	return rl.GetTime()
}

Set_Target_FPS :: proc(state: rawptr, fps: int) {
	if state != nil {
		rl.SetTargetFPS(c.int(fps))
	}
}

Window_Size :: proc(state: rawptr) -> (width, height: int) {
	if state == nil {
		return 0, 0
	}
	return int(rl.GetScreenWidth()), int(rl.GetScreenHeight())
}

Desktop_Size :: proc(state: rawptr) -> (width, height: int) {
	if state == nil {
		return 0, 0
	}
	monitor := rl.GetCurrentMonitor()
	return int(rl.GetMonitorWidth(monitor)), int(rl.GetMonitorHeight(monitor))
}

Current_Display_Mode :: proc(state: rawptr) -> (width, height, refresh_rate: int) {
	if state == nil {
		return 0, 0, 0
	}
	monitor := rl.GetCurrentMonitor()
	return int(rl.GetMonitorWidth(monitor)), int(rl.GetMonitorHeight(monitor)), int(rl.GetMonitorRefreshRate(monitor))
}

Is_Minimized :: proc(state: rawptr) -> bool {
	return state != nil && rl.IsWindowMinimized()
}

Set_Cursor_Visible :: proc(state: rawptr, visible: bool) {
	if state == nil {
		return
	}
	if visible {
		rl.EnableCursor()
	} else {
		rl.DisableCursor()
	}
}

Set_Window_Title :: proc(state: rawptr, title: string) {
	if state == nil {
		return
	}
	c_title, c_err := strings.clone_to_cstring(title, context.temp_allocator)
	if c_err == nil {
		rl.SetWindowTitle(c_title)
	}
}

Set_Window_Size :: proc(state: rawptr, width, height: int) {
	if state != nil {
		rl.SetWindowSize(c.int(width), c.int(height))
	}
}

Toggle_Fullscreen :: proc(state: rawptr) {
	if state != nil {
		rl.ToggleFullscreen()
	}
}

Is_Fullscreen :: proc(state: rawptr) -> bool {
	return state != nil && rl.IsWindowFullscreen()
}

Is_Window_Open :: proc(state: rawptr) -> bool {
	return state != nil && rl.IsWindowReady() && !rl.WindowShouldClose()
}

Has_Focus :: proc(state: rawptr) -> bool {
	return state != nil && rl.IsWindowFocused()
}

Has_Mouse_Focus :: proc(state: rawptr) -> bool {
	return state != nil && rl.IsWindowFocused()
}

Is_Visible :: proc(state: rawptr) -> bool {
	return state != nil && !rl.IsWindowHidden()
}

Is_Maximized :: proc(state: rawptr) -> bool {
	return state != nil && rl.IsWindowMaximized()
}

Maximize_Window :: proc(state: rawptr) {
	if state != nil && !rl.IsWindowMaximized() {
		rl.MaximizeWindow()
	}
}

Minimize_Window :: proc(state: rawptr) {
	if state != nil && !rl.IsWindowMinimized() {
		rl.MinimizeWindow()
	}
}

Restore_Window :: proc(state: rawptr) {
	if state != nil && (rl.IsWindowMaximized() || rl.IsWindowMinimized()) {
		rl.RestoreWindow()
	}
}

Get_VSync :: proc(state: rawptr) -> bool {
	return state != nil && rl.IsWindowState({.VSYNC_HINT})
}

Get_Display_Count :: proc(state: rawptr) -> int {
	if state == nil {
		return 0
	}
	return int(rl.GetMonitorCount())
}

Get_Display_Info :: proc(state: rawptr, index: int) -> (name: string, x, y, w, h: int, ok: bool) {
	if state == nil {
		return "", 0, 0, 0, 0, false
	}
	count := int(rl.GetMonitorCount())
	if index < 0 || index >= count {
		return "", 0, 0, 0, 0, false
	}
	pos := rl.GetMonitorPosition(c.int(index))
	return string(rl.GetMonitorName(c.int(index))), int(pos.x), int(pos.y), int(rl.GetMonitorWidth(c.int(index))), int(rl.GetMonitorHeight(c.int(index))), true
}

Set_Window_Icon_RGBA :: proc(state: rawptr, width, height: int, pixels: []u8) -> bool {
	if state == nil || width <= 0 || height <= 0 || len(pixels) < width*height*4 {
		return false
	}
	image := rl.Image{
		data = raw_data(pixels),
		width = c.int(width),
		height = c.int(height),
		mipmaps = 1,
		format = .UNCOMPRESSED_R8G8B8A8,
	}
	rl.SetWindowIcon(image)
	return true
}

Set_Mouse_Position :: proc(state: rawptr, x, y: f32) {
	if state != nil {
		rl.SetMousePosition(c.int(x), c.int(y))
	}
}

Set_System_Cursor :: proc(state: rawptr, cursor: int) {
	if state == nil {
		return
	}
	// 0=arrow 1=ibeam 2=crosshair 3=hand(pointing) 4=resize-ew 5=resize-ns 6=not-allowed
	switch cursor {
	case 1:
		rl.SetMouseCursor(.IBEAM)
	case 2:
		rl.SetMouseCursor(.CROSSHAIR)
	case 3:
		rl.SetMouseCursor(.POINTING_HAND)
	case 4:
		rl.SetMouseCursor(.RESIZE_EW)
	case 5:
		rl.SetMouseCursor(.RESIZE_NS)
	case 6:
		rl.SetMouseCursor(.NOT_ALLOWED)
	case:
		rl.SetMouseCursor(.ARROW)
	}
}

Begin_Camera :: proc(state: rawptr, target_x, target_y, offset_x, offset_y, rotation, zoom: f32) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	if b.camera_active {
		return
	}
	actual_zoom := zoom
	if actual_zoom <= 0 {
		actual_zoom = 1
	}
	rl.BeginMode2D(rl.Camera2D{
		offset = to_vec2(offset_x, offset_y),
		target = to_vec2(target_x, target_y),
		rotation = rotation,
		zoom = actual_zoom,
	})
	b.camera_active = true
}

End_Camera :: proc(state: rawptr) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	if b.camera_active {
		rl.EndMode2D()
		b.camera_active = false
	}
}

find_canvas :: proc(b: ^Backend, handle: u64) -> (^Canvas_Entry, bool) {
	for i := 0; i < len(b.canvases); i += 1 {
		if b.canvases[i].handle == handle {
			return &b.canvases[i], true
		}
	}
	return nil, false
}

Create_Canvas :: proc(state: rawptr, width, height: int) -> (u64, bool) {
	if state == nil || width <= 0 || height <= 0 {
		return 0, false
	}
	b := cast(^Backend)state
	canvas := rl.LoadRenderTexture(c.int(width), c.int(height))
	if !rl.IsRenderTextureValid(canvas) {
		return 0, false
	}
	handle := b.next_handle
	b.next_handle += 1
	append(&b.canvases, Canvas_Entry{handle = handle, value = canvas, width = width, height = height, msaa = 0})
	return handle, true
}

// v0.9 typed canvas creation. format is the Canvas_Format ordinal
// (0=RGBA8, 1=RGBA16F, 2=RGBA32F, 3=Depth_Stencil). Only RGBA8 maps to a real
// raylib resource: LoadRenderTexture produces an RGBA8 color buffer plus a
// depth renderbuffer. Float and explicit depth-stencil FBOs would need custom
// framebuffer assembly (LoadFramebuffer + FramebufferAttach + float texture
// upload) outside raylib's render-batch state tracking, so they report
// failure here and the public wrapper returns .Unsupported instead of a fake
// handle. Per-canvas MSAA is handled by the caller (window MSAA comes from
// Config.MSAA at creation time); this proc never takes an msaa argument.
Create_Canvas_Format :: proc(state: rawptr, width, height, format: int) -> (u64, bool) {
	if state == nil || width <= 0 || height <= 0 {
		return 0, false
	}
	if format != 0 {
		return 0, false
	}
	return Create_Canvas(state, width, height)
}

// v0.9 per-format canvas query. Only RGBA8 (0) is honored by Create_Canvas_Format.
Is_Canvas_Format_Supported :: proc(state: rawptr, format: int) -> bool {
	return state != nil && format == 0
}

Unload_Canvas :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	for i := 0; i < len(b.canvases); i += 1 {
		if b.canvases[i].handle == handle {
			if b.canvas_active && b.canvases[i].handle == handle {
				rl.EndTextureMode()
				b.canvas_active = false
			}
			if b.canvas_handle == handle {
				b.canvas_handle = 0
			}
			rl.UnloadRenderTexture(b.canvases[i].value)
			unordered_remove(&b.canvases, i)
			return
		}
	}
}

Set_Canvas :: proc(state: rawptr, handle: u64) -> bool {
	if state == nil { return false }
	b := cast(^Backend)state
	entry, ok := find_canvas(b, handle)
	if !ok || b.canvas_active { return false }
	rl.BeginTextureMode(entry.value)
	b.canvas_active = true
	b.canvas_handle = handle
	b.canvas_switches += 1
	return true
}

Reset_Canvas :: proc(state: rawptr) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	if b.canvas_active {
		rl.EndTextureMode()
		b.canvas_active = false
	}
	b.canvas_handle = 0
}

Draw_Canvas :: proc(state: rawptr, handle: u64, x, y, scale_x, scale_y: f32, r, g, b, a: u8) {
	if state == nil {
		return
	}
	backend := cast(^Backend)state
	backend.draw_calls += 1
	entry, ok := find_canvas(backend, handle)
	if !ok {
		return
	}
	position := transform_point(backend.transform, to_vec2(x, y))
	size := transform_size(backend.transform, to_vec2(f32(entry.width)*scale_x, f32(entry.height)*scale_y))
	source := to_rect(0, 0, f32(entry.width), -f32(entry.height))
	rl.DrawTexturePro(entry.value.texture, source, to_rect(position.x, position.y, size.x, size.y), rl.Vector2{}, backend.transform.rotation, to_color(r, g, b, a))
}

find_shader :: proc(b: ^Backend, handle: u64) -> (^Shader_Entry, bool) {
	for i := 0; i < len(b.shaders); i += 1 {
		if b.shaders[i].handle == handle {
			return &b.shaders[i], true
		}
	}
	return nil, false
}

Load_Shader :: proc(state: rawptr, vertex_path, fragment_path: string) -> (u64, bool) {
	if state == nil {
		return 0, false
	}
	b := cast(^Backend)state
	vertex_c, vertex_err := strings.clone_to_cstring(vertex_path, context.temp_allocator)
	fragment_c, fragment_err := strings.clone_to_cstring(fragment_path, context.temp_allocator)
	if vertex_err != nil || fragment_err != nil {
		return 0, false
	}
	shader := rl.LoadShader(vertex_c, fragment_c)
	if !rl.IsShaderValid(shader) {
		return 0, false
	}
	handle := b.next_handle
	b.next_handle += 1
	append(&b.shaders, Shader_Entry{handle, shader})
	return handle, true
}

Unload_Shader :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	for i := 0; i < len(b.shaders); i += 1 {
		if b.shaders[i].handle == handle {
			if b.shader_active == handle {
				rl.EndShaderMode()
				b.shader_active = 0
			}
			rl.UnloadShader(b.shaders[i].value)
			unordered_remove(&b.shaders, i)
			return
		}
	}
}

Begin_Shader :: proc(state: rawptr, handle: u64) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Backend)state
	entry, ok := find_shader(b, handle)
	if !ok || b.shader_active != 0 {
		return false
	}
	rl.BeginShaderMode(entry.value)
	b.shader_active = handle
	return true
}

End_Shader :: proc(state: rawptr) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	if b.shader_active != 0 {
		rl.EndShaderMode()
		b.shader_active = 0
	}
}

Set_Shader_Float :: proc(state: rawptr, handle: u64, name: string, value: f32) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	entry, ok := find_shader(b, handle)
	if !ok {
		return
	}
	c_name, c_err := strings.clone_to_cstring(name, context.temp_allocator)
	if c_err != nil {
		return
	}
	location := rl.GetShaderLocation(entry.value, c_name)
	if location >= 0 {
		actual_value := value
		rl.SetShaderValue(entry.value, location, &actual_value, .FLOAT)
	}
}

Set_Shader_Vec2 :: proc(state: rawptr, handle: u64, name: string, x, y: f32) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	entry, ok := find_shader(b, handle)
	if !ok {
		return
	}
	c_name, c_err := strings.clone_to_cstring(name, context.temp_allocator)
	if c_err != nil {
		return
	}
	location := rl.GetShaderLocation(entry.value, c_name)
	value := rl.Vector2{x, y}
	if location >= 0 {
		rl.SetShaderValue(entry.value, location, &value, .VEC2)
	}
}

Set_Shader_Vec4 :: proc(state: rawptr, handle: u64, name: string, x, y, z, w: f32) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	entry, ok := find_shader(b, handle)
	if !ok {
		return
	}
	c_name, c_err := strings.clone_to_cstring(name, context.temp_allocator)
	if c_err != nil {
		return
	}
	location := rl.GetShaderLocation(entry.value, c_name)
	value := rl.Vector4{x, y, z, w}
	if location >= 0 {
		rl.SetShaderValue(entry.value, location, &value, .VEC4)
	}
}

Set_Shader_Floats :: proc(state: rawptr, handle: u64, name: string, values: []f32) -> bool {
	if state == nil || len(values) == 0 {
		return false
	}
	b := cast(^Backend)state
	entry, ok := find_shader(b, handle)
	if !ok {
		return false
	}
	c_name, c_err := strings.clone_to_cstring(name, context.temp_allocator)
	if c_err != nil {
		return false
	}
	location := rl.GetShaderLocation(entry.value, c_name)
	if location < 0 {
		return false
	}
	rl.SetShaderValueV(entry.value, location, rawptr(&values[0]), .FLOAT, c.int(len(values)))
	return true
}

Set_Shader_Matrix :: proc(state: rawptr, handle: u64, name: string, value: Shader_Matrix) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Backend)state
	entry, ok := find_shader(b, handle)
	if !ok {
		return false
	}
	c_name, c_err := strings.clone_to_cstring(name, context.temp_allocator)
	if c_err != nil {
		return false
	}
	location := rl.GetShaderLocation(entry.value, c_name)
	if location < 0 {
		return false
	}
	native := value
	rl.SetShaderValueMatrix(entry.value, location, native)
	return true
}

Set_Shader_Texture :: proc(state: rawptr, shader_handle, texture_handle: u64, name: string) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Backend)state
	shader, shader_ok := find_shader(b, shader_handle)
	texture, texture_ok := find_texture(b, texture_handle)
	if !shader_ok || !texture_ok {
		return false
	}
	c_name, c_err := strings.clone_to_cstring(name, context.temp_allocator)
	if c_err != nil {
		return false
	}
	location := rl.GetShaderLocation(shader.value, c_name)
	if location < 0 {
		return false
	}
	rl.SetShaderValueTexture(shader.value, location, texture.value)
	return true
}

Set_Shader_Color :: proc(state: rawptr, handle: u64, name: string, r, g, b, a: u8) {
	if state == nil {
		return
	}
	backend := cast(^Backend)state
	entry, ok := find_shader(backend, handle)
	if !ok {
		return
	}
	c_name, c_err := strings.clone_to_cstring(name, context.temp_allocator)
	if c_err != nil {
		return
	}
	location := rl.GetShaderLocation(entry.value, c_name)
	value := rl.ColorNormalize(to_color(r, g, b, a))
	if location >= 0 {
		rl.SetShaderValue(entry.value, location, &value, .VEC4)
	}
}

identity_transform :: proc() -> Transform_State {
	return Transform_State{matrix_value = rl.Matrix{
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1,
	}, scale = rl.Vector2{1, 1}}
}

transform_from_matrix :: proc(m: rl.Matrix) -> Transform_State {
	sx := f32(math.sqrt(f64(m[0,0]*m[0,0] + m[1,0]*m[1,0])))
	sy := f32(math.sqrt(f64(m[0,1]*m[0,1] + m[1,1]*m[1,1])))
	angle := f32(math.atan2(f64(m[1,0]), f64(m[0,0])))*180/f32(math.PI) if sx > 0.0000001 else 0
	return Transform_State{
		matrix_value = m,
		translation = rl.Vector2{m[0, 3], m[1, 3]},
		scale = rl.Vector2{sx, sy},
		rotation = angle,
	}
}

Push_Transform :: proc(state: rawptr) {
	if state != nil {
		b := cast(^Backend)state
		append(&b.transforms, b.transform)
	}
}

Pop_Transform :: proc(state: rawptr) {
	if state == nil { return }
	b := cast(^Backend)state
	if len(b.transforms) == 0 { return }
	last := len(b.transforms)-1
	b.transform = b.transforms[last]
	pop(&b.transforms)
}

Translate :: proc(state: rawptr, x, y: f32) {
	if state != nil {
		b := cast(^Backend)state
		b.transform = transform_from_matrix(b.transform.matrix_value * rl.Matrix{
			1, 0, 0, x,
			0, 1, 0, y,
			0, 0, 1, 0,
			0, 0, 0, 1,
		})
	}
}

Rotate :: proc(state: rawptr, angle: f32) {
	if state != nil {
		b := cast(^Backend)state
		r := angle*f32(math.PI)/180
		b.transform = transform_from_matrix(b.transform.matrix_value * rl.Matrix{
			f32(math.cos(r)), -f32(math.sin(r)), 0, 0,
			f32(math.sin(r)), f32(math.cos(r)), 0, 0,
			0, 0, 1, 0,
			0, 0, 0, 1,
		})
	}
}

Scale :: proc(state: rawptr, x, y: f32) {
	if state != nil {
		b := cast(^Backend)state
		b.transform = transform_from_matrix(b.transform.matrix_value * rl.Matrix{
			x, 0, 0, 0,
			0, y, 0, 0,
			0, 0, 1, 0,
			0, 0, 0, 1,
		})
	}
}

Reset_Transform :: proc(state: rawptr) {
	if state != nil {
		b := cast(^Backend)state
		b.transform = identity_transform()
	}
}

Replace_Transform :: proc(state: rawptr, value: rl.Matrix) {
	if state != nil {
		b := cast(^Backend)state
		b.transform = transform_from_matrix(value)
	}
}

Transform_Point :: proc(state: rawptr, x, y: f32) -> (out_x, out_y: f32) {
	if state == nil { return x, y }
	p := transform_point((cast(^Backend)state).transform, rl.Vector2{x, y})
	return p.x, p.y
}

Inverse_Transform_Point :: proc(state: rawptr, x, y: f32) -> (out_x, out_y: f32) {
	if state == nil { return x, y }
	m := (cast(^Backend)state).transform.matrix_value
	a, b, c, d := m[0,0], m[0,1], m[1,0], m[1,1]
	det := a*d-b*c
	if math.abs(det) < 0.00000001 { return x, y }
	dx, dy := x-m[0,3], y-m[1,3]
	return (d*dx-b*dy)/det, (a*dy-c*dx)/det
}

transform_point :: proc(transform: Transform_State, point: rl.Vector2) -> rl.Vector2 {
	m := transform.matrix_value
	return rl.Vector2{m[0,0]*point.x+m[0,1]*point.y+m[0,3], m[1,0]*point.x+m[1,1]*point.y+m[1,3]}
}

transform_size :: proc(transform: Transform_State, size: rl.Vector2) -> rl.Vector2 {
	// Retained for rectangle APIs. The absolute axis scale is conservative;
	// arbitrary affine shapes use Draw_Triangles and are exact.
	m := transform.matrix_value
	return rl.Vector2{
		f32(math.sqrt(f64(m[0,0]*m[0,0]+m[1,0]*m[1,0])))*size.x,
		f32(math.sqrt(f64(m[0,1]*m[0,1]+m[1,1]*m[1,1])))*size.y,
	}
}

transform_scalar :: proc(transform: Transform_State, value: f32) -> f32 {
	m := transform.matrix_value
	return value * (f32(math.sqrt(f64(m[0,0]*m[0,0]+m[1,0]*m[1,0]))) + f32(math.sqrt(f64(m[0,1]*m[0,1]+m[1,1]*m[1,1])))) * 0.5
}

Camera_World_To_Screen :: proc(state: rawptr, world_x, world_y, target_x, target_y, offset_x, offset_y, rotation, zoom: f32) -> (x, y: f32) {
	if state == nil {
		return 0, 0
	}
	actual_zoom := zoom
	if actual_zoom <= 0 {
		actual_zoom = 1
	}
	result := rl.GetWorldToScreen2D(to_vec2(world_x, world_y), rl.Camera2D{
		offset = to_vec2(offset_x, offset_y),
		target = to_vec2(target_x, target_y),
		rotation = rotation,
		zoom = actual_zoom,
	})
	return result.x, result.y
}

Camera_Screen_To_World :: proc(state: rawptr, screen_x, screen_y, target_x, target_y, offset_x, offset_y, rotation, zoom: f32) -> (x, y: f32) {
	if state == nil {
		return 0, 0
	}
	actual_zoom := zoom
	if actual_zoom <= 0 {
		actual_zoom = 1
	}
	result := rl.GetScreenToWorld2D(to_vec2(screen_x, screen_y), rl.Camera2D{
		offset = to_vec2(offset_x, offset_y),
		target = to_vec2(target_x, target_y),
		rotation = rotation,
		zoom = actual_zoom,
	})
	return result.x, result.y
}

to_color :: proc(r, g, b, a: u8) -> rl.Color {
	return rl.Color{r, g, b, a}
}

to_vec2 :: proc(x, y: f32) -> rl.Vector2 {
	return rl.Vector2{x, y}
}

to_rect :: proc(x, y, w, h: f32) -> rl.Rectangle {
	return rl.Rectangle{x, y, w, h}
}

Clear :: proc(state: rawptr, r, g, b, a: u8) {
	if state != nil {
		rl.ClearBackground(to_color(r, g, b, a))
	}
}

Draw_Rect :: proc(state: rawptr, x, y, w, h: f32, r, g, b, a: u8) {
	if state != nil {
		backend := cast(^Backend)state
		backend.draw_calls += 1
		position := transform_point(backend.transform, to_vec2(x, y))
		size := transform_size(backend.transform, to_vec2(w, h))
		rl.DrawRectanglePro(to_rect(position.x, position.y, size.x, size.y), rl.Vector2{}, backend.transform.rotation, to_color(r, g, b, a))
	}
}

Draw_Rect_Outline :: proc(state: rawptr, x, y, w, h, thickness: f32, r, g, b, a: u8) {
	if state != nil {
		backend := cast(^Backend)state
		backend.draw_calls += 1
		p0 := transform_point(backend.transform, to_vec2(x, y))
		p1 := transform_point(backend.transform, to_vec2(x+w, y))
		p2 := transform_point(backend.transform, to_vec2(x+w, y+h))
		p3 := transform_point(backend.transform, to_vec2(x, y+h))
		line_thickness := transform_scalar(backend.transform, thickness)
		color := to_color(r, g, b, a)
		rl.DrawLineEx(p0, p1, line_thickness, color)
		rl.DrawLineEx(p1, p2, line_thickness, color)
		rl.DrawLineEx(p2, p3, line_thickness, color)
		rl.DrawLineEx(p3, p0, line_thickness, color)
	}
}

Draw_Circle :: proc(state: rawptr, x, y, radius: f32, r, g, b, a: u8) {
	if state != nil {
		backend := cast(^Backend)state
		backend.draw_calls += 1
		rl.DrawCircleV(transform_point(backend.transform, to_vec2(x, y)), transform_scalar(backend.transform, radius), to_color(r, g, b, a))
	}
}

Draw_Line :: proc(state: rawptr, start_x, start_y, end_x, end_y, thickness: f32, r, g, b, a: u8) {
	if state != nil {
		backend := cast(^Backend)state
		backend.draw_calls += 1
		rl.DrawLineEx(transform_point(backend.transform, to_vec2(start_x, start_y)), transform_point(backend.transform, to_vec2(end_x, end_y)), transform_scalar(backend.transform, thickness), to_color(r, g, b, a))
	}
}

Draw_Text :: proc(state: rawptr, text: string, x, y: f32, size: int, r, g, b, a: u8) {
	if state == nil {
		return
	}
	backend := cast(^Backend)state
	backend.draw_calls += 1
	c_text, c_err := strings.clone_to_cstring(text, context.temp_allocator)
	if c_err == nil {
		position := transform_point(backend.transform, to_vec2(x, y))
		font_size := int(transform_scalar(backend.transform, f32(size)))
		if font_size < 1 {
			font_size = 1
		}
		rl.DrawTextPro(rl.GetFontDefault(), c_text, position, rl.Vector2{}, backend.transform.rotation, f32(font_size), 0, to_color(r, g, b, a))
	}
}

Measure_Text :: proc(state: rawptr, text: string, size: int) -> int {
	if state == nil {
		return 0
	}
	c_text, c_err := strings.clone_to_cstring(text, context.temp_allocator)
	if c_err != nil {
		return 0
	}
	return int(rl.MeasureText(c_text, c.int(size)))
}

Load_Font :: proc(state: rawptr, path: string) -> (u64, bool) {
	if state == nil {
		return 0, false
	}
	b := cast(^Backend)state
	c_path, c_err := strings.clone_to_cstring(path, context.temp_allocator)
	if c_err != nil {
		return 0, false
	}
	font := rl.LoadFont(c_path)
	if !rl.IsFontValid(font) {
		return 0, false
	}
	handle := b.next_handle
	b.next_handle += 1
	append(&b.fonts, Font_Entry{handle = handle, value = font, line_height = 1})
	return handle, true
}

find_font :: proc(b: ^Backend, handle: u64) -> (^Font_Entry, bool) {
	for i := 0; i < len(b.fonts); i += 1 {
		if b.fonts[i].handle == handle {
			return &b.fonts[i], true
		}
	}
	return nil, false
}

Unload_Font :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	for i := 0; i < len(b.fonts); i += 1 {
		if b.fonts[i].handle == handle {
			rl.UnloadFont(b.fonts[i].value)
			remove_font_cache(b, handle)
			unordered_remove(&b.fonts, i)
			return
		}
	}
}

Draw_Text_Font :: proc(state: rawptr, handle: u64, text: string, x, y, size, spacing: f32, r, g, b, a: u8) {
	if state == nil {
		return
	}
	entry, ok := find_font(cast(^Backend)state, handle)
	if !ok {
		return
	}
	c_text, c_err := strings.clone_to_cstring(text, context.temp_allocator)
	if c_err == nil {
		backend := cast(^Backend)state
		position := transform_point(backend.transform, to_vec2(x, y))
		rl.DrawTextPro(entry.value, c_text, position, rl.Vector2{}, backend.transform.rotation, transform_scalar(backend.transform, size), spacing, to_color(r, g, b, a))
	}
}

Measure_Text_Font :: proc(state: rawptr, handle: u64, text: string, size, spacing: f32) -> (x, y: f32) {
	if state == nil {
		return 0, 0
	}
	entry, ok := find_font(cast(^Backend)state, handle)
	if !ok {
		return 0, 0
	}
	c_text, c_err := strings.clone_to_cstring(text, context.temp_allocator)
	if c_err != nil {
		return 0, 0
	}
	result := rl.MeasureTextEx(entry.value, c_text, size, spacing)
	return result.x, result.y
}

Create_Text :: proc(state: rawptr, font_handle: u64, value: string, size, spacing: f32) -> (u64, bool) {
	if state == nil || value == "" || size <= 0 {
		return 0, false
	}
	b := cast(^Backend)state
	if font_handle != 0 {
		if _, ok := find_font(b, font_handle); !ok {
			return 0, false
		}
	}
	owned, err := strings.clone(value)
	if err != nil {
		return 0, false
	}
	handle := b.next_handle
	b.next_handle += 1
	append(&b.texts, Text_Entry{handle = handle, font_handle = font_handle, value = owned, size = size, spacing = spacing})
	return handle, true
}

find_text :: proc(b: ^Backend, handle: u64) -> (^Text_Entry, bool) {
	if b == nil || handle == 0 {
		return nil, false
	}
	for &entry in b.texts {
		if entry.handle == handle {
			return &entry, true
		}
	}
	return nil, false
}

Set_Text :: proc(state: rawptr, handle: u64, value: string) -> bool {
	if state == nil || value == "" {
		return false
	}
	entry, ok := find_text(cast(^Backend)state, handle)
	if !ok {
		return false
	}
	owned, err := strings.clone(value)
	if err != nil {
		return false
	}
	if len(entry.value) > 0 {
		delete(entry.value)
	}
	entry.value = owned
	return true
}

Draw_Text_Object :: proc(state: rawptr, handle: u64, x, y: f32, r, g, b, a: u8) {
	if state == nil {
		return
	}
	backend := cast(^Backend)state
	entry, ok := find_text(backend, handle)
	if !ok {
		return
	}
	position := rl.Vector2{x, y}
	color := to_color(r, g, b, a)
	// v0.10 per-text line advance: when the text font's line-height
	// multiplier differs from 1.0, multiline text is drawn line-by-line so
	// each advance equals size * multiplier (LOVE Font:setLineHeight). The
	// default path keeps raylib's native DrawTextPro advance.
	if text_line_height(backend, entry) != 1 && strings.contains(entry.value, "\n") {
		draw_text_object_multiline(backend, entry, position, color)
		return
	}
	c_text, c_err := strings.clone_to_cstring(entry.value, context.temp_allocator)
	if c_err != nil {
		return
	}
	if entry.font_handle == 0 {
		rl.DrawTextPro(rl.GetFontDefault(), c_text, position, rl.Vector2{}, backend.transform.rotation, entry.size, entry.spacing, color)
		return
	}
	font, font_ok := find_font(backend, entry.font_handle)
	if font_ok {
		rl.DrawTextPro(font.value, c_text, position, rl.Vector2{}, backend.transform.rotation, entry.size, entry.spacing, color)
	}
}

Unload_Text :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	for i := 0; i < len(b.texts); i += 1 {
		if b.texts[i].handle == handle {
			if len(b.texts[i].value) > 0 {
				delete(b.texts[i].value)
			}
			unordered_remove(&b.texts, i)
			return
		}
	}
}

find_texture :: proc(b: ^Backend, handle: u64) -> (^Texture_Entry, bool) {
	for i := 0; i < len(b.textures); i += 1 {
		if b.textures[i].handle == handle {
			return &b.textures[i], true
		}
	}
	return nil, false
}

Load_Texture :: proc(state: rawptr, path: string) -> (u64, bool) {
	if state == nil {
		return 0, false
	}
	b := cast(^Backend)state
	c_path, c_err := strings.clone_to_cstring(path, context.temp_allocator)
	if c_err != nil {
		return 0, false
	}
	texture := rl.LoadTexture(c_path)
	if !rl.IsTextureValid(texture) {
		return 0, false
	}
	handle := b.next_handle
	b.next_handle += 1
	append(&b.textures, Texture_Entry{handle, texture})
	return handle, true
}

Generate_Texture :: proc(state: rawptr, width, height: int, r, g, b, a: u8) -> (u64, bool) {
	if state == nil {
		return 0, false
	}
	backend := cast(^Backend)state
	image := rl.GenImageColor(c.int(width), c.int(height), to_color(r, g, b, a))
	texture := rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	if !rl.IsTextureValid(texture) {
		return 0, false
	}
	handle := backend.next_handle
	backend.next_handle += 1
	append(&backend.textures, Texture_Entry{handle, texture})
	return handle, true
}

Unload_Texture :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	for i := 0; i < len(b.textures); i += 1 {
		if b.textures[i].handle == handle {
			rl.UnloadTexture(b.textures[i].value)
			remove_texture_cache(b, handle)
			unordered_remove(&b.textures, i)
			return
		}
	}
}

Texture_Size :: proc(state: rawptr, handle: u64) -> (width, height: int) {
	if state == nil {
		return 0, 0
	}
	entry, ok := find_texture(cast(^Backend)state, handle)
	if !ok {
		return 0, 0
	}
	return int(entry.value.width), int(entry.value.height)
}

Draw_Texture :: proc(state: rawptr, handle: u64, x, y: f32, r, g, b, a: u8) {
	if state == nil {
		return
	}
	backend := cast(^Backend)state
	backend.draw_calls += 1
	entry, ok := find_texture(cast(^Backend)state, handle)
	if ok {
		position := transform_point(backend.transform, to_vec2(x, y))
		size := transform_size(backend.transform, to_vec2(f32(entry.value.width), f32(entry.value.height)))
		rl.DrawTexturePro(entry.value, to_rect(0, 0, f32(entry.value.width), f32(entry.value.height)), to_rect(position.x, position.y, size.x, size.y), rl.Vector2{}, backend.transform.rotation, to_color(r, g, b, a))
	}
}

Draw_Texture_Ex :: proc(state: rawptr, handle: u64, x, y, rotation, scale: f32, r, g, b, a: u8) {
	if state == nil {
		return
	}
	backend := cast(^Backend)state
	backend.draw_calls += 1
	entry, ok := find_texture(cast(^Backend)state, handle)
	if ok {
		position := transform_point(backend.transform, to_vec2(x, y))
		combined_scale := transform_scalar(backend.transform, scale)
		rl.DrawTextureEx(entry.value, position, rotation + backend.transform.rotation, combined_scale, to_color(r, g, b, a))
	}
}

Draw_Texture_Pro :: proc(state: rawptr, handle: u64, sx, sy, sw, sh, dx, dy, dw, dh, ox, oy, rotation: f32, r, g, b, a: u8) {
	if state == nil {
		return
	}
	backend := cast(^Backend)state
	backend.draw_calls += 1
	entry, ok := find_texture(cast(^Backend)state, handle)
	if ok {
		position := transform_point(backend.transform, to_vec2(dx, dy))
		size := transform_size(backend.transform, to_vec2(dw, dh))
		origin := transform_size(backend.transform, to_vec2(ox, oy))
		rl.DrawTexturePro(entry.value, to_rect(sx, sy, sw, sh), to_rect(position.x, position.y, size.x, size.y), origin, rotation + backend.transform.rotation, to_color(r, g, b, a))
	}
}

Set_Texture_Filter :: proc(state: rawptr, handle: u64, filter: int) -> bool {
	if state == nil {
		return false
	}
	entry, ok := find_texture(cast(^Backend)state, handle)
	if !ok {
		return false
	}
	native := rl.TextureFilter.POINT
	switch filter {
	case 1:
		native = .BILINEAR
	case 2:
		native = .ANISOTROPIC_16X
	}
	rl.SetTextureFilter(entry.value, native)
	return true
}

Set_Texture_Wrap :: proc(state: rawptr, handle: u64, wrap: int) -> bool {
	if state == nil {
		return false
	}
	entry, ok := find_texture(cast(^Backend)state, handle)
	if !ok {
		return false
	}
	native := rl.TextureWrap.REPEAT
	switch wrap {
	case 1:
		native = .CLAMP
	case 2:
		native = .MIRROR_REPEAT
	case 3:
		native = .MIRROR_CLAMP
	}
	rl.SetTextureWrap(entry.value, native)
	return true
}

Set_Line_Width :: proc(state: rawptr, width: f32) -> bool {
	if state == nil || width <= 0 {
		return false
	}
	b := cast(^Backend)state
	b.line_width = width
	rlgl.SetLineWidth(width)
	return true
}

Get_Line_Width :: proc(state: rawptr) -> f32 {
	if state == nil { return 0 }
	return (cast(^Backend)state).line_width
}

Get_Point_Size :: proc(state: rawptr) -> f32 {
	if state == nil { return 0 }
	return (cast(^Backend)state).point_size
}

Draw_Triangle :: proc(state: rawptr, x0, y0, x1, y1, x2, y2: f32, r, g, b, a: u8) {
	if state == nil { return }
	backend := cast(^Backend)state
	backend.draw_calls += 1
	color := to_color(r, g, b, a)
	rl.DrawTriangle(
		transform_point(backend.transform, rl.Vector2{x0, y0}),
		transform_point(backend.transform, rl.Vector2{x1, y1}),
		transform_point(backend.transform, rl.Vector2{x2, y2}),
		color,
	)
}

Graphics_Stats :: proc(state: rawptr) -> (stats: struct {Draw_Calls, Texture_Memory, Canvas_Count, Mesh_Count: int}) {
	if state == nil { return }
	b := cast(^Backend)state
	stats.Draw_Calls = b.draw_calls
	stats.Canvas_Count = len(b.canvases)
	stats.Mesh_Count = len(b.meshes)
	for texture in b.textures {
		stats.Texture_Memory += int(texture.value.width) * int(texture.value.height) * 4
	}
	return
}

Renderer_Info :: proc(state: rawptr) -> (name, version: string, gpu_mesh, shader: bool) {
	if state == nil {
		return "", "", false, false
	}
	b := cast(^Backend)state
	return "raylib", "private", b.gpu_mesh_supported, true
}

// --- v0.10 text/canvas/shader completion (LOVE Font/Text/Canvas/Shader parity) ---
//
// Font metrics note: the vendored raylib Font exposes baseSize, glyphCount,
// glyphPadding, the atlas texture, glyph rectangles and per-glyph info — but
// no TrueType ascent/descent/line-gap tables. The public layer therefore
// reports proportional metrics (ascent 0.8em, descent 0.2em, baseline at the
// ascent, line advance size * multiplier) validated against the entries
// below, and documents the approximation. Only baseSize is read here.

// Font_Base_Size returns the raster base size, or 0 for unknown handles.
Font_Base_Size :: proc(state: rawptr, handle: u64) -> int {
	if state == nil || handle == 0 {
		return 0
	}
	entry, ok := find_font(cast(^Backend)state, handle)
	if !ok {
		return 0
	}
	return int(entry.value.baseSize)
}

// Font_Line_Height_Multiplier returns the stored LOVE setLineHeight value
// (1.0 default; stored values <= 0 read back as 1.0). Handle 0 is the
// default font, whose multiplier lives on the Backend.
Font_Line_Height_Multiplier :: proc(state: rawptr, handle: u64) -> f32 {
	if state == nil {
		return 0
	}
	b := cast(^Backend)state
	stored := b.default_font_line_height
	if handle != 0 {
		entry, ok := find_font(b, handle)
		if !ok {
			return 0
		}
		stored = entry.line_height
	}
	if stored <= 0 {
		return 1
	}
	return stored
}

Font_Set_Line_Height_Multiplier :: proc(state: rawptr, handle: u64, multiplier: f32) -> bool {
	if state == nil || multiplier <= 0 {
		return false
	}
	b := cast(^Backend)state
	if handle == 0 {
		b.default_font_line_height = multiplier
		return true
	}
	entry, ok := find_font(b, handle)
	if !ok {
		return false
	}
	entry.line_height = multiplier
	return true
}

// Font_Has_Codepoint reports whether codepoint has a glyph slot in the font.
// Best-effort: it scans the loaded glyph table for an exact codepoint match.
// Ligature/substitution shaping (a font rendering a codepoint only via
// fallback or composition) is not detected — documented approximation.
Font_Has_Codepoint :: proc(state: rawptr, handle: u64, codepoint: rune) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Backend)state
	if handle == 0 {
		default_font := rl.GetFontDefault()
		return glyph_table_contains(default_font, codepoint)
	}
	entry, ok := find_font(b, handle)
	if !ok {
		return false
	}
	return glyph_table_contains(entry.value, codepoint)
}

glyph_table_contains :: proc(font: rl.Font, codepoint: rune) -> bool {
	if font.glyphCount <= 0 || font.glyphs == nil {
		return false
	}
	for glyph in font.glyphs[:font.glyphCount] {
		if glyph.value == codepoint {
			return true
		}
	}
	return false
}

// Text_Append appends suffix to the stored string (LOVE Text:add subset:
// plain-text append; transforms and colored runs are out of scope).
Text_Append :: proc(state: rawptr, handle: u64, suffix: string) -> bool {
	if state == nil {
		return false
	}
	entry, ok := find_text(cast(^Backend)state, handle)
	if !ok {
		return false
	}
	if len(suffix) == 0 {
		return true
	}
	joined := strings.concatenate({entry.value, suffix})
	if len(entry.value) > 0 {
		delete(entry.value)
	}
	entry.value = joined
	return true
}

// Text_Clear resets the stored string to empty (Set_Text rejects empty
// input, so clearing needs this dedicated path).
Text_Clear :: proc(state: rawptr, handle: u64) -> bool {
	if state == nil {
		return false
	}
	entry, ok := find_text(cast(^Backend)state, handle)
	if !ok {
		return false
	}
	if len(entry.value) > 0 {
		delete(entry.value)
	}
	entry.value = ""
	return true
}

Text_Font_Handle :: proc(state: rawptr, handle: u64) -> (u64, bool) {
	if state == nil {
		return 0, false
	}
	entry, ok := find_text(cast(^Backend)state, handle)
	if !ok {
		return 0, false
	}
	return entry.font_handle, true
}

// Text_Set_Font_Handle overrides the per-text font (LOVE Text:setFont).
// Font 0 selects the default font; any other handle must exist.
Text_Set_Font_Handle :: proc(state: rawptr, handle, font_handle: u64) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Backend)state
	entry, ok := find_text(b, handle)
	if !ok {
		return false
	}
	if font_handle != 0 {
		if _, font_ok := find_font(b, font_handle); !font_ok {
			return false
		}
	}
	entry.font_handle = font_handle
	return true
}

// text_line_height resolves the advance multiplier for a text entry.
text_line_height :: proc(b: ^Backend, entry: ^Text_Entry) -> f32 {
	if b == nil || entry == nil {
		return 1
	}
	if entry.font_handle == 0 {
		if b.default_font_line_height <= 0 {
			return 1
		}
		return b.default_font_line_height
	}
	font, ok := find_font(b, entry.font_handle)
	if !ok || font.line_height <= 0 {
		return 1
	}
	return font.line_height
}

// draw_text_object_multiline draws each \n-separated line with a
// size * multiplier advance (LOVE setLineHeight effect on Text draw).
draw_text_object_multiline :: proc(b: ^Backend, entry: ^Text_Entry, position: rl.Vector2, color: rl.Color) {
	multiplier := text_line_height(b, entry)
	advance := entry.size * multiplier
	font := rl.GetFontDefault()
	use_default := entry.font_handle == 0
	if !use_default {
		named, ok := find_font(b, entry.font_handle)
		if !ok {
			return
		}
		font = named.value
	}
	line_y := position.y
	start := 0
	for i := 0; i <= len(entry.value); i += 1 {
		if i == len(entry.value) || entry.value[i] == '\n' {
			line := entry.value[start:i]
			c_line, c_err := strings.clone_to_cstring(line, context.temp_allocator)
			if c_err == nil {
				rl.DrawTextPro(font, c_line, rl.Vector2{position.x, line_y}, rl.Vector2{}, b.transform.rotation, entry.size, entry.spacing, color)
			}
			line_y += advance
			start = i+1
		}
	}
}

// Canvas_MSAA_Samples returns the stored MSAA sample count (always 0:
// LoadRenderTexture canvases have no per-canvas MSAA; see Create_Canvas).
Canvas_MSAA_Samples :: proc(state: rawptr, handle: u64) -> int {
	if state == nil {
		return 0
	}
	entry, ok := find_canvas(cast(^Backend)state, handle)
	if !ok {
		return 0
	}
	return entry.msaa
}

// Canvas_Exists reports whether handle names a live canvas.
Canvas_Exists :: proc(state: rawptr, handle: u64) -> bool {
	if state == nil || handle == 0 {
		return false
	}
	_, ok := find_canvas(cast(^Backend)state, handle)
	return ok
}

// Canvas_To_RGBA reads a canvas back into CPU RGBA8 pixels (LOVE
// Canvas:newImageData subset: full-canvas capture, no slice/mipmap args).
// Rows are flipped vertically so the image matches Draw_Canvas orientation
// (canvas textures are stored upside-down in GL; Draw_Canvas compensates
// with a negative-height source rect).
Canvas_To_RGBA :: proc(state: rawptr, handle: u64) -> (pixels: [dynamic]u8, width, height: int, ok: bool) {
	if state == nil {
		return nil, 0, 0, false
	}
	entry, found := find_canvas(cast(^Backend)state, handle)
	if !found {
		return nil, 0, 0, false
	}
	image := rl.LoadImageFromTexture(entry.value.texture)
	if !rl.IsImageValid(image) {
		return nil, 0, 0, false
	}
	defer rl.UnloadImage(image)
	rl.ImageFormat(&image, .UNCOMPRESSED_R8G8B8A8)
	width = int(image.width)
	height = int(image.height)
	if width <= 0 || height <= 0 || image.data == nil {
		return nil, 0, 0, false
	}
	size := int(rl.GetPixelDataSize(image.width, image.height, .UNCOMPRESSED_R8G8B8A8))
	if size != width*height*4 {
		return nil, 0, 0, false
	}
	raw := ([^]u8)(image.data)[:size]
	pixels = make([dynamic]u8, size)
	stride := width*4
	for y := 0; y < height; y += 1 {
		src := (height-1-y)*stride
		copy(pixels[y*stride:(y+1)*stride], raw[src:src+stride])
	}
	return pixels, width, height, true
}

// Shader_Has_Uniform reports whether name is an active uniform (LOVE
// Shader:hasUniform). Optimized-out uniforms report false, matching LOVE:
// drivers drop uniforms that do not affect the output.
Shader_Has_Uniform :: proc(state: rawptr, handle: u64, name: string) -> bool {
	if state == nil || len(name) == 0 {
		return false
	}
	b := cast(^Backend)state
	entry, ok := find_shader(b, handle)
	if !ok {
		return false
	}
	c_name, c_err := strings.clone_to_cstring(name, context.temp_allocator)
	if c_err != nil {
		return false
	}
	return rl.GetShaderLocation(entry.value, c_name) >= 0
}

// --- v0.10 wave 5 niche GPU + mesh/video completion queries ---
//
// Active_Canvas_Handle names the canvas Set_Canvas targeted (second return
// false when rendering to screen). Active_Shader_Handle does the same for
// Begin_Shader. Transform_Stack_Depth is len(transforms): the Push/Pop
// nesting depth. Texture_Exists / Shader_Exists validate handles for the
// readability/validation parity queries without exposing entries.

// Active_Canvas_Handle returns the targeted canvas handle, if any.
Active_Canvas_Handle :: proc(state: rawptr) -> (u64, bool) {
	if state == nil {
		return 0, false
	}
	b := cast(^Backend)state
	if !b.canvas_active || b.canvas_handle == 0 {
		return 0, false
	}
	return b.canvas_handle, true
}

// Active_Shader_Handle returns the active shader handle, if any.
Active_Shader_Handle :: proc(state: rawptr) -> (u64, bool) {
	if state == nil {
		return 0, false
	}
	b := cast(^Backend)state
	if b.shader_active == 0 {
		return 0, false
	}
	return b.shader_active, true
}

// Transform_Stack_Depth returns the Push_Transform nesting depth.
Transform_Stack_Depth :: proc(state: rawptr) -> int {
	if state == nil {
		return 0
	}
	return len((cast(^Backend)state).transforms)
}

// Texture_Exists reports whether handle names a live texture.
Texture_Exists :: proc(state: rawptr, handle: u64) -> bool {
	if state == nil || handle == 0 {
		return false
	}
	_, ok := find_texture(cast(^Backend)state, handle)
	return ok
}

// Texture_Mipmaps reports the stored mipmap level count (raylib textures
// carry their count; the backend never generates mipmaps, so this is 1 for
// every texture it creates). Zero for unknown handles.
Texture_Mipmaps :: proc(state: rawptr, handle: u64) -> int {
	if state == nil {
		return 0
	}
	entry, ok := find_texture(cast(^Backend)state, handle)
	if !ok {
		return 0
	}
	return int(entry.value.mipmaps)
}

// Shader_Exists reports whether handle names a live shader.
Shader_Exists :: proc(state: rawptr, handle: u64) -> bool {
	if state == nil || handle == 0 {
		return false
	}
	_, ok := find_shader(cast(^Backend)state, handle)
	return ok
}
