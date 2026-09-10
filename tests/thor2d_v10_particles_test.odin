package tests

import "core:testing"
import thor2d "thor2d:thor2d"

// v0.10 ParticleSystem tuning API. All headless-safe: the particle sim is
// pure CPU, so headless contexts run it in a windowless backend state
// (draw stays a no-op without a window/GPU).

v10_headless_ctx :: proc(t: ^testing.T) -> (thor2d.Context, bool) {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, err := thor2d.Create(config)
	if !testing.expect(t, err == .None) {
		return ctx, false
	}
	return ctx, true
}

v10_make_system :: proc(t: ^testing.T, ctx: ^thor2d.Context) -> (thor2d.Particle_System, bool) {
	ps, err := thor2d.Create_Particles(ctx, thor2d.Texture{}, thor2d.Default_Particle_Config(256))
	if !testing.expect(t, err == .None) {
		return ps, false
	}
	if !testing.expect(t, !thor2d.Particle_System_Invalid(ps)) {
		return ps, false
	}
	return ps, true
}

@(test)
test_v10_particle_config_roundtrips :: proc(t: ^testing.T) {
	ctx, ok := v10_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	ps, ps_ok := v10_make_system(t, &ctx)
	if !ps_ok {
		return
	}
	defer thor2d.Unload_Particles(&ctx, ps)

	thor2d.Set_Particle_Emission_Rate(&ctx, ps, 120)
	testing.expect(t, thor2d.Get_Particle_Emission_Rate(&ctx, ps) == 120)

	thor2d.Set_Particle_Emitter_Lifetime(&ctx, ps, 2.5)
	testing.expect(t, thor2d.Get_Particle_Emitter_Lifetime(&ctx, ps) == 2.5)

	thor2d.Set_Particle_Lifetime(&ctx, ps, 0.25, 0.75)
	lo, hi := thor2d.Get_Particle_Lifetime(&ctx, ps)
	testing.expect(t, lo == 0.25 && hi == 0.75)

	thor2d.Set_Particle_Direction(&ctx, ps, 1.5)
	testing.expect(t, thor2d.Get_Particle_Direction(&ctx, ps) == 1.5)
	thor2d.Set_Particle_Spread(&ctx, ps, 0.8)
	testing.expect(t, thor2d.Get_Particle_Spread(&ctx, ps) == 0.8)

	thor2d.Set_Particle_Speed(&ctx, ps, 40, 90)
	smin, smax := thor2d.Get_Particle_Speed(&ctx, ps)
	testing.expect(t, smin == 40 && smax == 90)

	thor2d.Set_Particle_Linear_Acceleration(&ctx, ps, thor2d.Vec2{-10, -20}, thor2d.Vec2{30, 40})
	amin, amax := thor2d.Get_Particle_Linear_Acceleration(&ctx, ps)
	testing.expect(t, amin == thor2d.Vec2{-10, -20} && amax == thor2d.Vec2{30, 40})

	thor2d.Set_Particle_Radial_Acceleration(&ctx, ps, -5, 15)
	rmin, rmax := thor2d.Get_Particle_Radial_Acceleration(&ctx, ps)
	testing.expect(t, rmin == -5 && rmax == 15)

	thor2d.Set_Particle_Tangential_Acceleration(&ctx, ps, 2, 8)
	tmin, tmax := thor2d.Get_Particle_Tangential_Acceleration(&ctx, ps)
	testing.expect(t, tmin == 2 && tmax == 8)

	thor2d.Set_Particle_Damping(&ctx, ps, 1, 3)
	dmin, dmax := thor2d.Get_Particle_Damping(&ctx, ps)
	testing.expect(t, dmin == 1 && dmax == 3)

	thor2d.Set_Particle_Gravity(&ctx, ps, thor2d.Vec2{0, 98})
	testing.expect(t, thor2d.Get_Particle_Gravity(&ctx, ps) == thor2d.Vec2{0, 98})

	thor2d.Set_Particle_Spin(&ctx, ps, -3, 3)
	pmin, pmax := thor2d.Get_Particle_Spin(&ctx, ps)
	testing.expect(t, pmin == -3 && pmax == 3)

	// Fresh systems snapshot 2-stop tracks from start/end.
	testing.expect(t, thor2d.Get_Particle_Size_Count(&ctx, ps) == 2)
	testing.expect(t, thor2d.Get_Particle_Color_Count(&ctx, ps) == 2)

	thor2d.Set_Particle_Sizes(&ctx, ps, []f32{10, 6, 2})
	testing.expect(t, thor2d.Get_Particle_Size_Count(&ctx, ps) == 3)
	testing.expect(t, thor2d.Get_Particle_Size(&ctx, ps) == 10)

	thor2d.Set_Particle_Size(&ctx, ps, 12)
	testing.expect(t, thor2d.Get_Particle_Size(&ctx, ps) == 12)
	testing.expect(t, thor2d.Get_Particle_Size_Count(&ctx, ps) == 3)

	thor2d.Set_Particle_Colors(&ctx, ps, []thor2d.Color{thor2d.Red, thor2d.Green, thor2d.Blue})
	testing.expect(t, thor2d.Get_Particle_Color_Count(&ctx, ps) == 3)
	testing.expect(t, thor2d.Get_Particle_Color(&ctx, ps) == thor2d.Red)

	thor2d.Set_Particle_Color(&ctx, ps, thor2d.Blue)
	testing.expect(t, thor2d.Get_Particle_Color(&ctx, ps) == thor2d.Blue)
	testing.expect(t, thor2d.Get_Particle_Color_Count(&ctx, ps) == 3)

	// Empty tracks are no-ops, never clobber.
	thor2d.Set_Particle_Sizes(&ctx, ps, []f32{})
	testing.expect(t, thor2d.Get_Particle_Size_Count(&ctx, ps) == 3)
	thor2d.Set_Particle_Colors(&ctx, ps, []thor2d.Color{})
	testing.expect(t, thor2d.Get_Particle_Color_Count(&ctx, ps) == 3)

	testing.expect(t, thor2d.Get_Particle_Max(&ctx, ps) == 256)
}

