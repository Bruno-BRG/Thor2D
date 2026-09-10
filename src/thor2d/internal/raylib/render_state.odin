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

// v0.9 spike result: per-channel color write masking is NOT supported.
// Evidence: `rg -i "colormask|color_mask"` over vendor/raylib (raylib.odin +
// rlgl/rlgl.odin) returns zero hits — neither raylib nor its rlgl bindings
// expose glColorMask or any equivalent. Importing raw OpenGL directly would
// bypass raylib's render-batch state tracking and break the headless and
// multi-GL-version abstraction, so no such path was added. Always false;
// Query_Capability(.Color_Mask) reads this.
Color_Mask_Supported :: proc(state: rawptr) -> bool {
	_ = state
	return false
}

// v0.9 spike result: stencil testing is NOT supported. Evidence:
// `rg -i stencil` over vendor/raylib returns exactly one hit —
// rlgl.FramebufferAttachType.STENCIL, an FBO attachment tag. The bindings
// expose no stencil-test control (no enable/func/op/mask procs), no stencil
// clear, and raylib's LoadRenderTexture builds its FBO with a depth
// renderbuffer only, so there is no stencil buffer to test against on either
// the default framebuffer or canvases. Assembling a custom stencil FBO via
// LoadFramebuffer + FramebufferAttach would still leave no test/clear API,
// so no path was added. Always false; Query_Capability(.Stencil) reads this.
Stencil_Supported :: proc(state: rawptr) -> bool {
	_ = state
	return false
}
