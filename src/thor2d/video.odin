package thor2d

import backend "thor2d:thor2d/internal/raylib"
import video "thor2d:thor2d/internal/video"

// Video is capability-gated at compile time. Builds without the optional
// FFmpeg adapter keep the same runtime and return Capability_Unavailable.
Load_Video :: proc(ctx: ^Context, path: string) -> (Video_Stream, Error) {
	if ctx == nil || ctx.video_backend == nil {
		return Video_Stream{}, .Backend_Initialization_Failed
	}
	if !video.Available() {
		return Video_Stream{}, .Capability_Unavailable
	}
	handle, ok := video.Load(ctx.video_backend, path)
	if !ok {
		return Video_Stream{}, .Resource_Load_Failed
	}
	return Video_Stream{handle}, .None
}

Play_Video :: proc(ctx: ^Context, stream: Video_Stream) -> Error {
	if ctx == nil || stream.handle == 0 {
		return .Invalid_Handle
	}
	if !video.Play(ctx.video_backend, stream.handle) {
		return .Capability_Unavailable if !video.Available() else .Invalid_Handle
	}
	return .None
}

Pause_Video :: proc(ctx: ^Context, stream: Video_Stream) -> Error {
	if ctx == nil || stream.handle == 0 {
		return .Invalid_Handle
	}
	if !video.Pause(ctx.video_backend, stream.handle) {
		return .Capability_Unavailable if !video.Available() else .Invalid_Handle
	}
	return .None
}

Seek_Video :: proc(ctx: ^Context, stream: Video_Stream, seconds: f64) -> Error {
	if ctx == nil || stream.handle == 0 {
		return .Invalid_Handle
	}
	if !video.Seek(ctx.video_backend, stream.handle, seconds) {
		return .Capability_Unavailable if !video.Available() else .Invalid_Handle
	}
	return .None
}

Set_Video_Loop :: proc(ctx: ^Context, stream: Video_Stream, looping: bool) -> Error {
	if ctx == nil || stream.handle == 0 {
		return .Invalid_Handle
	}
	if !video.Set_Loop(ctx.video_backend, stream.handle, looping) {
		return .Capability_Unavailable if !video.Available() else .Invalid_Handle
	}
	return .None
}

Update_Video :: proc(ctx: ^Context, stream: Video_Stream, delta: f32) -> Error {
	if ctx == nil || stream.handle == 0 {
		return .Invalid_Handle
	}
	if !video.Update(ctx.video_backend, ctx.backend, stream.handle, delta) {
		return .Capability_Unavailable if !video.Available() else .Invalid_Handle
	}
	return .None
}

Draw_Video :: proc(ctx: ^Context, stream: Video_Stream, position: Vec2, scale: Vec2, tint: Color) -> Error {
	if ctx == nil || stream.handle == 0 {
		return .Invalid_Handle
	}
	if !video.Draw(ctx.video_backend, ctx.backend, stream.handle, position.X, position.Y, scale.X, scale.Y, tint.R, tint.G, tint.B, tint.A) {
		return .Capability_Unavailable if !video.Available() else .Invalid_Handle
	}
	return .None
}

Video_Duration :: proc(ctx: ^Context, stream: Video_Stream) -> (f64, Error) {
	if ctx == nil || stream.handle == 0 {
		return 0, .Invalid_Handle
	}
	value, ok := video.Duration(ctx.video_backend, stream.handle)
	if !ok {
		return 0, .Capability_Unavailable if !video.Available() else .Invalid_Handle
	}
	return value, .None
}

Video_Position :: proc(ctx: ^Context, stream: Video_Stream) -> (f64, Error) {
	if ctx == nil || stream.handle == 0 {
		return 0, .Invalid_Handle
	}
	value, ok := video.Position(ctx.video_backend, stream.handle)
	if !ok {
		return 0, .Capability_Unavailable if !video.Available() else .Invalid_Handle
	}
	return value, .None
}

Video_Frame_Info :: proc(ctx: ^Context, stream: Video_Stream) -> (width, height: int, frame_rate: f64, err: Error) {
	if ctx == nil || stream.handle == 0 {
		return 0, 0, 0, .Invalid_Handle
	}
	w, h, rate, found := video.Frame_Info(ctx.video_backend, stream.handle)
	if !found {
		return 0, 0, 0, .Capability_Unavailable if !video.Available() else .Invalid_Handle
	}
	return w, h, rate, .None
}

Unload_Video :: proc(ctx: ^Context, stream: Video_Stream) -> Error {
	if ctx == nil || stream.handle == 0 {
		return .None
	}
	video.Unload(ctx.video_backend, ctx.backend, stream.handle)
	return .None
}

