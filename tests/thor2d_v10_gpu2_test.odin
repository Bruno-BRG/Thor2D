package tests

import "core:testing"
import thor2d "thor2d:thor2d"

// v0.10 wave 5: mesh accessors + texture introspection + niche GPU + video
// completion. Headless-safe: GPU-backed resources cannot exist without a
// backend, so headless tests assert explicit errors and stored/zero values.
// Windowed tests try a small context and return early when no display or
// backend is available — never failing for lack of a display. Video tests
// skip gracefully without an FFmpeg build (default) by asserting the
// capability-gated errors.

g2_headless_ctx :: proc(t: ^testing.T) -> (thor2d.Context, bool) {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	if !testing.expect(t, err == .None) {
		return ctx, false
	}
	return ctx, true
}

g2_windowed_ctx :: proc(t: ^testing.T) -> (thor2d.Context, bool) {
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

g2_triangle_verts :: proc() -> [3]thor2d.Mesh_Vertex {
	return [3]thor2d.Mesh_Vertex{
		{Position = thor2d.Vec2{0, 0}, UV = thor2d.Vec2{0, 0}, Color = thor2d.Red, Normal = thor2d.Vec2{0, 1}},
		{Position = thor2d.Vec2{64, 0}, UV = thor2d.Vec2{1, 0}, Color = thor2d.Green, Normal = thor2d.Vec2{0, 1}},
		{Position = thor2d.Vec2{32, 48}, UV = thor2d.Vec2{0.5, 1}, Color = thor2d.Blue, Normal = thor2d.Vec2{0, 1}},
	}
}

@(test)
test_v10g2_mesh_error_paths_headless :: proc(t: ^testing.T) {
	ctx, ok := g2_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	bad := thor2d.Mesh{handle = 999}

	// No GPU backend headless: creation fails loudly, never a fake handle.
	verts := g2_triangle_verts()
	_, err := thor2d.Create_Mesh(&ctx, verts[:])
	testing.expect(t, err == .Invalid_Config)
	_, nil_err := thor2d.Create_Mesh(nil, verts[:])
	testing.expect(t, nil_err == .Invalid_Config)
	_, empty_err := thor2d.Create_Mesh(&ctx, nil)
	testing.expect(t, empty_err == .Invalid_Config)

	// Accessors on missing backends / bad handles: zeros + explicit errors.
	testing.expect(t, thor2d.Mesh_Vertex_Count(&ctx, bad) == 0)
	testing.expect(t, thor2d.Mesh_Vertex_Count(nil, bad) == 0)
	_, at_err := thor2d.Mesh_Vertex_At(&ctx, bad, 0)
	testing.expect(t, at_err == .Invalid_Handle)
	_, at_nil := thor2d.Mesh_Vertex_At(nil, bad, 0)
	testing.expect(t, at_nil == .Invalid_Handle)
	testing.expect(t, thor2d.Mesh_Set_Vertex(&ctx, bad, 0, verts[0]) == .Invalid_Handle)
	testing.expect(t, thor2d.Mesh_Set_Vertex(nil, bad, 0, verts[0]) == .Invalid_Handle)

	_, mode_err := thor2d.Mesh_Draw_Mode_Of(&ctx, bad)
	testing.expect(t, mode_err == .Invalid_Handle)
	testing.expect(t, thor2d.Mesh_Set_Draw_Mode(&ctx, bad, .Triangle_Fan) == .Invalid_Handle)

	_, tex_err := thor2d.Mesh_Texture_Of(&ctx, bad)
	testing.expect(t, tex_err == .Invalid_Handle)
	testing.expect(t, thor2d.Set_Mesh_Texture(&ctx, bad, thor2d.Texture{}) == .Invalid_Handle)

	testing.expect(t, thor2d.Mesh_Set_Draw_Range(&ctx, bad, 0, 2) == .Invalid_Handle)
	s, c := thor2d.Mesh_Draw_Range(&ctx, bad)
	testing.expect(t, s == 0 && c == 0)
	s, c = thor2d.Mesh_Draw_Range(nil, bad)
	testing.expect(t, s == 0 && c == 0)

	// Draw/unload paths are headless no-ops; instanced reports its fallback.
	thor2d.Draw_Mesh(nil, bad, thor2d.Vec2{}, 0, thor2d.Vec2{1, 1})
	thor2d.Draw_Mesh(&ctx, bad, thor2d.Vec2{}, 0, thor2d.Vec2{1, 1})
	thor2d.Draw_Mesh_Textured(&ctx, bad, thor2d.Texture{}, thor2d.Vec2{}, 0, thor2d.Vec2{1, 1})
	thor2d.Unload_Mesh(&ctx, bad)
	thor2d.Unload_Mesh(nil, bad)
	testing.expect(t, thor2d.Draw_Mesh_Instanced(nil, bad, 2, thor2d.Vec2{}, 0, thor2d.Vec2{1, 1}) == .Invalid_Config)
	// Unknown-but-nonzero meshes run the no-op CPU fallback loop and report
	// .Unsupported (pre-existing Draw_Mesh_Instanced semantics); zero meshes
	// and non-positive counts are rejected up front.
	testing.expect(t, thor2d.Draw_Mesh_Instanced(&ctx, bad, 2, thor2d.Vec2{}, 0, thor2d.Vec2{1, 1}) == .Unsupported)
	testing.expect(t, thor2d.Draw_Mesh_Instanced(&ctx, thor2d.Mesh{}, 2, thor2d.Vec2{}, 0, thor2d.Vec2{1, 1}) == .Invalid_Handle)
	testing.expect(t, thor2d.Draw_Mesh_Instanced(&ctx, bad, 0, thor2d.Vec2{}, 0, thor2d.Vec2{1, 1}) == .Invalid_Handle)
}

@(test)
test_v10g2_texture_array_cpu_headless :: proc(t: ^testing.T) {
	ctx, ok := g2_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)

	// Pure value semantics: no backend needed for structural ops.
	testing.expect(t, thor2d.Texture_Array_Invalid(thor2d.Texture_Array{}))
	array := thor2d.Texture_Array{}
	append(&array.Layers, thor2d.Texture{})
	append(&array.Layers, thor2d.Texture{handle = 7})
	testing.expect(t, !thor2d.Texture_Array_Invalid(array))
	testing.expect(t, thor2d.Texture_Array_Layer_Count(array) == 2)

	layer, layer_err := thor2d.Texture_Array_Layer(array, 1)
	testing.expect(t, layer_err == .None && layer.handle == 7)
	_, oob_err := thor2d.Texture_Array_Layer(array, 2)
	testing.expect(t, oob_err == .Invalid_Data)
	_, neg_err := thor2d.Texture_Array_Layer(array, -1)
	testing.expect(t, neg_err == .Invalid_Data)

	// Draws are silent no-ops headless (and on bad layers); unloads free.
	thor2d.Draw_Texture_Array_Layer(nil, array, 0, thor2d.Vec2{})
	thor2d.Draw_Texture_Array_Layer(&ctx, array, 0, thor2d.Vec2{})
	thor2d.Draw_Texture_Array_Layer(&ctx, array, 9, thor2d.Vec2{})
	thor2d.Unload_Texture_Array(nil, nil)
	thor2d.Unload_Texture_Array(nil, &array)
	thor2d.Unload_Texture_Array(&ctx, &array)
	testing.expect(t, len(array.Layers) == 0)
	testing.expect(t, thor2d.Texture_Array_Invalid(array))

	// Loading needs a GPU backend; empty input is rejected before I/O.
	_, load_err := thor2d.Load_Texture_Array(&ctx, []string{"assets/missing.png"})
	testing.expect(t, load_err == .Backend_Initialization_Failed)
	_, nil_load := thor2d.Load_Texture_Array(nil, []string{"x.png"})
	testing.expect(t, nil_load == .Backend_Initialization_Failed)

	// Texture introspection: zeros headless, never fake numbers.
	testing.expect(t, !thor2d.Texture_Is_Readable(&ctx, thor2d.Texture{handle = 7}))
	testing.expect(t, !thor2d.Texture_Is_Readable(nil, thor2d.Texture{handle = 7}))
	testing.expect(t, thor2d.Texture_Mipmap_Count(&ctx, thor2d.Texture{handle = 7}) == 0)
	w, h := thor2d.Texture_Pixel_Size(&ctx, thor2d.Texture{handle = 7})
	testing.expect(t, w == 0 && h == 0)
}

