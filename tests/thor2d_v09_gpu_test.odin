package tests

import "core:testing"
import thor2d "thor2d:thor2d"

// v0.9 P1 GPU-side gaps. All tests are headless-safe: with no backend every
// GPU path is unavailable, so the suite asserts explicit errors (.Unsupported
// / .Invalid_*) and stored state — never fake success.

v09_gpu_headless_ctx :: proc(t: ^testing.T) -> thor2d.Context {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	testing.expect(t, err == .None)
	return ctx
}

@(test)
test_v09_gpu_instancing_rejects_bad_input :: proc(t: ^testing.T) {
	ctx := v09_gpu_headless_ctx(t)
	defer thor2d.Destroy(&ctx)
	mesh := thor2d.Mesh{handle = 999}
	testing.expect(t, thor2d.Draw_Mesh_Instanced(nil, mesh, 4, thor2d.Vec2{}, 0, thor2d.Vec2{1, 1}) == .Invalid_Config)
	testing.expect(t, thor2d.Draw_Mesh_Instanced(&ctx, thor2d.Mesh{}, 4, thor2d.Vec2{}, 0, thor2d.Vec2{1, 1}) == .Invalid_Handle)
	testing.expect(t, thor2d.Draw_Mesh_Instanced(&ctx, mesh, 0, thor2d.Vec2{}, 0, thor2d.Vec2{1, 1}) == .Invalid_Handle)
	testing.expect(t, thor2d.Draw_Mesh_Instanced(&ctx, mesh, -3, thor2d.Vec2{}, 0, thor2d.Vec2{1, 1}) == .Invalid_Handle)
}

@(test)
test_v09_gpu_instancing_headless_fallback :: proc(t: ^testing.T) {
	ctx := v09_gpu_headless_ctx(t)
	defer thor2d.Destroy(&ctx)
	// No backend headless: the per-instance Draw_Mesh loop no-ops and the
	// proc reports the CPU fallback honestly.
	mesh := thor2d.Mesh{handle = 999}
	testing.expect(t, thor2d.Draw_Mesh_Instanced(&ctx, mesh, 4, thor2d.Vec2{10, 10}, 0, thor2d.Vec2{1, 1}) == .Unsupported)
	testing.expect(t, thor2d.Query_Capability(&ctx, .Instancing) == false)
	testing.expect(t, thor2d.Is_Graphics_Supported(&ctx, "instancing") == false)
	testing.expect(t, thor2d.Get_System_Limits(&ctx).Instancing == false)
}

@(test)
test_v09_gpu_color_mask_headless :: proc(t: ^testing.T) {
	ctx := v09_gpu_headless_ctx(t)
	defer thor2d.Destroy(&ctx)
	// v0.9 spike: no color-mask API in vendor/raylib, so the mask is stored
	// for Get_Color_Mask but every set reports .Unsupported.
	mask := thor2d.Color_Mask{R = true, G = false, B = true, A = false}
	testing.expect(t, thor2d.Set_Color_Mask(&ctx, mask) == .Unsupported)
	testing.expect(t, thor2d.Get_Color_Mask(&ctx) == mask)
	testing.expect(t, thor2d.Set_Color_Mask(nil, mask) == .Invalid_Config)
	testing.expect(t, thor2d.Query_Capability(&ctx, .Color_Mask) == false)
}

@(test)
test_v09_gpu_stencil_headless :: proc(t: ^testing.T) {
	ctx := v09_gpu_headless_ctx(t)
	defer thor2d.Destroy(&ctx)
	// v0.9 spike: no stencil buffer or test API in the backend; both procs
	// report .Unsupported (see Graphics.md "Stencil (v0.9 spike)").
	testing.expect(t, thor2d.Set_Stencil_Test(&ctx, true) == .Unsupported)
	testing.expect(t, thor2d.Clear_Stencil(&ctx) == .Unsupported)
	testing.expect(t, thor2d.Set_Stencil_Test(nil, true) == .Invalid_Config)
	testing.expect(t, thor2d.Clear_Stencil(nil) == .Invalid_Config)
	testing.expect(t, thor2d.Query_Capability(&ctx, .Stencil) == false)
	testing.expect(t, thor2d.Is_Graphics_Supported(&ctx, "stencil") == false)
	testing.expect(t, thor2d.Get_System_Limits(&ctx).Stencil == false)
}

@(test)
test_v09_gpu_canvas_format_query_headless :: proc(t: ^testing.T) {
	ctx := v09_gpu_headless_ctx(t)
	defer thor2d.Destroy(&ctx)
	// Headless reports false for every format, including RGBA8.
	testing.expect(t, thor2d.Is_Canvas_Format_Supported(&ctx, .RGBA8) == false)
	testing.expect(t, thor2d.Is_Canvas_Format_Supported(&ctx, .RGBA16F) == false)
	testing.expect(t, thor2d.Is_Canvas_Format_Supported(&ctx, .RGBA32F) == false)
	testing.expect(t, thor2d.Is_Canvas_Format_Supported(&ctx, .Depth_Stencil) == false)
	testing.expect(t, thor2d.Is_Canvas_Format_Supported(nil, .RGBA8) == false)
}

@(test)
test_v09_gpu_canvas_format_create_headless :: proc(t: ^testing.T) {
	ctx := v09_gpu_headless_ctx(t)
	defer thor2d.Destroy(&ctx)
	// No backend headless: creation is rejected before format checks.
	_, err := thor2d.Create_Canvas_Format(&ctx, 64, 64, .RGBA8, 0)
	testing.expect(t, err == .Invalid_Config)
	_, float_err := thor2d.Create_Canvas_Format(&ctx, 64, 64, .RGBA16F, 0)
	testing.expect(t, float_err != .None)
	_, msaa_err := thor2d.Create_Canvas_Format(&ctx, 64, 64, .RGBA8, 4)
	testing.expect(t, msaa_err != .None)
	_, dim_err := thor2d.Create_Canvas_Format(&ctx, 0, 64, .RGBA8, 0)
	testing.expect(t, dim_err == .Invalid_Config)
	_, nil_err := thor2d.Create_Canvas_Format(nil, 64, 64, .RGBA8, 0)
	testing.expect(t, nil_err == .Invalid_Config)
}

@(test)
test_v09_gpu_msaa_default_zero :: proc(t: ^testing.T) {
	// MSAA defaults to off; the field survives a headless round-trip and a
	// plain struct copy so presets can set it before Create/Run.
	config := thor2d.Default_Config()
	testing.expect(t, config.MSAA == 0)
	config.MSAA = 4
	ctx, err := thor2d.Create(config)
	testing.expect(t, err == .None)
	defer thor2d.Destroy(&ctx)
	testing.expect(t, ctx.config.MSAA == 4)
}

@(test)
test_v09_gpu_capability_nil_ctx :: proc(t: ^testing.T) {
	// Nil contexts report no GPU capabilities.
	testing.expect(t, thor2d.Query_Capability(nil, .Instancing) == false)
	testing.expect(t, thor2d.Query_Capability(nil, .Stencil) == false)
	testing.expect(t, thor2d.Query_Capability(nil, .Color_Mask) == false)
	testing.expect(t, thor2d.Query_Capability(nil, .GPU_Mesh) == false)
}
