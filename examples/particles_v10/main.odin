package particles_v10

// Thor2D v0.10 ParticleSystem tuning demo: a fountain whose emission rate,
// spread and pause state are driven live from the keyboard. Imports only
// thor2d. Set THOR2D_SMOKE=1 to auto-quit (used by ./build.sh particles).

import "core:fmt"
import "core:os"
import thor2d "thor2d:thor2d"

elapsed: f64
system: thor2d.Particle_System
emission_rate: f32 = 150

make_system :: proc(ctx: ^thor2d.Context) {
	texture, texture_err := thor2d.Generate_Texture(ctx, 16, 16, thor2d.White)
	if texture_err != .None {
		// Windowed runs always reach here with a texture; the fallback
		// keeps the system valid (circle renderer) if one is unavailable.
		fmt.println("particles: texture unavailable, using circles")
	}
	ps, err := thor2d.Create_Particles(ctx, texture if texture_err == .None else thor2d.Texture{}, thor2d.Default_Particle_Config(600))
	if err != .None {
		fmt.println("particles: create failed:", thor2d.Error_String(err))
		return
	}
	system = ps
	thor2d.Set_Particle_Emission_Rate(ctx, system, emission_rate)
	thor2d.Set_Particle_Lifetime(ctx, system, 0.8, 1.6)
	thor2d.Set_Particle_Direction(ctx, system, -1.5707964) // up, radians
	thor2d.Set_Particle_Spread(ctx, system, 0.7)
	thor2d.Set_Particle_Speed(ctx, system, 120, 260)
	thor2d.Set_Particle_Gravity(ctx, system, thor2d.Vec2{0, 320})
	thor2d.Set_Particle_Damping(ctx, system, 20, 60)
	thor2d.Set_Particle_Spin(ctx, system, -4, 4)
	thor2d.Set_Particle_Sizes(ctx, system, []f32{10, 7, 3})
	thor2d.Set_Particle_Colors(ctx, system, []thor2d.Color{
		thor2d.Color{255, 220, 120, 255},
		thor2d.Color{255, 140, 60, 255},
		thor2d.Color{255, 80, 40, 0},
	})
	thor2d.Start_Particles(ctx, system)
}

load :: proc(ctx: ^thor2d.Context) {
	thor2d.Set_Background_Color(ctx, thor2d.RGB(14, 18, 30))
	make_system(ctx)
	fmt.println("particles_v10: Up/Down rate, Space pause, R reset, S stop, G start, Esc quit")
}

update :: proc(ctx: ^thor2d.Context, delta: f32) {
	elapsed += f64(delta)
	if os.get_env("THOR2D_SMOKE", context.temp_allocator) == "1" && elapsed >= 1.5 {
		thor2d.Quit(ctx)
		return
	}
	if thor2d.Particle_System_Invalid(system) {
		return
	}
	if thor2d.Key_Pressed(ctx, .Escape) {
		thor2d.Quit(ctx)
		return
	}
	if thor2d.Key_Pressed(ctx, .Up) {
		emission_rate += 50
		thor2d.Set_Particle_Emission_Rate(ctx, system, emission_rate)
	}
	if thor2d.Key_Pressed(ctx, .Down) {
		emission_rate -= 50
		if emission_rate < 0 {
			emission_rate = 0
		}
		thor2d.Set_Particle_Emission_Rate(ctx, system, emission_rate)
	}
	if thor2d.Key_Pressed(ctx, .Space) {
		if thor2d.Is_Particles_Paused(ctx, system) {
			thor2d.Start_Particles(ctx, system)
		} else {
			thor2d.Pause_Particles(ctx, system)
		}
	}
	if thor2d.Key_Pressed(ctx, .R) {
		thor2d.Reset_Particles(ctx, system)
		thor2d.Start_Particles(ctx, system)
	}
	if thor2d.Key_Pressed(ctx, .S) {
		thor2d.Stop_Particles(ctx, system)
	}
	if thor2d.Key_Pressed(ctx, .G) {
		thor2d.Start_Particles(ctx, system)
	}
	thor2d.Update_Particles(ctx, system, delta)
}

draw :: proc(ctx: ^thor2d.Context) {
	thor2d.Clear_Screen(ctx)
	w, h := thor2d.Get_Dimensions(ctx)
	thor2d.Draw_Particles(ctx, system, thor2d.Vec2{f32(w) * 0.5, f32(h) - 60})
	status := fmt.tprintf(
		"rate %.0f  count %d/%d  active %v  paused %v",
		emission_rate,
		thor2d.Get_Particle_Count(ctx, system),
		thor2d.Get_Particle_Max(ctx, system),
		thor2d.Is_Particles_Active(ctx, system),
		thor2d.Is_Particles_Paused(ctx, system),
	)
	thor2d.Print(ctx, status, thor2d.Vec2{16, 16}, thor2d.White)
	thor2d.Print(ctx, "Up/Down rate  Space pause  R reset  S stop  G start", thor2d.Vec2{16, 40}, thor2d.Gray)
}

on_event :: proc(ctx: ^thor2d.Context, event: thor2d.Event) {
	if event.Kind == .Quit {
		thor2d.Quit(ctx)
	}
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D Particles v0.10"
	config.Width = 960
	config.Height = 540
	err := thor2d.Run(config, thor2d.Game{Load = load, Update = update, Draw = draw, On_Event = on_event})
	if err != .None {
		fmt.println("Thor2D error:", thor2d.Error_String(err))
	}
}
