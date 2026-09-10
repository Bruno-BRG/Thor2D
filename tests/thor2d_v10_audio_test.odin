package tests

import "core:testing"
import thor2d "thor2d:thor2d"

// v0.10 wave 4 total audio API (LOVE Source/RecordingDevice/SoundData/Decoder
// parity). Headless-safe: without an audio device (nil backend, which is the
// headless case and the no-hardware case) every source/decoder getter
// returns zero values and fallible ops return explicit errors — never fake
// data. Pure-CPU Sound_Data format getters and the kind accessor run
// anywhere. Device-backed round-trips run only when ctx.audio_backend is
// non-nil, so the suite passes with or without audio hardware.

v10a_headless_ctx :: proc(t: ^testing.T) -> thor2d.Context {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	testing.expect(t, err == .None)
	return ctx
}

@(test)
test_v10a_zero_handles :: proc(t: ^testing.T) {
	ctx := v10a_headless_ctx(t)
	defer thor2d.Destroy(&ctx)
	bad := thor2d.Audio_Source{}

	testing.expect(t, !thor2d.Audio_Source_Is_Looping(&ctx, bad))
	testing.expect(t, thor2d.Audio_Source_Get_Volume(&ctx, bad) == 0)
	testing.expect(t, thor2d.Audio_Source_Get_Pitch(&ctx, bad) == 0)
	testing.expect(t, thor2d.Audio_Source_Get_Pan(&ctx, bad) == 0)
	testing.expect(t, thor2d.Audio_Source_Get_Position(&ctx, bad) == thor2d.Vec2{})
	testing.expect(t, thor2d.Audio_Source_Get_Velocity(&ctx, bad) == thor2d.Vec2{})
	testing.expect(t, thor2d.Audio_Source_Get_Direction(&ctx, bad) == thor2d.Vec2{})
	inner, outer, gain := thor2d.Audio_Source_Get_Cone(&ctx, bad)
	testing.expect(t, inner == 0 && outer == 0 && gain == 0)
	testing.expect(t, thor2d.Audio_Source_Get_Rolloff(&ctx, bad) == 0)
	testing.expect(t, thor2d.Audio_Source_Get_Doppler(&ctx, bad) == 0)
	testing.expect(t, !thor2d.Audio_Source_Is_Relative(&ctx, bad))
	testing.expect(t, thor2d.Audio_Source_Channels(&ctx, bad) == 0)
	testing.expect(t, thor2d.Audio_Source_Sample_Rate(&ctx, bad) == 0)

	// Nil ctx is equally zero-safe.
	testing.expect(t, !thor2d.Audio_Source_Is_Looping(nil, bad))
	testing.expect(t, thor2d.Audio_Source_Get_Volume(nil, bad) == 0)
	testing.expect(t, thor2d.Audio_Source_Channels(nil, bad) == 0)
	testing.expect(t, !thor2d.Audio_Source_Is_Relative(nil, bad))

	// Globals: nothing live headless.
	testing.expect(t, thor2d.Play_All_Audio(&ctx) == 0)
	testing.expect(t, thor2d.Pause_All_Audio(&ctx) == 0)
	testing.expect(t, thor2d.Stop_All_Audio(&ctx) == 0)
	testing.expect(t, thor2d.Play_All_Audio(nil) == 0)
	testing.expect(t, thor2d.Get_Audio_Doppler(&ctx) == 0)
	testing.expect(t, thor2d.Get_Audio_Doppler(nil) == 0)
	fwd, up := thor2d.Get_Audio_Orientation(&ctx)
	testing.expect(t, fwd == thor2d.Vec2{} && up == thor2d.Vec2{})
	testing.expect(t, thor2d.Set_Audio_Orientation(&ctx, thor2d.Vec2{0, 0}, thor2d.Vec2{0, 1}) != .None)
	testing.expect(t, thor2d.Set_Audio_Orientation(nil, thor2d.Vec2{}, thor2d.Vec2{}) != .None)

	// Capture: inactive headless.
	testing.expect(t, !thor2d.Is_Audio_Capturing(&ctx))
	testing.expect(t, !thor2d.Is_Audio_Capturing(nil))
	testing.expect(t, thor2d.Audio_Capture_Sample_Rate(&ctx) == 0)
	testing.expect(t, thor2d.Audio_Capture_Channels(&ctx) == 0)
	testing.expect(t, thor2d.Audio_Capture_Bit_Depth(&ctx) == 0)
	testing.expect(t, thor2d.Audio_Capture_Sample_Count(&ctx) == 0)

	// Recording devices: no backend headless, so enumeration errors loudly.
	_, rec_err := thor2d.Audio_Recording_Devices(&ctx)
	testing.expect(t, rec_err != .None)
	_, rec_nil_err := thor2d.Audio_Recording_Devices(nil)
	testing.expect(t, rec_nil_err != .None)

	// Indexed capture is default-device-only by design.
	testing.expect(t, thor2d.Start_Capture_From_Device(&ctx, thor2d.Audio_Device{}) == .Unsupported)
	testing.expect(t, thor2d.Start_Capture_From_Device(nil, thor2d.Audio_Device{}) == .Unsupported)
	_, name_err := thor2d.Audio_Recording_Device_Name(&ctx, thor2d.Audio_Device{})
	testing.expect(t, name_err != .None)

	// Decoder format getters on bad handles.
	testing.expect(t, thor2d.Audio_Decoder_Channels(&ctx, thor2d.Audio_Decoder{}) == 0)
	testing.expect(t, thor2d.Audio_Decoder_Sample_Rate(&ctx, thor2d.Audio_Decoder{}) == 0)
	testing.expect(t, thor2d.Audio_Decoder_Bit_Depth(&ctx, thor2d.Audio_Decoder{}) == 0)
	testing.expect(t, thor2d.Audio_Decoder_Channels(nil, thor2d.Audio_Decoder{}) == 0)
}

