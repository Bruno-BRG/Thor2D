package thor2d

import "core:math"
import "core:strings"
import audio "thor2d:thor2d/internal/audio"

New_Sound_Data :: proc(sample_rate, channels, frames: int, bit_depth := 32) -> (Sound_Data, Error) {
	if sample_rate <= 0 || channels <= 0 || frames <= 0 || (bit_depth != 8 && bit_depth != 16 && bit_depth != 32) {
		return Sound_Data{}, .Invalid_Data
	}
	return Sound_Data{
		Samples = make([dynamic]f32, frames*channels),
		Sample_Rate = sample_rate,
		Channels = channels,
		Bit_Depth = bit_depth,
	}, .None
}

Destroy_Sound_Data :: proc(data: ^Sound_Data) {
	if data != nil {
		delete(data.Samples)
		data^ = Sound_Data{}
	}
}

Sound_Data_Sample_Count :: proc(data: ^Sound_Data) -> int {
	if data == nil {
		return 0
	}
	return len(data.Samples)
}

Clone_Sound_Data :: proc(data: ^Sound_Data) -> (Sound_Data, Error) {
	if data == nil || data.Sample_Rate <= 0 || data.Channels <= 0 || len(data.Samples) == 0 || len(data.Samples)%data.Channels != 0 {
		return Sound_Data{}, .Invalid_Data
	}
	clone := Sound_Data{
		Samples = make([dynamic]f32, len(data.Samples)),
		Sample_Rate = data.Sample_Rate,
		Channels = data.Channels,
		Bit_Depth = data.Bit_Depth,
	}
	copy(clone.Samples[:], data.Samples[:])
	return clone, .None
}

Sound_Data_Frame_Count :: proc(data: ^Sound_Data) -> int {
	if data == nil || data.Channels <= 0 {
		return 0
	}
	return len(data.Samples) / data.Channels
}

Sound_Data_Duration :: proc(data: ^Sound_Data) -> f32 {
	if data == nil || data.Sample_Rate <= 0 {
		return 0
	}
	return f32(Sound_Data_Frame_Count(data)) / f32(data.Sample_Rate)
}

// Convert_Sound_Data performs deterministic linear resampling and channel
// mapping. It keeps the public representation float PCM, while accepting the
// same format-independent contract used by the decoder and capture APIs.
Convert_Sound_Data :: proc(data: ^Sound_Data, sample_rate, channels: int) -> (Sound_Data, Error) {
	if data == nil || data.Sample_Rate <= 0 || data.Channels <= 0 || len(data.Samples) == 0 ||
		len(data.Samples)%data.Channels != 0 || sample_rate <= 0 || channels <= 0 {
		return Sound_Data{}, .Invalid_Data
	}
	frames := Sound_Data_Frame_Count(data)
	out_frames := max(1, int(math.ceil(f64(frames)*f64(sample_rate)/f64(data.Sample_Rate))))
	result, err := New_Sound_Data(sample_rate, channels, out_frames, data.Bit_Depth)
	if err != .None {
		return Sound_Data{}, err
	}
	for frame := 0; frame < out_frames; frame += 1 {
		source_position := f64(frame) * f64(data.Sample_Rate) / f64(sample_rate)
		left := min(frames-1, max(0, int(math.floor(source_position))))
		right := min(frames-1, left+1)
		fraction := f32(source_position - f64(left))
		for channel := 0; channel < channels; channel += 1 {
			value_left: f32
			value_right: f32
			if data.Channels == 1 {
				value_left = data.Samples[left]
				value_right = data.Samples[right]
			} else if channels == 1 {
				for source_channel := 0; source_channel < data.Channels; source_channel += 1 {
					value_left += data.Samples[left*data.Channels+source_channel]
					value_right += data.Samples[right*data.Channels+source_channel]
				}
				value_left /= f32(data.Channels)
				value_right /= f32(data.Channels)
			} else {
				source_channel := min(data.Channels-1, channel)
				value_left = data.Samples[left*data.Channels+source_channel]
				value_right = data.Samples[right*data.Channels+source_channel]
			}
			result.Samples[frame*channels+channel] = Lerp(value_left, value_right, fraction)
		}
	}
	return result, .None
}

Set_Sound_Data_Sample :: proc(data: ^Sound_Data, index: int, value: f32) -> Error {
	if data == nil || index < 0 || index >= len(data.Samples) {
		return .Invalid_Data
	}
	data.Samples[index] = value
	return .None
}

