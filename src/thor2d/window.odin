package thor2d

import backend "thor2d:thor2d/internal/raylib"

// v0.8 LOVE-parity window gaps. Mirrors love.window queries missing from v0.7.
// All procs are headless-safe (return zero values when backend is nil).

Window_Title :: proc(ctx: ^Context) -> string {
	if ctx == nil {
		return ""
	}
	return ctx.config.Title
}

Window_Is_Open :: proc(ctx: ^Context) -> bool {
	return ctx != nil && !ctx.headless && ctx.backend != nil && backend.Is_Window_Open(ctx.backend)
}

Close_Window :: proc(ctx: ^Context) {
	if ctx != nil {
		ctx.running = false
	}
}

Window_Is_Visible :: proc(ctx: ^Context) -> bool {
	return ctx != nil && !ctx.headless && ctx.backend != nil && backend.Is_Visible(ctx.backend)
}

Window_Has_Focus :: proc(ctx: ^Context) -> bool {
	return ctx != nil && !ctx.headless && ctx.backend != nil && backend.Has_Focus(ctx.backend)
}

Window_Has_Mouse_Focus :: proc(ctx: ^Context) -> bool {
	return Window_Has_Focus(ctx)
}

Window_Is_Maximized :: proc(ctx: ^Context) -> bool {
	return ctx != nil && !ctx.headless && ctx.backend != nil && backend.Is_Maximized(ctx.backend)
}

Maximize_Window :: proc(ctx: ^Context) -> Error {
	if ctx == nil || ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	backend.Maximize_Window(ctx.backend)
	return .None
}

Minimize_Window :: proc(ctx: ^Context) -> Error {
	if ctx == nil || ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	backend.Minimize_Window(ctx.backend)
	return .None
}

Restore_Window :: proc(ctx: ^Context) -> Error {
	if ctx == nil || ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	backend.Restore_Window(ctx.backend)
	return .None
}

Get_Window_Mode :: proc(ctx: ^Context) -> (width, height: int, fullscreen, resizable, vsync: bool) {
	if ctx == nil {
		return 0, 0, false, false, false
	}
	w, h := Window_Size(ctx)
	return w, h, Window_Is_Fullscreen(ctx), ctx.config.Resizable, ctx.config.VSync
}

Get_VSync :: proc(ctx: ^Context) -> bool {
	if ctx == nil || ctx.backend == nil {
		return false
	}
	return backend.Get_VSync(ctx.backend)
}

Set_VSync :: proc(ctx: ^Context, enabled: bool) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	// Raylib sets VSYNC_HINT at window creation only. Report honestly.
	ctx.config.VSync = enabled
	return .Unsupported
}

Get_Display_Count :: proc(ctx: ^Context) -> int {
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	return backend.Get_Display_Count(ctx.backend)
}

Get_Display_Info :: proc(ctx: ^Context, index: int) -> (Display_Info, Error) {
	if ctx == nil || ctx.backend == nil {
		return Display_Info{}, .Backend_Initialization_Failed
	}
	name, x, y, w, h, ok := backend.Get_Display_Info(ctx.backend, index)
	if !ok {
		return Display_Info{}, .Invalid_Handle
	}
	return Display_Info{Index = index, Name = name, X = x, Y = y, W = w, H = h}, .None
}

// Get_Safe_Area returns the full window on desktop (no notch concept).
Get_Safe_Area :: proc(ctx: ^Context) -> Rect {
	w, h := Window_Size(ctx)
	return Rect{X = 0, Y = 0, W = f32(w), H = f32(h)}
}

Set_Window_Icon :: proc(ctx: ^Context, image: Image_Data) -> Error {
	if ctx == nil || ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	if image.Width <= 0 || image.Height <= 0 || len(image.Pixels) == 0 {
		return .Invalid_Data
	}
	if !backend.Set_Window_Icon_RGBA(ctx.backend, image.Width, image.Height, image.Pixels[:]) {
		return .Invalid_Data
	}
	// v0.10: record success — the backend has no icon getter, so this flag
	// backs Window_Has_Icon.
	ctx.window_has_icon = true
	return .None
}

Show_Message_Box :: proc(ctx: ^Context, title, message: string) -> Error {
	_ = ctx
	_ = title
	_ = message
	// No native message-box in the raylib backend; keep explicit.
	return .Unsupported
}

Get_Power_Info :: proc() -> Power_Info {
	// Desktop: no battery API in the backend yet.
	return Power_Info{State = "nobattery", Percent = 100}
}

Has_Background_Music :: proc(ctx: ^Context) -> bool {
	_ = ctx
	return false
}

