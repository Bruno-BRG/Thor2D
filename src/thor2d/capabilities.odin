package thor2d

import backend "thor2d:thor2d/internal/raylib"
import audio "thor2d:thor2d/internal/audio"
import video "thor2d:thor2d/internal/video"

// Query_Capability reports whether the active runtime can provide a feature.
// Optional hardware features must be checked before creating a resource; the
// framework never returns a fake handle for an unavailable capability.
Query_Capability :: proc(ctx: ^Context, capability: Capability) -> bool {
	if ctx == nil {
		return capability == .Headless
	}
	switch capability {
	case .Headless:
		return ctx.headless
	case .Archive_Mount:
		return true
	case .Video:
		// Decoding is also valid in headless mode; drawing the current frame
		// still requires a graphics backend and is checked by Draw_Video.
		return video.Available()
	case .Audio_Capture:
		return ctx.audio_backend != nil && audio.Supports_Capture(ctx.audio_backend)
	case .Audio_Effects:
		return ctx.audio_backend != nil && audio.Supports_Effects(ctx.audio_backend)
	case .Audio_Spatial:
		return ctx.audio_backend != nil && audio.Supports_Spatial(ctx.audio_backend)
	case .Audio_Decoder:
		return ctx.audio_backend != nil && audio.Supports_Decoder(ctx.audio_backend)
	case .Audio_Buses:
		return ctx.audio_backend != nil
	case .GPU_Mesh:
		return !ctx.headless && ctx.backend != nil && backend.GPU_Mesh_Supported(ctx.backend)
	case .Fullscreen, .Gamepad, .Touch:
		return !ctx.headless && ctx.backend != nil
	}
	return false
}
