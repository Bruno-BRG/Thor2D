package audio_backend

import "core:c"
import "core:strings"
import ma "vendor:miniaudio"

Queue_Chunk :: struct {
	Samples: [dynamic]f32,
	Channels: int,
}

Source_Entry :: struct {
	handle: u64,
	kind: int,
	sound: ma.sound,
	decoder: ma.decoder,
	buffer: ma.audio_buffer,
	data: [dynamic]byte,
	samples: [dynamic]f32,
	queue: [dynamic]Queue_Chunk,
	queue_index: int,
	decoder_ready: bool,
	buffer_ready: bool,
	sound_ready: bool,
	looping: bool,
	paused: bool,
	channels: int,
	sample_rate: int,
	bus_handle: u64,
	effect_handle: u64,
}

Bus_Entry :: struct {
	handle: u64,
	group: ma.sound_group,
}

Sound_Cache_Entry :: struct {
	path: string,
	handle: u64,
	asset_id: u64,
}

Device_Info :: struct {
	Handle: u64,
	Id: string,
	Name: string,
	Playback: bool,
	Capture: bool,
	Default: bool,
}

Decoder_Entry :: struct {
	handle: u64,
	decoder: ma.decoder,
	data: [dynamic]byte,
	channels: int,
	sample_rate: int,
	ready: bool,
}

Capture_Entry :: struct {
	device: ma.device,
	ring: ma.pcm_rb,
	channels: int,
	sample_rate: int,
	ready: bool,
}

Effect_Entry :: struct {
	handle: u64,
	kind: int,
	lpf: ma.lpf_node,
	hpf: ma.hpf_node,
	bpf: ma.bpf_node,
	delay: ma.delay_node,
	volume_group: ma.sound_group,
	initialized: bool,
}

Audio_Backend :: struct {
	engine: ma.engine,
	initialized: bool,
	next_handle: u64,
	sources: [dynamic]^Source_Entry,
	buses: [dynamic]^Bus_Entry,
	effects: [dynamic]^Effect_Entry,
	sound_cache: [dynamic]Sound_Cache_Entry,
	decoders: [dynamic]^Decoder_Entry,
	capture: ^Capture_Entry,
	master_volume: f32,
	distance_model: ma.attenuation_model,
	doppler_scale: f32,
	listener_position: [3]f32,
	listener_velocity: [3]f32,
	listener_direction: [3]f32,
	listener_up: [3]f32,
}

result_ok :: proc "contextless" (value: ma.result) -> bool {
	return value == ma.result.SUCCESS
}

b32_to_bool :: proc(value: b32) -> bool {
	if value {
		return true
	}
	return false
}

device_handle :: proc(id: string) -> u64 {
	hash: u64 = 14695981039346656037
	for value in id {
		hash = hash ~ u64(value)
		hash *= 1099511628211
	}
	return hash if hash != 0 else 1
}

init_engine :: proc(b: ^Audio_Backend, playback_id: ^ma.device_id = nil) -> bool {
	if b == nil {
		return false
	}
	config := ma.engine_config_init()
	config.listenerCount = 1
	config.channels = 2
	config.sampleRate = 48000
	config.periodSizeInMilliseconds = 20
	config.pPlaybackDeviceID = playback_id
	return result_ok(ma.engine_init(&config, &b.engine))
}

capture_callback :: proc "c" (device: ^ma.device, output, input: rawptr, frame_count: u32) {
	if device == nil || input == nil || device.pUserData == nil {
		return
	}
	capture := cast(^Capture_Entry)device.pUserData
	if !capture.ready || capture.channels <= 0 {
		return
	}
	frames := min(frame_count, ma.pcm_rb_available_write(&capture.ring))
	if frames == 0 {
		return
	}
	write_frames := frames
	buffer: rawptr
	if !result_ok(ma.pcm_rb_acquire_write(&capture.ring, &write_frames, &buffer)) || buffer == nil {
		return
	}
	input_samples := ([^]f32)(input)[:int(write_frames)*capture.channels]
	output_samples := ([^]f32)(buffer)[:int(write_frames)*capture.channels]
	for i := 0; i < len(output_samples); i += 1 {
		output_samples[i] = input_samples[i]
	}
	ma.pcm_rb_commit_write(&capture.ring, write_frames)
}

device_name :: proc(info: ^ma.device_info) -> string {
	if info == nil {
		return ""
	}
	length := 0
	for length < len(info.name) && info.name[length] != 0 {
		length += 1
	}
	if length == 0 {
		return "Unknown audio device"
	}
	bytes := make([dynamic]byte, length)
	for i := 0; i < length; i += 1 {
		bytes[i] = byte(info.name[i])
	}
	value, clone_err := strings.clone(string(bytes[:]))
	delete(bytes)
	if clone_err != nil {
		return "Unknown audio device"
	}
	return value
}

device_index_name :: proc(kind: string, index: int) -> string {
	// Device IDs are opaque in miniaudio. Include the enumeration index so
	// playback and capture entries remain distinct within this process.
	digits: [32]byte
	n := 0
	value := index
	if value == 0 {
		digits[0] = '0'
		n = 1
	} else {
		for value > 0 && n < len(digits) {
			digits[n] = byte(value%10) + '0'
			value /= 10
			n += 1
		}
	}
	bytes := make([dynamic]byte, len(kind)+1+n)
	copy(bytes[:], transmute([]byte)kind)
	bytes[len(kind)] = ':'
	for i := 0; i < n; i += 1 {
		bytes[len(kind)+1+i] = digits[n-1-i]
	}
	value_string, clone_err := strings.clone(string(bytes[:]))
	delete(bytes)
	if clone_err != nil {
		return kind
	}
	return value_string
}

Create :: proc() -> (rawptr, bool) {
	b := new(Audio_Backend)
	b.next_handle = 1
	b.master_volume = 1
	b.distance_model = .inverse
	b.doppler_scale = 1
	// LOVE listener defaults: forward (0,0,-1), up (0,1,0).
	b.listener_direction = [3]f32{0, 0, -1}
	b.listener_up = [3]f32{0, 1, 0}
	if !init_engine(b) {
		free(b)
		return nil, false
	}
	b.initialized = true
	ma.engine_listener_set_direction(&b.engine, 0, 0, 0, -1)
	ma.engine_listener_set_world_up(&b.engine, 0, 0, 1, 0)
	return rawptr(b), true
}

