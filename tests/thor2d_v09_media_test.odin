package tests

import "core:testing"
import thor2d "thor2d:thor2d"

// v0.9 P1 media-side gaps: image fonts, compressed images, LOVE audio effect
// names, video+audio gating. All tests are headless-safe: GPU paths assert
// explicit errors and CPU paths (magic bytes, measure, name queries) run
// anywhere. Video audio tests skip gracefully without an FFmpeg build by
// asserting the gated errors, mirroring test_sound_data_and_video_capability.

v09_media_headless_ctx :: proc(t: ^testing.T) -> thor2d.Context {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	testing.expect(t, err == .None)
	return ctx
}

@(test)
test_v09_media_image_font_headless :: proc(t: ^testing.T) {
	ctx := v09_media_headless_ctx(t)
	defer thor2d.Destroy(&ctx)

	// 8x4 sheet, glyphs "AB": two 4x4 cells.
	img, img_err := thor2d.New_Image_Data(8, 4, thor2d.White)
	testing.expect(t, img_err == .None)
	defer thor2d.Destroy_Image_Data(&img)

	font, font_err := thor2d.Load_Image_Font(&ctx, img, "AB")
	testing.expect(t, font_err == .None)
	testing.expect(t, !thor2d.Image_Font_Invalid(font))
	testing.expect(t, font.Cell_W == 4 && font.Cell_H == 4)

	// Headless fonts carry no GPU texture but measure exactly.
	measured := thor2d.Measure_Text_Image_Font(&ctx, font, "AB", 1)
	testing.expect(t, measured == thor2d.Vec2{8, 4})
	scaled := thor2d.Measure_Text_Image_Font(&ctx, font, "AB", 2)
	testing.expect(t, scaled == thor2d.Vec2{16, 8})
	multi := thor2d.Measure_Text_Image_Font(&ctx, font, "A\nB", 1)
	testing.expect(t, multi == thor2d.Vec2{4, 8})
	// Unknown glyphs advance one blank cell; empty text and bad scale are {}.
	testing.expect(t, thor2d.Measure_Text_Image_Font(&ctx, font, "A?", 1) == thor2d.Vec2{8, 4})
	testing.expect(t, thor2d.Measure_Text_Image_Font(&ctx, font, "", 1) == thor2d.Vec2{})
	testing.expect(t, thor2d.Measure_Text_Image_Font(&ctx, font, "AB", 0) == thor2d.Vec2{})
	testing.expect(t, thor2d.Measure_Text_Image_Font(nil, font, "AB", 1) == thor2d.Vec2{})

	// Draw is a headless no-op, never a crash.
	thor2d.Draw_Text_Image_Font(&ctx, font, "AB\nA?", thor2d.Vec2{10, 20}, 1, thor2d.White)
	thor2d.Draw_Text_Image_Font(nil, font, "AB", thor2d.Vec2{}, 1, thor2d.White)
	thor2d.Draw_Text_Image_Font(&ctx, thor2d.Image_Font{}, "AB", thor2d.Vec2{}, 1, thor2d.White)

	thor2d.Unload_Image_Font(&ctx, &font)
	testing.expect(t, thor2d.Image_Font_Invalid(font))
	testing.expect(t, thor2d.Image_Font_Invalid(thor2d.Image_Font{}))
	// Unload is nil- and zero-safe.
	thor2d.Unload_Image_Font(&ctx, &font)
	thor2d.Unload_Image_Font(nil, nil)

	// Rejections are loud, never mis-sliced.
	_, empty_err := thor2d.Load_Image_Font(&ctx, img, "")
	testing.expect(t, empty_err == .Invalid_Data)
	wide, _ := thor2d.New_Image_Data(6, 4, thor2d.White)
	defer thor2d.Destroy_Image_Data(&wide)
	_, nondyn_err := thor2d.Load_Image_Font(&ctx, wide, "ABCD")
	testing.expect(t, nondyn_err == .Invalid_Data)
	_, utf8_err := thor2d.Load_Image_Font(&ctx, img, "A\xc3\xa9")
	testing.expect(t, utf8_err == .Invalid_Data)
	_, bad_img_err := thor2d.Load_Image_Font(&ctx, thor2d.Image_Data{}, "AB")
	testing.expect(t, bad_img_err == .Invalid_Data)
	_, nil_err := thor2d.Load_Image_Font(nil, img, "AB")
	testing.expect(t, nil_err != .None)
}

