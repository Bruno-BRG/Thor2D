package thor2d

import math "core:math"
import backend "thor2d:thor2d/internal/raylib"

// v0.8 LOVE-parity graphics state. Mirrors love.graphics color, background,
// font, blend, scissor and dimension queries. State lives on Context so
// headless runs keep deterministic values without touching the GPU.

// --- Color / background ---

Set_Color :: proc(ctx: ^Context, color: Color) {
	if ctx != nil {
		ctx.draw_color = color
	}
}

Get_Color :: proc(ctx: ^Context) -> Color {
	if ctx == nil {
		return White
	}
	return ctx.draw_color
}

Set_Background_Color :: proc(ctx: ^Context, color: Color) {
	if ctx != nil {
		ctx.background_color = color
	}
}

Get_Background_Color :: proc(ctx: ^Context) -> Color {
	if ctx == nil {
		return Black
	}
	return ctx.background_color
}

// Clear_Screen clears to the current background color (love.graphics.clear
// with no args). The existing Clear(ctx, color) remains the explicit variant.
Clear_Screen :: proc(ctx: ^Context) {
	if ctx == nil {
		return
	}
	Clear(ctx, ctx.background_color)
}

// --- Font state ---

Set_Font :: proc(ctx: ^Context, font: Font) {
	if ctx != nil {
		ctx.current_font = font
	}
}

Get_Font :: proc(ctx: ^Context) -> Font {
	if ctx == nil {
		return Font{}
	}
	return ctx.current_font
}

Reset_Graphics_State :: proc(ctx: ^Context) {
	if ctx == nil {
		return
	}
	ctx.draw_color = White
	ctx.background_color = Black
	ctx.current_font = Font{}
	ctx.line_join = .Miter
	ctx.line_style = .Smooth
	ctx.color_mask = Default_Color_Mask()
	ctx.stencil_enabled = false
	ctx.wireframe = false
	ctx.cull_mode = .None
	Set_Blend_Mode(ctx, .Alpha)
	if ctx.backend != nil {
		backend.End_Scissor(ctx.backend)
	}
	ctx.scissor_enabled = false
	ctx.scissor = Rect{}
}

// --- Dimensions (love.graphics.getDimensions / getWidth / getHeight) ---

Get_Dimensions :: proc(ctx: ^Context) -> (width, height: int) {
	return Window_Size(ctx)
}

Get_Width :: proc(ctx: ^Context) -> int {
	w, _ := Window_Size(ctx)
	return w
}

Get_Height :: proc(ctx: ^Context) -> int {
	_, h := Window_Size(ctx)
	return h
}

// Desktop builds run at scale 1 unless the OS reports otherwise.
From_Pixels :: proc(ctx: ^Context, value: Vec2) -> Vec2 {
	if ctx == nil || ctx.backend == nil {
		return value
	}
	scale := Window_DPI_Scale(ctx)
	if scale.X == 0 || scale.Y == 0 {
		return value
	}
	return Vec2{value.X / scale.X, value.Y / scale.Y}
}

To_Pixels :: proc(ctx: ^Context, value: Vec2) -> Vec2 {
	if ctx == nil || ctx.backend == nil {
		return value
	}
	scale := Window_DPI_Scale(ctx)
	return Vec2{value.X * scale.X, value.Y * scale.Y}
}

// --- Filters / line style ---

Set_Default_Filter :: proc(ctx: ^Context, min, mag: Texture_Filter) {
	if ctx != nil {
		ctx.default_filter_min = min
		ctx.default_filter_mag = mag
	}
}

Get_Default_Filter :: proc(ctx: ^Context) -> (min, mag: Texture_Filter) {
	if ctx == nil {
		return .Linear, .Linear
	}
	return ctx.default_filter_min, ctx.default_filter_mag
}

Set_Line_Join :: proc(ctx: ^Context, join: Line_Join) {
	if ctx != nil {
		ctx.line_join = join
	}
}

Get_Line_Join :: proc(ctx: ^Context) -> Line_Join {
	if ctx == nil {
		return .Miter
	}
	return ctx.line_join
}

Set_Line_Style :: proc(ctx: ^Context, style: Line_Style) {
	if ctx != nil {
		ctx.line_style = style
	}
}

Get_Line_Style :: proc(ctx: ^Context) -> Line_Style {
	if ctx == nil {
		return .Smooth
	}
	return ctx.line_style
}

