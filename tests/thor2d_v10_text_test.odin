package tests

import "core:os"
import "core:testing"
import thor2d "thor2d:thor2d"

// v0.10 text/canvas/shader completion (LOVE Font/Text/Quad/SpriteBatch/Canvas/
// Shader parity). Headless-safe: GPU-backed resources cannot exist without a
// backend, so headless tests assert explicit errors and stored/zero values.
// Windowed tests run only when a window can be created (DISPLAY=:0 here) and
// return early otherwise — never failing for lack of a display.

v10t_headless_ctx :: proc(t: ^testing.T) -> (thor2d.Context, bool) {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	if !testing.expect(t, err == .None) {
		return ctx, false
	}
	return ctx, true
}

// v10t_windowed_ctx tries a small windowed context for success-path tests.
// Returns ok=false when no display/backend is available; callers must return
// early (skip), not fail.
v10t_windowed_ctx :: proc(t: ^testing.T) -> (thor2d.Context, bool) {
	_ = t
	config := thor2d.Default_Config()
	config.Headless = false
	config.Width = 320
	config.Height = 240
	config.Save_Directory = ".thor2d-test-save"
	ctx, err := thor2d.Create(config)
	if err != .None {
		return ctx, false
	}
	return ctx, true
}

v10t_cleanup_save :: proc() {
	os.remove_all(".thor2d-test-save")
}

// Odin nested procs cannot capture locals, so render_to probes use a
// package flag (tests run single-threaded).
v10t_render_flag: bool

v10t_mark_drawn :: proc(ctx: ^thor2d.Context) {
	_ = ctx
	v10t_render_flag = true
}

v10t_paint_canvas :: proc(ctx: ^thor2d.Context) {
	v10t_render_flag = true
	thor2d.Clear(ctx, thor2d.Red)
	thor2d.Draw_Rect(ctx, thor2d.Rect{W = 8, H = 8}, thor2d.Blue)
}

@(test)
test_v10t_font_metrics_headless :: proc(t: ^testing.T) {
	ctx, ok := v10t_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	def := thor2d.Font{}

	// Default-font ratios work headless (pure CPU): ascent 0.8em, descent
	// 0.2em, baseline at the ascent, advance == size at multiplier 1.0.
	testing.expect(t, thor2d.Font_Ascent(&ctx, def, 16) == 12.8)
	testing.expect(t, thor2d.Font_Descent(&ctx, def, 16) == 3.2)
	testing.expect(t, thor2d.Font_Baseline(&ctx, def, 16) == 12.8)
	testing.expect(t, thor2d.Font_Line_Height(&ctx, def, 16) == 16)
	ascent := thor2d.Font_Ascent(&ctx, def, 20)
	descent := thor2d.Font_Descent(&ctx, def, 20)
	line := thor2d.Font_Line_Height(&ctx, def, 20)
	testing.expect(t, line > 0 && ascent+descent == line)

	// Bad handles report zero, never fake numbers.
	testing.expect(t, thor2d.Font_Ascent(&ctx, thor2d.Font{handle = 999}, 16) == 0)
	testing.expect(t, thor2d.Font_Descent(&ctx, thor2d.Font{handle = 999}, 16) == 0)
	testing.expect(t, thor2d.Font_Baseline(&ctx, thor2d.Font{handle = 999}, 16) == 0)
	testing.expect(t, thor2d.Font_Line_Height(&ctx, thor2d.Font{handle = 999}, 16) == 0)
	testing.expect(t, thor2d.Font_Ascent(nil, def, 16) == 0)
	testing.expect(t, thor2d.Font_Ascent(&ctx, def, 0) == 0)
	testing.expect(t, thor2d.Font_Ascent(&ctx, def, -4) == 0)

	// Line-height multiplier defaults to 1.0; headless sets are no-ops.
	testing.expect(t, thor2d.Font_Get_Line_Height(&ctx, def) == 1.0)
	testing.expect(t, thor2d.Font_Get_Line_Height(&ctx, thor2d.Font{handle = 999}) == 0)
	testing.expect(t, thor2d.Font_Get_Line_Height(nil, def) == 0)
	thor2d.Font_Set_Line_Height(&ctx, def, 2.0)
	testing.expect(t, thor2d.Font_Get_Line_Height(&ctx, def) == 1.0)
	thor2d.Font_Set_Line_Height(nil, def, 2.0)

	// Glyph coverage: empty is vacuously true; headless default font assumes
	// ASCII; non-ASCII and unknown handles report false.
	testing.expect(t, thor2d.Font_Has_Glyphs(&ctx, def, "") == true)
	testing.expect(t, thor2d.Font_Has_Glyphs(&ctx, def, "hello ABC 123") == true)
	testing.expect(t, thor2d.Font_Has_Glyphs(&ctx, def, "h\xc3\xa9llo") == false)
	testing.expect(t, thor2d.Font_Has_Glyphs(&ctx, def, "\xff") == false)
	testing.expect(t, thor2d.Font_Has_Glyphs(&ctx, thor2d.Font{handle = 999}, "hi") == false)
	testing.expect(t, thor2d.Font_Has_Glyphs(nil, def, "hi") == false)

	// DPI scale mirrors the window scale: 1.0 headless, 0 on bad handles.
	testing.expect(t, thor2d.Font_DPI_Scale(&ctx, def) == 1.0)
	testing.expect(t, thor2d.Font_DPI_Scale(&ctx, thor2d.Font{handle = 999}) == 0)
}

