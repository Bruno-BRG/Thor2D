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
	entry := Mesh_Entry{handle = handle, mode = mode}
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

draw_mesh_gpu :: proc(entry: ^Mesh_Entry, texture: rl.Texture2D, use_texture: bool, x, y, rotation, scale_x, scale_y: f32) {
	if entry == nil || !entry.gpu_ready {
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
	rlgl.EnableVertexBufferElement(entry.gpu_indices)
	rlgl.DrawVertexArrayElements(0, c.int(len(entry.indices)), nil)
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
		draw_mesh_gpu(entry, rl.Texture2D{}, false, x, y, rotation, scale_x, scale_y)
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

	switch entry.mode {
	case 0: // triangles
		for i := 0; i+2 < len(entry.indices); i += 3 {
		draw_mesh_triangle(points[:], colors[:], int(entry.indices[i]), int(entry.indices[i+1]), int(entry.indices[i+2]))
		}
	case 1: // fan
		for i := 1; i+1 < len(entry.indices); i += 1 {
			draw_mesh_triangle(points[:], colors[:], int(entry.indices[0]), int(entry.indices[i]), int(entry.indices[i+1]))
		}
	case 2: // strip
		for i := 0; i+2 < len(entry.indices); i += 1 {
			draw_mesh_triangle(points[:], colors[:], int(entry.indices[i]), int(entry.indices[i+1]), int(entry.indices[i+2]))
		}
	case 3: // points
		for point in points {
			rl.DrawCircleV(point, backend.point_size*0.5, tint)
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
		draw_mesh_gpu(entry, texture.value, true, x, y, rotation, scale_x, scale_y)
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
