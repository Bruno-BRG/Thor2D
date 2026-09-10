package thor2d

import backend "thor2d:thor2d/internal/raylib"
import audio "thor2d:thor2d/internal/audio"

Create_Sprite_Batch :: proc(ctx: ^Context, texture: Texture, capacity: int) -> (Sprite_Batch, Error) {
	if ctx == nil || ctx.backend == nil || texture.handle == 0 || capacity <= 0 {
		return Sprite_Batch{}, .Invalid_Config
	}
	handle, ok := backend.Create_Sprite_Batch(ctx.backend, texture.handle, capacity)
	if !ok {
		return Sprite_Batch{}, .Invalid_Handle
	}
	return Sprite_Batch{handle}, .None
}

Clear_Sprite_Batch :: proc(ctx: ^Context, batch: Sprite_Batch) {
	if ctx != nil && ctx.backend != nil && batch.handle != 0 {
		backend.Clear_Sprite_Batch(ctx.backend, batch.handle)
	}
}

Add_Sprite :: proc(ctx: ^Context, batch: Sprite_Batch, source, destination: Rect, origin: Vec2, rotation: f32, tint := White) {
	if ctx != nil && ctx.backend != nil && batch.handle != 0 {
		backend.Add_Sprite(ctx.backend, batch.handle, source.X, source.Y, source.W, source.H, destination.X, destination.Y, destination.W, destination.H, origin.X, origin.Y, rotation, tint.R, tint.G, tint.B, tint.A)
	}
}

Draw_Sprite_Batch :: proc(ctx: ^Context, batch: Sprite_Batch) {
	if ctx != nil && ctx.backend != nil && batch.handle != 0 {
		backend.Draw_Sprite_Batch(ctx.backend, batch.handle)
	}
}

Unload_Sprite_Batch :: proc(ctx: ^Context, batch: Sprite_Batch) {
	if ctx != nil && ctx.backend != nil && batch.handle != 0 {
		backend.Unload_Sprite_Batch(ctx.backend, batch.handle)
	}
}

// --- v0.10 SpriteBatch completion (LOVE SpriteBatch:set / setColor /
// setDrawRange / getCount subset). Indices are 0-based in add order; LOVE
// sprite ids are 1-based, so subtract 1 when porting. Array-texture layers
// (addLayer/setLayer), attachAttribute and setTexture are out of scope: the
// backend has no array-texture support. Getters return zero values on bad
// handles; setters report Error (unlike void Add_Sprite, an out-of-range
// index must be loud, never a silent no-op).

// Sprite_Batch_Set mirrors LOVE SpriteBatch:set (plain-sprite variant):
// replaces the sprite at index. Argument order mirrors Add_Sprite.
Sprite_Batch_Set :: proc(ctx: ^Context, batch: Sprite_Batch, index: int, source, destination: Rect, origin: Vec2, rotation: f32, tint := White) -> Error {
	if ctx == nil || ctx.backend == nil || batch.handle == 0 {
		return .Invalid_Handle
	}
	if index < 0 {
		return .Invalid_Data
	}
	if !backend.Sprite_Batch_Set(ctx.backend, batch.handle, index, source.X, source.Y, source.W, source.H, destination.X, destination.Y, destination.W, destination.H, origin.X, origin.Y, rotation, tint.R, tint.G, tint.B, tint.A) {
		return .Invalid_Data
	}
	return .None
}

// Sprite_Batch_Set_Color recolors one slot (per-sprite color via set).
Sprite_Batch_Set_Color :: proc(ctx: ^Context, batch: Sprite_Batch, index: int, color: Color) -> Error {
	if ctx == nil || ctx.backend == nil || batch.handle == 0 {
		return .Invalid_Handle
	}
	if index < 0 {
		return .Invalid_Data
	}
	if !backend.Sprite_Batch_Set_Color(ctx.backend, batch.handle, index, color.R, color.G, color.B, color.A) {
		return .Invalid_Data
	}
	return .None
}

