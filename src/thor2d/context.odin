package thor2d

import "core:strings"
import "core:time"
import "core:os"
import backend "thor2d:thor2d/internal/raylib"
import audio "thor2d:thor2d/internal/audio"
import video "thor2d:thor2d/internal/video"

Create :: proc(config: Config) -> (Context, Error) {
	if config.Width <= 0 || config.Height <= 0 || config.Target_FPS < 0 {
		return Context{}, .Invalid_Config
	}
	filesystem, filesystem_err := Init_Filesystem(config.Source_Directory, config.Save_Directory)
	if filesystem_err != .None {
		return Context{}, filesystem_err
	}
	identity := config.Identity
	if identity == "" {
		identity = "thor2d"
	}
	if identity_err := Set_Identity(&filesystem, identity); identity_err != .None {
		Destroy_Filesystem(&filesystem)
		return Context{}, identity_err
	}
	package_path := config.Package_Path
	if package_path == "" {
		if environment_path, found := os.lookup_env("THOR2D_PACKAGE_ARCHIVE", context.temp_allocator); found {
			package_path = environment_path
			// lookup_env uses the temporary allocator here. Do not call delete on
			// that allocation: the temp allocator owns the whole frame and may
			// not be individually freed with the heap allocator.
		}
	}
	if package_path != "" {
		mount_err := Mount_Archive_File(&filesystem, package_path)
		if mount_err != .None {
			Destroy_Filesystem(&filesystem)
			return Context{}, mount_err
		}
	}
	if config.Headless {
		return Context{
			config = config,
			running = true,
			headless = true,
			fixed_delta = 1.0 / 60.0,
			Registry = New_Registry(),
			filesystem = filesystem,
			video_backend = video.Create(),
			draw_color = White,
			background_color = Black,
			graphics_transform = Identity_Transform(),
			blend_mode = .Alpha,
			line_width = 1,
			point_size = 2,
			color_mask = Color_Mask{R = true, G = true, B = true, A = true},
			default_filter_min = .Linear,
			default_filter_mag = .Linear,
			cursor_visible = true,
			meter_scale = config.Pixels_Per_Meter,
			display_sleep_enabled = true,
		}, .None
	}

	state, ok := backend.Create(config.Title, config.Width, config.Height, config.Target_FPS, config.Resizable, config.VSync, config.MSAA)
	if !ok {
		Destroy_Filesystem(&filesystem)
		return Context{}, .Backend_Initialization_Failed
	}
	audio_state, _ := audio.Create()
	meter := config.Pixels_Per_Meter
	if meter <= 0 {
		meter = 32
	}
	return Context{
		backend = state,
		audio_backend = audio_state,
		video_backend = video.Create(),
		config = config,
		running = true,
		headless = false,
		fixed_delta = 1.0 / 60.0,
		Registry = New_Registry(),
		filesystem = filesystem,
		draw_color = White,
		background_color = Black,
		graphics_transform = Identity_Transform(),
		blend_mode = .Alpha,
		line_width = 1,
		point_size = 2,
		color_mask = Color_Mask{R = true, G = true, B = true, A = true},
		default_filter_min = .Linear,
		default_filter_mag = .Linear,
		cursor_visible = true,
		meter_scale = meter,
		display_sleep_enabled = true,
	}, .None
}

Destroy :: proc(ctx: ^Context) {
	if ctx == nil {
		return
	}
	for i := 0; i < len(ctx.threads); i += 1 {
		Join_Thread(&ctx.threads[i])
	}
	delete(ctx.threads)
	Destroy_Registry(&ctx.Registry)
	for event in ctx.events {
		delete(event.Path)
		delete(event.Editing)
	}
	delete(ctx.events)
	delete(ctx.graphics_transform_stack)
	Destroy_All_Physics(ctx)
	if ctx.audio_backend != nil {
		audio.Destroy(ctx.audio_backend)
	}
	ctx.audio_backend = nil
	if ctx.video_backend != nil {
		video.Destroy(ctx.video_backend, ctx.backend)
	}
	ctx.video_backend = nil
	Destroy_Filesystem(&ctx.filesystem)
	if ctx.backend != nil {
		backend.Destroy(ctx.backend)
	}
	ctx.backend = nil
	ctx.running = false
}

