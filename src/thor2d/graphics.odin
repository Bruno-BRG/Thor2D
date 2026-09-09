package thor2d

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