// Sprite_Batch_Count mirrors LOVE SpriteBatch:getCount. Zero on bad handles.
Sprite_Batch_Count :: proc(ctx: ^Context, batch: Sprite_Batch) -> int {
	if ctx == nil || ctx.backend == nil || batch.handle == 0 {
		return 0
	}
	return backend.Sprite_Batch_Count(ctx.backend, batch.handle)
}

// Sprite_Batch_Set_Draw_Range mirrors LOVE SpriteBatch:setDrawRange:
// restricts drawing to [start, start + count). count < 0 draws everything
// from start (the default; reset with (0, -1)). Nil ctx, missing batch and
// negative start report errors; out-of-range ends clamp at draw.
Sprite_Batch_Set_Draw_Range :: proc(ctx: ^Context, batch: Sprite_Batch, start, count: int) -> Error {
	if ctx == nil || ctx.backend == nil || batch.handle == 0 {
		return .Invalid_Handle
	}
	if !backend.Sprite_Batch_Set_Draw_Range(ctx.backend, batch.handle, start, count) {
		return .Invalid_Data
	}
	return .None
}

// Sprite_Batch_Draw_Range returns the stored range (start, count with -1
// meaning "to the end"). (0, 0) on bad handles — count 0 is not settable,
// so it unambiguously signals a missing batch.
Sprite_Batch_Draw_Range :: proc(ctx: ^Context, batch: Sprite_Batch) -> (start, count: int) {
	if ctx == nil || ctx.backend == nil || batch.handle == 0 {
		return 0, 0
	}
	return backend.Sprite_Batch_Draw_Range(ctx.backend, batch.handle)
}

Create_Particles :: proc(ctx: ^Context, texture: Texture, config: Particle_Config) -> (Particle_System, Error) {
	if ctx == nil || config.Max_Particles <= 0 {
		return Particle_System{}, .Invalid_Config
	}
	if ctx.backend != nil {
		handle, ok := backend.Create_Particles(
			ctx.backend,
			texture.handle,
			config.Max_Particles,
			config.Lifetime_Min,
			config.Lifetime_Max,
			config.Emission_Rate,
			config.Gravity.X,
			config.Gravity.Y,
			config.Start_Size,
			config.End_Size,
			config.Start_Color.R,
			config.Start_Color.G,
			config.Start_Color.B,
			config.Start_Color.A,
			config.End_Color.R,
			config.End_Color.G,
			config.End_Color.B,
			config.End_Color.A,
		)
		if !ok {
			return Particle_System{}, .Invalid_Handle
		}
		return Particle_System{handle}, .None
	}
	// Headless (no window/GPU): run the pure-CPU sim in a windowless backend
	// state owned by this package. Textures need a GPU backend, so only
	// textureless systems exist headless — never a fake handle.
	if texture.handle != 0 {
		return Particle_System{}, .Invalid_Handle
	}
	state := backend.Particle_Create_Headless_State()
	handle, ok := backend.Create_Particles(
		state,
		0,
		config.Max_Particles,
		config.Lifetime_Min,
		config.Lifetime_Max,
		config.Emission_Rate,
		config.Gravity.X,
		config.Gravity.Y,
		config.Start_Size,
		config.End_Size,
		config.Start_Color.R,
		config.Start_Color.G,
		config.Start_Color.B,
		config.Start_Color.A,
		config.End_Color.R,
		config.End_Color.G,
		config.End_Color.B,
		config.End_Color.A,
	)
	if !ok {
		backend.Particle_Destroy_Headless_State(state)
		return Particle_System{}, .Invalid_Handle
	}
	if headless_particle_next == 0 {
		headless_particle_next = 1
	}
	id := headless_particle_next
	headless_particle_next += 1
	if !headless_particle_slot_insert(id, state, handle) {
		backend.Particle_Destroy_Headless_State(state)
		return Particle_System{}, .Invalid_Handle
	}
	return Particle_System{id}, .None
}

Emit_Particles :: proc(ctx: ^Context, particles: Particle_System, count: int) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Emit_Particles(state, local, count)
	}
}

Update_Particles :: proc(ctx: ^Context, particles: Particle_System, delta: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Update_Particles(state, local, delta)
	}
}

