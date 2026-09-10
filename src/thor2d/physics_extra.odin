package thor2d

import math "core:math"
import b2 "thor2d:thor2d/internal/box2d"

// v0.8 LOVE-parity physics gaps. Thor2D works in pixels with
// Config.Pixels_Per_Meter as the Box2D length-unit scale; Set_Meter/Get_Meter
// exist so LOVE ports using love.physics.setMeter compile and behave.

Set_Meter :: proc(ctx: ^Context, scale: f32) -> Error {
	if ctx == nil || scale <= 0 {
		return .Invalid_Config
	}
	ctx.meter_scale = scale
	return .None
}

Get_Meter :: proc(ctx: ^Context) -> f32 {
	if ctx == nil {
		return 32
	}
	if ctx.meter_scale > 0 {
		return ctx.meter_scale
	}
	if ctx.config.Pixels_Per_Meter > 0 {
		return ctx.config.Pixels_Per_Meter
	}
	return 32
}

// Get_Physics_Distance approximates love.physics.getDistance using shape AABBs.
// LOVE returns exact closest points between fixtures; Box2D 3.x exposes no
// public distance query in this backend, so v0.8 documents the AABB
// approximation explicitly.
Get_Physics_Distance :: proc(ctx: ^Context, a, b: Physics_Shape) -> (point_a, point_b: Vec2, distance: f32, err: Error) {
	if ctx == nil {
		return Vec2{}, Vec2{}, 0, .Invalid_Config
	}
	if Physics_Shape_Invalid(a) || Physics_Shape_Invalid(b) {
		return Vec2{}, Vec2{}, 0, .Invalid_Handle
	}
	rect_a := Physics_Shape_Bounds(ctx, a)
	rect_b := Physics_Shape_Bounds(ctx, b)
	ca := Vec2{rect_a.X + rect_a.W*0.5, rect_a.Y + rect_a.H*0.5}
	cb := Vec2{rect_b.X + rect_b.W*0.5, rect_b.Y + rect_b.H*0.5}
	dx := max(0, max(rect_b.X-(rect_a.X+rect_a.W), rect_a.X-(rect_b.X+rect_b.W)))
	dy := max(0, max(rect_b.Y-(rect_a.Y+rect_a.H), rect_a.Y-(rect_b.Y+rect_b.H)))
	dist := dx*dx + dy*dy
	if dist > 0 {
		dist = __sqrt_f32(dist)
	}
	_ = ca
	_ = cb
	// Clamp points onto each AABB along the center axis for a stable answer.
	pa := Vec2{
		min(max(cb.X, rect_a.X), rect_a.X+rect_a.W),
		min(max(cb.Y, rect_a.Y), rect_a.Y+rect_a.H),
	}
	pb := Vec2{
		min(max(ca.X, rect_b.X), rect_b.X+rect_b.W),
		min(max(ca.Y, rect_b.Y), rect_b.Y+rect_b.H),
	}
	return pa, pb, dist, .None
}

__sqrt_f32 :: proc(value: f32) -> f32 {
	if value <= 0 {
		return 0
	}
	x := value
	for _ in 0..<16 {
		x = 0.5*(x + value/x)
	}
	return x
}

// v0.10 wave 2: physics runtime depth — LOVE-style World callbacks, body
// runtime state, fixture filters, world enumeration, contact-control verdicts,
// and joint introspection. Everything below is headless-safe (pure Box2D CPU
// state, no backend/window). Units stay pixels/radians like the rest of
// Thor2D physics. See docs/wiki/modules/Physics.md.

// Physics_Contact_Callback mirrors love.physics World callbacks
// (beginContact/endContact/preSolve/postSolve). Callbacks fire post-step from
// Step_Physics/Step_All_Physics — outside the Box2D solve — so creating or
// destroying bodies/shapes/joints inside a callback is allowed and takes
// effect on the next step. Registration changes made inside a callback take
// effect on the next step.
Physics_Contact_Callback :: #type proc(ctx: ^Context, contact: Physics_Contact_Data)