@(test)
test_v10t_quad_viewport_roundtrip :: proc(t: ^testing.T) {
	// Pure CPU value semantics: no context needed, works everywhere.
	q := thor2d.New_Quad(thor2d.Texture{}, thor2d.Rect{X = 1, Y = 2, W = 8, H = 16})
	testing.expect(t, thor2d.Quad_Viewport(q) == thor2d.Rect{X = 1, Y = 2, W = 8, H = 16})
	w, h := thor2d.Quad_Texture_Size(q)
	testing.expect(t, w == 0 && h == 0)

	moved := thor2d.Quad_Set_Viewport(q, thor2d.Rect{X = 4, Y = 4, W = 2, H = 2})
	testing.expect(t, thor2d.Quad_Viewport(moved) == thor2d.Rect{X = 4, Y = 4, W = 2, H = 2})
	// Original untouched; texture dims preserved.
	testing.expect(t, thor2d.Quad_Viewport(q) == thor2d.Rect{X = 1, Y = 2, W = 8, H = 16})

	sized := thor2d.New_Quad_From_Texture(nil, thor2d.Texture{}, thor2d.Rect{W = 4, H = 4})
	sized = thor2d.Quad_Set_Viewport(sized, thor2d.Rect{X = 0, Y = 0, W = 4, H = 4}, 64, 32)
	testing.expect(t, thor2d.Quad_Viewport(sized) == thor2d.Rect{X = 0, Y = 0, W = 4, H = 4})
	w, h = thor2d.Quad_Texture_Size(sized)
	testing.expect(t, w == 64 && h == 32)
	// Non-positive reference sizes keep the stored dims (LOVE optional sw/sh).
	kept := thor2d.Quad_Set_Viewport(sized, thor2d.Rect{X = 1, Y = 1, W = 2, H = 2}, -1, 0)
	w, h = thor2d.Quad_Texture_Size(kept)
	testing.expect(t, w == 64 && h == 32)
}

