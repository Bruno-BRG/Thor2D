package raylib_backend

import "core:strings"
import math "core:math"
import rl "vendor:raylib"

Create_Sprite_Batch :: proc(state: rawptr, texture_handle: u64, capacity: int) -> (u64, bool) {
	if state == nil || texture_handle == 0 || capacity <= 0 {
		return 0, false
	}
	b := cast(^Backend)state
	_, texture_ok := find_texture(b, texture_handle)
	if !texture_ok {
		return 0, false
	}
	handle := b.next_handle
	b.next_handle += 1
	append(&b.sprite_batches, Sprite_Batch_Entry{
		handle = handle,
		texture_handle = texture_handle,
		capacity = capacity,
		draw_start = 0,
		draw_count = -1,
	})
	return handle, true
}

find_sprite_batch :: proc(b: ^Backend, handle: u64) -> (^Sprite_Batch_Entry, bool) {
	for i := 0; i < len(b.sprite_batches); i += 1 {
		if b.sprite_batches[i].handle == handle {
			return &b.sprite_batches[i], true
		}
	}
	return nil, false
}

Clear_Sprite_Batch :: proc(state: rawptr, handle: u64) {
	if state != nil {
		if batch, ok := find_sprite_batch(cast(^Backend)state, handle); ok {
			clear(&batch.commands)
		}
	}
}

Add_Sprite :: proc(state: rawptr, handle: u64, sx, sy, sw, sh, dx, dy, dw, dh, ox, oy, rotation: f32, r, g, b, a: u8) -> bool {
	if state == nil {
		return false
	}
	backend := cast(^Backend)state
	batch, ok := find_sprite_batch(backend, handle)
	if !ok || len(batch.commands) >= batch.capacity {
		return false
	}
	append(&batch.commands, Sprite_Command{
		source = rl.Rectangle{sx, sy, sw, sh},
		destination = rl.Rectangle{dx, dy, dw, dh},
		origin = rl.Vector2{ox, oy},
		rotation = rotation,
		tint = rl.Color{r, g, b, a},
	})
	return true
}

Draw_Sprite_Batch :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	backend := cast(^Backend)state
	batch, ok := find_sprite_batch(backend, handle)
	if !ok {
		return
	}
	texture, texture_ok := find_texture(backend, batch.texture_handle)
	if !texture_ok {
		return
	}
	// v0.10 draw range (LOVE SpriteBatch:setDrawRange subset, 0-based).
	// Negative count draws everything from start; bounds clamp.
	lo := batch.draw_start if batch.draw_start > 0 else 0
	hi := len(batch.commands)
	if batch.draw_count >= 0 {
		hi = min(lo+batch.draw_count, len(batch.commands))
	}
	lo = min(lo, len(batch.commands))
	for i := lo; i < hi; i += 1 {
		command := batch.commands[i]
		position := transform_point(backend.transform, rl.Vector2{command.destination.x, command.destination.y})
		size := transform_size(backend.transform, rl.Vector2{command.destination.width, command.destination.height})
		origin := transform_size(backend.transform, command.origin)
		rl.DrawTexturePro(texture.value, command.source, rl.Rectangle{position.x, position.y, size.x, size.y}, origin, command.rotation + backend.transform.rotation, command.tint)
	}
}

Unload_Sprite_Batch :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	for i := 0; i < len(b.sprite_batches); i += 1 {
		if b.sprite_batches[i].handle == handle {
			delete(b.sprite_batches[i].commands)
			unordered_remove(&b.sprite_batches, i)
			return
		}
	}
}

// v0.10 SpriteBatch slot/range completion (LOVE SpriteBatch:set / setColor /
// setDrawRange / getCount subset). Indices are 0-based in add order; LOVE
// sprite ids are 1-based, so subtract 1 when porting. Array-texture layers,
// attachAttribute and setTexture are out of scope (no array-texture backend).

// Sprite_Batch_Set replaces the sprite at index (mirror of Add_Sprite args).
Sprite_Batch_Set :: proc(state: rawptr, handle: u64, index: int, sx, sy, sw, sh, dx, dy, dw, dh, ox, oy, rotation: f32, r, g, b, a: u8) -> bool {
	if state == nil || index < 0 {
		return false
	}
	batch, ok := find_sprite_batch(cast(^Backend)state, handle)
	if !ok || index >= len(batch.commands) {
		return false
	}
	batch.commands[index] = Sprite_Command{
		source = rl.Rectangle{sx, sy, sw, sh},
		destination = rl.Rectangle{dx, dy, dw, dh},
		origin = rl.Vector2{ox, oy},
		rotation = rotation,
		tint = rl.Color{r, g, b, a},
	}
	return true
}