@(test)
test_v09_media_is_compressed_magic :: proc(t: ^testing.T) {
	dds := []u8{0x44, 0x44, 0x53, 0x20, 0, 0, 0}
	testing.expect(t, thor2d.Is_Compressed_Image(dds))
	ktx1 := []u8{0xAB, 0x4B, 0x54, 0x58, 0x20, 0x31, 0x31, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A}
	testing.expect(t, thor2d.Is_Compressed_Image(ktx1))
	ktx2 := []u8{0xAB, 0x4B, 0x54, 0x58, 0x20, 0x32, 0x30, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A}
	testing.expect(t, thor2d.Is_Compressed_Image(ktx2))
	pkm := []u8{0x50, 0x4B, 0x4D, 0x20, 0x31, 0x30}
	testing.expect(t, thor2d.Is_Compressed_Image(pkm))
	astc := []u8{0x13, 0xAB, 0xA1, 0x5C, 0, 0}
	testing.expect(t, thor2d.Is_Compressed_Image(astc))
	pvr := []u8{0x50, 0x56, 0x52, 0x03, 0, 0}
	testing.expect(t, thor2d.Is_Compressed_Image(pvr))

	// LOVE's isCompressed means GPU-compressed: PNG/JPEG are file compression.
	png := []u8{137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0, 0}
	testing.expect(t, !thor2d.Is_Compressed_Image(png))
	jpeg := []u8{0xFF, 0xD8, 0xFF, 0xE0, 0, 0}
	testing.expect(t, !thor2d.Is_Compressed_Image(jpeg))
	testing.expect(t, !thor2d.Is_Compressed_Image([]u8{1, 2, 3, 4, 5}))
	testing.expect(t, !thor2d.Is_Compressed_Image([]u8{0x44, 0x44}))
	testing.expect(t, !thor2d.Is_Compressed_Image(nil))
}

@(test)
test_v09_media_load_compressed_headless :: proc(t: ^testing.T) {
	ctx := v09_media_headless_ctx(t)
	defer thor2d.Destroy(&ctx)
	// No backend headless: explicit error before any file access, never a
	// fake texture.
	_, err := thor2d.Load_Compressed_Texture(&ctx, "assets/sprite.dds")
	testing.expect(t, err == .Backend_Initialization_Failed)
	_, nil_err := thor2d.Load_Compressed_Texture(nil, "assets/sprite.dds")
	testing.expect(t, nil_err == .Backend_Initialization_Failed)
}

@(test)
test_v09_media_love_effect_names :: proc(t: ^testing.T) {
	// Wired miniaudio kinds: echo (Delay node) and reverb (delay approx).
	testing.expect(t, thor2d.Is_LOVE_Audio_Effect_Supported("echo"))
	testing.expect(t, thor2d.Is_LOVE_Audio_Effect_Supported("reverb"))
	// No miniaudio node exists for these: documented absence, never a fake.
	testing.expect(t, !thor2d.Is_LOVE_Audio_Effect_Supported("chorus"))
	testing.expect(t, !thor2d.Is_LOVE_Audio_Effect_Supported("compressor"))
	testing.expect(t, !thor2d.Is_LOVE_Audio_Effect_Supported("distortion"))
	testing.expect(t, !thor2d.Is_LOVE_Audio_Effect_Supported("equalizer"))
	testing.expect(t, !thor2d.Is_LOVE_Audio_Effect_Supported("flanger"))
	testing.expect(t, !thor2d.Is_LOVE_Audio_Effect_Supported("ringmodulator"))
	testing.expect(t, !thor2d.Is_LOVE_Audio_Effect_Supported(""))
	testing.expect(t, !thor2d.Is_LOVE_Audio_Effect_Supported("ECHO"))
	testing.expect(t, !thor2d.Is_LOVE_Audio_Effect_Supported("Reverb"))
}

@(test)
test_v09_media_video_audio_gated :: proc(t: ^testing.T) {
	ctx := v09_media_headless_ctx(t)
	defer thor2d.Destroy(&ctx)
	// Default build has no FFmpeg: video capability stays off and the audio
	// side degrades to explicit negatives, mirroring the existing video
	// capability pattern.
	testing.expect(t, !thor2d.Query_Capability(&ctx, .Video))
	testing.expect(t, !thor2d.Video_Has_Audio(&ctx, thor2d.Video_Stream{}))
	testing.expect(t, !thor2d.Video_Has_Audio(nil, thor2d.Video_Stream{}))
	_, src_err := thor2d.Video_Audio_Source(&ctx, thor2d.Video_Stream{})
	testing.expect(t, src_err == .Invalid_Handle)
	_, nil_src_err := thor2d.Video_Audio_Source(nil, thor2d.Video_Stream{})
	testing.expect(t, nil_src_err == .Invalid_Handle)
	testing.expect(t, thor2d.Set_Video_Audio_Volume(&ctx, thor2d.Video_Stream{}, 1) == .Invalid_Handle)
	testing.expect(t, thor2d.Set_Video_Audio_Volume(nil, thor2d.Video_Stream{}, 1) == .Invalid_Handle)
}
