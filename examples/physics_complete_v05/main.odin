package physics_complete_v05

import "core:fmt"
import thor2d "thor2d:thor2d"

main :: proc() {
	config := thor2d.Default_Config()
	config.Headless = true
	world: thor2d.Physics_World
	ctx, err := thor2d.Create(config)
	if err != .None {
		fmt.println(thor2d.Error_String(err))
		return
	}
	world, err = thor2d.Create_Physics_World(&ctx)
	if err == .None {
		fmt.println("physics world ready:", !thor2d.Physics_World_Invalid(world))
	}
	thor2d.Destroy(&ctx)
}
