package async_assets_v07

import "core:fmt"
import thor2d "thor2d:thor2d"

frames: int

fixed_update :: proc(ctx: ^thor2d.Context, delta: f32) {
	frames += 1
}

update :: proc(ctx: ^thor2d.Context, delta: f32) {
	if frames >= 12 {
		thor2d.Quit(ctx)
	}
}

shutdown :: proc(ctx: ^thor2d.Context) {
	fmt.println("async asset/headless lifecycle frames:", frames)
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Headless = true
	thor2d.Run_Headless(config, thor2d.Game{Fixed_Update = fixed_update, Update = update, Shutdown = shutdown}, 30)
}