Draw_Particles :: proc(ctx: ^Context, particles: Particle_System, position: Vec2, tint := White) {
	// Headless draw is a no-op (no window/GPU); windowed draws via backend.
	if ctx != nil && ctx.backend != nil && particles.handle != 0 {
		backend.Draw_Particles(ctx.backend, particles.handle, position.X, position.Y, tint.R, tint.G, tint.B, tint.A)
	}
}

Clear_Particles :: proc(ctx: ^Context, particles: Particle_System) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Clear_Particles(state, local)
	}
}

Unload_Particles :: proc(ctx: ^Context, particles: Particle_System) {
	if ctx == nil || particles.handle == 0 {
		return
	}
	if ctx.backend != nil {
		backend.Unload_Particles(ctx.backend, particles.handle)
		return
	}
	// Headless: destroy the owned windowless state. Headless systems must be
	// unloaded explicitly; Context.Destroy cannot reach this package store.
	if slot, ok := headless_particle_slot_find(particles.handle); ok {
		backend.Particle_Destroy_Headless_State(slot.state)
		headless_particle_slot_remove(particles.handle)
	}
}

// v0.10 ParticleSystem tuning API (LOVE graphics.ParticleSystem parity).
// All angles are radians and spin is radians/second (LOVE units); sizes are
// absolute pixels. Every setter is headless-safe and a no-op on an invalid
// handle; getters return stored values (zero on invalid handles). Only
// Clone_Particles and Replace_Particle_Texture are fallible ((T, Error)).
// Main-thread only, like all Context use.

Headless_Particle_Slot :: struct {
	id: u64, // public handle; 0 marks a tombstone
	state: rawptr,
	local: u64,
}

// Windowless sim states for headless particle systems. A static slot table
// (not heap storage): headless systems are few and short-lived (tests,
// headless servers), and static storage keeps system lookup deterministic
// with zero allocation churn. Windowed systems live in ctx.backend and never
// touch this store. Main-thread only, like all Context use.
//
// Headless slots are exhausted at HEADLESS_PARTICLE_MAX_SLOTS concurrent
// systems; Create_Particles then reports .Invalid_Handle (never a fake).
HEADLESS_PARTICLE_MAX_SLOTS :: 256

headless_particle_slots: [HEADLESS_PARTICLE_MAX_SLOTS]Headless_Particle_Slot
headless_particle_next: u64

headless_particle_slot_find :: proc(id: u64) -> (Headless_Particle_Slot, bool) {
	if id == 0 {
		return {}, false
	}
	for slot in headless_particle_slots {
		if slot.id == id {
			return slot, true
		}
	}
	return {}, false
}

// Returns false when the table is full.
headless_particle_slot_insert :: proc(id: u64, state: rawptr, local: u64) -> bool {
	for &slot in headless_particle_slots {
		if slot.id == 0 {
			slot = Headless_Particle_Slot{id = id, state = state, local = local}
			return true
		}
	}
	return false
}

headless_particle_slot_remove :: proc(id: u64) {
	for &slot in headless_particle_slots {
		if slot.id == id {
			slot = {}
			return
		}
	}
}

particle_resolve :: proc(ctx: ^Context, particles: Particle_System) -> (rawptr, u64, bool) {
	if ctx == nil || particles.handle == 0 {
		return nil, 0, false
	}
	if ctx.backend != nil {
		return ctx.backend, particles.handle, true
	}
	slot, ok := headless_particle_slot_find(particles.handle)
	if !ok || slot.state == nil {
		return nil, 0, false
	}
	return slot.state, slot.local, true
}

// --- Emission ---

Set_Particle_Emission_Rate :: proc(ctx: ^Context, particles: Particle_System, rate: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Emission_Rate(state, local, rate)
	}
}

Get_Particle_Emission_Rate :: proc(ctx: ^Context, particles: Particle_System) -> f32 {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Emission_Rate(state, local)
	}
	return 0
}

// Emitter budget in seconds; 0 means infinite emission (LOVE uses -1 for
// infinite; Thor2D uses 0 so the zero value is the common case). When the
// budget expires the system auto-stops (live particles keep simulating).
Set_Particle_Emitter_Lifetime :: proc(ctx: ^Context, particles: Particle_System, lifetime: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Emitter_Lifetime(state, local, lifetime)
	}
}

