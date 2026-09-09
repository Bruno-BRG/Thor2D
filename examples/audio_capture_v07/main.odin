package audio_capture_v07

import "core:fmt"
import "core:os"
import thor2d "thor2d:thor2d"

elapsed: f32
capturing: bool

load :: proc(ctx: ^thor2d.Context) {
	capabilities := thor2d.Get_Audio_Capabilities(ctx)
	if capabilities.Capture {
		capturing = thor2d.Start_Audio_Capture(ctx) == .None
	}
}

update :: proc(ctx: ^thor2d.Context, delta: f32) {
	elapsed += delta
	if capturing {
		data, err := thor2d.Read_Audio_Capture(ctx, 2048)
		if err == .None {
			thor2d.Destroy_Sound_Data(&data)
		}
	}
	if os.get_env("THOR2D_SMOKE", context.temp_allocator) == "1" && elapsed >= 0.4 {
		thor2d.Quit(ctx)
	}
}

on_event :: proc(ctx: ^thor2d.Context, event: thor2d.Event) {
	if event.Kind == .Quit || (event.Kind == .Key_Pressed && event.Key == .Escape) {
		thor2d.Quit(ctx)
	}
}

draw :: proc(ctx: ^thor2d.Context) {
	thor2d.Clear(ctx, thor2d.RGBA(24, 18, 18, 255))
	thor2d.Draw_Text(ctx, "Thor2D v0.7 | capture capability", thor2d.Vec2{28, 32}, 24, thor2d.White)
	}

shutdown :: proc(ctx: ^thor2d.Context) {
	if capturing {
		thor2d.Stop_Audio_Capture(ctx)
	}
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D Audio Capture v0.7"
	if err := thor2d.Run(config, thor2d.Game{Load = load, Update = update, Draw = draw, Shutdown = shutdown, On_Event = on_event}); err != .None {
		fmt.println(thor2d.Error_String(err))
	}
}