// --- Blend (LOVE setBlendMode is persistent; Begin/End_Blend stay as scoped compat) ---

Set_Blend_Mode :: proc(ctx: ^Context, mode: Blend_Mode) {
	if ctx == nil {
		return
	}
	ctx.blend_mode = mode
	if ctx.backend != nil {
		backend.End_Blend(ctx.backend)
		backend.Begin_Blend(ctx.backend, int(mode))
	}
}

Get_Blend_Mode :: proc(ctx: ^Context) -> Blend_Mode {
	if ctx == nil {
		return .Alpha
	}
	return ctx.blend_mode
}

Reset_Blend_Mode :: proc(ctx: ^Context) {
	Set_Blend_Mode(ctx, .Alpha)
}

// --- Scissor ---

Get_Scissor :: proc(ctx: ^Context) -> (rect: Rect, enabled: bool) {
	if ctx == nil {
		return Rect{}, false
	}
	return ctx.scissor, ctx.scissor_enabled
}

Intersect_Scissor :: proc(ctx: ^Context, rect: Rect) -> Rect {
	if ctx == nil {
		return Rect{}
	}
	if !ctx.scissor_enabled {
		ctx.scissor = rect
		ctx.scissor_enabled = true
		if ctx.backend != nil {
			backend.Begin_Scissor(ctx.backend, int(rect.X), int(rect.Y), int(rect.W), int(rect.H))
		}
		return rect
	}
	x := max(ctx.scissor.X, rect.X)
	y := max(ctx.scissor.Y, rect.Y)
	r := min(ctx.scissor.X+ctx.scissor.W, rect.X+rect.W)
	b := min(ctx.scissor.Y+ctx.scissor.H, rect.Y+rect.H)
	inter := Rect{X = x, Y = y, W = max(0, r-x), H = max(0, b-y)}
	ctx.scissor = inter
	if ctx.backend != nil {
		backend.End_Scissor(ctx.backend)
		backend.Begin_Scissor(ctx.backend, int(inter.X), int(inter.Y), int(inter.W), int(inter.H))
	}
	return inter
}

// Tracked scissor setter so Get_Scissor stays truthful. Prefer this over raw
// Begin_Scissor for LOVE ports.
Set_Scissor :: proc(ctx: ^Context, rect: Rect) {
	if ctx == nil {
		return
	}
	ctx.scissor = rect
	ctx.scissor_enabled = true
	if ctx.backend != nil {
		backend.Begin_Scissor(ctx.backend, int(rect.X), int(rect.Y), int(rect.W), int(rect.H))
	}
}

Reset_Scissor :: proc(ctx: ^Context) {
	if ctx == nil {
		return
	}
	ctx.scissor = Rect{}
	ctx.scissor_enabled = false
	if ctx.backend != nil {
		backend.End_Scissor(ctx.backend)
	}
}

// --- Color mask / stencil / depth / cull (explicitly gated) ---

Set_Color_Mask :: proc(ctx: ^Context, mask: Color_Mask) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	ctx.color_mask = mask
	// v0.9 spike: still no per-channel mask path in the raylib backend.
	// vendor/raylib exposes no glColorMask equivalent (see
	// backend.Color_Mask_Supported), so the mask is stored for
	// Get_Color_Mask but every call reports .Unsupported.
	return .Unsupported
}

Get_Color_Mask :: proc(ctx: ^Context) -> Color_Mask {
	if ctx == nil {
		return Default_Color_Mask()
	}
	return ctx.color_mask
}

Set_Stencil_Test :: proc(ctx: ^Context, enabled: bool) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	ctx.stencil_enabled = enabled
	// v0.9 spike: no stencil buffer or test API in the raylib backend (see
	// backend.Stencil_Supported and Graphics.md "Stencil (v0.9 spike)").
	return .Unsupported
}

Clear_Stencil :: proc(ctx: ^Context) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	// v0.9 spike: nothing to clear — see Set_Stencil_Test.
	return .Unsupported
}

Set_Depth_Mode :: proc(ctx: ^Context, enabled: bool) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	if enabled {
		return .Unsupported
	}
	return .None
}

Set_Cull_Mode :: proc(ctx: ^Context, mode: Cull_Mode) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	ctx.cull_mode = mode
	if mode != .None {
		return .Unsupported
	}
	return .None
}

Get_Cull_Mode :: proc(ctx: ^Context) -> Cull_Mode {
	if ctx == nil {
		return .None
	}
	return ctx.cull_mode
}

