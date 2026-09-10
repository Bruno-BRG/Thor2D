package tests

import "core:io"
import "core:strings"
import "core:testing"
import thor2d "thor2d:thor2d"

// v0.10 final sweep (wave 6): filesystem File object, math matrix/noise/bezier,
// threads introspection, window completion, data levels/lines. All
// headless-safe (pure CPU + OS-file I/O, no display/device).

v10f_abs_diff :: proc(a, b: f32) -> f32 {
	d := a - b
	return d if d >= 0 else -d
}

@(test)
test_v10f_file_object :: proc(t: ^testing.T) {
	filesystem, fs_err := thor2d.Init_Filesystem(".", ".thor2d-test-save-v10f")
	testing.expect(t, fs_err == .None)
	if fs_err != .None {
		return
	}
	defer thor2d.Destroy_Filesystem(&filesystem)
	testing.expect(t, thor2d.Are_Symlinks_Enabled(&filesystem))

	content := "first\nsecond\r\nthird"
	testing.expect(t, thor2d.Write_Save(&filesystem, "v10f/lines.txt", transmute([]byte)content) == .None)

	file, open_err := thor2d.Open_File(&filesystem, "v10f/lines.txt", .Read)
	testing.expect(t, open_err == .None)
	if open_err != .None {
		return
	}
	testing.expect(t, thor2d.File_Is_Open(file))
	testing.expect(t, thor2d.File_Name(file) == "v10f/lines.txt")
	testing.expect(t, thor2d.File_Mode(file) == .Read)
	testing.expect(t, !thor2d.File_Is_EOF(file))
	size, size_err := thor2d.File_Size_Of(file)
	testing.expect(t, size_err == .None && size == i64(len(content)))
	pos, _ := thor2d.Tell_File(file)
	testing.expect(t, pos == 0)

	line1, line1_err := thor2d.File_Read_Line(file)
	testing.expect(t, line1_err == .None && line1 == "first")
	delete(line1)
	line2, line2_err := thor2d.File_Read_Line(file)
	testing.expect(t, line2_err == .None && line2 == "second")
	delete(line2)
	line3, line3_err := thor2d.File_Read_Line(file)
	testing.expect(t, line3_err == .None && line3 == "third")
	delete(line3)
	testing.expect(t, thor2d.File_Is_EOF(file))
	_, eof_err := thor2d.File_Read_Line(file)
	testing.expect(t, eof_err == .File_Not_Found)

	// Seek back and read raw bytes.
	testing.expect(t, thor2d.File_Flush(file) == .None)
	back, _ := thor2d.Seek_File(file, 0, io.Seek_From.Start)
	testing.expect(t, back == 0)
	raw := make([]byte, 5)
	defer delete(raw)
	count, read_err := thor2d.Read_File_Handle(file, raw)
	testing.expect(t, read_err == .None && count == 5 && string(raw) == "first")

	testing.expect(t, thor2d.Close_File(file) == .None)
	testing.expect(t, !thor2d.File_Is_Open(file))
	testing.expect(t, thor2d.File_Is_EOF(file))
	// Identity survives close (LOVE File:getFilename after close).
	testing.expect(t, thor2d.File_Name(file) == "v10f/lines.txt")
	testing.expect(t, thor2d.File_Mode(file) == .Read)
	testing.expect(t, thor2d.File_Flush(file) == .Invalid_Handle)
	_, closed_size_err := thor2d.File_Size_Of(file)
	testing.expect(t, closed_size_err == .Invalid_Handle)
	_, closed_line_err := thor2d.File_Read_Line(file)
	testing.expect(t, closed_line_err == .Invalid_Handle)

	// Write-mode handle: flush is an honest unbuffered no-op.
	writer, writer_err := thor2d.Open_File(&filesystem, "v10f/out.bin", .Write)
	testing.expect(t, writer_err == .None)
	if writer_err == .None {
		testing.expect(t, thor2d.File_Mode(writer) == .Write)
		written, write_err := thor2d.Write_File_Handle(writer, []byte{1, 2, 3})
		testing.expect(t, write_err == .None && written == 3)
		testing.expect(t, thor2d.File_Flush(writer) == .None)
		wsize, wsize_err := thor2d.File_Size_Of(writer)
		testing.expect(t, wsize_err == .None && wsize == 3)
		testing.expect(t, thor2d.Close_File(writer) == .None)
	}

	// Buffer modes: .None honored, anything else loud.
	testing.expect(t, thor2d.File_Set_Buffer_Mode(nil, .None) == .Invalid_Handle)
	testing.expect(t, thor2d.File_Buffer_Mode_Of(nil) == .None)
	testing.expect(t, thor2d.File_Set_Buffer_Mode(file, .None) == .None)
	testing.expect(t, thor2d.File_Buffer_Mode_Of(file) == .None)
	testing.expect(t, thor2d.File_Set_Buffer_Mode(file, .Full) == .Unsupported)
	testing.expect(t, thor2d.File_Set_Buffer_Mode(file, .Line) == .Unsupported)
	testing.expect(t, thor2d.File_Buffer_Mode_Of(file) == .None)

	// Nil-handle edges.
	testing.expect(t, !thor2d.File_Is_Open(nil))
	testing.expect(t, thor2d.File_Is_EOF(nil))
	testing.expect(t, thor2d.File_Name(nil) == "")
	testing.expect(t, thor2d.File_Mode(nil) == .Read)
}

