package video_player_v05

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
	video, load_err := thor2d.Load_Video(&ctx, "assets/demo.mp4")
	fmt.println("video capability:", thor2d.Query_Capability(&ctx, .Video), "load:", thor2d.Error_String(load_err), "valid:", !thor2d.Video_Stream_Invalid(video))
}