Enumerate_Devices :: proc(state: rawptr) -> ([dynamic]Device_Info, bool) {
	devices := make([dynamic]Device_Info, 0)
	if !Available(state) {
		return devices, false
	}
	b := cast(^Audio_Backend)state
	device := ma.engine_get_device(&b.engine)
	if device == nil || device.pContext == nil {
		return devices, false
	}
	playback_infos: [^]ma.device_info
	capture_infos: [^]ma.device_info
	playback_count, capture_count: u32
	if !result_ok(ma.context_get_devices(device.pContext, &playback_infos, &playback_count, &capture_infos, &capture_count)) {
		return devices, false
	}
	for i := u32(0); i < playback_count; i += 1 {
		info := &playback_infos[i]
		name := device_name(info)
		id := device_index_name("playback", int(i))
		append(&devices, Device_Info{Handle = device_handle(id), Id = id, Name = name, Playback = true, Default = b32_to_bool(info.isDefault)})
	}
	for i := u32(0); i < capture_count; i += 1 {
		info := &capture_infos[i]
		name := device_name(info)
		id := device_index_name("capture", int(i))
		append(&devices, Device_Info{Handle = device_handle(id), Id = id, Name = name, Capture = true, Default = b32_to_bool(info.isDefault)})
	}
	return devices, true
}

Destroy_Device_Infos :: proc(devices: ^[dynamic]Device_Info) {
	if devices == nil {
		return
	}
	for device in devices^ {
		delete(device.Id)
		delete(device.Name)
	}
	delete(devices^)
}

Select_Device :: proc(state: rawptr, handle: u64) -> bool {
	if !Available(state) || handle == 0 {
		return false
	}
	b := cast(^Audio_Backend)state
	// Rebuilding the device graph invalidates every sound node. Refuse the
	// operation while resources are live instead of silently losing them.
	if len(b.sources) != 0 || len(b.buses) != 0 || len(b.effects) != 0 || len(b.decoders) != 0 || b.capture != nil {
		return false
	}
	device := ma.engine_get_device(&b.engine)
	if device == nil || device.pContext == nil {
		return false
	}
	playback_infos: [^]ma.device_info
	capture_infos: [^]ma.device_info
	playback_count, capture_count: u32
	if !result_ok(ma.context_get_devices(device.pContext, &playback_infos, &playback_count, &capture_infos, &capture_count)) {
		return false
	}
	chosen: ma.device_id
	found := false
	for i := u32(0); i < playback_count; i += 1 {
		id := device_index_name("playback", int(i))
		if device_handle(id) == handle {
			chosen = playback_infos[i].id
			found = true
		}
		delete(id)
		if found {
			break
		}
	}
	if !found {
		return false
	}
	ma.engine_uninit(&b.engine)
	b.initialized = false
	if !init_engine(b, &chosen) {
		// Keep the runtime usable if a device disappeared between enumeration
		// and initialization.
		if init_engine(b) {
			b.initialized = true
		}
		return false
	}
	b.initialized = true
	return true
}

find_source :: proc(b: ^Audio_Backend, handle: u64, kind := -1) -> (^Source_Entry, bool) {
	if b == nil || handle == 0 {
		return nil, false
	}
	for source in b.sources {
		if source.handle == handle && (kind < 0 || source.kind == kind) {
			return source, true
		}
	}
	return nil, false
}

find_bus :: proc(b: ^Audio_Backend, handle: u64) -> (^Bus_Entry, bool) {
	if b == nil || handle == 0 {
		return nil, false
	}
	for bus in b.buses {
		if bus.handle == handle {
			return bus, true
		}
	}
	return nil, false
}

find_effect :: proc(b: ^Audio_Backend, handle: u64) -> (^Effect_Entry, bool) {
	if b == nil || handle == 0 {
		return nil, false
	}
	for effect in b.effects {
		if effect.handle == handle {
			return effect, true
		}
	}
	return nil, false
}

source_data_source :: proc(source: ^Source_Entry) -> ^ma.data_source {
	if source == nil {
		return nil
	}
	if source.decoder_ready {
		return cast(^ma.data_source)&source.decoder.ds
	}
	if source.buffer_ready {
		return cast(^ma.data_source)&source.buffer.ref.ds
	}
	return nil
}

init_sound :: proc(b: ^Audio_Backend, source: ^Source_Entry, bus: ^Bus_Entry = nil) -> bool {
	data_source := source_data_source(source)
	if data_source == nil {
		return false
	}
	group: ^ma.sound_group
	if bus != nil {
		group = &bus.group
	}
	if !result_ok(ma.sound_init_from_data_source(&b.engine, data_source, {}, group, &source.sound)) {
		return false
	}
	source.sound_ready = true
	ma.sound_set_attenuation_model(&source.sound, b.distance_model)
	ma.sound_set_doppler_factor(&source.sound, max(0, b.doppler_scale))
	return true
}

copy_bytes :: proc(destination: ^[dynamic]byte, source: []byte) -> bool {
	if len(source) == 0 {
		return false
	}
	destination^ = make([dynamic]byte, len(source))
	copy(destination^[:], source)
	return true
}

decode_all :: proc(source: ^Source_Entry) -> (int, int, bool) {
	config := ma.decoder_config_init(.f32, 0, 0)
	if !result_ok(ma.decoder_init_memory(rawptr(&source.data[0]), c.size_t(len(source.data)), &config, &source.decoder)) {
		return 0, 0, false
	}
	source.decoder_ready = true
	format: ma.format
	channels, sample_rate: u32
	channel_map: [256]ma.channel
	if !result_ok(ma.decoder_get_data_format(&source.decoder, &format, &channels, &sample_rate, &channel_map[0], len(channel_map))) {
		return 0, 0, false
	}
	if format != .f32 || channels == 0 || sample_rate == 0 {
		return 0, 0, false
	}
	frame_count: u64
	if !result_ok(ma.decoder_get_length_in_pcm_frames(&source.decoder, &frame_count)) || frame_count == 0 {
		return 0, 0, false
	}
	if frame_count > u64(1 << 60) / u64(channels) {
		return 0, 0, false
	}
	source.samples = make([dynamic]f32, int(frame_count)*int(channels))
	frames_read: u64
	if !result_ok(ma.decoder_read_pcm_frames(&source.decoder, rawptr(&source.samples[0]), frame_count, &frames_read)) || frames_read != frame_count {
		return 0, 0, false
	}
	ma.decoder_uninit(&source.decoder)
	source.decoder_ready = false
	return int(channels), int(sample_rate), true
}

init_buffer_from_samples :: proc(source: ^Source_Entry, sample_rate, channels: int) -> bool {
	if source == nil || len(source.samples) == 0 || sample_rate <= 0 || channels <= 0 || len(source.samples)%channels != 0 {
		return false
	}
	config := ma.audio_buffer_config_init(.f32, u32(channels), u64(len(source.samples)/channels), rawptr(&source.samples[0]), nil)
	config.sampleRate = u32(sample_rate)
	if !result_ok(ma.audio_buffer_init(&config, &source.buffer)) {
		return false
	}
	source.buffer_ready = true
	return true
}

