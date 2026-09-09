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
}

Particle_Config_Internal :: struct {
	max_particles: int,
	lifetime_min, lifetime_max: f32,
	emission_rate: f32,
	gravity: rl.Vector2,
	start_size, end_size: f32,
	start_color, end_color: rl.Color,
}

Particle_State :: struct {
	position, velocity: rl.Vector2,
	life, lifetime: f32,
	rotation, angular_velocity: f32,
	scale: f32,
}

Particle_System_Entry :: struct {
	handle: u64,
	texture_handle: u64,
	config: Particle_Config_Internal,
	particles: [dynamic]Particle_State,
	emission_remainder: f32,
	seed: u32,
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
}

Create :: proc(title: string, width, height, target_fps: int, resizable, vsync: bool) -> (rawptr, bool) {
	b := new(Backend)
	b.next_handle = 1
	b.next_asset_id = 1
	b.transform = Transform_State{scale = rl.Vector2{1, 1}}
	b.point_size = 2

	flags := rl.ConfigFlags{}
	if resizable {
		flags += {.WINDOW_RESIZABLE}
	}
	if vsync {
		flags += {.VSYNC_HINT}
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
		delete(entry.value)
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
		if b.camera_active {
			rl.EndMode2D()
			b.camera_active = false
		}
		b.transform = Transform_State{scale = rl.Vector2{1, 1}}
		clear(&b.transforms)
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
	append(&b.canvases, Canvas_Entry{handle, canvas, width, height})
	return handle, true
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
			rl.UnloadRenderTexture(b.canvases[i].value)
			unordered_remove(&b.canvases, i)
			return
		}
	}
}

Set_Canvas :: proc(state: rawptr, handle: u64) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Backend)state
	entry, ok := find_canvas(b, handle)
	if !ok || b.canvas_active {
		return false
	}
	rl.BeginTextureMode(entry.value)
	b.canvas_active = true
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
}

Draw_Canvas :: proc(state: rawptr, handle: u64, x, y, scale_x, scale_y: f32, r, g, b, a: u8) {
	if state == nil {
		return
	}
	backend := cast(^Backend)state
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

Push_Transform :: proc(state: rawptr) {
	if state != nil {
		b := cast(^Backend)state
		append(&b.transforms, b.transform)
	}
}

Pop_Transform :: proc(state: rawptr) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	if len(b.transforms) == 0 {
		return
	}
	last := len(b.transforms) - 1
	b.transform = b.transforms[last]
	unordered_remove(&b.transforms, last)
}

Translate :: proc(state: rawptr, x, y: f32) {
	if state != nil {
		b := cast(^Backend)state
		b.transform.translation.x += x
		b.transform.translation.y += y
	}
}

Rotate :: proc(state: rawptr, angle: f32) {
	if state != nil {
		b := cast(^Backend)state
		b.transform.rotation += angle
	}
}

Scale :: proc(state: rawptr, x, y: f32) {
	if state != nil {
		b := cast(^Backend)state
		b.transform.scale.x *= x
		b.transform.scale.y *= y
	}
}

Reset_Transform :: proc(state: rawptr) {
	if state != nil {
		b := cast(^Backend)state
		b.transform = Transform_State{scale = rl.Vector2{1, 1}}
	}
}

transform_point :: proc(transform: Transform_State, point: rl.Vector2) -> rl.Vector2 {
	x := point.x * transform.scale.x
	y := point.y * transform.scale.y
	radians := transform.rotation * f32(math.PI) / 180
	cosine := math.cos(radians)
	sine := math.sin(radians)
	return rl.Vector2{
		x * cosine - y * sine + transform.translation.x,
		x * sine + y * cosine + transform.translation.y,
	}
}

transform_size :: proc(transform: Transform_State, size: rl.Vector2) -> rl.Vector2 {
	return rl.Vector2{size.x * transform.scale.x, size.y * transform.scale.y}
}

transform_scalar :: proc(transform: Transform_State, value: f32) -> f32 {
	return value * (math.abs(transform.scale.x) + math.abs(transform.scale.y)) * 0.5
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
		position := transform_point(backend.transform, to_vec2(x, y))
		size := transform_size(backend.transform, to_vec2(w, h))
		rl.DrawRectanglePro(to_rect(position.x, position.y, size.x, size.y), rl.Vector2{}, backend.transform.rotation, to_color(r, g, b, a))
	}
}

Draw_Rect_Outline :: proc(state: rawptr, x, y, w, h, thickness: f32, r, g, b, a: u8) {
	if state != nil {
		backend := cast(^Backend)state
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
		rl.DrawCircleV(transform_point(backend.transform, to_vec2(x, y)), transform_scalar(backend.transform, radius), to_color(r, g, b, a))
	}
}

Draw_Line :: proc(state: rawptr, start_x, start_y, end_x, end_y, thickness: f32, r, g, b, a: u8) {
	if state != nil {
		backend := cast(^Backend)state
		rl.DrawLineEx(transform_point(backend.transform, to_vec2(start_x, start_y)), transform_point(backend.transform, to_vec2(end_x, end_y)), transform_scalar(backend.transform, thickness), to_color(r, g, b, a))
	}
}

Draw_Text :: proc(state: rawptr, text: string, x, y: f32, size: int, r, g, b, a: u8) {
	if state == nil {
		return
	}
	c_text, c_err := strings.clone_to_cstring(text, context.temp_allocator)
	if c_err == nil {
		backend := cast(^Backend)state
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
	append(&b.fonts, Font_Entry{handle, font})
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
	delete(entry.value)
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
			delete(b.texts[i].value)
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
	entry, ok := find_texture(cast(^Backend)state, handle)
	if ok {
		backend := cast(^Backend)state
		position := transform_point(backend.transform, to_vec2(x, y))
		size := transform_size(backend.transform, to_vec2(f32(entry.value.width), f32(entry.value.height)))
		rl.DrawTexturePro(entry.value, to_rect(0, 0, f32(entry.value.width), f32(entry.value.height)), to_rect(position.x, position.y, size.x, size.y), rl.Vector2{}, backend.transform.rotation, to_color(r, g, b, a))
	}
}

Draw_Texture_Ex :: proc(state: rawptr, handle: u64, x, y, rotation, scale: f32, r, g, b, a: u8) {
	if state == nil {
		return
	}
	entry, ok := find_texture(cast(^Backend)state, handle)
	if ok {
		backend := cast(^Backend)state
		position := transform_point(backend.transform, to_vec2(x, y))
		combined_scale := transform_scalar(backend.transform, scale)
		rl.DrawTextureEx(entry.value, position, rotation + backend.transform.rotation, combined_scale, to_color(r, g, b, a))
	}
}

Draw_Texture_Pro :: proc(state: rawptr, handle: u64, sx, sy, sw, sh, dx, dy, dw, dh, ox, oy, rotation: f32, r, g, b, a: u8) {
	if state == nil {
		return
	}
	entry, ok := find_texture(cast(^Backend)state, handle)
	if ok {
		backend := cast(^Backend)state
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
	rlgl.SetLineWidth(width)
	return true
}

Renderer_Info :: proc(state: rawptr) -> (name, version: string, gpu_mesh, shader: bool) {
	if state == nil {
		return "", "", false, false
	}
	b := cast(^Backend)state
	return "raylib", "private", b.gpu_mesh_supported, true
}
