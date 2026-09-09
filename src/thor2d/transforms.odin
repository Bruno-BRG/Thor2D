package thor2d

import backend "thor2d:thor2d/internal/raylib"

Begin_Camera :: proc(ctx: ^Context, camera: Camera_2D) {
	if ctx != nil && ctx.backend != nil {
		backend.Begin_Camera(ctx.backend, camera.Target.X, camera.Target.Y, camera.Offset.X, camera.Offset.Y, camera.Rotation, camera.Zoom)
	}
}

End_Camera :: proc(ctx: ^Context) {
	if ctx != nil && ctx.backend != nil {
		backend.End_Camera(ctx.backend)
	}
}

Push_Transform :: proc(ctx: ^Context) {
	if ctx != nil && ctx.backend != nil {
		backend.Push_Transform(ctx.backend)
	}
}

Pop_Transform :: proc(ctx: ^Context) {
	if ctx != nil && ctx.backend != nil {
		backend.Pop_Transform(ctx.backend)
	}
}

Translate :: proc(ctx: ^Context, offset: Vec2) {
	if ctx != nil && ctx.backend != nil {
		backend.Translate(ctx.backend, offset.X, offset.Y)
	}
}

Rotate :: proc(ctx: ^Context, angle: f32) {
	if ctx != nil && ctx.backend != nil {
		backend.Rotate(ctx.backend, angle)
	}
}

Scale :: proc(ctx: ^Context, factor: Vec2) {
	if ctx != nil && ctx.backend != nil {
		backend.Scale(ctx.backend, factor.X, factor.Y)
	}
}

Reset_Transform :: proc(ctx: ^Context) {
	if ctx != nil && ctx.backend != nil {
		backend.Reset_Transform(ctx.backend)
	}
}

World_To_Screen :: proc(ctx: ^Context, camera: Camera_2D, world: Vec2) -> Vec2 {
	if ctx == nil || ctx.backend == nil {
		return Vec2{}
	}
	x, y := backend.Camera_World_To_Screen(ctx.backend, world.X, world.Y, camera.Target.X, camera.Target.Y, camera.Offset.X, camera.Offset.Y, camera.Rotation, camera.Zoom)
	return Vec2{x, y}
}

Screen_To_World :: proc(ctx: ^Context, camera: Camera_2D, screen: Vec2) -> Vec2 {
	if ctx == nil || ctx.backend == nil {
		return Vec2{}
	}
	x, y := backend.Camera_Screen_To_World(ctx.backend, screen.X, screen.Y, camera.Target.X, camera.Target.Y, camera.Offset.X, camera.Offset.Y, camera.Rotation, camera.Zoom)
	return Vec2{x, y}
}
