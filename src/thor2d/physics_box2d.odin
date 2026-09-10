package thor2d

import "core:c"
import b2 "thor2d:thor2d/internal/box2d"

Physics_Body_Type :: enum {
	Static,
	Kinematic,
	Dynamic,
}

Physics_Body_Def :: struct {
	Type: Physics_Body_Type,
	Position: Vec2,
	Rotation: f32,
	Linear_Velocity: Vec2,
	Angular_Velocity: f32,
	Linear_Damping: f32,
	Angular_Damping: f32,
	Gravity_Scale: f32,
	Fixed_Rotation: bool,
	Bullet: bool,
	Enable_Sleep: bool,
}

Default_Physics_Body_Def :: proc() -> Physics_Body_Def {
	return Physics_Body_Def{Type = .Dynamic, Gravity_Scale = 1, Enable_Sleep = true}
}

Physics_Shape_Def :: struct {
	Density: f32,
	Friction: f32,
	Restitution: f32,
	Sensor: bool,
	Contact_Events: bool,
	Sensor_Events: bool,
	Category_Bits: u64,
	Mask_Bits: u64,
	Group_Index: i32,
}

Default_Physics_Shape_Def :: proc() -> Physics_Shape_Def {
	return Physics_Shape_Def{Density = 1, Friction = 0.5, Restitution = 0.0, Contact_Events = true, Sensor_Events = true}
}

Physics_World_Def :: struct {
	Gravity: Vec2,
	Sub_Steps: int,
}

Default_Physics_World_Def :: proc() -> Physics_World_Def {
	return Physics_World_Def{Gravity = Vec2{0, 980}, Sub_Steps = 4}
}

Physics_World_Entry :: struct {
	handle: u64,
	native: b2.WorldId,
	sub_steps: int,
	events: [dynamic]Physics_Event,
	// v0.10 wave 2: LOVE-style World callbacks (see Set_Physics_Callbacks in
	// physics_extra.odin). Nil means unregistered. They fire post-step from
	// fire_physics_callbacks, after the poll queue is filled.
	on_begin_contact: Physics_Contact_Callback,
	on_end_contact: Physics_Contact_Callback,
	on_pre_solve: Physics_Contact_Callback,
	on_post_solve: Physics_Contact_Callback,
}

Physics_Body_Entry :: struct {
	handle: u64,
	native: b2.BodyId,
	world: u64,
	user_tag: u64,
}

Physics_Shape_Entry :: struct {
	handle: u64,
	native: b2.ShapeId,
	body: u64,
	world: u64,
	chain: b2.ChainId,
	chain_segments: [dynamic]b2.ShapeId,
	user_tag: u64,
}

Physics_Joint_Entry :: struct {
	handle: u64,
	native: b2.JointId,
	world: u64,
}

Physics_State :: struct {
	worlds: [dynamic]Physics_World_Entry,
	bodies: [dynamic]Physics_Body_Entry,
	shapes: [dynamic]Physics_Shape_Entry,
	joints: [dynamic]Physics_Joint_Entry,
	next_handle: u64,
	length_units: f32,
	destroyed: bool,
}

physics_next_handle :: proc(state: ^Physics_State) -> u64 {
	if state.next_handle == 0 {
		state.next_handle = 1
	}
	handle := state.next_handle
	state.next_handle += 1
	return handle
}

find_physics_world :: proc(state: ^Physics_State, handle: u64) -> (^Physics_World_Entry, bool) {
	if state == nil || handle == 0 {
		return nil, false
	}
	for &world in state.worlds {
		if world.handle == handle {
			return &world, true
		}
	}
	return nil, false
}

find_physics_body :: proc(state: ^Physics_State, handle: u64) -> (^Physics_Body_Entry, bool) {
	if state == nil || handle == 0 {
		return nil, false
	}
	for &body in state.bodies {
		if body.handle == handle {
			return &body, true
		}
	}
	return nil, false
}

find_physics_shape :: proc(state: ^Physics_State, handle: u64) -> (^Physics_Shape_Entry, bool) {
	if state == nil || handle == 0 {
		return nil, false
	}
	for &shape in state.shapes {
		if shape.handle == handle {
			return &shape, true
		}
	}
	return nil, false
}

find_public_body_by_native :: proc(state: ^Physics_State, native: b2.BodyId) -> Physics_Body {
	if state != nil {
		for body in state.bodies {
			if body.native == native {
				return Physics_Body{body.handle}
			}
		}
	}
	return Physics_Body{}
}

find_public_shape_by_native :: proc(state: ^Physics_State, native: b2.ShapeId) -> Physics_Shape {
	if state != nil {
		for shape in state.shapes {
			if shape.native == native {
				return Physics_Shape{shape.handle}
			}
			for segment in shape.chain_segments {
				if segment == native {
					return Physics_Shape{shape.handle}
				}
			}
		}
	}
	return Physics_Shape{}
}

Create_Physics_World :: proc(ctx: ^Context, def := Physics_World_Def{Gravity = Vec2{0, 980}, Sub_Steps = 4}) -> (Physics_World, Error) {
	if ctx == nil {
		return Physics_World{}, .Invalid_Config
	}
	if ctx.config.Pixels_Per_Meter <= 0 {
		return Physics_World{}, .Invalid_Config
	}
	if ctx.physics.length_units == 0 {
		b2.SetLengthUnitsPerMeter(ctx.config.Pixels_Per_Meter)
		ctx.physics.length_units = ctx.config.Pixels_Per_Meter
	}
	ctx.physics.destroyed = false
	native_def := b2.DefaultWorldDef()
	native := b2.CreateWorld(native_def)
	if !b2.World_IsValid(native) {
		return Physics_World{}, .Resource_Load_Failed
	}
	b2.World_SetGravity(native, b2.Vec2{def.Gravity.X, def.Gravity.Y})
	handle := physics_next_handle(&ctx.physics)
	sub_steps := def.Sub_Steps
	if sub_steps <= 0 {
		sub_steps = 4
	}
	append(&ctx.physics.worlds, Physics_World_Entry{handle = handle, native = native, sub_steps = sub_steps})
	return Physics_World{handle}, .None
}