@(test)
test_v10f_file_data_and_archives :: proc(t: ^testing.T) {
	data, data_err := thor2d.New_File_Data("assets/sprite.png", []byte{9, 8, 7})
	testing.expect(t, data_err == .None)
	defer thor2d.Destroy_File_Data(&data)
	testing.expect(t, thor2d.File_Data_Name(&data) == "assets/sprite.png")
	testing.expect(t, thor2d.File_Data_Extension(&data) == "png")
	testing.expect(t, len(thor2d.File_Data_Bytes(&data)) == 3)

	plain := thor2d.File_Data{}
	testing.expect(t, thor2d.File_Data_Name(&plain) == "")
	testing.expect(t, thor2d.File_Data_Extension(&plain) == "")
	testing.expect(t, thor2d.File_Data_Name(nil) == "")
	testing.expect(t, thor2d.File_Data_Extension(nil) == "")
	no_ext, _ := thor2d.New_File_Data("README", []byte{1})
	defer thor2d.Destroy_File_Data(&no_ext)
	testing.expect(t, thor2d.File_Data_Extension(&no_ext) == "")

	filesystem, fs_err := thor2d.Init_Filesystem(".", ".thor2d-test-save-v10f")
	testing.expect(t, fs_err == .None)
	if fs_err != .None {
		return
	}
	defer thor2d.Destroy_Filesystem(&filesystem)

	// Garbage bytes are rejected, never mounted as a fake archive.
	testing.expect(t, thor2d.Mount_Archive_Memory(&filesystem, "junk.zip", []byte{1, 2, 3, 4}) == .Invalid_Data)
	testing.expect(t, thor2d.Mount_Archive_Memory(&filesystem, "", []byte{1, 2}) == .Invalid_Data)
	testing.expect(t, thor2d.Mount_Archive_Memory(nil, "x.zip", []byte{1}) == .Invalid_Data)
	testing.expect(t, len(filesystem.archives) == 0)

	// Symlink intent flag round-trips; sandbox behavior is unchanged.
	testing.expect(t, thor2d.Are_Symlinks_Enabled(&filesystem))
	testing.expect(t, thor2d.Set_Symlinks_Enabled(&filesystem, false) == .None)
	testing.expect(t, !thor2d.Are_Symlinks_Enabled(&filesystem))
	testing.expect(t, thor2d.Set_Symlinks_Enabled(&filesystem, true) == .None)
	testing.expect(t, thor2d.Are_Symlinks_Enabled(&filesystem))
	testing.expect(t, !thor2d.Are_Symlinks_Enabled(nil))
	testing.expect(t, thor2d.Set_Symlinks_Enabled(nil, true) == .Invalid_Data)
}