Get_Sound_Data_Sample :: proc(data: ^Sound_Data, index: int) -> (f32, Error) {
	if data == nil || index < 0 || index >= len(data.Samples) {
		return 0, .Invalid_Data
	}
	return data.Samples[index], .None
}

Fill_Sine_Wave :: proc(data: ^Sound_Data, frequency, amplitude: f32) -> Error {
	if data == nil || data.Sample_Rate <= 0 || data.Channels <= 0 {
		return .Invalid_Data
	}
	frames := len(data.Samples) / data.Channels
	for frame := 0; frame < frames; frame += 1 {
		value := amplitude * f32(math.sin(2 * math.PI * f64(frequency) * f64(frame) / f64(data.Sample_Rate)))
		for channel := 0; channel < data.Channels; channel += 1 {
			data.Samples[frame*data.Channels+channel] = value
		}
	}
	return .None
}

Sound_Data_From_Buffer :: proc(ctx: ^Context, buffer: ^Byte_Buffer) -> (Sound_Data, Error) {
	if buffer == nil || len(buffer.Bytes) == 0 {
		return Sound_Data{}, .Invalid_Data
	}
	return Sound_Data_From_Bytes(ctx, buffer.Bytes[:])
}

Sound_Data_From_Bytes :: proc(ctx: ^Context, bytes: []byte) -> (Sound_Data, Error) {
	if ctx == nil || ctx.audio_backend == nil || len(bytes) == 0 {
		return Sound_Data{}, .Backend_Initialization_Failed
	}
	handle, ok := audio.Create_Decoder(ctx.audio_backend, bytes)
	if !ok {
		return Sound_Data{}, .Invalid_Data
	}
	defer audio.Destroy_Decoder(ctx.audio_backend, handle)
	channels: int
	sample_rate: int
	samples: [dynamic]f32
	for {
		chunk, chunk_channels, chunk_rate, frames, chunk_ok := audio.Read_Decoder(ctx.audio_backend, handle, 4096)
		if !chunk_ok {
			delete(samples)
			return Sound_Data{}, .Invalid_Data
		}
		if channels == 0 {
			channels = chunk_channels
			sample_rate = chunk_rate
		}
		if frames > 0 {
			for sample in chunk {
				append(&samples, sample)
			}
		}
		delete(chunk)
		if frames == 0 {
			break
		}
	}
	if channels <= 0 || sample_rate <= 0 || len(samples) == 0 {
		delete(samples)
		return Sound_Data{}, .Invalid_Data
	}
	return Sound_Data{Samples = samples, Sample_Rate = sample_rate, Channels = channels, Bit_Depth = 32}, .None
}

Load_Sound_Data :: proc(ctx: ^Context, path: string) -> (Sound_Data, Error) {
	if ctx == nil {
		return Sound_Data{}, .Backend_Initialization_Failed
	}
	file, err := Read_Path(&ctx.filesystem, path)
	if err != .None {
		return Sound_Data{}, err
	}
	defer Destroy_File_Data(&file)
	return Sound_Data_From_Bytes(ctx, file.Bytes[:])
}

Load_Sound :: proc(ctx: ^Context, path: string) -> (Sound, Error) {
	if ctx == nil || ctx.audio_backend == nil {
		return Sound{}, .Backend_Initialization_Failed
	}
	file, file_err := Read_Path(&ctx.filesystem, path)
	if file_err != .None {
		return Sound{}, file_err
	}
	defer Destroy_File_Data(&file)
	handle, ok := audio.Load_Static(ctx.audio_backend, path, file.Bytes[:])
	if !ok {
		return Sound{}, .Resource_Load_Failed
	}
	return Sound{handle}, .None
}

Unload_Sound :: proc(ctx: ^Context, sound: Sound) {
	if ctx != nil && ctx.audio_backend != nil && sound.handle != 0 {
		audio.Destroy_Source(ctx.audio_backend, sound.handle, 0)
	}
}

Play_Sound :: proc(ctx: ^Context, sound: Sound) {
	if ctx != nil && ctx.audio_backend != nil && sound.handle != 0 {
		audio.Play(ctx.audio_backend, sound.handle, 0)
	}
}