// Set_Physics_Callbacks mirrors love.physics World:setCallbacks. Each slot is
// stored per world; a nil slot means unregistered. Event mapping (Box2D 3.x
// buffers begin/end/hit events per step):
//   begin      <- Contact_Begin (two fixtures started touching)
//   end        <- Contact_End (two fixtures separated)
//   pre_solve  <- Contact_Begin (LOVE also fires preSolve on the begin step;
//                Thor2D runs post-step, so — like LOVE ports must accept here —
//                the contact can no longer be disabled from this callback)
//   post_solve <- Contact_Hit (impulse-speed report for the step)
// Sensor overlaps (Sensor_Begin/Sensor_End) stay poll-only via
// Poll_Physics_Event: Physics_Contact_Data carries no sensor flag, so routing
// them here would hand callbacks indistinguishable data. Callbacks fire before
// the caller polls, and the queue is left intact — callbacks AND polling work
// together on the same step.
//
// Hit-event note: Box2D reports Contact_Hit only for shapes with hit events
// enabled (off by default in this backend). Registering a non-nil post_solve
// turns hit reporting on for the world's shapes (and Step_Physics keeps it on
// for shapes created later, while post_solve stays registered); unregistering
// post_solve with nil turns it back off. Hit reports then also appear in the
// poll queue — same collected events, both sinks.
Set_Physics_Callbacks :: proc(ctx: ^Context, world: Physics_World, begin, end, pre_solve, post_solve: Physics_Contact_Callback) -> Error {
	if ctx == nil {
		return .Invalid_Handle
	}
	entry, ok := find_physics_world(&ctx.physics, world.handle)
	if !ok {
		return .Invalid_Handle
	}
	entry.on_begin_contact = begin
	entry.on_end_contact = end
	entry.on_pre_solve = pre_solve
	entry.on_post_solve = post_solve
	physics_set_hit_events(ctx, entry, post_solve != nil)
	return .None
}

// physics_set_hit_events toggles Box2D hit-event reporting on every shape of
// a world (chain segments included). Idempotent; safe on any shape state.
physics_set_hit_events :: proc(ctx: ^Context, entry: ^Physics_World_Entry, enable: bool) {
	if ctx == nil || entry == nil {
		return
	}
	for shape in ctx.physics.shapes {
		if shape.world != entry.handle {
			continue
		}
		if b2.Shape_IsValid(shape.native) {
			b2.Shape_EnableHitEvents(shape.native, enable)
		} else {
			for segment in shape.chain_segments {
				b2.Shape_EnableHitEvents(segment, enable)
			}
		}
	}
}

physics_event_is_contact :: proc(kind: Physics_Event_Kind) -> bool {
	switch kind {
	case .Contact_Begin, .Contact_End, .Contact_Hit:
		return true
	case .Sensor_Begin, .Sensor_End:
		return false
	}
	return false
}

physics_event_to_contact :: proc(event: Physics_Event) -> Physics_Contact_Data {
	return Physics_Contact_Data{
		Shape_A         = event.Shape_A,
		Shape_B         = event.Shape_B,
		Body_A          = event.Body_A,
		Body_B          = event.Body_B,
		Position        = event.Position,
		Normal          = event.Normal,
		Normal_Impulse  = event.Normal_Impulse,
		Tangent_Impulse = event.Tangent_Impulse,
	}
}

// fire_physics_callbacks runs the registered world callbacks over the step's
// collected events. Called at the end of Step_Physics (hence also from
// Step_All_Physics). The poll queue is filled before this runs and is left
// untouched, so Poll_Physics_Event still drains every event afterwards.
fire_physics_callbacks :: proc(ctx: ^Context, world: Physics_World) {
	if ctx == nil {
		return
	}
	entry, ok := find_physics_world(&ctx.physics, world.handle)
	if !ok || len(entry.events) == 0 {
		return
	}
	on_begin := entry.on_begin_contact
	on_end := entry.on_end_contact
	on_pre := entry.on_pre_solve
	on_post := entry.on_post_solve
	if on_begin == nil && on_end == nil && on_pre == nil && on_post == nil {
		return
	}
	// Snapshot the queue: callbacks may create/destroy bodies, shapes,
	// joints, or even this world, so `entry` is never touched again below.
	snapshot := make([dynamic]Physics_Event, len(entry.events))
	copy(snapshot[:], entry.events[:])
	for event in snapshot {
		contact := physics_event_to_contact(event)
		switch event.Kind {
		case .Contact_Begin:
			if on_begin != nil {
				on_begin(ctx, contact)
			}
			if on_pre != nil {
				on_pre(ctx, contact)
			}
		case .Contact_End:
			if on_end != nil {
				on_end(ctx, contact)
			}
		case .Contact_Hit:
			if on_post != nil {
				on_post(ctx, contact)
			}
		case .Sensor_Begin, .Sensor_End:
			// Poll-only by design; see Set_Physics_Callbacks.
		}
	}
	delete(snapshot)
}

// Physics_Body_Set_Angular_Velocity mirrors love Body:setAngularVelocity
// (the getter Physics_Body_Angular_Velocity already exists).
Physics_Body_Set_Angular_Velocity :: proc(ctx: ^Context, body: Physics_Body, velocity: f32) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_SetAngularVelocity(entry.native, velocity)
	}
}