// Sprite_Batch_Set_Color recolors one slot (per-sprite color via set).
Sprite_Batch_Set_Color :: proc(state: rawptr, handle: u64, index: int, r, g, b, a: u8) -> bool {
	if state == nil || index < 0 {
		return false
	}
	batch, ok := find_sprite_batch(cast(^Backend)state, handle)
	if !ok || index >= len(batch.commands) {
		return false
	}
	batch.commands[index].tint = rl.Color{r, g, b, a}
	return true
}

Sprite_Batch_Count :: proc(state: rawptr, handle: u64) -> int {
	if state == nil {
		return 0
	}
	batch, ok := find_sprite_batch(cast(^Backend)state, handle)
	if !ok {
		return 0
	}
	return len(batch.commands)
}

// Sprite_Batch_Set_Draw_Range restricts drawing to [start, start+count).
// count < 0 draws everything from start (the default). Out-of-range ends
// clamp at draw; a start beyond the end draws nothing.
Sprite_Batch_Set_Draw_Range :: proc(state: rawptr, handle: u64, start, count: int) -> bool {
	if state == nil || start < 0 || (count <= 0 && count != -1) {
		return false
	}
	batch, ok := find_sprite_batch(cast(^Backend)state, handle)
	if !ok {
		return false
	}
	batch.draw_start = start
	batch.draw_count = count
	return true
}

Sprite_Batch_Draw_Range :: proc(state: rawptr, handle: u64) -> (start, count: int) {
	if state == nil {
		return 0, 0
	}
	batch, ok := find_sprite_batch(cast(^Backend)state, handle)
	if !ok {
		return 0, 0
	}
	return batch.draw_start, batch.draw_count
}


Create_Particles :: proc(state: rawptr, texture_handle: u64, max_particles: int, lifetime_min, lifetime_max, emission_rate: f32, gravity_x, gravity_y: f32, start_size, end_size: f32, start_r, start_g, start_b, start_a, end_r, end_g, end_b, end_a: u8) -> (u64, bool) {
	if state == nil || max_particles <= 0 || lifetime_min < 0 || lifetime_max < lifetime_min {
		return 0, false
	}
	b := cast(^Backend)state
	if texture_handle != 0 {
		_, ok := find_texture(b, texture_handle)
		if !ok {
			return 0, false
		}
	}
	handle := b.next_handle
	b.next_handle += 1
	config := Particle_Config_Internal{
		max_particles = max_particles,
		lifetime_min = lifetime_min,
		lifetime_max = lifetime_max,
		emission_rate = emission_rate,
		gravity = rl.Vector2{gravity_x, gravity_y},
		start_size = start_size,
		end_size = end_size,
		start_color = rl.Color{start_r, start_g, start_b, start_a},
		end_color = rl.Color{end_r, end_g, end_b, end_a},
		// v0.10 defaults: full-circle spread and 20..100 speed reproduce the
		// legacy emit distribution; zero accels/damping; spin defaults to
		// -PI/2..PI/2 rad/s so angular velocity matches the legacy
		// -90..+90 deg/s range; infinite emitter budget; 2-stop tracks
		// snapshotted from start/end (legacy start->end lerp preserved).
		direction = 0,
		spread = 6.2831855,
		speed_min = 20,
		speed_max = 100,
		spin_min = -1.5707964,
		spin_max = 1.5707964,
		emitter_lifetime = 0,
	}
	entry := Particle_System_Entry{
		handle = handle,
		texture_handle = texture_handle,
		config = config,
		seed = 0x9E3779B9,
		active = true,
		sizes = {start_size, end_size, 0, 0, 0, 0, 0, 0},
		size_count = 2,
		colors = {rl.Color{start_r, start_g, start_b, start_a}, rl.Color{end_r, end_g, end_b, end_a}, {}, {}, {}, {}, {}, {}},
		color_count = 2,
	}
	append(&b.particles, entry)
	// Live count never exceeds max_particles (emit_one enforces the cap),
	// so one bounded reservation up front means the particle array never
	// reallocates during emission — no per-frame allocator churn in the
	// real-time path. OOM here reports failure instead of a fake handle.
	if reserve(&b.particles[len(b.particles)-1].particles, max_particles) != nil {
		pop(&b.particles)
		return 0, false
	}
	return handle, true
}

