package raylib_backend

import "core:c"
import math "core:math"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

Create_Mesh :: proc(state: rawptr, vertices: []Mesh_Vertex_Internal, indices: []u32, mode: int) -> (u64, bool) {
	if state == nil || len(vertices) == 0 {
		return 0, false
	}
	b := cast(^Backend)state
	handle := b.next_handle
	b.next_handle += 1
	entry := Mesh_Entry{handle = handle, mode = mode, draw_start = 0, draw_count = -1}
	entry.vertices = make([dynamic]Mesh_Vertex_Internal, len(vertices))
	copy(entry.vertices[:], vertices)
	entry.positions = make([dynamic]f32, len(vertices)*2)
	entry.texcoords = make([dynamic]f32, len(vertices)*2)
	entry.normals = make([dynamic]f32, len(vertices)*2)
	entry.colors = make([dynamic]u8, len(vertices)*4)
	for vertex, i in vertices {
		entry.positions[i*2+0] = vertex.position_x
		entry.positions[i*2+1] = vertex.position_y
		entry.texcoords[i*2+0] = vertex.uv_x
		entry.texcoords[i*2+1] = vertex.uv_y
		entry.normals[i*2+0] = vertex.normal_x
		entry.normals[i*2+1] = vertex.normal_y
		entry.colors[i*4+0] = vertex.r
		entry.colors[i*4+1] = vertex.g
		entry.colors[i*4+2] = vertex.b
		entry.colors[i*4+3] = vertex.a
	}
	if len(indices) > 0 {
		entry.indices = make([dynamic]u32, len(indices))
		copy(entry.indices[:], indices)
	} else {
		count := len(vertices)
		entry.indices = make([dynamic]u32, count)
		for i := 0; i < count; i += 1 {
			entry.indices[i] = u32(i)
		}
	}
	entry.gpu_ready = upload_mesh_gpu(&entry)
	append(&b.meshes, entry)
	return handle, true
}

find_mesh :: proc(b: ^Backend, handle: u64) -> (^Mesh_Entry, bool) {
	for i := 0; i < len(b.meshes); i += 1 {
		if b.meshes[i].handle == handle {
			return &b.meshes[i], true
		}
	}
	return nil, false
}

Update_Mesh :: proc(state: rawptr, handle: u64, vertices: []Mesh_Vertex_Internal, indices: []u32) -> bool {
	if state == nil || len(vertices) == 0 {
		return false
	}
	entry, ok := find_mesh(cast(^Backend)state, handle)
	if !ok {
		return false
	}
	clear(&entry.vertices)
	entry.vertices = make([dynamic]Mesh_Vertex_Internal, len(vertices))
	copy(entry.vertices[:], vertices)
	delete(entry.positions)
	delete(entry.texcoords)
	delete(entry.normals)
	delete(entry.colors)
	entry.positions = make([dynamic]f32, len(vertices)*2)
	entry.texcoords = make([dynamic]f32, len(vertices)*2)
	entry.normals = make([dynamic]f32, len(vertices)*2)
	entry.colors = make([dynamic]u8, len(vertices)*4)
	for vertex, i in vertices {
		entry.positions[i*2+0] = vertex.position_x
		entry.positions[i*2+1] = vertex.position_y
		entry.texcoords[i*2+0] = vertex.uv_x
		entry.texcoords[i*2+1] = vertex.uv_y
		entry.normals[i*2+0] = vertex.normal_x
		entry.normals[i*2+1] = vertex.normal_y
		entry.colors[i*4+0] = vertex.r
		entry.colors[i*4+1] = vertex.g
		entry.colors[i*4+2] = vertex.b
		entry.colors[i*4+3] = vertex.a
	}
	if len(indices) > 0 {
		clear(&entry.indices)
		entry.indices = make([dynamic]u32, len(indices))
		copy(entry.indices[:], indices)
	}
	if entry.gpu_ready {
		unload_mesh_gpu(entry)
	}
	entry.gpu_ready = upload_mesh_gpu(entry)
	return true
}