@(test)
test_v10g2_gpu_state_headless :: proc(t: ^testing.T) {
	ctx, ok := g2_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)

	// No canvas/shader can be active without a backend.
	_, active := thor2d.Get_Active_Canvas(&ctx)
	testing.expect(t, !active)
	_, nil_active := thor2d.Get_Active_Canvas(nil)
	testing.expect(t, !nil_active)
	_, shader_active := thor2d.Get_Active_Shader(&ctx)
	testing.expect(t, !shader_active)
	_, shader_nil := thor2d.Get_Active_Shader(nil)
	testing.expect(t, !shader_nil)

	// Transform pushes are no-ops headless: depth stays 0.
	testing.expect(t, thor2d.Get_Transform_Stack_Depth(&ctx) == 0)
	testing.expect(t, thor2d.Get_Transform_Stack_Depth(nil) == 0)
	thor2d.Push_Transform(&ctx)
	testing.expect(t, thor2d.Get_Transform_Stack_Depth(&ctx) == 0)
	thor2d.Pop_Transform(&ctx)

	// No sRGB pipeline anywhere.
	testing.expect(t, !thor2d.Is_Gamma_Correct(&ctx))
	testing.expect(t, !thor2d.Is_Gamma_Correct(nil))

	// Nothing validates without a backend; messages stay non-empty.
	valid, message := thor2d.Validate_Shader(&ctx, thor2d.Shader{handle = 7})
	testing.expect(t, !valid && len(message) > 0)
	nil_valid, nil_message := thor2d.Validate_Shader(nil, thor2d.Shader{})
	testing.expect(t, !nil_valid && len(nil_message) > 0)

	// Discard validates handles, then no-ops.
	testing.expect(t, thor2d.Discard_Canvas(nil, thor2d.Canvas{}) == .Invalid_Config)
	testing.expect(t, thor2d.Discard_Canvas(&ctx, thor2d.Canvas{}) == .Invalid_Handle)
	testing.expect(t, thor2d.Discard_Canvas(&ctx, thor2d.Canvas{handle = 999}) == .None)
}