find_particles :: proc(b: ^Backend, handle: u64) -> (^Particle_System_Entry, bool) {
	for i := 0; i < len(b.particles); i += 1 {
		if b.particles[i].handle == handle {
			return &b.particles[i], true
		}
	}
	return nil, false
}

particle_random :: proc(seed: ^u32) -> f32 {
	seed^ = seed^ * 1664525 + 1013904223
	return f32(seed^ % 10000) / 10000
}

particle_lerp :: proc(a, b, amount: f32) -> f32 {
	return a + (b-a)*amount
}

particle_color :: proc(a, b: rl.Color, amount: f32) -> rl.Color {
	return rl.Color{
		u8(particle_lerp(f32(a.r), f32(b.r), amount)),
		u8(particle_lerp(f32(a.g), f32(b.g), amount)),
		u8(particle_lerp(f32(a.b), f32(b.b), amount)),
		u8(particle_lerp(f32(a.a), f32(b.a), amount)),
	}
}

particle_track_value :: proc(stops: ^[8]f32, count: int, fallback_a, fallback_b, age: f32) -> f32 {
	if count <= 0 {
		return particle_lerp(fallback_a, fallback_b, age)
	}
	if count == 1 {
		return stops[0]
	}
	clamped := age if age >= 0 else 0
	if clamped > 1 {
		clamped = 1
	}
	position := clamped * f32(count-1)
	index := int(position)
	if index >= count-1 {
		index = count-2
	}
	return particle_lerp(stops[index], stops[index+1], position - f32(index))
}

particle_track_color :: proc(stops: ^[8]rl.Color, count: int, fallback_a, fallback_b: rl.Color, age: f32) -> rl.Color {
	if count <= 0 {
		return particle_color(fallback_a, fallback_b, age)
	}
	if count == 1 {
		return stops[0]
	}
	clamped := age if age >= 0 else 0
	if clamped > 1 {
		clamped = 1
	}
	position := clamped * f32(count-1)
	index := int(position)
	if index >= count-1 {
		index = count-2
	}
	return particle_color(stops[index], stops[index+1], position - f32(index))
}

emit_one :: proc(system: ^Particle_System_Entry) {
	if len(system.particles) >= system.config.max_particles {
		return
	}
	life_range := system.config.lifetime_max - system.config.lifetime_min
	lifetime := system.config.lifetime_min + life_range*particle_random(&system.seed)
	if lifetime <= 0 {
		lifetime = 0.001
	}
	// LOVE emission cone: angle uniform in [direction - spread/2, direction + spread/2].
	angle := system.config.direction + (particle_random(&system.seed)-0.5)*system.config.spread
	speed_range := system.config.speed_max - system.config.speed_min
	speed := system.config.speed_min + speed_range*particle_random(&system.seed)
	linear := rl.Vector2{
		system.config.linear_accel_min.x + (system.config.linear_accel_max.x-system.config.linear_accel_min.x)*particle_random(&system.seed),
		system.config.linear_accel_min.y + (system.config.linear_accel_max.y-system.config.linear_accel_min.y)*particle_random(&system.seed),
	}
	radial := system.config.radial_min + (system.config.radial_max-system.config.radial_min)*particle_random(&system.seed)
	tangential := system.config.tangential_min + (system.config.tangential_max-system.config.tangential_min)*particle_random(&system.seed)
	damping := system.config.damping_min + (system.config.damping_max-system.config.damping_min)*particle_random(&system.seed)
	// Spin is stored in rad/s (LOVE units); Particle_State keeps deg/s.
	spin := system.config.spin_min + (system.config.spin_max-system.config.spin_min)*particle_random(&system.seed)
	append(&system.particles, Particle_State{
		velocity = rl.Vector2{math.cos(angle) * speed, math.sin(angle) * speed},
		life = lifetime,
		lifetime = lifetime,
		rotation = particle_random(&system.seed) * 360,
		angular_velocity = spin * 57.29578,
		scale = particle_track_value(&system.sizes, system.size_count, system.config.start_size, system.config.end_size, 0),
		linear_accel = linear,
		radial_accel = radial,
		tangential_accel = tangential,
		damping = damping,
	})
}

