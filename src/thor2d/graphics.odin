package thor2d

import "core:fmt"
import utf8 "core:unicode/utf8"
import backend "thor2d:thor2d/internal/raylib"

Clear :: proc(ctx: ^Context, color: Color) {
	if ctx != nil && ctx.backend != nil {
		backend.Clear(ctx.backend, color.R, color.G, color.B, color.A)
	}
}

Draw_Rect :: proc(ctx: ^Context, rect: Rect, color: Color) {
	if ctx != nil && ctx.backend != nil {
		backend.Draw_Rect(ctx.backend, rect.X, rect.Y, rect.W, rect.H, color.R, color.G, color.B, color.A)
	}
}

Draw_Rect_Outline :: proc(ctx: ^Context, rect: Rect, thickness: f32, color: Color) {
	if ctx != nil && ctx.backend != nil {
		backend.Draw_Rect_Outline(ctx.backend, rect.X, rect.Y, rect.W, rect.H, thickness, color.R, color.G, color.B, color.A)
	}
}

Draw_Circle :: proc(ctx: ^Context, center: Vec2, radius: f32, color: Color) {
	if ctx != nil && ctx.backend != nil {
		backend.Draw_Circle(ctx.backend, center.X, center.Y, radius, color.R, color.G, color.B, color.A)
	}
}

Draw_Line :: proc(ctx: ^Context, start, end: Vec2, thickness: f32, color: Color) {
	if ctx != nil && ctx.backend != nil {
		backend.Draw_Line(ctx.backend, start.X, start.Y, end.X, end.Y, thickness, color.R, color.G, color.B, color.A)
	}
}

Draw_Text :: proc(ctx: ^Context, text: string, position: Vec2, size: int, color: Color) {
	if ctx != nil && ctx.backend != nil {
		backend.Draw_Text(ctx.backend, text, position.X, position.Y, size, color.R, color.G, color.B, color.A)
	}
}

Measure_Text :: proc(ctx: ^Context, text: string, size: int) -> int {
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	return backend.Measure_Text(ctx.backend, text, size)
}

Load_Font :: proc(ctx: ^Context, path: string) -> (Font, Error) {
	if ctx == nil || ctx.backend == nil {
		return Font{}, .Backend_Initialization_Failed
	}
	file, file_err := Read_Path(&ctx.filesystem, path)
	if file_err != .None {
		return Font{}, file_err
	}
	defer Destroy_File_Data(&file)
	handle, ok := backend.Load_Font_From_Memory(ctx.backend, path, file.Bytes[:], 32)
	if !ok {
		return Font{}, .Resource_Load_Failed
	}
	return Font{handle}, .None
}

Unload_Font :: proc(ctx: ^Context, font: Font) {
	if ctx != nil && ctx.backend != nil && font.handle != 0 {
		backend.Unload_Font(ctx.backend, font.handle)
	}
}

Draw_Text_Font :: proc(ctx: ^Context, font: Font, text: string, position: Vec2, size: f32, spacing: f32, color: Color) {
	if ctx != nil && ctx.backend != nil && font.handle != 0 {
		backend.Draw_Text_Font(ctx.backend, font.handle, text, position.X, position.Y, size, spacing, color.R, color.G, color.B, color.A)
	}
}

Measure_Text_Font :: proc(ctx: ^Context, font: Font, text: string, size, spacing: f32) -> Vec2 {
	if ctx == nil || ctx.backend == nil || font.handle == 0 {
		return Vec2{}
	}
	x, y := backend.Measure_Text_Font(ctx.backend, font.handle, text, size, spacing)
	return Vec2{x, y}
}

Create_Text :: proc(ctx: ^Context, font: Font, value: string, size: f32, spacing := f32(0)) -> (Text, Error) {
	if ctx == nil || ctx.backend == nil || value == "" || size <= 0 {
		return Text{}, .Invalid_Config
	}
	handle, ok := backend.Create_Text(ctx.backend, font.handle, value, size, spacing)
	if !ok {
		return Text{}, .Invalid_Handle
	}
	return Text{handle}, .None
}

Set_Text :: proc(ctx: ^Context, text: Text, value: string) -> Error {
	if ctx == nil || ctx.backend == nil || text.handle == 0 {
		return .Invalid_Handle
	}
	if !backend.Set_Text(ctx.backend, text.handle, value) {
		return .Invalid_Data
	}
	return .None
}

Draw_Text_Object :: proc(ctx: ^Context, text: Text, position: Vec2, color := White) {
	if ctx != nil && ctx.backend != nil && text.handle != 0 {
		backend.Draw_Text_Object(ctx.backend, text.handle, position.X, position.Y, color.R, color.G, color.B, color.A)
	}
}

Unload_Text :: proc(ctx: ^Context, text: Text) {
	if ctx != nil && ctx.backend != nil && text.handle != 0 {
		backend.Unload_Text(ctx.backend, text.handle)
	}
}

measure_layout_line :: proc(ctx: ^Context, value: string, size, spacing: f32) -> f32 {
	if value == "" {
		return 0
	}
	return f32(Measure_Text(ctx, value, int(size))) + spacing*f32(max(0, len(value)-1))
}

// Measure_Text_Layout computes a multiline text block. Wrapping happens at
// whitespace and explicit line breaks are always honored. Long words are
// retained as one line, matching the behavior of common 2D text APIs.
Measure_Text_Layout :: proc(ctx: ^Context, text: string, size: f32, max_width := f32(0), spacing := f32(0)) -> Text_Layout {
	if ctx == nil || ctx.backend == nil || size <= 0 {
		return Text_Layout{}
	}
	result := Text_Layout{Line_Height = size}
	// v0.10: the current font's line-height multiplier scales the advance
	// (LOVE Font:setLineHeight). Default 1.0, so default output is unchanged.
	line_mult := Font_Get_Line_Height(ctx, ctx.current_font)
	if line_mult > 0 {
		result.Line_Height = size*line_mult
	}
	paragraph_start := 0
	for paragraph_start <= len(text) {
		paragraph_end := paragraph_start
		for paragraph_end < len(text) && text[paragraph_end] != '\n' {
			paragraph_end += 1
		}
		if paragraph_start == paragraph_end {
			result.Lines += 1
		} else if max_width <= 0 {
			width := measure_layout_line(ctx, text[paragraph_start:paragraph_end], size, spacing)
			result.Width = max(result.Width, width)
			result.Lines += 1
		} else {
			line_start := paragraph_start
			word_start := paragraph_start
			line_width: f32
			line_has_text := false
			for cursor := paragraph_start; cursor <= paragraph_end; cursor += 1 {
				is_break := cursor == paragraph_end || text[cursor] == ' ' || text[cursor] == '\t'
				if !is_break {
					continue
				}
				if cursor == word_start {
					word_start = cursor + 1
					continue
				}
				candidate_start := line_start
				if !line_has_text {
					candidate_start = word_start
				}
				candidate_width := measure_layout_line(ctx, text[candidate_start:cursor], size, spacing)
				if line_has_text && candidate_width > max_width {
					result.Width = max(result.Width, line_width)
					result.Lines += 1
					line_start = word_start
					line_width = measure_layout_line(ctx, text[word_start:cursor], size, spacing)
				} else {
					line_width = candidate_width
				}
				line_has_text = true
				word_start = cursor + 1
			}
			if line_has_text {
				result.Width = max(result.Width, line_width)
				result.Lines += 1
			}
		}
		if paragraph_end >= len(text) {
			break
		}
		paragraph_start = paragraph_end + 1
	}
	if result.Lines == 0 {
		result.Lines = 1
	}
	return result
}