// Update_Window_Mode mirrors the love.window.setMode(width, height, flags)
// subset. Size and fullscreen apply immediately via Set_Window_Size /
// Set_Fullscreen when a backend is present; resizable/vsync are stored in
// ctx.config. Raylib fixes VSYNC_HINT and the resizable flag at window
// creation, so vsync/resizable changes need a restart where the backend
// requires it. Returns .None and applies what is possible, never fakes:
// headless stores the config and returns .None (nothing to apply to).
// Non-positive size maps to .Invalid_Config; nil ctx maps to .Invalid_Config.
Update_Window_Mode :: proc(ctx: ^Context, width, height: int, fullscreen, resizable, vsync: bool) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	if width <= 0 || height <= 0 {
		return .Invalid_Config
	}
	ctx.config.Resizable = resizable
	ctx.config.VSync = vsync
	if ctx.backend == nil {
		ctx.config.Width = width
		ctx.config.Height = height
		return .None
	}
	Set_Window_Size(ctx, width, height)
	ctx.config.Width = width
	ctx.config.Height = height
	Set_Fullscreen(ctx, fullscreen)
	return .None
}

// Get_Display_Orientation is a mobile-future helper (mirrors the
// portrait/landscape queries mobile LOVE ports need). Desktop has no
// orientation sensor, so it derives the answer from the window aspect:
// width >= height is "landscape", otherwise "portrait". Headless (or nil
// ctx, or zero size) has no window and reports "unknown".
// See guides/Mobile.md.
Get_Display_Orientation :: proc(ctx: ^Context) -> string {
	if ctx == nil || ctx.backend == nil {
		return "unknown"
	}
	w, h := Window_Size(ctx)
	if w <= 0 || h <= 0 {
		return "unknown"
	}
	if w >= h {
		return "landscape"
	}
	return "portrait"
}

// Set_Display_Sleep_Enabled is a mobile-future stub (mirrors keeping the
// screen awake on phones). `enabled = false` would ask the OS to keep the
// display on; desktop has no such API in the raylib backend, so this
// always returns .Unsupported instead of pretending — including for nil ctx
// (there is nothing to store the intent on). The intent IS stored on live
// Contexts (backing Is_Display_Sleep_Enabled) so games can round-trip their
// request. See guides/Mobile.md.
Set_Display_Sleep_Enabled :: proc(ctx: ^Context, enabled: bool) -> Error {
	if ctx != nil {
		ctx.display_sleep_enabled = enabled
	}
	return .Unsupported
}

// v0.10 window completion.

// Is_Display_Sleep_Enabled is the getter for the Set_Display_Sleep_Enabled
// intent (mirrors love.window.isDisplaySleepEnabled reads). Default true;
// nil ctx reports the default. The value is stored intent, not OS state:
// desktop never honors the request (setter returns .Unsupported).
Is_Display_Sleep_Enabled :: proc(ctx: ^Context) -> bool {
	if ctx == nil {
		return true
	}
	return ctx.display_sleep_enabled
}

// Window_Has_Icon reports whether Set_Window_Icon has succeeded on this
// Context (mirrors love.window.getIcon presence checks). The raylib backend
// exposes no icon getter, so this stored flag is the honest answer; nil or
// headless Contexts report false.
Window_Has_Icon :: proc(ctx: ^Context) -> bool {
	return ctx != nil && ctx.window_has_icon
}

// Get_Fullscreen_Modes lists one Display_Mode per monitor (mirrors
// love.window.getFullscreenModes). Width/Height come from Get_Display_Info;
// Refresh_Rate is filled from Current_Display_Mode when its dimensions match
// the monitor (the backend only reports the current monitor's rate), else 0
// ("unknown" — never a guessed 60). Headless or nil ctx yields an empty
// array. The caller owns the returned array (delete it).
Get_Fullscreen_Modes :: proc(ctx: ^Context) -> [dynamic]Display_Mode {
	modes := make([dynamic]Display_Mode, 0, context.allocator)
	if ctx == nil || ctx.backend == nil {
		return modes
	}
	count := Get_Display_Count(ctx)
	current := Current_Display_Mode(ctx)
	for i in 0..<count {
		info, info_err := Get_Display_Info(ctx, i)
		if info_err != .None {
			continue
		}
		refresh := 0
		if current.Refresh_Rate > 0 && info.W == current.Width && info.H == current.Height {
			refresh = current.Refresh_Rate
		}
		append(&modes, Display_Mode{Width = info.W, Height = info.H, Refresh_Rate = refresh})
	}
	return modes
}

// Request_Attention asks the window manager to draw attention to the window
// (mirrors love.window.requestAttention / taskbar flashing). The raylib
// backend exposes no such API (vendor/raylib has no RequestWindowAttention
// binding — verified v0.10), so this always returns .Unsupported instead of a
// fake flash. Nil ctx maps to .Invalid_Config; headless maps to
// .Backend_Initialization_Failed.
Request_Attention :: proc(ctx: ^Context) -> Error {
	if ctx == nil {
		return .Invalid_Config
	}
	if ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	return .Unsupported
}