Unload_Mesh :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	for i := 0; i < len(b.meshes); i += 1 {
		if b.meshes[i].handle == handle {
			if b.meshes[i].gpu_ready {
				unload_mesh_gpu(&b.meshes[i])
			}
			delete(b.meshes[i].vertices)
			delete(b.meshes[i].indices)
			delete(b.meshes[i].positions)
			delete(b.meshes[i].texcoords)
			delete(b.meshes[i].normals)
			delete(b.meshes[i].colors)
			unordered_remove(&b.meshes, i)
			return
		}
	}
}

upload_mesh_gpu :: proc(entry: ^Mesh_Entry) -> bool {
	if entry == nil || len(entry.positions) == 0 || entry.mode != 0 {
		return false
	}
	entry.gpu_vao = rlgl.LoadVertexArray()
	entry.gpu_position = rlgl.LoadVertexBuffer(raw_data(entry.positions), c.int(len(entry.positions)*size_of(f32)), false)
	entry.gpu_texcoord = rlgl.LoadVertexBuffer(raw_data(entry.texcoords), c.int(len(entry.texcoords)*size_of(f32)), false)
	entry.gpu_normal = rlgl.LoadVertexBuffer(raw_data(entry.normals), c.int(len(entry.normals)*size_of(f32)), false)
	entry.gpu_color = rlgl.LoadVertexBuffer(raw_data(entry.colors), c.int(len(entry.colors)*size_of(u8)), false)
	entry.gpu_indices = rlgl.LoadVertexBufferElement(raw_data(entry.indices), c.int(len(entry.indices)*size_of(u32)), false)
	if entry.gpu_vao == 0 || entry.gpu_position == 0 || entry.gpu_texcoord == 0 || entry.gpu_normal == 0 || entry.gpu_color == 0 || entry.gpu_indices == 0 {
		unload_mesh_gpu(entry)
		return false
	}
	rlgl.EnableVertexArray(entry.gpu_vao)
	rlgl.EnableVertexBuffer(entry.gpu_position)
	rlgl.SetVertexAttribute(0, 2, rlgl.FLOAT, false, 0, 0)
	rlgl.EnableVertexAttribute(0)
	rlgl.EnableVertexBuffer(entry.gpu_texcoord)
	rlgl.SetVertexAttribute(1, 2, rlgl.FLOAT, false, 0, 0)
	rlgl.EnableVertexAttribute(1)
	rlgl.EnableVertexBuffer(entry.gpu_normal)
	rlgl.SetVertexAttribute(2, 2, rlgl.FLOAT, false, 0, 0)
	rlgl.EnableVertexAttribute(2)
	rlgl.EnableVertexBuffer(entry.gpu_color)
	rlgl.SetVertexAttribute(3, 4, rlgl.UNSIGNED_BYTE, true, 0, 0)
	rlgl.EnableVertexAttribute(3)
	rlgl.EnableVertexBufferElement(entry.gpu_indices)
	rlgl.DisableVertexBufferElement()
	rlgl.DisableVertexBuffer()
	rlgl.DisableVertexArray()
	return true
}

unload_mesh_gpu :: proc(entry: ^Mesh_Entry) {
	if entry == nil {
		return
	}
	if entry.gpu_indices != 0 {
		rlgl.UnloadVertexBuffer(entry.gpu_indices)
	}
	if entry.gpu_color != 0 {
		rlgl.UnloadVertexBuffer(entry.gpu_color)
	}
	if entry.gpu_normal != 0 {
		rlgl.UnloadVertexBuffer(entry.gpu_normal)
	}
	if entry.gpu_texcoord != 0 {
		rlgl.UnloadVertexBuffer(entry.gpu_texcoord)
	}
	if entry.gpu_position != 0 {
		rlgl.UnloadVertexBuffer(entry.gpu_position)
	}
	if entry.gpu_vao != 0 {
		rlgl.UnloadVertexArray(entry.gpu_vao)
	}
	entry.gpu_vao = 0
	entry.gpu_position = 0
	entry.gpu_texcoord = 0
	entry.gpu_normal = 0
	entry.gpu_color = 0
	entry.gpu_indices = 0
	entry.gpu_ready = false
}