Destroy_Physics_World :: proc(ctx: ^Context, world: Physics_World) {
	if ctx == nil {
		return
	}
	entry, ok := find_physics_world(&ctx.physics, world.handle)
	if !ok {
		return
	}
	b2.DestroyWorld(entry.native)
	for i := len(ctx.physics.shapes)-1; i >= 0; i -= 1 {
		if ctx.physics.shapes[i].world == world.handle {
			delete(ctx.physics.shapes[i].chain_segments)
			unordered_remove(&ctx.physics.shapes, i)
		}
	}
	for i := len(ctx.physics.bodies)-1; i >= 0; i -= 1 {
		if ctx.physics.bodies[i].world == world.handle {
			unordered_remove(&ctx.physics.bodies, i)
		}
	}
	for i := len(ctx.physics.joints)-1; i >= 0; i -= 1 {
		if ctx.physics.joints[i].world == world.handle {
			unordered_remove(&ctx.physics.joints, i)
		}
	}
	for i := 0; i < len(ctx.physics.worlds); i += 1 {
		if ctx.physics.worlds[i].handle == world.handle {
			delete(ctx.physics.worlds[i].events)
			unordered_remove(&ctx.physics.worlds, i)
			return
		}
	}
}

Destroy_All_Physics :: proc(ctx: ^Context) {
	if ctx == nil {
		return
	}
	if ctx.physics.destroyed {
		return
	}
	for len(ctx.physics.worlds) > 0 {
		Destroy_Physics_World(ctx, Physics_World{ctx.physics.worlds[len(ctx.physics.worlds)-1].handle})
	}
	delete(ctx.physics.worlds)
	delete(ctx.physics.bodies)
	delete(ctx.physics.shapes)
	delete(ctx.physics.joints)
	ctx.physics.destroyed = true
}

Set_Physics_Gravity :: proc(ctx: ^Context, world: Physics_World, gravity: Vec2) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_world(&ctx.physics, world.handle); ok {
		b2.World_SetGravity(entry.native, b2.Vec2{gravity.X, gravity.Y})
	}
}

Physics_Body_Type_Native :: proc(kind: Physics_Body_Type) -> b2.BodyType {
	switch kind {
	case .Static:
		return b2.BodyType(0)
	case .Kinematic:
		return b2.BodyType(1)
	case .Dynamic:
		return b2.BodyType(2)
	}
	return b2.BodyType(2)
}

Create_Physics_Body :: proc(ctx: ^Context, world: Physics_World, def := Physics_Body_Def{Type = .Dynamic, Gravity_Scale = 1, Enable_Sleep = true}) -> (Physics_Body, Error) {
	if ctx == nil {
		return Physics_Body{}, .Invalid_Config
	}
	world_entry, ok := find_physics_world(&ctx.physics, world.handle)
	if !ok {
		return Physics_Body{}, .Invalid_Handle
	}
	native_def := b2.DefaultBodyDef()
	native := b2.CreateBody(world_entry.native, native_def)
	if !b2.Body_IsValid(native) {
		return Physics_Body{}, .Resource_Load_Failed
	}
	b2.Body_SetType(native, Physics_Body_Type_Native(def.Type))
	b2.Body_SetTransform(native, b2.Vec2{def.Position.X, def.Position.Y}, b2.MakeRot(def.Rotation))
	b2.Body_SetLinearVelocity(native, b2.Vec2{def.Linear_Velocity.X, def.Linear_Velocity.Y})
	b2.Body_SetAngularVelocity(native, def.Angular_Velocity)
	b2.Body_SetLinearDamping(native, def.Linear_Damping)
	b2.Body_SetAngularDamping(native, def.Angular_Damping)
	b2.Body_SetGravityScale(native, def.Gravity_Scale)
	b2.Body_SetFixedRotation(native, def.Fixed_Rotation)
	b2.Body_SetBullet(native, def.Bullet)
	b2.Body_EnableSleep(native, def.Enable_Sleep)
	handle := physics_next_handle(&ctx.physics)
	append(&ctx.physics.bodies, Physics_Body_Entry{handle = handle, native = native, world = world.handle})
	return Physics_Body{handle}, .None
}

Destroy_Physics_Body :: proc(ctx: ^Context, body: Physics_Body) {
	if ctx == nil {
		return
	}
	entry, ok := find_physics_body(&ctx.physics, body.handle)
	if !ok {
		return
	}
	b2.DestroyBody(entry.native)
	for i := len(ctx.physics.shapes)-1; i >= 0; i -= 1 {
		if ctx.physics.shapes[i].body == body.handle {
			if b2.Chain_IsValid(ctx.physics.shapes[i].chain) {
				b2.DestroyChain(ctx.physics.shapes[i].chain)
			}
			delete(ctx.physics.shapes[i].chain_segments)
			unordered_remove(&ctx.physics.shapes, i)
		}
	}
	for i := 0; i < len(ctx.physics.bodies); i += 1 {
		if ctx.physics.bodies[i].handle == body.handle {
			unordered_remove(&ctx.physics.bodies, i)
			return
		}
	}
}

Create_Box_Shape :: proc(ctx: ^Context, body: Physics_Body, width, height: f32, def := Physics_Shape_Def{Density = 1, Friction = 0.5, Contact_Events = true, Sensor_Events = true}) -> (Physics_Shape, Error) {
	if ctx == nil {
		return Physics_Shape{}, .Invalid_Config
	}
	body_entry, ok := find_physics_body(&ctx.physics, body.handle)
	if !ok || !b2.Body_IsValid(body_entry.native) {
		return Physics_Shape{}, .Invalid_Handle
	}
	native := b2.Thor2D_Create_Box_Shape(body_entry.native, width*0.5, height*0.5, def.Density, def.Friction, def.Restitution, def.Sensor, def.Contact_Events, def.Sensor_Events, def.Category_Bits, def.Mask_Bits, def.Group_Index)
	if !b2.Shape_IsValid(native) {
		return Physics_Shape{}, .Resource_Load_Failed
	}
	handle := physics_next_handle(&ctx.physics)
	append(&ctx.physics.shapes, Physics_Shape_Entry{handle = handle, native = native, body = body.handle, world = body_entry.world})
	return Physics_Shape{handle}, .None
}