// Register_Thread transfers ownership of a worker to the Context. Destroy
// will join all registered workers before releasing the rest of the runtime.
Register_Thread :: proc(ctx: ^Context, thread: Thread) -> Error {
	if ctx == nil || thread.native == nil {
		return .Invalid_Handle
	}
	append(&ctx.threads, thread)
	return .None
}

Filesystem_Access :: proc(ctx: ^Context) -> ^Filesystem {
	if ctx == nil {
		return nil
	}
	return &ctx.filesystem
}

Run :: proc(config: Config, game: Game) -> Error {
	if config.Headless {
		return Run_Headless(config, game, 0)
	}
	ctx, err := Create(config)
	if err != .None {
		// v0.9: no Context exists when Create fails, so On_Error (if set)
		// is invoked with a nil ctx and the Create error. Callers must
		// handle a nil ctx in On_Error for this path.
		if game.On_Error != nil {
			game.On_Error(nil, err)
		}
		return err
	}

	if game.Load != nil {
		game.Load(&ctx)
	}

	for ctx.running {
		ctx.delta = Begin_Frame(&ctx)
		Poll_Events(&ctx, game.On_Event)
		ctx.fixed_accumulator += min(ctx.delta, 0.25)
		ctx.fixed_steps = 0
		for ctx.fixed_accumulator >= ctx.fixed_delta && ctx.fixed_steps < 8 {
			if game.Fixed_Update != nil {
				game.Fixed_Update(&ctx, ctx.fixed_delta)
			}
			Step_All_Physics(&ctx, ctx.fixed_delta)
			ctx.fixed_accumulator -= ctx.fixed_delta
			ctx.fixed_steps += 1
		}
		if game.Update != nil {
			game.Update(&ctx, ctx.delta)
		}
		if game.Draw != nil {
			game.Draw(&ctx)
		}
		End_Frame(&ctx)
	}

	if game.Shutdown != nil {
		game.Shutdown(&ctx)
	}
	Destroy(&ctx)
	return .None
}

Fixed_Delta_Time :: proc(ctx: ^Context) -> f32 {
	if ctx == nil {
		return 1.0 / 60.0
	}
	return ctx.fixed_delta
}

Fixed_Steps_Last_Frame :: proc(ctx: ^Context) -> int {
	if ctx == nil {
		return 0
	}
	return ctx.fixed_steps
}

Is_Running :: proc(ctx: ^Context) -> bool {
	return ctx != nil && ctx.running && (ctx.headless || backend.Is_Running(ctx.backend))
}

Quit :: proc(ctx: ^Context) {
	if ctx != nil {
		ctx.running = false
	}
}

Begin_Frame :: proc(ctx: ^Context) -> f32 {
	if ctx == nil {
		return 0
	}
	if ctx.headless {
		ctx.delta = ctx.fixed_delta
		return ctx.delta
	}
	if ctx.backend == nil {
		return 0
	}
	backend.Begin_Frame(ctx.backend)
	ctx.delta = backend.Delta_Time(ctx.backend)
	return ctx.delta
}

End_Frame :: proc(ctx: ^Context) {
	if ctx != nil && ctx.backend != nil {
		if ctx.audio_backend != nil {
			audio.Update(ctx.audio_backend)
		}
		backend.End_Frame(ctx.backend)
	} else if ctx != nil && ctx.audio_backend != nil {
		audio.Update(ctx.audio_backend)
	}
}