Stop_Sound :: proc(ctx: ^Context, sound: Sound) {
	if ctx != nil && ctx.audio_backend != nil && sound.handle != 0 {
		audio.Stop(ctx.audio_backend, sound.handle, 0)
	}
}

Set_Sound_Volume :: proc(ctx: ^Context, sound: Sound, volume: f32) {
	if ctx != nil && ctx.audio_backend != nil && sound.handle != 0 {
		audio.Set_Volume(ctx.audio_backend, sound.handle, 0, volume)
	}
}

Load_Music :: proc(ctx: ^Context, path: string) -> (Music, Error) {
	if ctx == nil || ctx.audio_backend == nil {
		return Music{}, .Backend_Initialization_Failed
	}
	file, file_err := Read_Path(&ctx.filesystem, path)
	if file_err != .None {
		return Music{}, file_err
	}
	defer Destroy_File_Data(&file)
	handle, ok := audio.Load_Stream(ctx.audio_backend, path, file.Bytes[:])
	if !ok {
		return Music{}, .Resource_Load_Failed
	}
	return Music{handle}, .None
}

Unload_Music :: proc(ctx: ^Context, music: Music) {
	if ctx != nil && ctx.audio_backend != nil && music.handle != 0 {
		audio.Destroy_Source(ctx.audio_backend, music.handle, 1)
	}
}

Play_Music :: proc(ctx: ^Context, music: Music) {
	if ctx != nil && ctx.audio_backend != nil && music.handle != 0 {
		audio.Play(ctx.audio_backend, music.handle, 1)
	}
}

Update_Music :: proc(ctx: ^Context, music: Music) {
	if ctx != nil && ctx.audio_backend != nil && music.handle != 0 {
		audio.Update(ctx.audio_backend)
	}
}

Set_Master_Volume :: proc(ctx: ^Context, volume: f32) {
	if ctx != nil && ctx.audio_backend != nil {
		audio.Set_Master(ctx.audio_backend, volume)
	}
}

Load_Audio_Source :: proc(ctx: ^Context, path: string, kind: Audio_Source_Kind) -> (Audio_Source, Error) {
	if ctx == nil || ctx.audio_backend == nil {
		return Audio_Source{}, .Backend_Initialization_Failed
	}
	if kind == .Static {
		sound, err := Load_Sound(ctx, path)
		if err != .None {
			return Audio_Source{}, err
		}
		return Audio_Source{handle = sound.handle, Kind = kind}, .None
	}
	if kind == .Stream {
		music, err := Load_Music(ctx, path)
		if err != .None {
			return Audio_Source{}, err
		}
		return Audio_Source{handle = music.handle, Kind = kind}, .None
	}
	return Audio_Source{}, .Unsupported
}

Create_Queueable_Source :: proc(ctx: ^Context) -> (Audio_Source, Error) {
	if ctx == nil || ctx.audio_backend == nil {
		return Audio_Source{}, .Backend_Initialization_Failed
	}
	handle, ok := audio.Create_Queue(ctx.audio_backend, 48000, 2)
	if !ok {
		return Audio_Source{}, .Capability_Unavailable
	}
	return Audio_Source{handle = handle, Kind = .Queue}, .None
}

Create_Audio_Source_From_Data :: proc(ctx: ^Context, data: Sound_Data) -> (Audio_Source, Error) {
	if data.Sample_Rate <= 0 || data.Channels <= 0 || len(data.Samples) == 0 {
		return Audio_Source{}, .Invalid_Data
	}
	if ctx == nil || ctx.audio_backend == nil {
		return Audio_Source{}, .Backend_Initialization_Failed
	}
	bit_depth := data.Bit_Depth
	if bit_depth <= 0 {
		bit_depth = 32
	}
	handle, ok := audio.Create_From_Data(ctx.audio_backend, data.Samples[:], data.Sample_Rate, data.Channels)
	if !ok {
		return Audio_Source{}, .Capability_Unavailable
	}
	return Audio_Source{handle = handle, Kind = .Static}, .None
}

Destroy_Audio_Source :: proc(ctx: ^Context, source: Audio_Source) {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 {
		return
	}
	audio.Destroy_Source(ctx.audio_backend, source.handle, int(source.Kind))
}

Play_Audio_Source :: proc(ctx: ^Context, source: Audio_Source) {
	if ctx != nil && ctx.audio_backend != nil && source.handle != 0 {
		audio.Play(ctx.audio_backend, source.handle, int(source.Kind))
	}
}