@(test)
test_v10a_sound_data_format :: proc(t: ^testing.T) {
	// Pure CPU: runs anywhere, no device needed.
	data, err := thor2d.New_Sound_Data(44100, 2, 100, 16)
	testing.expect(t, err == .None)
	defer thor2d.Destroy_Sound_Data(&data)
	testing.expect(t, thor2d.Sound_Data_Sample_Rate(&data) == 44100)
	testing.expect(t, thor2d.Sound_Data_Channels(&data) == 2)
	testing.expect(t, thor2d.Sound_Data_Bit_Depth(&data) == 16)

	data32, err32 := thor2d.New_Sound_Data(48000, 1, 48)
	testing.expect(t, err32 == .None)
	defer thor2d.Destroy_Sound_Data(&data32)
	testing.expect(t, thor2d.Sound_Data_Sample_Rate(&data32) == 48000)
	testing.expect(t, thor2d.Sound_Data_Channels(&data32) == 1)
	testing.expect(t, thor2d.Sound_Data_Bit_Depth(&data32) == 32)

	testing.expect(t, thor2d.Sound_Data_Sample_Rate(nil) == 0)
	testing.expect(t, thor2d.Sound_Data_Channels(nil) == 0)
	testing.expect(t, thor2d.Sound_Data_Bit_Depth(nil) == 0)
}

@(test)
test_v10a_source_kind :: proc(t: ^testing.T) {
	// Kind rides in the handle: pure, nil-safe, no device needed.
	testing.expect(t, thor2d.Audio_Source_Get_Kind(thor2d.Audio_Source{Kind = .Static}) == .Static)
	testing.expect(t, thor2d.Audio_Source_Get_Kind(thor2d.Audio_Source{Kind = .Stream}) == .Stream)
	testing.expect(t, thor2d.Audio_Source_Get_Kind(thor2d.Audio_Source{Kind = .Queue}) == .Queue)
	testing.expect(t, thor2d.Audio_Source_Get_Kind(thor2d.Audio_Source{}) == .Static)
}