Create_Circle_Shape :: proc(ctx: ^Context, body: Physics_Body, radius: f32, def := Physics_Shape_Def{Density = 1, Friction = 0.5, Contact_Events = true, Sensor_Events = true}) -> (Physics_Shape, Error) {
	if ctx == nil {
		return Physics_Shape{}, .Invalid_Config
	}
	body_entry, ok := find_physics_body(&ctx.physics, body.handle)
	if !ok || !b2.Body_IsValid(body_entry.native) {
		return Physics_Shape{}, .Invalid_Handle
	}
	native := b2.Thor2D_Create_Circle_Shape(body_entry.native, radius, def.Density, def.Friction, def.Restitution, def.Sensor, def.Contact_Events, def.Sensor_Events, def.Category_Bits, def.Mask_Bits, def.Group_Index)
	if !b2.Shape_IsValid(native) {
		return Physics_Shape{}, .Resource_Load_Failed
	}
	handle := physics_next_handle(&ctx.physics)
	append(&ctx.physics.shapes, Physics_Shape_Entry{handle = handle, native = native, body = body.handle, world = body_entry.world})
	return Physics_Shape{handle}, .None
}

Create_Segment_Shape :: proc(ctx: ^Context, body: Physics_Body, a, b: Vec2, def := Physics_Shape_Def{Density = 1, Friction = 0.5, Contact_Events = true, Sensor_Events = true}) -> (Physics_Shape, Error) {
	if ctx == nil {
		return Physics_Shape{}, .Invalid_Config
	}
	body_entry, ok := find_physics_body(&ctx.physics, body.handle)
	if !ok || !b2.Body_IsValid(body_entry.native) {
		return Physics_Shape{}, .Invalid_Handle
	}
	native := b2.Thor2D_Create_Segment_Shape(body_entry.native, a.X, a.Y, b.X, b.Y, def.Density, def.Friction, def.Restitution, def.Sensor, def.Contact_Events, def.Sensor_Events, def.Category_Bits, def.Mask_Bits, def.Group_Index)
	if !b2.Shape_IsValid(native) {
		return Physics_Shape{}, .Resource_Load_Failed
	}
	handle := physics_next_handle(&ctx.physics)
	append(&ctx.physics.shapes, Physics_Shape_Entry{handle = handle, native = native, body = body.handle, world = body_entry.world})
	return Physics_Shape{handle}, .None
}

Create_Capsule_Shape :: proc(ctx: ^Context, body: Physics_Body, half_length, radius: f32, def := Physics_Shape_Def{Density = 1, Friction = 0.5, Contact_Events = true, Sensor_Events = true}) -> (Physics_Shape, Error) {
	if ctx == nil {
		return Physics_Shape{}, .Invalid_Config
	}
	body_entry, ok := find_physics_body(&ctx.physics, body.handle)
	if !ok || !b2.Body_IsValid(body_entry.native) || half_length < 0 || radius <= 0 {
		return Physics_Shape{}, .Invalid_Handle
	}
	native := b2.Thor2D_Create_Capsule_Shape(body_entry.native, half_length, radius, def.Density, def.Friction, def.Restitution, def.Sensor, def.Contact_Events, def.Sensor_Events, def.Category_Bits, def.Mask_Bits, def.Group_Index)
	if !b2.Shape_IsValid(native) {
		return Physics_Shape{}, .Resource_Load_Failed
	}
	handle := physics_next_handle(&ctx.physics)
	append(&ctx.physics.shapes, Physics_Shape_Entry{handle = handle, native = native, body = body.handle, world = body_entry.world})
	return Physics_Shape{handle}, .None
}

Create_Polygon_Shape :: proc(ctx: ^Context, body: Physics_Body, points: []Vec2, radius: f32 = 0, def := Physics_Shape_Def{Density = 1, Friction = 0.5, Contact_Events = true, Sensor_Events = true}) -> (Physics_Shape, Error) {
	if ctx == nil || len(points) < 3 {
		return Physics_Shape{}, .Invalid_Data
	}
	body_entry, ok := find_physics_body(&ctx.physics, body.handle)
	if !ok {
		return Physics_Shape{}, .Invalid_Handle
	}
	native_points := make([dynamic]b2.Vec2, len(points))
	defer delete(native_points)
	for point, i in points {
		native_points[i] = b2.Vec2{point.X, point.Y}
	}
	native := b2.Thor2D_Create_Polygon_Shape(body_entry.native, native_points[:], radius, def.Density, def.Friction, def.Restitution, def.Sensor, def.Contact_Events, def.Sensor_Events, def.Category_Bits, def.Mask_Bits, def.Group_Index)
	if !b2.Shape_IsValid(native) {
		return Physics_Shape{}, .Resource_Load_Failed
	}
	handle := physics_next_handle(&ctx.physics)
	append(&ctx.physics.shapes, Physics_Shape_Entry{handle = handle, native = native, body = body.handle, world = body_entry.world})
	return Physics_Shape{handle}, .None
}

// Create_Chain_Shape creates a native Box2D chain. Box2D expands a chain into
// segment shapes internally; Thor2D keeps those ids private and exposes one
// stable handle to the game.
Create_Chain_Shape :: proc(ctx: ^Context, body: Physics_Body, points: []Vec2, loop := false, def := Physics_Shape_Def{Friction = 0.5, Restitution = 0.0}) -> (Physics_Shape, Error) {
	if ctx == nil || len(points) < 4 {
		return Physics_Shape{}, .Invalid_Data
	}
	body_entry, ok := find_physics_body(&ctx.physics, body.handle)
	if !ok || !b2.Body_IsValid(body_entry.native) {
		return Physics_Shape{}, .Invalid_Handle
	}
	native_points := make([dynamic]b2.Vec2, len(points))
	defer delete(native_points)
	for point, i in points {
		native_points[i] = b2.Vec2{point.X, point.Y}
	}
	chain := b2.Thor2D_Create_Chain_Shape(body_entry.native, native_points[:], loop, def.Friction, def.Restitution, def.Category_Bits, def.Mask_Bits, def.Group_Index)
	if !b2.Chain_IsValid(chain) {
		return Physics_Shape{}, .Resource_Load_Failed
	}
	segment_count := int(b2.Chain_GetSegmentCount(chain))
	segments := make([dynamic]b2.ShapeId, max(segment_count, 0))
	if segment_count > 0 {
		segment_count = int(b2.Chain_GetSegments(chain, raw_data(segments), c.int(len(segments))))
		trimmed := make([dynamic]b2.ShapeId, segment_count)
		copy(trimmed[:], segments[:segment_count])
		delete(segments)
		segments = trimmed
	}
	handle := physics_next_handle(&ctx.physics)
	append(&ctx.physics.shapes, Physics_Shape_Entry{
		handle = handle,
		native = b2.ShapeId{},
		body = body.handle,
		world = body_entry.world,
		chain = chain,
		chain_segments = segments,
	})
	return Physics_Shape{handle}, .None
}