// Draw_Text_Aligned draws a line with an explicit alignment anchor.
Draw_Text_Aligned :: proc(ctx: ^Context, text: string, position: Vec2, size: f32, align: Text_Align, color: Color) {
	if ctx == nil || ctx.backend == nil {
		return
	}
	width := f32(Measure_Text(ctx, text, int(size)))
	draw_position := position
	switch align {
	case .Left:
		// The supplied position is already the left anchor.
	case .Center:
		draw_position.X -= width * 0.5
	case .Right:
		draw_position.X -= width
	}
	Draw_Text(ctx, text, draw_position, int(size), color)
}

Load_Texture :: proc(ctx: ^Context, path: string) -> (Texture, Error) {
	if ctx == nil || ctx.backend == nil {
		return Texture{}, .Backend_Initialization_Failed
	}
	file, file_err := Read_Path(&ctx.filesystem, path)
	if file_err != .None {
		return Texture{}, file_err
	}
	defer Destroy_File_Data(&file)
	handle, ok := backend.Load_Texture_From_Memory(ctx.backend, path, file.Bytes[:])
	if !ok {
		return Texture{}, .Resource_Load_Failed
	}
	return Texture{handle}, .None
}

Generate_Texture :: proc(ctx: ^Context, width, height: int, color: Color) -> (Texture, Error) {
	if ctx == nil || ctx.backend == nil || width <= 0 || height <= 0 {
		return Texture{}, .Invalid_Config
	}
	handle, ok := backend.Generate_Texture(ctx.backend, width, height, color.R, color.G, color.B, color.A)
	if !ok {
		return Texture{}, .Resource_Load_Failed
	}
	return Texture{handle}, .None
}

Unload_Texture :: proc(ctx: ^Context, texture: Texture) {
	if ctx != nil && ctx.backend != nil && texture.handle != 0 {
		backend.Unload_Texture(ctx.backend, texture.handle)
	}
}

Texture_Size :: proc(ctx: ^Context, texture: Texture) -> (width, height: int) {
	if ctx == nil || ctx.backend == nil || texture.handle == 0 {
		return 0, 0
	}
	return backend.Texture_Size(ctx.backend, texture.handle)
}

Draw_Texture :: proc(ctx: ^Context, texture: Texture, position: Vec2, tint := White) {
	if ctx != nil && ctx.backend != nil && texture.handle != 0 {
		backend.Draw_Texture(ctx.backend, texture.handle, position.X, position.Y, tint.R, tint.G, tint.B, tint.A)
	}
}

Draw_Texture_Ex :: proc(ctx: ^Context, texture: Texture, position: Vec2, rotation, scale: f32, tint := White) {
	if ctx != nil && ctx.backend != nil && texture.handle != 0 {
		backend.Draw_Texture_Ex(ctx.backend, texture.handle, position.X, position.Y, rotation, scale, tint.R, tint.G, tint.B, tint.A)
	}
}

Draw_Texture_Pro :: proc(ctx: ^Context, texture: Texture, source, destination: Rect, origin: Vec2, rotation: f32, tint := White) {
	if ctx != nil && ctx.backend != nil && texture.handle != 0 {
		backend.Draw_Texture_Pro(ctx.backend, texture.handle, source.X, source.Y, source.W, source.H, destination.X, destination.Y, destination.W, destination.H, origin.X, origin.Y, rotation, tint.R, tint.G, tint.B, tint.A)
	}
}

Set_Texture_Filter :: proc(ctx: ^Context, texture: Texture, filter: Texture_Filter) -> Error {
	if ctx == nil || ctx.backend == nil || texture.handle == 0 {
		return .Invalid_Handle
	}
	if !backend.Set_Texture_Filter(ctx.backend, texture.handle, int(filter)) {
		return .Invalid_Handle
	}
	return .None
}

Set_Texture_Wrap :: proc(ctx: ^Context, texture: Texture, wrap: Texture_Wrap) -> Error {
	if ctx == nil || ctx.backend == nil || texture.handle == 0 {
		return .Invalid_Handle
	}
	if !backend.Set_Texture_Wrap(ctx.backend, texture.handle, int(wrap)) {
		return .Invalid_Handle
	}
	return .None
}

Create_Canvas :: proc(ctx: ^Context, width, height: int) -> (Canvas, Error) {
	if ctx == nil || ctx.backend == nil || width <= 0 || height <= 0 {
		return Canvas{}, .Invalid_Config
	}
	handle, ok := backend.Create_Canvas(ctx.backend, width, height)
	if !ok {
		return Canvas{}, .Resource_Load_Failed
	}
	return Canvas{handle}, .None
}

Unload_Canvas :: proc(ctx: ^Context, canvas: Canvas) {
	if ctx != nil && ctx.backend != nil && canvas.handle != 0 {
		backend.Unload_Canvas(ctx.backend, canvas.handle)
	}
}

Set_Canvas :: proc(ctx: ^Context, canvas: Canvas) {
	if ctx != nil && ctx.backend != nil && canvas.handle != 0 {
		backend.Set_Canvas(ctx.backend, canvas.handle)
	}
}

Reset_Canvas :: proc(ctx: ^Context) {
	if ctx != nil && ctx.backend != nil {
		backend.Reset_Canvas(ctx.backend)
	}
}

Draw_Canvas :: proc(ctx: ^Context, canvas: Canvas, position: Vec2, scale: Vec2, tint := White) {
	if ctx != nil && ctx.backend != nil && canvas.handle != 0 {
		backend.Draw_Canvas(ctx.backend, canvas.handle, position.X, position.Y, scale.X, scale.Y, tint.R, tint.G, tint.B, tint.A)
	}
}

