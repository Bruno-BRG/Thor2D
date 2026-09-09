package raylib_backend

import "core:c"
import "core:strings"
import rl "vendor:raylib"

// These entry points keep package-mounted assets inside the public filesystem
// contract. The normal path loaders remain for backwards compatibility, while
// the runtime can now decode bytes read from a source directory or .thor ZIP.
asset_file_type :: proc(path: string) -> (cstring, bool) {
	last_dot := -1
	for i := 0; i < len(path); i += 1 {
		if path[i] == '.' {
			last_dot = i
		}
	}
	if last_dot < 0 || last_dot+1 >= len(path) {
		return nil, false
	}
	extension, err := strings.clone_to_cstring(path[last_dot:], context.temp_allocator)
	if err != nil {
		return nil, false
	}
	return extension, true
}

Load_Texture_From_Memory :: proc(state: rawptr, path: string, data: []byte) -> (u64, bool) {
	if state == nil || len(data) == 0 {
		return 0, false
	}
	file_type, ok := asset_file_type(path)
	if !ok {
		return 0, false
	}
	b := cast(^Backend)state
	image := rl.LoadImageFromMemory(file_type, rawptr(&data[0]), c.int(len(data)))
	if !rl.IsImageValid(image) {
		return 0, false
	}
	texture := rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	if !rl.IsTextureValid(texture) {
		return 0, false
	}
	handle := b.next_handle
	b.next_handle += 1
	append(&b.textures, Texture_Entry{handle = handle, value = texture})
	return handle, true
}

Load_Font_From_Memory :: proc(state: rawptr, path: string, data: []byte, size: int) -> (u64, bool) {
	if state == nil || len(data) == 0 || size <= 0 {
		return 0, false
	}
	file_type, ok := asset_file_type(path)
	if !ok {
		return 0, false
	}
	b := cast(^Backend)state
	font := rl.LoadFontFromMemory(file_type, rawptr(&data[0]), c.int(len(data)), c.int(size), nil, 0)
	if !rl.IsFontValid(font) {
		return 0, false
	}
	handle := b.next_handle
	b.next_handle += 1
	append(&b.fonts, Font_Entry{handle = handle, value = font})
	return handle, true
}

Load_Sound_From_Memory :: proc(state: rawptr, path: string, data: []byte) -> (u64, bool) {
	// Audio resources are decoded by thor2d/internal/audio. Keep this legacy
	// entry point link-free so Raylib cannot pull its raudio module into the
	// executable alongside the dedicated miniaudio backend.
	return 0, false
}

Load_Music_From_Memory :: proc(state: rawptr, path: string, data: []byte) -> (u64, bool) {
	return 0, false
}

Load_Shader_From_Memory :: proc(state: rawptr, vertex, fragment: []byte) -> (u64, bool) {
	if state == nil || len(vertex) == 0 || len(fragment) == 0 {
		return 0, false
	}
	b := cast(^Backend)state
	vertex_code, vertex_err := strings.clone_to_cstring(string(vertex), context.temp_allocator)
	fragment_code, fragment_err := strings.clone_to_cstring(string(fragment), context.temp_allocator)
	if vertex_err != nil || fragment_err != nil {
		return 0, false
	}
	shader := rl.LoadShaderFromMemory(vertex_code, fragment_code)
	if !rl.IsShaderValid(shader) {
		return 0, false
	}
	handle := b.next_handle
	b.next_handle += 1
	append(&b.shaders, Shader_Entry{handle = handle, value = shader})
	return handle, true
}

Load_Texture_Cached_From_Memory :: proc(state: rawptr, path: string, data: []byte) -> (u64, u64, bool) {
	if state == nil {
		return 0, 0, false
	}
	b := cast(^Backend)state
	normalized, ok := normalize_asset_path(path)
	if !ok {
		return 0, 0, false
	}
	for entry in b.texture_cache {
		if entry.path == normalized {
			delete(normalized)
			return entry.handle, entry.asset_id, true
		}
	}
	handle, loaded := Load_Texture_From_Memory(state, normalized, data)
	if !loaded {
		delete(normalized)
		return 0, 0, false
	}
	asset_id := stable_asset_id(normalized)
	append(&b.texture_cache, Texture_Cache_Entry{path = normalized, handle = handle, asset_id = asset_id})
	return handle, asset_id, true
}

Load_Font_Cached_From_Memory :: proc(state: rawptr, path: string, data: []byte, size: int) -> (u64, u64, bool) {
	if state == nil {
		return 0, 0, false
	}
	b := cast(^Backend)state
	normalized, ok := normalize_asset_path(path)
	if !ok {
		return 0, 0, false
	}
	for entry in b.font_cache {
		if entry.path == normalized {
			delete(normalized)
			return entry.handle, entry.asset_id, true
		}
	}
	handle, loaded := Load_Font_From_Memory(state, normalized, data, size)
	if !loaded {
		delete(normalized)
		return 0, 0, false
	}
	asset_id := stable_asset_id(normalized)
	append(&b.font_cache, Font_Cache_Entry{path = normalized, handle = handle, asset_id = asset_id})
	return handle, asset_id, true
}

Load_Sound_Cached_From_Memory :: proc(state: rawptr, path: string, data: []byte) -> (u64, u64, bool) {
	if state == nil {
		return 0, 0, false
	}
	b := cast(^Backend)state
	normalized, ok := normalize_asset_path(path)
	if !ok {
		return 0, 0, false
	}
	for entry in b.sound_cache {
		if entry.path == normalized {
			delete(normalized)
			return entry.handle, entry.asset_id, true
		}
	}
	handle, loaded := Load_Sound_From_Memory(state, normalized, data)
	if !loaded {
		delete(normalized)
		return 0, 0, false
	}
	asset_id := stable_asset_id(normalized)
	append(&b.sound_cache, Sound_Cache_Entry{path = normalized, handle = handle, asset_id = asset_id})
	return handle, asset_id, true
}