@(test)
test_v10_particle_lifecycle :: proc(t: ^testing.T) {
	ctx, ok := v10_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	ps, ps_ok := v10_make_system(t, &ctx)
	if !ps_ok {
		return
	}
	defer thor2d.Unload_Particles(&ctx, ps)

	// New systems start active (Thor2D CType behavior) and empty.
	testing.expect(t, thor2d.Is_Particles_Active(&ctx, ps))
	testing.expect(t, !thor2d.Is_Particles_Paused(&ctx, ps))
	testing.expect(t, !thor2d.Is_Particles_Stopped(&ctx, ps))
	testing.expect(t, thor2d.Is_Particles_Empty(&ctx, ps))
	testing.expect(t, thor2d.Get_Particle_Count(&ctx, ps) == 0)

	// High emission rate produces live particles headless.
	thor2d.Set_Particle_Emission_Rate(&ctx, ps, 1000)
	thor2d.Update_Particles(&ctx, ps, 0.1)
	testing.expect(t, thor2d.Get_Particle_Count(&ctx, ps) > 0)
	testing.expect(t, !thor2d.Is_Particles_Empty(&ctx, ps))

	// Pause freezes the sim: counts stop changing.
	before := thor2d.Get_Particle_Count(&ctx, ps)
	thor2d.Pause_Particles(&ctx, ps)
	testing.expect(t, thor2d.Is_Particles_Paused(&ctx, ps))
	testing.expect(t, !thor2d.Is_Particles_Active(&ctx, ps))
	thor2d.Update_Particles(&ctx, ps, 1.0)
	testing.expect(t, thor2d.Get_Particle_Count(&ctx, ps) == before)

	// Start resumes; stop halts emission while live particles decay.
	thor2d.Start_Particles(&ctx, ps)
	testing.expect(t, thor2d.Is_Particles_Active(&ctx, ps))
	thor2d.Stop_Particles(&ctx, ps)
	testing.expect(t, thor2d.Is_Particles_Stopped(&ctx, ps))
	testing.expect(t, !thor2d.Is_Particles_Active(&ctx, ps))
	thor2d.Update_Particles(&ctx, ps, 10.0)
	testing.expect(t, thor2d.Is_Particles_Empty(&ctx, ps))

	// Reset clears everything back to the stopped state.
	thor2d.Start_Particles(&ctx, ps)
	thor2d.Update_Particles(&ctx, ps, 0.1)
	testing.expect(t, thor2d.Get_Particle_Count(&ctx, ps) > 0)
	thor2d.Reset_Particles(&ctx, ps)
	testing.expect(t, thor2d.Is_Particles_Stopped(&ctx, ps))
	testing.expect(t, thor2d.Is_Particles_Empty(&ctx, ps))
	testing.expect(t, thor2d.Get_Particle_Count(&ctx, ps) == 0)

	// Emitter budget auto-stops emission; live particles still decay.
	thor2d.Set_Particle_Emission_Rate(&ctx, ps, 1000)
	thor2d.Set_Particle_Emitter_Lifetime(&ctx, ps, 0.05)
	thor2d.Start_Particles(&ctx, ps)
	thor2d.Update_Particles(&ctx, ps, 0.1)
	testing.expect(t, thor2d.Is_Particles_Stopped(&ctx, ps))
	thor2d.Update_Particles(&ctx, ps, 10.0)
	testing.expect(t, thor2d.Is_Particles_Empty(&ctx, ps))
}