New_Quad :: proc(texture: Texture, source: Rect) -> Quad {
	return Quad{Source = source}
}

New_Quad_From_Texture :: proc(ctx: ^Context, texture: Texture, source: Rect) -> Quad {
	width, height := Texture_Size(ctx, texture)
	return Quad{Source = source, Texture_Width = width, Texture_Height = height}
}

Draw_Texture_Quad :: proc(ctx: ^Context, texture: Texture, quad: Quad, position: Vec2, rotation, scale: f32, tint := White) {
	if ctx == nil || ctx.backend == nil || texture.handle == 0 {
		return
	}
	backend.Draw_Texture_Pro(ctx.backend, texture.handle, quad.Source.X, quad.Source.Y, quad.Source.W, quad.Source.H, position.X, position.Y, quad.Source.W*scale, quad.Source.H*scale, 0, 0, rotation, tint.R, tint.G, tint.B, tint.A)
}

Load_Shader :: proc(ctx: ^Context, vertex_path, fragment_path: string) -> (Shader, Error) {
	if ctx == nil || ctx.backend == nil {
		return Shader{}, .Backend_Initialization_Failed
	}
	vertex, vertex_err := Read_Path(&ctx.filesystem, vertex_path)
	if vertex_err != .None {
		return Shader{}, vertex_err
	}
	defer Destroy_File_Data(&vertex)
	fragment, fragment_err := Read_Path(&ctx.filesystem, fragment_path)
	if fragment_err != .None {
		return Shader{}, fragment_err
	}
	defer Destroy_File_Data(&fragment)
	handle, ok := backend.Load_Shader_From_Memory(ctx.backend, vertex.Bytes[:], fragment.Bytes[:])
	if !ok {
		return Shader{}, .Resource_Load_Failed
	}
	return Shader{handle}, .None
}

Unload_Shader :: proc(ctx: ^Context, shader: Shader) {
	if ctx != nil && ctx.backend != nil && shader.handle != 0 {
		backend.Unload_Shader(ctx.backend, shader.handle)
	}
}

Begin_Shader :: proc(ctx: ^Context, shader: Shader) {
	if ctx != nil && ctx.backend != nil && shader.handle != 0 {
		backend.Begin_Shader(ctx.backend, shader.handle)
	}
}

End_Shader :: proc(ctx: ^Context) {
	if ctx != nil && ctx.backend != nil {
		backend.End_Shader(ctx.backend)
	}
}

Set_Shader_Float :: proc(ctx: ^Context, shader: Shader, name: string, value: f32) {
	if ctx != nil && ctx.backend != nil && shader.handle != 0 {
		backend.Set_Shader_Float(ctx.backend, shader.handle, name, value)
	}
}

Set_Shader_Vec2 :: proc(ctx: ^Context, shader: Shader, name: string, value: Vec2) {
	if ctx != nil && ctx.backend != nil && shader.handle != 0 {
		backend.Set_Shader_Vec2(ctx.backend, shader.handle, name, value.X, value.Y)
	}
}

Set_Shader_Vec4 :: proc(ctx: ^Context, shader: Shader, name: string, value: Vec4) {
	if ctx != nil && ctx.backend != nil && shader.handle != 0 {
		backend.Set_Shader_Vec4(ctx.backend, shader.handle, name, value.X, value.Y, value.Z, value.W)
	}
}

Set_Shader_Texture :: proc(ctx: ^Context, shader: Shader, name: string, texture: Texture) -> Error {
	if ctx == nil || ctx.backend == nil || shader.handle == 0 || texture.handle == 0 {
		return .Invalid_Handle
	}
	if !backend.Set_Shader_Texture(ctx.backend, shader.handle, texture.handle, name) {
		return .Invalid_Handle
	}
	return .None
}

Set_Shader_Color :: proc(ctx: ^Context, shader: Shader, name: string, color: Color) {
	if ctx != nil && ctx.backend != nil && shader.handle != 0 {
		backend.Set_Shader_Color(ctx.backend, shader.handle, name, color.R, color.G, color.B, color.A)
	}
}

Set_Shader_Floats :: proc(ctx: ^Context, shader: Shader, name: string, values: []f32) -> Error {
	if ctx == nil || ctx.backend == nil || shader.handle == 0 {
		return .Invalid_Handle
	}
	if !backend.Set_Shader_Floats(ctx.backend, shader.handle, name, values) {
		return .Invalid_Data
	}
	return .None
}

Set_Shader_Matrix :: proc(ctx: ^Context, shader: Shader, name: string, value: Matrix_4) -> Error {
	if ctx == nil || ctx.backend == nil || shader.handle == 0 {
		return .Invalid_Handle
	}
	if !backend.Set_Shader_Matrix(ctx.backend, shader.handle, name, value) {
		return .Invalid_Data
	}
	return .None
}

Create_Mesh :: proc(ctx: ^Context, vertices: []Mesh_Vertex, indices: []u32 = nil, mode := Mesh_Draw_Mode.Triangles) -> (Mesh, Error) {
	if ctx == nil || ctx.backend == nil || len(vertices) == 0 {
		return Mesh{}, .Invalid_Config
	}
	internal := make([dynamic]backend.Mesh_Vertex_Internal, len(vertices))
	defer delete(internal)
	for vertex, i in vertices {
		internal[i] = backend.Mesh_Vertex_Internal{
			position_x = vertex.Position.X,
			position_y = vertex.Position.Y,
			uv_x = vertex.UV.X,
			uv_y = vertex.UV.Y,
			normal_x = vertex.Normal.X,
			normal_y = vertex.Normal.Y,
			r = vertex.Color.R,
			g = vertex.Color.G,
			b = vertex.Color.B,
			a = vertex.Color.A,
		}
	}
	handle, ok := backend.Create_Mesh(ctx.backend, internal[:], indices, int(mode))
	if !ok {
		return Mesh{}, .Resource_Load_Failed
	}
	return Mesh{handle}, .None
}

Update_Mesh :: proc(ctx: ^Context, mesh: Mesh, vertices: []Mesh_Vertex, indices: []u32 = nil) -> Error {
	if ctx == nil || ctx.backend == nil || mesh.handle == 0 || len(vertices) == 0 {
		return .Invalid_Handle
	}
	internal := make([dynamic]backend.Mesh_Vertex_Internal, len(vertices))
	defer delete(internal)
	for vertex, i in vertices {
		internal[i] = backend.Mesh_Vertex_Internal{
			position_x = vertex.Position.X,
			position_y = vertex.Position.Y,
			uv_x = vertex.UV.X,
			uv_y = vertex.UV.Y,
			normal_x = vertex.Normal.X,
			normal_y = vertex.Normal.Y,
			r = vertex.Color.R,
			g = vertex.Color.G,
			b = vertex.Color.B,
			a = vertex.Color.A,
		}
	}
	if !backend.Update_Mesh(ctx.backend, mesh.handle, internal[:], indices) {
		return .Invalid_Handle
	}
	return .None
}

