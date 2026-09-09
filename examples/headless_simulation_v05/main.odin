package headless_simulation_v05

import "core:fmt"
import thor2d "thor2d:thor2d"

world: thor2d.Physics_World
body: thor2d.Physics_Body
steps: int

load :: proc(ctx: ^thor2d.Context) {
	world, _ = thor2d.Create_Physics_World(ctx)
	definition := thor2d.Default_Physics_Body_Def()
	definition.Position = thor2d.Vec2{0, 0}
	body, _ = thor2d.Create_Physics_Body(ctx, world, definition)
	thor2d.Create_Box_Shape(ctx, body, 1, 1)
}

fixed_update :: proc(ctx: ^thor2d.Context, delta: f32) {
	steps += 1
}

shutdown :: proc(ctx: ^thor2d.Context) {
	position := thor2d.Physics_Body_Position(ctx, body)
	fmt.println("headless simulation:", steps, "steps; body.y=", position.Y)
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Headless = true
	err := thor2d.Run_Headless(config, thor2d.Game{Load = load, Fixed_Update = fixed_update, Shutdown = shutdown}, 30)
	if err != .None {
		fmt.println(thor2d.Error_String(err))
	}
}