Load_Static :: proc(state: rawptr, path: string, data: []byte) -> (u64, bool) {
	if state == nil || len(data) == 0 {
		return 0, false
	}
	b := cast(^Audio_Backend)state
	source := new(Source_Entry)
	source.handle = b.next_handle
	source.kind = 0
	b.next_handle += 1
	if !copy_bytes(&source.data, data) {
		free(source)
		return 0, false
	}
	channels, sample_rate, ok := decode_all(source)
	if !ok || !init_buffer_from_samples(source, sample_rate, channels) || !init_sound(b, source) {
		if source.decoder_ready {
			ma.decoder_uninit(&source.decoder)
		}
		if source.buffer_ready {
			ma.audio_buffer_uninit(&source.buffer)
		}
		delete(source.data)
		delete(source.samples)
		free(source)
		return 0, false
	}
	source.channels = channels
	source.sample_rate = sample_rate
	delete(source.data)
	append(&b.sources, source)
	return source.handle, true
}

stable_asset_id :: proc(path: string) -> u64 {
	// FNV-1a gives project assets a deterministic, dependency-free identifier.
	// The project manifest remains the authority when a persisted ID is present.
	hash: u64 = 14695981039346656037
	for value in path {
		hash = hash ~ u64(value)
		hash *= 1099511628211
	}
	if hash == 0 {
		return 1
	}
	return hash
}

Load_Static_Cached :: proc(state: rawptr, path: string, data: []byte) -> (u64, u64, bool) {
	if state == nil || path == "" {
		return 0, 0, false
	}
	b := cast(^Audio_Backend)state
	for entry in b.sound_cache {
		if entry.path == path {
			return entry.handle, entry.asset_id, true
		}
	}
	handle, ok := Load_Static(state, path, data)
	if !ok {
		return 0, 0, false
	}
	owned, clone_err := strings.clone(path)
	if clone_err != nil {
		Destroy_Source(state, handle, 0)
		return 0, 0, false
	}
	asset_id := stable_asset_id(path)
	append(&b.sound_cache, Sound_Cache_Entry{path = owned, handle = handle, asset_id = asset_id})
	return handle, asset_id, true
}

find_decoder :: proc(b: ^Audio_Backend, handle: u64) -> (^Decoder_Entry, bool) {
	if b == nil || handle == 0 {
		return nil, false
	}
	for decoder in b.decoders {
		if decoder.handle == handle {
			return decoder, true
		}
	}
	return nil, false
}

Create_Decoder :: proc(state: rawptr, data: []byte) -> (u64, bool) {
	if state == nil || len(data) == 0 {
		return 0, false
	}
	b := cast(^Audio_Backend)state
	decoder := new(Decoder_Entry)
	decoder.handle = b.next_handle
	b.next_handle += 1
	decoder.data = make([dynamic]byte, len(data))
	copy(decoder.data[:], data)
	config := ma.decoder_config_init(.f32, 0, 0)
	if !result_ok(ma.decoder_init_memory(rawptr(&decoder.data[0]), c.size_t(len(decoder.data)), &config, &decoder.decoder)) {
		delete(decoder.data)
		free(decoder)
		return 0, false
	}
	decoder.ready = true
	format: ma.format
	channels, sample_rate: u32
	channel_map: [256]ma.channel
	if !result_ok(ma.decoder_get_data_format(&decoder.decoder, &format, &channels, &sample_rate, &channel_map[0], len(channel_map))) || format != .f32 || channels == 0 || sample_rate == 0 {
		ma.decoder_uninit(&decoder.decoder)
		delete(decoder.data)
		free(decoder)
		return 0, false
	}
	decoder.channels = int(channels)
	decoder.sample_rate = int(sample_rate)
	append(&b.decoders, decoder)
	return decoder.handle, true
}

Read_Decoder :: proc(state: rawptr, handle: u64, max_frames: int) -> (samples: [dynamic]f32, channels, sample_rate, frames: int, ok: bool) {
	decoder, found := find_decoder(cast(^Audio_Backend)state, handle)
	if !found || !decoder.ready || max_frames <= 0 {
		return nil, 0, 0, 0, false
	}
	frames_to_read := max_frames
	available: u64
	if result_ok(ma.decoder_get_available_frames(&decoder.decoder, &available)) && available < u64(frames_to_read) {
		frames_to_read = int(available)
	}
	if frames_to_read <= 0 {
		return make([dynamic]f32, 0), decoder.channels, decoder.sample_rate, 0, true
	}
	samples = make([dynamic]f32, frames_to_read*decoder.channels)
	frames_read: u64
	if !result_ok(ma.decoder_read_pcm_frames(&decoder.decoder, rawptr(&samples[0]), u64(frames_to_read), &frames_read)) {
		delete(samples)
		return nil, 0, 0, 0, false
	}
	resize(&samples, int(frames_read)*decoder.channels)
	return samples, decoder.channels, decoder.sample_rate, int(frames_read), true
}

Seek_Decoder_Seconds :: proc(state: rawptr, handle: u64, seconds: f32) -> bool {
	decoder, found := find_decoder(cast(^Audio_Backend)state, handle)
	if !found || !decoder.ready {
		return false
	}
	return result_ok(ma.decoder_seek_to_pcm_frame(&decoder.decoder, u64(max(0, seconds)*f32(decoder.sample_rate))))
}

Tell_Decoder_Seconds :: proc(state: rawptr, handle: u64) -> (f32, bool) {
	decoder, found := find_decoder(cast(^Audio_Backend)state, handle)
	if !found || !decoder.ready {
		return 0, false
	}
	frame: u64
	if !result_ok(ma.decoder_get_cursor_in_pcm_frames(&decoder.decoder, &frame)) {
		return 0, false
	}
	return f32(frame) / f32(decoder.sample_rate), true
}

Length_Decoder_Seconds :: proc(state: rawptr, handle: u64) -> (f32, bool) {
	decoder, found := find_decoder(cast(^Audio_Backend)state, handle)
	if !found || !decoder.ready {
		return 0, false
	}
	frames: u64
	if !result_ok(ma.decoder_get_length_in_pcm_frames(&decoder.decoder, &frames)) {
		return 0, false
	}
	return f32(frames) / f32(decoder.sample_rate), true
}