Emit_Particles :: proc(state: rawptr, handle: u64, count: int) {
	if state == nil || count <= 0 {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		for i := 0; i < count; i += 1 {
			emit_one(system)
		}
	}
}

Update_Particles :: proc(state: rawptr, handle: u64, delta: f32) {
	if state == nil || delta <= 0 {
		return
	}
	system, ok := find_particles(cast(^Backend)state, handle)
	if !ok {
		return
	}
	// Paused systems are fully frozen (LOVE pause semantics).
	if system.paused {
		return
	}
	if system.active {
		budget_ok := system.config.emitter_lifetime <= 0 || system.emitter_age < system.config.emitter_lifetime
		if budget_ok && system.config.emission_rate > 0 {
			system.emission_remainder += system.config.emission_rate * delta
			emit_count := int(system.emission_remainder)
			system.emission_remainder -= f32(emit_count)
			for i := 0; i < emit_count; i += 1 {
				emit_one(system)
			}
		}
		if system.config.emitter_lifetime > 0 {
			system.emitter_age += delta
			if system.emitter_age >= system.config.emitter_lifetime {
				system.active = false
			}
		}
	}
	for i := len(system.particles)-1; i >= 0; i -= 1 {
		particle := &system.particles[i]
		particle.life -= delta
		if particle.life <= 0 {
			unordered_remove(&system.particles, i)
			continue
		}
		accel_x := system.config.gravity.x + particle.linear_accel.x
		accel_y := system.config.gravity.y + particle.linear_accel.y
		// Radial (away from the emitter at local origin) and tangential
		// (perpendicular) accelerations use per-particle magnitudes.
		distance := math.sqrt(particle.position.x*particle.position.x + particle.position.y*particle.position.y)
		if distance > 0.000001 {
			normal_x := particle.position.x / distance
			normal_y := particle.position.y / distance
			accel_x += normal_x*particle.radial_accel - normal_y*particle.tangential_accel
			accel_y += normal_y*particle.radial_accel + normal_x*particle.tangential_accel
		}
		particle.velocity.x += accel_x * delta
		particle.velocity.y += accel_y * delta
		// Linear damping is a constant deceleration opposing motion
		// (LOVE "constant deceleration"), clamped so velocity never flips.
		if particle.damping > 0 {
			speed := math.sqrt(particle.velocity.x*particle.velocity.x + particle.velocity.y*particle.velocity.y)
			if speed > 0 {
				remaining := speed - particle.damping*delta
				if remaining < 0 {
					remaining = 0
				}
				scale := remaining / speed
				particle.velocity.x *= scale
				particle.velocity.y *= scale
			}
		}
		particle.position.x += particle.velocity.x * delta
		particle.position.y += particle.velocity.y * delta
		particle.rotation += particle.angular_velocity * delta
		age := 1 - particle.life/particle.lifetime
		particle.scale = particle_track_value(&system.sizes, system.size_count, system.config.start_size, system.config.end_size, age)
	}
}

Draw_Particles :: proc(state: rawptr, handle: u64, x, y: f32, r, g, b, a: u8) {
	if state == nil {
		return
	}
	backend := cast(^Backend)state
	system, ok := find_particles(backend, handle)
	if !ok {
		return
	}
	texture, has_texture := find_texture(backend, system.texture_handle)
	tint := rl.Color{r, g, b, a}
	for particle in system.particles {
		age := 1 - particle.life/particle.lifetime
		color := particle_track_color(&system.colors, system.color_count, system.config.start_color, system.config.end_color, age)
		color.r = u8((u16(color.r)*u16(tint.r))/255)
		color.g = u8((u16(color.g)*u16(tint.g))/255)
		color.b = u8((u16(color.b)*u16(tint.b))/255)
		color.a = u8((u16(color.a)*u16(tint.a))/255)
		position := transform_point(backend.transform, rl.Vector2{x + particle.position.x, y + particle.position.y})
		size := transform_scalar(backend.transform, particle.scale)
		if has_texture {
			width := size
			height := size
			if texture.value.width > 0 {
				height = size * f32(texture.value.height) / f32(texture.value.width)
			}
			rl.DrawTexturePro(texture.value, rl.Rectangle{0, 0, f32(texture.value.width), f32(texture.value.height)}, rl.Rectangle{position.x, position.y, width, height}, rl.Vector2{}, particle.rotation + backend.transform.rotation, color)
		} else {
			rl.DrawCircleV(position, size*0.5, color)
		}
	}
}

