package pong

import "core:fmt"
import thor2d "thor2d:thor2d"

left_y: f32 = 220
right_y: f32 = 220
ball := thor2d.Vec2{480, 260}
velocity := thor2d.Vec2{260, 180}

update :: proc(ctx: ^thor2d.Context, delta: f32) {
	paddle_speed: f32 = 320
	if thor2d.Key_Down(ctx, .W) { left_y -= paddle_speed * delta }
	if thor2d.Key_Down(ctx, .S) { left_y += paddle_speed * delta }
	if thor2d.Key_Down(ctx, .Up) { right_y -= paddle_speed * delta }
	if thor2d.Key_Down(ctx, .Down) { right_y += paddle_speed * delta }
	left_y = thor2d.Clamp(left_y, 24, 456)
	right_y = thor2d.Clamp(right_y, 24, 456)

	ball = thor2d.Vec2_Add(ball, thor2d.Vec2_Scale(velocity, delta))
	if ball.Y < 16 || ball.Y > 524 { velocity.Y = -velocity.Y }
	left_paddle := thor2d.Rect{24, left_y, 18, 84}
	right_paddle := thor2d.Rect{918, right_y, 18, 84}
	ball_rect := thor2d.Rect{ball.X - 10, ball.Y - 10, 20, 20}
	if thor2d.Rects_Overlap(ball_rect, left_paddle) && velocity.X < 0 { velocity.X = -velocity.X }
	if thor2d.Rects_Overlap(ball_rect, right_paddle) && velocity.X > 0 { velocity.X = -velocity.X }
	if ball.X < 0 || ball.X > 960 {
		ball = thor2d.Vec2{480, 270}
		velocity.X = -velocity.X
	}
	if thor2d.Key_Pressed(ctx, .Escape) { thor2d.Quit(ctx) }
}

draw :: proc(ctx: ^thor2d.Context) {
	thor2d.Clear(ctx, thor2d.Color{10, 12, 20, 255})
	thor2d.Draw_Text(ctx, "THOR2D PONG", thor2d.Vec2{32, 24}, 24, thor2d.White)
	thor2d.Draw_Rect(ctx, thor2d.Rect{24, left_y, 18, 84}, thor2d.Green)
	thor2d.Draw_Rect(ctx, thor2d.Rect{918, right_y, 18, 84}, thor2d.Blue)
	thor2d.Draw_Circle(ctx, ball, 10, thor2d.White)
	for y: f32 = 0; y < 540; y += 24 {
		thor2d.Draw_Rect(ctx, thor2d.Rect{478, y, 4, 12}, thor2d.Gray)
	}
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D Pong"
	config.Width = 960
	config.Height = 540
	err := thor2d.Run(config, thor2d.Game{Update = update, Draw = draw})
	if err != .None { fmt.println(thor2d.Error_String(err)) }
}