@(test)
test_v10f_transform_matrix :: proc(t: ^testing.T) {
	// Identity converts to the 4x4 identity.
	identity := thor2d.Identity_Transform()
	testing.expect(t, !thor2d.Transform_Has_Matrix(identity))
	m := thor2d.Transform_Get_Matrix(identity)
	testing.expect(t, m[0, 0] == 1 && m[1, 1] == 1 && m[2, 2] == 1 && m[3, 3] == 1)
	testing.expect(t, m[0, 3] == 0 && m[1, 3] == 0 && m[0, 1] == 0)

	// TRS translation lands in column 3 exactly.
	tr := thor2d.Identity_Transform()
	tr.Position = thor2d.Vec2{5, -3}
	tm := thor2d.Transform_Get_Matrix(tr)
	testing.expect(t, tm[0, 3] == 5 && tm[1, 3] == -3)
	got := thor2d.Transform_Point(tr, thor2d.Vec2{1, 2})
	testing.expect(t, got == thor2d.Vec2{6, -1})

	// Raw shear matrix: the exact path TRS cannot express.
	shear := thor2d.Identity_Transform()
	sm := thor2d.Transform_Get_Matrix(shear)
	sm[0, 1] = 2 // x' = x + 2y
	testing.expect(t, thor2d.Transform_Set_Matrix(&shear, sm) == .None)
	testing.expect(t, thor2d.Transform_Has_Matrix(shear))
	testing.expect(t, thor2d.Transform_Set_Matrix(nil, sm) == .Invalid_Data)
	sp := thor2d.Transform_Point(shear, thor2d.Vec2{1, 1})
	testing.expect(t, v10f_abs_diff(sp.X, 3) < 0.0001 && v10f_abs_diff(sp.Y, 1) < 0.0001)
	// Get returns the stored matrix verbatim.
	back := thor2d.Transform_Get_Matrix(shear)
	testing.expect(t, back[0, 1] == 2 && back[0, 0] == 1)
	// Inverse round-trips through the sheared point.
	inv := thor2d.Transform_Inverse(shear)
	testing.expect(t, thor2d.Transform_Has_Matrix(inv))
	there := thor2d.Transform_Point(shear, thor2d.Vec2{4, -2})
	home := thor2d.Transform_Point(inv, there)
	testing.expect(t, v10f_abs_diff(home.X, 4) < 0.001 && v10f_abs_diff(home.Y, -2) < 0.001)
	legacy := thor2d.Transform_Point_Inverse(shear, there)
	testing.expect(t, v10f_abs_diff(home.X, legacy.X) < 0.001 && v10f_abs_diff(home.Y, legacy.Y) < 0.001)

	// Combine with an override stays exact (nested == combined).
	shift := thor2d.Identity_Transform()
	shift.Position = thor2d.Vec2{10, 0}
	combined := thor2d.Transform_Combine(shift, shear)
	testing.expect(t, thor2d.Transform_Has_Matrix(combined))
	check_points := [3]thor2d.Vec2{{0, 0}, {4, -2}, {-7, 9}}
	for p in check_points {
		nested := thor2d.Transform_Point(shift, thor2d.Transform_Point(shear, p))
		direct := thor2d.Transform_Point(combined, p)
		testing.expect(t, v10f_abs_diff(direct.X, nested.X) < 0.001 && v10f_abs_diff(direct.Y, nested.Y) < 0.001)
	}

	// TRS edits clear the override (documented projection back to TRS).
	thor2d.Transform_Translate(&shear, thor2d.Vec2{1, 1})
	testing.expect(t, !thor2d.Transform_Has_Matrix(shear))
	thor2d.Transform_Set_Matrix(&shear, sm)
	thor2d.Transform_Clear_Matrix(&shear)
	testing.expect(t, !thor2d.Transform_Has_Matrix(shear))
	thor2d.Transform_Clear_Matrix(nil) // nil-safe no-op
}

