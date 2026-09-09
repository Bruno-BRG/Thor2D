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

Create_Particles :: proc(ctx: ^Context, texture: Texture, config: Particle_Config) -> (Particle_System, Error) {
	if ctx == nil || ctx.backend == nil || config.Max_Particles <= 0 {
		return Particle_System{}, .Invalid_Config
	}
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

Emit_Particles :: proc(ctx: ^Context, particles: Particle_System, count: int) {
	if ctx != nil && ctx.backend != nil && particles.handle != 0 {
		backend.Emit_Particles(ctx.backend, particles.handle, count)
	}
}

Update_Particles :: proc(ctx: ^Context, particles: Particle_System, delta: f32) {
	if ctx != nil && ctx.backend != nil && particles.handle != 0 {
		backend.Update_Particles(ctx.backend, particles.handle, delta)
	}
}

Draw_Particles :: proc(ctx: ^Context, particles: Particle_System, position: Vec2, tint := White) {
	if ctx != nil && ctx.backend != nil && particles.handle != 0 {
		backend.Draw_Particles(ctx.backend, particles.handle, position.X, position.Y, tint.R, tint.G, tint.B, tint.A)
	}
}

Clear_Particles :: proc(ctx: ^Context, particles: Particle_System) {
	if ctx != nil && ctx.backend != nil && particles.handle != 0 {
		backend.Clear_Particles(ctx.backend, particles.handle)
	}
}

Unload_Particles :: proc(ctx: ^Context, particles: Particle_System) {
	if ctx != nil && ctx.backend != nil && particles.handle != 0 {
		backend.Unload_Particles(ctx.backend, particles.handle)
	}
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
