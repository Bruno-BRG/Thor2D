package love_port_v08

// LOVE-port proof for Thor2D v0.8: exercises color/background state,
// arc/ellipse/polygon/points, Print/Printf, window getters, meter,
// filesystem extras and input extras. Imports only thor2d.

import "core:fmt"
import "core:os"
import thor2d "thor2d:thor2d"

elapsed: f64

load :: proc(ctx: ^thor2d.Context) {
	thor2d.Set_Background_Color(ctx, thor2d.RGB(18, 24, 38))
	thor2d.Set_Color(ctx, thor2d.Red)
	thor2d.Set_Blend_Mode(ctx, .Alpha)
	thor2d.Set_Key_Repeat(ctx, true)
	thor2d.Set_Text_Input(ctx, true)
	_ = thor2d.Set_Meter(ctx, 32)
	fs := thor2d.Filesystem_Access(ctx)
	_ = thor2d.Create_Directory(fs, "love_port")
	_ = thor2d.Append_Save(fs, "love_port/log.txt", transmute([]u8)string("love_port v0.8\n"))
	fmt.println("title:", thor2d.Window_Title(ctx))
	fmt.println("meter:", thor2d.Get_Meter(ctx))
	fmt.println("master volume:", thor2d.Get_Master_Volume(ctx))
}

update :: proc(ctx: ^thor2d.Context, delta: f32) {
	elapsed += f64(delta)
	if os.get_env("THOR2D_SMOKE", context.temp_allocator) == "1" && elapsed >= 0.5 {
		thor2d.Quit(ctx)
	}
	if thor2d.Key_Pressed(ctx, .Escape) {
		thor2d.Quit(ctx)
	}
}

draw :: proc(ctx: ^thor2d.Context) {
	thor2d.Clear_Screen(ctx)
	thor2d.Set_Color(ctx, thor2d.Red)
	thor2d.Draw_Arc(ctx, thor2d.Vec2{200, 200}, 80, 0, 3.14159, .Fill)
	thor2d.Draw_Ellipse(ctx, thor2d.Vec2{400, 200}, 90, 50, .Line)
	thor2d.Draw_Polygon(ctx, []thor2d.Vec2{{500, 120}, {580, 120}, {540, 200}}, .Fill, thor2d.Green)
	thor2d.Draw_Points(ctx, []thor2d.Vec2{{100, 400}, {140, 400}, {180, 400}}, thor2d.Blue)
	thor2d.Print(ctx, "love_port v0.8", thor2d.Vec2{32, 28})
	thor2d.Printf(ctx, "arc ellipse polygon points", thor2d.Rect{X = 32, Y = 60, W = 600, H = 24}, .Left, thor2d.Gray)
	w, h := thor2d.Get_Dimensions(ctx)
	_ = w
	_ = h
}

on_event :: proc(ctx: ^thor2d.Context, event: thor2d.Event) {
	if event.Kind == .Quit {
		thor2d.Quit(ctx)
	}
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D Love Port v0.8"
	config.Width = 960
	config.Height = 540
	err := thor2d.Run(config, thor2d.Game{Load = load, Update = update, Draw = draw, On_Event = on_event})
	if err != .None {
		fmt.println("Thor2D error:", thor2d.Error_String(err))
	}
}
