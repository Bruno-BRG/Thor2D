package hello

import "core:fmt"
import thor2d "thor2d:thor2d"

position := thor2d.Vec2{160, 180}

update :: proc(ctx: ^thor2d.Context, delta: f32) {
	speed: f32 = 240
	if thor2d.Key_Down(ctx, .Right) {
		position.X += speed * delta
	}
	if thor2d.Key_Down(ctx, .Left) {
		position.X -= speed * delta
	}
	if thor2d.Key_Down(ctx, .Down) {
		position.Y += speed * delta
	}
	if thor2d.Key_Down(ctx, .Up) {
		position.Y -= speed * delta
	}
	if thor2d.Key_Pressed(ctx, .Escape) {
		thor2d.Quit(ctx)
	}
}

draw :: proc(ctx: ^thor2d.Context) {
	thor2d.Clear(ctx, thor2d.Color{18, 24, 38, 255})
	thor2d.Draw_Text(ctx, "Thor2D + raylib", thor2d.Vec2{32, 28}, 32, thor2d.White)
	thor2d.Draw_Text(ctx, "Use the arrow keys. Press ESC to quit.", thor2d.Vec2{32, 76}, 20, thor2d.Gray)
	thor2d.Draw_Rect(ctx, thor2d.Rect{position.X, position.Y, 96, 96}, thor2d.Blue)
	thor2d.Draw_Rect_Outline(ctx, thor2d.Rect{position.X, position.Y, 96, 96}, 3, thor2d.White)
	thor2d.Draw_Circle(ctx, thor2d.Vec2{position.X + 48, position.Y + 48}, 16, thor2d.Green)
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D Hello"
	config.Width = 960
	config.Height = 540

	err := thor2d.Run(config, thor2d.Game{Update = update, Draw = draw})
	if err != .None {
		fmt.println("Thor2D error:", thor2d.Error_String(err))
	}
}
