package thor2d

import corehash "core:hash"
import backend "thor2d:thor2d/internal/raylib"
import zlib "vendor:zlib"

New_Image_Data :: proc(width, height: int, fill := Color{0, 0, 0, 0}) -> (Image_Data, Error) {
	if width <= 0 || height <= 0 {
		return Image_Data{}, .Invalid_Config
	}
	data := Image_Data{Width = width, Height = height, Format = .RGBA8}
	data.Pixels = make([dynamic]u8, width*height*4)
	for y := 0; y < height; y += 1 {
		for x := 0; x < width; x += 1 {
			Set_Image_Pixel(&data, x, y, fill)
		}
	}
	return data, .None
}

Image_Data_From_Bytes :: proc(width, height: int, pixels: []u8) -> (Image_Data, Error) {
	if width <= 0 || height <= 0 || len(pixels) != width*height*4 {
		return Image_Data{}, .Invalid_Data
	}
	data := Image_Data{Width = width, Height = height, Format = .RGBA8}
	data.Pixels = make([dynamic]u8, len(pixels))
	copy(data.Pixels[:], pixels)
	return data, .None
}

Image_Data_From_Buffer :: proc(width, height: int, buffer: ^Byte_Buffer) -> (Image_Data, Error) {
	if buffer == nil {
		return Image_Data{}, .Invalid_Data
	}
	return Image_Data_From_Bytes(width, height, buffer.Bytes[:])
}

Destroy_Image_Data :: proc(data: ^Image_Data) {
	if data != nil {
		delete(data.Pixels)
		data^ = Image_Data{}
	}
}

Image_Data_Bytes :: proc(data: ^Image_Data) -> []u8 {
	if data == nil {
		return nil
	}
	return data.Pixels[:]
}

Get_Image_Pixel :: proc(data: ^Image_Data, x, y: int) -> (Color, Error) {
	if data == nil || x < 0 || y < 0 || x >= data.Width || y >= data.Height {
		return Color{}, .Invalid_Data
	}
	index := (y*data.Width+x)*4
	return Color{data.Pixels[index], data.Pixels[index+1], data.Pixels[index+2], data.Pixels[index+3]}, .None
}

Set_Image_Pixel :: proc(data: ^Image_Data, x, y: int, color: Color) -> Error {
	if data == nil || x < 0 || y < 0 || x >= data.Width || y >= data.Height {
		return .Invalid_Data
	}
	index := (y*data.Width+x)*4
	data.Pixels[index] = color.R
	data.Pixels[index+1] = color.G
	data.Pixels[index+2] = color.B
	data.Pixels[index+3] = color.A
	return .None
}

Create_Texture_From_Image_Data :: proc(ctx: ^Context, data: ^Image_Data) -> (Texture, Error) {
	if ctx == nil || ctx.backend == nil || data == nil {
		return Texture{}, .Backend_Initialization_Failed
	}
	handle, ok := backend.Create_Texture_From_RGBA(ctx.backend, data.Width, data.Height, data.Pixels[:])
	if !ok {
		return Texture{}, .Resource_Load_Failed
	}
	return Texture{handle}, .None
}

Export_Image_PNG :: proc(data: ^Image_Data, path: string) -> Error {
	if data == nil || !backend.Export_RGBA(data.Width, data.Height, data.Pixels[:], path) {
		return .Resource_Load_Failed
	}
	return .None
}

// Capture_Screenshot reads the current framebuffer into CPU-owned Image_Data.
// It is only available while a real graphics backend is active.
Capture_Screenshot :: proc(ctx: ^Context) -> (Image_Data, Error) {
	if ctx == nil || ctx.backend == nil {
		return Image_Data{}, .Capability_Unavailable
	}
	pixels, width, height, ok := backend.Screenshot_RGBA(ctx.backend)
	if !ok {
		return Image_Data{}, .Resource_Load_Failed
	}
	return Image_Data{Width = width, Height = height, Format = .RGBA8, Pixels = pixels}, .None
}

Convert_Image_Data :: proc(data: ^Image_Data, format: Image_Data_Format) -> (Image_Data, Error) {
	if data == nil || data.Width <= 0 || data.Height <= 0 || len(data.Pixels) != data.Width*data.Height*4 {
		return Image_Data{}, .Invalid_Data
	}
	if format != .RGBA8 {
		return Image_Data{}, .Unsupported
	}
	return Image_Data_From_Bytes(data.Width, data.Height, data.Pixels[:])
}