@(test)
test_v10f_noise_and_bezier :: proc(t: ^testing.T) {
	// Deterministic per (coordinate, seed), bounded to [-1, 1].
	testing.expect(t, thor2d.Random_Noise_1D(1.5, 99) == thor2d.Random_Noise_1D(1.5, 99))
	testing.expect(t, thor2d.Random_Noise_3D(1, 2, 3, 7) == thor2d.Random_Noise_3D(1, 2, 3, 7))
	testing.expect(t, thor2d.Random_Noise_4D(1, 2, 3, 4, 7) == thor2d.Random_Noise_4D(1, 2, 3, 4, 7))
	samples := [4]f32{
		thor2d.Random_Noise_1D(0, 1), thor2d.Random_Noise_1D(-3.25, 42),
		thor2d.Random_Noise_3D(1, -1, 0.5, 5), thor2d.Random_Noise_4D(9, 9, 9, 9, 9),
	}
	for sample in samples {
		testing.expect(t, sample >= -1 && sample <= 1)
	}
	// Seeds perturb the lattice (hash differs virtually surely).
	testing.expect(t, thor2d.Random_Noise_1D(1.5, 1) != thor2d.Random_Noise_1D(1.5, 2))
	testing.expect(t, thor2d.Random_Noise_3D(0, 0, 0, 1) != thor2d.Random_Noise_3D(0, 0, 0, 2))

	curve, curve_err := thor2d.New_Bezier_Curve([]thor2d.Vec2{{0, 0}, {2, 2}, {4, 0}})
	testing.expect(t, curve_err == .None)
	defer thor2d.Destroy_Bezier_Curve(&curve)
	testing.expect(t, thor2d.Bezier_Degree(&curve) == 2)
	testing.expect(t, thor2d.Bezier_Degree(nil) == 0)

	rendered, render_err := thor2d.Bezier_Render(&curve, 4)
	testing.expect(t, render_err == .None && len(rendered) == 5)
	if render_err == .None {
		testing.expect(t, rendered[0] == thor2d.Vec2{0, 0} && rendered[4] == thor2d.Vec2{4, 0})
		mid := thor2d.Bezier_Point(&curve, 0.5)
		testing.expect(t, v10f_abs_diff(rendered[2].X, mid.X) < 0.0001 && v10f_abs_diff(rendered[2].Y, mid.Y) < 0.0001)
	}
	delete(rendered)
	_, bad_render := thor2d.Bezier_Render(&curve, 0)
	testing.expect(t, bad_render == .Invalid_Data)
	_, nil_render := thor2d.Bezier_Render(nil, 4)
	testing.expect(t, nil_render == .Invalid_Data)

	segment, seg_err := thor2d.Bezier_Segment(&curve, 0.25, 0.75)
	testing.expect(t, seg_err == .None)
	defer thor2d.Destroy_Bezier_Curve(&segment)
	if seg_err == .None {
		testing.expect(t, thor2d.Bezier_Degree(&segment) == 2)
		want_start := thor2d.Bezier_Point(&curve, 0.25)
		want_end := thor2d.Bezier_Point(&curve, 0.75)
		got_start := thor2d.Bezier_Point(&segment, 0)
		got_end := thor2d.Bezier_Point(&segment, 1)
		testing.expect(t, v10f_abs_diff(got_start.X, want_start.X) < 0.001 && v10f_abs_diff(got_start.Y, want_start.Y) < 0.001)
		testing.expect(t, v10f_abs_diff(got_end.X, want_end.X) < 0.001 && v10f_abs_diff(got_end.Y, want_end.Y) < 0.001)
	}
	_, reversed := thor2d.Bezier_Segment(&curve, 0.8, 0.2)
	testing.expect(t, reversed == .Invalid_Data)
	_, nil_seg := thor2d.Bezier_Segment(nil, 0, 1)
	testing.expect(t, nil_seg == .Invalid_Data)

	points := thor2d.Bezier_Control_Points(&curve)
	testing.expect(t, len(points) == 3 && thor2d.Bezier_Control_Points(nil) == nil)
	testing.expect(t, thor2d.Bezier_Set_Control_Points(&curve, []thor2d.Vec2{{1, 1}, {3, 3}}) == .None)
	testing.expect(t, thor2d.Bezier_Degree(&curve) == 1)
	testing.expect(t, thor2d.Bezier_Set_Control_Points(&curve, []thor2d.Vec2{{0, 0}}) == .Invalid_Config)
	testing.expect(t, thor2d.Bezier_Set_Control_Points(nil, []thor2d.Vec2{{0, 0}, {1, 1}}) == .Invalid_Data)
}