// Physics_Body_Mass_Data mirrors love Body:getMass/getInertia. Returns the
// Box2D body mass and rotational inertia about the local origin.
Physics_Body_Mass_Data :: proc(ctx: ^Context, body: Physics_Body) -> (mass, inertia: f32, err: Error) {
	if ctx == nil {
		return 0, 0, .Invalid_Handle
	}
	entry, ok := find_physics_body(&ctx.physics, body.handle)
	if !ok {
		return 0, 0, .Invalid_Handle
	}
	return b2.Body_GetMass(entry.native), b2.Body_GetRotationalInertia(entry.native), .None
}

// Physics_Body_Reset_Mass mirrors love Body:resetMassData: recompute the body
// mass from its current shapes (normally only needed after overriding mass or
// mutating shapes behind the material setters).
Physics_Body_Reset_Mass :: proc(ctx: ^Context, body: Physics_Body) -> Error {
	if ctx == nil {
		return .Invalid_Handle
	}
	entry, ok := find_physics_body(&ctx.physics, body.handle)
	if !ok {
		return .Invalid_Handle
	}
	b2.Body_ApplyMassFromShapes(entry.native)
	return .None
}

// Physics_Body_Set_Active mirrors love Body:setActive. An inactive body is
// skipped by the simulation until reactivated.
Physics_Body_Set_Active :: proc(ctx: ^Context, body: Physics_Body, active: bool) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		if active {
			b2.Body_Enable(entry.native)
		} else {
			b2.Body_Disable(entry.native)
		}
	}
}

// Physics_Body_Is_Active mirrors love Body:isActive. Unknown handles read as
// false.
Physics_Body_Is_Active :: proc(ctx: ^Context, body: Physics_Body) -> bool {
	if ctx == nil {
		return false
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		return b2.Body_IsEnabled(entry.native)
	}
	return false
}

// Physics_Body_Set_Bullet mirrors love Body:setBullet (continuous collision
// detection for fast bodies).
Physics_Body_Set_Bullet :: proc(ctx: ^Context, body: Physics_Body, bullet: bool) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_SetBullet(entry.native, bullet)
	}
}

// Physics_Body_Is_Bullet mirrors love Body:isBullet. Unknown handles read as
// false.
Physics_Body_Is_Bullet :: proc(ctx: ^Context, body: Physics_Body) -> bool {
	if ctx == nil {
		return false
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		return b2.Body_IsBullet(entry.native)
	}
	return false
}

// Physics_Body_Set_Fixed_Rotation mirrors love Body:setFixedRotation.
Physics_Body_Set_Fixed_Rotation :: proc(ctx: ^Context, body: Physics_Body, fixed: bool) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_SetFixedRotation(entry.native, fixed)
	}
}

// Physics_Body_Is_Fixed_Rotation mirrors love Body:isFixedRotation. Unknown
// handles read as false.
Physics_Body_Is_Fixed_Rotation :: proc(ctx: ^Context, body: Physics_Body) -> bool {
	if ctx == nil {
		return false
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		return b2.Body_IsFixedRotation(entry.native)
	}
	return false
}

// Physics_Body_Set_Sleep_Allowed mirrors love Body:setSleepingAllowed.
Physics_Body_Set_Sleep_Allowed :: proc(ctx: ^Context, body: Physics_Body, allowed: bool) {
	if ctx == nil {
		return
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		b2.Body_EnableSleep(entry.native, allowed)
	}
}

// Physics_Body_Is_Sleep_Allowed mirrors love Body:isSleepingAllowed. Unknown
// handles read as false.
Physics_Body_Is_Sleep_Allowed :: proc(ctx: ^Context, body: Physics_Body) -> bool {
	if ctx == nil {
		return false
	}
	if entry, ok := find_physics_body(&ctx.physics, body.handle); ok {
		return b2.Body_IsSleepEnabled(entry.native)
	}
	return false
}

physics_body_transform :: proc(ctx: ^Context, body: Physics_Body) -> (position: Vec2, angle: f32, ok: bool) {
	if ctx == nil {
		return Vec2{}, 0, false
	}
	if _, found := find_physics_body(&ctx.physics, body.handle); !found {
		return Vec2{}, 0, false
	}
	return Physics_Body_Position(ctx, body), Physics_Body_Rotation(ctx, body), true
}