// Paste_Image copies every pixel of src onto dst with its top-left corner at
// (x, y), mirroring love.image ImageData:paste. Source pixels falling outside
// dst are clipped; a fully out-of-bounds paste is a successful no-op.
// RGBA8-only. Pure CPU, headless-safe, and safe to call from worker threads
// (it never touches Context or the GPU). An aliased self-paste (dst == src)
// copies via a snapshot so overlapping regions paste correctly.
Paste_Image :: proc(dst, src: ^Image_Data, x, y: int) -> Error {
	if dst == nil || src == nil {
		return .Invalid_Data
	}
	if dst.Width <= 0 || dst.Height <= 0 || src.Width <= 0 || src.Height <= 0 {
		return .Invalid_Data
	}
	if len(dst.Pixels) != dst.Width*dst.Height*4 || len(src.Pixels) != src.Width*src.Height*4 {
		return .Invalid_Data
	}
	if dst.Format != .RGBA8 || src.Format != .RGBA8 {
		return .Unsupported
	}
	source := src.Pixels[:]
	snapshot: [dynamic]u8
	if dst == src {
		snapshot = make([dynamic]u8, len(src.Pixels))
		copy(snapshot[:], src.Pixels[:])
		source = snapshot[:]
		defer delete(snapshot)
	}
	for sy := 0; sy < src.Height; sy += 1 {
		dy := y + sy
		if dy < 0 || dy >= dst.Height {
			continue
		}
		for sx := 0; sx < src.Width; sx += 1 {
			dx := x + sx
			if dx < 0 || dx >= dst.Width {
				continue
			}
			src_index := (sy*src.Width+sx)*4
			dst_index := (dy*dst.Width+dx)*4
			dst.Pixels[dst_index] = source[src_index]
			dst.Pixels[dst_index+1] = source[src_index+1]
			dst.Pixels[dst_index+2] = source[src_index+2]
			dst.Pixels[dst_index+3] = source[src_index+3]
		}
	}
	return .None
}

// Map_Pixel applies fn to every pixel of data in place, mirroring
// love.image ImageData:mapPixel. RGBA8-only. Pure CPU, headless-safe, and
// safe to call from worker threads (it never touches Context or the GPU).
Map_Pixel :: proc(data: ^Image_Data, fn: proc(c: Color) -> Color) -> Error {
	if data == nil || fn == nil {
		return .Invalid_Data
	}
	if data.Width <= 0 || data.Height <= 0 || len(data.Pixels) != data.Width*data.Height*4 {
		return .Invalid_Data
	}
	if data.Format != .RGBA8 {
		return .Unsupported
	}
	for i := 0; i < len(data.Pixels); i += 4 {
		mapped := fn(Color{data.Pixels[i], data.Pixels[i+1], data.Pixels[i+2], data.Pixels[i+3]})
		data.Pixels[i] = mapped.R
		data.Pixels[i+1] = mapped.G
		data.Pixels[i+2] = mapped.B
		data.Pixels[i+3] = mapped.A
	}
	return .None
}

_png_signature := [8]u8{137, 80, 78, 71, 13, 10, 26, 10}

_png_append_u32_be :: proc(out: ^[dynamic]u8, value: u32) {
	append(out, u8(value >> 24), u8(value >> 16), u8(value >> 8), u8(value))
}

_png_append_chunk :: proc(out: ^[dynamic]u8, chunk_type: string, data: []u8) {
	_png_append_u32_be(out, u32(len(data)))
	start := len(out)
	for i := 0; i < 4; i += 1 {
		append(out, chunk_type[i])
	}
	append(out, ..data)
	_png_append_u32_be(out, corehash.crc32(out[start:len(out)]))
}

