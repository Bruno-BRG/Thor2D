package thor2d

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