@(test)
test_v10f_channel_introspection :: proc(t: ^testing.T) {
	channel, err := thor2d.New_Channel(int, 4)
	testing.expect(t, err == .None)
	defer thor2d.Destroy_Channel(&channel)
	testing.expect(t, thor2d.Channel_Get_Count(&channel) == 0)
	testing.expect(t, !thor2d.Channel_Has_Data(&channel))
	testing.expect(t, thor2d.Try_Send(&channel, 11))
	testing.expect(t, thor2d.Try_Send(&channel, 22))
	testing.expect(t, thor2d.Channel_Get_Count(&channel) == 2)
	testing.expect(t, thor2d.Channel_Has_Data(&channel))
	_, peek_err := thor2d.Channel_Peek(&channel)
	testing.expect(t, peek_err == .Unsupported)
	// Peek is non-destructive by virtue of never popping.
	testing.expect(t, thor2d.Channel_Get_Count(&channel) == 2)
	testing.expect(t, thor2d.Channel_Clear(&channel) == 2)
	testing.expect(t, thor2d.Channel_Get_Count(&channel) == 0)
	testing.expect(t, !thor2d.Channel_Has_Data(&channel))
	testing.expect(t, thor2d.Channel_Clear(&channel) == 0)

	// Nil channels are safe zeros, never panics.
	empty: thor2d.Channel(int)
	testing.expect(t, thor2d.Channel_Get_Count(&empty) == 0)
	nil_channel: ^thor2d.Channel(int) = nil
	testing.expect(t, thor2d.Channel_Get_Count(nil_channel) == 0)
	testing.expect(t, !thor2d.Channel_Has_Data(nil_channel))
	testing.expect(t, thor2d.Channel_Clear(nil_channel) == 0)
	_, nil_peek := thor2d.Channel_Peek(&empty)
	testing.expect(t, nil_peek == .Invalid_Handle)
}

@(test)
test_v10f_window_completion_headless :: proc(t: ^testing.T) {
	// Nil-context edges (no backend needed).
	testing.expect(t, len(thor2d.Get_Fullscreen_Modes(nil)) == 0)
	testing.expect(t, !thor2d.Window_Has_Icon(nil))
	testing.expect(t, thor2d.Request_Attention(nil) == .Invalid_Config)
	testing.expect(t, thor2d.Is_Display_Sleep_Enabled(nil))

	config := thor2d.Default_Config()
	config.Headless = true
	ctx, create_err := thor2d.Create(config)
	testing.expect(t, create_err == .None)
	if create_err != .None {
		return
	}
	defer thor2d.Destroy(&ctx)

	modes := thor2d.Get_Fullscreen_Modes(&ctx)
	testing.expect(t, len(modes) == 0)
	delete(modes)
	testing.expect(t, !thor2d.Window_Has_Icon(&ctx))
	// Headless has no window to flash or icon.
	testing.expect(t, thor2d.Request_Attention(&ctx) == .Backend_Initialization_Failed)
	testing.expect(t, thor2d.Is_Display_Sleep_Enabled(&ctx))
	testing.expect(t, thor2d.Set_Display_Sleep_Enabled(&ctx, false) == .Unsupported)
	testing.expect(t, !thor2d.Is_Display_Sleep_Enabled(&ctx))
	testing.expect(t, thor2d.Set_Display_Sleep_Enabled(&ctx, true) == .Unsupported)
	testing.expect(t, thor2d.Is_Display_Sleep_Enabled(&ctx))
	testing.expect(t, thor2d.Set_Display_Sleep_Enabled(nil, true) == .Unsupported)
}

