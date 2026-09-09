package audio_lab_v07

import "core:fmt"
import "core:os"
import thor2d "thor2d:thor2d"

source: thor2d.Audio_Source
data: thor2d.Sound_Data
bus: thor2d.Audio_Bus
effect: thor2d.Audio_Effect
elapsed: f32

load :: proc(ctx: ^thor2d.Context) {
	data, _ = thor2d.New_Sound_Data(48000, 2, 4800)
	thor2d.Fill_Sine_Wave(&data, 440, 0.12)
	created, err := thor2d.Create_Audio_Source_From_Data(ctx, data)
	if err == .None {
		source = created
		thor2d.Set_Audio_Source_Looping(ctx, source, true)
		thor2d.Set_Audio_Source_Volume(ctx, source, 0.25)
		thor2d.Play_Audio_Source(ctx, source)
	}
	bus, _ = thor2d.Create_Audio_Bus(ctx, "music")
	if !thor2d.Audio_Bus_Invalid(bus) {
		thor2d.Set_Audio_Bus_Volume(ctx, bus, 0.5)
		thor2d.Set_Audio_Source_Bus(ctx, source, bus)
	}
	created_effect, effect_err := thor2d.Create_Audio_Effect(ctx, int(thor2d.Audio_Effect_Kind.Low_Pass))
	if effect_err == .None {
		effect = created_effect
		thor2d.Attach_Audio_Effect(ctx, source, effect)
	}
}

update :: proc(ctx: ^thor2d.Context, delta: f32) {
	elapsed += delta
	if thor2d.Audio_Source_Invalid(source) {
		return
	}
	thor2d.Set_Audio_Source_Pan(ctx, source, thor2d.Sin(elapsed*0.5))
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
	thor2d.Clear(ctx, thor2d.RGBA(18, 20, 32, 255))
	thor2d.Draw_Text(ctx, "Thor2D v0.7 | miniaudio source / bus / effect", thor2d.Vec2{28, 32}, 24, thor2d.White)
	thor2d.Draw_Text(ctx, "Dedicated playback is active when the device is available", thor2d.Vec2{28, 72}, 18, thor2d.Gray)
}

shutdown :: proc(ctx: ^thor2d.Context) {
	thor2d.Detach_Audio_Effect(ctx, source, effect)
	thor2d.Destroy_Audio_Effect(ctx, effect)
	thor2d.Destroy_Audio_Bus(ctx, bus)
	thor2d.Destroy_Audio_Source(ctx, source)
	thor2d.Destroy_Sound_Data(&data)
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D Audio Lab v0.7"
	if err := thor2d.Run(config, thor2d.Game{Load = load, Update = update, Draw = draw, Shutdown = shutdown, On_Event = on_event}); err != .None {
		fmt.println(thor2d.Error_String(err))
	}
}