@(test)
test_v10_particle_clone_independence :: proc(t: ^testing.T) {
	ctx, ok := v10_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	ps, ps_ok := v10_make_system(t, &ctx)
	if !ps_ok {
		return
	}
	defer thor2d.Unload_Particles(&ctx, ps)

	thor2d.Set_Particle_Emission_Rate(&ctx, ps, 500)
	thor2d.Set_Particle_Gravity(&ctx, ps, thor2d.Vec2{0, 50})
	thor2d.Set_Particle_Speed(&ctx, ps, 10, 20)
	thor2d.Set_Particle_Sizes(&ctx, ps, []f32{9, 4})
	thor2d.Update_Particles(&ctx, ps, 0.1)
	testing.expect(t, thor2d.Get_Particle_Count(&ctx, ps) > 0)

	clone, clone_err := thor2d.Clone_Particles(&ctx, ps)
	testing.expect(t, clone_err == .None)
	defer thor2d.Unload_Particles(&ctx, clone)

	// Tuning inherited; live particles not copied; clone starts stopped.
	testing.expect(t, thor2d.Get_Particle_Emission_Rate(&ctx, clone) == 500)
	testing.expect(t, thor2d.Get_Particle_Gravity(&ctx, clone) == thor2d.Vec2{0, 50})
	cmin, cmax := thor2d.Get_Particle_Speed(&ctx, clone)
	testing.expect(t, cmin == 10 && cmax == 20)
	testing.expect(t, thor2d.Get_Particle_Size_Count(&ctx, clone) == 2)
	testing.expect(t, thor2d.Is_Particles_Stopped(&ctx, clone))
	testing.expect(t, thor2d.Is_Particles_Empty(&ctx, clone))
	testing.expect(t, thor2d.Get_Particle_Max(&ctx, clone) == 256)

	// Mutations do not cross between original and clone.
	thor2d.Set_Particle_Emission_Rate(&ctx, ps, 5)
	testing.expect(t, thor2d.Get_Particle_Emission_Rate(&ctx, clone) == 500)
	thor2d.Set_Particle_Emission_Rate(&ctx, clone, 7)
	testing.expect(t, thor2d.Get_Particle_Emission_Rate(&ctx, ps) == 5)
}

@(test)
test_v10_particle_determinism :: proc(t: ^testing.T) {
	ctx, ok := v10_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	a, a_ok := v10_make_system(t, &ctx)
	if !a_ok {
		return
	}
	defer thor2d.Unload_Particles(&ctx, a)
	b, b_ok := v10_make_system(t, &ctx)
	if !b_ok {
		return
	}
	defer thor2d.Unload_Particles(&ctx, b)

	configure :: proc(ctx: ^thor2d.Context, ps: thor2d.Particle_System) {
		thor2d.Set_Particle_Emission_Rate(ctx, ps, 300)
		thor2d.Set_Particle_Lifetime(ctx, ps, 0.4, 0.9)
		thor2d.Set_Particle_Direction(ctx, ps, 0.7)
		thor2d.Set_Particle_Spread(ctx, ps, 1.2)
		thor2d.Set_Particle_Speed(ctx, ps, 30, 80)
		thor2d.Set_Particle_Linear_Acceleration(ctx, ps, thor2d.Vec2{-5, -5}, thor2d.Vec2{5, 5})
		thor2d.Set_Particle_Radial_Acceleration(ctx, ps, -4, 4)
		thor2d.Set_Particle_Tangential_Acceleration(ctx, ps, -2, 2)
		thor2d.Set_Particle_Damping(ctx, ps, 0, 2)
		thor2d.Set_Particle_Gravity(ctx, ps, thor2d.Vec2{0, 20})
		thor2d.Set_Particle_Spin(ctx, ps, -2, 2)
		thor2d.Set_Particle_Sizes(ctx, ps, []f32{8, 5, 2})
	}
	configure(&ctx, a)
	configure(&ctx, b)

	// Same seed + config + update sequence evolves identically.
	for i := 0; i < 60; i += 1 {
		thor2d.Update_Particles(&ctx, a, 1.0/60.0)
		thor2d.Update_Particles(&ctx, b, 1.0/60.0)
		testing.expect(t, thor2d.Get_Particle_Count(&ctx, a) == thor2d.Get_Particle_Count(&ctx, b))
	}
	testing.expect(t, thor2d.Get_Particle_Count(&ctx, a) > 0)
}

