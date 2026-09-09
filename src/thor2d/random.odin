package thor2d

import math "core:math"
import backend "thor2d:thor2d/internal/raylib"

Random_Int :: proc(ctx: ^Context, minimum, maximum: int) -> int {
	if ctx == nil || ctx.backend == nil || minimum > maximum {
		return minimum
	}
	return backend.Random_Int(ctx.backend, minimum, maximum)
}

New_Random_Generator :: proc(seed: u64) -> Random_Generator {
	value := seed
	if value == 0 {
		value = 0x9E3779B97F4A7C15
	}
	return Random_Generator{State = value}
}

Seed_Random_Generator :: proc(generator: ^Random_Generator, seed: u64) {
	if generator != nil {
		generator.State = New_Random_Generator(seed).State
	}
}

Random_Next_U64 :: proc(generator: ^Random_Generator) -> u64 {
	if generator == nil {
		return 0
	}
	x := generator.State
	x = x ~ (x >> 12)
	x = x ~ (x << 25)
	x = x ~ (x >> 27)
	generator.State = x
	return x * 2685821657736338717
}

Random_Float :: proc(generator: ^Random_Generator, minimum, maximum: f32) -> f32 {
	if generator == nil {
		return minimum
	}
	unit := f32(Random_Next_U64(generator) >> 40) / f32(1 << 24)
	return minimum + (maximum-minimum)*unit
}

Random_Int_Range :: proc(generator: ^Random_Generator, minimum, maximum: int) -> int {
	if generator == nil || minimum >= maximum {
		return minimum
	}
	span := u64(maximum-minimum+1)
	return minimum + int(Random_Next_U64(generator)%span)
}

Random_Noise_2D :: proc(x, y: f32, seed: u64) -> f32 {
	ix := i64(x)
	iy := i64(y)
	hash := u64(ix)*0x9E3779B185EBCA87 ~ u64(iy)*0xC2B2AE3D27D4EB4F ~ seed
	hash = hash ~ (hash >> 30)
	hash *= 0xBF58476D1CE4E5B9
	hash = hash ~ (hash >> 27)
	return f32(hash >> 40)/f32(1<<24)*2-1
}

Lerp :: proc(a, b, amount: f32) -> f32 {
	return a + (b-a)*amount
}

SRGB_To_Linear :: proc(value: f32) -> f32 {
	if value <= 0.04045 {
		return value / 12.92
	}
	return f32(math.pow(f64((value+0.055)/1.055), 2.4))
}

Linear_To_SRGB :: proc(value: f32) -> f32 {
	if value <= 0.0031308 {
		return value * 12.92
	}
	return 1.055*f32(math.pow(f64(value), 1.0/2.4)) - 0.055
}