Get_Particle_Emitter_Lifetime :: proc(ctx: ^Context, particles: Particle_System) -> f32 {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Emitter_Lifetime(state, local)
	}
	return 0
}

Set_Particle_Lifetime :: proc(ctx: ^Context, particles: Particle_System, min, max: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Lifetime(state, local, min, max)
	}
}

Get_Particle_Lifetime :: proc(ctx: ^Context, particles: Particle_System) -> (min, max: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Lifetime(state, local)
	}
	return 0, 0
}

// --- Motion ---

Set_Particle_Direction :: proc(ctx: ^Context, particles: Particle_System, direction: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Direction(state, local, direction)
	}
}

Get_Particle_Direction :: proc(ctx: ^Context, particles: Particle_System) -> f32 {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Direction(state, local)
	}
	return 0
}

Set_Particle_Spread :: proc(ctx: ^Context, particles: Particle_System, spread: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Spread(state, local, spread)
	}
}

Get_Particle_Spread :: proc(ctx: ^Context, particles: Particle_System) -> f32 {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Spread(state, local)
	}
	return 0
}

Set_Particle_Speed :: proc(ctx: ^Context, particles: Particle_System, min, max: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Speed(state, local, min, max)
	}
}

Get_Particle_Speed :: proc(ctx: ^Context, particles: Particle_System) -> (min, max: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Speed(state, local)
	}
	return 0, 0
}

Set_Particle_Linear_Acceleration :: proc(ctx: ^Context, particles: Particle_System, min, max: Vec2) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Linear_Acceleration(state, local, min.X, min.Y, max.X, max.Y)
	}
}

Get_Particle_Linear_Acceleration :: proc(ctx: ^Context, particles: Particle_System) -> (min, max: Vec2) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		min_x, min_y, max_x, max_y := backend.Particle_Linear_Acceleration(state, local)
		return Vec2{min_x, min_y}, Vec2{max_x, max_y}
	}
	return Vec2{}, Vec2{}
}

Set_Particle_Radial_Acceleration :: proc(ctx: ^Context, particles: Particle_System, min, max: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Radial_Acceleration(state, local, min, max)
	}
}

Get_Particle_Radial_Acceleration :: proc(ctx: ^Context, particles: Particle_System) -> (min, max: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Radial_Acceleration(state, local)
	}
	return 0, 0
}

Set_Particle_Tangential_Acceleration :: proc(ctx: ^Context, particles: Particle_System, min, max: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Tangential_Acceleration(state, local, min, max)
	}
}

Get_Particle_Tangential_Acceleration :: proc(ctx: ^Context, particles: Particle_System) -> (min, max: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Tangential_Acceleration(state, local)
	}
	return 0, 0
}

Set_Particle_Damping :: proc(ctx: ^Context, particles: Particle_System, min, max: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Damping(state, local, min, max)
	}
}

Get_Particle_Damping :: proc(ctx: ^Context, particles: Particle_System) -> (min, max: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Damping(state, local)
	}
	return 0, 0
}

Set_Particle_Gravity :: proc(ctx: ^Context, particles: Particle_System, gravity: Vec2) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Gravity(state, local, gravity.X, gravity.Y)
	}
}

Get_Particle_Gravity :: proc(ctx: ^Context, particles: Particle_System) -> Vec2 {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		x, y := backend.Particle_Gravity(state, local)
		return Vec2{x, y}
	}
	return Vec2{}
}

Set_Particle_Spin :: proc(ctx: ^Context, particles: Particle_System, min, max: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Spin(state, local, min, max)
	}
}

Get_Particle_Spin :: proc(ctx: ^Context, particles: Particle_System) -> (min, max: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Spin(state, local)
	}
	return 0, 0
}

// --- Appearance ---

// Size track (LOVE setSizes, max 8 stops); the system interpolates evenly
// across stops over each particle's lifetime. Empty input is a no-op.
Set_Particle_Sizes :: proc(ctx: ^Context, particles: Particle_System, sizes: []f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Sizes(state, local, sizes)
	}
}

