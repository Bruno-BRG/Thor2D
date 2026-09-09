package showcase_v04

import "core:os"
import thor2d "thor2d:thor2d"

image: thor2d.Image_Data
texture: thor2d.Texture
mesh: thor2d.Mesh
world: thor2d.Physics_World
body: thor2d.Physics_Body
elapsed: f32

load :: proc(ctx: ^thor2d.Context) {
	image, _ = thor2d.New_Image_Data(32, 32, thor2d.RGBA(30, 70, 180, 255))
	for y := 0; y < image.Height; y += 1 {
		for x := 0; x < image.Width; x += 1 {
			thor2d.Set_Image_Pixel(&image, x, y, thor2d.RGBA(u8(x*8), u8(y*8), 220, 255))
		}
	}
	texture, _ = thor2d.Create_Texture_From_Image_Data(ctx, &image)
	vertices := []thor2d.Mesh_Vertex{
		{Position = thor2d.Vec2{0, -60}, Color = thor2d.Red},
		{Position = thor2d.Vec2{60, 60}, Color = thor2d.Green},
		{Position = thor2d.Vec2{-60, 60}, Color = thor2d.Blue},
	}
	mesh, _ = thor2d.Create_Mesh(ctx, vertices)
	world, _ = thor2d.Create_Physics_World(ctx)
	body, _ = thor2d.Create_Physics_Body(ctx, world)
	thor2d.Create_Circle_Shape(ctx, body, 16)
}

on_event :: proc(ctx: ^thor2d.Context, event: thor2d.Event) {
	#partial switch event.Kind {
	case .Quit:
		thor2d.Quit(ctx)
	case .Key_Pressed:
		if event.Key == .Escape {
			thor2d.Quit(ctx)
		}
	}
}

update :: proc(ctx: ^thor2d.Context, delta: f32) {
	elapsed += delta
	if os.get_env("THOR2D_SMOKE", context.temp_allocator) == "1" && elapsed >= 0.5 {
		thor2d.Quit(ctx)
	}
}

draw :: proc(ctx: ^thor2d.Context) {
	thor2d.Clear(ctx, thor2d.RGBA(15, 18, 28, 255))
	thor2d.Draw_Texture_Ex(ctx, texture, thor2d.Vec2{100, 100}, elapsed*45, 4, thor2d.White)
	thor2d.Draw_Mesh(ctx, mesh, thor2d.Vec2{480, 270}, elapsed*30, thor2d.Vec2{1, 1}, thor2d.White)
	thor2d.Draw_Text(ctx, "Thor2D v0.4 data + image + mesh", thor2d.Vec2{24, 24}, 24, thor2d.White)
}

shutdown :: proc(ctx: ^thor2d.Context) {
	thor2d.Destroy_All_Physics(ctx)
	thor2d.Unload_Mesh(ctx, mesh)
	thor2d.Unload_Texture(ctx, texture)
	thor2d.Destroy_Image_Data(&image)
}

main :: proc() {
	config := thor2d.Default_Config()
	config.Title = "Thor2D v0.4 Showcase"
	thor2d.Run(config, thor2d.Game{Load = load, Update = update, Draw = draw, Shutdown = shutdown, On_Event = on_event})
}
