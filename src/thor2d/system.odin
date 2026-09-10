package thor2d

import "core:os"
import "core:time"
import backend "thor2d:thor2d/internal/raylib"

FPS :: proc(ctx: ^Context) -> int {
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	return backend.FPS(ctx.backend)
}

Frame_Time_Average :: proc(ctx: ^Context) -> f32 {
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	return backend.Average_Frame_Time(ctx.backend)
}

Get_Runtime_Metrics :: proc(ctx: ^Context) -> Runtime_Metrics {
	if ctx == nil {
		return Runtime_Metrics{}
	}
	return Runtime_Metrics{
		FPS = FPS(ctx),
		Frame_Time = ctx.delta,
		Average_Frame_Time = Frame_Time_Average(ctx),
		Fixed_Step_Backlog = ctx.fixed_accumulator,
		Fixed_Steps = ctx.fixed_steps,
		Active_Audio_Sources = Active_Audio_Source_Count(ctx),
	}
}

Fixed_Step_Backlog :: proc(ctx: ^Context) -> f32 {
	if ctx == nil {
		return 0
	}
	return ctx.fixed_accumulator
}

Sleep :: proc(seconds: f64) {
	if seconds > 0 {
		time.sleep(time.Duration(seconds * f64(time.Second)))
	}
}

Clipboard_Text :: proc(ctx: ^Context) -> string {
	if ctx == nil || ctx.backend == nil {
		return ""
	}
	return backend.Clipboard_Text(ctx.backend)
}

Set_Clipboard_Text :: proc(ctx: ^Context, value: string) {
	if ctx != nil && ctx.backend != nil {
		backend.Set_Clipboard_Text(ctx.backend, value)
	}
}

Open_URL :: proc(ctx: ^Context, value: string) -> Error {
	if ctx == nil || ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	if !backend.Open_URL(ctx.backend, value) {
		return .Capability_Unavailable
	}
	return .None
}

Processor_Count :: proc() -> int {
	return os.get_processor_core_count()
}

Process_Arguments :: proc() -> []string {
	return os.args
}

Locale :: proc() -> string {
	if value, found := os.lookup_env("LC_ALL", context.temp_allocator); found {
		return value
	}
	if value, found := os.lookup_env("LANG", context.temp_allocator); found {
		return value
	}
	return "C"
}

Operating_System :: proc() -> string {
	when ODIN_OS == .Linux {
		return "Linux"
	} else when ODIN_OS == .Windows {
		return "Windows"
	} else when ODIN_OS == .Darwin {
		return "macOS"
	} else {
		return "Unknown"
	}
}

Window_Position :: proc(ctx: ^Context) -> Vec2 {
	if ctx == nil || ctx.backend == nil {
		return Vec2{}
	}
	x, y := backend.Window_Position(ctx.backend)
	return Vec2{f32(x), f32(y)}
}

Set_Window_Position :: proc(ctx: ^Context, position: Vec2) {
	if ctx != nil && ctx.backend != nil {
		backend.Set_Window_Position(ctx.backend, int(position.X), int(position.Y))
	}
}

Window_DPI_Scale :: proc(ctx: ^Context) -> Vec2 {
	if ctx == nil || ctx.backend == nil {
		return Vec2{1, 1}
	}
	x, y := backend.Window_DPI_Scale(ctx.backend)
	return Vec2{x, y}
}

Window_Is_Fullscreen :: proc(ctx: ^Context) -> bool {
	return ctx != nil && ctx.backend != nil && backend.Is_Fullscreen(ctx.backend)
}

Window_Is_Minimized :: proc(ctx: ^Context) -> bool {
	return ctx != nil && ctx.backend != nil && backend.Is_Minimized(ctx.backend)
}

Desktop_Size :: proc(ctx: ^Context) -> (width, height: int) {
	if ctx == nil || ctx.backend == nil {
		return 0, 0
	}
	return backend.Desktop_Size(ctx.backend)
}

Current_Display_Mode :: proc(ctx: ^Context) -> Display_Mode {
	if ctx == nil || ctx.backend == nil {
		return Display_Mode{}
	}
	width, height, refresh_rate := backend.Current_Display_Mode(ctx.backend)
	return Display_Mode{Width = width, Height = height, Refresh_Rate = refresh_rate}
}

Set_Fullscreen :: proc(ctx: ^Context, fullscreen: bool) -> Error {
	if ctx == nil || ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	if backend.Is_Fullscreen(ctx.backend) != fullscreen {
		backend.Toggle_Fullscreen(ctx.backend)
	}
	return .None
}

Set_Cursor_Visible :: proc(ctx: ^Context, visible: bool) -> Error {
	if ctx == nil || ctx.backend == nil {
		return .Backend_Initialization_Failed
	}
	backend.Set_Cursor_Visible(ctx.backend, visible)
	ctx.cursor_visible = visible
	return .None
}

Is_Cursor_Visible :: proc(ctx: ^Context) -> bool {
	if ctx == nil {
		return true
	}
	return ctx.cursor_visible
}

Set_Mouse_Grab :: proc(ctx: ^Context, grab: bool) {
	if ctx == nil {
		return
	}
	ctx.cursor_grabbed = grab
	if ctx.backend != nil {
		backend.Set_Mouse_Grab(ctx.backend, grab)
	}
}

// Thor2D_Version mirrors love.getVersion (without codename). Returns the
// THOR2D_VERSION_* constants. No ctx needed; pure compile-time version.
Thor2D_Version :: proc() -> (major, minor, patch: int) {
	return THOR2D_VERSION_MAJOR, THOR2D_VERSION_MINOR, THOR2D_VERSION_PATCH
}

// Is_Version_Compatible mirrors love.isVersionCompatible for the major.minor
// subset. Same major and requested minor <= current minor is compatible.
Is_Version_Compatible :: proc(major, minor: int) -> bool {
	if major < 0 || minor < 0 {
		return false
	}
	return major == THOR2D_VERSION_MAJOR && minor <= THOR2D_VERSION_MINOR
}

// Vibrate is a mobile-future stub (mirrors love.system.vibrate).
// Desktop has no vibration hardware, so any positive duration returns
// .Unsupported instead of a fake buzz. Non-positive durations are rejected
// with .Invalid_Data before the backend is touched. A future mobile backend
// will vibrate for `seconds` and return .None. See guides/Mobile.md.
Vibrate :: proc(seconds: f32) -> Error {
	if !(seconds > 0) {
		return .Invalid_Data
	}
	return .Unsupported
}
