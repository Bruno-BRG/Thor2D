package video_player_v07

import "core:fmt"
import "core:os"
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
	path := "assets/demo.mp4"
	if environment_path, found := os.lookup_env("THOR2D_VIDEO_PATH", context.temp_allocator); found && environment_path != "" {
		path = environment_path
	}
	video, load_err := thor2d.Load_Video(&ctx, path)
	fmt.println("video:", thor2d.Query_Capability(&ctx, .Video), "load:", thor2d.Error_String(load_err), "valid:", !thor2d.Video_Stream_Invalid(video))
	if load_err == .None {
		thor2d.Set_Video_Loop(&ctx, video, true)
		thor2d.Play_Video(&ctx, video)
		for _ in 0..<6 {
			thor2d.Update_Video(&ctx, video, 1.0 / 30.0)
		}
		width, height, rate, info_err := thor2d.Video_Frame_Info(&ctx, video)
		position, position_err := thor2d.Video_Position(&ctx, video)
		fmt.println("frame:", width, "x", height, "fps:", rate, "position:", position, "info:", thor2d.Error_String(info_err), "position_err:", thor2d.Error_String(position_err))
		thor2d.Unload_Video(&ctx, video)
	}
}
