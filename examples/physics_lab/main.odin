package physics_lab

import thor2d "thor2d:thor2d"

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D Physics Lab"
	thor2d.Run(config, thor2d.Game{})
}