Create_Physics_Joint :: proc(ctx: ^Context, world: Physics_World, def: Physics_Joint_Def) -> (Physics_Joint, Error) {
	if ctx == nil {
		return Physics_Joint{}, .Invalid_Config
	}
	world_entry, world_ok := find_physics_world(&ctx.physics, world.handle)
	body_a, body_a_ok := find_physics_body(&ctx.physics, def.Body_A.handle)
	body_b, body_b_ok := find_physics_body(&ctx.physics, def.Body_B.handle)
	if !world_ok || !body_a_ok || !body_b_ok || body_a.world != world.handle || body_b.world != world.handle {
		return Physics_Joint{}, .Invalid_Handle
	}
	native: b2.JointId
	switch def.Kind {
	case .Distance:
		native = b2.Thor2D_Create_Distance_Joint(world_entry.native, body_a.native, body_b.native, b2.Vec2{def.Anchor_A.X, def.Anchor_A.Y}, b2.Vec2{def.Anchor_B.X, def.Anchor_B.Y}, def.Length, def.Collide_Connected)
	case .Revolute:
		native = b2.Thor2D_Create_Revolute_Joint(world_entry.native, body_a.native, body_b.native, b2.Vec2{def.Anchor_A.X, def.Anchor_A.Y}, b2.Vec2{def.Anchor_B.X, def.Anchor_B.Y}, def.Collide_Connected)
	case .Weld:
		native = b2.Thor2D_Create_Weld_Joint(world_entry.native, body_a.native, body_b.native, b2.Vec2{def.Anchor_A.X, def.Anchor_A.Y}, b2.Vec2{def.Anchor_B.X, def.Anchor_B.Y}, def.Collide_Connected)
	case .Motor:
		native = b2.Thor2D_Create_Motor_Joint(world_entry.native, body_a.native, body_b.native, b2.Vec2{def.Anchor_A.X, def.Anchor_A.Y}, def.Angular_Offset, def.Max_Force, def.Max_Torque, def.Collide_Connected)
	case .Mouse:
		native = b2.Thor2D_Create_Mouse_Joint(world_entry.native, body_a.native, body_b.native, b2.Vec2{def.Target.X, def.Target.Y}, def.Max_Force, def.Collide_Connected)
	case .Prismatic:
		native = b2.Thor2D_Create_Prismatic_Joint(world_entry.native, body_a.native, body_b.native, b2.Vec2{def.Anchor_A.X, def.Anchor_A.Y}, b2.Vec2{def.Anchor_B.X, def.Anchor_B.Y}, b2.Vec2{def.Axis.X, def.Axis.Y}, def.Collide_Connected)
	case .Wheel:
		native = b2.Thor2D_Create_Wheel_Joint(world_entry.native, body_a.native, body_b.native, b2.Vec2{def.Anchor_A.X, def.Anchor_A.Y}, b2.Vec2{def.Anchor_B.X, def.Anchor_B.Y}, b2.Vec2{def.Axis.X, def.Axis.Y}, def.Collide_Connected)
	case .Pulley, .Rope, .Friction, .Gear:
		// Box2D 3.x removed these joint types. Return an explicit error so
		// LOVE ports fail loudly instead of getting a fake handle.
		return Physics_Joint{}, .Unsupported
	}
	if !b2.Joint_IsValid(native) {
		return Physics_Joint{}, .Resource_Load_Failed
	}
	handle := physics_next_handle(&ctx.physics)
	append(&ctx.physics.joints, Physics_Joint_Entry{handle, native, world.handle})
	return Physics_Joint{handle}, .None
}

Destroy_Physics_Joint :: proc(ctx: ^Context, joint: Physics_Joint) {
	if ctx == nil {
		return
	}
	for i := 0; i < len(ctx.physics.joints); i += 1 {
		if ctx.physics.joints[i].handle == joint.handle {
			b2.DestroyJoint(ctx.physics.joints[i].native)
			unordered_remove(&ctx.physics.joints, i)
			return
		}
	}
}

Physics_Raycast_Closest :: proc(ctx: ^Context, world: Physics_World, origin, translation: Vec2) -> Physics_Raycast_Hit {
	if ctx == nil {
		return Physics_Raycast_Hit{}
	}
	world_entry, ok := find_physics_world(&ctx.physics, world.handle)
	if !ok {
		return Physics_Raycast_Hit{}
	}
	native := b2.Thor2D_Raycast_Closest(world_entry.native, b2.Vec2{origin.X, origin.Y}, b2.Vec2{translation.X, translation.Y})
	shape := find_public_shape_by_native(&ctx.physics, native.Shape)
	body := Physics_Body{}
	if shape_entry, shape_ok := find_physics_shape(&ctx.physics, shape.handle); shape_ok {
		body = Physics_Body{shape_entry.body}
	}
	return Physics_Raycast_Hit{Hit = native.Hit, Shape = shape, Body = body, Point = Vec2{native.Point[0], native.Point[1]}, Normal = Vec2{native.Normal[0], native.Normal[1]}, Fraction = native.Fraction}
}

Physics_Query_Accumulator :: struct {
	shapes: [256]b2.ShapeId,
	points: [256]b2.Vec2,
	normals: [256]b2.Vec2,
	fractions: [256]f32,
	count: int,
}

physics_query_body :: proc(state: ^Physics_State, shape: Physics_Shape) -> Physics_Body {
	if state != nil {
		if entry, ok := find_physics_shape(state, shape.handle); ok {
			return Physics_Body{entry.body}
		}
	}
	return Physics_Body{}
}