@(test)
test_v10g2_video_headless :: proc(t: ^testing.T) {
	ctx, ok := g2_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	bad := thor2d.Video_Stream{handle = 999}

	// Plain queries: false/empty, never errors.
	testing.expect(t, !thor2d.Video_Is_Playing(&ctx, bad))
	testing.expect(t, !thor2d.Video_Is_Playing(nil, bad))
	testing.expect(t, !thor2d.Video_Is_Playing(&ctx, thor2d.Video_Stream{}))
	testing.expect(t, thor2d.Video_Source_Path(&ctx, bad) == "")
	testing.expect(t, thor2d.Video_Source_Path(nil, bad) == "")

	// Fallible paths: explicit errors. Filter gating mirrors
	// Set_Video_Audio_Volume: zero handles fail first; unknown handles report
	// .Capability_Unavailable without FFmpeg, .Invalid_Handle with it.
	// Rewind is Seek(0): zero handles fail up front; unknown handles follow
	// the Seek_Video gating (.Capability_Unavailable without FFmpeg).
	testing.expect(t, thor2d.Video_Rewind(&ctx, thor2d.Video_Stream{}) == .Invalid_Handle)
	testing.expect(t, thor2d.Video_Rewind(nil, bad) == .Invalid_Handle)
	if thor2d.Query_Capability(&ctx, .Video) {
		testing.expect(t, thor2d.Video_Rewind(&ctx, bad) == .Invalid_Handle)
	} else {
		testing.expect(t, thor2d.Video_Rewind(&ctx, bad) == .Capability_Unavailable)
	}
	testing.expect(t, thor2d.Set_Video_Filter(&ctx, thor2d.Video_Stream{}, .Linear) == .Invalid_Handle)
	testing.expect(t, thor2d.Set_Video_Filter(nil, bad, .Linear) == .Invalid_Handle)
	if thor2d.Query_Capability(&ctx, .Video) {
		testing.expect(t, thor2d.Set_Video_Filter(&ctx, bad, .Linear) == .Invalid_Handle)
	} else {
		testing.expect(t, thor2d.Set_Video_Filter(&ctx, bad, .Linear) == .Capability_Unavailable)
	}

	// No test video asset ships: loading a bogus path must fail loudly
	// (.Capability_Unavailable without FFmpeg, .Resource_Load_Failed with).
	_, load_err := thor2d.Load_Video(&ctx, "assets/nonexistent-video.ogv")
	testing.expect(t, load_err != .None)
}

