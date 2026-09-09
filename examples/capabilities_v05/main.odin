package capabilities_v05

import "core:fmt"
import thor2d "thor2d:thor2d"

main :: proc() {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	if err != .None {
		fmt.println(thor2d.Error_String(err))
		return
	}
	defer thor2d.Destroy(&ctx)
	for capability in thor2d.Capability {
		fmt.println(capability, ":", thor2d.Query_Capability(&ctx, capability))
	}
}