Draw_Mesh :: proc(ctx: ^Context, mesh: Mesh, position: Vec2, rotation: f32, scale: Vec2, tint := White) {
	if ctx != nil && ctx.backend != nil && mesh.handle != 0 {
		backend.Draw_Mesh(ctx.backend, mesh.handle, position.X, position.Y, rotation, scale.X, scale.Y, tint.R, tint.G, tint.B, tint.A)
	}
}

Draw_Mesh_Textured :: proc(ctx: ^Context, mesh: Mesh, texture: Texture, position: Vec2, rotation: f32, scale: Vec2) {
	if ctx != nil && ctx.backend != nil && mesh.handle != 0 && texture.handle != 0 {
		backend.Draw_Mesh_Textured(ctx.backend, mesh.handle, texture.handle, position.X, position.Y, rotation, scale.X, scale.Y)
	}
}

Unload_Mesh :: proc(ctx: ^Context, mesh: Mesh) {
	if ctx != nil && ctx.backend != nil && mesh.handle != 0 {
		backend.Unload_Mesh(ctx.backend, mesh.handle)
	}
}

Begin_Blend :: proc(ctx: ^Context, mode: Blend_Mode) {
	if ctx != nil && ctx.backend != nil {
		backend.Begin_Blend(ctx.backend, int(mode))
	}
}

End_Blend :: proc(ctx: ^Context) {
	if ctx != nil && ctx.backend != nil {
		backend.End_Blend(ctx.backend)
	}
}

Begin_Scissor :: proc(ctx: ^Context, rect: Rect) {
	if ctx != nil && ctx.backend != nil {
		backend.Begin_Scissor(ctx.backend, int(rect.X), int(rect.Y), int(rect.W), int(rect.H))
	}
}

End_Scissor :: proc(ctx: ^Context) {
	if ctx != nil && ctx.backend != nil {
		backend.End_Scissor(ctx.backend)
	}
}

Take_Screenshot :: proc(ctx: ^Context, path: string) -> Error {
	if ctx == nil || ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	if !backend.Take_Screenshot(ctx.backend, path) {
		return .Resource_Load_Failed
	}
	return .None
}

Set_Line_Width :: proc(ctx: ^Context, width: f32) -> Error {
	if ctx == nil || ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	if !backend.Set_Line_Width(ctx.backend, width) {
		return .Invalid_Config
	}
	return .None
}

Set_Point_Size :: proc(ctx: ^Context, size: f32) -> Error {
	if ctx == nil || ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	if !backend.Set_Point_Size(ctx.backend, size) {
		return .Invalid_Config
	}
	return .None
}

Get_Renderer_Info :: proc(ctx: ^Context) -> Renderer_Info {
	if ctx == nil || ctx.backend == nil {
		return Renderer_Info{}
	}
	name, version, gpu_mesh, shader := backend.Renderer_Info(ctx.backend)
	return Renderer_Info{Name = name, Version = version, GPU_Mesh = gpu_mesh, Shader = shader}
}

// v0.9 typed canvas creation (mirrors love.graphics.newCanvas with
// format/msaa settings). Only .RGBA8 with msaa == 0 maps to a real raylib
// resource (LoadRenderTexture is RGBA8 + depth); float and depth-stencil
// formats have no vendor backing (see backend.Create_Canvas_Format), and
// per-canvas MSAA does not exist in raylib — window-level MSAA comes from
// Config.MSAA at creation time. Anything unavailable returns .Unsupported,
// never a fake canvas.
Create_Canvas_Format :: proc(ctx: ^Context, width, height: int, format: Canvas_Format, msaa: int) -> (Canvas, Error) {
	if ctx == nil || ctx.backend == nil || width <= 0 || height <= 0 {
		return Canvas{}, .Invalid_Config
	}
	if msaa != 0 {
		return Canvas{}, .Unsupported
	}
	if format != .RGBA8 {
		return Canvas{}, .Unsupported
	}
	handle, ok := backend.Create_Canvas_Format(ctx.backend, width, height, int(format))
	if !ok {
		return Canvas{}, .Resource_Load_Failed
	}
	return Canvas{handle}, .None
}

// v0.9 per-format canvas support query. Headless (or nil) contexts report
// false for every format; windowed backends report true for .RGBA8 only.
Is_Canvas_Format_Supported :: proc(ctx: ^Context, format: Canvas_Format) -> bool {
	if ctx == nil || ctx.headless || ctx.backend == nil {
		return false
	}
	return backend.Is_Canvas_Format_Supported(ctx.backend, int(format))
}

// --- v0.10 text/canvas/shader completion (LOVE Font/Text/Quad/SpriteBatch/Canvas/Shader parity) ---
//
// LOVE sources: love-api modules/graphics/types/{Font,Text,Quad,SpriteBatch,
// Canvas,Shader}.lua. Wiki: docs/wiki/modules/Graphics.md and Font.md.
// Colored-text variants (LOVE add/set with {color, string} tables),
// formatted addf/setf with wrap limits, glyph transforms, array-texture
// layers, attachAttribute, mipmaps and canvas slices are out of scope.
// Conventions: ctx-first; getters return zero values on bad handles; only
// fallible ops return Error; draw paths no-op headless.

// font_metrics_valid reports whether font metrics can be answered. Handle 0
// is the default font (LOVE's default font / rl.GetFontDefault): always
// answerable, via CPU ratios when headless. Named handles need a live
// backend entry — headless named fonts report invalid, never fake numbers.
font_metrics_valid :: proc(ctx: ^Context, font: Font) -> bool {
	if ctx == nil {
		return false
	}
	if font.handle == 0 {
		return true
	}
	if ctx.backend == nil {
		return false
	}
	return backend.Font_Base_Size(ctx.backend, font.handle) > 0
}

// Font_Ascent mirrors LOVE Font:getAscent at the requested raster size.
// Approximation (documented): raylib's Font exposes only baseSize plus the
// glyph table — no TrueType ascent table — so metrics scale proportionally
// with size (ascent = 0.8em).
Font_Ascent :: proc(ctx: ^Context, font: Font, size: f32) -> f32 {
	if size <= 0 || !font_metrics_valid(ctx, font) {
		return 0
	}
	return size*0.8
}