Clear_Particles :: proc(state: rawptr, handle: u64) {
	if state != nil {
		if system, ok := find_particles(cast(^Backend)state, handle); ok {
			clear(&system.particles)
		}
	}
}

Unload_Particles :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	b := cast(^Backend)state
	for i := 0; i < len(b.particles); i += 1 {
		if b.particles[i].handle == handle {
			delete(b.particles[i].particles)
			unordered_remove(&b.particles, i)
			return
		}
	}
}

// v0.10 ParticleSystem tuning support. All setters tolerate nil state and
// unknown handles as no-ops; scalar getters return zero values then. The
// public thor2d layer mirrors those semantics, except Clone/Replace which
// report Error.

// Headless particle simulation: headless contexts have no Backend (no
// window/GPU), but the particle sim is pure CPU. Each headless system owns
// a windowless Backend holding only particle entries; no raylib call ever
// touches it (draw paths are skipped headless by the public layer).
Particle_Create_Headless_State :: proc() -> rawptr {
	b := new(Backend)
	b.next_handle = 1
	// A headless state owns exactly one system (clones allocate fresh
	// states), so one systems slot reserved up front means the systems
	// array never reallocates for headless use.
	reserve(&b.particles, 1)
	return rawptr(b)
}

Particle_Destroy_Headless_State :: proc(state: rawptr) {	if state == nil {
		return
	}
	b := cast(^Backend)state
	for i := 0; i < len(b.particles); i += 1 {
		delete(b.particles[i].particles)
	}
	delete(b.particles)
	free(b)
}

Particle_Start :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		system.active = true
		system.paused = false
	}
}

Particle_Stop :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		system.active = false
		system.paused = false
		system.emitter_age = 0
		system.emission_remainder = 0
	}
}

Particle_Pause :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		if system.active && !system.paused {
			system.paused = true
		}
	}
}

Particle_Reset :: proc(state: rawptr, handle: u64) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		clear(&system.particles)
		system.emission_remainder = 0
		system.emitter_age = 0
		system.active = false
		system.paused = false
	}
}

Particle_Is_Active :: proc(state: rawptr, handle: u64) -> bool {
	if state == nil {
		return false
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.active && !system.paused
	}
	return false
}

Particle_Is_Paused :: proc(state: rawptr, handle: u64) -> bool {
	if state == nil {
		return false
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.paused
	}
	return false
}

Particle_Is_Stopped :: proc(state: rawptr, handle: u64) -> bool {
	if state == nil {
		return false
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return !system.active && !system.paused
	}
	return false
}

Particle_Is_Empty :: proc(state: rawptr, handle: u64) -> bool {
	if state == nil {
		return true
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return len(system.particles) == 0
	}
	return true
}

Particle_Count :: proc(state: rawptr, handle: u64) -> int {
	if state == nil {
		return 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return len(system.particles)
	}
	return 0
}

Particle_Max :: proc(state: rawptr, handle: u64) -> int {
	if state == nil {
		return 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.max_particles
	}
	return 0
}

Particle_Set_Emission_Rate :: proc(state: rawptr, handle: u64, rate: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		system.config.emission_rate = rate if rate > 0 else 0
	}
}

Particle_Emission_Rate :: proc(state: rawptr, handle: u64) -> f32 {
	if state == nil {
		return 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.emission_rate
	}
	return 0
}

Particle_Set_Emitter_Lifetime :: proc(state: rawptr, handle: u64, lifetime: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		system.config.emitter_lifetime = lifetime if lifetime > 0 else 0
	}
}

Particle_Emitter_Lifetime :: proc(state: rawptr, handle: u64) -> f32 {
	if state == nil {
		return 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.emitter_lifetime
	}
	return 0
}

Particle_Set_Lifetime :: proc(state: rawptr, handle: u64, min, max: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		lo := min if min > 0 else 0
		hi := max if max >= lo else lo
		system.config.lifetime_min = lo
		system.config.lifetime_max = hi
	}
}

Particle_Lifetime :: proc(state: rawptr, handle: u64) -> (f32, f32) {
	if state == nil {
		return 0, 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.lifetime_min, system.config.lifetime_max
	}
	return 0, 0
}

Particle_Set_Direction :: proc(state: rawptr, handle: u64, direction: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		system.config.direction = direction
	}
}