Destroy_Decoder :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	b := cast(^Audio_Backend)state
	for index := 0; index < len(b.decoders); index += 1 {
		decoder := b.decoders[index]
		if decoder.handle != handle {
			continue
		}
		if decoder.ready {
			ma.decoder_uninit(&decoder.decoder)
		}
		delete(decoder.data)
		free(decoder)
		unordered_remove(&b.decoders, index)
		return
	}
}

Sound_Asset_ID :: proc(state: rawptr, handle: u64) -> u64 {
	if state == nil || handle == 0 {
		return 0
	}
	b := cast(^Audio_Backend)state
	for entry in b.sound_cache {
		if entry.handle == handle {
			return entry.asset_id
		}
	}
	return 0
}

Load_Stream :: proc(state: rawptr, path: string, data: []byte) -> (u64, bool) {
	if state == nil || len(data) == 0 {
		return 0, false
	}
	b := cast(^Audio_Backend)state
	source := new(Source_Entry)
	source.handle = b.next_handle
	source.kind = 1
	b.next_handle += 1
	if !copy_bytes(&source.data, data) {
		free(source)
		return 0, false
	}
	config := ma.decoder_config_init(.f32, 0, 0)
	if !result_ok(ma.decoder_init_memory(rawptr(&source.data[0]), c.size_t(len(source.data)), &config, &source.decoder)) {
		delete(source.data)
		free(source)
		return 0, false
	}
	source.decoder_ready = true
	format: ma.format
	channels, sample_rate: u32
	channel_map: [256]ma.channel
	if !result_ok(ma.decoder_get_data_format(&source.decoder, &format, &channels, &sample_rate, &channel_map[0], len(channel_map))) || format != .f32 || channels == 0 || sample_rate == 0 {
		ma.decoder_uninit(&source.decoder)
		delete(source.data)
		free(source)
		return 0, false
	}
	source.channels = int(channels)
	source.sample_rate = int(sample_rate)
	if !init_sound(b, source) {
		ma.decoder_uninit(&source.decoder)
		delete(source.data)
		free(source)
		return 0, false
	}
	append(&b.sources, source)
	return source.handle, true
}

Create_From_Data :: proc(state: rawptr, samples: []f32, sample_rate, channels: int) -> (u64, bool) {
	if state == nil || len(samples) == 0 || sample_rate <= 0 || channels <= 0 || len(samples)%channels != 0 {
		return 0, false
	}
	b := cast(^Audio_Backend)state
	source := new(Source_Entry)
	source.handle = b.next_handle
	source.kind = 0
	b.next_handle += 1
	source.samples = make([dynamic]f32, len(samples))
	copy(source.samples[:], samples)
	if !init_buffer_from_samples(source, sample_rate, channels) || !init_sound(b, source) {
		if source.buffer_ready {
			ma.audio_buffer_uninit(&source.buffer)
		}
		delete(source.samples)
		free(source)
		return 0, false
	}
	source.channels = channels
	source.sample_rate = sample_rate
	append(&b.sources, source)
	return source.handle, true
}

Create_Queue :: proc(state: rawptr, sample_rate, channels: int) -> (u64, bool) {
	if state == nil || sample_rate <= 0 || channels <= 0 {
		return 0, false
	}
	// A one-frame silent buffer gives the queue a valid data source until its
	// first chunk arrives. The update path replaces it without reallocating the
	// Source_Entry referenced by miniaudio.
	silence := make([dynamic]f32, channels)
	defer delete(silence)
	handle, ok := Create_From_Data(state, silence[:], sample_rate, channels)
	if ok {
		if source, found := find_source(cast(^Audio_Backend)state, handle, 0); found {
			source.kind = 2
		}
	}
	return handle, ok
}

Play :: proc(state: rawptr, handle: u64, kind: int) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		source.paused = false
		ma.sound_start(&source.sound)
	}
}

Pause :: proc(state: rawptr, handle: u64, kind: int) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		source.paused = true
		ma.node_set_state(cast(^ma.node)&source.sound.engineNode.baseNode, .stopped)
	}
}

Resume :: proc(state: rawptr, handle: u64, kind: int) {
	Play(state, handle, kind)
}

Stop :: proc(state: rawptr, handle: u64, kind: int) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		source.paused = false
		ma.sound_stop(&source.sound)
		ma.sound_seek_to_pcm_frame(&source.sound, 0)
	}
}

Rewind :: proc(state: rawptr, handle: u64, kind: int) -> bool {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		source.paused = false
		return result_ok(ma.sound_seek_to_pcm_frame(&source.sound, 0))
	}
	return false
}

Clone_Source :: proc(state: rawptr, handle: u64, kind: int) -> (u64, bool) {
	if state == nil {
		return 0, false
	}
	source, found := find_source(cast(^Audio_Backend)state, handle, kind)
	if !found {
		return 0, false
	}
	if kind == 0 && len(source.samples) > 0 {
		return Create_From_Data(state, source.samples[:], source.sample_rate, source.channels)
	}
	if kind == 1 && len(source.data) > 0 {
		return Load_Stream(state, "", source.data[:])
	}
	// Queue sources have transient timing state and cannot be cloned safely.
	return 0, false
}

Set_Volume :: proc(state: rawptr, handle: u64, kind: int, value: f32) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		ma.sound_set_volume(&source.sound, max(0, value))
	}
}

Set_Master :: proc(state: rawptr, value: f32) {
	if state == nil {
		return
	}
	b := cast(^Audio_Backend)state
	b.master_volume = max(0, value)
	ma.engine_set_volume(&b.engine, b.master_volume)
}

Get_Master :: proc(state: rawptr) -> f32 {
	if state == nil {
		return 0
	}
	return (cast(^Audio_Backend)state).master_volume
}

Get_Distance_Model :: proc(state: rawptr) -> int {
	if state == nil {
		return 1
	}
	#partial switch (cast(^Audio_Backend)state).distance_model {
	case .none:
		return 0
	case .linear:
		return 3
	case .exponential:
		return 5
	}
	return 1
}

Get_Listener :: proc(state: rawptr) -> (position, velocity: [3]f32) {
	if state == nil {
		return [3]f32{}, [3]f32{}
	}
	b := cast(^Audio_Backend)state
	return b.listener_position, b.listener_velocity
}

Set_Pitch :: proc(state: rawptr, handle: u64, kind: int, value: f32) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		ma.sound_set_pitch(&source.sound, max(0.01, value))
	}
}

Set_Pan :: proc(state: rawptr, handle: u64, kind: int, value: f32) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		ma.sound_set_pan(&source.sound, value)
	}
}

Set_Looping :: proc(state: rawptr, handle: u64, kind: int, value: bool) -> bool {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		source.looping = value
		ma.sound_set_looping(&source.sound, b32(value))
		return true
	}
	return false
}