// Font_Descent mirrors LOVE Font:getDescent (descent = 0.2em, so
// ascent + descent == 1em == the default line advance). Same approximation
// as Font_Ascent.
Font_Descent :: proc(ctx: ^Context, font: Font, size: f32) -> f32 {
	if size <= 0 || !font_metrics_valid(ctx, font) {
		return 0
	}
	return size*0.2
}

// Font_Baseline mirrors LOVE Font:getBaseline: the baseline sits one ascent
// below the line top. Same approximation as Font_Ascent.
Font_Baseline :: proc(ctx: ^Context, font: Font, size: f32) -> f32 {
	if size <= 0 || !font_metrics_valid(ctx, font) {
		return 0
	}
	return size*0.8
}

// Font_Line_Height mirrors LOVE Font:getHeight: the line advance in pixels,
// which is size scaled by the Font_Set_Line_Height multiplier (1.0 default).
Font_Line_Height :: proc(ctx: ^Context, font: Font, size: f32) -> f32 {
	if size <= 0 {
		return 0
	}
	mult := Font_Get_Line_Height(ctx, font)
	if mult <= 0 {
		return 0
	}
	return size*mult
}

// Font_Set_Line_Height mirrors LOVE Font:setLineHeight: stores a per-font
// line advance multiplier (must be positive). Silent no-op on nil ctx,
// invalid handles and headless contexts (no backend owns the entry).
// Honored by Font_Line_Height, Measure_Text_Layout (via the current font)
// and multiline Text draw advance.
Font_Set_Line_Height :: proc(ctx: ^Context, font: Font, height: f32) {
	if ctx == nil || ctx.backend == nil || height <= 0 {
		return
	}
	backend.Font_Set_Line_Height_Multiplier(ctx.backend, font.handle, height)
}

// Font_Get_Line_Height mirrors LOVE Font:getLineHeight: the stored
// multiplier (1.0 default). Zero on nil ctx or unknown handles; 1.0 for the
// default font on headless/nil backends.
Font_Get_Line_Height :: proc(ctx: ^Context, font: Font) -> f32 {
	if ctx == nil {
		return 0
	}
	if ctx.backend == nil {
		return 1 if font.handle == 0 else 0
	}
	return backend.Font_Line_Height_Multiplier(ctx.backend, font.handle)
}

// Font_Has_Glyphs mirrors LOVE Font:hasGlyphs (plain-string variant).
// Best-effort via codepoint coverage (documented approximation): windowed
// backends scan the loaded glyph table for each rune; shaping-only coverage
// (ligatures, fallback composition) is not detected. Headless, only the
// default font answers, assuming ASCII coverage. Empty text is vacuously
// true; invalid UTF-8 reports false.
Font_Has_Glyphs :: proc(ctx: ^Context, font: Font, text: string) -> bool {
	if text == "" {
		return true
	}
	if ctx == nil {
		return false
	}
	if ctx.backend == nil {
		if font.handle != 0 {
			return false
		}
		for byte in text {
			if byte >= 128 {
				return false
			}
		}
		return true
	}
	rest := text
	for len(rest) > 0 {
		r, size := utf8.decode_rune_in_string(rest)
		if r == utf8.RUNE_ERROR && size != 3 {
			return false
		}
		if !backend.Font_Has_Codepoint(ctx.backend, font.handle, r) {
			return false
		}
		rest = rest[size:]
	}
	return true
}

// Font_DPI_Scale mirrors LOVE Font:getDPIScale: Thor2D rasterizes fonts once
// (base size 32) and scales at draw time, so every font shares the window
// DPI scale — this returns Window_DPI_Scale(ctx).X (1.0 headless). Unknown
// named handles report 0; the font parameter exists for LOVE call-shape parity.
Font_DPI_Scale :: proc(ctx: ^Context, font: Font) -> f32 {
	if ctx != nil && font.handle != 0 {
		if ctx.backend == nil {
			return 0
		}
		if backend.Font_Base_Size(ctx.backend, font.handle) <= 0 {
			return 0
		}
	}
	return Window_DPI_Scale(ctx).X
}

// Text_Add mirrors LOVE Text:add (plain-string variant): appends value to
// the stored string. Transforms and colored runs are out of scope.
// Appending "" is a successful no-op.
Text_Add :: proc(ctx: ^Context, text: Text, value: string) -> Error {
	if ctx == nil || ctx.backend == nil || text.handle == 0 {
		return .Invalid_Handle
	}
	if value == "" {
		return .None
	}
	if !backend.Text_Append(ctx.backend, text.handle, value) {
		return .Invalid_Data
	}
	return .None
}

// Text_Addf appends fmt.tprintf(format, ..args) to the stored string (the
// Odin answer to LOVE's formatted text helpers; Odin has no Lua
// string.format, so core:fmt verbs apply).
Text_Addf :: proc(ctx: ^Context, text: Text, format: string, args: ..any) -> Error {
	if ctx == nil || ctx.backend == nil || text.handle == 0 {
		return .Invalid_Handle
	}
	formatted := fmt.tprintf(format, ..args)
	if formatted == "" {
		return .None
	}
	if !backend.Text_Append(ctx.backend, text.handle, formatted) {
		return .Invalid_Data
	}
	return .None
}

// Text_Clear empties the stored string (LOVE Text:clear). There was no prior
// clear path: Set_Text rejects empty input, so this has a dedicated backend
// entry. Draw of a cleared text is a no-op; measure reports zero.
Text_Clear :: proc(ctx: ^Context, text: Text) -> Error {
	if ctx == nil || ctx.backend == nil || text.handle == 0 {
		return .Invalid_Handle
	}
	if !backend.Text_Clear(ctx.backend, text.handle) {
		return .Invalid_Data
	}
	return .None
}

// Text_Font mirrors LOVE Text:getFont: the per-text font (Font{} selects the
// default font). Zero value on bad handles.
Text_Font :: proc(ctx: ^Context, text: Text) -> Font {
	if ctx == nil || ctx.backend == nil || text.handle == 0 {
		return Font{}
	}
	handle, ok := backend.Text_Font_Handle(ctx.backend, text.handle)
	if !ok {
		return Font{}
	}
	return Font{handle}
}

// Text_Set_Font mirrors LOVE Text:setFont: overrides the font used by
// Draw_Text_Object for this text. Font{} selects the default font; any other
// handle must exist in the backend.
Text_Set_Font :: proc(ctx: ^Context, text: Text, font: Font) -> Error {
	if ctx == nil || ctx.backend == nil || text.handle == 0 {
		return .Invalid_Handle
	}
	if !backend.Text_Set_Font_Handle(ctx.backend, text.handle, font.handle) {
		return .Invalid_Data
	}
	return .None
}

