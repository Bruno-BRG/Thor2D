package thor2d

Vec2 :: struct {
	X, Y: f32,
}

Vec4 :: struct {
	X, Y, Z, W: f32,
}

Matrix_4 :: #row_major matrix[4, 4]f32

Rect :: struct {
	X, Y, W, H: f32,
}

Color :: struct {
	R, G, B, A: u8,
}

RGB :: proc(r, g, b: u8) -> Color {
	return Color{r, g, b, 255}
}

RGBA :: proc(r, g, b, a: u8) -> Color {
	return Color{r, g, b, a}
}

White :: Color{255, 255, 255, 255}
Black :: Color{0, 0, 0, 255}
Red   :: Color{230, 41, 55, 255}
Green :: Color{0, 228, 48, 255}
Blue  :: Color{0, 121, 241, 255}
Gray  :: Color{130, 130, 130, 255}

Key :: enum int {
	Unknown = 0,
	Space = 32,
	Apostrophe = 39,
	Comma = 44,
	Minus = 45,
	Period = 46,
	Slash = 47,
	Zero = 48, One, Two, Three, Four, Five, Six, Seven, Eight, Nine,
	Semicolon = 59,
	Equal = 61,
	A = 65, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
	LeftBracket = 91,
	Backslash = 92,
	RightBracket = 93,
	Grave = 96,
	Escape = 256,
	Enter, Tab, Backspace, Insert, Delete,
	Right, Left, Down, Up, PageUp, PageDown, Home, End,
	CapsLock = 280, ScrollLock, NumLock, PrintScreen, Pause,
	F1 = 290, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
	LeftShift = 340, LeftControl, LeftAlt, LeftSuper,
	RightShift, RightControl, RightAlt, RightSuper, Menu,
}

Mouse_Button :: enum int {
	Left,
	Right,
	Middle,
	Side,
	Extra,
	Forward,
	Back,
}

Texture :: struct {
	handle: u64,
}

Sound :: struct {
	handle: u64,
}

Music :: struct {
	handle: u64,
}

Audio_Source :: struct {
	handle: u64,
	Kind: Audio_Source_Kind,
}

Audio_Source_Kind :: enum {
	Static,
	Stream,
	Queue,
}

Audio_Source_State :: enum {
	Stopped,
	Playing,
	Paused,
}

Audio_Device :: struct {
	handle: u64,
}

Recording_Device :: struct {
	handle: u64,
}

Audio_Distance_Model :: enum {
	None,
	Inverse,
	Inverse_Clamped,
	Linear,
	Linear_Clamped,
	Exponential,
	Exponential_Clamped,
}

Audio_Positioning :: enum {
	Absolute,
	Relative,
}

Audio_Effect_Kind :: enum {
	Volume,
	Delay,
	Low_Pass,
	High_Pass,
	Band_Pass,
	Reverb,
}

Audio_Filter :: struct {
	Enabled: bool,
	Kind: Audio_Effect_Kind,
	Cutoff: f32,
	Q: f32,
}

Audio_Device_Info :: struct {
	Handle: u64,
	Id: string,
	Name: string,
	Playback: bool,
	Capture: bool,
	Default: bool,
}

Audio_Capabilities :: struct {
	Playback: bool,
	Capture: bool,
	Spatial: bool,
	Effects: bool,
	Queue: bool,
}

Sound_Data :: struct {
	Samples: [dynamic]f32,
	Sample_Rate: int,
	Channels: int,
	Bit_Depth: int,
}

Image_Data_Format :: enum {
	RGBA8,
}

Image_Data :: struct {
	Width, Height: int,
	Format: Image_Data_Format,
	Pixels: [dynamic]u8,
}

Audio_Decoder :: struct {
	handle: u64,
}

Video_Stream :: struct {
	handle: u64,
}

Audio_Bus :: struct {
	handle: u64,
}

Audio_Effect :: struct {
	handle: u64,
}

Font :: struct {
	handle: u64,
}

Text :: struct {
	handle: u64,
}

Canvas :: struct {
	handle: u64,
}

Shader :: struct {
	handle: u64,
}

Sprite_Batch :: struct {
	handle: u64,
}

Particle_System :: struct {
	handle: u64,
}

Mesh :: struct {
	handle: u64,
}

Mesh_Vertex :: struct {
	Position: Vec2,
	UV: Vec2,
	Color: Color,
	Normal: Vec2,
}