Poll_Events :: proc(ctx: ^Context, callback: proc(ctx: ^Context, event: Event)) {
	if ctx == nil || ctx.headless || ctx.backend == nil {
		return
	}
	for raw in backend.Poll_Events(ctx.backend) {
		event := Event{}
		switch raw.kind {
		case .Quit:
			event.Kind = .Quit
			ctx.running = false
		case .Key_Pressed:
			event.Kind = .Key_Pressed
			event.Key = Key(raw.key)
		case .Key_Released:
			event.Kind = .Key_Released
			event.Key = Key(raw.key)
		case .Text_Input:
			event.Kind = .Text_Input
			event.Text = raw.text
		case .Key_Text_Edited:
			event.Kind = .Key_Text_Edited
			event.Editing = raw.path
		case .Mouse_Button_Pressed:
			event.Kind = .Mouse_Button_Pressed
			event.Mouse_Button = Mouse_Button(raw.mouse_button)
		case .Mouse_Button_Released:
			event.Kind = .Mouse_Button_Released
			event.Mouse_Button = Mouse_Button(raw.mouse_button)
		case .Mouse_Moved:
			event.Kind = .Mouse_Moved
			event.Position = Vec2{raw.x, raw.y}
			event.Delta = Vec2{raw.dx, raw.dy}
		case .Mouse_Wheel:
			event.Kind = .Mouse_Wheel
			event.Position = Vec2{raw.x, raw.y}
			event.Delta = Vec2{raw.dx, raw.dy}
		case .Window_Resized:
			event.Kind = .Window_Resized
			event.Width = raw.width
			event.Height = raw.height
		case .Focus_Changed:
			event.Kind = .Focus_Changed
			event.Focused = raw.focused
		case .Window_Visible:
			event.Kind = .Window_Visible
			event.Visible = raw.visible
		case .Gamepad_Button_Pressed:
			event.Kind = .Gamepad_Button_Pressed
			event.Device = raw.device
			event.Button = raw.button
		case .Gamepad_Button_Released:
			event.Kind = .Gamepad_Button_Released
			event.Device = raw.device
			event.Button = raw.button
		case .Gamepad_Axis_Moved:
			event.Kind = .Gamepad_Axis_Moved
			event.Device = raw.device
			event.Axis = raw.axis
			event.Value = raw.value
		case .Joystick_Added:
			event.Kind = .Joystick_Added
			event.Device = raw.device
		case .Joystick_Removed:
			event.Kind = .Joystick_Removed
			event.Device = raw.device
		case .Joystick_Button_Pressed:
			event.Kind = .Joystick_Button_Pressed
			event.Device = raw.device
			event.Button = raw.button
		case .Joystick_Button_Released:
			event.Kind = .Joystick_Button_Released
			event.Device = raw.device
			event.Button = raw.button
		case .Joystick_Axis_Moved:
			event.Kind = .Joystick_Axis_Moved
			event.Device = raw.device
			event.Axis = raw.axis
			event.Value = raw.value
		case .Joystick_Hat_Moved:
			event.Kind = .Joystick_Hat_Moved
			event.Device = raw.device
			event.Hat = raw.hat
			event.Value = raw.value
		case .Touch_Pressed:
			event.Kind = .Touch_Pressed
			event.Touch_ID = raw.touch_id
			event.Position = Vec2{raw.x, raw.y}
		case .Touch_Released:
			event.Kind = .Touch_Released
			event.Touch_ID = raw.touch_id
		case .Touch_Moved:
			event.Kind = .Touch_Moved
			event.Touch_ID = raw.touch_id
			event.Position = Vec2{raw.x, raw.y}
		case .File_Dropped, .Directory_Dropped:
			event.Kind = Event_Kind(raw.kind)
			// v0.10: raylib reports every drop as File_Dropped
			// (LoadDroppedFiles has no kind). Reclassify real OS
			// directories via the filesystem so LOVE directorydropped
			// ports work; missing paths keep the File_Dropped kind.
			if raw.kind == .File_Dropped && raw.path != "" && os.is_directory(raw.path) {
				event.Kind = .Directory_Dropped
			}
			event.Path = raw.path
		}
		Push_Event(ctx, event)
		if callback != nil {
			callback(ctx, event)
		}
	}
}

