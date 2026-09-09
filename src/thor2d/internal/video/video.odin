package video_backend

import "core:c"
import "core:strings"
import graphics "thor2d:thor2d/internal/raylib"

FFMPEG_ENABLED :: #config(THOR2D_FFMPEG, false)

when FFMPEG_ENABLED {
	foreign import ffmpeg {
		"lib/thor2d_video.a",
		"system:avformat",
		"system:avcodec",
		"system:swscale",
		"system:avutil",
		"system:m",
		"system:pthread",
	}

	foreign ffmpeg {
		thor_video_open :: proc "c" (path: cstring) -> rawptr ---
		thor_video_close :: proc "c" (video: rawptr) ---
		thor_video_play :: proc "c" (video: rawptr) ---
		thor_video_pause :: proc "c" (video: rawptr) ---
		thor_video_set_loop :: proc "c" (video: rawptr, looping: c.int) ---
		thor_video_seek :: proc "c" (video: rawptr, seconds: f64) -> c.int ---
		thor_video_update :: proc "c" (video: rawptr, delta: f64) -> c.int ---
		thor_video_frame :: proc "c" (video: rawptr, pixels: ^rawptr, width, height: ^c.int) -> c.int ---
		thor_video_duration :: proc "c" (video: rawptr) -> f64 ---
		thor_video_position :: proc "c" (video: rawptr) -> f64 ---
		thor_video_width :: proc "c" (video: rawptr) -> c.int ---
		thor_video_height :: proc "c" (video: rawptr) -> c.int ---
		thor_video_frame_rate :: proc "c" (video: rawptr) -> f64 ---
	}
}

// Keep the optional FFMPEG types behind the build flag while retaining a
// normal Odin import graph for the default build.
video_c_int :: proc(value: int) -> c.int {
	return c.int(value)
}

video_path_cstring :: proc(path: string) -> (cstring, bool) {
	value, err := strings.clone_to_cstring(path, context.temp_allocator)
	return value, err == nil
}

Video_Entry :: struct {
	handle: u64,
	decoder: rawptr,
	texture: u64,
	frame: [dynamic]u8,
	width, height: int,
	frame_rate: f64,
	duration, position: f64,
	looping: bool,
	playing: bool,
}

Video_Backend :: struct {
	next_handle: u64,
	entries: [dynamic]^Video_Entry,
}

Create :: proc() -> rawptr {
	backend := new(Video_Backend)
	backend.next_handle = 1
	return rawptr(backend)
}

find :: proc(backend: ^Video_Backend, handle: u64) -> (^Video_Entry, bool) {
	if backend == nil || handle == 0 {
		return nil, false
	}
	for entry in backend.entries {
		if entry.handle == handle {
			return entry, true
		}
	}
	return nil, false
}

Available :: proc() -> bool {
	when FFMPEG_ENABLED {
		return true
	} else {
		return false
	}
}

Load :: proc(state: rawptr, path: string) -> (u64, bool) {
	if state == nil || path == "" {
		return 0, false
	}
	when FFMPEG_ENABLED {
		backend := cast(^Video_Backend)state
		c_path, valid_path := video_path_cstring(path)
		if !valid_path {
			return 0, false
		}
		decoder := thor_video_open(c_path)
		if decoder == nil {
			return 0, false
		}
		entry := new(Video_Entry)
		entry.handle = backend.next_handle
		backend.next_handle += 1
		entry.decoder = decoder
		entry.width = int(thor_video_width(decoder))
		entry.height = int(thor_video_height(decoder))
		entry.frame_rate = thor_video_frame_rate(decoder)
		entry.duration = thor_video_duration(decoder)
		if entry.width <= 0 || entry.height <= 0 {
			thor_video_close(decoder)
			free(entry)
			return 0, false
		}
		append(&backend.entries, entry)
		return entry.handle, true
	} else {
		return 0, false
	}
}

Play :: proc(state: rawptr, handle: u64) -> bool {
	when FFMPEG_ENABLED {
		entry, found := find(cast(^Video_Backend)state, handle)
		if !found {
			return false
		}
		thor_video_play(entry.decoder)
		entry.playing = true
		return true
	} else {
		return false
	}
}

Pause :: proc(state: rawptr, handle: u64) -> bool {
	when FFMPEG_ENABLED {
		entry, found := find(cast(^Video_Backend)state, handle)
		if !found {
			return false
		}
		thor_video_pause(entry.decoder)
		entry.playing = false
		return true
	} else {
		return false
	}
}

