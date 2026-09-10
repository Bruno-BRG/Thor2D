# thor2d.Video

LOVE equivalent: `love.video`. Sources: `video.odin`.

## Description

Optional FFmpeg: `Load/Play/Pause/Seek/Set_Loop/Update/Draw/Duration/Position/Frame_Info/Unload_Video`. Without `-define:THOR2D_FFMPEG=true` returns `.Capability_Unavailable`.

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## See Also

[Graphics](Graphics.md)

## Video audio (v0.9)

LOVE equivalent: video sources with audio (`love.audio.newSource(video)`-style
mixing). Source: `video.odin`.

Known boundary, honest negative: the FFmpeg shim
(`src/thor2d/internal/video/video_shim.c`) demuxes video packets only —
`Thor_Video` has no audio codec/stream fields and no `thor_video_audio_*`
symbols exist — so no audio frames ever reach the backend. `Video_Has_Audio`
therefore returns false, `Video_Audio_Source` returns
`.Capability_Unavailable` without an FFmpeg build and `.Unsupported` with
one, and `Set_Video_Audio_Volume` is gated the same way. The decode-only
video path (`Load/Update/Draw`) is unaffected and stays headless-safe. Wire
audio demux + resampling into the shim before flipping these.

## Video completion (v0.10 wave 5)

LOVE equivalent: `love.video` stream queries. Source: `video.odin`.

- `Video_Is_Playing(ctx, stream)` — whether the stream is playing (plain
  bool query; false for bad handles, headless-safe).
- `Video_Rewind(ctx, stream)` — seek-to-start wrapper around `Seek_Video`.
- `Video_Source_Path(ctx, stream)` — the path `Load_Video` stored (borrowed:
  valid until `Unload_Video`; `""` for bad handles and non-FFmpeg builds).
- `Set_Video_Filter(ctx, stream, filter)` — frame-texture filter (the
  `Set_Texture_Filter` path applied to video frames). Stored on the entry
  and re-applied to every new frame texture, because frames re-upload on
  each decode (which would otherwise reset the GL filter state). Setter-only
  — the backend retains no per-texture filter memory — and a stream with no
  decoded frame yet still stores it for the first frame. Error gating
  mirrors `Set_Video_Audio_Volume`: `.Capability_Unavailable` without
  FFmpeg, `.Invalid_Handle` for bad handles.

The audio track stays `.Unsupported` (shim lacks demux — no FFmpeg C work
was attempted).
