package raylib_backend

import "core:c"
import rl "vendor:raylib"

Key_Down :: proc(state: rawptr, key: int) -> bool {
	return state != nil && rl.IsKeyDown(rl.KeyboardKey(key))
}

Key_Pressed :: proc(state: rawptr, key: int) -> bool {
	return state != nil && rl.IsKeyPressed(rl.KeyboardKey(key))
}

Key_Pressed_Repeat :: proc(state: rawptr, key: int) -> bool {
	return state != nil && rl.IsKeyPressedRepeat(rl.KeyboardKey(key))
}

Key_Released :: proc(state: rawptr, key: int) -> bool {
	return state != nil && rl.IsKeyReleased(rl.KeyboardKey(key))
}

Mouse_Button_Down :: proc(state: rawptr, button: int) -> bool {
	return state != nil && rl.IsMouseButtonDown(rl.MouseButton(button))
}

Mouse_Button_Pressed :: proc(state: rawptr, button: int) -> bool {
	return state != nil && rl.IsMouseButtonPressed(rl.MouseButton(button))
}

Mouse_Button_Released :: proc(state: rawptr, button: int) -> bool {
	return state != nil && rl.IsMouseButtonReleased(rl.MouseButton(button))
}

Mouse_Position :: proc(state: rawptr) -> (x, y: f32) {
	if state == nil {
		return 0, 0
	}
	position := rl.GetMousePosition()
	return position.x, position.y
}

Mouse_Wheel :: proc(state: rawptr) -> f32 {
	if state == nil {
		return 0
	}
	return rl.GetMouseWheelMove()
}

Mouse_Delta :: proc(state: rawptr) -> (x, y: f32) {
	if state == nil {
		return 0, 0
	}
	delta := rl.GetMouseDelta()
	return delta.x, delta.y
}

Set_Mouse_Relative :: proc(state: rawptr, relative: bool) {
	if state == nil {
		return
	}
	if relative {
		rl.DisableCursor()
	} else {
		rl.EnableCursor()
	}
}

Gamepad_Name :: proc(state: rawptr, index: int) -> string {
	if state == nil || !rl.IsGamepadAvailable(c.int(index)) {
		return ""
	}
	return string(rl.GetGamepadName(c.int(index)))
}

Gamepad_Available :: proc(state: rawptr, index: int) -> bool {
	return state != nil && rl.IsGamepadAvailable(c.int(index))
}

Gamepad_Axis :: proc(state: rawptr, index, axis: int) -> f32 {
	if state == nil {
		return 0
	}
	return rl.GetGamepadAxisMovement(c.int(index), rl.GamepadAxis(axis))
}

Gamepad_Button_Down :: proc(state: rawptr, index, button: int) -> bool {
	return state != nil && rl.IsGamepadButtonDown(c.int(index), rl.GamepadButton(button))
}

Gamepad_Button_Pressed :: proc(state: rawptr, index, button: int) -> bool {
	return state != nil && rl.IsGamepadButtonPressed(c.int(index), rl.GamepadButton(button))
}

Touch_Count :: proc(state: rawptr) -> int {
	if state == nil {
		return 0
	}
	return int(rl.GetTouchPointCount())
}

Touch_Position :: proc(state: rawptr, index: int) -> (x, y: f32) {
	if state == nil {
		return 0, 0
	}
	position := rl.GetTouchPosition(c.int(index))
	return position.x, position.y
}

// Audio is owned by thor2d/internal/audio. These compatibility entry points
// intentionally fail instead of silently falling back to Raylib's raudio
// module; keeping them link-free prevents two miniaudio copies in one binary.
Load_Sound :: proc(state: rawptr, path: string) -> (u64, bool) { return 0, false }
Unload_Sound :: proc(state: rawptr, handle: u64) {}
Play_Sound :: proc(state: rawptr, handle: u64) {}
Stop_Sound :: proc(state: rawptr, handle: u64) {}
Set_Sound_Volume :: proc(state: rawptr, handle: u64, volume: f32) {}
Load_Music :: proc(state: rawptr, path: string) -> (u64, bool) { return 0, false }
Unload_Music :: proc(state: rawptr, handle: u64) {}
Play_Music :: proc(state: rawptr, handle: u64) {}
Update_Music :: proc(state: rawptr, handle: u64) {}
Update_All_Music :: proc(state: rawptr) {}
Create_Audio_Source :: proc(state: rawptr, path: string, kind: int) -> (u64, bool) { return 0, false }
Create_Queueable_Audio_Source :: proc(state: rawptr, sample_rate, bit_depth, channels: int) -> (u64, bool) { return 0, false }
Unload_Audio_Stream :: proc(state: rawptr, handle: u64) {}
Queue_Audio_Data :: proc(state: rawptr, handle: u64, samples: []f32, channels: int) -> bool { return false }
Play_Audio_Source :: proc(state: rawptr, handle: u64, kind: int) {}
Pause_Audio_Source :: proc(state: rawptr, handle: u64, kind: int) {}
Resume_Audio_Source :: proc(state: rawptr, handle: u64, kind: int) {}
Stop_Audio_Source :: proc(state: rawptr, handle: u64, kind: int) {}
Audio_Source_State :: proc(state: rawptr, handle: u64, kind: int) -> int { return 0 }
Set_Audio_Source_Volume :: proc(state: rawptr, handle: u64, kind: int, volume: f32) {}
Set_Audio_Source_Pitch :: proc(state: rawptr, handle: u64, kind: int, pitch: f32) {}
Set_Audio_Source_Pan :: proc(state: rawptr, handle: u64, kind: int, pan: f32) {}

Random_Int :: proc(state: rawptr, minimum, maximum: int) -> int {
	if state == nil {
		return minimum
	}
	return int(rl.GetRandomValue(c.int(minimum), c.int(maximum)))
}
