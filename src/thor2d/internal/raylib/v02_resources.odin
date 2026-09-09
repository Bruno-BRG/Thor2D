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
	for command in batch.commands {
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
	}
	append(&b.particles, Particle_System_Entry{
		handle = handle,
		texture_handle = texture_handle,
		config = config,
		seed = 0x9E3779B9,
	})
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

emit_one :: proc(system: ^Particle_System_Entry) {
	if len(system.particles) >= system.config.max_particles {
		return
	}
	life_range := system.config.lifetime_max - system.config.lifetime_min
	lifetime := system.config.lifetime_min + life_range*particle_random(&system.seed)
	if lifetime <= 0 {
		lifetime = 0.001
	}
	angle := particle_random(&system.seed) * 6.2831855
	speed := 20 + particle_random(&system.seed)*80
	append(&system.particles, Particle_State{
		velocity = rl.Vector2{math.cos(angle) * speed, math.sin(angle) * speed},
		life = lifetime,
		lifetime = lifetime,
		rotation = particle_random(&system.seed) * 360,
		angular_velocity = -90 + particle_random(&system.seed)*180,
		scale = system.config.start_size,
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
	if system.config.emission_rate > 0 {
		system.emission_remainder += system.config.emission_rate * delta
		emit_count := int(system.emission_remainder)
		system.emission_remainder -= f32(emit_count)
		for i := 0; i < emit_count; i += 1 {
			emit_one(system)
		}
	}
	for i := len(system.particles)-1; i >= 0; i -= 1 {
		particle := &system.particles[i]
		particle.life -= delta
		if particle.life <= 0 {
			unordered_remove(&system.particles, i)
			continue
		}
		particle.velocity.x += system.config.gravity.x * delta
		particle.velocity.y += system.config.gravity.y * delta
		particle.position.x += particle.velocity.x * delta
		particle.position.y += particle.velocity.y * delta
		particle.rotation += particle.angular_velocity * delta
		age := 1 - particle.life/particle.lifetime
		particle.scale = particle_lerp(system.config.start_size, system.config.end_size, age)
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
		color := particle_color(system.config.start_color, system.config.end_color, age)
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