Pause_Audio_Source :: proc(ctx: ^Context, source: Audio_Source) {
	if ctx != nil && ctx.audio_backend != nil && source.handle != 0 {
		audio.Pause(ctx.audio_backend, source.handle, int(source.Kind))
	}
}

Resume_Audio_Source :: proc(ctx: ^Context, source: Audio_Source) {
	if ctx != nil && ctx.audio_backend != nil && source.handle != 0 {
		audio.Resume(ctx.audio_backend, source.handle, int(source.Kind))
	}
}

Stop_Audio_Source :: proc(ctx: ^Context, source: Audio_Source) {
	if ctx != nil && ctx.audio_backend != nil && source.handle != 0 {
		audio.Stop(ctx.audio_backend, source.handle, int(source.Kind))
	}
}

Rewind_Audio_Source :: proc(ctx: ^Context, source: Audio_Source) -> Error {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 {
		return .Invalid_Handle
	}
	if !audio.Rewind(ctx.audio_backend, source.handle, int(source.Kind)) {
		return .Invalid_Handle
	}
	return .None
}

Clone_Audio_Source :: proc(ctx: ^Context, source: Audio_Source) -> (Audio_Source, Error) {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 {
		return Audio_Source{}, .Invalid_Handle
	}
	handle, ok := audio.Clone_Source(ctx.audio_backend, source.handle, int(source.Kind))
	if !ok {
		return Audio_Source{}, .Unsupported
	}
	return Audio_Source{handle = handle, Kind = source.Kind}, .None
}

Get_Audio_Source_State :: proc(ctx: ^Context, source: Audio_Source) -> Audio_Source_State {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 {
		return .Stopped
	}
	return Audio_Source_State(audio.State(ctx.audio_backend, source.handle, int(source.Kind)))
}

Set_Audio_Source_Volume :: proc(ctx: ^Context, source: Audio_Source, volume: f32) {
	if ctx != nil && ctx.audio_backend != nil && source.handle != 0 {
		audio.Set_Volume(ctx.audio_backend, source.handle, int(source.Kind), volume)
	}
}

Set_Audio_Source_Pitch :: proc(ctx: ^Context, source: Audio_Source, pitch: f32) {
	if ctx != nil && ctx.audio_backend != nil && source.handle != 0 {
		audio.Set_Pitch(ctx.audio_backend, source.handle, int(source.Kind), pitch)
	}
}

Set_Audio_Source_Pan :: proc(ctx: ^Context, source: Audio_Source, pan: f32) {
	if ctx != nil && ctx.audio_backend != nil && source.handle != 0 {
		audio.Set_Pan(ctx.audio_backend, source.handle, int(source.Kind), pan)
	}
}

Queue_Audio_Data :: proc(ctx: ^Context, source: Audio_Source, data: Sound_Data) -> Error {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 || source.Kind != .Queue {
		return .Invalid_Handle
	}
	if !audio.Queue(ctx.audio_backend, source.handle, data.Samples[:], data.Channels) {
		return .Capability_Unavailable
	}
	return .None
}

Set_Audio_Source_Looping :: proc(ctx: ^Context, source: Audio_Source, looping: bool) -> Error {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 {
		return .Invalid_Handle
	}
	if !audio.Set_Looping(ctx.audio_backend, source.handle, int(source.Kind), looping) {
		return .Invalid_Handle
	}
	return .None
}

Set_Audio_Source_Relative :: proc(ctx: ^Context, source: Audio_Source, relative: bool) -> Error {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 {
		return .Invalid_Handle
	}
	if !audio.Set_Positioning(ctx.audio_backend, source.handle, int(source.Kind), relative) {
		return .Invalid_Handle
	}
	return .None
}

Set_Audio_Source_Direction :: proc(ctx: ^Context, source: Audio_Source, direction: Vec2) -> Error {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 || !audio.Set_Direction(ctx.audio_backend, source.handle, int(source.Kind), direction.X, direction.Y) {
		return .Invalid_Handle
	}
	return .None
}

Set_Audio_Source_Cone :: proc(ctx: ^Context, source: Audio_Source, inner_angle, outer_angle, outer_gain: f32) -> Error {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 || !audio.Set_Cone(ctx.audio_backend, source.handle, int(source.Kind), inner_angle, outer_angle, outer_gain) {
		return .Invalid_Handle
	}
	return .None
}