Mesh_Draw_Mode :: enum {
	Triangles,
	Triangle_Fan,
	Triangle_Strip,
	Points,
}

// v0.8 LOVE-parity draw state.
Draw_Mode :: enum {
	Fill,
	Line,
}

Arc_Type :: enum {
	Pie,
	Open,
	Closed,
}

Line_Join :: enum {
	Miter,
	Bevel,
	None,
}

Line_Style :: enum {
	Smooth,
	Rough,
}

Cull_Mode :: enum {
	None,
	Back,
	Front,
}

Winding :: enum {
	Clockwise,
	Counter_Clockwise,
}

Color_Mask :: struct {
	R, G, B, A: bool,
}

Default_Color_Mask :: proc() -> Color_Mask {
	return Color_Mask{R = true, G = true, B = true, A = true}
}

Graphics_Stats :: struct {
	Draw_Calls: int,
	Texture_Memory: int,
	Canvas_Count: int,
	Mesh_Count: int,
}

System_Limits :: struct {
	Texture_Size: int,
	Canvas_Size: int,
	Multi_Canvas: bool,
	Instancing: bool,
	Stencil: bool,
}

Display_Info :: struct {
	Index: int,
	Name: string,
	X, Y, W, H: int,
}

Power_Info :: struct {
	// State mirrors love.system.getPowerInfo states: "unknown", "battery",
	// "nobattery", "charging", "charged". Desktop reports "nobattery".
	State: string,
	Percent: int,
}

Cursor_Type :: enum {
	Arrow,
	IBeam,
	Crosshair,
	Hand,
	HResize,
	VResize,
	Not_Allowed,
}

Blend_Mode :: enum {
	Alpha,
	Additive,
	Multiplied,
	Add_Colors,
	Subtract_Colors,
	Alpha_Premultiplied,
}

Texture_Filter :: enum {
	Nearest,
	Linear,
	Anisotropic,
}

Texture_Wrap :: enum {
	Repeat,
	Clamp,
	Mirror_Repeat,
	Mirror_Clamp,
}

// v0.9 canvas pixel formats (mirrors love.graphics.newCanvas format/precision
// variants). Only RGBA8 is backed by the raylib backend
// (LoadRenderTexture is RGBA8 + a depth renderbuffer); the rest are accepted
// by the type system so LOVE ports compile, but Create_Canvas_Format returns
// .Unsupported for them instead of a fake handle. See Graphics.md.
Canvas_Format :: enum {
	RGBA8,
	RGBA16F,
	RGBA32F,
	Depth_Stencil,
}

Text_Align :: enum {
	Left,
	Center,
	Right,
}

Text_Layout :: struct {
	Width: f32,
	Line_Height: f32,
	Lines: int,
}

Bezier_Curve :: struct {
	Control_Points: [dynamic]Vec2,
}

Renderer_Info :: struct {
	Name: string,
	Version: string,
	GPU_Mesh: bool,
	Shader: bool,
}

Display_Mode :: struct {
	Width, Height: int,
	Refresh_Rate: int,
}

Runtime_Metrics :: struct {
	FPS: int,
	Frame_Time: f32,
	Average_Frame_Time: f32,
	Fixed_Step_Backlog: f32,
	Fixed_Steps: int,
	Active_Audio_Sources: int,
}

Action_Kind :: enum {
	Key,
	Mouse_Button,
	Gamepad_Button,
	Gamepad_Axis,
}

Action_Binding :: struct {
	Kind: Action_Kind,
	Code: int,
	Axis_Sign: f32,
	Scale: f32,
}

Action_Map :: struct {
	Bindings: map[string][dynamic]Action_Binding,
	Dead_Zone: f32,
}

Capability :: enum {
	Headless,
	Archive_Mount,
	Video,
	Audio_Capture,
	Audio_Effects,
	Audio_Spatial,
	Fullscreen,
	Gamepad,
	Touch,
	GPU_Mesh,
	Audio_Decoder,
	Audio_Buses,
	Stencil,
	Instancing,
	Color_Mask,
	System_Cursor,
	Gamepad_Mapping,
}

Physics_World :: struct {
	handle: u64,
}

Physics_Body :: struct {
	handle: u64,
}

Physics_Shape :: struct {
	handle: u64,
}

Physics_Joint :: struct {
	handle: u64,
}

Entity :: distinct u64