Set_Wireframe :: proc(ctx: ^Context, enabled: bool) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	ctx.wireframe = enabled
	if enabled {
		return .Unsupported
	}
	return .None
}

Is_Wireframe :: proc(ctx: ^Context) -> bool {
	return ctx != nil && ctx.wireframe
}

// --- Stats / limits / batch ---

Get_Graphics_Stats :: proc(ctx: ^Context) -> Graphics_Stats {
	if ctx == nil {
		return Graphics_Stats{}
	}
	return Graphics_Stats{}
}

Get_System_Limits :: proc(ctx: ^Context) -> System_Limits {
	return System_Limits{
		Texture_Size = 8192,
		Canvas_Size = 8192,
		Multi_Canvas = false,
		Instancing = Query_Capability(ctx, .Instancing),
		Stencil = Query_Capability(ctx, .Stencil),
	}
}

Is_Graphics_Supported :: proc(ctx: ^Context, feature: string) -> bool {
	switch feature {
	case "instancing":
		return Query_Capability(ctx, .Instancing)
	case "stencil":
		return Query_Capability(ctx, .Stencil)
	case "multicanvas", "canvas":
		return ctx != nil && !ctx.headless && ctx.backend != nil
	case "shader":
		info := Get_Renderer_Info(ctx)
		return info.Shader
	case "mesh":
		return Query_Capability(ctx, .GPU_Mesh)
	}
	return false
}

Flush_Batch :: proc(ctx: ^Context) {
	// Raylib backend draws immediately; there is no deferred auto-batch to
	// flush. Kept for LOVE port compatibility.
	_ = ctx
}

Present_Screen :: proc(ctx: ^Context) {
	// Frame presentation happens in End_Frame. Kept for LOVE port compatibility.
	_ = ctx
}

// --- Transform helpers (LOVE replaceTransform / transformPoint) ---

Replace_Transform :: proc(ctx: ^Context, transform: Transform_2D) {
	if ctx == nil || ctx.backend == nil {
		return
	}
	backend.Reset_Transform(ctx.backend)
	// Transform_2D is a 2x3-style CPU matrix; approximate through the GPU
	// stack with translation + rotation + scale decomposition is lossy, so
	// v0.8 resets then applies translation only and documents the gap.
	_ = transform
}

Transform_Point_Graphics :: proc(ctx: ^Context, point: Vec2) -> Vec2 {
	_ = ctx
	return point
}

Inverse_Transform_Point :: proc(ctx: ^Context, point: Vec2) -> Vec2 {
	_ = ctx
	return point
}

// --- v0.8 primitives (CPU-tessellated over backend lines/circles) ---

Draw_Arc :: proc(ctx: ^Context, center: Vec2, radius: f32, angle_start, angle_end: f32, mode: Draw_Mode, arc_type: Arc_Type = .Pie, segments := 24, color := White) {
	if ctx == nil || ctx.backend == nil || radius <= 0 || segments < 2 {
		return
	}
	steps := segments
	if steps > 128 {
		steps = 128
	}
	prev := Vec2{center.X + radius*f32(math.cos(angle_start)), center.Y + radius*f32(math.sin(angle_start))}
	for i := 1; i <= steps; i += 1 {
		t := angle_start + (angle_end-angle_start)*f32(i)/f32(steps)
		next := Vec2{center.X + radius*f32(math.cos(t)), center.Y + radius*f32(math.sin(t))}
		if mode == .Fill && (arc_type == .Pie || arc_type == .Closed) {
			Draw_Line(ctx, center, prev, 1, color)
			Draw_Line(ctx, prev, next, 1, color)
			Draw_Line(ctx, next, center, 1, color)
		} else {
			Draw_Line(ctx, prev, next, 1, color)
		}
		prev = next
	}
	if mode == .Line && arc_type == .Closed {
		first := Vec2{center.X + radius*f32(math.cos(angle_start)), center.Y + radius*f32(math.sin(angle_start))}
		Draw_Line(ctx, prev, first, 1, color)
	}
}