// Physics_Body_World_Point mirrors love Body:getWorldPoint. Pure CPU math on
// the current body transform (no native call): world = position + R(angle) *
// local. Angles are radians.
Physics_Body_World_Point :: proc(ctx: ^Context, body: Physics_Body, local: Vec2) -> (world: Vec2, err: Error) {
	position, angle, ok := physics_body_transform(ctx, body)
	if !ok {
		return Vec2{}, .Invalid_Handle
	}
	c := math.cos(angle)
	s := math.sin(angle)
	return Vec2{position.X + c*local.X - s*local.Y, position.Y + s*local.X + c*local.Y}, .None
}

// Physics_Body_Local_Point mirrors love Body:getLocalPoint: the inverse of
// Physics_Body_World_Point, computed CPU-side.
Physics_Body_Local_Point :: proc(ctx: ^Context, body: Physics_Body, world: Vec2) -> (local: Vec2, err: Error) {
	position, angle, ok := physics_body_transform(ctx, body)
	if !ok {
		return Vec2{}, .Invalid_Handle
	}
	c := math.cos(angle)
	s := math.sin(angle)
	dx := world.X - position.X
	dy := world.Y - position.Y
	return Vec2{c*dx + s*dy, -s*dx + c*dy}, .None
}

// Physics_Body_World_Vector mirrors love Body:getWorldVector: like
// Physics_Body_World_Point but without the translation (directions only).
Physics_Body_World_Vector :: proc(ctx: ^Context, body: Physics_Body, local: Vec2) -> (world: Vec2, err: Error) {
	_, angle, ok := physics_body_transform(ctx, body)
	if !ok {
		return Vec2{}, .Invalid_Handle
	}
	c := math.cos(angle)
	s := math.sin(angle)
	return Vec2{c*local.X - s*local.Y, s*local.X + c*local.Y}, .None
}

// Physics_Body_Local_Vector mirrors love Body:getLocalVector: the inverse of
// Physics_Body_World_Vector, computed CPU-side.
Physics_Body_Local_Vector :: proc(ctx: ^Context, body: Physics_Body, world: Vec2) -> (local: Vec2, err: Error) {
	_, angle, ok := physics_body_transform(ctx, body)
	if !ok {
		return Vec2{}, .Invalid_Handle
	}
	c := math.cos(angle)
	s := math.sin(angle)
	return Vec2{c*world.X + s*world.Y, -s*world.X + c*world.Y}, .None
}

// Physics_Body_Contacts returns the step's collected contact reports touching
// this body (Contact_Begin/End/Hit only; sensor overlaps are poll-only).
// Built from the same event cache that feeds Poll_Physics_Event and the world
// callbacks, so it reflects the most recent Step_Physics for the body's
// world. The returned array belongs to the caller (delete it, even when
// empty); unknown bodies yield an empty array.
Physics_Body_Contacts :: proc(ctx: ^Context, body: Physics_Body) -> [dynamic]Physics_Contact_Data {
	contacts: [dynamic]Physics_Contact_Data
	if ctx == nil {
		return contacts
	}
	body_entry, ok := find_physics_body(&ctx.physics, body.handle)
	if !ok {
		return contacts
	}
	world_entry, world_ok := find_physics_world(&ctx.physics, body_entry.world)
	if !world_ok {
		return contacts
	}
	for event in world_entry.events {
		if !physics_event_is_contact(event.Kind) {
			continue
		}
		if event.Body_A.handle != body.handle && event.Body_B.handle != body.handle {
			continue
		}
		append(&contacts, physics_event_to_contact(event))
	}
	return contacts
}

// Physics_Body_Shapes enumerates every fixture handle attached to a body,
// including fixtures added to an already-simulated (live) body. The returned
// array belongs to the caller; unknown bodies yield an empty array.
Physics_Body_Shapes :: proc(ctx: ^Context, body: Physics_Body) -> [dynamic]Physics_Shape {
	shapes: [dynamic]Physics_Shape
	if ctx == nil {
		return shapes
	}
	if _, ok := find_physics_body(&ctx.physics, body.handle); !ok {
		return shapes
	}
	for shape in ctx.physics.shapes {
		if shape.body == body.handle {
			append(&shapes, Physics_Shape{shape.handle})
		}
	}
	return shapes
}

// Physics_Body_Joints enumerates every joint attached to a body. The returned
// array belongs to the caller; unknown bodies yield an empty array.
Physics_Body_Joints :: proc(ctx: ^Context, body: Physics_Body) -> [dynamic]Physics_Joint {
	joints: [dynamic]Physics_Joint
	if ctx == nil {
		return joints
	}
	body_entry, ok := find_physics_body(&ctx.physics, body.handle)
	if !ok {
		return joints
	}
	for joint in ctx.physics.joints {
		if joint.world != body_entry.world {
			continue
		}
		if b2.Joint_GetBodyA(joint.native) == body_entry.native ||
		   b2.Joint_GetBodyB(joint.native) == body_entry.native {
			append(&joints, Physics_Joint{joint.handle})
		}
	}
	return joints
}

