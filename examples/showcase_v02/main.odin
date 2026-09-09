package showcase_v02

import "core:fmt"
import "core:os"
import thor2d "thor2d:thor2d"

texture: thor2d.Texture
canvas: thor2d.Canvas
shader: thor2d.Shader
quad: thor2d.Quad
batch: thor2d.Sprite_Batch
particles: thor2d.Particle_System
music: thor2d.Music
music_loaded: bool
elapsed: f32
event_count: int
smoke_mode: bool
resize_requested: bool

load :: proc(ctx: ^thor2d.Context) {
	smoke_mode = os.get_env("THOR2D_SMOKE", context.temp_allocator) == "1"
	texture, _ = thor2d.Generate_Texture(ctx, 48, 48, thor2d.RGBA(255, 180, 40, 255))
	canvas, _ = thor2d.Create_Canvas(ctx, 320, 180)
	quad = thor2d.New_Quad_From_Texture(ctx, texture, thor2d.Rect{0, 0, 48, 48})
	batch, _ = thor2d.Create_Sprite_Batch(ctx, texture, 32)

	config := thor2d.Default_Particle_Config(256)
	config.Lifetime_Min = 0.35
	config.Lifetime_Max = 1.2
	config.Emission_Rate = 18
	config.Gravity = thor2d.Vec2{0, 28}
	config.Start_Size = 14
	config.End_Size = 2
	config.Start_Color = thor2d.RGBA(255, 210, 80, 230)
	config.End_Color = thor2d.RGBA(255, 60, 20, 0)
	particles, _ = thor2d.Create_Particles(ctx, texture, config)

	shader_err: thor2d.Error
	shader, shader_err = thor2d.Load_Shader(ctx, "examples/showcase_v02/assets/pulse.vs", "examples/showcase_v02/assets/pulse.fs")
	if shader_err != .None {
		fmt.println("showcase: shader unavailable:", thor2d.Error_String(shader_err))
	}

	if thor2d.File_Exists("examples/showcase_v02/assets/music.wav") {
		music_err: thor2d.Error
		music, music_err = thor2d.Load_Music(ctx, "examples/showcase_v02/assets/music.wav")
		music_loaded = music_err == .None
		if music_loaded {
			thor2d.Play_Music(ctx, music)
		}
	}
}

on_event :: proc(ctx: ^thor2d.Context, event: thor2d.Event) {
	event_count += 1
	#partial switch event.Kind {
	case .Quit:
		thor2d.Quit(ctx)
	case .Key_Pressed:
		if event.Key == .Escape {
			thor2d.Quit(ctx)
		}
	case .Mouse_Button_Pressed:
		thor2d.Emit_Particles(ctx, particles, 24)
	case .Window_Resized:
		if smoke_mode {
			fmt.println("showcase resize event:", event.Width, event.Height)
		}
	}
}

update :: proc(ctx: ^thor2d.Context, delta: f32) {
	elapsed += delta
	thor2d.Update_Particles(ctx, particles, delta)

	thor2d.Clear_Sprite_Batch(ctx, batch)
	for i := 0; i < 8; i += 1 {
		angle := elapsed*45 + f32(i)*45
		position := thor2d.Vec2{430 + f32(i%4)*64, 290 + f32(i/4)*64}
		thor2d.Add_Sprite(ctx, batch, thor2d.Rect{0, 0, 48, 48}, thor2d.Rect{position.X, position.Y, 48, 48}, thor2d.Vec2{24, 24}, angle, thor2d.White)
	}

	if thor2d.Key_Pressed(ctx, .Space) {
		thor2d.Emit_Particles(ctx, particles, 64)
	}
	if smoke_mode && elapsed >= 0.75 {
		thor2d.Quit(ctx)
	}
	if smoke_mode && !resize_requested && elapsed >= 0.2 {
		thor2d.Set_Window_Size(ctx, 800, 480)
		resize_requested = true
	}
}

draw :: proc(ctx: ^thor2d.Context) {
	thor2d.Clear(ctx, thor2d.Color{12, 16, 32, 255})

	camera := thor2d.Camera_2D{Target = thor2d.Vec2{480, 270}, Offset = thor2d.Vec2{480, 270}, Zoom = 1}
	thor2d.Begin_Camera(ctx, camera)
	thor2d.Push_Transform(ctx)
	thor2d.Draw_Rect(ctx, thor2d.Rect{32, 120, 250, 140}, thor2d.RGBA(24, 40, 78, 255))
	thor2d.Draw_Rect_Outline(ctx, thor2d.Rect{32, 120, 250, 140}, 3, thor2d.Blue)
	thor2d.Draw_Text(ctx, "camera + transforms", thor2d.Vec2{48, 144}, 20, thor2d.White)
	thor2d.Rotate(ctx, elapsed*18)
	thor2d.Draw_Texture_Quad(ctx, texture, quad, thor2d.Vec2{206, 194}, elapsed*30, 1.4, thor2d.White)
	thor2d.Pop_Transform(ctx)
	thor2d.End_Camera(ctx)

	thor2d.Set_Canvas(ctx, canvas)
	thor2d.Clear(ctx, thor2d.RGBA(20, 24, 42, 255))
	thor2d.Draw_Circle(ctx, thor2d.Vec2{160, 90}, 55, thor2d.RGBA(30, 150, 240, 255))
	thor2d.Draw_Text(ctx, "Canvas", thor2d.Vec2{120, 82}, 24, thor2d.White)
	thor2d.Reset_Canvas(ctx)

	if !thor2d.Shader_Invalid(shader) {
		thor2d.Set_Shader_Float(ctx, shader, "time", elapsed)
		thor2d.Begin_Shader(ctx, shader)
	}
	thor2d.Draw_Canvas(ctx, canvas, thor2d.Vec2{330, 54}, thor2d.Vec2{1.25, 1.25}, thor2d.White)
	if !thor2d.Shader_Invalid(shader) {
		thor2d.End_Shader(ctx)
	}

	thor2d.Draw_Sprite_Batch(ctx, batch)
	thor2d.Draw_Particles(ctx, particles, thor2d.Vec2{640, 160}, thor2d.White)

	thor2d.Draw_Text(ctx, "Thor2D v0.2 showcase", thor2d.Vec2{28, 24}, 28, thor2d.White)
	thor2d.Draw_Text(ctx, "SPACE emits particles | click emits | ESC quits", thor2d.Vec2{28, 62}, 18, thor2d.Gray)
	thor2d.Draw_Text(ctx, "events:", thor2d.Vec2{28, 500}, 18, thor2d.Green)
	thor2d.Draw_Text(ctx, fmt.aprintf("%d", event_count), thor2d.Vec2{94, 500}, 18, thor2d.White)
}

shutdown :: proc(ctx: ^thor2d.Context) {
	if music_loaded {
		thor2d.Unload_Music(ctx, music)
	}
	thor2d.Unload_Particles(ctx, particles)
	thor2d.Unload_Sprite_Batch(ctx, batch)
	thor2d.Unload_Shader(ctx, shader)
	thor2d.Unload_Canvas(ctx, canvas)
	thor2d.Unload_Texture(ctx, texture)
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D v0.2 Showcase"
	config.Width = 960
	config.Height = 540
	err := thor2d.Run(config, thor2d.Game{Load = load, On_Event = on_event, Update = update, Draw = draw, Shutdown = shutdown})
	if err != .None {
		fmt.println("showcase:", thor2d.Error_String(err))
	}
}