State :: proc(state: rawptr, handle: u64, kind: int) -> int {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		if source.paused {
			return 2
		}
		if ma.sound_is_playing(&source.sound) {
			return 1
		}
		return 0
	}
	return 0
}

Seek_Seconds :: proc(state: rawptr, handle: u64, kind: int, seconds: f32) -> bool {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		return result_ok(ma.sound_seek_to_second(&source.sound, max(0, seconds)))
	}
	return false
}

Tell_Seconds :: proc(state: rawptr, handle: u64, kind: int) -> (f32, bool) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		value: f32
		return value, result_ok(ma.sound_get_cursor_in_seconds(&source.sound, &value))
	}
	return 0, false
}

Length_Seconds :: proc(state: rawptr, handle: u64, kind: int) -> (f32, bool) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		value: f32
		return value, result_ok(ma.sound_get_length_in_seconds(&source.sound, &value))
	}
	return 0, false
}

// v0.10 wave 4 source getters (LOVE Source:get* parity). All query live
// miniaudio state where a ma.sound_get_* accessor exists, so the values are
// real engine state, never stored guesses. Channels/sample rate come from
// the entry fields captured at decode time. Bad handles return zero values
// with ok=false; callers map those to stored/zero values, never fake data.

Get_Source_Volume :: proc(state: rawptr, handle: u64, kind: int) -> (f32, bool) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		return ma.sound_get_volume(&source.sound), true
	}
	return 0, false
}

Get_Source_Pitch :: proc(state: rawptr, handle: u64, kind: int) -> (f32, bool) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		return ma.sound_get_pitch(&source.sound), true
	}
	return 0, false
}

Get_Source_Pan :: proc(state: rawptr, handle: u64, kind: int) -> (f32, bool) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		return ma.sound_get_pan(&source.sound), true
	}
	return 0, false
}

Get_Source_Position :: proc(state: rawptr, handle: u64, kind: int) -> ([3]f32, bool) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		v := ma.sound_get_position(&source.sound)
		return [3]f32{v.x, v.y, v.z}, true
	}
	return [3]f32{}, false
}

Get_Source_Velocity :: proc(state: rawptr, handle: u64, kind: int) -> ([3]f32, bool) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		v := ma.sound_get_velocity(&source.sound)
		return [3]f32{v.x, v.y, v.z}, true
	}
	return [3]f32{}, false
}

Get_Source_Direction :: proc(state: rawptr, handle: u64, kind: int) -> ([3]f32, bool) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		v := ma.sound_get_direction(&source.sound)
		return [3]f32{v.x, v.y, v.z}, true
	}
	return [3]f32{}, false
}

Get_Source_Cone :: proc(state: rawptr, handle: u64, kind: int) -> (inner, outer, gain: f32, ok: bool) {
	if source, found := find_source(cast(^Audio_Backend)state, handle, kind); found && source.sound_ready {
		ma.sound_get_cone(&source.sound, &inner, &outer, &gain)
		return inner, outer, gain, true
	}
	return 0, 0, 0, false
}

Get_Source_Rolloff :: proc(state: rawptr, handle: u64, kind: int) -> (f32, bool) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		return ma.sound_get_rolloff(&source.sound), true
	}
	return 0, false
}

Get_Source_Doppler :: proc(state: rawptr, handle: u64, kind: int) -> (f32, bool) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		return ma.sound_get_doppler_factor(&source.sound), true
	}
	return 0, false
}

Get_Source_Positioning :: proc(state: rawptr, handle: u64, kind: int) -> (bool, bool) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		return ma.sound_get_positioning(&source.sound) == .relative, true
	}
	return false, false
}

Is_Source_Looping :: proc(state: rawptr, handle: u64, kind: int) -> (bool, bool) {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		return b32_to_bool(ma.sound_is_looping(&source.sound)), true
	}
	return false, false
}

Get_Source_Format :: proc(state: rawptr, handle: u64, kind: int) -> (channels, sample_rate: int, ok: bool) {
	if source, found := find_source(cast(^Audio_Backend)state, handle, kind); found && source.channels > 0 && source.sample_rate > 0 {
		return source.channels, source.sample_rate, true
	}
	return 0, 0, false
}

// Play/Pause/Stop_All iterate the live source list (LOVE love.audio.play/
// pause/stop with no arguments) and return how many sources were acted on.
Play_All :: proc(state: rawptr) -> int {
	if state == nil {
		return 0
	}
	b := cast(^Audio_Backend)state
	count := 0
	for source in b.sources {
		if source.sound_ready {
			source.paused = false
			ma.sound_start(&source.sound)
			count += 1
		}
	}
	return count
}

Pause_All :: proc(state: rawptr) -> int {
	if state == nil {
		return 0
	}
	b := cast(^Audio_Backend)state
	count := 0
	for source in b.sources {
		if source.sound_ready {
			source.paused = true
			ma.node_set_state(cast(^ma.node)&source.sound.engineNode.baseNode, .stopped)
			count += 1
		}
	}
	return count
}

Stop_All :: proc(state: rawptr) -> int {
	if state == nil {
		return 0
	}
	b := cast(^Audio_Backend)state
	count := 0
	for source in b.sources {
		if source.sound_ready {
			source.paused = false
			ma.sound_stop(&source.sound)
			ma.sound_seek_to_pcm_frame(&source.sound, 0)
			count += 1
		}
	}
	return count
}

// Decoder_Format reports the decoded stream format retained in the decoder
// entry (LOVE Decoder:getChannelCount/getSampleRate parity). Decoders always
// produce f32 PCM, so bit depth is 32 wherever a live decoder exists.
Decoder_Format :: proc(state: rawptr, handle: u64) -> (channels, sample_rate: int, ok: bool) {
	if decoder, found := find_decoder(cast(^Audio_Backend)state, handle); found && decoder.ready {
		return decoder.channels, decoder.sample_rate, true
	}
	return 0, 0, false
}

// Capture_Info reports the live capture ring state (LOVE RecordingDevice
// getSampleRate/getChannelCount/getSampleCount/isRecording parity). The ring
// is f32 PCM, so bit depth is 32 wherever capture is active.
Capture_Info :: proc(state: rawptr) -> (channels, sample_rate, buffered_frames: int, recording: bool) {
	if state == nil {
		return 0, 0, 0, false
	}
	capture := (cast(^Audio_Backend)state).capture
	if capture == nil || !capture.ready {
		return 0, 0, 0, false
	}
	return capture.channels, capture.sample_rate, int(ma.pcm_rb_available_read(&capture.ring)), true
}

