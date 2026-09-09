package thor2d

import backend "thor2d:thor2d/internal/raylib"

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
