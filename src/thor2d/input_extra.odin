package thor2d

import "core:fmt"
import backend "thor2d:thor2d/internal/raylib"

// v0.8 LOVE-parity input gaps. Headless-safe: polling returns zero values,
// setters on headless Contexts update tracked state only.

Set_Key_Repeat :: proc(ctx: ^Context, enabled: bool) {
	if ctx != nil {
		ctx.key_repeat = enabled
	}
}

Has_Key_Repeat :: proc(ctx: ^Context) -> bool {
	return ctx != nil && ctx.key_repeat
}

Set_Text_Input :: proc(ctx: ^Context, enabled: bool) {
	if ctx != nil {
		ctx.text_input = enabled
	}
}

Has_Text_Input :: proc(ctx: ^Context) -> bool {
	return ctx != nil && ctx.text_input
}

Has_Screen_Keyboard :: proc(ctx: ^Context) -> bool {
	_ = ctx
	return false
}

Get_Key_From_Scancode :: proc(scancode: int) -> (Key, Error) {
	// Raylib backend keys already use GLFW keycodes; scancodes are the same
	// integer domain on desktop. Accept the LOVE range explicitly.
	if scancode < 0 || scancode > 512 {
		return .Unknown, .Invalid_Data
	}
	return Key(scancode), .None
}

Get_Scancode_From_Key :: proc(key: Key) -> (int, Error) {
	return int(key), .None
}

Is_Scancode_Down :: proc(ctx: ^Context, scancode: int) -> bool {
	if ctx == nil {
		return false
	}
	key, err := Get_Key_From_Scancode(scancode)
	if err != .None {
		return false
	}
	return Key_Down(ctx, key)
}

Set_Mouse_Position :: proc(ctx: ^Context, position: Vec2) {
	if ctx == nil {
		return
	}
	ctx.mouse_x = position.X
	ctx.mouse_y = position.Y
	if ctx.backend != nil {
		backend.Set_Mouse_Position(ctx.backend, position.X, position.Y)
	}
}

Is_Mouse_Grabbed :: proc(ctx: ^Context) -> bool {
	return ctx != nil && ctx.cursor_grabbed
}

Get_Relative_Mode :: proc(ctx: ^Context) -> bool {
	return ctx != nil && ctx.relative_mode
}

Is_Cursor_Supported :: proc(ctx: ^Context) -> bool {
	return ctx != nil && !ctx.headless && ctx.backend != nil
}

Set_System_Cursor :: proc(ctx: ^Context, cursor: Cursor_Type) -> Error {
	if ctx == nil || ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	backend.Set_System_Cursor(ctx.backend, int(cursor))
	return .None
}

Reset_Cursor :: proc(ctx: ^Context) -> Error {
	return Set_System_Cursor(ctx, .Arrow)
}

Get_Joystick_Count :: proc(ctx: ^Context) -> int {
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	count := 0
	for i in 0..<8 {
		if Gamepad_Available(ctx, i) {
			count += 1
		}
	}
	return count
}

Get_Gamepad_Mapping :: proc(ctx: ^Context, index: int) -> (string, Error) {
	_ = index
	if ctx == nil || ctx.backend == nil {
		return "", .Backend_Initialization_Failed
	}
	// Raylib backend has no SDL-style mapping database in v0.8.
	return "", .Unsupported
}

Set_Gamepad_Mapping :: proc(ctx: ^Context, mapping: string) -> Error {
	_ = mapping
	if ctx == nil {
		return .Invalid_Config
	}
	return .Unsupported
}

Get_Touch_Ids :: proc(ctx: ^Context) -> []int {
	// Returns touch indices [0, count). LOVE returns opaque lightuserdata ids;
	// Thor2D documents integer indices instead.
	if ctx == nil || ctx.backend == nil {
		return nil
	}
	count := Touch_Count(ctx)
	if count <= 0 {
		return nil
	}
	ids := make([]int, count, context.temp_allocator)
	for i in 0..<count {
		ids[i] = i
	}
	return ids
}

Get_Touch_Pressure :: proc(ctx: ^Context, index: int) -> f32 {
	_ = index
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	// Backend reports position only; pressure defaults to full press.
	return 1.0
}

// v0.9 LOVE-parity joystick completion (mirrors love.joystick).
// All procs are headless-safe: polling returns zero values, setters return
// an explicit error when there is no backend.

// Get_Joysticks returns connected gamepad indices in 0..<8 (mirrors
// love.joystick.getJoysticks, documented as integer indices instead of
// LOVE lightuserdata objects). Temp-allocator slice; empty (nil) headless.
Get_Joysticks :: proc(ctx: ^Context) -> []int {
	if ctx == nil || ctx.backend == nil {
		return nil
	}
	ids := make([dynamic]int, 0, 8, context.temp_allocator)
	for i in 0..<8 {
		if Gamepad_Available(ctx, i) {
			append(&ids, i)
		}
	}
	return ids[:]
}

