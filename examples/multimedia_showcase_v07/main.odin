package multimedia_showcase_v07

import "core:os"
import thor2d "thor2d:thor2d"

elapsed: f32
sound: thor2d.Audio_Source
sound_data: thor2d.Sound_Data

load :: proc(ctx: ^thor2d.Context) {
	sound_data, _ = thor2d.New_Sound_Data(48000, 2, 2400)
	thor2d.Fill_Sine_Wave(&sound_data, 220, 0.1)
	sound, _ = thor2d.Create_Audio_Source_From_Data(ctx, sound_data)
	if !thor2d.Audio_Source_Invalid(sound) {
		thor2d.Play_Audio_Source(ctx, sound)
	}
}

update :: proc(ctx: ^thor2d.Context, delta: f32) {
	elapsed += delta
	if os.get_env("THOR2D_SMOKE", context.temp_allocator) == "1" && elapsed >= 0.6 {
		thor2d.Quit(ctx)
	}
}

on_event :: proc(ctx: ^thor2d.Context, event: thor2d.Event) {
	if event.Kind == .Quit || (event.Kind == .Key_Pressed && event.Key == .Escape) {
		thor2d.Quit(ctx)
	}
}

draw :: proc(ctx: ^thor2d.Context) {
	thor2d.Clear(ctx, thor2d.RGBA(12, 24, 24, 255))
	thor2d.Draw_Circle(ctx, thor2d.Vec2{640, 360}, 100 + 20*thor2d.Sin(elapsed), thor2d.RGBA(60, 190, 190, 255))
	thor2d.Draw_Text(ctx, "Thor2D v0.7 multimedia showcase", thor2d.Vec2{32, 32}, 28, thor2d.White)
	thor2d.Draw_Text(ctx, "Video is capability-gated; audio uses dedicated miniaudio", thor2d.Vec2{32, 72}, 18, thor2d.Gray)
}

shutdown :: proc(ctx: ^thor2d.Context) {
	thor2d.Destroy_Audio_Source(ctx, sound)
	thor2d.Destroy_Sound_Data(&sound_data)
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D Multimedia Showcase v0.7"
	thor2d.Run(config, thor2d.Game{Load = load, Update = update, Draw = draw, Shutdown = shutdown, On_Event = on_event})
}