@(test)
test_v10t_text_invalid_handles :: proc(t: ^testing.T) {
	ctx, ok := v10t_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	bad := thor2d.Text{handle = 999}

	// Headless: no backend owns texts, so creation fails loudly.
	_, err := thor2d.Create_Text(&ctx, thor2d.Font{}, "hi", 16)
	testing.expect(t, err != .None)
	testing.expect(t, thor2d.Text_Add(&ctx, bad, "x") == .Invalid_Handle)
	testing.expect(t, thor2d.Text_Addf(&ctx, bad, "%d", 1) == .Invalid_Handle)
	testing.expect(t, thor2d.Text_Clear(&ctx, bad) == .Invalid_Handle)
	testing.expect(t, thor2d.Text_Set_Font(&ctx, bad, thor2d.Font{}) == .Invalid_Handle)
	testing.expect(t, thor2d.Text_Font(&ctx, bad) == thor2d.Font{})
	testing.expect(t, thor2d.Text_Font(&ctx, thor2d.Text{}) == thor2d.Font{})

	// Nil-context variants never crash.
	testing.expect(t, thor2d.Text_Add(nil, bad, "x") == .Invalid_Handle)
	testing.expect(t, thor2d.Text_Addf(nil, bad, "x") == .Invalid_Handle)
	testing.expect(t, thor2d.Text_Clear(nil, bad) == .Invalid_Handle)
	testing.expect(t, thor2d.Text_Set_Font(nil, bad, thor2d.Font{}) == .Invalid_Handle)
	testing.expect(t, thor2d.Text_Font(nil, bad) == thor2d.Font{})
}

@(test)
test_v10t_batch_invalid_handles :: proc(t: ^testing.T) {
	ctx, ok := v10t_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	bad := thor2d.Sprite_Batch{handle = 999}
	src := thor2d.Rect{W = 4, H = 4}
	dst := thor2d.Rect{W = 4, H = 4}

	testing.expect(t, thor2d.Sprite_Batch_Count(&ctx, bad) == 0)
	testing.expect(t, thor2d.Sprite_Batch_Count(nil, bad) == 0)
	testing.expect(t, thor2d.Sprite_Batch_Set(&ctx, bad, 0, src, dst, thor2d.Vec2{}, 0) == .Invalid_Handle)
	testing.expect(t, thor2d.Sprite_Batch_Set(nil, bad, 0, src, dst, thor2d.Vec2{}, 0) == .Invalid_Handle)
	testing.expect(t, thor2d.Sprite_Batch_Set_Color(&ctx, bad, 0, thor2d.Red) == .Invalid_Handle)
	testing.expect(t, thor2d.Sprite_Batch_Set_Color(nil, bad, 0, thor2d.Red) == .Invalid_Handle)
	testing.expect(t, thor2d.Sprite_Batch_Set_Draw_Range(&ctx, bad, 0, 1) == .Invalid_Handle)
	testing.expect(t, thor2d.Sprite_Batch_Set_Draw_Range(nil, bad, 0, 1) == .Invalid_Handle)
	start, count := thor2d.Sprite_Batch_Draw_Range(&ctx, bad)
	testing.expect(t, start == 0 && count == 0)
	start, count = thor2d.Sprite_Batch_Draw_Range(nil, bad)
	testing.expect(t, start == 0 && count == 0)
	// Draw/unload paths no-op on bad handles.
	thor2d.Draw_Sprite_Batch(&ctx, bad)
	thor2d.Draw_Sprite_Batch(nil, bad)
	thor2d.Unload_Sprite_Batch(&ctx, bad)
	thor2d.Clear_Sprite_Batch(&ctx, bad)
}

@(test)
test_v10t_canvas_render_to_nilsafe :: proc(t: ^testing.T) {
	// Nil context / nil draw never crash.
	thor2d.Canvas_Render_To(nil, thor2d.Canvas{}, nil)
	thor2d.Canvas_Render_To(nil, thor2d.Canvas{handle = 1}, nil)

	ctx, ok := v10t_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	thor2d.Canvas_Render_To(&ctx, thor2d.Canvas{}, nil)

	// Headless: set/reset are backend no-ops, draw still runs.
	v10t_render_flag = false
	thor2d.Canvas_Render_To(&ctx, thor2d.Canvas{}, v10t_mark_drawn)
	testing.expect(t, v10t_render_flag)

	// Invalid canvas still invokes draw (documented Set_Canvas parity).
	v10t_render_flag = false
	thor2d.Canvas_Render_To(&ctx, thor2d.Canvas{handle = 999}, v10t_mark_drawn)
	testing.expect(t, v10t_render_flag)
}