@(test)
test_v10_particle_invalid_handles :: proc(t: ^testing.T) {
	ctx, ok := v10_headless_ctx(t)
	if !ok {
		return
	}
	defer thor2d.Destroy(&ctx)
	bad := thor2d.Particle_System{}

	// Setters/lifecycle on invalid handles are silent no-ops.
	thor2d.Set_Particle_Emission_Rate(&ctx, bad, 100)
	thor2d.Set_Particle_Emitter_Lifetime(&ctx, bad, 1)
	thor2d.Set_Particle_Lifetime(&ctx, bad, 1, 2)
	thor2d.Set_Particle_Direction(&ctx, bad, 1)
	thor2d.Set_Particle_Spread(&ctx, bad, 1)
	thor2d.Set_Particle_Speed(&ctx, bad, 1, 2)
	thor2d.Set_Particle_Linear_Acceleration(&ctx, bad, thor2d.Vec2{}, thor2d.Vec2{})
	thor2d.Set_Particle_Radial_Acceleration(&ctx, bad, 1, 2)
	thor2d.Set_Particle_Tangential_Acceleration(&ctx, bad, 1, 2)
	thor2d.Set_Particle_Damping(&ctx, bad, 1, 2)
	thor2d.Set_Particle_Gravity(&ctx, bad, thor2d.Vec2{1, 1})
	thor2d.Set_Particle_Spin(&ctx, bad, 1, 2)
	thor2d.Set_Particle_Sizes(&ctx, bad, []f32{4})
	thor2d.Set_Particle_Colors(&ctx, bad, []thor2d.Color{thor2d.Red})
	thor2d.Set_Particle_Size(&ctx, bad, 4)
	thor2d.Set_Particle_Color(&ctx, bad, thor2d.Red)
	thor2d.Start_Particles(&ctx, bad)
	thor2d.Stop_Particles(&ctx, bad)
	thor2d.Pause_Particles(&ctx, bad)
	thor2d.Reset_Particles(&ctx, bad)
	thor2d.Emit_Particles(&ctx, bad, 10)
	thor2d.Update_Particles(&ctx, bad, 0.016)
	thor2d.Clear_Particles(&ctx, bad)
	thor2d.Unload_Particles(&ctx, bad)
	thor2d.Draw_Particles(&ctx, bad, thor2d.Vec2{})

	// Getters report zero values.
	testing.expect(t, thor2d.Get_Particle_Emission_Rate(&ctx, bad) == 0)
	testing.expect(t, thor2d.Get_Particle_Emitter_Lifetime(&ctx, bad) == 0)
	testing.expect(t, thor2d.Get_Particle_Size_Count(&ctx, bad) == 0)
	testing.expect(t, thor2d.Get_Particle_Color_Count(&ctx, bad) == 0)
	testing.expect(t, thor2d.Get_Particle_Size(&ctx, bad) == 0)
	testing.expect(t, thor2d.Get_Particle_Color(&ctx, bad) == thor2d.Color{})
	testing.expect(t, thor2d.Get_Particle_Count(&ctx, bad) == 0)
	testing.expect(t, thor2d.Get_Particle_Max(&ctx, bad) == 0)
	testing.expect(t, !thor2d.Is_Particles_Active(&ctx, bad))
	testing.expect(t, !thor2d.Is_Particles_Paused(&ctx, bad))
	testing.expect(t, !thor2d.Is_Particles_Stopped(&ctx, bad))
	testing.expect(t, thor2d.Is_Particles_Empty(&ctx, bad))

	// Fallible procs report errors, never fake handles.
	_, clone_err := thor2d.Clone_Particles(&ctx, bad)
	testing.expect(t, clone_err == .Invalid_Handle)
	testing.expect(t, thor2d.Replace_Particle_Texture(&ctx, bad, thor2d.Texture{}) == .Invalid_Handle)

	// Headless has no GPU textures: Texture{} is fine, real ones rejected.
	ps, ps_ok := v10_make_system(t, &ctx)
	if !ps_ok {
		return
	}
	defer thor2d.Unload_Particles(&ctx, ps)
	testing.expect(t, thor2d.Replace_Particle_Texture(&ctx, ps, thor2d.Texture{}) == .None)
	testing.expect(t, thor2d.Replace_Particle_Texture(&ctx, ps, thor2d.Texture{handle = 999}) == .Invalid_Handle)

	// Nil contexts never crash.
	thor2d.Set_Particle_Emission_Rate(nil, ps, 100)
	testing.expect(t, thor2d.Get_Particle_Emission_Rate(nil, ps) == 0)
	_, nil_clone_err := thor2d.Clone_Particles(nil, ps)
	testing.expect(t, nil_clone_err == .Invalid_Handle)
}
