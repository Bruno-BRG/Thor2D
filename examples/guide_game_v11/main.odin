package guide_game_v11

import "core:fmt"
import thor2d "thor2d:thor2d"

player := thor2d.Vec2{320, 240}
coin := thor2d.Vec2{520, 240}
score: int
ui_font: thor2d.Font

load :: proc(ctx: ^thor2d.Context) {
	loaded_font, err := thor2d.Load_Font(ctx, "assets/AdwaitaSans-Regular.ttf")
	ui_font = loaded_font
	if err != .None { fmt.println("font load:", thor2d.Error_String(err)) }
}

update :: proc(ctx: ^thor2d.Context, delta: f32) {
	speed: f32 = 220
	if thor2d.Key_Down(ctx, .A) || thor2d.Key_Down(ctx, .Left) { player.X -= speed * delta }
	if thor2d.Key_Down(ctx, .D) || thor2d.Key_Down(ctx, .Right) { player.X += speed * delta }
	if thor2d.Key_Down(ctx, .W) || thor2d.Key_Down(ctx, .Up) { player.Y -= speed * delta }
	if thor2d.Key_Down(ctx, .S) || thor2d.Key_Down(ctx, .Down) { player.Y += speed * delta }
	player.X = thor2d.Clamp(player.X, 24, 616)
	player.Y = thor2d.Clamp(player.Y, 96, 448)
	difference := thor2d.Vec2_Sub(player, coin)
	if thor2d.Vec2_Length_Squared(difference) < 28 * 28 {
		score += 1
		coin = thor2d.Vec2{f32(80 + (score * 97) % 520), f32(110 + (score * 61) % 320)}
	}
	if thor2d.Key_Pressed(ctx, .Escape) { thor2d.Quit(ctx) }
}

draw :: proc(ctx: ^thor2d.Context) {
	background := thor2d.RGBA(10, 14, 27, 255)
	panel := thor2d.RGBA(20, 28, 48, 255)
	border := thor2d.RGBA(48, 67, 99, 255)
	ink := thor2d.RGBA(234, 241, 255, 255)
	muted := thor2d.RGBA(145, 162, 190, 255)
	gold := thor2d.RGBA(255, 196, 75, 255)
	cyan := thor2d.RGBA(72, 220, 225, 255)
	thor2d.Clear(ctx, background)
	// Subtle layered backdrop gives the arena depth without requiring textures.
	for x: f32 = 40; x < 640; x += 80 {
		for y: f32 = 100; y < 480; y += 80 {
			thor2d.Draw_Circle(ctx, thor2d.Vec2{x, y}, 1.5, thor2d.RGBA(55, 78, 112, 150))
		}
	}
	thor2d.Draw_Rect(ctx, thor2d.Rect{16, 14, 608, 52}, panel)
	thor2d.Draw_Rect(ctx, thor2d.Rect{16, 14, 608, 2}, cyan)
	thor2d.Draw_Rect(ctx, thor2d.Rect{16, 72, 608, 400}, panel)
	thor2d.Draw_Rect(ctx, thor2d.Rect{16, 72, 608, 2}, border)
	thor2d.Draw_Rect(ctx, thor2d.Rect{16, 470, 608, 2}, border)

	if !thor2d.Font_Invalid(ui_font) {
		thor2d.Draw_Text_Font(ctx, ui_font, "COIN RUN", thor2d.Vec2{32, 23}, 26, 0, ink)
		thor2d.Draw_Text_Font(ctx, ui_font, "WASD / ARROWS", thor2d.Vec2{32, 49}, 12, 0, muted)
		thor2d.Draw_Text_Font(ctx, ui_font, fmt.aprintf("%02d  COINS", score), thor2d.Vec2{496, 28}, 18, 0, gold)
	} else {
		thor2d.Draw_Text(ctx, "COIN RUN", thor2d.Vec2{32, 23}, 26, ink)
	}
	// Soft shadows are separate shapes so the example stays backend-agnostic.
	thor2d.Draw_Circle(ctx, thor2d.Vec2{coin.X + 3, coin.Y + 5}, 16, thor2d.RGBA(0, 0, 0, 90))
	thor2d.Draw_Circle(ctx, coin, 14, gold)
	thor2d.Draw_Circle(ctx, coin, 8, thor2d.RGBA(255, 226, 125, 255))
	thor2d.Draw_Circle(ctx, thor2d.Vec2{player.X + 4, player.Y + 6}, 21, thor2d.RGBA(0, 0, 0, 100))
	thor2d.Draw_Circle(ctx, player, 20, cyan)
	thor2d.Draw_Circle(ctx, thor2d.Vec2{player.X - 6, player.Y - 7}, 6, thor2d.RGBA(190, 255, 255, 220))
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D Guide Game"
	config.Width = 640
	config.Height = 480
	err := thor2d.Run(config, thor2d.Game{Load = load, Update = update, Draw = draw})
	if err != .None { fmt.println(thor2d.Error_String(err)) }
}