// Get_Gamepad_GUID mirrors love.joystick.getGUID. Raylib exposes no GUID
// API, so Thor2D returns the documented synthetic string
// "thor2d-gamepad-<index>" with .None. The string lives on the temp
// allocator; clone it to retain. Index outside 0..<8 is .Invalid_Handle.
Get_Gamepad_GUID :: proc(ctx: ^Context, index: int) -> (string, Error) {
	if ctx == nil {
		return "", .Invalid_Config
	}
	if index < 0 || index >= 8 {
		return "", .Invalid_Handle
	}
	return fmt.tprintf("thor2d-gamepad-%d", index), .None
}

// Get_Gamepad_Axis_Count mirrors love.joystick axis counts. The raylib
// GamepadAxis enum defines 6 axes (LEFT_X/Y, RIGHT_X/Y, LEFT/RIGHT_TRIGGER),
// so an available gamepad reports 6, otherwise 0. Headless returns 0.
Get_Gamepad_Axis_Count :: proc(ctx: ^Context, index: int) -> int {
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	if !Gamepad_Available(ctx, index) {
		return 0
	}
	return 6
}

// Get_Gamepad_Button_Count mirrors love.joystick button counts. The backend
// polls 18 raylib GamepadButton values (see Poll_Events), so an available
// gamepad reports 18, otherwise 0. Headless returns 0.
Get_Gamepad_Button_Count :: proc(ctx: ^Context, index: int) -> int {
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	if !Gamepad_Available(ctx, index) {
		return 0
	}
	return 18
}

// Get_Gamepad_Hat mirrors love.joystick hat queries. The raylib backend has
// no hat API, so this always returns (0, .Unsupported) — never a fake hat
// value. ctx == nil maps to .Invalid_Config.
Get_Gamepad_Hat :: proc(ctx: ^Context, index, hat: int) -> (int, Error) {
	_ = index
	_ = hat
	if ctx == nil {
		return 0, .Invalid_Config
	}
	return 0, .Unsupported
}

// Set_Gamepad_Vibration mirrors love.joystick setVibration (motors 0..1,
// clamped). Wired to raylib SetGamepadVibration with a fixed 1.0s duration;
// call repeatedly for longer rumble and Stop_Gamepad_Vibration to cancel.
// Unavailable gamepad maps to .Invalid_Handle (never faked); headless or
// nil backend maps to .Backend_Initialization_Failed.
Set_Gamepad_Vibration :: proc(ctx: ^Context, index: int, left, right: f32) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	if index < 0 || index >= 8 {
		return .Invalid_Handle
	}
	if ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	if !Gamepad_Available(ctx, index) {
		return .Invalid_Handle
	}
	l := Clamp(left, 0, 1)
	r := Clamp(right, 0, 1)
	if !backend.Set_Gamepad_Vibration(ctx.backend, index, l, r, 1.0) {
		return .Invalid_Handle
	}
	return .None
}

// Stop_Gamepad_Vibration cancels rumble started by Set_Gamepad_Vibration
// (zero motors, zero duration). Same error mapping as Set_Gamepad_Vibration.
Stop_Gamepad_Vibration :: proc(ctx: ^Context, index: int) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	if index < 0 || index >= 8 {
		return .Invalid_Handle
	}
	if ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	if !Gamepad_Available(ctx, index) {
		return .Invalid_Handle
	}
	backend.Set_Gamepad_Vibration(ctx.backend, index, 0, 0, 0)
	return .None
}

// Load_Cursor_From_Image mirrors love.mouse.newCursor(imageData, hotx, hoty).
// Raylib has no custom-OS-cursor API, so Thor2D uploads the RGBA8 image as a
// Texture, hides the OS cursor, and returns Cursor{texture handle} under a
// draw-it-yourself contract: the game draws the cursor each frame with
// Draw_Texture at Mouse_Position minus (hot_x, hot_y) and calls
// Set_Cursor_Visible(ctx, true) + Unload_Cursor when done. Hotspot must lie
// inside the image; headless (no backend) returns .Backend_Initialization_Failed,
// never a fake handle.
Load_Cursor_From_Image :: proc(ctx: ^Context, image: Image_Data, hot_x, hot_y: int) -> (Cursor, Error) {
	if ctx == nil {
		return Cursor{}, .Invalid_Config
	}
	if image.Width <= 0 || image.Height <= 0 || len(image.Pixels) != image.Width*image.Height*4 {
		return Cursor{}, .Invalid_Data
	}
	if hot_x < 0 || hot_y < 0 || hot_x >= image.Width || hot_y >= image.Height {
		return Cursor{}, .Invalid_Data
	}
	if ctx.backend == nil {
		return Cursor{}, .Backend_Initialization_Failed
	}
	handle, ok := backend.Create_Texture_From_RGBA(ctx.backend, image.Width, image.Height, image.Pixels[:])
	if !ok {
		return Cursor{}, .Resource_Load_Failed
	}
	backend.Set_Cursor_Visible(ctx.backend, false)
	ctx.cursor_visible = false
	return Cursor{handle = handle}, .None
}

// Unload_Cursor frees a cursor created by Load_Cursor_From_Image (the handle
// is the underlying texture handle). Headless-safe no-op. Does not restore
// OS-cursor visibility; call Set_Cursor_Visible(ctx, true) explicitly.
Unload_Cursor :: proc(ctx: ^Context, cursor: Cursor) {
	if ctx != nil && ctx.backend != nil && cursor.handle != 0 {
		backend.Unload_Texture(ctx.backend, cursor.handle)
	}
}