physics_overlap_callback :: proc "c" (native: b2.ShapeId, callback_ctx: rawptr) -> bool {
	if callback_ctx == nil {
		return false
	}
	accumulator := cast(^Physics_Query_Accumulator)callback_ctx
	if accumulator.count < len(accumulator.shapes) {
		accumulator.shapes[accumulator.count] = native
		accumulator.count += 1
	}
	return accumulator.count < len(accumulator.shapes)
}

physics_raycast_callback :: proc "c" (native: b2.ShapeId, point, normal: b2.Vec2, fraction: f32, callback_ctx: rawptr) -> f32 {
	if callback_ctx == nil {
		return 0
	}
	accumulator := cast(^Physics_Query_Accumulator)callback_ctx
	if accumulator.count < len(accumulator.shapes) {
		index := accumulator.count
		accumulator.shapes[index] = native
		accumulator.points[index] = point
		accumulator.normals[index] = normal
		accumulator.fractions[index] = fraction
		accumulator.count += 1
	}
	return 1
}

append_physics_query_results :: proc(state: ^Physics_State, accumulator: ^Physics_Query_Accumulator, results: ^[dynamic]Physics_Query_Result, include_geometry: bool) {
	if state == nil || accumulator == nil || results == nil {
		return
	}
	for i := 0; i < accumulator.count; i += 1 {
		shape := find_public_shape_by_native(state, accumulator.shapes[i])
		if shape.handle == 0 {
			continue
		}
		result := Physics_Query_Result{Shape = shape, Body = physics_query_body(state, shape)}
		if include_geometry {
			result.Point = Vec2{accumulator.points[i][0], accumulator.points[i][1]}
			result.Normal = Vec2{accumulator.normals[i][0], accumulator.normals[i][1]}
			result.Fraction = accumulator.fractions[i]
		}
		append(results, result)
	}
}

// Physics_Overlap_AABB returns all public shapes potentially overlapping the
// rectangle. The returned dynamic array belongs to the caller and uses the
// current Odin allocator.
Physics_Overlap_AABB :: proc(ctx: ^Context, world: Physics_World, bounds: Rect, filter := Physics_Query_Filter{}) -> [dynamic]Physics_Query_Result {
	results: [dynamic]Physics_Query_Result
	if ctx == nil {
		return results
	}
	world_entry, ok := find_physics_world(&ctx.physics, world.handle)
	if !ok {
		return results
	}
	points := [2]b2.Vec2{{bounds.X, bounds.Y}, {bounds.X + bounds.W, bounds.Y + bounds.H}}
	native_filter := b2.Thor2D_Make_Query_Filter(filter.Category_Bits, filter.Mask_Bits)
	accumulator := Physics_Query_Accumulator{}
	stats := b2.World_OverlapAABB(world_entry.native, b2.MakeAABB(points[:], 0), native_filter, physics_overlap_callback, rawptr(&accumulator))
	_ = stats
	append_physics_query_results(&ctx.physics, &accumulator, &results, false)
	return results
}

// Physics_Raycast_All preserves every hit in callback order. Use
// Physics_Raycast_Closest when only the nearest hit is needed.
Physics_Raycast_All :: proc(ctx: ^Context, world: Physics_World, origin, translation: Vec2, filter := Physics_Query_Filter{}) -> [dynamic]Physics_Query_Result {
	results: [dynamic]Physics_Query_Result
	if ctx == nil {
		return results
	}
	world_entry, ok := find_physics_world(&ctx.physics, world.handle)
	if !ok {
		return results
	}
	native_filter := b2.Thor2D_Make_Query_Filter(filter.Category_Bits, filter.Mask_Bits)
	accumulator := Physics_Query_Accumulator{}
	stats := b2.World_CastRay(world_entry.native, b2.Vec2{origin.X, origin.Y}, b2.Vec2{translation.X, translation.Y}, native_filter, physics_raycast_callback, rawptr(&accumulator))
	_ = stats
	append_physics_query_results(&ctx.physics, &accumulator, &results, true)
	return results
}

// Physics_Shape_Cast_Circle sweeps a circle through the world and returns
// every hit collected by Box2D. The callback is bounded to keep native query
// code allocation-free; callers can split a long sweep when they need more
// than 256 results.
Physics_Shape_Cast_Circle :: proc(ctx: ^Context, world: Physics_World, origin: Vec2, radius: f32, translation: Vec2, filter := Physics_Query_Filter{}) -> [dynamic]Physics_Query_Result {
	results: [dynamic]Physics_Query_Result
	if ctx == nil || radius <= 0 {
		return results
	}
	world_entry, ok := find_physics_world(&ctx.physics, world.handle)
	if !ok {
		return results
	}
	points := make([dynamic]b2.Vec2, 1)
	points[0] = b2.Vec2{origin.X, origin.Y}
	defer delete(points)
	proxy := b2.MakeProxy(points[:], radius)
	native_filter := b2.Thor2D_Make_Query_Filter(filter.Category_Bits, filter.Mask_Bits)
	accumulator := Physics_Query_Accumulator{}
	stats := b2.World_CastShape(world_entry.native, proxy, b2.Vec2{translation.X, translation.Y}, native_filter, physics_raycast_callback, rawptr(&accumulator))
	_ = stats
	append_physics_query_results(&ctx.physics, &accumulator, &results, true)
	return results
}