@(test)
test_v10f_data_levels_and_lines :: proc(t: ^testing.T) {
	payload := transmute([]byte)string("the quick brown fox jumps over the lazy dog, repeatedly! the quick brown fox!")
	levels := [3]int{1, 6, 9}
	for level in levels {
		compressed, comp_err := thor2d.Compress_With_Level(payload, .ZLIB, level)
		testing.expect(t, comp_err == .None)
		if comp_err != .None {
			continue
		}
		raw, decomp_err := thor2d.Decompress_Data(compressed)
		thor2d.Destroy_Byte_Buffer(&compressed.Buffer)
		testing.expect(t, decomp_err == .None && string(raw.Bytes[:]) == string(payload))
		thor2d.Destroy_Byte_Buffer(&raw)
	}
	// Level clamps instead of failing.
	clamped, clamp_err := thor2d.Compress_With_Level(payload, .GZIP, 99)
	testing.expect(t, clamp_err == .None)
	thor2d.Destroy_Byte_Buffer(&clamped.Buffer)
	// LZ4 ignores the level but still round-trips.
	lz, lz_err := thor2d.Compress_With_Level(payload, .LZ4, 9)
	testing.expect(t, lz_err == .None)
	if lz_err == .None {
		back, back_err := thor2d.Decompress_Data(lz)
		thor2d.Destroy_Byte_Buffer(&lz.Buffer)
		testing.expect(t, back_err == .None && string(back.Bytes[:]) == string(payload))
		thor2d.Destroy_Byte_Buffer(&back)
	}

	// Base64 with line wrapping: strip newlines to recover the plain form.
	blob := make([]byte, 60)
	defer delete(blob)
	for i in 0..<len(blob) {
		blob[i] = byte(i)
	}
	plain, plain_err := thor2d.Encode_Base64(blob)
	testing.expect(t, plain_err == .None)
	defer delete(plain)
	wrapped, wrap_err := thor2d.Encode_Base64_Lines(blob, 76)
	testing.expect(t, wrap_err == .None)
	defer delete(wrapped)
	testing.expect(t, strings.contains(wrapped, "\n"))
	flat_builder := strings.builder_make(context.allocator)
	defer strings.builder_destroy(&flat_builder)
	for i := 0; i < len(wrapped); i += 1 {
		if wrapped[i] != '\n' {
			strings.write_byte(&flat_builder, wrapped[i])
		}
	}
	flat := strings.to_string(flat_builder)
	testing.expect(t, flat == plain)
	// Every emitted line honors the limit.
	for line in strings.split_lines_iterator(&wrapped) {
		testing.expect(t, len(line) <= 76)
	}
	_, bad_lines := thor2d.Encode_Base64_Lines(blob, 0)
	testing.expect(t, bad_lines == .Invalid_Data)
}

@(test)
test_v10f_event_drop_and_text_paths :: proc(t: ^testing.T) {
	// The LOVE callback mapping all exists as queueable Event kinds: push and
	// poll preserve kind + owned strings (headless-safe).
	ctx := thor2d.Context{}
	defer thor2d.Destroy(&ctx)
	thor2d.Push_Event(&ctx, thor2d.Event{Kind = .Directory_Dropped, Path = "/tmp/some-dir"})
	thor2d.Push_Event(&ctx, thor2d.Event{Kind = .File_Dropped, Path = "/tmp/file.txt"})
	thor2d.Push_Event(&ctx, thor2d.Event{Kind = .Text_Input, Text = 'e'})
	thor2d.Push_Event(&ctx, thor2d.Event{Kind = .Key_Text_Edited, Editing = "compos"})

	event, ok := thor2d.Poll_Event(&ctx)
	testing.expect(t, ok && event.Kind == .Directory_Dropped && event.Path == "/tmp/some-dir")
	thor2d.Destroy_Event(&event)
	event, ok = thor2d.Poll_Event(&ctx)
	testing.expect(t, ok && event.Kind == .File_Dropped && event.Path == "/tmp/file.txt")
	thor2d.Destroy_Event(&event)
	event, ok = thor2d.Poll_Event(&ctx)
	testing.expect(t, ok && event.Kind == .Text_Input && event.Text == 'e')
	thor2d.Destroy_Event(&event)
	event, ok = thor2d.Poll_Event(&ctx)
	testing.expect(t, ok && event.Kind == .Key_Text_Edited && event.Editing == "compos")
	thor2d.Destroy_Event(&event)

	// Text-input state (Is_Text_Input_Active is Has_Text_Input; kept as one).
	testing.expect(t, !thor2d.Has_Text_Input(&ctx))
	thor2d.Set_Text_Input(&ctx, true)
	testing.expect(t, thor2d.Has_Text_Input(&ctx))
	thor2d.Set_Text_Input(&ctx, false)
	testing.expect(t, !thor2d.Has_Text_Input(&ctx))
}