Particle_Direction :: proc(state: rawptr, handle: u64) -> f32 {
	if state == nil {
		return 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.direction
	}
	return 0
}

Particle_Set_Spread :: proc(state: rawptr, handle: u64, spread: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		system.config.spread = spread if spread > 0 else 0
	}
}

Particle_Spread :: proc(state: rawptr, handle: u64) -> f32 {
	if state == nil {
		return 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.spread
	}
	return 0
}

Particle_Set_Speed :: proc(state: rawptr, handle: u64, min, max: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		lo := min if min > 0 else 0
		hi := max if max >= lo else lo
		system.config.speed_min = lo
		system.config.speed_max = hi
	}
}

Particle_Speed :: proc(state: rawptr, handle: u64) -> (f32, f32) {
	if state == nil {
		return 0, 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.speed_min, system.config.speed_max
	}
	return 0, 0
}

Particle_Set_Linear_Acceleration :: proc(state: rawptr, handle: u64, min_x, min_y, max_x, max_y: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		system.config.linear_accel_min = rl.Vector2{min_x, min_y}
		system.config.linear_accel_max = rl.Vector2{max_x, max_y}
	}
}

Particle_Linear_Acceleration :: proc(state: rawptr, handle: u64) -> (f32, f32, f32, f32) {
	if state == nil {
		return 0, 0, 0, 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.linear_accel_min.x, system.config.linear_accel_min.y, system.config.linear_accel_max.x, system.config.linear_accel_max.y
	}
	return 0, 0, 0, 0
}

Particle_Set_Radial_Acceleration :: proc(state: rawptr, handle: u64, min, max: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		hi := max if max >= min else min
		system.config.radial_min = min
		system.config.radial_max = hi
	}
}

Particle_Radial_Acceleration :: proc(state: rawptr, handle: u64) -> (f32, f32) {
	if state == nil {
		return 0, 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.radial_min, system.config.radial_max
	}
	return 0, 0
}

Particle_Set_Tangential_Acceleration :: proc(state: rawptr, handle: u64, min, max: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		hi := max if max >= min else min
		system.config.tangential_min = min
		system.config.tangential_max = hi
	}
}

Particle_Tangential_Acceleration :: proc(state: rawptr, handle: u64) -> (f32, f32) {
	if state == nil {
		return 0, 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.tangential_min, system.config.tangential_max
	}
	return 0, 0
}

Particle_Set_Damping :: proc(state: rawptr, handle: u64, min, max: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		lo := min if min > 0 else 0
		hi := max if max >= lo else lo
		system.config.damping_min = lo
		system.config.damping_max = hi
	}
}

Particle_Damping :: proc(state: rawptr, handle: u64) -> (f32, f32) {
	if state == nil {
		return 0, 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.damping_min, system.config.damping_max
	}
	return 0, 0
}

Particle_Set_Gravity :: proc(state: rawptr, handle: u64, x, y: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		system.config.gravity = rl.Vector2{x, y}
	}
}

Particle_Gravity :: proc(state: rawptr, handle: u64) -> (f32, f32) {
	if state == nil {
		return 0, 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.gravity.x, system.config.gravity.y
	}
	return 0, 0
}

Particle_Set_Spin :: proc(state: rawptr, handle: u64, min, max: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		hi := max if max >= min else min
		system.config.spin_min = min
		system.config.spin_max = hi
	}
}

Particle_Spin :: proc(state: rawptr, handle: u64) -> (f32, f32) {
	if state == nil {
		return 0, 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.config.spin_min, system.config.spin_max
	}
	return 0, 0
}

particle_sync_size_ends :: proc(system: ^Particle_System_Entry) {
	if system.size_count > 0 {
		system.config.start_size = system.sizes[0]
		system.config.end_size = system.sizes[system.size_count-1]
	}
}

particle_sync_color_ends :: proc(system: ^Particle_System_Entry) {
	if system.color_count > 0 {
		system.config.start_color = system.colors[0]
		system.config.end_color = system.colors[system.color_count-1]
	}
}

particle_ensure_tracks :: proc(system: ^Particle_System_Entry) {
	if system.size_count <= 0 {
		system.sizes[0] = system.config.start_size
		system.sizes[1] = system.config.end_size
		system.size_count = 2
	}
	if system.color_count <= 0 {
		system.colors[0] = system.config.start_color
		system.colors[1] = system.config.end_color
		system.color_count = 2
	}
}

