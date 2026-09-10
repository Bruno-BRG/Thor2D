package tests

import "core:testing"
import thor2d "thor2d:thor2d"

v09_platform_on_error_called := false
v09_platform_on_error_err := thor2d.Error.None

v09_platform_on_error :: proc(ctx: ^thor2d.Context, err: thor2d.Error) {
	v09_platform_on_error_called = true
	v09_platform_on_error_err = err
	_ = ctx
}

v09_platform_noop_low_memory :: proc(ctx: ^thor2d.Context) {
	_ = ctx
}

@(test)
test_v09_joystick_list_empty_headless :: proc(t: ^testing.T) {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	testing.expect(t, err == .None)
	if err != .None {
		return
	}
	defer thor2d.Destroy(&ctx)
	joysticks := thor2d.Get_Joysticks(&ctx)
	testing.expect(t, len(joysticks) == 0)
	testing.expect(t, thor2d.Get_Gamepad_Axis_Count(&ctx, 0) == 0)
	testing.expect(t, thor2d.Get_Gamepad_Button_Count(&ctx, 0) == 0)
	_, hat_err := thor2d.Get_Gamepad_Hat(&ctx, 0, 0)
	testing.expect(t, hat_err == .Unsupported)
}

@(test)
test_v09_gamepad_guid_synthetic :: proc(t: ^testing.T) {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	testing.expect(t, err == .None)
	if err != .None {
		return
	}
	defer thor2d.Destroy(&ctx)
	guid, guid_err := thor2d.Get_Gamepad_GUID(&ctx, 2)
	testing.expect(t, guid_err == .None)
	testing.expect(t, guid == "thor2d-gamepad-2")
	_, bad_err := thor2d.Get_Gamepad_GUID(&ctx, 99)
	testing.expect(t, bad_err == .Invalid_Handle)
}

@(test)
test_v09_vibration_headless_errors :: proc(t: ^testing.T) {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	testing.expect(t, err == .None)
	if err != .None {
		return
	}
	defer thor2d.Destroy(&ctx)
	// Headless has no backend: expect an explicit error, never success.
	// (Windowed with a live gamepad returns .None instead.)
	testing.expect(t, thor2d.Set_Gamepad_Vibration(&ctx, 0, 1, 1) != .None)
	testing.expect(t, thor2d.Stop_Gamepad_Vibration(&ctx, 0) != .None)
	testing.expect(t, thor2d.Set_Gamepad_Vibration(&ctx, 99, 1, 1) == .Invalid_Handle)
	testing.expect(t, thor2d.Stop_Gamepad_Vibration(&ctx, -1) == .Invalid_Handle)
}

@(test)
test_v09_cursor_headless_error_path :: proc(t: ^testing.T) {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	testing.expect(t, err == .None)
	if err != .None {
		return
	}
	defer thor2d.Destroy(&ctx)
	img, img_err := thor2d.New_Image_Data(4, 4, thor2d.White)
	testing.expect(t, img_err == .None)
	defer thor2d.Destroy_Image_Data(&img)
	// Headless has no GPU: must fail explicitly, never a fake handle.
	cursor, load_err := thor2d.Load_Cursor_From_Image(&ctx, img, 0, 0)
	testing.expect(t, load_err != .None)
	testing.expect(t, thor2d.Cursor_Invalid(cursor))
	// Unload of an invalid cursor is a safe no-op.
	thor2d.Unload_Cursor(&ctx, cursor)
	// Bad hotspot is rejected before the backend is touched.
	_, hot_err := thor2d.Load_Cursor_From_Image(&ctx, img, 99, 0)
	testing.expect(t, hot_err == .Invalid_Data)
	empty := thor2d.Image_Data{}
	_, empty_err := thor2d.Load_Cursor_From_Image(&ctx, empty, 0, 0)
	testing.expect(t, empty_err == .Invalid_Data)
}

@(test)
test_v09_version_consts_and_compat :: proc(t: ^testing.T) {
	testing.expect(t, thor2d.THOR2D_VERSION_MAJOR == 0)
	testing.expect(t, thor2d.THOR2D_VERSION_MINOR == 11)
	testing.expect(t, thor2d.THOR2D_VERSION_PATCH == 0)
	major, minor, patch := thor2d.Thor2D_Version()
	testing.expect(t, major == 0 && minor == 11 && patch == 0)
	testing.expect(t, thor2d.Is_Version_Compatible(0, 11))
	testing.expect(t, thor2d.Is_Version_Compatible(0, 9))
	testing.expect(t, !thor2d.Is_Version_Compatible(0, 12))
	testing.expect(t, !thor2d.Is_Version_Compatible(1, 0))
	testing.expect(t, !thor2d.Is_Version_Compatible(-1, 0))
}

@(test)
test_v09_on_error_invoked_on_bad_config :: proc(t: ^testing.T) {
	v09_platform_on_error_called = false
	v09_platform_on_error_err = .None
	config := thor2d.Default_Config()
	config.Headless = true
	config.Width = 0
	game := thor2d.Game{On_Error = v09_platform_on_error, On_Low_Memory = v09_platform_noop_low_memory}
	err := thor2d.Run_Headless(config, game, 1)
	testing.expect(t, err == .Invalid_Config)
	testing.expect(t, v09_platform_on_error_called)
	testing.expect(t, v09_platform_on_error_err == .Invalid_Config)

	v09_platform_on_error_called = false
	v09_platform_on_error_err = .None
	bad := thor2d.Default_Config()
	bad.Width = 0
	bad.Headless = false
	err2 := thor2d.Run(bad, thor2d.Game{On_Error = v09_platform_on_error})
	testing.expect(t, err2 == .Invalid_Config)
	testing.expect(t, v09_platform_on_error_called)
}

@(test)
test_v09_update_window_mode_headless :: proc(t: ^testing.T) {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	testing.expect(t, err == .None)
	if err != .None {
		return
	}
	defer thor2d.Destroy(&ctx)
	testing.expect(t, thor2d.Update_Window_Mode(&ctx, 800, 600, false, true, false) == .None)
	testing.expect(t, ctx.config.Width == 800 && ctx.config.Height == 600)
	testing.expect(t, thor2d.Update_Window_Mode(&ctx, 0, 600, false, true, false) == .Invalid_Config)
	testing.expect(t, thor2d.Update_Window_Mode(nil, 800, 600, false, true, false) == .Invalid_Config)
}