mesh_transform :: proc(position: rl.Vector2, origin, scale: rl.Vector2, rotation: f32) -> rl.Vector2 {
	x := (position.x-origin.x)*scale.x
	y := (position.y-origin.y)*scale.y
	radians := rotation * f32(math.PI) / 180
	cosine := f32(math.cos(radians))
	sine := f32(math.sin(radians))
	return rl.Vector2{x*cosine - y*sine + origin.x, x*sine + y*cosine + origin.y}
}

mesh_tint :: proc(a: rl.Color, b: rl.Color) -> rl.Color {
	return rl.Color{
		u8((u16(a.r)*u16(b.r))/255),
		u8((u16(a.g)*u16(b.g))/255),
		u8((u16(a.b)*u16(b.b))/255),
		u8((u16(a.a)*u16(b.a))/255),
	}
}

// mesh_draw_span resolves the LOVE setDrawRange subset to a clamped
// [start, end) span over the index list. An unset range (draw_count < 0)
// spans everything; a set range clamps the end at len(indices) and draws
// nothing when start is past the end.
mesh_draw_span :: proc(entry: ^Mesh_Entry) -> (start, end: int) {
	if entry == nil {
		return 0, 0
	}
	if entry.draw_count < 0 {
		return 0, len(entry.indices)
	}
	s := clamp(entry.draw_start, 0, len(entry.indices))
	e := min(s+max(0, entry.draw_count), len(entry.indices))
	return s, e
}

// mesh_bound_texture resolves the LOVE Mesh:getTexture binding: the bound
// texture while it still exists in the backend, nothing otherwise. A stale
// binding (texture unloaded after binding) draws untextured — documented on
// the public wrapper.
mesh_bound_texture :: proc(b: ^Backend, entry: ^Mesh_Entry) -> (rl.Texture2D, bool) {
	if entry == nil || entry.texture_handle == 0 {
		return rl.Texture2D{}, false
	}
	texture, ok := find_texture(b, entry.texture_handle)
	if !ok {
		return rl.Texture2D{}, false
	}
	return texture.value, true
}

draw_mesh_gpu :: proc(entry: ^Mesh_Entry, texture: rl.Texture2D, use_texture: bool, x, y, rotation, scale_x, scale_y: f32, start, end: int) {
	if entry == nil || !entry.gpu_ready {
		return
	}
	s := clamp(start, 0, len(entry.indices))
	e := clamp(end, s, len(entry.indices))
	if e <= s {
		return
	}
	rlgl.PushMatrix()
	rlgl.Translatef(x, y, 0)
	rlgl.Rotatef(rotation, 0, 0, 1)
	rlgl.Scalef(scale_x, scale_y, 1)
	if use_texture {
		rlgl.EnableTexture(texture.id)
	}
	rlgl.EnableVertexArray(entry.gpu_vao)
	rlgl.EnableVertexBuffer(entry.gpu_position)
	rlgl.EnableVertexBuffer(entry.gpu_texcoord)
	rlgl.EnableVertexBuffer(entry.gpu_normal)
	rlgl.EnableVertexBuffer(entry.gpu_color)
	if e-s == len(entry.indices) {
		rlgl.EnableVertexBufferElement(entry.gpu_indices)
		rlgl.DrawVertexArrayElements(0, c.int(len(entry.indices)), nil)
	} else {
		// Subset draw without relying on driver index-offset semantics:
		// the sliced indices go to a temporary element buffer that is
		// drawn from and dropped. Only paid when a custom range is set;
		// full draws keep the existing zero-upload path.
		tmp := rlgl.LoadVertexBufferElement(raw_data(entry.indices[s:e]), c.int((e-s)*size_of(u32)), false)
		if tmp != 0 {
			rlgl.EnableVertexBufferElement(tmp)
			rlgl.DrawVertexArrayElements(0, c.int(e-s), nil)
			rlgl.DisableVertexBufferElement()
			rlgl.DisableVertexBuffer()
			rlgl.UnloadVertexBuffer(tmp)
		}
	}
	rlgl.DisableVertexBufferElement()
	rlgl.DisableVertexBuffer()
	rlgl.DisableVertexArray()
	if use_texture {
		rlgl.DisableTexture()
	}
	rlgl.PopMatrix()
}