Seek_Audio_Source :: proc(ctx: ^Context, source: Audio_Source, seconds: f32) -> Error {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 || !audio.Seek_Seconds(ctx.audio_backend, source.handle, int(source.Kind), seconds) {
		return .Invalid_Handle
	}
	return .None
}

Tell_Audio_Source :: proc(ctx: ^Context, source: Audio_Source) -> (f32, Error) {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 {
		return 0, .Invalid_Handle
	}
	value, ok := audio.Tell_Seconds(ctx.audio_backend, source.handle, int(source.Kind))
	if !ok {
		return 0, .Invalid_Handle
	}
	return value, .None
}

Audio_Source_Length :: proc(ctx: ^Context, source: Audio_Source) -> (f32, Error) {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 {
		return 0, .Invalid_Handle
	}
	value, ok := audio.Length_Seconds(ctx.audio_backend, source.handle, int(source.Kind))
	if !ok {
		return 0, .Invalid_Handle
	}
	return value, .None
}

Set_Audio_Listener :: proc(ctx: ^Context, position, direction, velocity: Vec2) -> Error {
	if ctx == nil || ctx.audio_backend == nil || !audio.Set_Listener(ctx.audio_backend, [3]f32{position.X, position.Y, 0}, [3]f32{direction.X, direction.Y, 0}, [3]f32{velocity.X, velocity.Y, 0}) {
		return .Capability_Unavailable
	}
	return .None
}

Enumerate_Audio_Devices :: proc(ctx: ^Context) -> ([dynamic]Audio_Device_Info, Error) {
	devices := make([dynamic]Audio_Device_Info, 0)
	if ctx == nil || ctx.audio_backend == nil {
		return devices, .Backend_Initialization_Failed
	}
	native_devices, ok := audio.Enumerate_Devices(ctx.audio_backend)
	if !ok {
		delete(devices)
		return nil, .Capability_Unavailable
	}
	defer audio.Destroy_Device_Infos(&native_devices)
	for native in native_devices {
		id, id_err := strings.clone(native.Id)
		name, name_err := strings.clone(native.Name)
		if id_err != nil || name_err != nil {
			if id_err == nil { delete(id) }
			if name_err == nil { delete(name) }
			for entry in devices {
				delete(entry.Id)
				delete(entry.Name)
			}
			delete(devices)
			return nil, .Resource_Load_Failed
		}
		append(&devices, Audio_Device_Info{Handle = native.Handle, Id = id, Name = name, Playback = native.Playback, Capture = native.Capture, Default = native.Default})
	}
	return devices, .None
}

Destroy_Audio_Device_Infos :: proc(devices: ^[dynamic]Audio_Device_Info) {
	if devices == nil {
		return
	}
	for device in devices^ {
		delete(device.Id)
		delete(device.Name)
	}
	delete(devices^)
}

Select_Audio_Device :: proc(ctx: ^Context, device: Audio_Device) -> Error {
	if ctx == nil || ctx.audio_backend == nil || device.handle == 0 {
		return .Invalid_Handle
	}
	if !audio.Select_Device(ctx.audio_backend, device.handle) {
		return .Unsupported
	}
	return .None
}

Audio_Device_From_Info :: proc(info: Audio_Device_Info) -> Audio_Device {
	return Audio_Device{handle = info.Handle}
}

Load_Audio_Decoder :: proc(ctx: ^Context, path: string) -> (Audio_Decoder, Error) {
	if ctx == nil || ctx.audio_backend == nil {
		return Audio_Decoder{}, .Backend_Initialization_Failed
	}
	file, file_err := Read_Path(&ctx.filesystem, path)
	if file_err != .None {
		return Audio_Decoder{}, file_err
	}
	defer Destroy_File_Data(&file)
	handle, ok := audio.Create_Decoder(ctx.audio_backend, file.Bytes[:])
	if !ok {
		return Audio_Decoder{}, .Resource_Load_Failed
	}
	return Audio_Decoder{handle}, .None
}

Unload_Audio_Decoder :: proc(ctx: ^Context, decoder: Audio_Decoder) {
	if ctx != nil && ctx.audio_backend != nil && decoder.handle != 0 {
		audio.Destroy_Decoder(ctx.audio_backend, decoder.handle)
	}
}