@(test)
test_v10t_canvas_headless_errors :: proc(t: ^testing.T) {
	ctx, ok := v10t_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)

	// Headless readback is unavailable (matches Capture_Screenshot); MSAA is
	// stored state, 0 without a backend.
	_, err := thor2d.Canvas_To_Image(&ctx, thor2d.Canvas{handle = 999})
	testing.expect(t, err != .None)
	_, err = thor2d.Canvas_To_Image(nil, thor2d.Canvas{handle = 1})
	testing.expect(t, err != .None)
	testing.expect(t, thor2d.Canvas_MSAA(&ctx, thor2d.Canvas{handle = 999}) == 0)
	testing.expect(t, thor2d.Canvas_MSAA(nil, thor2d.Canvas{handle = 1}) == 0)
	testing.expect(t, thor2d.Canvas_MSAA(&ctx, thor2d.Canvas{}) == 0)
}

@(test)
test_v10t_shader_headless :: proc(t: ^testing.T) {
	ctx, ok := v10t_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	bad := thor2d.Shader{handle = 999}

	testing.expect(t, thor2d.Shader_Has_Uniform(&ctx, bad, "x") == false)
	testing.expect(t, thor2d.Shader_Has_Uniform(&ctx, thor2d.Shader{}, "x") == false)
	testing.expect(t, thor2d.Shader_Has_Uniform(&ctx, bad, "") == false)
	testing.expect(t, thor2d.Shader_Has_Uniform(nil, bad, "x") == false)
	// No compile log is retained anywhere: warnings are always "".
	testing.expect(t, thor2d.Shader_Warnings(&ctx, bad) == "")
	testing.expect(t, thor2d.Shader_Warnings(nil, bad) == "")
}

// v10t_copy_system_font stages a host TTF into the test save dir so Load_Font
// can succeed windowed. Returns "" when no candidate font exists (skip).
v10t_copy_system_font :: proc(t: ^testing.T, ctx: ^thor2d.Context) -> string {
	candidates := []string{
		"/usr/share/fonts/TTF/JetBrainsMono-ExtraBold.ttf",
		"/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
		"/usr/share/fonts/noto/NotoSans-Regular.ttf",
	}
	for path in candidates {
		data, read_err := os.read_entire_file(path, context.allocator)
		if read_err != nil {
			continue
		}
		defer delete(data)
		fs := thor2d.Filesystem_Access(ctx)
		if thor2d.Write_Save(fs, "v10t_font.ttf", data) != .None {
			continue
		}
		return "v10t_font.ttf"
	}
	return ""
}