Draw_Mesh :: proc(state: rawptr, handle: u64, x, y, rotation, scale_x, scale_y: f32, r, g, b, a: u8) {
	if state == nil {
		return
	}
	backend := cast(^Backend)state
	entry, ok := find_mesh(backend, handle)
	if !ok {
		return
	}
	tint := rl.Color{r, g, b, a}
	if entry.gpu_ready {
		// v0.10: a bound texture (Set_Mesh_Texture) shades the GPU draw,
		// matching LOVE draw(mesh) with Mesh:getTexture set.
		texture, use_texture := mesh_bound_texture(backend, entry)
		s, e := mesh_draw_span(entry)
		draw_mesh_gpu(entry, texture, use_texture, x, y, rotation, scale_x, scale_y, s, e)
		return
	}
	points := make([dynamic]rl.Vector2, len(entry.vertices))
	defer delete(points)
	colors := make([dynamic]rl.Color, len(entry.vertices))
	defer delete(colors)
	for vertex, i in entry.vertices {
		local := mesh_transform(rl.Vector2{vertex.position_x, vertex.position_y}, rl.Vector2{}, rl.Vector2{scale_x, scale_y}, rotation)
		world := transform_point(backend.transform, rl.Vector2{local.x + x, local.y + y})
		points[i] = world
		colors[i] = mesh_tint(rl.Color{vertex.r, vertex.g, vertex.b, vertex.a}, tint)
	}

	// v0.10: a set draw range slices the index list (LOVE setDrawRange
	// restricts the vertex map). Unset, the span is the full list, so
	// triangulation is unchanged. Textured CPU draws stay flat-shaded:
	// the CPU path has no UV rasterizer (same documented limit as
	// Draw_Mesh_Textured below), so the bound texture only affects GPU.
	s, e := mesh_draw_span(entry)
	span := entry.indices[s:e]
	ranged := entry.draw_count >= 0
	switch entry.mode {
	case 0: // triangles
		for i := 0; i+2 < len(span); i += 3 {
		draw_mesh_triangle(points[:], colors[:], int(span[i]), int(span[i+1]), int(span[i+2]))
		}
	case 1: // fan
		for i := 1; i+1 < len(span); i += 1 {
			draw_mesh_triangle(points[:], colors[:], int(span[0]), int(span[i]), int(span[i+1]))
		}
	case 2: // strip
		for i := 0; i+2 < len(span); i += 1 {
			draw_mesh_triangle(points[:], colors[:], int(span[i]), int(span[i+1]), int(span[i+2]))
		}
	case 3: // points
		if ranged {
			for idx in span {
				if int(idx) >= 0 && int(idx) < len(points) {
					rl.DrawCircleV(points[idx], backend.point_size*0.5, tint)
				}
			}
		} else {
			for point in points {
				rl.DrawCircleV(point, backend.point_size*0.5, tint)
			}
		}
	}
}

Draw_Mesh_Textured :: proc(state: rawptr, handle, texture_handle: u64, x, y, rotation, scale_x, scale_y: f32) {
	if state == nil {
		return
	}
	backend := cast(^Backend)state
	entry, mesh_ok := find_mesh(backend, handle)
	texture, texture_ok := find_texture(backend, texture_handle)
	if !mesh_ok || !texture_ok {
		return
	}
	if entry.gpu_ready {
		s, e := mesh_draw_span(entry)
		draw_mesh_gpu(entry, texture.value, true, x, y, rotation, scale_x, scale_y, s, e)
	} else {
		Draw_Mesh(state, handle, x, y, rotation, scale_x, scale_y, 255, 255, 255, 255)
	}
}

draw_mesh_triangle :: proc(points: []rl.Vector2, colors: []rl.Color, i0, i1, i2: int) {
	if i0 < 0 || i1 < 0 || i2 < 0 || i0 >= len(points) || i1 >= len(points) || i2 >= len(points) {
		return
	}
	color := rl.Color{
		u8((u16(colors[i0].r)+u16(colors[i1].r)+u16(colors[i2].r))/3),
		u8((u16(colors[i0].g)+u16(colors[i1].g)+u16(colors[i2].g))/3),
		u8((u16(colors[i0].b)+u16(colors[i1].b)+u16(colors[i2].b))/3),
		u8((u16(colors[i0].a)+u16(colors[i1].a)+u16(colors[i2].a))/3),
	}
	rl.DrawTriangle(points[i0], points[i1], points[i2], color)
}