Get_Particle_Size_Count :: proc(ctx: ^Context, particles: Particle_System) -> int {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Size_Count(state, local)
	}
	return 0
}

// Color track (LOVE setColors, max 8 stops, u8 0-255 channels); empty input
// is a no-op.
Set_Particle_Colors :: proc(ctx: ^Context, particles: Particle_System, colors: []Color) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		if len(colors) > 0 {
			rgba: [32]u8
			count := len(colors) if len(colors) < 8 else 8
			for i := 0; i < count; i += 1 {
				rgba[i*4] = colors[i].R
				rgba[i*4+1] = colors[i].G
				rgba[i*4+2] = colors[i].B
				rgba[i*4+3] = colors[i].A
			}
			backend.Particle_Set_Colors(state, local, rgba[:count*4])
		}
	}
}

Get_Particle_Color_Count :: proc(ctx: ^Context, particles: Particle_System) -> int {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Color_Count(state, local)
	}
	return 0
}

// Single size/color convenience: reads/writes the track start value,
// preserving the remaining stops.
Set_Particle_Size :: proc(ctx: ^Context, particles: Particle_System, size: f32) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Size(state, local, size)
	}
}

Get_Particle_Size :: proc(ctx: ^Context, particles: Particle_System) -> f32 {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Size(state, local)
	}
	return 0
}

Set_Particle_Color :: proc(ctx: ^Context, particles: Particle_System, color: Color) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Set_Color(state, local, color.R, color.G, color.B, color.A)
	}
}

Get_Particle_Color :: proc(ctx: ^Context, particles: Particle_System) -> Color {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		r, g, b, a := backend.Particle_Color(state, local)
		return Color{r, g, b, a}
	}
	return Color{}
}

// Swaps the particle texture (LOVE setTexture). Texture{} selects the
// textureless circle renderer. A non-zero texture must exist in the active
// backend, so headless replaces with a real texture report .Invalid_Handle
// instead of a fake handle.
Replace_Particle_Texture :: proc(ctx: ^Context, particles: Particle_System, texture: Texture) -> Error {
	state, local, ok := particle_resolve(ctx, particles)
	if !ok {
		return .Invalid_Handle
	}
	if !backend.Particle_Set_Texture(state, local, texture.handle) {
		return .Invalid_Handle
	}
	return .None
}

// --- Lifecycle ---

// New systems start active (Thor2D CType behavior); call Stop_Particles
// after Create for LOVE's initially-stopped flow.
Start_Particles :: proc(ctx: ^Context, particles: Particle_System) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Start(state, local)
	}
}

Stop_Particles :: proc(ctx: ^Context, particles: Particle_System) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Stop(state, local)
	}
}

Pause_Particles :: proc(ctx: ^Context, particles: Particle_System) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Pause(state, local)
	}
}

// Clears all live particles and returns the system to the stopped state.
Reset_Particles :: proc(ctx: ^Context, particles: Particle_System) {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		backend.Particle_Reset(state, local)
	}
}

Is_Particles_Active :: proc(ctx: ^Context, particles: Particle_System) -> bool {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Is_Active(state, local)
	}
	return false
}

Is_Particles_Paused :: proc(ctx: ^Context, particles: Particle_System) -> bool {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Is_Paused(state, local)
	}
	return false
}

Is_Particles_Stopped :: proc(ctx: ^Context, particles: Particle_System) -> bool {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Is_Stopped(state, local)
	}
	return false
}

Is_Particles_Empty :: proc(ctx: ^Context, particles: Particle_System) -> bool {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Is_Empty(state, local)
	}
	return true
}

Get_Particle_Count :: proc(ctx: ^Context, particles: Particle_System) -> int {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Count(state, local)
	}
	return 0
}

Get_Particle_Max :: proc(ctx: ^Context, particles: Particle_System) -> int {
	if state, local, ok := particle_resolve(ctx, particles); ok {
		return backend.Particle_Max(state, local)
	}
	return 0
}

