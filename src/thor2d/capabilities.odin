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
	case .Instancing:
		// v0.9: GPU instancing issues all copies from resident mesh VBOs
		// (backend.Draw_Mesh_Instanced); availability equals GPU mesh
		// support. Meshes without GPU buffers still draw via the CPU
		// fallback, which reports .Unsupported per call.
		return !ctx.headless && ctx.backend != nil && backend.GPU_Mesh_Supported(ctx.backend)
	case .Stencil, .Color_Mask:
		// v0.9 spikes found no backend path: rlgl exposes no color-mask
		// API and no stencil-test/clear API (see
		// backend.Color_Mask_Supported / backend.Stencil_Supported), so
		// these stay false and the public setters return .Unsupported
		// instead of fake state.
		return backend.Color_Mask_Supported(ctx.backend) || backend.Stencil_Supported(ctx.backend)
	case .System_Cursor, .Gamepad_Mapping:
		return !ctx.headless && ctx.backend != nil
	}
	return false
}
