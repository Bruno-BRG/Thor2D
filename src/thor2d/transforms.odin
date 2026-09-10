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
	if ctx == nil { return }
	append(&ctx.graphics_transform_stack, ctx.graphics_transform)
	if ctx.backend != nil { backend.Push_Transform(ctx.backend) }
}

Pop_Transform :: proc(ctx: ^Context) {
	if ctx == nil || len(ctx.graphics_transform_stack) == 0 { return }
	last := len(ctx.graphics_transform_stack)-1
	ctx.graphics_transform = ctx.graphics_transform_stack[last]
	pop(&ctx.graphics_transform_stack)
	if ctx.backend != nil {
		backend.Pop_Transform(ctx.backend)
		backend.Replace_Transform(ctx.backend, Transform_Get_Matrix(ctx.graphics_transform))
	}
}

Translate :: proc(ctx: ^Context, offset: Vec2) {
	if ctx == nil { return }
	Transform_Translate(&ctx.graphics_transform, offset)
	if ctx.backend != nil { backend.Replace_Transform(ctx.backend, Transform_Get_Matrix(ctx.graphics_transform)) }
}

Rotate :: proc(ctx: ^Context, angle: f32) {
	if ctx == nil { return }
	Transform_Rotate(&ctx.graphics_transform, angle)
	if ctx.backend != nil { backend.Replace_Transform(ctx.backend, Transform_Get_Matrix(ctx.graphics_transform)) }
}

Scale :: proc(ctx: ^Context, factor: Vec2) {
	if ctx == nil { return }
	Transform_Scale(&ctx.graphics_transform, factor)
	if ctx.backend != nil { backend.Replace_Transform(ctx.backend, Transform_Get_Matrix(ctx.graphics_transform)) }
}

Reset_Transform :: proc(ctx: ^Context) {
	if ctx == nil { return }
	ctx.graphics_transform = Identity_Transform()
	clear(&ctx.graphics_transform_stack)
	if ctx.backend != nil { backend.Reset_Transform(ctx.backend) }
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