Particle_Set_Sizes :: proc(state: rawptr, handle: u64, sizes: []f32) {
	if state == nil || len(sizes) == 0 {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		count := len(sizes) if len(sizes) < 8 else 8
		for i := 0; i < count; i += 1 {
			system.sizes[i] = sizes[i] if sizes[i] > 0 else 0
		}
		system.size_count = count
		particle_sync_size_ends(system)
	}
}

Particle_Size_Count :: proc(state: rawptr, handle: u64) -> int {
	if state == nil {
		return 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.size_count
	}
	return 0
}

Particle_Set_Colors :: proc(state: rawptr, handle: u64, rgba: []u8) {
	if state == nil || len(rgba) < 4 {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		count := len(rgba) / 4
		if count > 8 {
			count = 8
		}
		for i := 0; i < count; i += 1 {
			system.colors[i] = rl.Color{rgba[i*4], rgba[i*4+1], rgba[i*4+2], rgba[i*4+3]}
		}
		system.color_count = count
		particle_sync_color_ends(system)
	}
}

Particle_Color_Count :: proc(state: rawptr, handle: u64) -> int {
	if state == nil {
		return 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		return system.color_count
	}
	return 0
}

Particle_Set_Size :: proc(state: rawptr, handle: u64, size: f32) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		particle_ensure_tracks(system)
		system.sizes[0] = size if size > 0 else 0
		particle_sync_size_ends(system)
	}
}

Particle_Size :: proc(state: rawptr, handle: u64) -> f32 {
	if state == nil {
		return 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		if system.size_count > 0 {
			return system.sizes[0]
		}
		return system.config.start_size
	}
	return 0
}

Particle_Set_Color :: proc(state: rawptr, handle: u64, r, g, b, a: u8) {
	if state == nil {
		return
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		particle_ensure_tracks(system)
		system.colors[0] = rl.Color{r, g, b, a}
		particle_sync_color_ends(system)
	}
}

Particle_Color :: proc(state: rawptr, handle: u64) -> (u8, u8, u8, u8) {
	if state == nil {
		return 0, 0, 0, 0
	}
	if system, ok := find_particles(cast(^Backend)state, handle); ok {
		color := system.config.start_color
		if system.color_count > 0 {
			color = system.colors[0]
		}
		return color.r, color.g, color.b, color.a
	}
	return 0, 0, 0, 0
}

Particle_Set_Texture :: proc(state: rawptr, handle, texture_handle: u64) -> bool {
	if state == nil {
		return false
	}
	b := cast(^Backend)state
	system, ok := find_particles(b, handle)
	if !ok {
		return false
	}
	if texture_handle != 0 {
		if _, texture_ok := find_texture(b, texture_handle); !texture_ok {
			return false
		}
	}
	system.texture_handle = texture_handle
	return true
}

// Particle_Clone_To copies a system into dst_state (which may equal
// src_state for windowed clones, or a fresh headless state). The clone
// starts stopped with zero live particles (LOVE clone semantics) but
// inherits all tuning, tracks, texture and the RNG seed for deterministic
// continuation. Live particles are not copied.
Particle_Clone_To :: proc(dst_state, src_state: rawptr, handle: u64) -> (u64, bool) {
	if dst_state == nil || src_state == nil {
		return 0, false
	}
	src, ok := find_particles(cast(^Backend)src_state, handle)
	if !ok {
		return 0, false
	}
	dst := cast(^Backend)dst_state
	new_handle := dst.next_handle
	dst.next_handle += 1
	clone := Particle_System_Entry{
		handle = new_handle,
		texture_handle = src.texture_handle,
		config = src.config,
		seed = src.seed,
		active = false,
		paused = false,
		emitter_age = 0,
		sizes = src.sizes,
		size_count = src.size_count,
		colors = src.colors,
		color_count = src.color_count,
	}
	// Headless-to-headless clones reference texture handles that cannot
	// resolve without a GPU backend; keep the handle value (honest: it
	// resolves once a real texture with that handle exists, and Draw is a
	// headless no-op regardless). Windowed validation happens at replace.
	append(&dst.particles, clone)
	// Same bounded reservation as Create_Particles: clones emit within the
	// inherited max, so their arrays never reallocate either.
	if reserve(&dst.particles[len(dst.particles)-1].particles, clone.config.max_particles) != nil {
		pop(&dst.particles)
		return 0, false
	}
	return new_handle, true
}