// Run_Headless executes the same fixed/update/draw lifecycle without creating
// a window or touching Raylib. max_frames <= 0 means run until Quit is called.
// v0.9: a Create failure invokes game.On_Error (if set) with a nil ctx, then
// returns the error. On_Low_Memory is never invoked on desktop (no OS
// low-memory signal); it is reserved as mobile-future.
Run_Headless :: proc(config: Config, game: Game, max_frames: int = 0) -> Error {
	headless_config := config
	headless_config.Headless = true
	ctx, err := Create(headless_config)
	if err != .None {
		if game.On_Error != nil {
			game.On_Error(nil, err)
		}
		return err
	}
	if game.Load != nil {
		game.Load(&ctx)
	}
	frames := 0
	for ctx.running && (max_frames <= 0 || frames < max_frames) {
		ctx.delta = Begin_Frame(&ctx)
		ctx.fixed_accumulator += min(ctx.delta, 0.25)
		ctx.fixed_steps = 0
		for ctx.fixed_accumulator >= ctx.fixed_delta && ctx.fixed_steps < 8 {
			if game.Fixed_Update != nil {
				game.Fixed_Update(&ctx, ctx.fixed_delta)
			}
			Step_All_Physics(&ctx, ctx.fixed_delta)
			ctx.fixed_accumulator -= ctx.fixed_delta
			ctx.fixed_steps += 1
		}
		if game.Update != nil {
			game.Update(&ctx, ctx.delta)
		}
		if game.Draw != nil {
			game.Draw(&ctx)
		}
		frames += 1
	}
	if game.Shutdown != nil {
		game.Shutdown(&ctx)
	}
	Destroy(&ctx)
	return .None
}

Push_Event :: proc(ctx: ^Context, event: Event) {
	if ctx == nil {
		return
	}
	copy := event
	if event.Path != "" {
		copy.Path, _ = clone_string(event.Path)
	}
	if event.Editing != "" {
		copy.Editing, _ = clone_string(event.Editing)
	}
	append(&ctx.events, copy)
}

Poll_Event :: proc(ctx: ^Context) -> (Event, bool) {
	if ctx == nil || len(ctx.events) == 0 {
		return Event{}, false
	}
	event := ctx.events[0]
	for i := 1; i < len(ctx.events); i += 1 {
		ctx.events[i-1] = ctx.events[i]
	}
	pop(&ctx.events)
	return event, true
}

// Destroy_Event releases owned strings returned by Poll_Event. Scalar events
// do not need cleanup, but dropped-file and text-edit events do.
Destroy_Event :: proc(event: ^Event) {
	if event == nil {
		return
	}
	delete(event.Path)
	delete(event.Editing)
	event^ = Event{}
}

Wait_Event :: proc(ctx: ^Context) -> Event {
	for ctx != nil && ctx.running {
		if event, ok := Poll_Event(ctx); ok {
			return event
		}
		Poll_Events(ctx, nil)
		if event, ok := Poll_Event(ctx); ok {
			return event
		}
		time.sleep(time.Millisecond)
	}
	return Event{}
}

Clear_Events :: proc(ctx: ^Context) {
	if ctx == nil {
		return
	}
	for event in ctx.events {
		delete(event.Path)
		delete(event.Editing)
	}
	clear(&ctx.events)
}

clone_string :: proc(value: string) -> (string, bool) {
	if value == "" {
		return "", true
	}
	copy, err := strings.clone(value)
	return copy, err == nil
}

Delta_Time :: proc(ctx: ^Context) -> f32 {
	if ctx == nil {
		return 0
	}
	return ctx.delta
}

Elapsed_Time :: proc(ctx: ^Context) -> f64 {
	if ctx == nil || ctx.backend == nil {
		return 0
	}
	return backend.Elapsed_Time(ctx.backend)
}

Set_Target_FPS :: proc(ctx: ^Context, fps: int) {
	if ctx != nil && ctx.backend != nil && fps >= 0 {
		backend.Set_Target_FPS(ctx.backend, fps)
	}
}

Window_Size :: proc(ctx: ^Context) -> (width, height: int) {
	if ctx == nil || ctx.backend == nil {
		return 0, 0
	}
	return backend.Window_Size(ctx.backend)
}

Set_Window_Title :: proc(ctx: ^Context, title: string) {
	if ctx != nil && ctx.backend != nil {
		backend.Set_Window_Title(ctx.backend, title)
	}
}

Set_Window_Size :: proc(ctx: ^Context, width, height: int) {
	if ctx != nil && ctx.backend != nil && width > 0 && height > 0 {
		backend.Set_Window_Size(ctx.backend, width, height)
	}
}

Toggle_Fullscreen :: proc(ctx: ^Context) {
	if ctx != nil && ctx.backend != nil {
		backend.Toggle_Fullscreen(ctx.backend)
	}
}