Physics_Shape_Contains_Point :: proc(ctx: ^Context, shape: Physics_Shape, point: Vec2) -> bool {
	if ctx == nil {
		return false
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	return ok && b2.Shape_IsValid(entry.native) && b2.Shape_TestPoint(entry.native, b2.Vec2{point.X, point.Y})
}

Physics_Chain_Segment_Count :: proc(ctx: ^Context, shape: Physics_Shape) -> int {
	if ctx == nil {
		return 0
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	if !ok || !b2.Chain_IsValid(entry.chain) {
		return 0
	}
	return len(entry.chain_segments)
}

Physics_Shape_Bounds :: proc(ctx: ^Context, shape: Physics_Shape) -> Rect {
	if ctx == nil {
		return Rect{}
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	if !ok {
		return Rect{}
	}
	if b2.Shape_IsValid(entry.native) {
		aabb := b2.Shape_GetAABB(entry.native)
		return Rect{aabb.lowerBound[0], aabb.lowerBound[1], aabb.upperBound[0]-aabb.lowerBound[0], aabb.upperBound[1]-aabb.lowerBound[1]}
	}
	if len(entry.chain_segments) == 0 {
		return Rect{}
	}
	first := b2.Shape_GetAABB(entry.chain_segments[0])
	lower_x, lower_y := first.lowerBound[0], first.lowerBound[1]
	upper_x, upper_y := first.upperBound[0], first.upperBound[1]
	for segment in entry.chain_segments[1:] {
		aabb := b2.Shape_GetAABB(segment)
		lower_x = min(lower_x, aabb.lowerBound[0])
		lower_y = min(lower_y, aabb.lowerBound[1])
		upper_x = max(upper_x, aabb.upperBound[0])
		upper_y = max(upper_y, aabb.upperBound[1])
	}
	return Rect{lower_x, lower_y, upper_x-lower_x, upper_y-lower_y}
}

// Draw_Physics_Debug draws stable public AABBs. It intentionally avoids
// exposing Box2D's DebugDraw callbacks while still providing an immediately
// useful visualizer for all native shapes, including chain segments.
Draw_Physics_Debug :: proc(ctx: ^Context, world: Physics_World, color := Color{80, 220, 120, 180}) {
	if ctx == nil || ctx.backend == nil {
		return
	}
	for shape in ctx.physics.shapes {
		if shape.world != world.handle {
			continue
		}
		bounds := Physics_Shape_Bounds(ctx, Physics_Shape{shape.handle})
		if bounds.W > 0 && bounds.H > 0 {
			Draw_Rect_Outline(ctx, bounds, 1, color)
		}
	}
}

Destroy_Physics_Shape :: proc(ctx: ^Context, shape: Physics_Shape) {
	if ctx == nil {
		return
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	if !ok {
		return
	}
	b2.DestroyShape(entry.native, true)
	for i := 0; i < len(ctx.physics.shapes); i += 1 {
		if ctx.physics.shapes[i].handle == shape.handle {
			if b2.Chain_IsValid(ctx.physics.shapes[i].chain) {
				b2.DestroyChain(ctx.physics.shapes[i].chain)
			}
			delete(ctx.physics.shapes[i].chain_segments)
			unordered_remove(&ctx.physics.shapes, i)
			return
		}
	}
}

Physics_Body_Position :: proc(ctx: ^Context, body: Physics_Body) -> Vec2 {
	if ctx == nil {
		return Vec2{}
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		position := b2.Body_GetPosition(entry.native)
		return Vec2{position[0], position[1]}
	}
	return Vec2{}
}

Physics_Body_Rotation :: proc(ctx: ^Context, body: Physics_Body) -> f32 {
	if ctx == nil {
		return 0
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		return b2.Thor2D_Rotation_Angle(b2.Body_GetRotation(entry.native))
	}
	return 0
}

Physics_Body_Set_Transform :: proc(ctx: ^Context, body: Physics_Body, position: Vec2, rotation: f32) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_SetTransform(entry.native, b2.Vec2{position.X, position.Y}, b2.MakeRot(rotation))
	}
}

Physics_Body_Set_Linear_Velocity :: proc(ctx: ^Context, body: Physics_Body, velocity: Vec2) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_SetLinearVelocity(entry.native, b2.Vec2{velocity.X, velocity.Y})
	}
}

Physics_Body_Linear_Velocity :: proc(ctx: ^Context, body: Physics_Body) -> Vec2 {
	if ctx == nil {
		return Vec2{}
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		velocity := b2.Body_GetLinearVelocity(entry.native)
		return Vec2{velocity[0], velocity[1]}
	}
	return Vec2{}
}

Physics_Body_Angular_Velocity :: proc(ctx: ^Context, body: Physics_Body) -> f32 {
	if ctx == nil {
		return 0
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		return b2.Body_GetAngularVelocity(entry.native)
	}
	return 0
}

Physics_Body_Apply_Force :: proc(ctx: ^Context, body: Physics_Body, force, point: Vec2, wake := true) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_ApplyForce(entry.native, b2.Vec2{force.X, force.Y}, b2.Vec2{point.X, point.Y}, wake)
	}
}

Physics_Body_Apply_Impulse :: proc(ctx: ^Context, body: Physics_Body, impulse, point: Vec2, wake := true) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_ApplyLinearImpulse(entry.native, b2.Vec2{impulse.X, impulse.Y}, b2.Vec2{point.X, point.Y}, wake)
	}
}

Physics_Body_Apply_Force_Center :: proc(ctx: ^Context, body: Physics_Body, force: Vec2, wake := true) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_ApplyForceToCenter(entry.native, b2.Vec2{force.X, force.Y}, wake)
	}
}

Physics_Body_Apply_Torque :: proc(ctx: ^Context, body: Physics_Body, torque: f32, wake := true) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_ApplyTorque(entry.native, torque, wake)
	}
}

Physics_Body_Apply_Impulse_Center :: proc(ctx: ^Context, body: Physics_Body, impulse: Vec2, wake := true) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_ApplyLinearImpulseToCenter(entry.native, b2.Vec2{impulse.X, impulse.Y}, wake)
	}
}

Physics_Body_Apply_Angular_Impulse :: proc(ctx: ^Context, body: Physics_Body, impulse: f32, wake := true) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_ApplyAngularImpulse(entry.native, impulse, wake)
	}
}

Physics_Body_Set_Awake :: proc(ctx: ^Context, body: Physics_Body, awake: bool) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_SetAwake(entry.native, awake)
	}
}

Physics_Body_Is_Awake :: proc(ctx: ^Context, body: Physics_Body) -> bool {
	if ctx == nil {
		return false
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		return b2.Body_IsAwake(entry.native)
	}
	return false
}

Physics_Body_Set_User_Tag :: proc(ctx: ^Context, body: Physics_Body, tag: u64) -> Error {
	if ctx == nil {
		return .Invalid_Handle
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		entry.user_tag = tag
		return .None
	}
	return .Invalid_Handle
}

Physics_Body_User_Tag :: proc(ctx: ^Context, body: Physics_Body) -> u64 {
	if ctx == nil {
		return 0
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		return entry.user_tag
	}
	return 0
}