Read_Audio_Decoder :: proc(ctx: ^Context, decoder: Audio_Decoder, max_frames: int) -> (Sound_Data, Error) {
	if ctx == nil || ctx.audio_backend == nil || decoder.handle == 0 || max_frames <= 0 {
		return Sound_Data{}, .Invalid_Handle
	}
	samples, channels, sample_rate, _, ok := audio.Read_Decoder(ctx.audio_backend, decoder.handle, max_frames)
	if !ok {
		return Sound_Data{}, .Invalid_Handle
	}
	return Sound_Data{Samples = samples, Sample_Rate = sample_rate, Channels = channels, Bit_Depth = 32}, .None
}

Seek_Audio_Decoder :: proc(ctx: ^Context, decoder: Audio_Decoder, seconds: f32) -> Error {
	if ctx == nil || ctx.audio_backend == nil || decoder.handle == 0 || !audio.Seek_Decoder_Seconds(ctx.audio_backend, decoder.handle, seconds) {
		return .Invalid_Handle
	}
	return .None
}

Tell_Audio_Decoder :: proc(ctx: ^Context, decoder: Audio_Decoder) -> (f32, Error) {
	if ctx == nil || ctx.audio_backend == nil || decoder.handle == 0 {
		return 0, .Invalid_Handle
	}
	value, ok := audio.Tell_Decoder_Seconds(ctx.audio_backend, decoder.handle)
	if !ok {
		return 0, .Invalid_Handle
	}
	return value, .None
}

Audio_Decoder_Length :: proc(ctx: ^Context, decoder: Audio_Decoder) -> (f32, Error) {
	if ctx == nil || ctx.audio_backend == nil || decoder.handle == 0 {
		return 0, .Invalid_Handle
	}
	value, ok := audio.Length_Decoder_Seconds(ctx.audio_backend, decoder.handle)
	if !ok {
		return 0, .Invalid_Handle
	}
	return value, .None
}

Set_Audio_Position :: proc(ctx: ^Context, source: Audio_Source, position: Vec2) -> Error {
	if ctx == nil || ctx.audio_backend == nil || !audio.Set_Position(ctx.audio_backend, source.handle, int(source.Kind), position.X, position.Y) {
		return .Invalid_Handle
	}
	return .None
}

Set_Audio_Velocity :: proc(ctx: ^Context, source: Audio_Source, velocity: Vec2) -> Error {
	if ctx == nil || ctx.audio_backend == nil || !audio.Set_Velocity(ctx.audio_backend, source.handle, int(source.Kind), velocity.X, velocity.Y) {
		return .Invalid_Handle
	}
	return .None
}

Set_Audio_Attenuation :: proc(ctx: ^Context, source: Audio_Source, rolloff: f32) -> Error {
	if ctx == nil || ctx.audio_backend == nil || !audio.Set_Rolloff(ctx.audio_backend, source.handle, int(source.Kind), rolloff) {
		return .Invalid_Handle
	}
	return .None
}

Set_Audio_Distance_Model :: proc(ctx: ^Context, model: int) -> Error {
	if ctx == nil || ctx.audio_backend == nil || !audio.Set_Distance_Model(ctx.audio_backend, model) {
		return .Unsupported
	}
	return .None
}

Set_Audio_Doppler :: proc(ctx: ^Context, factor: f32) -> Error {
	if ctx == nil || ctx.audio_backend == nil || !audio.Set_Doppler_All(ctx.audio_backend, factor) {
		return .Invalid_Handle
	}
	return .None
}

Start_Audio_Capture :: proc(ctx: ^Context) -> Error {
	if ctx == nil || ctx.audio_backend == nil {
		return .Backend_Initialization_Failed
	}
	if !audio.Start_Capture(ctx.audio_backend) {
		return .Capability_Unavailable
	}
	return .None
}

Stop_Audio_Capture :: proc(ctx: ^Context) -> Error {
	if ctx == nil || ctx.audio_backend == nil {
		return .Backend_Initialization_Failed
	}
	audio.Stop_Capture(ctx.audio_backend)
	return .None
}

Read_Audio_Capture :: proc(ctx: ^Context, max_frames: int) -> (Sound_Data, Error) {
	if ctx == nil || ctx.audio_backend == nil {
		return Sound_Data{}, .Backend_Initialization_Failed
	}
	samples, channels, sample_rate, _, ok := audio.Read_Capture(ctx.audio_backend, max_frames)
	if !ok {
		return Sound_Data{}, .Capability_Unavailable
	}
	return Sound_Data{Samples = samples, Sample_Rate = sample_rate, Channels = channels, Bit_Depth = 32}, .None
}