// v0.9 GPU instanced draw. Returns true when the mesh has resident GPU vertex
// buffers (gpu_ready) and all `count` copies were issued from them via
// draw_mesh_gpu, so no CPU triangulation happened; the caller maps that to
// Error.None. Returns false when the mesh is missing or has no GPU buffers
// (GL 1.1, non-triangle draw modes), in which case the caller falls back to
// the per-instance Draw_Mesh CPU path and reports .Unsupported.
//
// Design note (spike evidence): rlgl also exposes
// DrawVertexArrayElementsInstanced (single-call glDrawElementsInstanced) and
// raylib exposes DrawMeshInstanced (rl.Mesh + Material + per-instance Matrix
// array). Both were evaluated and deliberately NOT used here:
//   - The public API carries one shared transform, not a per-instance array,
//     so a single instanced call would rasterize N identical overlapping
//     copies — pixel-identical to this loop, with no visual or API gain.
//   - rl.DrawMeshInstanced needs an rl.Mesh/Material conversion that
//     duplicates the resident VBOs and needs shader/material setup the 2D
//     backend does not own.
//   - glDrawElementsInstanced is not core on OpenGL ES 2.0 without an
//     extension, while the draw_mesh_gpu path is already proven on every
//     backend configuration Draw_Mesh supports.
// A future per-instance-transform overload can adopt divisor attributes
// (rlgl.SetVertexAttributeDivisor exists) plus DrawVertexArrayElementsInstanced.
Draw_Mesh_Instanced :: proc(state: rawptr, handle: u64, count: int, x, y, rotation, scale_x, scale_y: f32, r, g, b, a: u8) -> bool {
	if state == nil || count <= 0 {
		return false
	}
	b := cast(^Backend)state
	entry, ok := find_mesh(b, handle)
	if !ok || !entry.gpu_ready {
		return false
	}
	// Tint matches Draw_Mesh GPU behavior: draw_mesh_gpu shades from the
	// per-vertex colors and ignores the flat tint on the GPU path.
	_ = r
	_ = g
	_ = b
	_ = a
	s, e := mesh_draw_span(entry)
	for i := 0; i < count; i += 1 {
		draw_mesh_gpu(entry, rl.Texture2D{}, false, x, y, rotation, scale_x, scale_y, s, e)
	}
	return true
}

// --- v0.10 wave 5 mesh accessors (LOVE Mesh getVertex/getVertexCount/
// setVertex/getDrawMode/setDrawMode/getTexture/setTexture/
// setDrawRange/getDrawRange subset). Indices are 0-based into the CPU vertex
// copy every mesh keeps (LOVE ids are 1-based: subtract 1 when porting).
// attachAttribute/detachAttribute, custom vertex formats, setVertices and
// the vertex map stay out of scope: the backend has one fixed format and
// treats indices as the map.

// Mesh_Vertex_At reads one vertex from the CPU copy.
Mesh_Vertex_At :: proc(state: rawptr, handle: u64, index: int) -> (Mesh_Vertex_Internal, bool) {
	if state == nil || index < 0 {
		return {}, false
	}
	entry, ok := find_mesh(cast(^Backend)state, handle)
	if !ok || index >= len(entry.vertices) {
		return {}, false
	}
	return entry.vertices[index], true
}

// Mesh_Vertex_Count returns the CPU vertex count (0 for unknown handles).
Mesh_Vertex_Count :: proc(state: rawptr, handle: u64) -> int {
	if state == nil {
		return 0
	}
	entry, ok := find_mesh(cast(^Backend)state, handle)
	if !ok {
		return 0
	}
	return len(entry.vertices)
}

