package thor2d

import math "core:math"
import audio "thor2d:thor2d/internal/audio"

// v0.8 LOVE-parity getters for audio, math and data. All headless-safe.

// --- Audio getters (love.audio get*) ---

Get_Master_Volume :: proc(ctx: ^Context) -> f32 {
	if ctx == nil || ctx.audio_backend == nil {
		return 0
	}
	return audio.Get_Master(ctx.audio_backend)
}

Get_Audio_Position :: proc(ctx: ^Context) -> Vec2 {
	if ctx == nil || ctx.audio_backend == nil {
		return Vec2{}
	}
	position, _ := audio.Get_Listener(ctx.audio_backend)
	return Vec2{position[0], position[1]}
}

Get_Audio_Velocity :: proc(ctx: ^Context) -> Vec2 {
	if ctx == nil || ctx.audio_backend == nil {
		return Vec2{}
	}
	_, velocity := audio.Get_Listener(ctx.audio_backend)
	return Vec2{velocity[0], velocity[1]}
}

Get_Audio_Distance_Model :: proc(ctx: ^Context) -> Audio_Distance_Model {
	if ctx == nil || ctx.audio_backend == nil {
		return .Inverse
	}
	switch audio.Get_Distance_Model(ctx.audio_backend) {
	case 0:
		return .None
	case 3:
		return .Linear
	case 5:
		return .Exponential
	}
	return .Inverse
}

Is_Audio_Effects_Supported :: proc(ctx: ^Context) -> bool {
	return Query_Capability(ctx, .Audio_Effects)
}

// --- Math gaps (love.math) ---

Get_Random_Seed :: proc(generator: ^Random_Generator) -> u64 {
	if generator == nil {
		return 0
	}
	return generator.State
}

Set_Random_State :: proc(generator: ^Random_Generator, state: u64) {
	if generator != nil {
		generator.State = state
	}
}

Random_Normal :: proc(generator: ^Random_Generator, mean := f32(0), std := f32(1)) -> f32 {
	// Box-Muller with the deterministic xorshift generator.
	if generator == nil || std <= 0 {
		return mean
	}
	u1 := Random_Float(generator, 1e-6, 1.0)
	u2 := Random_Float(generator, 0.0, 1.0)
	r := math.sqrt(-2*f64(math.ln(f64(u1))))
	theta := 2*f64(math.PI)*f64(u2)
	return mean + std*f32(r*f64(math.cos(theta)))
}

// --- Data gaps (love.data) ---

Packed_Size_U16 :: proc() -> int { return 2 }
Packed_Size_U32 :: proc() -> int { return 4 }
Packed_Size_U64 :: proc() -> int { return 8 }
Packed_Size_I32 :: proc() -> int { return 4 }
Packed_Size_F32 :: proc() -> int { return 4 }

// Get_Packed_Size documents the fixed-width LE pack format as the intentional
// v0.8 subset (no Lua 5.3 format strings).
Get_Packed_Size :: proc(type_name: string) -> (int, Error) {
	switch type_name {
	case "u16":
		return 2, .None
	case "u32", "i32", "f32":
		return 4, .None
	case "u64":
		return 8, .None
	}
	return 0, .Invalid_Data
}
