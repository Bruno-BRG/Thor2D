package guide_game_v11

import "core:fmt"
import thor2d "thor2d:thor2d"

player := thor2d.Vec2{320, 240}
coin := thor2d.Vec2{520, 240}
score: int

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
	thor2d.Clear(ctx, thor2d.Color{13, 18, 31, 255})
	thor2d.Draw_Text(ctx, "THOR2D COIN RUN", thor2d.Vec2{24, 22}, 28, thor2d.White)
	thor2d.Draw_Text(ctx, "WASD / arrows to move   |   Esc to quit", thor2d.Vec2{24, 52}, 16, thor2d.Gray)
	thor2d.Draw_Text(ctx, fmt.aprintf("Coins: %d", score), thor2d.Vec2{520, 28}, 20, thor2d.Color{255, 210, 60, 255})
	thor2d.Draw_Rect(ctx, thor2d.Rect{16, 72, 608, 400}, thor2d.Color{25, 35, 55, 255})
	thor2d.Draw_Circle(ctx, coin, 14, thor2d.Color{255, 210, 60, 255})
	thor2d.Draw_Circle(ctx, player, 20, thor2d.Color{60, 220, 220, 255})
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D Guide Game"
	config.Width = 640
	config.Height = 480
	err := thor2d.Run(config, thor2d.Game{Update = update, Draw = draw})
	if err != .None { fmt.println(thor2d.Error_String(err)) }
}