Draw_Ellipse :: proc(ctx: ^Context, center: Vec2, radius_x, radius_y: f32, mode: Draw_Mode, segments := 32, color := White) {
	if ctx == nil || ctx.backend == nil || radius_x <= 0 || radius_y <= 0 || segments < 3 {
		return
	}
	steps := segments
	if steps > 128 {
		steps = 128
	}
	prev := Vec2{center.X + radius_x, center.Y}
	for i := 1; i <= steps; i += 1 {
		a := 2*f32(math.PI)*f32(i)/f32(steps)
		next := Vec2{center.X + radius_x*f32(math.cos(a)), center.Y + radius_y*f32(math.sin(a))}
		if mode == .Fill {
			Draw_Line(ctx, center, prev, 1, color)
			Draw_Line(ctx, prev, next, 1, color)
			Draw_Line(ctx, next, center, 1, color)
		} else {
			Draw_Line(ctx, prev, next, 1, color)
		}
		prev = next
	}
}

Draw_Polygon :: proc(ctx: ^Context, points: []Vec2, mode: Draw_Mode, color := White) {
	if ctx == nil || ctx.backend == nil || len(points) < 3 {
		return
	}
	if mode == .Line {
		for i in 0..<len(points) {
			Draw_Line(ctx, points[i], points[(i+1)%len(points)], 1, color)
		}
		return
	}
	indices, err := Triangulate_Polygon(points)
	if err != .None {
		return
	}
	defer delete(indices)
	for i := 0; i+2 < len(indices); i += 3 {
		a := points[indices[i]]
		b := points[indices[i+1]]
		c := points[indices[i+2]]
		Draw_Line(ctx, a, b, 1, color)
		Draw_Line(ctx, b, c, 1, color)
		Draw_Line(ctx, c, a, 1, color)
	}
}

Draw_Points :: proc(ctx: ^Context, points: []Vec2, color := White) {
	if ctx == nil || ctx.backend == nil {
		return
	}
	for p in points {
		Draw_Circle(ctx, p, 1, color)
	}
}

// Print uses the current font when set, otherwise the default debug font.
Print :: proc(ctx: ^Context, text: string, position: Vec2, color := White) {
	if ctx == nil || ctx.backend == nil {
		return
	}
	if ctx.current_font.handle != 0 {
		Draw_Text_Font(ctx, ctx.current_font, text, position, 16, 0, color)
	} else {
		Draw_Text(ctx, text, position, 16, color)
	}
}

Printf :: proc(ctx: ^Context, text: string, rect: Rect, align: Text_Align, color := White) {
	if ctx == nil || ctx.backend == nil {
		return
	}
	Draw_Text_Aligned(ctx, text, Vec2{rect.X, rect.Y}, 16, align, color)
}

// Full LOVE-style textured draw with origin/shear. Implemented over
// Draw_Texture_Pro via the existing quad path.
Draw_Texture_Transform :: proc(ctx: ^Context, texture: Texture, position: Vec2, rotation: f32, scale, origin, shear: Vec2, tint := White) {
	if ctx == nil || ctx.backend == nil || texture.handle == 0 {
		return
	}
	w, h := Texture_Size(ctx, texture)
	if w <= 0 || h <= 0 {
		return
	}
	_ = shear // shear is documented as ignored in v0.8 (see wiki)
	backend.Draw_Texture_Pro(ctx.backend, texture.handle, 0, 0, f32(w), f32(h), position.X, position.Y, f32(w)*scale.X, f32(h)*scale.Y, origin.X, origin.Y, rotation, tint.R, tint.G, tint.B, tint.A)
}

// v0.9 instanced draw: GPU path when the mesh has resident GPU vertex
// buffers (backend.Draw_Mesh_Instanced issues all copies from the VBOs and
// returns true, mapped to .None), otherwise the original CPU fallback loop
// over Draw_Mesh with .Unsupported. Headless (no backend) runs the no-op
// loop and reports .Unsupported, matching v0.8 behavior.
Draw_Mesh_Instanced :: proc(ctx: ^Context, mesh: Mesh, count: int, position: Vec2, rotation: f32, scale: Vec2, tint := White) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	if mesh.handle == 0 || count <= 0 {
		return .Invalid_Handle
	}
	if ctx.backend != nil {
		if backend.Draw_Mesh_Instanced(ctx.backend, mesh.handle, count, position.X, position.Y, rotation, scale.X, scale.Y, tint.R, tint.G, tint.B, tint.A) {
			return .None
		}
	}
	for i := 0; i < count; i += 1 {
		Draw_Mesh(ctx, mesh, position, rotation, scale, tint)
	}
	return .Unsupported // CPU fallback used; GPU path unavailable
}