@(test)
test_v10t_windowed_font_text :: proc(t: ^testing.T) {
	ctx, ok := v10t_windowed_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	defer v10t_cleanup_save()

	// Named font through the real backend entry.
	font_path := v10t_copy_system_font(t, &ctx)
	if font_path == "" {
		return
	}
	font, load_err := thor2d.Load_Font(&ctx, font_path)
	if !testing.expect(t, load_err == .None) {
		return
	}
	defer thor2d.Unload_Font(&ctx, font)

	testing.expect(t, thor2d.Font_Ascent(&ctx, font, 32) == 25.6)
	testing.expect(t, thor2d.Font_Descent(&ctx, font, 32) == 6.4)
	testing.expect(t, thor2d.Font_Baseline(&ctx, font, 32) == 25.6)
	testing.expect(t, thor2d.Font_Line_Height(&ctx, font, 32) == 32)
	testing.expect(t, thor2d.Font_Has_Glyphs(&ctx, font, "ABC abc 012") == true)
	testing.expect(t, thor2d.Font_DPI_Scale(&ctx, font) > 0)

	// Stored multiplier round-trips and scales layout + line height.
	thor2d.Font_Set_Line_Height(&ctx, font, 2.0)
	testing.expect(t, thor2d.Font_Get_Line_Height(&ctx, font) == 2.0)
	testing.expect(t, thor2d.Font_Line_Height(&ctx, font, 16) == 32)
	thor2d.Set_Font(&ctx, font)
	layout := thor2d.Measure_Text_Layout(&ctx, "hi", 16)
	testing.expect(t, layout.Line_Height == 32)
	thor2d.Font_Set_Line_Height(&ctx, font, 1.0)
	testing.expect(t, thor2d.Font_Get_Line_Height(&ctx, font) == 1.0)
	thor2d.Set_Font(&ctx, thor2d.Font{})

	// Text append path: stored string grows, default-font measure grows.
	text, text_err := thor2d.Create_Text(&ctx, thor2d.Font{}, "hi", 16)
	if !testing.expect(t, text_err == .None) {
		return
	}
	defer thor2d.Unload_Text(&ctx, text)
	testing.expect(t, thor2d.Text_Font(&ctx, text) == thor2d.Font{})
	testing.expect(t, thor2d.Text_Set_Font(&ctx, text, font) == .None)
	testing.expect(t, thor2d.Text_Font(&ctx, text) == font)
	testing.expect(t, thor2d.Text_Set_Font(&ctx, text, thor2d.Font{handle = 999}) == .Invalid_Data)
	w0 := thor2d.Measure_Text(&ctx, "hi", 16)
	testing.expect(t, thor2d.Text_Add(&ctx, text, " there") == .None)
	w1 := thor2d.Measure_Text(&ctx, "hi there", 16)
	testing.expect(t, w1 > w0)
	testing.expect(t, thor2d.Text_Add(&ctx, text, "") == .None)
	testing.expect(t, thor2d.Text_Addf(&ctx, text, " %d", 42) == .None)
	thor2d.Draw_Text_Object(&ctx, text, thor2d.Vec2{4, 4})
	thor2d.Draw_Text_Font(&ctx, font, "hi", thor2d.Vec2{4, 20}, 16, 0, thor2d.White)
	testing.expect(t, thor2d.Text_Clear(&ctx, text) == .None)
	testing.expect(t, thor2d.Text_Set_Font(&ctx, text, thor2d.Font{}) == .None)
	testing.expect(t, thor2d.Text_Font(&ctx, text) == thor2d.Font{})
}

@(test)
test_v10t_windowed_batch :: proc(t: ^testing.T) {
	ctx, ok := v10t_windowed_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	defer v10t_cleanup_save()

	tex, tex_err := thor2d.Generate_Texture(&ctx, 8, 8, thor2d.White)
	if !testing.expect(t, tex_err == .None) {
		return
	}
	defer thor2d.Unload_Texture(&ctx, tex)
	batch, batch_err := thor2d.Create_Sprite_Batch(&ctx, tex, 4)
	if !testing.expect(t, batch_err == .None) {
		return
	}
	defer thor2d.Unload_Sprite_Batch(&ctx, batch)

	testing.expect(t, thor2d.Sprite_Batch_Count(&ctx, batch) == 0)
	start, count := thor2d.Sprite_Batch_Draw_Range(&ctx, batch)
	testing.expect(t, start == 0 && count == -1)
	src := thor2d.Rect{W = 8, H = 8}
	thor2d.Add_Sprite(&ctx, batch, src, thor2d.Rect{X = 0, Y = 0, W = 8, H = 8}, thor2d.Vec2{}, 0)
	thor2d.Add_Sprite(&ctx, batch, src, thor2d.Rect{X = 16, Y = 0, W = 8, H = 8}, thor2d.Vec2{}, 0)
	testing.expect(t, thor2d.Sprite_Batch_Count(&ctx, batch) == 2)

	// Slot update + recolor; out-of-range is loud, 0-based.
	testing.expect(t, thor2d.Sprite_Batch_Set(&ctx, batch, 0, src, thor2d.Rect{X = 4, Y = 4, W = 8, H = 8}, thor2d.Vec2{}, 0) == .None)
	testing.expect(t, thor2d.Sprite_Batch_Set(&ctx, batch, 5, src, thor2d.Rect{X = 4, Y = 4, W = 8, H = 8}, thor2d.Vec2{}, 0) != .None)
	testing.expect(t, thor2d.Sprite_Batch_Set(&ctx, batch, -1, src, thor2d.Rect{X = 0, Y = 0, W = 8, H = 8}, thor2d.Vec2{}, 0) != .None)
	testing.expect(t, thor2d.Sprite_Batch_Set_Color(&ctx, batch, 1, thor2d.Red) == .None)
	testing.expect(t, thor2d.Sprite_Batch_Set_Color(&ctx, batch, 5, thor2d.Red) != .None)

	// Draw-range round-trip; invalid ranges rejected.
	testing.expect(t, thor2d.Sprite_Batch_Set_Draw_Range(&ctx, batch, 1, 1) == .None)
	start, count = thor2d.Sprite_Batch_Draw_Range(&ctx, batch)
	testing.expect(t, start == 1 && count == 1)
	testing.expect(t, thor2d.Sprite_Batch_Set_Draw_Range(&ctx, batch, -1, 1) != .None)
	testing.expect(t, thor2d.Sprite_Batch_Set_Draw_Range(&ctx, batch, 0, 0) != .None)
	thor2d.Draw_Sprite_Batch(&ctx, batch)
	testing.expect(t, thor2d.Sprite_Batch_Set_Draw_Range(&ctx, batch, 0, -1) == .None)
	start, count = thor2d.Sprite_Batch_Draw_Range(&ctx, batch)
	testing.expect(t, start == 0 && count == -1)
	thor2d.Draw_Sprite_Batch(&ctx, batch)
}