Set_Position :: proc(state: rawptr, handle: u64, kind: int, x, y: f32) -> bool {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		ma.sound_set_position(&source.sound, x, y, 0)
		return true
	}
	return false
}

Set_Velocity :: proc(state: rawptr, handle: u64, kind: int, x, y: f32) -> bool {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		ma.sound_set_velocity(&source.sound, x, y, 0)
		return true
	}
	return false
}

Set_Positioning :: proc(state: rawptr, handle: u64, kind: int, relative: bool) -> bool {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		positioning := ma.positioning.absolute
		if relative {
			positioning = .relative
		}
		ma.sound_set_positioning(&source.sound, positioning)
		ma.sound_set_spatialization_enabled(&source.sound, b32(!relative))
		return true
	}
	return false
}

Set_Direction :: proc(state: rawptr, handle: u64, kind: int, x, y: f32) -> bool {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		ma.sound_set_direction(&source.sound, x, y, 0)
		return true
	}
	return false
}

Set_Cone :: proc(state: rawptr, handle: u64, kind: int, inner_angle, outer_angle, outer_gain: f32) -> bool {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		ma.sound_set_cone(&source.sound, inner_angle, outer_angle, max(0, outer_gain))
		return true
	}
	return false
}

Set_Rolloff :: proc(state: rawptr, handle: u64, kind: int, rolloff: f32) -> bool {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		ma.sound_set_rolloff(&source.sound, max(0, rolloff))
		return true
	}
	return false
}

Set_Distance_Model :: proc(state: rawptr, model: int) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Audio_Backend)state
	if model < 0 || model > 6 {
		return false
	}
	switch model {
	case 0: b.distance_model = .none
	case 1, 2: b.distance_model = .inverse
	case 3, 4: b.distance_model = .linear
	case 5, 6: b.distance_model = .exponential
	}
	for source in b.sources {
		if source.sound_ready {
			ma.sound_set_attenuation_model(&source.sound, b.distance_model)
		}
	}
	return true
}

Set_Doppler :: proc(state: rawptr, handle: u64, kind: int, factor: f32) -> bool {
	if source, ok := find_source(cast(^Audio_Backend)state, handle, kind); ok && source.sound_ready {
		ma.sound_set_doppler_factor(&source.sound, max(0, factor))
		return true
	}
	return false
}

Set_Doppler_All :: proc(state: rawptr, factor: f32) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Audio_Backend)state
	if !b.initialized {
		return false
	}
	b.doppler_scale = max(0, factor)
	for source in b.sources {
		if source.sound_ready {
			ma.sound_set_doppler_factor(&source.sound, b.doppler_scale)
		}
	}
	return true
}

Queue :: proc(state: rawptr, handle: u64, samples: []f32, channels: int) -> bool {
	if state == nil || len(samples) == 0 || channels <= 0 || len(samples)%channels != 0 {
		return false
	}
	source, ok := find_source(cast(^Audio_Backend)state, handle, 0)
	if !ok || source.kind != 0 {
		// Queue sources use the same native audio buffer primitive but carry a
		// distinct public handle kind in the API layer.
		source, ok = find_source(cast(^Audio_Backend)state, handle, 2)
	}
	if !ok {
		return false
	}
	chunk := Queue_Chunk{Channels = channels}
	chunk.Samples = make([dynamic]f32, len(samples))
	copy(chunk.Samples[:], samples)
	append(&source.queue, chunk)
	return true
}

Set_Listener :: proc(state: rawptr, position, direction, velocity: [3]f32) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Audio_Backend)state
	b.listener_position = position
	b.listener_velocity = velocity
	b.listener_direction = direction
	ma.engine_listener_set_position(&b.engine, 0, position[0], position[1], position[2])
	ma.engine_listener_set_direction(&b.engine, 0, direction[0], direction[1], direction[2])
	ma.engine_listener_set_velocity(&b.engine, 0, velocity[0], velocity[1], velocity[2])
	return true
}

// Set_Orientation stores the listener forward/up vectors (v0.10 wave 4: LOVE
// getOrientation/setOrientation parity) and pushes them to the engine.
Set_Orientation :: proc(state: rawptr, forward, up: [3]f32) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Audio_Backend)state
	b.listener_direction = forward
	b.listener_up = up
	ma.engine_listener_set_direction(&b.engine, 0, forward[0], forward[1], forward[2])
	ma.engine_listener_set_world_up(&b.engine, 0, up[0], up[1], up[2])
	return true
}

Get_Orientation :: proc(state: rawptr) -> (forward, up: [3]f32, ok: bool) {
	if state == nil {
		return [3]f32{}, [3]f32{}, false
	}
	b := cast(^Audio_Backend)state
	return b.listener_direction, b.listener_up, true
}

Get_Doppler_Scale :: proc(state: rawptr) -> (f32, bool) {
	if state == nil {
		return 0, false
	}
	return (cast(^Audio_Backend)state).doppler_scale, true
}

Start_Capture :: proc(state: rawptr, channels := 2, sample_rate := 48000) -> bool {
	if state == nil || channels <= 0 || sample_rate <= 0 {
		return false
	}
	b := cast(^Audio_Backend)state
	if b.capture != nil {
		return true
	}
	capture := new(Capture_Entry)
	capture.channels = channels
	capture.sample_rate = sample_rate
	if !result_ok(ma.pcm_rb_init(.f32, u32(channels), u32(sample_rate*4), nil, nil, &capture.ring)) {
		free(capture)
		return false
	}
	config := ma.device_config_init(.capture)
	config.sampleRate = u32(sample_rate)
	config.periodSizeInMilliseconds = 20
	config.capture.format = .f32
	config.capture.channels = u32(channels)
	config.dataCallback = capture_callback
	config.pUserData = capture
	if !result_ok(ma.device_init(nil, &config, &capture.device)) {
		ma.pcm_rb_uninit(&capture.ring)
		free(capture)
		return false
	}
	if !result_ok(ma.device_start(&capture.device)) {
		ma.device_uninit(&capture.device)
		ma.pcm_rb_uninit(&capture.ring)
		free(capture)
		return false
	}
	capture.ready = true
	b.capture = capture
	return true
}