// Quad_Viewport mirrors LOVE Quad:getViewport: the source rect. Pure CPU, no ctx.
Quad_Viewport :: proc(quad: Quad) -> Rect {
	return quad.Source
}

// Quad_Set_Viewport mirrors LOVE Quad:setViewport. Quads are values (see
// New_Quad), so this returns the updated Quad. Non-positive tex_w/tex_h keep
// the stored reference size (LOVE's optional sw/sh must be > 0 when set).
Quad_Set_Viewport :: proc(quad: Quad, viewport: Rect, tex_w := -1, tex_h := -1) -> Quad {
	result := quad
	result.Source = viewport
	if tex_w > 0 {
		result.Texture_Width = tex_w
	}
	if tex_h > 0 {
		result.Texture_Height = tex_h
	}
	return result
}

// Quad_Texture_Size mirrors LOVE Quad:getTextureDimensions. Pure CPU, no ctx.
Quad_Texture_Size :: proc(quad: Quad) -> (width, height: int) {
	return quad.Texture_Width, quad.Texture_Height
}

// Canvas_Render_To mirrors LOVE Canvas:renderTo: targets canvas, invokes
// draw(ctx), then resets to the main target. Nil-safe: nil ctx or nil draw
// is a no-op. An invalid canvas leaves the current target in place and still
// invokes draw (matching Set_Canvas, which ignores invalid handles);
// headless backends make the set/reset steps no-ops while draw runs.
Canvas_Render_To :: proc(ctx: ^Context, canvas: Canvas, draw: proc(ctx: ^Context)) {
	if ctx == nil || draw == nil {
		return
	}
	Set_Canvas(ctx, canvas)
	draw(ctx)
	Reset_Canvas(ctx)
}

// Canvas_To_Image mirrors LOVE Canvas:newImageData (full-canvas capture;
// slice/mipmap/area args are out of scope). Reads the canvas back into
// CPU-owned RGBA8 Image_Data via LoadImageFromTexture. Headless (or nil ctx)
// reports .Capability_Unavailable like Capture_Screenshot; unknown handles
// report .Invalid_Handle. Caller owns the pixels: Destroy_Image_Data.
Canvas_To_Image :: proc(ctx: ^Context, canvas: Canvas) -> (Image_Data, Error) {
	if ctx == nil || ctx.backend == nil {
		return Image_Data{}, .Capability_Unavailable
	}
	if canvas.handle == 0 || !backend.Canvas_Exists(ctx.backend, canvas.handle) {
		return Image_Data{}, .Invalid_Handle
	}
	pixels, width, height, ok := backend.Canvas_To_RGBA(ctx.backend, canvas.handle)
	if !ok {
		return Image_Data{}, .Resource_Load_Failed
	}
	return Image_Data{Width = width, Height = height, Format = .RGBA8, Pixels = pixels}, .None
}

// Canvas_MSAA mirrors LOVE Canvas:getMSAA: the stored sample count. Always 0
// (LoadRenderTexture canvases have no per-canvas MSAA; window-level MSAA
// comes from Config.MSAA at creation time). Zero on bad handles.
Canvas_MSAA :: proc(ctx: ^Context, canvas: Canvas) -> int {
	if ctx == nil || ctx.backend == nil || canvas.handle == 0 {
		return 0
	}
	return backend.Canvas_MSAA_Samples(ctx.backend, canvas.handle)
}

// Shader_Has_Uniform mirrors LOVE Shader:hasUniform: whether name is an
// active uniform. False for nil ctx, empty names and unknown handles; driver
// optimized-out uniforms also report false, matching LOVE.
Shader_Has_Uniform :: proc(ctx: ^Context, shader: Shader, name: string) -> bool {
	if ctx == nil || ctx.backend == nil || shader.handle == 0 || len(name) == 0 {
		return false
	}
	return backend.Shader_Has_Uniform(ctx.backend, shader.handle, name)
}

// Shader_Warnings mirrors LOVE Shader:getWarnings. Documented stub: raylib
// exposes no compile-log query (diagnostics go to stdout at load), the
// backend retains no log, so this always returns "" — including for invalid
// handles. A non-empty string would be a fake.
Shader_Warnings :: proc(ctx: ^Context, shader: Shader) -> string {
	_ = ctx
	_ = shader
	return ""
}

// --- v0.10 wave 5: mesh accessors + texture introspection + niche GPU ---
//
// LOVE sources: love-api modules/graphics/types/{Mesh,Texture}.lua and the
// graphics module (getCanvas/getShader/isGammaCorrect/validateShader/
// discard). Wiki: docs/wiki/modules/Graphics.md. Conventions: ctx-first
// (pure value ops on Texture_Array mirror the ctx-free Quad precedent);
// getters return zero values on bad handles; only fallible ops return Error;
// draw paths no-op headless. Mesh indices are 0-based (LOVE ids are 1-based:
// subtract 1 when porting).

// mesh_to_internal maps a public vertex onto the backend upload format.
mesh_to_internal :: proc(v: Mesh_Vertex) -> backend.Mesh_Vertex_Internal {
	return backend.Mesh_Vertex_Internal{
		position_x = v.Position.X,
		position_y = v.Position.Y,
		uv_x = v.UV.X,
		uv_y = v.UV.Y,
		normal_x = v.Normal.X,
		normal_y = v.Normal.Y,
		r = v.Color.R,
		g = v.Color.G,
		b = v.Color.B,
		a = v.Color.A,
	}
}

// mesh_from_internal maps a backend vertex back onto the public format.
mesh_from_internal :: proc(v: backend.Mesh_Vertex_Internal) -> Mesh_Vertex {
	return Mesh_Vertex{
		Position = Vec2{v.position_x, v.position_y},
		UV = Vec2{v.uv_x, v.uv_y},
		Color = Color{v.r, v.g, v.b, v.a},
		Normal = Vec2{v.normal_x, v.normal_y},
	}
}

// Mesh_Vertex_At mirrors LOVE Mesh:getVertex: reads one vertex from the CPU
// copy every mesh keeps. Out-of-range indices report .Invalid_Data; unknown
// meshes (and nil/missing backends) report .Invalid_Handle, never fake data.
Mesh_Vertex_At :: proc(ctx: ^Context, mesh: Mesh, index: int) -> (Mesh_Vertex, Error) {
	if ctx == nil || ctx.backend == nil || mesh.handle == 0 {
		return Mesh_Vertex{}, .Invalid_Handle
	}
	if index < 0 {
		return Mesh_Vertex{}, .Invalid_Data
	}
	// Meshes always hold >= 1 vertex (Create/Update reject empty input), so
	// a zero count unambiguously signals an unknown mesh.
	if backend.Mesh_Vertex_Count(ctx.backend, mesh.handle) == 0 {
		return Mesh_Vertex{}, .Invalid_Handle
	}
	internal, ok := backend.Mesh_Vertex_At(ctx.backend, mesh.handle, index)
	if !ok {
		return Mesh_Vertex{}, .Invalid_Data
	}
	return mesh_from_internal(internal), .None
}

