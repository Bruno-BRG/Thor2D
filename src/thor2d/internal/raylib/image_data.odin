package raylib_backend

import "core:c"
import "core:strings"
import rl "vendor:raylib"

Create_Texture_From_RGBA :: proc(state: rawptr, width, height: int, pixels: []u8) -> (u64, bool) {
	if state == nil || width <= 0 || height <= 0 || len(pixels) < width*height*4 {
		return 0, false
	}
	b := cast(^Backend)state
	image := rl.GenImageColor(c.int(width), c.int(height), rl.Color{0, 0, 0, 0})
	if !rl.IsImageValid(image) {
		return 0, false
	}
	for y := 0; y < height; y += 1 {
		for x := 0; x < width; x += 1 {
			index := (y*width+x)*4
			rl.ImageDrawPixel(&image, c.int(x), c.int(y), rl.Color{pixels[index], pixels[index+1], pixels[index+2], pixels[index+3]})
		}
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

Export_RGBA :: proc(width, height: int, pixels: []u8, path: string) -> bool {
	if width <= 0 || height <= 0 || len(pixels) < width*height*4 {
		return false
	}
	c_path, c_err := strings.clone_to_cstring(path, context.temp_allocator)
	if c_err != nil {
		return false
	}
	image := rl.GenImageColor(c.int(width), c.int(height), rl.Color{0, 0, 0, 0})
	if !rl.IsImageValid(image) {
		return false
	}
	for y := 0; y < height; y += 1 {
		for x := 0; x < width; x += 1 {
			index := (y*width+x)*4
			rl.ImageDrawPixel(&image, c.int(x), c.int(y), rl.Color{pixels[index], pixels[index+1], pixels[index+2], pixels[index+3]})
		}
	}
	ok := rl.ExportImage(image, c_path)
	rl.UnloadImage(image)
	return ok
}

Screenshot_RGBA :: proc(state: rawptr) -> (pixels: [dynamic]u8, width, height: int, ok: bool) {
	if state == nil {
		return nil, 0, 0, false
	}
	image := rl.LoadImageFromScreen()
	if !rl.IsImageValid(image) {
		return nil, 0, 0, false
	}
	defer rl.UnloadImage(image)
	rl.ImageFormat(&image, .UNCOMPRESSED_R8G8B8A8)
	width = int(image.width)
	height = int(image.height)
	if width <= 0 || height <= 0 || image.data == nil {
		return nil, 0, 0, false
	}
	size := int(rl.GetPixelDataSize(image.width, image.height, .UNCOMPRESSED_R8G8B8A8))
	if size != width*height*4 {
		return nil, 0, 0, false
	}
	pixels = make([dynamic]u8, size)
	copy(pixels[:], ([^]u8)(image.data)[:size])
	return pixels, width, height, true
}