Physics_Sync_Mode :: enum {
	Physics_To_Transform,
	Transform_To_Physics,
	Manual,
}

Rigid_Body_2D :: struct {
	World: Physics_World,
	Body: Physics_Body,
	Sync_Mode: Physics_Sync_Mode,
}

Physics_Event_Kind :: enum {
	Contact_Begin,
	Contact_End,
	Contact_Hit,
	Sensor_Begin,
	Sensor_End,
}

Physics_Event :: struct {
	Kind: Physics_Event_Kind,
	Body_A, Body_B: Physics_Body,
	Shape_A, Shape_B: Physics_Shape,
	Position: Vec2,
	Normal: Vec2,
	Normal_Impulse: f32,
	Tangent_Impulse: f32,
	Approach_Speed: f32,
}

Physics_Joint_Kind :: enum {
	Distance,
	Revolute,
	Weld,
	Motor,
	Mouse,
	Prismatic,
	Wheel,
	// v0.8: Box2D 3.x removed pulley/rope/friction/gear joints. The kinds
	// below are accepted by the type system so LOVE ports compile, but
	// Create_Physics_Joint returns .Unsupported for them. See Porting_From_LOVE.
	Pulley,
	Rope,
	Friction,
	Gear,
}

Physics_Joint_Def :: struct {
	Kind: Physics_Joint_Kind,
	Body_A, Body_B: Physics_Body,
	Anchor_A, Anchor_B: Vec2,
	Axis: Vec2,
	Length: f32,
	Target: Vec2,
	Max_Force, Max_Torque: f32,
	Angular_Offset: f32,
	Collide_Connected: bool,
	// v0.8 extended fields for LOVE-parity joint kinds. Used by future
	// backends; Box2D 3.x returns .Unsupported when Pulley/Rope/Friction/Gear
	// is requested.
	Ground_A, Ground_B: Vec2,
	Max_Length: f32,
	Ratio: f32,
}

Physics_Raycast_Hit :: struct {
	Hit: bool,
	Shape: Physics_Shape,
	Body: Physics_Body,
	Point: Vec2,
	Normal: Vec2,
	Fraction: f32,
}

Physics_Query_Filter :: struct {
	Category_Bits: u64,
	Mask_Bits: u64,
}

Physics_Query_Result :: struct {
	Shape: Physics_Shape,
	Body: Physics_Body,
	Point: Vec2,
	Normal: Vec2,
	Fraction: f32,
}

Physics_Contact_Data :: struct {
	Shape_A, Shape_B: Physics_Shape,
	Body_A, Body_B: Physics_Body,
	Position: Vec2,
	Normal: Vec2,
	Normal_Impulse: f32,
	Tangent_Impulse: f32,
}

Asset_Id :: distinct u64

Quad :: struct {
	Source: Rect,
	Texture_Width: int,
	Texture_Height: int,
}

Camera_2D :: struct {
	Target: Vec2,
	Offset: Vec2,
	Rotation: f32,
	Zoom: f32,
}