// Mesh_Vertex_Count mirrors LOVE Mesh:getVertexCount. Zero on bad handles.
Mesh_Vertex_Count :: proc(ctx: ^Context, mesh: Mesh) -> int {
	if ctx == nil || ctx.backend == nil || mesh.handle == 0 {
		return 0
	}
	return backend.Mesh_Vertex_Count(ctx.backend, mesh.handle)
}

// Mesh_Set_Vertex mirrors LOVE Mesh:setVertex (single-vertex variant):
// patches one vertex in the CPU copy and re-uploads the GPU buffers (the
// same unload/upload cycle Update_Mesh uses), so both copies stay in sync.
Mesh_Set_Vertex :: proc(ctx: ^Context, mesh: Mesh, index: int, vertex: Mesh_Vertex) -> Error {
	if ctx == nil || ctx.backend == nil || mesh.handle == 0 {
		return .Invalid_Handle
	}
	if index < 0 {
		return .Invalid_Data
	}
	if backend.Mesh_Vertex_Count(ctx.backend, mesh.handle) == 0 {
		return .Invalid_Handle
	}
	if !backend.Mesh_Set_Vertex(ctx.backend, mesh.handle, index, mesh_to_internal(vertex)) {
		return .Invalid_Data
	}
	return .None
}

// Mesh_Draw_Mode_Of mirrors LOVE Mesh:getDrawMode: the mode stored at
// creation (or by Mesh_Set_Draw_Mode). Unknown meshes report .Invalid_Handle.
Mesh_Draw_Mode_Of :: proc(ctx: ^Context, mesh: Mesh) -> (Mesh_Draw_Mode, Error) {
	if ctx == nil || ctx.backend == nil || mesh.handle == 0 {
		return .Triangles, .Invalid_Handle
	}
	ordinal, ok := backend.Mesh_Mode(ctx.backend, mesh.handle)
	if !ok || ordinal < 0 || ordinal > 3 {
		return .Triangles, .Invalid_Handle
	}
	return Mesh_Draw_Mode(ordinal), .None
}

// Mesh_Set_Draw_Mode mirrors LOVE Mesh:setDrawMode: switches the stored mode
// and rebuilds the GPU object (unload + upload). Non-triangle modes have no
// GPU upload path (upload accepts triangles only), so they draw via the CPU
// fallback — the same rule Create_Mesh applies. The switch itself always
// succeeds; only GPU residency varies.
Mesh_Set_Draw_Mode :: proc(ctx: ^Context, mesh: Mesh, mode: Mesh_Draw_Mode) -> Error {
	if ctx == nil || ctx.backend == nil || mesh.handle == 0 {
		return .Invalid_Handle
	}
	if !backend.Mesh_Set_Mode(ctx.backend, mesh.handle, int(mode)) {
		return .Invalid_Handle
	}
	return .None
}

// Mesh_Texture_Of mirrors LOVE Mesh:getTexture: the bound texture
// (Texture{} when none is bound). Unknown meshes report .Invalid_Handle.
Mesh_Texture_Of :: proc(ctx: ^Context, mesh: Mesh) -> (Texture, Error) {
	if ctx == nil || ctx.backend == nil || mesh.handle == 0 {
		return Texture{}, .Invalid_Handle
	}
	handle, ok := backend.Mesh_Texture(ctx.backend, mesh.handle)
	if !ok {
		return Texture{}, .Invalid_Handle
	}
	return Texture{handle}, .None
}

// Set_Mesh_Texture mirrors LOVE Mesh:setTexture: binds a texture so Draw_Mesh
// shades from it (matching LOVE draw(mesh) with a texture set).
// Texture{} clears the binding. A non-zero texture must name a live texture;
// a stale binding (texture unloaded after binding) draws untextured.
Set_Mesh_Texture :: proc(ctx: ^Context, mesh: Mesh, texture: Texture) -> Error {
	if ctx == nil || ctx.backend == nil || mesh.handle == 0 {
		return .Invalid_Handle
	}
	if texture.handle != 0 && !backend.Texture_Exists(ctx.backend, texture.handle) {
		return .Invalid_Handle
	}
	if !backend.Mesh_Set_Texture(ctx.backend, mesh.handle, texture.handle) {
		return .Invalid_Handle
	}
	return .None
}

// Mesh_Set_Draw_Range mirrors LOVE Mesh:setDrawRange: restricts drawing to
// indices [start, start + count). Count < 0 draws to the end (the default;
// reset with (0, -1)). Mirrors the SpriteBatch range validation: negative
// starts and count == 0 report .Invalid_Data. The end clamps at draw.
Mesh_Set_Draw_Range :: proc(ctx: ^Context, mesh: Mesh, start, count: int) -> Error {
	if ctx == nil || ctx.backend == nil || mesh.handle == 0 {
		return .Invalid_Handle
	}
	if !backend.Mesh_Set_Draw_Range(ctx.backend, mesh.handle, start, count) {
		return .Invalid_Data
	}
	return .None
}

// Mesh_Draw_Range mirrors LOVE Mesh:getDrawRange (subset form): the stored
// range (0-based start, count with -1 meaning "to the end"). (0, 0) on bad
// handles — count 0 is not settable, so it unambiguously signals a missing
// mesh (same convention as Sprite_Batch_Draw_Range).
Mesh_Draw_Range :: proc(ctx: ^Context, mesh: Mesh) -> (start, count: int) {
	if ctx == nil || ctx.backend == nil || mesh.handle == 0 {
		return 0, 0
	}
	range_start, range_count, ok := backend.Mesh_Draw_Range(ctx.backend, mesh.handle)
	if !ok {
		return 0, 0
	}
	return range_start, range_count
}

// Texture_Is_Readable mirrors LOVE Texture:isReadable: whether the texture
// can be drawn and sent to a shader. Always true for live textures — raylib
// textures are all readable, and LOVE's unreadable case (depth/stencil
// canvases) cannot be created here (Create_Canvas_Format rejects non-RGBA8).
// False for nil contexts, missing backends and unknown handles.
Texture_Is_Readable :: proc(ctx: ^Context, texture: Texture) -> bool {
	if ctx == nil || ctx.backend == nil || texture.handle == 0 {
		return false
	}
	return backend.Texture_Exists(ctx.backend, texture.handle)
}

