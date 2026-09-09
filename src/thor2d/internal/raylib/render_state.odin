package raylib_backend

import "core:c"
import "core:strings"
import rl "vendor:raylib"

Begin_Blend :: proc(state: rawptr, mode: int) {
	if state == nil {
		return
	}
	native := rl.BlendMode.ALPHA
	switch mode {
	case 1: native = .ADDITIVE
	case 2: native = .MULTIPLIED
	case 3: native = .ADD_COLORS
	case 4: native = .SUBTRACT_COLORS
	case 5: native = .ALPHA_PREMULTIPLY
	}
	rl.BeginBlendMode(native)
}

End_Blend :: proc(state: rawptr) {
	if state != nil {
		rl.EndBlendMode()
	}
}

Begin_Scissor :: proc(state: rawptr, x, y, width, height: int) {
	if state != nil {
		rl.BeginScissorMode(c.int(x), c.int(y), c.int(width), c.int(height))
	}
}

End_Scissor :: proc(state: rawptr) {
	if state != nil {
		rl.EndScissorMode()
	}
}

Set_Point_Size :: proc(state: rawptr, size: f32) -> bool {
	if state == nil || size <= 0 {
		return false
	}
	b := cast(^Backend)state
	b.point_size = size
	return true
}

Take_Screenshot :: proc(state: rawptr, path: string) -> bool {
	if state == nil {
		return false
	}
	c_path, err := strings.clone_to_cstring(path, context.temp_allocator)
	if err != nil {
		return false
	}
	rl.TakeScreenshot(c_path)
	return true
}
