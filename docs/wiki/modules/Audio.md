# thor2d.Audio

LOVE equivalent: `love.audio`. Sources: `audio.odin`, `love_gaps.odin`.

## Description

Static/stream/queue sources, buses, effects, spatial, decoders, capture. New v0.8 getters: `Get_Master_Volume`, `Get_Audio_Position/Velocity`, `Get_Audio_Distance_Model`, `Is_Audio_Effects_Supported`.

## Total audio API (v0.10 wave 4)

LOVE equivalent: `Source:get*/is*`, `love.audio.play/pause/stop`,
`setOrientation/getOrientation`, `getRecordingDevices`,
`RecordingDevice:get*`. Source: `audio.odin`.

Source getters (headless/nil backend or bad handle → zero values, never fake;
live values come from miniaudio `ma.sound_get_*`, format from the retained
decode-time state): `Audio_Source_Is_Looping`, `Audio_Source_Get_Volume/
Get_Pitch/Get_Pan`, `Audio_Source_Get_Position/Get_Velocity/Get_Direction`
(2D projection, Z dropped), `Audio_Source_Get_Cone` (inner, outer, gain),
`Audio_Source_Get_Rolloff`, `Audio_Source_Get_Doppler` (per-source factor),
`Audio_Source_Is_Relative`, `Audio_Source_Channels`, `Audio_Source_Sample_Rate`,
`Audio_Source_Get_Kind` (pure, rides in the handle — LOVE `getType`).

Globals: `Play_All_Audio` / `Pause_All_Audio` / `Stop_All_Audio` iterate live
sources (LOVE `love.audio.play/pause/stop` with no arguments) and return the
count acted on (0 headless). `Get_Audio_Doppler` mirrors
`love.audio.getDopplerScale`: the stored global (default 1) applied to live
sources and inherited by new ones.

Listener orientation: `Set_Audio_Orientation(ctx, forward, up)` /
`Get_Audio_Orientation(ctx)` (LOVE `setOrientation/getOrientation` projected
onto 2D; Z=0). Stored backend-side alongside the v0.8 listener
position/velocity. Extends `Set_Audio_Listener` (no up vector there).

Recording: `Audio_Recording_Devices` (capture-capable subset of
`Enumerate_Audio_Devices`; free with `Destroy_Audio_Device_Infos`),
`Audio_Recording_Device_Name` (`getName`), `Is_Audio_Capturing`
(`isRecording`), `Audio_Capture_Sample_Rate/Channels/Bit_Depth/Sample_Count`
(`getSampleRate/getChannelCount/getBitDepth/getSampleCount`; the ring is f32
PCM so live bit depth is always 32, 0 when inactive).
`Start_Capture_From_Device` returns `.Unsupported` by design: the backend
always opens the default capture device, so indexed selection is a
documented default-device-only boundary — use `Start_Audio_Capture`.

## Functions

See [Api_Reference](../Api_Reference.md) for the full procedure index, and [Porting_From_LOVE](../guides/Porting_From_LOVE.md) for the LOVE mapping table.

## See Also

[Sound](Sound.md), [System](System.md)

## Effect kinds (v0.9)

LOVE equivalent: `love.audio.newEffect` types (`chorus`, `compressor`,
`distortion`, `echo`, `equalizer`, `flanger`, `reverb`, `ringmodulator`).
Source: `audio.odin`.

`Is_LOVE_Audio_Effect_Supported` maps the LOVE names to the engine: `echo`
(Delay node) and `reverb` (feedback-delay approximation) are wired through
`Create_Audio_Effect`; `chorus`, `compressor`, `distortion`, `equalizer`,
`flanger` and `ringmodulator` report false because miniaudio exposes no
matching nodes (only delay and lpf/hpf/bpf primitives — verified by searching
`vendor/miniaudio` for chorus/distortion/compressor/flanger/ringmod node
types). No `Audio_Effect_Kind` variants were added for the unsupported kinds:
a variant that always fails would be a fake handle. Single-band filtering
stays available via `.Low_Pass` / `.High_Pass` / `.Band_Pass`.