// Texture_Mipmap_Count mirrors LOVE Texture:getMipmapCount. Honest value,
// not a constant: it reads the stored GL mipmap count. The backend never
// generates mipmaps (no GenTextureMipmaps call), so this is 1 for every live
// texture and 0 for unknown handles.
Texture_Mipmap_Count :: proc(ctx: ^Context, texture: Texture) -> int {
	if ctx == nil || ctx.backend == nil || texture.handle == 0 {
		return 0
	}
	return backend.Texture_Mipmaps(ctx.backend, texture.handle)
}

// Texture_Pixel_Size mirrors LOVE Texture:getPixelDimensions. Desktop builds
// run at DPI scale 1, so density-independent units and pixels coincide: this
// equals Texture_Size. (0, 0) on bad handles.
Texture_Pixel_Size :: proc(ctx: ^Context, texture: Texture) -> (width, height: int) {
	return Texture_Size(ctx, texture)
}

// Load_Texture_Array loads one Texture per path into an owned Texture_Array
// (LOVE newArrayImage subset). Raylib exposes no 2D array/volume texture API
// (LoadTextureCubemap is a 3D skybox samplerCube path with no 2D layer draw),
// so this is an honest CPU-side emulation — a layer list drawn one layer at
// a time — not a GPU array. On any failure the layers loaded so far are
// unloaded and the per-file error (e.g. .File_Not_Found) propagates.
Load_Texture_Array :: proc(ctx: ^Context, paths: []string) -> (Texture_Array, Error) {
	if ctx == nil || ctx.backend == nil {
		return Texture_Array{}, .Backend_Initialization_Failed
	}
	if len(paths) == 0 {
		return Texture_Array{}, .Invalid_Config
	}
	array := Texture_Array{}
	for path in paths {
		texture, err := Load_Texture(ctx, path)
		if err != .None {
			for layer in array.Layers {
				Unload_Texture(ctx, layer)
			}
			delete(array.Layers)
			return Texture_Array{}, err
		}
		append(&array.Layers, texture)
	}
	return array, .None
}

// Unload_Texture_Array unloads every layer and frees the layer list. Single
// owner: load once, unload once. Nil-safe.
Unload_Texture_Array :: proc(ctx: ^Context, array: ^Texture_Array) {
	if ctx == nil || array == nil {
		return
	}
	for layer in array.Layers {
		Unload_Texture(ctx, layer)
	}
	delete(array.Layers)
	array.Layers = nil
}

// Texture_Array_Layer_Count mirrors LOVE Texture:getLayerCount. Pure
// structural query over the value (no ctx, like Quad_Viewport).
Texture_Array_Layer_Count :: proc(array: Texture_Array) -> int {
	return len(array.Layers)
}

// Texture_Array_Layer returns one layer for direct use (draw, filter, shader
// send). Out-of-range layers report .Invalid_Data, never a fake texture.
Texture_Array_Layer :: proc(array: Texture_Array, layer: int) -> (Texture, Error) {
	if layer < 0 || layer >= len(array.Layers) {
		return Texture{}, .Invalid_Data
	}
	return array.Layers[layer], .None
}

// Draw_Texture_Array_Layer draws one array layer (the 2D answer to LOVE
// shader-side array sampling). Out-of-range layers and missing backends are
// silent no-ops, matching Draw_Texture.
Draw_Texture_Array_Layer :: proc(ctx: ^Context, array: Texture_Array, layer: int, position: Vec2, tint := White) {
	if ctx == nil || ctx.backend == nil {
		return
	}
	texture, err := Texture_Array_Layer(array, layer)
	if err != .None {
		return
	}
	Draw_Texture(ctx, texture, position, tint)
}

// Discard_Canvas mirrors LOVE Canvas:discard (perf hint: the contents are no
// longer needed). Real no-op with docs: the backend draws immediately with
// no deferred tile memory, so there is nothing to discard — this validates
// the handle and returns .None. Unknown canvases report .Invalid_Handle.
Discard_Canvas :: proc(ctx: ^Context, canvas: Canvas) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	if canvas.handle == 0 {
		return .Invalid_Handle
	}
	if ctx.backend != nil && !backend.Canvas_Exists(ctx.backend, canvas.handle) {
		return .Invalid_Handle
	}
	return .None
}

// Validate_Shader mirrors LOVE graphics.validateShader: whether the shader
// is a live, compiled program. Real check, not a stub: the backend compiles
// at load (Load_Shader fails on bad GLSL, so no log retention is needed —
// hence Shader_Warnings stays ""), and Unload removes the registry entry, so
// registry presence means a live GPU program. The message is "" when valid.
Validate_Shader :: proc(ctx: ^Context, shader: Shader) -> (valid: bool, message: string) {
	if ctx == nil || ctx.backend == nil {
		return false, "no graphics backend"
	}
	if shader.handle == 0 || !backend.Shader_Exists(ctx.backend, shader.handle) {
		return false, "unknown shader handle"
	}
	return true, ""
}

// Is_Gamma_Correct mirrors LOVE graphics.isGammaCorrect. Always false,
// documented: there is no sRGB framebuffer pipeline — colors pass through
// unmodified. (There are no manual SRGB<->linear helpers either; LOVE ports
// doing their own conversion keep working on raw channel values.)
Is_Gamma_Correct :: proc(ctx: ^Context) -> bool {
	_ = ctx
	return false
}

// Get_Active_Canvas mirrors LOVE graphics.getCanvas: the canvas Set_Canvas
// targeted, or (Canvas{}, false) when rendering to screen. False on nil
// contexts and headless backends.
Get_Active_Canvas :: proc(ctx: ^Context) -> (canvas: Canvas, active: bool) {
	if ctx == nil || ctx.backend == nil {
		return Canvas{}, false
	}
	handle, ok := backend.Active_Canvas_Handle(ctx.backend)
	if !ok {
		return Canvas{}, false
	}
	return Canvas{handle}, true
}

// Get_Active_Shader mirrors LOVE graphics.getShader: the Begin_Shader
// target, or (Shader{}, false) when no shader is active.
Get_Active_Shader :: proc(ctx: ^Context) -> (shader: Shader, active: bool) {
	if ctx == nil || ctx.backend == nil {
		return Shader{}, false
	}
	handle, ok := backend.Active_Shader_Handle(ctx.backend)
	if !ok {
		return Shader{}, false
	}
	return Shader{handle}, true
}

// Get_Transform_Stack_Depth returns the Push_Transform nesting depth (the
// backend transform stack length). Zero on nil/headless contexts, where
// pushes are no-ops.
Get_Transform_Stack_Depth :: proc(ctx: ^Context) -> int {
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	return backend.Transform_Stack_Depth(ctx.backend)
}