Physics_Shape_Set_User_Tag :: proc(ctx: ^Context, shape: Physics_Shape, tag: u64) -> Error {
	if ctx == nil {
		return .Invalid_Handle
	}
	if entry, ok := find_physics_shape(&ctx.physics, shape.handle); ok {
		entry.user_tag = tag
		return .None
	}
	return .Invalid_Handle
}

Physics_Shape_User_Tag :: proc(ctx: ^Context, shape: Physics_Shape) -> u64 {
	if ctx == nil {
		return 0
	}
	if entry, ok := find_physics_shape(&ctx.physics, shape.handle); ok {
		return entry.user_tag
	}
	return 0
}

queue_physics_contact :: proc(
	state: ^Physics_State,
	world: ^Physics_World_Entry,
	event_kind: Physics_Event_Kind,
	native_a, native_b: b2.ShapeId,
	position := Vec2{},
	normal := Vec2{},
	normal_impulse := f32(0),
	tangent_impulse := f32(0),
	approach_speed := f32(0),
) {
	shape_a := find_public_shape_by_native(state, native_a)
	shape_b := find_public_shape_by_native(state, native_b)
	body_a := Physics_Body{}
	body_b := Physics_Body{}
	if entry, ok := find_physics_shape(state, shape_a.handle); ok {
		body_a = Physics_Body{entry.body}
	}
	if entry, ok := find_physics_shape(state, shape_b.handle); ok {
		body_b = Physics_Body{entry.body}
	}
	append(&world.events, Physics_Event{
		Kind = event_kind,
		Body_A = body_a,
		Body_B = body_b,
		Shape_A = shape_a,
		Shape_B = shape_b,
		Position = position,
		Normal = normal,
		Normal_Impulse = normal_impulse,
		Tangent_Impulse = tangent_impulse,
		Approach_Speed = approach_speed,
	})
}

Step_Physics :: proc(ctx: ^Context, world: Physics_World, delta := f32(1.0/60.0)) {
	if ctx == nil || delta <= 0 {
		return
	}
	entry, ok := find_physics_world(&ctx.physics, world.handle)
	if !ok {
		return
	}
	if entry.on_post_solve != nil {
		// Hit events back the post_solve callback and are opt-in per shape
		// in Box2D. Refresh here (not just at registration) so shapes
		// created after Set_Physics_Callbacks report too. Worlds without a
		// post_solve callback keep the exact prior event stream.
		physics_set_hit_events(ctx, entry, true)
	}
	b2.World_Step(entry.native, delta, c.int(entry.sub_steps))
	clear(&entry.events)
	begin: [dynamic]b2.Thor2D_Contact_Event
	end: [dynamic]b2.Thor2D_Contact_Event
	sensor_begin: [dynamic]b2.Thor2D_Sensor_Event
	sensor_end: [dynamic]b2.Thor2D_Sensor_Event
	b2.Thor2D_Collect_Contact_Events(entry.native, &begin, &end)
	b2.Thor2D_Collect_Sensor_Events(entry.native, &sensor_begin, &sensor_end)
	for event in begin {
		queue_physics_contact(&ctx.physics, entry, .Contact_Begin, event.Shape_A, event.Shape_B, Vec2{event.Position[0], event.Position[1]}, Vec2{event.Normal[0], event.Normal[1]}, event.Normal_Impulse, event.Tangent_Impulse)
	}
	for event in end {
		queue_physics_contact(&ctx.physics, entry, .Contact_End, event.Shape_A, event.Shape_B)
	}
	for event in sensor_begin {
		queue_physics_contact(&ctx.physics, entry, .Sensor_Begin, event.Sensor, event.Visitor)
	}
	for event in sensor_end {
		queue_physics_contact(&ctx.physics, entry, .Sensor_End, event.Sensor, event.Visitor)
	}
	hits: [dynamic]b2.Thor2D_Hit_Event
	b2.Thor2D_Collect_Hit_Events(entry.native, &hits)
	for event in hits {
		queue_physics_contact(&ctx.physics, entry, .Contact_Hit, event.Shape_A, event.Shape_B, Vec2{event.Point[0], event.Point[1]}, Vec2{event.Normal[0], event.Normal[1]}, 0, 0, event.Approach_Speed)
	}
	delete(begin)
	delete(end)
	delete(sensor_begin)
	delete(sensor_end)
	delete(hits)
	// Fire LOVE-style callbacks last: the poll queue above stays intact and
	// pollable. This must be the final use of `entry` — callbacks may create
	// or destroy worlds/bodies, invalidating it.
	fire_physics_callbacks(ctx, world)
}

Step_All_Physics :: proc(ctx: ^Context, delta: f32) {
	if ctx == nil {
		return
	}
	// Snapshot handles first: Step callbacks may create or destroy worlds, so
	// iterating the live array could skip or double-step worlds. Worlds
	// created mid-call are stepped on the next call; destroyed ones resolve
	// to no-ops inside Step_Physics.
	handles := make([dynamic]u64, len(ctx.physics.worlds))
	for world, i in ctx.physics.worlds {
		handles[i] = world.handle
	}
	for handle in handles {
		Step_Physics(ctx, Physics_World{handle}, delta)
	}
	delete(handles)
	iterator := Query(&ctx.Registry, Rigid_Body_2D)
	for {
		entity, _, ok := Query_Next(&iterator)
		if !ok {
			break
		}
		Sync_Physics_Entity(ctx, entity)
	}
}

Poll_Physics_Event :: proc(ctx: ^Context, world: Physics_World) -> (Physics_Event, bool) {
	if ctx == nil {
		return Physics_Event{}, false
	}
	entry, ok := find_physics_world(&ctx.physics, world.handle)
	if !ok || len(entry.events) == 0 {
		return Physics_Event{}, false
	}
	event := entry.events[0]
	for i := 1; i < len(entry.events); i += 1 {
		entry.events[i-1] = entry.events[i]
	}
	pop(&entry.events)
	return event, true
}