// Encode_Image_PNG encodes RGBA8 Image_Data to a PNG file in memory,
// mirroring love.image ImageData:encode("png"). It is a minimal pure-CPU
// encoder (8-bit RGBA, filter 0, zlib IDAT via vendor:zlib): no window, no
// GPU, no backend, and no temp-file round-trip, so it is headless-safe and
// safe to call from worker threads. Decoding stays on the file/backend side;
// the output is standard PNG readable by any decoder.
Encode_Image_PNG :: proc(data: ^Image_Data) -> (Byte_Buffer, Error) {
	if data == nil || data.Width <= 0 || data.Height <= 0 {
		return Byte_Buffer{}, .Invalid_Data
	}
	if data.Format != .RGBA8 {
		return Byte_Buffer{}, .Unsupported
	}
	if len(data.Pixels) != data.Width*data.Height*4 {
		return Byte_Buffer{}, .Invalid_Data
	}
	stride := data.Width*4
	filtered := make([]u8, (stride+1)*data.Height)
	defer delete(filtered)
	for y := 0; y < data.Height; y += 1 {
		filtered[y*(stride+1)] = 0
		copy(filtered[y*(stride+1)+1:(y+1)*(stride+1)], data.Pixels[y*stride:(y+1)*stride])
	}
	bound := int(zlib.compressBound(zlib.uLong(len(filtered))))
	compressed := make([]u8, bound)
	defer delete(compressed)
	out_size := zlib.uLongf(bound)
	if zlib.compress2(&compressed[0], &out_size, &filtered[0], zlib.uLong(len(filtered)), zlib.DEFAULT_COMPRESSION) != zlib.OK {
		return Byte_Buffer{}, .Compression_Failed
	}
	out := make([dynamic]u8, 0, 8+13+12+int(out_size)+16+12)
	append(&out, .._png_signature[:])
	ihdr := make([dynamic]u8, 0, 13)
	defer delete(ihdr)
	_png_append_u32_be(&ihdr, u32(data.Width))
	_png_append_u32_be(&ihdr, u32(data.Height))
	append(&ihdr, 8, 6, 0, 0, 0)
	_png_append_chunk(&out, "IHDR", ihdr[:])
	_png_append_chunk(&out, "IDAT", compressed[:int(out_size)])
	_png_append_chunk(&out, "IEND", nil)
	return Byte_Buffer{Bytes = out}, .None
}

// v0.9 GPU-compressed image detection (mirrors love.image.isCompressed).
//
// LOVE's isCompressed means GPU-compressed texture formats (DXT/S3TC, ETC,
// ASTC, PVR, KTX containers) — NOT file compression like PNG/JPEG. PNG
// signatures and JPEG SOI markers therefore return false by design. Pure CPU
// magic-byte sniff, headless-safe and safe to call from worker threads.
Is_Compressed_Image :: proc(data: []u8) -> bool {
	if len(data) < 4 {
		return false
	}
	// DDS "DDS ".
	if data[0] == 0x44 && data[1] == 0x44 && data[2] == 0x53 && data[3] == 0x20 {
		return true
	}
	// PKM "PKM " (ETC1/ETC2 PKM container).
	if data[0] == 0x50 && data[1] == 0x4B && data[2] == 0x4D && data[3] == 0x20 {
		return true
	}
	// ASTC 13 AB A1 5C.
	if data[0] == 0x13 && data[1] == 0xAB && data[2] == 0xA1 && data[3] == 0x5C {
		return true
	}
	// PVR v3 "PVR\x03" (version 0x03525650 little-endian).
	if data[0] == 0x50 && data[1] == 0x56 && data[2] == 0x52 && data[3] == 0x03 {
		return true
	}
	// KTX1/KTX2 12-byte magic: AB 4B 54 58 20 31 31 / 32 30 BB 0D 0A 1A 0A.
	if len(data) >= 12 &&
		data[0] == 0xAB && data[1] == 0x4B && data[2] == 0x54 && data[3] == 0x58 &&
		data[4] == 0x20 && data[7] == 0xBB && data[8] == 0x0D && data[9] == 0x0A &&
		data[10] == 0x1A && data[11] == 0x0A &&
		((data[5] == 0x31 && data[6] == 0x31) || (data[5] == 0x32 && data[6] == 0x30)) {
		return true
	}
	return false
}

// v0.9 compressed texture loading (mirrors love.graphics.newImage over
// love.image.newCompressedData).
//
// Only GPU-compressed containers (see Is_Compressed_Image) are accepted;
// anything else — including valid PNG/JPEG files — is rejected with
// .Invalid_Data, never silently decompressed. Loading is extension-driven via
// backend.Load_Texture_From_Memory (raylib LoadImageFromMemory advertises DXT,
// ETC and ASTC GPU formats): a recognized container the backend cannot realize
// reports .Unsupported instead of a fake texture. Headless (no backend)
// reports .Backend_Initialization_Failed.
Load_Compressed_Texture :: proc(ctx: ^Context, path: string) -> (Texture, Error) {
	if ctx == nil || ctx.backend == nil {
		return Texture{}, .Backend_Initialization_Failed
	}
	file, file_err := Read_Path(&ctx.filesystem, path)
	if file_err != .None {
		return Texture{}, file_err
	}
	defer Destroy_File_Data(&file)
	if !Is_Compressed_Image(file.Bytes[:]) {
		return Texture{}, .Invalid_Data
	}
	handle, ok := backend.Load_Texture_From_Memory(ctx.backend, path, file.Bytes[:])
	if !ok {
		return Texture{}, .Unsupported
	}
	return Texture{handle}, .None
}