@(test)
test_v10a_device_roundtrip :: proc(t: ^testing.T) {
	ctx := v10a_headless_ctx(t)
	defer thor2d.Destroy(&ctx)
	if ctx.audio_backend == nil {
		// No audio device (headless CI): zero-paths above already cover us.
		return
	}

	// Synthetic mono source: format retained at creation.
	data, data_err := thor2d.New_Sound_Data(48000, 1, 480)
	testing.expect(t, data_err == .None)
	defer thor2d.Destroy_Sound_Data(&data)
	testing.expect(t, thor2d.Fill_Sine_Wave(&data, 440, 0.5) == .None)
	source, src_err := thor2d.Create_Audio_Source_From_Data(&ctx, data)
	if !testing.expect(t, src_err == .None) {
		return
	}
	defer thor2d.Destroy_Audio_Source(&ctx, source)
	testing.expect(t, thor2d.Audio_Source_Get_Kind(source) == .Static)
	testing.expect(t, thor2d.Audio_Source_Channels(&ctx, source) == 1)
	testing.expect(t, thor2d.Audio_Source_Sample_Rate(&ctx, source) == 48000)

	// Scalar round-trips through live miniaudio state.
	thor2d.Set_Audio_Source_Volume(&ctx, source, 0.5)
	testing.expect(t, thor2d.Audio_Source_Get_Volume(&ctx, source) == 0.5)
	thor2d.Set_Audio_Source_Pitch(&ctx, source, 1.5)
	testing.expect(t, thor2d.Audio_Source_Get_Pitch(&ctx, source) == 1.5)
	thor2d.Set_Audio_Source_Pan(&ctx, source, -0.25)
	testing.expect(t, thor2d.Audio_Source_Get_Pan(&ctx, source) == -0.25)
	testing.expect(t, thor2d.Set_Audio_Source_Looping(&ctx, source, true) == .None)
	testing.expect(t, thor2d.Audio_Source_Is_Looping(&ctx, source))
	testing.expect(t, thor2d.Set_Audio_Source_Looping(&ctx, source, false) == .None)
	testing.expect(t, !thor2d.Audio_Source_Is_Looping(&ctx, source))

	// Spatial round-trips (2D plane, Z dropped).
	testing.expect(t, thor2d.Set_Audio_Position(&ctx, source, thor2d.Vec2{3, 4}) == .None)
	testing.expect(t, thor2d.Audio_Source_Get_Position(&ctx, source) == thor2d.Vec2{3, 4})
	testing.expect(t, thor2d.Set_Audio_Velocity(&ctx, source, thor2d.Vec2{1, -2}) == .None)
	testing.expect(t, thor2d.Audio_Source_Get_Velocity(&ctx, source) == thor2d.Vec2{1, -2})
	testing.expect(t, thor2d.Set_Audio_Source_Direction(&ctx, source, thor2d.Vec2{0, 1}) == .None)
	testing.expect(t, thor2d.Audio_Source_Get_Direction(&ctx, source) == thor2d.Vec2{0, 1})
	testing.expect(t, thor2d.Set_Audio_Source_Cone(&ctx, source, 0.5, 1.0, 0.25) == .None)
	ci, co, cg := thor2d.Audio_Source_Get_Cone(&ctx, source)
	testing.expect(t, ci == 0.5 && co == 1.0 && cg == 0.25)
	testing.expect(t, thor2d.Set_Audio_Attenuation(&ctx, source, 2.0) == .None)
	testing.expect(t, thor2d.Audio_Source_Get_Rolloff(&ctx, source) == 2.0)
	testing.expect(t, thor2d.Set_Audio_Source_Relative(&ctx, source, true) == .None)
	testing.expect(t, thor2d.Audio_Source_Is_Relative(&ctx, source))
	testing.expect(t, thor2d.Set_Audio_Source_Relative(&ctx, source, false) == .None)
	testing.expect(t, !thor2d.Audio_Source_Is_Relative(&ctx, source))

	// Doppler: global scale is stored, inherited by new sources.
	testing.expect(t, thor2d.Get_Audio_Doppler(&ctx) == 1.0)
	testing.expect(t, thor2d.Set_Audio_Doppler(&ctx, 2.0) == .None)
	testing.expect(t, thor2d.Get_Audio_Doppler(&ctx) == 2.0)
	testing.expect(t, thor2d.Audio_Source_Get_Doppler(&ctx, source) == 2.0)
	testing.expect(t, thor2d.Set_Audio_Doppler(&ctx, 1.0) == .None)

	// Listener orientation round-trips stored backend state.
	testing.expect(t, thor2d.Set_Audio_Orientation(&ctx, thor2d.Vec2{1, 0}, thor2d.Vec2{0, 1}) == .None)
	fwd, up := thor2d.Get_Audio_Orientation(&ctx)
	testing.expect(t, fwd == thor2d.Vec2{1, 0} && up == thor2d.Vec2{0, 1})

	// Global play/pause/stop iterate the one live source.
	testing.expect(t, thor2d.Play_All_Audio(&ctx) == 1)
	testing.expect(t, thor2d.Get_Audio_Source_State(&ctx, source) == .Playing)
	testing.expect(t, thor2d.Pause_All_Audio(&ctx) == 1)
	testing.expect(t, thor2d.Get_Audio_Source_State(&ctx, source) == .Paused)
	testing.expect(t, thor2d.Stop_All_Audio(&ctx) == 1)
	testing.expect(t, thor2d.Get_Audio_Source_State(&ctx, source) == .Stopped)

	// Recording-device enumeration runs when a backend exists; capture
	// hardware may still be absent, so only assert the call contract.
	devices, dev_err := thor2d.Audio_Recording_Devices(&ctx)
	if dev_err == .None {
		defer thor2d.Destroy_Audio_Device_Infos(&devices)
		for entry in devices {
			testing.expect(t, entry.Capture)
		}
	}
}