normalize_asset_path :: proc(path: string) -> (string, bool) {
	normalized, _ := strings.replace_all(path, "\\", "/")
	stable, err := strings.clone(normalized)
	return stable, err == nil
}

stable_asset_id :: proc(path: string) -> u64 {
	value: u64 = 14695981039346656037
	for c in path {
		value = value ~ u64(c)
		value *= 1099511628211
	}
	if value == 0 {
		value = 1
	}
	return value
}

remove_texture_cache :: proc(b: ^Backend, handle: u64) {
	for i := len(b.texture_cache)-1; i >= 0; i -= 1 {
		if b.texture_cache[i].handle == handle {
			delete(b.texture_cache[i].path)
			unordered_remove(&b.texture_cache, i)
		}
	}
}

remove_font_cache :: proc(b: ^Backend, handle: u64) {
	for i := len(b.font_cache)-1; i >= 0; i -= 1 {
		if b.font_cache[i].handle == handle {
			delete(b.font_cache[i].path)
			unordered_remove(&b.font_cache, i)
		}
	}
}

remove_sound_cache :: proc(b: ^Backend, handle: u64) {
	for i := len(b.sound_cache)-1; i >= 0; i -= 1 {
		if b.sound_cache[i].handle == handle {
			delete(b.sound_cache[i].path)
			unordered_remove(&b.sound_cache, i)
		}
	}
}

Texture_Asset_ID :: proc(state: rawptr, handle: u64) -> u64 {
	if state == nil {
		return 0
	}
	b := cast(^Backend)state
	for entry in b.texture_cache {
		if entry.handle == handle {
			return entry.asset_id
		}
	}
	return 0
}

Font_Asset_ID :: proc(state: rawptr, handle: u64) -> u64 {
	if state == nil {
		return 0
	}
	b := cast(^Backend)state
	for entry in b.font_cache {
		if entry.handle == handle {
			return entry.asset_id
		}
	}
	return 0
}

Sound_Asset_ID :: proc(state: rawptr, handle: u64) -> u64 {
	if state == nil {
		return 0
	}
	b := cast(^Backend)state
	for entry in b.sound_cache {
		if entry.handle == handle {
			return entry.asset_id
		}
	}
	return 0
}

Load_Texture_Cached :: proc(state: rawptr, path: string) -> (u64, u64, bool) {
	if state == nil {
		return 0, 0, false
	}
	b := cast(^Backend)state
	normalized, ok := normalize_asset_path(path)
	if !ok {
		return 0, 0, false
	}
	for entry in b.texture_cache {
		if entry.path == normalized {
			delete(normalized)
			return entry.handle, entry.asset_id, true
		}
	}
	handle, loaded := Load_Texture(state, normalized)
	if !loaded {
		delete(normalized)
		return 0, 0, false
	}
	asset_id := stable_asset_id(normalized)
	append(&b.texture_cache, Texture_Cache_Entry{normalized, handle, asset_id})
	return handle, asset_id, true
}

Load_Font_Cached :: proc(state: rawptr, path: string) -> (u64, u64, bool) {
	if state == nil {
		return 0, 0, false
	}
	b := cast(^Backend)state
	normalized, ok := normalize_asset_path(path)
	if !ok {
		return 0, 0, false
	}
	for entry in b.font_cache {
		if entry.path == normalized {
			delete(normalized)
			return entry.handle, entry.asset_id, true
		}
	}
	handle, loaded := Load_Font(state, normalized)
	if !loaded {
		delete(normalized)
		return 0, 0, false
	}
	asset_id := stable_asset_id(normalized)
	append(&b.font_cache, Font_Cache_Entry{normalized, handle, asset_id})
	return handle, asset_id, true
}

Load_Sound_Cached :: proc(state: rawptr, path: string) -> (u64, u64, bool) {
	if state == nil {
		return 0, 0, false
	}
	b := cast(^Backend)state
	normalized, ok := normalize_asset_path(path)
	if !ok {
		return 0, 0, false
	}
	for entry in b.sound_cache {
		if entry.path == normalized {
			delete(normalized)
			return entry.handle, entry.asset_id, true
		}
	}
	handle, loaded := Load_Sound(state, normalized)
	if !loaded {
		delete(normalized)
		return 0, 0, false
	}
	asset_id := stable_asset_id(normalized)
	append(&b.sound_cache, Sound_Cache_Entry{normalized, handle, asset_id})
	return handle, asset_id, true
}