Seek :: proc(state: rawptr, handle: u64, seconds: f64) -> bool {
	when FFMPEG_ENABLED {
		entry, found := find(cast(^Video_Backend)state, handle)
		if !found || thor_video_seek(entry.decoder, max(0, seconds)) == 0 {
			return false
		}
		entry.position = max(0, seconds)
		return true
	} else {
		return false
	}
}

Set_Loop :: proc(state: rawptr, handle: u64, looping: bool) -> bool {
	when FFMPEG_ENABLED {
		entry, found := find(cast(^Video_Backend)state, handle)
		if !found {
			return false
		}
		entry.looping = looping
		thor_video_set_loop(entry.decoder, video_c_int(1 if looping else 0))
		return true
	} else {
		return false
	}
}

Update :: proc(state: rawptr, graphics_state: rawptr, handle: u64, delta: f32) -> bool {
	when FFMPEG_ENABLED {
		backend := cast(^Video_Backend)state
		entry, found := find(backend, handle)
		if !found {
			return false
		}
		if entry.playing {
			thor_video_update(entry.decoder, f64(max(0, delta)))
		}
		pixels: rawptr
		width, height: c.int
		if thor_video_frame(entry.decoder, &pixels, &width, &height) == 0 || pixels == nil {
			entry.position = thor_video_position(entry.decoder)
			return true
		}
		size := int(width)*int(height)*4
		if size <= 0 {
			return false
		}
		delete(entry.frame)
		entry.frame = make([dynamic]u8, size)
		copy(entry.frame[:], ([^]u8)(pixels)[:size])
		if entry.texture != 0 && graphics_state != nil {
			graphics.Unload_Texture(graphics_state, entry.texture)
		}
		if graphics_state != nil {
			entry.texture, _ = graphics.Create_Texture_From_RGBA(graphics_state, int(width), int(height), entry.frame[:])
		}
		entry.width = int(width)
		entry.height = int(height)
		entry.position = thor_video_position(entry.decoder)
		return true
	} else {
		return false
	}
}

Draw :: proc(state: rawptr, graphics_state: rawptr, handle: u64, x, y, scale_x, scale_y: f32, r, g, b, a: u8) -> bool {
	if state == nil || graphics_state == nil {
		return false
	}
	entry, ok := find(cast(^Video_Backend)state, handle)
	if !ok || entry.texture == 0 {
		return false
	}
	graphics.Draw_Texture_Pro(graphics_state, entry.texture, 0, 0, f32(entry.width), f32(entry.height), x, y, f32(entry.width)*scale_x, f32(entry.height)*scale_y, 0, 0, 0, r, g, b, a)
	return true
}

Duration :: proc(state: rawptr, handle: u64) -> (f64, bool) {
	entry, found := find(cast(^Video_Backend)state, handle)
	if !found {
		return 0, false
	}
	return entry.duration, true
}

Position :: proc(state: rawptr, handle: u64) -> (f64, bool) {
	entry, found := find(cast(^Video_Backend)state, handle)
	if !found {
		return 0, false
	}
	return entry.position, true
}

Frame_Info :: proc(state: rawptr, handle: u64) -> (width, height: int, rate: f64, ok: bool) {
	entry, found := find(cast(^Video_Backend)state, handle)
	if !found {
		return 0, 0, 0, false
	}
	return entry.width, entry.height, entry.frame_rate, true
}

Unload :: proc(state: rawptr, graphics_state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	backend := cast(^Video_Backend)state
	for index := 0; index < len(backend.entries); index += 1 {
		entry := backend.entries[index]
		if entry.handle != handle {
			continue
		}
		when FFMPEG_ENABLED {
			thor_video_close(entry.decoder)
		}
		if entry.texture != 0 && graphics_state != nil {
			graphics.Unload_Texture(graphics_state, entry.texture)
		}
		delete(entry.frame)
		free(entry)
		unordered_remove(&backend.entries, index)
		return
	}
}

Destroy :: proc(state: rawptr, graphics_state: rawptr) {
	if state == nil {
		return
	}
	backend := cast(^Video_Backend)state
	for entry in backend.entries {
		when FFMPEG_ENABLED {
			thor_video_close(entry.decoder)
		}
		if entry.texture != 0 && graphics_state != nil {
			graphics.Unload_Texture(graphics_state, entry.texture)
		}
		delete(entry.frame)
		free(entry)
	}
	delete(backend.entries)
	free(backend)
}