// Mesh_Set_Vertex patches one vertex in the CPU copy plus the upload arrays
// and re-uploads the GPU buffers (same unload/upload cycle as Update_Mesh),
// so GPU and CPU copies stay in sync.
Mesh_Set_Vertex :: proc(state: rawptr, handle: u64, index: int, vertex: Mesh_Vertex_Internal) -> bool {
	if state == nil || index < 0 {
		return false
	}
	entry, ok := find_mesh(cast(^Backend)state, handle)
	if !ok || index >= len(entry.vertices) {
		return false
	}
	entry.vertices[index] = vertex
	entry.positions[index*2+0] = vertex.position_x
	entry.positions[index*2+1] = vertex.position_y
	entry.texcoords[index*2+0] = vertex.uv_x
	entry.texcoords[index*2+1] = vertex.uv_y
	entry.normals[index*2+0] = vertex.normal_x
	entry.normals[index*2+1] = vertex.normal_y
	entry.colors[index*4+0] = vertex.r
	entry.colors[index*4+1] = vertex.g
	entry.colors[index*4+2] = vertex.b
	entry.colors[index*4+3] = vertex.a
	if entry.gpu_ready {
		unload_mesh_gpu(entry)
	}
	entry.gpu_ready = upload_mesh_gpu(entry)
	return true
}

// Mesh_Mode returns the stored draw mode ordinal (matches Mesh_Draw_Mode
// order: 0=Triangles, 1=Triangle_Fan, 2=Triangle_Strip, 3=Points).
Mesh_Mode :: proc(state: rawptr, handle: u64) -> (int, bool) {
	if state == nil {
		return 0, false
	}
	entry, ok := find_mesh(cast(^Backend)state, handle)
	if !ok {
		return 0, false
	}
	return entry.mode, true
}

// Mesh_Set_Mode switches the stored draw mode and rebuilds the GPU object
// (unload + upload). Non-triangle modes have no GPU upload path
// (upload_mesh_gpu accepts mode 0 only), so they draw via the CPU fallback —
// the same rule Create_Mesh applies. The mode switch itself always succeeds
// for valid modes; only GPU residency varies. Mode must be 0..3.
Mesh_Set_Mode :: proc(state: rawptr, handle: u64, mode: int) -> bool {
	if state == nil || mode < 0 || mode > 3 {
		return false
	}
	entry, ok := find_mesh(cast(^Backend)state, handle)
	if !ok {
		return false
	}
	entry.mode = mode
	if entry.gpu_ready {
		unload_mesh_gpu(entry)
	}
	entry.gpu_ready = upload_mesh_gpu(entry)
	return true
}

// Mesh_Texture returns the bound texture handle (0 = none).
Mesh_Texture :: proc(state: rawptr, handle: u64) -> (u64, bool) {
	if state == nil {
		return 0, false
	}
	entry, ok := find_mesh(cast(^Backend)state, handle)
	if !ok {
		return 0, false
	}
	return entry.texture_handle, true
}

// Mesh_Set_Texture binds a texture for Draw_Mesh (LOVE Mesh:setTexture).
// Texture 0 clears the binding; any other handle must name a live texture.
Mesh_Set_Texture :: proc(state: rawptr, handle, texture: u64) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Backend)state
	entry, ok := find_mesh(b, handle)
	if !ok {
		return false
	}
	if texture != 0 {
		if _, tex_ok := find_texture(b, texture); !tex_ok {
			return false
		}
	}
	entry.texture_handle = texture
	return true
}

// Mesh_Draw_Range returns the stored draw range (0-based start, count with
// -1 meaning "to the end"). (0, -1) is the default (draw all).
Mesh_Draw_Range :: proc(state: rawptr, handle: u64) -> (start, count: int, ok: bool) {
	if state == nil {
		return 0, 0, false
	}
	entry, found := find_mesh(cast(^Backend)state, handle)
	if !found {
		return 0, 0, false
	}
	return entry.draw_start, entry.draw_count, true
}

// Mesh_Set_Draw_Range restricts drawing to indices [start, start+count)
// (LOVE Mesh:setDrawRange; 0-based, count < 0 draws to the end, reset with
// (0, -1)). Mirrors the SpriteBatch range validation: negative starts and
// count == 0 report failure. The end clamps at draw (see mesh_draw_span).
Mesh_Set_Draw_Range :: proc(state: rawptr, handle: u64, start, count: int) -> bool {
	if state == nil || start < 0 || (count <= 0 && count != -1) {
		return false
	}
	entry, ok := find_mesh(cast(^Backend)state, handle)
	if !ok {
		return false
	}
	entry.draw_start = start
	entry.draw_count = count
	return true
}
