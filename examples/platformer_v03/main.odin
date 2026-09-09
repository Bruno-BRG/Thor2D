package platformer_v03

import "core:fmt"
import "core:os"
import thor2d "thor2d:thor2d"

world: thor2d.Physics_World
player: thor2d.Physics_Body
ground: thor2d.Physics_Body
elapsed: f32

load :: proc(ctx: ^thor2d.Context) {
	world, _ = thor2d.Create_Physics_World(ctx)
	ground_def := thor2d.Default_Physics_Body_Def()
	ground_def.Type = .Static
	ground_def.Position = thor2d.Vec2{480, 440}
	ground, _ = thor2d.Create_Physics_Body(ctx, world, ground_def)
	thor2d.Create_Box_Shape(ctx, ground, 720, 32)

	player_def := thor2d.Default_Physics_Body_Def()
	player_def.Position = thor2d.Vec2{480, 160}
	player_def.Enable_Sleep = false
	player, _ = thor2d.Create_Physics_Body(ctx, world, player_def)
	thor2d.Create_Box_Shape(ctx, player, 32, 32)
}

on_event :: proc(ctx: ^thor2d.Context, event: thor2d.Event) {
	#partial switch event.Kind {
	case .Quit:
		thor2d.Quit(ctx)
	case .Key_Pressed:
		if event.Key == .Escape {
			thor2d.Quit(ctx)
		}
	}
}

fixed_update :: proc(ctx: ^thor2d.Context, delta: f32) {
	if thor2d.Key_Down(ctx, .Left) {
		thor2d.Physics_Body_Set_Linear_Velocity(ctx, player, thor2d.Vec2{-120, 0})
	} else if thor2d.Key_Down(ctx, .Right) {
		thor2d.Physics_Body_Set_Linear_Velocity(ctx, player, thor2d.Vec2{120, 0})
	}
}

update :: proc(ctx: ^thor2d.Context, delta: f32) {
	elapsed += delta
	if os.get_env("THOR2D_SMOKE", context.temp_allocator) == "1" && elapsed >= 0.5 {
		thor2d.Quit(ctx)
	}
}

draw :: proc(ctx: ^thor2d.Context) {
	thor2d.Clear(ctx, thor2d.RGBA(18, 24, 38, 255))
	thor2d.Draw_Rect(ctx, thor2d.Rect{120, 424, 720, 32}, thor2d.RGBA(80, 150, 90, 255))
	position := thor2d.Physics_Body_Position(ctx, player)
	thor2d.Draw_Rect(ctx, thor2d.Rect{position.X - 16, position.Y - 16, 32, 32}, thor2d.RGBA(240, 190, 60, 255))
	thor2d.Draw_Text(ctx, "Thor2D platformer v0.3 | arrows move | ESC quits", thor2d.Vec2{24, 24}, 20, thor2d.White)
}

shutdown :: proc(ctx: ^thor2d.Context) {
	thor2d.Destroy_All_Physics(ctx)
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D Platformer v0.3"
	config.Width = 960
	config.Height = 540
	if err := thor2d.Run(config, thor2d.Game{Load = load, Update = update, Draw = draw, Shutdown = shutdown, On_Event = on_event, Fixed_Update = fixed_update}); err != .None {
		fmt.println(thor2d.Error_String(err))
	}
}