Read_Capture :: proc(state: rawptr, max_frames: int) -> (samples: [dynamic]f32, channels, sample_rate, frames: int, ok: bool) {
	if state == nil || max_frames <= 0 {
		return nil, 0, 0, 0, false
	}
	b := cast(^Audio_Backend)state
	capture := b.capture
	if capture == nil || !capture.ready {
		return nil, 0, 0, 0, false
	}
	frames_to_read := min(u32(max_frames), ma.pcm_rb_available_read(&capture.ring))
	if frames_to_read == 0 {
		return make([dynamic]f32, 0), capture.channels, capture.sample_rate, 0, true
	}
	read_frames := frames_to_read
	buffer: rawptr
	if !result_ok(ma.pcm_rb_acquire_read(&capture.ring, &read_frames, &buffer)) || buffer == nil {
		return nil, 0, 0, 0, false
	}
	samples = make([dynamic]f32, int(read_frames)*capture.channels)
	copy(samples[:], ([^]f32)(buffer)[:len(samples)])
	ma.pcm_rb_commit_read(&capture.ring, read_frames)
	return samples, capture.channels, capture.sample_rate, int(read_frames), true
}

Stop_Capture :: proc(state: rawptr) {
	if state == nil {
		return
	}
	b := cast(^Audio_Backend)state
	if b.capture == nil {
		return
	}
	capture := b.capture
	capture.ready = false
	ma.device_stop(&capture.device)
	ma.device_uninit(&capture.device)
	ma.pcm_rb_uninit(&capture.ring)
	free(capture)
	b.capture = nil
}

Update :: proc(state: rawptr) {
	if state == nil {
		return
	}
	b := cast(^Audio_Backend)state
	for source in b.sources {
		if source.kind != 2 || len(source.queue) == 0 || !source.buffer_ready {
			continue
		}
		if ma.audio_buffer_at_end(&source.buffer) {
			if source.queue_index < len(source.queue) {
				chunk := &source.queue[source.queue_index]
				source.queue_index += 1
				ma.audio_buffer_ref_set_data(&source.buffer.ref, rawptr(&chunk.Samples[0]), u64(len(chunk.Samples)/chunk.Channels))
				ma.sound_start(&source.sound)
			} else {
				source.queue_index = 0
				clear(&source.queue)
			}
		}
	}
}

Create_Bus :: proc(state: rawptr) -> (u64, bool) {
	if state == nil {
		return 0, false
	}
	b := cast(^Audio_Backend)state
	bus := new(Bus_Entry)
	bus.handle = b.next_handle
	b.next_handle += 1
	if !result_ok(ma.sound_group_init(&b.engine, {}, nil, &bus.group)) {
		free(bus)
		return 0, false
	}
	append(&b.buses, bus)
	return bus.handle, true
}

Set_Bus_Volume :: proc(state: rawptr, handle: u64, volume: f32) -> bool {
	if bus, ok := find_bus(cast(^Audio_Backend)state, handle); ok {
		ma.sound_group_set_volume(&bus.group, max(0, volume))
		return true
	}
	return false
}

Attach_Bus :: proc(state: rawptr, source_handle, bus_handle: u64, kind: int) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Audio_Backend)state
	source, source_ok := find_source(b, source_handle, kind)
	bus, bus_ok := find_bus(b, bus_handle)
	if !source_ok || !bus_ok || !source.sound_ready {
		return false
	}
	source_node := cast(^ma.node)&source.sound.engineNode.baseNode
	bus_node := cast(^ma.node)&bus.group.engineNode.baseNode
	if !result_ok(ma.node_detach_all_output_buses(source_node)) {
		return false
	}
	ok := result_ok(ma.node_attach_output_bus(source_node, 0, bus_node, 0))
	if ok {
		source.bus_handle = bus.handle
		source.effect_handle = 0
	}
	return ok
}

Create_Effect :: proc(state: rawptr, kind: int, cutoff: f32) -> (u64, bool) {
	if state == nil {
		return 0, false
	}
	b := cast(^Audio_Backend)state
	effect := new(Effect_Entry)
	effect.handle = b.next_handle
	effect.kind = kind
	b.next_handle += 1
	graph := ma.engine_get_node_graph(&b.engine)
	init_result: ma.result
	switch kind {
	case 0:
		init_result = ma.sound_group_init(&b.engine, {}, nil, &effect.volume_group)
	case 2:
		config := ma.lpf_node_config_init(2, ma.engine_get_sample_rate(&b.engine), f64(max(cutoff, 20)), 2)
		init_result = ma.lpf_node_init(graph, &config, nil, &effect.lpf)
	case 3:
		config := ma.hpf_node_config_init(2, ma.engine_get_sample_rate(&b.engine), f64(max(cutoff, 20)), 2)
		init_result = ma.hpf_node_init(graph, &config, nil, &effect.hpf)
	case 4:
		config := ma.bpf_node_config_init(2, ma.engine_get_sample_rate(&b.engine), f64(max(cutoff, 20)), 2)
		init_result = ma.bpf_node_init(graph, &config, nil, &effect.bpf)
	case 1:
		config := ma.delay_node_config_init(2, ma.engine_get_sample_rate(&b.engine), u32(max(cutoff, 1)), 0.35)
		init_result = ma.delay_node_init(graph, &config, nil, &effect.delay)
	case 5:
		// miniaudio does not ship a reverb node. A feedback delay is a useful,
		// deterministic small-room approximation and keeps the API honest about
		// the implementation instead of silently dropping the effect.
		config := ma.delay_node_config_init(2, ma.engine_get_sample_rate(&b.engine), u32(max(cutoff, 80)), 0.55)
		init_result = ma.delay_node_init(graph, &config, nil, &effect.delay)
	case:
		free(effect)
		return 0, false
	}
	if !result_ok(init_result) {
		free(effect)
		return 0, false
	}
	effect.initialized = true
	append(&b.effects, effect)
	return effect.handle, true
}

Attach_Effect :: proc(state: rawptr, source_handle, effect_handle: u64, kind: int) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Audio_Backend)state
	source, source_ok := find_source(b, source_handle, kind)
	effect, effect_ok := find_effect(b, effect_handle)
	if !source_ok || !effect_ok || !source.sound_ready || !effect.initialized {
		return false
	}
	node: ^ma.node = nil
	switch effect.kind {
	case 0:
		node = cast(^ma.node)&effect.volume_group.engineNode.baseNode
	case 1:
		node = cast(^ma.node)&effect.delay.baseNode
	case 5:
		node = cast(^ma.node)&effect.delay.baseNode
	case 2:
		node = cast(^ma.node)&effect.lpf.baseNode
	case 3:
		node = cast(^ma.node)&effect.hpf.baseNode
	case 4:
		node = cast(^ma.node)&effect.bpf.baseNode
	case:
		return false
	}
	ok := result_ok(ma.node_detach_all_output_buses(cast(^ma.node)&source.sound.engineNode.baseNode)) &&
		result_ok(ma.node_attach_output_bus(cast(^ma.node)&source.sound.engineNode.baseNode, 0, node, 0)) &&
		result_ok(ma.node_attach_output_bus(node, 0, ma.engine_get_endpoint(&b.engine), 0))
	if ok {
		source.effect_handle = effect.handle
		source.bus_handle = 0
	}
	return ok
}