Event_Kind :: enum {
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

Event :: struct {
	Kind: Event_Kind,
	Key: Key,
	Mouse_Button: Mouse_Button,
	Position: Vec2,
	Delta: Vec2,
	Text: rune,
	Width, Height: int,
	Focused: bool,
	Visible: bool,
	Device: int,
	Button: int,
	Axis: int,
	Hat: int,
	Value: f32,
	Touch_ID: int,
	Path: string,
	Editing: string,
}

Particle_Config :: struct {
	Max_Particles: int,
	Lifetime_Min, Lifetime_Max: f32,
	Emission_Rate: f32,
	Gravity: Vec2,
	Start_Size, End_Size: f32,
	Start_Color, End_Color: Color,
}

Default_Particle_Config :: proc(max_particles: int) -> Particle_Config {
	return Particle_Config{
		Max_Particles = max_particles,
		Lifetime_Min = 0.5,
		Lifetime_Max = 1.0,
		Emission_Rate = 0,
		Gravity = Vec2{},
		Start_Size = 8,
		End_Size = 1,
		Start_Color = White,
		End_Color = RGBA(255, 255, 255, 0),
	}
}

Texture_Invalid :: proc(texture: Texture) -> bool {
	return texture.handle == 0
}

Sound_Invalid :: proc(sound: Sound) -> bool {
	return sound.handle == 0
}

Music_Invalid :: proc(music: Music) -> bool {
	return music.handle == 0
}

Audio_Source_Invalid :: proc(source: Audio_Source) -> bool {
	return source.handle == 0
}

Audio_Device_Invalid :: proc(device: Audio_Device) -> bool {
	return device.handle == 0
}

Recording_Device_Invalid :: proc(device: Recording_Device) -> bool {
	return device.handle == 0
}

Audio_Decoder_Invalid :: proc(decoder: Audio_Decoder) -> bool {
	return decoder.handle == 0
}

Video_Stream_Invalid :: proc(video: Video_Stream) -> bool {
	return video.handle == 0
}

Audio_Bus_Invalid :: proc(bus: Audio_Bus) -> bool {
	return bus.handle == 0
}

Audio_Effect_Invalid :: proc(effect: Audio_Effect) -> bool {
	return effect.handle == 0
}

Font_Invalid :: proc(font: Font) -> bool {
	return font.handle == 0
}

Text_Invalid :: proc(text: Text) -> bool {
	return text.handle == 0
}

Canvas_Invalid :: proc(canvas: Canvas) -> bool {
	return canvas.handle == 0
}

Shader_Invalid :: proc(shader: Shader) -> bool {
	return shader.handle == 0
}

Sprite_Batch_Invalid :: proc(batch: Sprite_Batch) -> bool {
	return batch.handle == 0
}

Particle_System_Invalid :: proc(particles: Particle_System) -> bool {
	return particles.handle == 0
}

Mesh_Invalid :: proc(mesh: Mesh) -> bool {
	return mesh.handle == 0
}

Physics_World_Invalid :: proc(world: Physics_World) -> bool {
	return world.handle == 0
}

Physics_Body_Invalid :: proc(body: Physics_Body) -> bool {
	return body.handle == 0
}

Physics_Shape_Invalid :: proc(shape: Physics_Shape) -> bool {
	return shape.handle == 0
}

Physics_Joint_Invalid :: proc(joint: Physics_Joint) -> bool {
	return joint.handle == 0
}

Config :: struct {
	Title: string,
	Width: int,
	Height: int,
	Target_FPS: int,
	Resizable: bool,
	VSync: bool,
	Pixels_Per_Meter: f32,
	Identity: string,
	Source_Directory: string,
	Save_Directory: string,
	Headless: bool,
	Package_Path: string,
	// v0.9 MSAA sample request (mirrors love.window.setMode msaa flag).
	// Honored at window creation via the raylib MSAA_4X_HINT config flag:
	// 0 (default) disables MSAA; any positive value requests 4x MSAA
	// (raylib exposes only a 4x hint, so the exact count is not selectable).
	// Must be set before Create/Run; changing it later has no effect.
	MSAA: int,
}

Default_Config :: proc() -> Config {
	return Config{
		Title = "Thor2D",
		Width = 1280,
		Height = 720,
		Target_FPS = 60,
		Resizable = true,
		VSync = false,
		Pixels_Per_Meter = 32,
		Identity = "thor2d",
		Source_Directory = ".",
		Save_Directory = ".thor2d-save",
		Headless = false,
		Package_Path = "",
		MSAA = 0,
	}
}

Error :: enum {
	None,
	Invalid_Config,
	Backend_Initialization_Failed,
	Resource_Load_Failed,
	Invalid_Handle,
	Invalid_Data,
	Serialization_Failed,
	Compression_Failed,
	Unsupported,
	File_Not_Found,
	Path_Outside_Sandbox,
	Project_Invalid,
	Capability_Unavailable,
	// v0.9 non-blocking I/O: a non-blocking socket operation (TCP_Accept,
	// TCP_Send/TCP_Receive, UDP_Receive_From) has no data/peer ready yet.
	// Poll again later; never treat as failure. Appended last so existing
	// Error ordinals are unchanged.
	Not_Ready,
}

Error_String :: proc(err: Error) -> string {
	switch err {
	case .None:
		return "no error"
	case .Invalid_Config:
		return "invalid Thor2D configuration"
	case .Backend_Initialization_Failed:
		return "Thor2D backend initialization failed"
	case .Resource_Load_Failed:
		return "resource could not be loaded"
	case .Invalid_Handle:
		return "invalid Thor2D resource handle"
	case .Invalid_Data:
		return "invalid or corrupted data"
	case .Serialization_Failed:
		return "serialization failed"
	case .Compression_Failed:
		return "compression or decompression failed"
	case .Unsupported:
		return "feature is not supported by the active backend"
	case .File_Not_Found:
		return "file was not found"
	case .Path_Outside_Sandbox:
		return "path escapes the Thor2D sandbox"
	case .Project_Invalid:
		return "invalid Thor2D project"
	case .Capability_Unavailable:
		return "capability is unavailable on this platform or device"
	case .Not_Ready:
		return "non-blocking operation is not ready yet; try again later"
	}
	return "unknown Thor2D error"
}

Context :: struct {
	backend: rawptr,
	audio_backend: rawptr,
	video_backend: rawptr,
	config: Config,
	running: bool,
	headless: bool,
	delta: f32,
	fixed_delta: f32,
	fixed_accumulator: f32,
	fixed_steps: int,
	Registry: Registry,
	physics: Physics_State,
	filesystem: Filesystem,
	events: [dynamic]Event,
	threads: [dynamic]Thread,
	// v0.8 LOVE-parity graphics state (mirrors love.graphics state).
	draw_color: Color,
	background_color: Color,
	current_font: Font,
	blend_mode: Blend_Mode,
	scissor: Rect,
	scissor_enabled: bool,
	color_mask: Color_Mask,
	line_join: Line_Join,
	line_style: Line_Style,
	default_filter_min: Texture_Filter,
	default_filter_mag: Texture_Filter,
	stencil_enabled: bool,
	wireframe: bool,
	cull_mode: Cull_Mode,
	// v0.8 input state.
	key_repeat: bool,
	text_input: bool,
	cursor_visible: bool,
	cursor_grabbed: bool,
	relative_mode: bool,
	mouse_x, mouse_y: f32,
	// v0.8 physics meter scale (mirrors love.physics.setMeter). Initialized
	// from Config.Pixels_Per_Meter on world creation.
	meter_scale: f32,
	// v0.10 window state. window_has_icon records a successful Set_Window_Icon
	// (no backend icon getter exists); display_sleep_enabled records the
	// Set_Display_Sleep_Enabled intent (default true; desktop still returns
	// .Unsupported because there is no display-sleep API to honor it).
	window_has_icon: bool,
	display_sleep_enabled: bool,
}

Byte_Buffer :: struct {
	Bytes: [dynamic]byte,
}

// Data_View is a non-owning view over bytes owned by a Byte_Buffer, File_Data,
// or another caller-owned allocation. The owner must outlive the view.
Data_View :: struct {
	Bytes: []byte,
}

File_Data :: struct {
	Bytes: [dynamic]byte,
	Path: string,
}

Compression_Format :: enum {
	LZ4,
	ZLIB,
	GZIP,
	DEFLATE,
}

Compressed_Data :: struct {
	Buffer: Byte_Buffer,
	Format: Compression_Format,
}

Hash_Algorithm :: enum {
	MD5,
	SHA1,
	SHA224,
	SHA256,
	SHA384,
	SHA512,
}

Random_Generator :: struct {
	State: u64,
}

Filesystem :: struct {
	Identity: string,
	Source_Directory: string,
	Save_Directory: string,
	archives: [dynamic]Filesystem_Archive,
	// v0.10 LOVE symlink intent flag (mirrors love.filesystem symlink policy
	// queries). The backend follows OS symlinks on reads; this flag records
	// game intent (default true) and never weakens the sandbox: paths
	// escaping via ".." are still rejected. See Filesystem.md.
	Symlinks_Enabled: bool,
}

File_Open_Mode :: enum {
	Read,
	Write,
	Read_Write,
}

Filesystem_Archive_Entry :: struct {
	Path: string,
	Method: u16,
	Data_Offset: int,
	Compressed_Size: int,
	Uncompressed_Size: int,
}

Filesystem_Archive :: struct {
	Path: string,
	Bytes: [dynamic]byte,
	Entries: [dynamic]Filesystem_Archive_Entry,
}

Thor2D_File_Info :: struct {
	Exists: bool,
	Directory: bool,
	Size: i64,
}

Directory_Entry :: struct {
	Path: string,
	Directory: bool,
}

Project_Asset :: struct {
	Id: u64 `json:"id"`,
	Path: string `json:"path"`,
	Kind: string `json:"kind"`,
	Hash: string `json:"hash"`,
}

Project_Entity_Record :: struct {
	Id: u64 `json:"id"`,
	Name: string `json:"name"`,
	Parent: u64 `json:"parent"`,
	Components: map[string]string `json:"components"`,
}

Project_Scene :: struct {
	Id: string `json:"id"`,
	Name: string `json:"name"`,
	Entities: [dynamic]Project_Entity_Record `json:"entities"`,
}

Project :: struct {
	Schema_Version: int `json:"schema_version"`,
	Project_Id: string `json:"project_id"`,
	Name: string `json:"name"`,
	Assets: [dynamic]Project_Asset `json:"assets"`,
	Scenes: [dynamic]Project_Scene `json:"scenes"`,
}

Game :: struct {
	Load: proc(ctx: ^Context),
	Update: proc(ctx: ^Context, delta: f32),
	Draw: proc(ctx: ^Context),
	Shutdown: proc(ctx: ^Context),
	On_Event: proc(ctx: ^Context, event: Event),
	Fixed_Update: proc(ctx: ^Context, delta: f32),
	// v0.9 LOVE-parity runtime gaps (mirrors love.errorhandler / love.lowmemory).
	// Appended at the end so existing Game literals stay compatible.
	// On_Error is invoked by Run/Run_Headless when Create fails. ctx is nil
	// in that case because no Context was created; future runtime errors
	// will pass a valid ctx. On_Low_Memory is never invoked on desktop
	// (no OS low-memory signal); reserved as mobile-future.
	On_Error: proc(ctx: ^Context, err: Error),
	On_Low_Memory: proc(ctx: ^Context),
}

// v0.9 custom cursor handle (mirrors love.mouse.newCursor).
// Raylib has no custom-OS-cursor API, so a Cursor derives from a Texture:
// Load_Cursor_From_Image hides the OS cursor and the game draws the cursor
// texture itself at Mouse_Position minus the hotspot (draw-it-yourself).
Cursor :: struct {
	handle: u64,
}

Cursor_Invalid :: proc(cursor: Cursor) -> bool {
	return cursor.handle == 0
}

// v0.9 framework version (mirrors love.getVersion). Patch is 0 for v0.9.0.
THOR2D_VERSION_MAJOR :: 0
THOR2D_VERSION_MINOR :: 10
THOR2D_VERSION_PATCH :: 0

// v0.9 CPU-side image font (mirrors love.graphics.newImageFont).
//
// LOVE lays the glyphs out left-to-right in a single image row; cell width is
// image.width / len(glyphs). The raylib backend's LoadFontFromImage assumes
// sequential codepoints from a firstChar instead, so it cannot represent an
// arbitrary LOVE glyph string faithfully. Image_Font therefore stays CPU-side:
// Glyphs/Cell_W/Cell_H drive Measure_Text_Image_Font anywhere (headless-safe),
// while Texture backs Draw_Text_Image_Font only when a graphics backend exists
// (headless fonts keep a zero Texture and draw as a no-op).
//
// Glyphs is an owned ASCII clone freed by Unload_Image_Font. Validity is about
// the CPU data (glyphs + cell dims), not the GPU handle, so a headless-loaded
// font reports valid for measure/unload purposes.
Image_Font :: struct {
	Texture: Texture,
	Glyphs: string,
	Cell_W, Cell_H: int,
}

Image_Font_Invalid :: proc(font: Image_Font) -> bool {
	return len(font.Glyphs) == 0 || font.Cell_W <= 0 || font.Cell_H <= 0
}

// v0.10 CPU-side texture array (LOVE newArrayImage subset).
//
// Raylib exposes no 2D array/volume texture API (LoadTextureCubemap is a 3D
// skybox samplerCube path with no 2D layer draw), so this is an honest
// emulation, not a GPU array: an owned list of 2D Texture layers drawn one
// layer at a time via Draw_Texture_Array_Layer. Single owner: load once,
// unload once with Unload_Texture_Array (which also frees Layers).
Texture_Array :: struct {
	Layers: [dynamic]Texture,
}

Texture_Array_Invalid :: proc(array: Texture_Array) -> bool {
	return len(array.Layers) == 0
}

// v0.10 LOVE File:setBuffer/getBuffer parity (mirrors love.filesystem
// BufferMode). The Thor2D file backend is unbuffered (os.read/os.write go
// straight to the OS), so only .None is honored; requesting .Line/.Full
// returns .Unsupported. See Filesystem.md.
File_Buffer_Mode :: enum {
	None,
	Line,
	Full,
}