// v0.9 video+audio boundary (known v0.7-v0.8 gap).
//
// The FFmpeg shim (src/thor2d/internal/video/video_shim.c) demuxes VIDEO
// packets only: Thor_Video carries no audio codec/stream fields, nothing
// selects AVMEDIA_TYPE_AUDIO, no swresample resampling is linked, and no
// thor_video_audio_* symbols exist. Audio frames therefore never reach the
// backend, so there is nothing to mix — the honest answers below beat a fake
// Audio_Source. The video decode-only path (Load/Update/Draw) is unaffected
// and keeps working headless-safe; these procs only gate the audio side.

// Video_Has_Audio reports whether decoded audio frames are available for
// stream. Always false until the shim demuxes an audio track (see above).
// Plain bool query: false for nil ctx, missing backend, bad handles, and
// non-FFmpeg builds alike — never an error, headless-safe.
Video_Has_Audio :: proc(ctx: ^Context, stream: Video_Stream) -> bool {
	if ctx == nil || ctx.video_backend == nil || stream.handle == 0 {
		return false
	}
	return video.Has_Audio(ctx.video_backend, stream.handle)
}

// Video_Audio_Source would return an Audio_Source fed by the video's decoded
// audio frames for manual mixing. Without an FFmpeg build it returns
// .Capability_Unavailable; with one it still returns .Unsupported because the
// shim exposes no audio frames to feed the source with. Never a fake source.
Video_Audio_Source :: proc(ctx: ^Context, stream: Video_Stream) -> (Audio_Source, Error) {
	if ctx == nil || ctx.video_backend == nil || stream.handle == 0 {
		return Audio_Source{}, .Invalid_Handle
	}
	if !video.Available() {
		return Audio_Source{}, .Capability_Unavailable
	}
	return Audio_Source{}, .Unsupported
}

// Set_Video_Audio_Volume would scale the auto-mixed video audio track.
// Gated like Video_Audio_Source: .Capability_Unavailable without FFmpeg,
// .Unsupported with it (no audio pipeline exists to apply the volume to).
Set_Video_Audio_Volume :: proc(ctx: ^Context, stream: Video_Stream, volume: f32) -> Error {
	if ctx == nil || ctx.video_backend == nil || stream.handle == 0 {
		return .Invalid_Handle
	}
	if !video.Available() {
		return .Capability_Unavailable
	}
	if volume < 0 {
		return .Invalid_Data
	}
	return .Unsupported
}

// --- v0.10 video completion (LOVE Video parity subset). The audio track
// stays .Unsupported (the shim demuxes video packets only — see above); do
// not attempt FFmpeg C work here.

// Video_Is_Playing reports whether the stream is playing (Play set it and no
// Pause followed). Plain bool query: false for nil contexts, missing
// backends and bad handles — headless-safe, never an error.
Video_Is_Playing :: proc(ctx: ^Context, stream: Video_Stream) -> bool {
	if ctx == nil || ctx.video_backend == nil || stream.handle == 0 {
		return false
	}
	return video.Is_Playing(ctx.video_backend, stream.handle)
}

// Video_Rewind seeks to the start (Seek 0 wrapper; LOVE Video:rewind).
Video_Rewind :: proc(ctx: ^Context, stream: Video_Stream) -> Error {
	return Seek_Video(ctx, stream, 0)
}

// Video_Source_Path returns the path Load stored (borrowed: valid until
// Unload_Video). Empty for nil contexts, missing backends and bad handles —
// including non-FFmpeg builds, where Load never creates an entry.
Video_Source_Path :: proc(ctx: ^Context, stream: Video_Stream) -> string {
	if ctx == nil || ctx.video_backend == nil || stream.handle == 0 {
		return ""
	}
	return video.Source_Path(ctx.video_backend, stream.handle)
}

// Set_Video_Filter sets the frame-texture filter (LOVE Texture:setFilter on
// the video frame). The filter is stored on the entry and applied to the
// live frame texture plus every future one: frames re-upload on each decode,
// which would otherwise reset the GL filter state. There is no getter — the
// backend retains no per-texture filter memory (same reason Set_Texture_Filter
// is setter-only). A stream with no decoded frame yet still stores the
// filter (.None); it applies from the first frame on.
Set_Video_Filter :: proc(ctx: ^Context, stream: Video_Stream, filter: Texture_Filter) -> Error {
	if ctx == nil || ctx.video_backend == nil || stream.handle == 0 {
		return .Invalid_Handle
	}
	if !video.Available() {
		return .Capability_Unavailable
	}
	if !video.Set_Filter(ctx.video_backend, stream.handle, int(filter)) {
		return .Invalid_Handle
	}
	if ctx.backend != nil {
		if texture, ok := video.Frame_Texture(ctx.video_backend, stream.handle); ok && texture != 0 {
			backend.Set_Texture_Filter(ctx.backend, texture, int(filter))
		}
	}
	return .None
}
