package audio_lab_v05

import "core:fmt"
import "core:os"
import thor2d "thor2d:thor2d"

source: thor2d.Audio_Source
data: thor2d.Sound_Data
elapsed: f32

load :: proc(ctx: ^thor2d.Context) {
	data, _ = thor2d.New_Sound_Data(48000, 2, 2048)
	thor2d.Fill_Sine_Wave(&data, 440, 0.15)
	created, err := thor2d.Create_Audio_Source_From_Data(ctx, data)
	if err == .None {
		source = created
		thor2d.Play_Audio_Source(ctx, source)
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
	thor2d.Clear(ctx, thor2d.RGBA(20, 20, 30, 255))
	thor2d.Draw_Text(ctx, "Thor2D audio lab v0.5 | generated PCM", thor2d.Vec2{32, 32}, 24, thor2d.White)
}

shutdown :: proc(ctx: ^thor2d.Context) {
	thor2d.Destroy_Audio_Source(ctx, source)
	thor2d.Destroy_Sound_Data(&data)
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D Audio Lab v0.5"
	if err := thor2d.Run(config, thor2d.Game{Load = load, Update = update, Draw = draw, Shutdown = shutdown, On_Event = on_event}); err != .None {
		fmt.println(thor2d.Error_String(err))
	}
}