Create_Audio_Bus :: proc(ctx: ^Context, name: string) -> (Audio_Bus, Error) {
	if ctx == nil || ctx.audio_backend == nil {
		return Audio_Bus{}, .Backend_Initialization_Failed
	}
	handle, ok := audio.Create_Bus(ctx.audio_backend)
	if !ok {
		return Audio_Bus{}, .Resource_Load_Failed
	}
	return Audio_Bus{handle}, .None
}

Set_Audio_Bus_Volume :: proc(ctx: ^Context, bus: Audio_Bus, volume: f32) -> Error {
	if ctx == nil || ctx.audio_backend == nil || !audio.Set_Bus_Volume(ctx.audio_backend, bus.handle, volume) {
		return .Invalid_Handle
	}
	return .None
}

Destroy_Audio_Bus :: proc(ctx: ^Context, bus: Audio_Bus) {
	if ctx != nil && ctx.audio_backend != nil && bus.handle != 0 {
		audio.Destroy_Bus(ctx.audio_backend, bus.handle)
	}
}

Set_Audio_Source_Bus :: proc(ctx: ^Context, source: Audio_Source, bus: Audio_Bus) -> Error {
	if ctx == nil || ctx.audio_backend == nil || source.handle == 0 || bus.handle == 0 {
		return .Invalid_Handle
	}
	if !audio.Attach_Bus(ctx.audio_backend, source.handle, bus.handle, int(source.Kind)) {
		return .Invalid_Handle
	}
	return .None
}

Create_Audio_Effect :: proc(ctx: ^Context, kind: int) -> (Audio_Effect, Error) {
	if ctx == nil || ctx.audio_backend == nil {
		return Audio_Effect{}, .Backend_Initialization_Failed
	}
	handle, ok := audio.Create_Effect(ctx.audio_backend, kind, 1000)
	if !ok {
		return Audio_Effect{}, .Capability_Unavailable
	}
	return Audio_Effect{handle}, .None
}

Destroy_Audio_Effect :: proc(ctx: ^Context, effect: Audio_Effect) {
	if ctx != nil && ctx.audio_backend != nil && effect.handle != 0 {
		audio.Destroy_Effect(ctx.audio_backend, effect.handle)
	}
}

Attach_Audio_Effect :: proc(ctx: ^Context, source: Audio_Source, effect: Audio_Effect) -> Error {
	if ctx == nil || ctx.audio_backend == nil || !audio.Attach_Effect(ctx.audio_backend, source.handle, effect.handle, int(source.Kind)) {
		return .Capability_Unavailable
	}
	return .None
}

Detach_Audio_Effect :: proc(ctx: ^Context, source: Audio_Source, effect: Audio_Effect) -> Error {
	if ctx == nil || ctx.audio_backend == nil || !audio.Detach_Effect(ctx.audio_backend, source.handle, effect.handle, int(source.Kind)) {
		return .Capability_Unavailable
	}
	return .None
}

Set_Audio_Effect_Volume :: proc(ctx: ^Context, effect: Audio_Effect, volume: f32) -> Error {
	if ctx == nil || ctx.audio_backend == nil || effect.handle == 0 {
		return .Invalid_Handle
	}
	if !audio.Set_Effect_Volume(ctx.audio_backend, effect.handle, volume) {
		return .Unsupported
	}
	return .None
}

Active_Audio_Source_Count :: proc(ctx: ^Context) -> int {
	if ctx == nil || ctx.audio_backend == nil {
		return 0
	}
	return audio.Active_Source_Count(ctx.audio_backend)
}

Get_Audio_Capabilities :: proc(ctx: ^Context) -> Audio_Capabilities {
	if ctx == nil || ctx.audio_backend == nil {
		return Audio_Capabilities{}
	}
	return Audio_Capabilities{
		Playback = audio.Available(ctx.audio_backend),
		Capture = audio.Supports_Capture(ctx.audio_backend),
		Spatial = audio.Supports_Spatial(ctx.audio_backend),
		Effects = audio.Supports_Effects(ctx.audio_backend),
		Queue = audio.Available(ctx.audio_backend),
	}
}