@(test)
test_v10g2_mesh_roundtrip_windowed :: proc(t: ^testing.T) {
	ctx, ok := g2_windowed_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	verts := g2_triangle_verts()

	mesh, create_err := thor2d.Create_Mesh(&ctx, verts[:])
	testing.expect(t, create_err == .None)
	if create_err != .None {
		return
	}
	defer thor2d.Unload_Mesh(&ctx, mesh)

	// Vertex count + accessor round-trip (0-based; LOVE ports subtract 1).
	testing.expect(t, thor2d.Mesh_Vertex_Count(&ctx, mesh) == 3)
	got, at_err := thor2d.Mesh_Vertex_At(&ctx, mesh, 1)
	testing.expect(t, at_err == .None)
	testing.expect(t, got.Position == verts[1].Position && got.UV == verts[1].UV && got.Color == verts[1].Color && got.Normal == verts[1].Normal)
	_, oob_err := thor2d.Mesh_Vertex_At(&ctx, mesh, 5)
	testing.expect(t, oob_err == .Invalid_Data)
	_, neg_err := thor2d.Mesh_Vertex_At(&ctx, mesh, -1)
	testing.expect(t, neg_err == .Invalid_Data)
	_, unknown_err := thor2d.Mesh_Vertex_At(&ctx, thor2d.Mesh{handle = 999}, 0)
	testing.expect(t, unknown_err == .Invalid_Handle)

	// Single-vertex set patches exactly one vertex (GPU + CPU stay in sync).
	replacement := thor2d.Mesh_Vertex{
		Position = thor2d.Vec2{10, 20},
		UV = thor2d.Vec2{0.25, 0.75},
		Color = thor2d.White,
		Normal = thor2d.Vec2{1, 0},
	}
	testing.expect(t, thor2d.Mesh_Set_Vertex(&ctx, mesh, 0, replacement) == .None)
	patched, _ := thor2d.Mesh_Vertex_At(&ctx, mesh, 0)
	testing.expect(t, patched == replacement)
	untouched, _ := thor2d.Mesh_Vertex_At(&ctx, mesh, 2)
	testing.expect(t, untouched.Position == verts[2].Position)
	testing.expect(t, thor2d.Mesh_Set_Vertex(&ctx, mesh, 9, replacement) == .Invalid_Data)
	testing.expect(t, thor2d.Mesh_Set_Vertex(&ctx, mesh, -1, replacement) == .Invalid_Data)

	// Draw mode getter/setter round-trip (setter rebuilds the GPU object).
	mode, mode_err := thor2d.Mesh_Draw_Mode_Of(&ctx, mesh)
	testing.expect(t, mode_err == .None && mode == .Triangles)
	testing.expect(t, thor2d.Mesh_Set_Draw_Mode(&ctx, mesh, .Triangle_Fan) == .None)
	mode, _ = thor2d.Mesh_Draw_Mode_Of(&ctx, mesh)
	testing.expect(t, mode == .Triangle_Fan)
	testing.expect(t, thor2d.Mesh_Set_Draw_Mode(&ctx, mesh, .Triangles) == .None)
	_, bad_mode := thor2d.Mesh_Draw_Mode_Of(&ctx, thor2d.Mesh{handle = 999})
	testing.expect(t, bad_mode == .Invalid_Handle)

	// GPU instanced path works on the triangle mesh with resident buffers.
	testing.expect(
		t,
		thor2d.Draw_Mesh_Instanced(&ctx, mesh, 2, thor2d.Vec2{8, 8}, 0, thor2d.Vec2{1, 1}) == .None,
	)

	// Texture binding round-trip; explicit-texture draws still work.
	bound, bound_err := thor2d.Mesh_Texture_Of(&ctx, mesh)
	testing.expect(t, bound_err == .None && bound.handle == 0)
	tex, tex_err := thor2d.Generate_Texture(&ctx, 8, 8, thor2d.White)
	testing.expect(t, tex_err == .None)
	if tex_err == .None {
		defer thor2d.Unload_Texture(&ctx, tex)
		testing.expect(t, thor2d.Set_Mesh_Texture(&ctx, mesh, tex) == .None)
		bound, _ = thor2d.Mesh_Texture_Of(&ctx, mesh)
		testing.expect(t, bound.handle == tex.handle)
		thor2d.Draw_Mesh(&ctx, mesh, thor2d.Vec2{16, 16}, 0, thor2d.Vec2{1, 1})
		thor2d.Draw_Mesh_Textured(&ctx, mesh, tex, thor2d.Vec2{24, 24}, 0, thor2d.Vec2{1, 1})
		testing.expect(t, thor2d.Set_Mesh_Texture(&ctx, mesh, thor2d.Texture{}) == .None)
		bound, _ = thor2d.Mesh_Texture_Of(&ctx, mesh)
		testing.expect(t, bound.handle == 0)
		testing.expect(
			t,
			thor2d.Set_Mesh_Texture(&ctx, mesh, thor2d.Texture{handle = 999}) == .Invalid_Handle,
		)
		testing.expect(t, thor2d.Texture_Is_Readable(&ctx, tex))
		testing.expect(t, thor2d.Texture_Mipmap_Count(&ctx, tex) == 1)
		pw, ph := thor2d.Texture_Pixel_Size(&ctx, tex)
		sw, sh := thor2d.Texture_Size(&ctx, tex)
		testing.expect(t, pw == sw && ph == sh && pw == 8 && ph == 8)
	}
	testing.expect(t, !thor2d.Texture_Is_Readable(&ctx, thor2d.Texture{handle = 999}))

	// Draw range round-trip; drawing honors it, reset restores full draws.
	rs, rc := thor2d.Mesh_Draw_Range(&ctx, mesh)
	testing.expect(t, rs == 0 && rc == -1)
	testing.expect(t, thor2d.Mesh_Set_Draw_Range(&ctx, mesh, 0, 3) == .None)
	rs, rc = thor2d.Mesh_Draw_Range(&ctx, mesh)
	testing.expect(t, rs == 0 && rc == 3)
	thor2d.Draw_Mesh(&ctx, mesh, thor2d.Vec2{32, 32}, 0, thor2d.Vec2{1, 1})
	testing.expect(t, thor2d.Mesh_Set_Draw_Range(&ctx, mesh, 0, -1) == .None)
	testing.expect(t, thor2d.Mesh_Set_Draw_Range(&ctx, mesh, -1, 2) == .Invalid_Data)
	testing.expect(t, thor2d.Mesh_Set_Draw_Range(&ctx, mesh, 0, 0) == .Invalid_Data)
	testing.expect(t, thor2d.Mesh_Set_Draw_Range(&ctx, thor2d.Mesh{handle = 999}, 0, 2) == .Invalid_Data)

	// Array load rejects empty input before I/O; bogus paths fail loudly.
	_, empty_err := thor2d.Load_Texture_Array(&ctx, nil)
	testing.expect(t, empty_err == .Invalid_Config)
	_, bogus_err := thor2d.Load_Texture_Array(&ctx, []string{"assets/nope-a.png", "assets/nope-b.png"})
	testing.expect(t, bogus_err != .None)
}