Set_Effect_Volume :: proc(state: rawptr, handle: u64, volume: f32) -> bool {
	if state == nil {
		return false
	}
	effect, found := find_effect(cast(^Audio_Backend)state, handle)
	if !found || !effect.initialized || effect.kind != 0 {
		return false
	}
	ma.sound_group_set_volume(&effect.volume_group, max(0, volume))
	return true
}

Detach_Effect :: proc(state: rawptr, source_handle, effect_handle: u64, kind: int) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Audio_Backend)state
	source, source_ok := find_source(b, source_handle, kind)
	effect, effect_ok := find_effect(b, effect_handle)
	if !source_ok || !effect_ok || !source.sound_ready || !effect.initialized {
		return false
	}
	ma.node_detach_all_output_buses(cast(^ma.node)&source.sound.engineNode.baseNode)
	ok := result_ok(ma.node_attach_output_bus(cast(^ma.node)&source.sound.engineNode.baseNode, 0, ma.engine_get_endpoint(&b.engine), 0))
	if ok {
		source.effect_handle = 0
	}
	return ok
}

Destroy_Bus :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	b := cast(^Audio_Backend)state
	for index := 0; index < len(b.buses); index += 1 {
		bus := b.buses[index]
		if bus.handle != handle {
			continue
		}
		for source in b.sources {
			if source.bus_handle == handle && source.sound_ready {
				source_node := cast(^ma.node)&source.sound.engineNode.baseNode
				ma.node_detach_all_output_buses(source_node)
				ma.node_attach_output_bus(source_node, 0, ma.engine_get_endpoint(&b.engine), 0)
				source.bus_handle = 0
			}
		}
		ma.sound_group_uninit(&bus.group)
		free(bus)
		unordered_remove(&b.buses, index)
		return
	}
}

Destroy_Effect :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	b := cast(^Audio_Backend)state
	for index := 0; index < len(b.effects); index += 1 {
		effect := b.effects[index]
		if effect.handle != handle {
			continue
		}
		for source in b.sources {
			if source.effect_handle == handle && source.sound_ready {
				source_node := cast(^ma.node)&source.sound.engineNode.baseNode
				ma.node_detach_all_output_buses(source_node)
				ma.node_attach_output_bus(source_node, 0, ma.engine_get_endpoint(&b.engine), 0)
				source.effect_handle = 0
			}
		}
		switch effect.kind {
		case 0: ma.sound_group_uninit(&effect.volume_group)
		case 1, 5: ma.delay_node_uninit(&effect.delay, nil)
		case 2: ma.lpf_node_uninit(&effect.lpf, nil)
		case 3: ma.hpf_node_uninit(&effect.hpf, nil)
		case 4: ma.bpf_node_uninit(&effect.bpf, nil)
		}
		free(effect)
		unordered_remove(&b.effects, index)
		return
	}
}

Destroy_Source :: proc(state: rawptr, handle: u64, kind: int) {
	if state == nil {
		return
	}
	b := cast(^Audio_Backend)state
	for i := 0; i < len(b.sources); i += 1 {
		source := b.sources[i]
		if source.handle != handle || source.kind != kind {
			continue
		}
		if source.sound_ready {
			ma.sound_stop(&source.sound)
			ma.sound_uninit(&source.sound)
		}
		if source.decoder_ready {
			ma.decoder_uninit(&source.decoder)
		}
		if source.buffer_ready {
			ma.audio_buffer_uninit(&source.buffer)
		}
		for chunk in source.queue {
			delete(chunk.Samples)
		}
		delete(source.queue)
		delete(source.data)
		delete(source.samples)
		free(source)
		for cache_index := 0; cache_index < len(b.sound_cache); cache_index += 1 {
			if b.sound_cache[cache_index].handle == handle {
				delete(b.sound_cache[cache_index].path)
				unordered_remove(&b.sound_cache, cache_index)
				break
			}
		}
		unordered_remove(&b.sources, i)
		return
	}
}

Destroy :: proc(state: rawptr) {
	if state == nil {
		return
	}
	b := cast(^Audio_Backend)state
	if b.capture != nil {
		Stop_Capture(state)
	}
	for source in b.sources {
		if source.sound_ready {
			ma.sound_stop(&source.sound)
			ma.sound_uninit(&source.sound)
		}
		if source.decoder_ready {
			ma.decoder_uninit(&source.decoder)
		}
		if source.buffer_ready {
			ma.audio_buffer_uninit(&source.buffer)
		}
		for chunk in source.queue {
			delete(chunk.Samples)
		}
		delete(source.queue)
		delete(source.data)
		delete(source.samples)
		free(source)
	}
	for effect in b.effects {
		switch effect.kind {
		case 0: ma.sound_group_uninit(&effect.volume_group)
		case 1: ma.delay_node_uninit(&effect.delay, nil)
		case 5: ma.delay_node_uninit(&effect.delay, nil)
		case 2: ma.lpf_node_uninit(&effect.lpf, nil)
		case 3: ma.hpf_node_uninit(&effect.hpf, nil)
		case 4: ma.bpf_node_uninit(&effect.bpf, nil)
		}
		free(effect)
	}
	for bus in b.buses {
		ma.sound_group_uninit(&bus.group)
		free(bus)
	}
	for entry in b.sound_cache {
		delete(entry.path)
	}
	delete(b.sources)
	delete(b.effects)
	delete(b.buses)
	delete(b.sound_cache)
	if b.initialized {
		ma.engine_uninit(&b.engine)
	}
	free(b)
}

Available :: proc(state: rawptr) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Audio_Backend)state
	return b != nil && b.initialized
}

Supports_Effects :: proc(state: rawptr) -> bool {
	// miniaudio supplies delay, room-delay (reverb approximation), and the three
	// filter nodes. Unsupported effect kinds still return a capability error.
	return Available(state)
}

Active_Source_Count :: proc(state: rawptr) -> int {
	if !Available(state) {
		return 0
	}
	return len((cast(^Audio_Backend)state).sources)
}

Supports_Spatial :: proc(state: rawptr) -> bool {
	return Available(state)
}

Supports_Capture :: proc(state: rawptr) -> bool {
	devices, ok := Enumerate_Devices(state)
	if !ok {
		return false
	}
	defer Destroy_Device_Infos(&devices)
	for device in devices {
		if device.Capture {
			return true
		}
	}
	return false
}

Supports_Decoder :: proc(state: rawptr) -> bool {
	return Available(state)
}