Sync_Physics_Entity :: proc(ctx: ^Context, entity: Entity) {
	if ctx == nil || !Entity_Alive(&ctx.Registry, entity) {
		return
	}
	transform := Get_Component(&ctx.Registry, entity, Transform_2D)
	rigid := Get_Component(&ctx.Registry, entity, Rigid_Body_2D)
	if transform == nil || rigid == nil {
		return
	}
	switch rigid.Sync_Mode {
	case .Physics_To_Transform:
		transform.Position = Physics_Body_Position(ctx, rigid.Body)
		transform.Rotation = Physics_Body_Rotation(ctx, rigid.Body)
	case .Transform_To_Physics:
		Physics_Body_Set_Transform(ctx, rigid.Body, transform.Position, transform.Rotation)
	case .Manual:
		// The caller owns synchronization in manual mode.
	}
}

// The shape material procs below mirror love.physics Fixture setters at
// runtime. Friction, restitution, and density map directly to Box2D 3.x shape
// state; chains apply to (and read from) their segments since Box2D expands a
// chain into segment shapes internally. Sensor state is fixed at creation via
// Physics_Shape_Def.Sensor because Box2D 3.x forbids sensor<->solid
// transitions, so the sensor setter reports .Unsupported instead of faking.
// All procs are headless-safe (pure Box2D CPU state, no backend).

// Physics_Shape_Set_Friction mirrors love Fixture:setFriction.
Physics_Shape_Set_Friction :: proc(ctx: ^Context, shape: Physics_Shape, value: f32) -> Error {
	if ctx == nil {
		return .Invalid_Handle
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	if !ok {
		return .Invalid_Handle
	}
	if b2.Shape_IsValid(entry.native) {
		b2.Shape_SetFriction(entry.native, value)
		return .None
	}
	if len(entry.chain_segments) > 0 {
		for segment in entry.chain_segments {
			b2.Shape_SetFriction(segment, value)
		}
		return .None
	}
	return .Invalid_Handle
}

// Physics_Shape_Set_Restitution mirrors love Fixture:setRestitution.
Physics_Shape_Set_Restitution :: proc(ctx: ^Context, shape: Physics_Shape, value: f32) -> Error {
	if ctx == nil {
		return .Invalid_Handle
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	if !ok {
		return .Invalid_Handle
	}
	if b2.Shape_IsValid(entry.native) {
		b2.Shape_SetRestitution(entry.native, value)
		return .None
	}
	if len(entry.chain_segments) > 0 {
		for segment in entry.chain_segments {
			b2.Shape_SetRestitution(segment, value)
		}
		return .None
	}
	return .Invalid_Handle
}

// Physics_Shape_Set_Density mirrors love Fixture:setDensity and updates the
// parent body mass, like Box2D does when shapes are created with a density.
Physics_Shape_Set_Density :: proc(ctx: ^Context, shape: Physics_Shape, value: f32) -> Error {
	if ctx == nil {
		return .Invalid_Handle
	}
	if value < 0 {
		return .Invalid_Data
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	if !ok {
		return .Invalid_Handle
	}
	if b2.Shape_IsValid(entry.native) {
		b2.Shape_SetDensity(entry.native, value, true)
		return .None
	}
	if len(entry.chain_segments) > 0 {
		for segment in entry.chain_segments {
			b2.Shape_SetDensity(segment, value, true)
		}
		return .None
	}
	return .Invalid_Handle
}

// Physics_Shape_Set_Sensor mirrors love Fixture:setSensor. Box2D 3.x cannot
// change a shape from sensor to solid (or back) after creation, so this is a
// no-op success when the shape already has the requested state and
// .Unsupported otherwise; set Physics_Shape_Def.Sensor at creation instead.
Physics_Shape_Set_Sensor :: proc(ctx: ^Context, shape: Physics_Shape, sensor: bool) -> Error {
	if ctx == nil {
		return .Invalid_Handle
	}
	if _, ok := find_physics_shape(&ctx.physics, shape.handle); !ok {
		return .Invalid_Handle
	}
	if Physics_Shape_Is_Sensor(ctx, shape) == sensor {
		return .None
	}
	return .Unsupported
}

// Physics_Shape_Friction mirrors love Fixture:getFriction. Chains report
// their first segment; unknown handles read as 0.
Physics_Shape_Friction :: proc(ctx: ^Context, shape: Physics_Shape) -> f32 {
	if ctx == nil {
		return 0
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	if !ok {
		return 0
	}
	if b2.Shape_IsValid(entry.native) {
		return b2.Shape_GetFriction(entry.native)
	}
	if len(entry.chain_segments) > 0 {
		return b2.Shape_GetFriction(entry.chain_segments[0])
	}
	return 0
}

// Physics_Shape_Restitution mirrors love Fixture:getRestitution. Chains report
// their first segment; unknown handles read as 0.
Physics_Shape_Restitution :: proc(ctx: ^Context, shape: Physics_Shape) -> f32 {
	if ctx == nil {
		return 0
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	if !ok {
		return 0
	}
	if b2.Shape_IsValid(entry.native) {
		return b2.Shape_GetRestitution(entry.native)
	}
	if len(entry.chain_segments) > 0 {
		return b2.Shape_GetRestitution(entry.chain_segments[0])
	}
	return 0
}

// Physics_Shape_Density mirrors love Fixture:getDensity. Chains report their
// first segment; unknown handles read as 0.
Physics_Shape_Density :: proc(ctx: ^Context, shape: Physics_Shape) -> f32 {
	if ctx == nil {
		return 0
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	if !ok {
		return 0
	}
	if b2.Shape_IsValid(entry.native) {
		return b2.Shape_GetDensity(entry.native)
	}
	if len(entry.chain_segments) > 0 {
		return b2.Shape_GetDensity(entry.chain_segments[0])
	}
	return 0
}

// Physics_Shape_Is_Sensor mirrors love Fixture:isSensor. Chains report their
// first segment; unknown handles read as false.
Physics_Shape_Is_Sensor :: proc(ctx: ^Context, shape: Physics_Shape) -> bool {
	if ctx == nil {
		return false
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	if !ok {
		return false
	}
	if b2.Shape_IsValid(entry.native) {
		return b2.Shape_IsSensor(entry.native)
	}
	if len(entry.chain_segments) > 0 {
		return b2.Shape_IsSensor(entry.chain_segments[0])
	}
	return false
}