@(test)
test_v10g2_texture_array_windowed :: proc(t: ^testing.T) {
	ctx, ok := g2_windowed_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)

	// Real GPU layers behind the CPU-side array value: draw + unload.
	a, a_err := thor2d.Generate_Texture(&ctx, 4, 4, thor2d.Red)
	testing.expect(t, a_err == .None)
	b, b_err := thor2d.Generate_Texture(&ctx, 4, 4, thor2d.Blue)
	testing.expect(t, b_err == .None)
	if a_err != .None || b_err != .None {
		return
	}
	array := thor2d.Texture_Array{}
	append(&array.Layers, a)
	append(&array.Layers, b)
	testing.expect(t, thor2d.Texture_Array_Layer_Count(array) == 2)
	thor2d.Draw_Texture_Array_Layer(&ctx, array, 0, thor2d.Vec2{4, 4})
	thor2d.Draw_Texture_Array_Layer(&ctx, array, 1, thor2d.Vec2{12, 12}, thor2d.Green)
	thor2d.Unload_Texture_Array(&ctx, &array)
	testing.expect(t, thor2d.Texture_Array_Invalid(array))
}

@(test)
test_v10g2_state_windowed :: proc(t: ^testing.T) {
	ctx, ok := g2_windowed_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)

	// Active-canvas tracking follows Set/Reset.
	_, active := thor2d.Get_Active_Canvas(&ctx)
	testing.expect(t, !active)
	canvas, canvas_err := thor2d.Create_Canvas(&ctx, 32, 32)
	testing.expect(t, canvas_err == .None)
	if canvas_err == .None {
		defer thor2d.Unload_Canvas(&ctx, canvas)
		thor2d.Set_Canvas(&ctx, canvas)
		got, is_active := thor2d.Get_Active_Canvas(&ctx)
		testing.expect(t, is_active && got.handle == canvas.handle)
		thor2d.Reset_Canvas(&ctx)
		_, is_still := thor2d.Get_Active_Canvas(&ctx)
		testing.expect(t, !is_still)
		testing.expect(t, thor2d.Discard_Canvas(&ctx, canvas) == .None)
	}
	testing.expect(t, thor2d.Discard_Canvas(&ctx, thor2d.Canvas{handle = 999}) == .Invalid_Handle)

	// No shader active by default; bogus handles never validate.
	_, shader_active := thor2d.Get_Active_Shader(&ctx)
	testing.expect(t, !shader_active)
	valid, message := thor2d.Validate_Shader(&ctx, thor2d.Shader{handle = 999})
	testing.expect(t, !valid && len(message) > 0)

	// Transform stack depth tracks Push/Pop nesting.
	testing.expect(t, thor2d.Get_Transform_Stack_Depth(&ctx) == 0)
	thor2d.Push_Transform(&ctx)
	thor2d.Push_Transform(&ctx)
	testing.expect(t, thor2d.Get_Transform_Stack_Depth(&ctx) == 2)
	thor2d.Pop_Transform(&ctx)
	testing.expect(t, thor2d.Get_Transform_Stack_Depth(&ctx) == 1)
	thor2d.Pop_Transform(&ctx)
	testing.expect(t, thor2d.Get_Transform_Stack_Depth(&ctx) == 0)

	testing.expect(t, !thor2d.Is_Gamma_Correct(&ctx))
}

@(test)
test_v10g2_video_windowed :: proc(t: ^testing.T) {
	ctx, ok := g2_windowed_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	bad := thor2d.Video_Stream{handle = 999}

	// No shippable video asset: error paths only, valid under both builds.
	testing.expect(t, !thor2d.Video_Is_Playing(&ctx, bad))
	testing.expect(t, thor2d.Video_Rewind(&ctx, thor2d.Video_Stream{}) == .Invalid_Handle)
	testing.expect(t, thor2d.Video_Source_Path(&ctx, bad) == "")
	_, load_err := thor2d.Load_Video(&ctx, "assets/nonexistent-video.ogv")
	testing.expect(t, load_err != .None)
	// Filter gating mirrors Set_Video_Audio_Volume (see the headless test):
	// unknown handles report .Capability_Unavailable without FFmpeg.
	if thor2d.Query_Capability(&ctx, .Video) {
		testing.expect(t, thor2d.Set_Video_Filter(&ctx, bad, .Linear) == .Invalid_Handle)
	} else {
		testing.expect(t, thor2d.Set_Video_Filter(&ctx, bad, .Linear) == .Capability_Unavailable)
	}
}