@(test)
test_v10t_windowed_canvas :: proc(t: ^testing.T) {
	ctx, ok := v10t_windowed_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	defer v10t_cleanup_save()

	canvas, canvas_err := thor2d.Create_Canvas(&ctx, 32, 16)
	if !testing.expect(t, canvas_err == .None) {
		return
	}
	defer thor2d.Unload_Canvas(&ctx, canvas)
	testing.expect(t, thor2d.Canvas_MSAA(&ctx, canvas) == 0)

	drawn := false
	v10t_render_flag = false
	thor2d.Canvas_Render_To(&ctx, canvas, v10t_paint_canvas)
	drawn = v10t_render_flag
	testing.expect(t, drawn)

	image, image_err := thor2d.Canvas_To_Image(&ctx, canvas)
	if !testing.expect(t, image_err == .None) {
		return
	}
	defer thor2d.Destroy_Image_Data(&image)
	testing.expect(t, image.Width == 32 && image.Height == 16)
	testing.expect(t, len(image.Pixels) == 32*16*4)
	_, bad_err := thor2d.Canvas_To_Image(&ctx, thor2d.Canvas{handle = 999})
	testing.expect(t, bad_err == .Invalid_Handle)
}

V10T_TEST_VS :: `#version 330
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;
out vec2 fragTexCoord;
out vec4 fragColor;
uniform mat4 mvp;
void main()
{
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    gl_Position = mvp*vec4(vertexPosition, 1.0);
}
`

V10T_TEST_FS :: `#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
out vec4 finalColor;
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float myValue;
void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    finalColor = texelColor*colDiffuse*fragColor;
    finalColor.r += myValue*0.0001;
}
`

@(test)
test_v10t_windowed_shader :: proc(t: ^testing.T) {
	ctx, ok := v10t_windowed_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	defer v10t_cleanup_save()

	fs := thor2d.Filesystem_Access(&ctx)
	vs := V10T_TEST_VS
	if thor2d.Write_Save(fs, "v10t_test.vs", transmute([]u8)vs) != .None {
		return
	}
	frag := V10T_TEST_FS
	if thor2d.Write_Save(fs, "v10t_test.fs", transmute([]u8)frag) != .None {
		return
	}
	shader, load_err := thor2d.Load_Shader(&ctx, "v10t_test.vs", "v10t_test.fs")
	if load_err != .None {
		return
	}
	defer thor2d.Unload_Shader(&ctx, shader)
	// Real uniform query through GetShaderLocation: the live uniform is
	// found, the bogus name is not (drivers drop unused names too).
	testing.expect(t, thor2d.Shader_Has_Uniform(&ctx, shader, "myValue") == true)
	testing.expect(t, thor2d.Shader_Has_Uniform(&ctx, shader, "v10t_no_such_uniform") == false)
	testing.expect(t, thor2d.Shader_Warnings(&ctx, shader) == "")
}