// Physics_Shape_Set_Filter mirrors love Fixture:setFilter: category/mask are
// u64 bit sets, group is the Box2D group index (negative = never collide,
// positive = always collide, zero = use the mask). Applies to every segment
// of chain shapes, like the other shape material setters.
Physics_Shape_Set_Filter :: proc(ctx: ^Context, shape: Physics_Shape, category, mask: u64, group: i32) -> Error {
	if ctx == nil {
		return .Invalid_Handle
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	if !ok {
		return .Invalid_Handle
	}
	filter := b2.Filter{categoryBits = category, maskBits = mask, groupIndex = group}
	if b2.Shape_IsValid(entry.native) {
		b2.Shape_SetFilter(entry.native, filter)
		return .None
	}
	if len(entry.chain_segments) > 0 {
		for segment in entry.chain_segments {
			b2.Shape_SetFilter(segment, filter)
		}
		return .None
	}
	return .Invalid_Handle
}

// Physics_Shape_Filter mirrors love Fixture:getFilter. Chain shapes report
// their first segment.
Physics_Shape_Filter :: proc(ctx: ^Context, shape: Physics_Shape) -> (category, mask: u64, group: i32, err: Error) {
	if ctx == nil {
		return 0, 0, 0, .Invalid_Handle
	}
	entry, ok := find_physics_shape(&ctx.physics, shape.handle)
	if !ok {
		return 0, 0, 0, .Invalid_Handle
	}
	native := entry.native
	if !b2.Shape_IsValid(native) {
		if len(entry.chain_segments) == 0 {
			return 0, 0, 0, .Invalid_Handle
		}
		native = entry.chain_segments[0]
	}
	filter := b2.Shape_GetFilter(native)
	return filter.categoryBits, filter.maskBits, filter.groupIndex, .None
}

// Physics_World_Bodies enumerates every body in a world. The returned array
// belongs to the caller; unknown worlds yield an empty array.
Physics_World_Bodies :: proc(ctx: ^Context, world: Physics_World) -> [dynamic]Physics_Body {
	bodies: [dynamic]Physics_Body
	if ctx == nil {
		return bodies
	}
	if _, ok := find_physics_world(&ctx.physics, world.handle); !ok {
		return bodies
	}
	for body in ctx.physics.bodies {
		if body.world == world.handle {
			append(&bodies, Physics_Body{body.handle})
		}
	}
	return bodies
}

// Physics_World_Joints enumerates every joint in a world. The returned array
// belongs to the caller; unknown worlds yield an empty array.
Physics_World_Joints :: proc(ctx: ^Context, world: Physics_World) -> [dynamic]Physics_Joint {
	joints: [dynamic]Physics_Joint
	if ctx == nil {
		return joints
	}
	if _, ok := find_physics_world(&ctx.physics, world.handle); !ok {
		return joints
	}
	for joint in ctx.physics.joints {
		if joint.world == world.handle {
			append(&joints, Physics_Joint{joint.handle})
		}
	}
	return joints
}

// Physics_World_Contacts returns the step's collected contact reports for a
// world (Contact_Begin/End/Hit only; sensor overlaps are poll-only). This is
// the same event cache that feeds Poll_Physics_Event, the world callbacks,
// and Physics_Body_Contacts — NOT a live manifold query. The returned array
// belongs to the caller; unknown worlds yield an empty array.
Physics_World_Contacts :: proc(ctx: ^Context, world: Physics_World) -> [dynamic]Physics_Contact_Data {
	contacts: [dynamic]Physics_Contact_Data
	if ctx == nil {
		return contacts
	}
	entry, ok := find_physics_world(&ctx.physics, world.handle)
	if !ok {
		return contacts
	}
	for event in entry.events {
		if !physics_event_is_contact(event.Kind) {
			continue
		}
		append(&contacts, physics_event_to_contact(event))
	}
	return contacts
}

// Physics_World_Body_Count mirrors love World:getBodyCount. Unknown worlds
// read as 0.
Physics_World_Body_Count :: proc(ctx: ^Context, world: Physics_World) -> int {
	if ctx == nil {
		return 0
	}
	if _, ok := find_physics_world(&ctx.physics, world.handle); !ok {
		return 0
	}
	count := 0
	for body in ctx.physics.bodies {
		if body.world == world.handle {
			count += 1
		}
	}
	return count
}

// Physics_World_Joint_Count mirrors love World:getJointCount. Unknown worlds
// read as 0.
Physics_World_Joint_Count :: proc(ctx: ^Context, world: Physics_World) -> int {
	if ctx == nil {
		return 0
	}
	if _, ok := find_physics_world(&ctx.physics, world.handle); !ok {
		return 0
	}
	count := 0
	for joint in ctx.physics.joints {
		if joint.world == world.handle {
			count += 1
		}
	}
	return count
}

// Physics_World_Contact_Count mirrors love World:getContactCount over the
// step's collected contact cache (see Physics_World_Contacts). Unknown worlds
// read as 0.
Physics_World_Contact_Count :: proc(ctx: ^Context, world: Physics_World) -> int {
	if ctx == nil {
		return 0
	}
	entry, ok := find_physics_world(&ctx.physics, world.handle)
	if !ok {
		return 0
	}
	count := 0
	for event in entry.events {
		if physics_event_is_contact(event.Kind) {
			count += 1
		}
	}
	return count
}

physics_validate_contact :: proc(ctx: ^Context, world: Physics_World, contact: Physics_Contact_Data) -> Error {
	if ctx == nil {
		return .Invalid_Handle
	}
	if _, ok := find_physics_world(&ctx.physics, world.handle); !ok {
		return .Invalid_Handle
	}
	if _, ok := find_physics_shape(&ctx.physics, contact.Shape_A.handle); !ok {
		return .Invalid_Handle
	}
	if _, ok := find_physics_shape(&ctx.physics, contact.Shape_B.handle); !ok {
		return .Invalid_Handle
	}
	return .None
}

// Physics_Contact_Set_Enabled mirrors love Contact:setEnabled. It always
// returns .Unsupported on valid contacts: Box2D 3.x contacts are transient
// manifold snapshots with no enable/disable API in this backend, and Thor2D
// callbacks run post-step (outside the solve), so nothing here could affect
// the current step anyway. Faking it by toggling the sensor bit on the
// fixtures was rejected: that would change fixture identity, not the contact.
// Disable collision up front with fixture filters (Physics_Shape_Set_Filter)
// or destroy the fixture instead.
Physics_Contact_Set_Enabled :: proc(ctx: ^Context, world: Physics_World, contact: Physics_Contact_Data, enabled: bool) -> Error {
	if err := physics_validate_contact(ctx, world, contact); err != .None {
		return err
	}
	_ = enabled
	return .Unsupported
}

// Physics_Contact_Set_Friction mirrors love Contact:setFriction. It always
// returns .Unsupported on valid contacts: the backend exposes per-shape
// materials only (Physics_Shape_Set_Friction), with no per-contact override
// channel. See Physics_Contact_Set_Enabled for the rationale.
Physics_Contact_Set_Friction :: proc(ctx: ^Context, world: Physics_World, contact: Physics_Contact_Data, value: f32) -> Error {
	if err := physics_validate_contact(ctx, world, contact); err != .None {
		return err
	}
	_ = value
	return .Unsupported
}

// Physics_Contact_Set_Restitution mirrors love Contact:setRestitution. It
// always returns .Unsupported on valid contacts: the backend exposes
// per-shape materials only (Physics_Shape_Set_Restitution), with no
// per-contact override channel. See Physics_Contact_Set_Enabled for the
// rationale.
Physics_Contact_Set_Restitution :: proc(ctx: ^Context, world: Physics_World, contact: Physics_Contact_Data, value: f32) -> Error {
	if err := physics_validate_contact(ctx, world, contact); err != .None {
		return err
	}
	_ = value
	return .Unsupported
}

physics_joint_entry :: proc(ctx: ^Context, joint: Physics_Joint) -> (^Physics_Joint_Entry, Error) {
	if ctx == nil {
		return nil, .Invalid_Handle
	}
	for &entry in ctx.physics.joints {
		if entry.handle == joint.handle {
			return &entry, .None
		}
	}
	return nil, .Invalid_Handle
}

// Physics_Joint_Type returns which LOVE joint kind a handle was created as.
// A filter joint (unreachable through the public API — Thor2D never creates
// one) reports .Unsupported rather than a fake kind.
Physics_Joint_Type :: proc(ctx: ^Context, joint: Physics_Joint) -> (kind: Physics_Joint_Kind, err: Error) {
	entry, find_err := physics_joint_entry(ctx, joint)
	if find_err != .None {
		return .Distance, find_err
	}
	switch b2.Joint_GetType(entry.native) {
	case .distanceJoint:
		return .Distance, .None
	case .revoluteJoint:
		return .Revolute, .None
	case .weldJoint:
		return .Weld, .None
	case .motorJoint:
		return .Motor, .None
	case .mouseJoint:
		return .Mouse, .None
	case .prismaticJoint:
		return .Prismatic, .None
	case .wheelJoint:
		return .Wheel, .None
	case .filterJoint:
		return .Distance, .Unsupported
	}
	return .Distance, .Unsupported
}

// Physics_Joint_Bodies returns the two bodies a joint connects, in creation
// (A, B) order.
Physics_Joint_Bodies :: proc(ctx: ^Context, joint: Physics_Joint) -> (a, b: Physics_Body, err: Error) {
	entry, find_err := physics_joint_entry(ctx, joint)
	if find_err != .None {
		return Physics_Body{}, Physics_Body{}, find_err
	}
	bodies := &ctx.physics
	return find_public_body_by_native(bodies, b2.Joint_GetBodyA(entry.native)),
		find_public_body_by_native(bodies, b2.Joint_GetBodyB(entry.native)), .None
}

physics_joint_body_frame :: proc(ctx: ^Context, native_body: b2.BodyId) -> (position: Vec2, angle: f32) {
	public := find_public_body_by_native(&ctx.physics, native_body)
	if public.handle == 0 {
		return Vec2{}, 0
	}
	return Physics_Body_Position(ctx, public), Physics_Body_Rotation(ctx, public)
}

// Physics_Joint_Anchors mirrors love Joint:getAnchors: both anchor points in
// world coordinates, derived from the native local anchors and the bodies'
// current transforms. Angles are radians.
Physics_Joint_Anchors :: proc(ctx: ^Context, joint: Physics_Joint) -> (a, b: Vec2, err: Error) {
	entry, find_err := physics_joint_entry(ctx, joint)
	if find_err != .None {
		return Vec2{}, Vec2{}, find_err
	}
	pos_a, ang_a := physics_joint_body_frame(ctx, b2.Joint_GetBodyA(entry.native))
	pos_b, ang_b := physics_joint_body_frame(ctx, b2.Joint_GetBodyB(entry.native))
	local_a := b2.Joint_GetLocalAnchorA(entry.native)
	local_b := b2.Joint_GetLocalAnchorB(entry.native)
	ca := math.cos(ang_a)
	sa := math.sin(ang_a)
	cb := math.cos(ang_b)
	sb := math.sin(ang_b)
	a = Vec2{pos_a.X + ca*local_a[0] - sa*local_a[1], pos_a.Y + sa*local_a[0] + ca*local_a[1]}
	b = Vec2{pos_b.X + cb*local_b[0] - sb*local_b[1], pos_b.Y + sb*local_b[0] + cb*local_b[1]}
	return a, b, .None
}

physics_joint_require_kind :: proc(ctx: ^Context, joint: Physics_Joint, want: Physics_Joint_Kind) -> (b2.JointId, Error) {
	entry, find_err := physics_joint_entry(ctx, joint)
	if find_err != .None {
		return b2.JointId{}, find_err
	}
	got, type_err := Physics_Joint_Type(ctx, joint)
	if type_err != .None {
		return b2.JointId{}, type_err
	}
	if got != want {
		// The native limit/motor procs are joint-type-specific; calling them
		// with the wrong kind would be undefined, so this fails loudly.
		return b2.JointId{}, .Invalid_Data
	}
	return entry.native, .None
}

// Physics_Joint_Revolute_Set_Limits mirrors love RevoluteJoint:setLimits and
// enables the limit. Angles are radians.
Physics_Joint_Revolute_Set_Limits :: proc(ctx: ^Context, joint: Physics_Joint, lower, upper: f32) -> Error {
	native, err := physics_joint_require_kind(ctx, joint, .Revolute)
	if err != .None {
		return err
	}
	b2.RevoluteJoint_SetLimits(native, lower, upper)
	b2.RevoluteJoint_EnableLimit(native, true)
	return .None
}

// Physics_Joint_Revolute_Limits mirrors love RevoluteJoint:getLimits plus the
// enabled flag. Angles are radians.
Physics_Joint_Revolute_Limits :: proc(ctx: ^Context, joint: Physics_Joint) -> (lower, upper: f32, enabled: bool, err: Error) {
	native, require_err := physics_joint_require_kind(ctx, joint, .Revolute)
	if require_err != .None {
		return 0, 0, false, require_err
	}
	return b2.RevoluteJoint_GetLowerLimit(native), b2.RevoluteJoint_GetUpperLimit(native), b2.RevoluteJoint_IsLimitEnabled(native), .None
}

// Physics_Joint_Revolute_Set_Motor mirrors love RevoluteJoint:setMotorSpeed /
// setMaxMotorTorque plus the enable flag. `speed` is rad/s.
Physics_Joint_Revolute_Set_Motor :: proc(ctx: ^Context, joint: Physics_Joint, speed, max_torque: f32, enable: bool) -> Error {
	native, err := physics_joint_require_kind(ctx, joint, .Revolute)
	if err != .None {
		return err
	}
	b2.RevoluteJoint_SetMotorSpeed(native, speed)
	b2.RevoluteJoint_SetMaxMotorTorque(native, max_torque)
	b2.RevoluteJoint_EnableMotor(native, enable)
	return .None
}

// Physics_Joint_Revolute_Motor mirrors love RevoluteJoint:getMotorSpeed plus
// the configured max torque and the enabled flag.
Physics_Joint_Revolute_Motor :: proc(ctx: ^Context, joint: Physics_Joint) -> (speed, max_torque: f32, enabled: bool, err: Error) {
	native, require_err := physics_joint_require_kind(ctx, joint, .Revolute)
	if require_err != .None {
		return 0, 0, false, require_err
	}
	return b2.RevoluteJoint_GetMotorSpeed(native), b2.RevoluteJoint_GetMaxMotorTorque(native), b2.RevoluteJoint_IsMotorEnabled(native), .None
}

// Physics_Joint_Revolute_Angle mirrors love RevoluteJoint:getJointAngle.
// The angle is radians.
Physics_Joint_Revolute_Angle :: proc(ctx: ^Context, joint: Physics_Joint) -> (angle: f32, err: Error) {
	native, require_err := physics_joint_require_kind(ctx, joint, .Revolute)
	if require_err != .None {
		return 0, require_err
	}
	return b2.RevoluteJoint_GetAngle(native), .None
}

// Physics_Joint_Prismatic_Set_Limits mirrors love PrismaticJoint:setLimits
// and enables the limit. Limits are meters-along-axis in pixels.
Physics_Joint_Prismatic_Set_Limits :: proc(ctx: ^Context, joint: Physics_Joint, lower, upper: f32) -> Error {
	native, err := physics_joint_require_kind(ctx, joint, .Prismatic)
	if err != .None {
		return err
	}
	b2.PrismaticJoint_SetLimits(native, lower, upper)
	b2.PrismaticJoint_EnableLimit(native, true)
	return .None
}

// Physics_Joint_Prismatic_Limits mirrors love PrismaticJoint:getLimits plus
// the enabled flag.
Physics_Joint_Prismatic_Limits :: proc(ctx: ^Context, joint: Physics_Joint) -> (lower, upper: f32, enabled: bool, err: Error) {
	native, require_err := physics_joint_require_kind(ctx, joint, .Prismatic)
	if require_err != .None {
		return 0, 0, false, require_err
	}
	return b2.PrismaticJoint_GetLowerLimit(native), b2.PrismaticJoint_GetUpperLimit(native), b2.PrismaticJoint_IsLimitEnabled(native), .None
}

// Physics_Joint_Prismatic_Set_Motor mirrors love PrismaticJoint:setMotorSpeed
// / setMaxMotorForce plus the enable flag. `speed` is pixels/s along the
// axis.
Physics_Joint_Prismatic_Set_Motor :: proc(ctx: ^Context, joint: Physics_Joint, speed, max_force: f32, enable: bool) -> Error {
	native, err := physics_joint_require_kind(ctx, joint, .Prismatic)
	if err != .None {
		return err
	}
	b2.PrismaticJoint_SetMotorSpeed(native, speed)
	b2.PrismaticJoint_SetMaxMotorForce(native, max_force)
	b2.PrismaticJoint_EnableMotor(native, enable)
	return .None
}

// Physics_Joint_Prismatic_Motor mirrors love PrismaticJoint:getMotorSpeed
// plus the configured max force and the enabled flag.
Physics_Joint_Prismatic_Motor :: proc(ctx: ^Context, joint: Physics_Joint) -> (speed, max_force: f32, enabled: bool, err: Error) {
	native, require_err := physics_joint_require_kind(ctx, joint, .Prismatic)
	if require_err != .None {
		return 0, 0, false, require_err
	}
	return b2.PrismaticJoint_GetMotorSpeed(native), b2.PrismaticJoint_GetMaxMotorForce(native), b2.PrismaticJoint_IsMotorEnabled(native), .None
}

// Physics_Joint_Prismatic_Translation mirrors love
// PrismaticJoint:getJointTranslation: the current slide position in pixels.
Physics_Joint_Prismatic_Translation :: proc(ctx: ^Context, joint: Physics_Joint) -> (translation: f32, err: Error) {
	native, require_err := physics_joint_require_kind(ctx, joint, .Prismatic)
	if require_err != .None {
		return 0, require_err
	}
	return b2.PrismaticJoint_GetTranslation(native), .None
}
