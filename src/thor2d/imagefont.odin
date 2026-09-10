package thor2d

import "core:strings"

// v0.9 image fonts (mirrors love.graphics.newImageFont).
//
// Design: CPU-side Image_Font (see types.odin), not a backend Font. The raylib
// backend only offers LoadFontFromImage(image, key, firstChar), which assumes
// sequential codepoints starting at firstChar and cannot represent LOVE's
// arbitrary glyph-string ordering (e.g. glyphs "ABC...xyz012..."). Slicing the
// Image_Data into per-glyph cells on the CPU and drawing textured quads
// through Draw_Texture_Pro keeps LOVE semantics exact: glyph i of the glyph
// string occupies cell i, cell width = image.width / len(glyphs), one row.
//
// LOVE convention reproduced here:
//   - glyphs run left-to-right in a single row, equal-width cells;
//   - ASCII only: Load_Image_Font rejects glyph strings with bytes >= 128
//     (.Invalid_Data) instead of mis-slicing multibyte UTF-8;
//   - text bytes absent from the glyph string advance by one blank cell width
//     (documented choice; LOVE ports should keep text to the glyph set);
//   - '\n' in drawn/measured text starts a new line one cell tall.
//
// Headless-safe: with no graphics backend (or a headless context) the font
// keeps its CPU data and a zero Texture; Measure_Text_Image_Font and
// Unload_Image_Font keep working, Draw_Text_Image_Font is a silent no-op.
// Worker threads must still not touch Context (draw path takes ctx).

// Load_Image_Font registers image as an image font for glyphs, LOVE
// newImageFont style. image is copied into a GPU texture when a backend is
// present; the Image_Data itself stays caller-owned. Returns .Invalid_Data
// for empty/non-ASCII glyphs, non-positive cells, or image.width not divisible
// by len(glyphs).
Load_Image_Font :: proc(ctx: ^Context, image: Image_Data, glyphs: string) -> (Image_Font, Error) {
	if ctx == nil {
		return Image_Font{}, .Backend_Initialization_Failed
	}
	if image.Width <= 0 || image.Height <= 0 || len(image.Pixels) != image.Width*image.Height*4 {
		return Image_Font{}, .Invalid_Data
	}
	if len(glyphs) == 0 || image.Width % len(glyphs) != 0 {
		return Image_Font{}, .Invalid_Data
	}
	cell_w := image.Width / len(glyphs)
	if cell_w <= 0 {
		return Image_Font{}, .Invalid_Data
	}
	for i := 0; i < len(glyphs); i += 1 {
		if glyphs[i] >= 128 {
			return Image_Font{}, .Invalid_Data
		}
	}
	owned, clone_err := strings.clone(glyphs)
	if clone_err != nil {
		return Image_Font{}, .Resource_Load_Failed
	}
	font := Image_Font{Glyphs = owned, Cell_W = cell_w, Cell_H = image.Height}
	if ctx.backend == nil || ctx.headless {
		return font, .None
	}
	img := image
	texture, tex_err := Create_Texture_From_Image_Data(ctx, &img)
	if tex_err != .None {
		delete(owned)
		return Image_Font{}, tex_err
	}
	font.Texture = texture
	return font, .None
}

// Unload_Image_Font releases the font texture (when present) and the owned
// glyph clone, then zeroes the struct. Safe on zero/invalid fonts and nil ctx.
Unload_Image_Font :: proc(ctx: ^Context, font: ^Image_Font) {
	if font == nil {
		return
	}
	if ctx != nil && ctx.backend != nil && font.Texture.handle != 0 {
		Unload_Texture(ctx, font.Texture)
	}
	if len(font.Glyphs) > 0 {
		delete(font.Glyphs)
	}
	font^ = Image_Font{}
}

// Draw_Text_Image_Font draws text with an image font at position (top-left of
// the first cell), uniformly scaled by scale and tinted. No-op when ctx or the
// backend is nil, the font has no texture (e.g. headless), scale <= 0, or text
// is empty.
Draw_Text_Image_Font :: proc(ctx: ^Context, font: Image_Font, text: string, position: Vec2, scale: f32, tint: Color) {
	if ctx == nil || ctx.backend == nil || font.Texture.handle == 0 || len(font.Glyphs) == 0 || font.Cell_W <= 0 || font.Cell_H <= 0 || scale <= 0 || len(text) == 0 {
		return
	}
	x := position.X
	y := position.Y
	advance := f32(font.Cell_W) * scale
	line_h := f32(font.Cell_H) * scale
	for i := 0; i < len(text); i += 1 {
		b := text[i]
		if b == '\n' {
			x = position.X
			y += line_h
			continue
		}
		index := image_font_glyph_index(font.Glyphs, b)
		if index < 0 {
			x += advance
			continue
		}
		source := Rect{f32(index*font.Cell_W), 0, f32(font.Cell_W), f32(font.Cell_H)}
		dest := Rect{x, y, f32(font.Cell_W)*scale, f32(font.Cell_H)*scale}
		Draw_Texture_Pro(ctx, font.Texture, source, dest, Vec2{}, 0, tint)
		x += advance
	}
}

// Measure_Text_Image_Font measures text in pixels at uniform scale without
// touching the GPU, so it works headless and on fonts loaded without a
// backend. Returns {} for invalid fonts, scale <= 0, empty text, or nil ctx.
Measure_Text_Image_Font :: proc(ctx: ^Context, font: Image_Font, text: string, scale: f32) -> Vec2 {
	if ctx == nil || len(font.Glyphs) == 0 || font.Cell_W <= 0 || font.Cell_H <= 0 || scale <= 0 || len(text) == 0 {
		return Vec2{}
	}
	lines := 1
	longest := 0
	current := 0
	for i := 0; i < len(text); i += 1 {
		if text[i] == '\n' {
			longest = max(longest, current)
			current = 0
			lines += 1
			continue
		}
		current += 1
	}
	longest = max(longest, current)
	return Vec2{f32(longest*font.Cell_W) * scale, f32(lines*font.Cell_H) * scale}
}

image_font_glyph_index :: proc(glyphs: string, b: byte) -> int {
	for i := 0; i < len(glyphs); i += 1 {
		if glyphs[i] == b {
			return i
		}
	}
	return -1
}