// Deep copy of all tuning, tracks, texture and RNG seed. The clone starts
// stopped with zero live particles (LOVE clone semantics); live particles
// are not copied. Invalid handles report .Invalid_Handle, never a fake.
Clone_Particles :: proc(ctx: ^Context, particles: Particle_System) -> (Particle_System, Error) {
	if ctx == nil || particles.handle == 0 {
		return Particle_System{}, .Invalid_Handle
	}
	if ctx.backend != nil {
		handle, ok := backend.Particle_Clone_To(ctx.backend, ctx.backend, particles.handle)
		if !ok {
			return Particle_System{}, .Invalid_Handle
		}
		return Particle_System{handle}, .None
	}
	slot, ok := headless_particle_slot_find(particles.handle)
	if !ok || slot.state == nil {
		return Particle_System{}, .Invalid_Handle
	}
	dst := backend.Particle_Create_Headless_State()
	handle, clone_ok := backend.Particle_Clone_To(dst, slot.state, slot.local)
	if !clone_ok {
		backend.Particle_Destroy_Headless_State(dst)
		return Particle_System{}, .Invalid_Handle
	}
	if headless_particle_next == 0 {
		headless_particle_next = 1
	}
	id := headless_particle_next
	headless_particle_next += 1
	if !headless_particle_slot_insert(id, dst, handle) {
		backend.Particle_Destroy_Headless_State(dst)
		return Particle_System{}, .Invalid_Handle
	}
	return Particle_System{id}, .None
}

Load_Texture_Cached :: proc(ctx: ^Context, path: string) -> (Texture, Error) {
	if ctx == nil || ctx.backend == nil {
		return Texture{}, .Backend_Initialization_Failed
	}
	file, file_err := Read_Path(&ctx.filesystem, path)
	if file_err != .None {
		return Texture{}, file_err
	}
	defer Destroy_File_Data(&file)
	handle, _, ok := backend.Load_Texture_Cached_From_Memory(ctx.backend, path, file.Bytes[:])
	if !ok {
		return Texture{}, .Resource_Load_Failed
	}
	return Texture{handle}, .None
}

Load_Font_Cached :: proc(ctx: ^Context, path: string) -> (Font, Error) {
	if ctx == nil || ctx.backend == nil {
		return Font{}, .Backend_Initialization_Failed
	}
	file, file_err := Read_Path(&ctx.filesystem, path)
	if file_err != .None {
		return Font{}, file_err
	}
	defer Destroy_File_Data(&file)
	handle, _, ok := backend.Load_Font_Cached_From_Memory(ctx.backend, path, file.Bytes[:], 32)
	if !ok {
		return Font{}, .Resource_Load_Failed
	}
	return Font{handle}, .None
}

Load_Sound_Cached :: proc(ctx: ^Context, path: string) -> (Sound, Error) {
	if ctx == nil || ctx.audio_backend == nil {
		return Sound{}, .Backend_Initialization_Failed
	}
	file, file_err := Read_Path(&ctx.filesystem, path)
	if file_err != .None {
		return Sound{}, file_err
	}
	defer Destroy_File_Data(&file)
	handle, _, ok := audio.Load_Static_Cached(ctx.audio_backend, path, file.Bytes[:])
	if !ok {
		return Sound{}, .Resource_Load_Failed
	}
	return Sound{handle}, .None
}

Texture_Asset_ID :: proc(ctx: ^Context, texture: Texture) -> Asset_Id {
	if ctx == nil || ctx.backend == nil || texture.handle == 0 {
		return Asset_Id(0)
	}
	return Asset_Id(backend.Texture_Asset_ID(ctx.backend, texture.handle))
}

Font_Asset_ID :: proc(ctx: ^Context, font: Font) -> Asset_Id {
	if ctx == nil || ctx.backend == nil || font.handle == 0 {
		return Asset_Id(0)
	}
	return Asset_Id(backend.Font_Asset_ID(ctx.backend, font.handle))
}

Sound_Asset_ID :: proc(ctx: ^Context, sound: Sound) -> Asset_Id {
	if ctx == nil || ctx.audio_backend == nil || sound.handle == 0 {
		return Asset_Id(0)
	}
	return Asset_Id(audio.Sound_Asset_ID(ctx.audio_backend, sound.handle))
}
