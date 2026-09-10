package tests

import math "core:math"
import "core:testing"
import thor2d "thor2d:thor2d"

// v0.10 wave 2: physics runtime depth — LOVE-style World callbacks, body
// runtime state, fixture filters, world enumeration, fixture-on-live-body,
// contact-control verdicts, joint introspection. All headless-safe: physics
// is pure Box2D CPU state, so a bare Context (no window/GPU) suffices, matching
// the existing box2d tests in thor2d_test.odin.

// File-scope callback counters (tests run single-threaded).
v10p_begin_count := 0
v10p_end_count := 0
v10p_pre_count := 0
v10p_post_count := 0
v10p_destroy_target := thor2d.Physics_Body{}

v10p_reset_counts :: proc() {
	v10p_begin_count = 0
	v10p_end_count = 0
	v10p_pre_count = 0
	v10p_post_count = 0
	v10p_destroy_target = thor2d.Physics_Body{}
}

v10p_on_begin :: proc(ctx: ^thor2d.Context, contact: thor2d.Physics_Contact_Data) {
	_ = ctx
	_ = contact
	v10p_begin_count += 1
}

v10p_on_end :: proc(ctx: ^thor2d.Context, contact: thor2d.Physics_Contact_Data) {
	_ = ctx
	_ = contact
	v10p_end_count += 1
}

v10p_on_pre :: proc(ctx: ^thor2d.Context, contact: thor2d.Physics_Contact_Data) {
	_ = ctx
	_ = contact
	v10p_pre_count += 1
}

v10p_on_post :: proc(ctx: ^thor2d.Context, contact: thor2d.Physics_Contact_Data) {
	_ = ctx
	_ = contact
	v10p_post_count += 1
}

// Destroying a body inside a callback is allowed: callbacks run post-step
// (outside the Box2D solve) and take effect on the next step.
v10p_on_begin_destroy :: proc(ctx: ^thor2d.Context, contact: thor2d.Physics_Contact_Data) {
	_ = contact
	v10p_begin_count += 1
	thor2d.Destroy_Physics_Body(ctx, v10p_destroy_target)
}

// Overlapping static ground + dynamic body: deterministic first-step contact.
v10p_make_contact_pair :: proc(t: ^testing.T, ctx: ^thor2d.Context, world: thor2d.Physics_World) -> (ground, dyn: thor2d.Physics_Body) {
	t, ctx := t, ctx
	static_def := thor2d.Default_Physics_Body_Def()
	static_def.Type = .Static
	g, ground_err := thor2d.Create_Physics_Body(ctx, world, static_def)
	if !testing.expect(t, ground_err == .None) {
		return g, dyn
	}
	_, _ = thor2d.Create_Box_Shape(ctx, g, 200, 20)
	dyn_def := thor2d.Default_Physics_Body_Def()
	dyn_def.Gravity_Scale = 0
	dyn_def.Enable_Sleep = false
	d, dyn_err := thor2d.Create_Physics_Body(ctx, world, dyn_def)
	if !testing.expect(t, dyn_err == .None) {
		return g, d
	}
	_, _ = thor2d.Create_Box_Shape(ctx, d, 10, 10)
	return g, d
}

v10p_drain_poll :: proc(ctx: ^thor2d.Context, world: thor2d.Physics_World) -> int {
	polled := 0
	for {
		_, ok := thor2d.Poll_Physics_Event(ctx, world)
		if !ok {
			break
		}
		polled += 1
	}
	return polled
}

@(test)
test_v10p_world_callbacks_fire_and_poll_coexists :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	v10p_reset_counts()
	world, world_err := thor2d.Create_Physics_World(&ctx)
	if !testing.expect(t, world_err == .None) {
		return
	}
	defer thor2d.Destroy_All_Physics(&ctx)
	_, _ = v10p_make_contact_pair(t, &ctx, world)

	testing.expect(t, thor2d.Set_Physics_Callbacks(&ctx, world, v10p_on_begin, v10p_on_end, nil, nil) == .None)
	thor2d.Step_Physics(&ctx, world, 1.0/60.0)
	testing.expect(t, v10p_begin_count >= 1)
	testing.expect(t, v10p_end_count == 0)
	// The same step's events must still be pollable after callbacks ran.
	testing.expect(t, v10p_drain_poll(&ctx, world) >= 1)

	// Nil unregisters: no more callback invocations.
	testing.expect(t, thor2d.Set_Physics_Callbacks(&ctx, world, nil, nil, nil, nil) == .None)
	v10p_reset_counts()
	thor2d.Step_Physics(&ctx, world, 1.0/60.0)
	testing.expect(t, v10p_begin_count == 0)

	// Bad handles fail loudly.
	testing.expect(t, thor2d.Set_Physics_Callbacks(&ctx, thor2d.Physics_World{}, v10p_on_begin, nil, nil, nil) == .Invalid_Handle)
	testing.expect(t, thor2d.Set_Physics_Callbacks(nil, world, v10p_on_begin, nil, nil, nil) == .Invalid_Handle)
}

@(test)
test_v10p_world_callbacks_end_presolve_postsolve :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	v10p_reset_counts()
	world, world_err := thor2d.Create_Physics_World(&ctx)
	if !testing.expect(t, world_err == .None) {
		return
	}
	defer thor2d.Destroy_All_Physics(&ctx)

	// Falling body: begin on impact, hit (post_solve) from the collision.
	static_def := thor2d.Default_Physics_Body_Def()
	static_def.Type = .Static
	static_def.Position = thor2d.Vec2{0, 100}
	ground, _ := thor2d.Create_Physics_Body(&ctx, world, static_def)
	_, _ = thor2d.Create_Box_Shape(&ctx, ground, 200, 20)
	dyn_def := thor2d.Default_Physics_Body_Def()
	dyn_def.Enable_Sleep = false
	dyn, _ := thor2d.Create_Physics_Body(&ctx, world, dyn_def)
	_, _ = thor2d.Create_Box_Shape(&ctx, dyn, 10, 10)

	testing.expect(t, thor2d.Set_Physics_Callbacks(&ctx, world, v10p_on_begin, v10p_on_end, v10p_on_pre, v10p_on_post) == .None)
	for _ in 0..<120 {
		thor2d.Step_Physics(&ctx, world, 1.0/60.0)
	}
	testing.expect(t, v10p_begin_count >= 1)
	testing.expect(t, v10p_pre_count >= 1)
	testing.expect(t, v10p_post_count >= 1)

	// Teleport away and step: the separation must fire end.
	v10p_reset_counts()
	thor2d.Physics_Body_Set_Transform(&ctx, dyn, thor2d.Vec2{0, -1000}, 0)
	for _ in 0..<5 {
		thor2d.Step_Physics(&ctx, world, 1.0/60.0)
	}
	testing.expect(t, v10p_end_count >= 1)
}

@(test)
test_v10p_callback_destroy_body_is_safe :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	v10p_reset_counts()
	world, world_err := thor2d.Create_Physics_World(&ctx)
	if !testing.expect(t, world_err == .None) {
		return
	}
	defer thor2d.Destroy_All_Physics(&ctx)
	_, dyn := v10p_make_contact_pair(t, &ctx, world)
	before := thor2d.Physics_World_Body_Count(&ctx, world)
	testing.expect(t, before == 2)

	// The begin callback destroys one of the touching bodies mid-dispatch.
	v10p_destroy_target = dyn
	testing.expect(t, thor2d.Set_Physics_Callbacks(&ctx, world, v10p_on_begin_destroy, nil, nil, nil) == .None)
	thor2d.Step_Physics(&ctx, world, 1.0/60.0)
	testing.expect(t, v10p_begin_count >= 1)
	testing.expect(t, thor2d.Physics_World_Body_Count(&ctx, world) == before-1)
	// Stepping and polling after destruction inside a callback must be safe.
	thor2d.Step_Physics(&ctx, world, 1.0/60.0)
	_ = v10p_drain_poll(&ctx, world)
	thor2d.Step_All_Physics(&ctx, 1.0/60.0)
}

@(test)
test_v10p_body_mass_angular_and_flags :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	world, _ := thor2d.Create_Physics_World(&ctx)
	defer thor2d.Destroy_All_Physics(&ctx)
	body, _ := thor2d.Create_Physics_Body(&ctx, world, thor2d.Default_Physics_Body_Def())
	def := thor2d.Default_Physics_Shape_Def()
	def.Density = 2
	shape, _ := thor2d.Create_Box_Shape(&ctx, body, 4, 3, def)

	// 4x3 box at density 2 -> mass 24.
	mass, inertia, mass_err := thor2d.Physics_Body_Mass_Data(&ctx, body)
	testing.expect(t, mass_err == .None)
	testing.expect(t, abs(mass-24) < 0.5)
	testing.expect(t, inertia > 0)
	_, _, bad_err := thor2d.Physics_Body_Mass_Data(&ctx, thor2d.Physics_Body{})
	testing.expect(t, bad_err == .Invalid_Handle)

	testing.expect(t, thor2d.Physics_Body_Reset_Mass(&ctx, body) == .None)
	mass2, _, _ := thor2d.Physics_Body_Mass_Data(&ctx, body)
	testing.expect(t, abs(mass2-24) < 0.5)
	testing.expect(t, thor2d.Physics_Body_Reset_Mass(&ctx, thor2d.Physics_Body{}) == .Invalid_Handle)

	// Density changes flow into the body mass (native updateBodyMass).
	testing.expect(t, thor2d.Physics_Shape_Set_Density(&ctx, shape, 4) == .None)
	mass3, _, _ := thor2d.Physics_Body_Mass_Data(&ctx, body)
	testing.expect(t, abs(mass3-48) < 1.0)

	thor2d.Physics_Body_Set_Angular_Velocity(&ctx, body, 3.5)
	testing.expect(t, thor2d.Physics_Body_Angular_Velocity(&ctx, body) == 3.5)

	testing.expect(t, thor2d.Physics_Body_Is_Active(&ctx, body))
	thor2d.Physics_Body_Set_Active(&ctx, body, false)
	testing.expect(t, !thor2d.Physics_Body_Is_Active(&ctx, body))
	thor2d.Physics_Body_Set_Active(&ctx, body, true)
	testing.expect(t, thor2d.Physics_Body_Is_Active(&ctx, body))
	testing.expect(t, !thor2d.Physics_Body_Is_Active(&ctx, thor2d.Physics_Body{}))

	thor2d.Physics_Body_Set_Bullet(&ctx, body, true)
	testing.expect(t, thor2d.Physics_Body_Is_Bullet(&ctx, body))
	thor2d.Physics_Body_Set_Bullet(&ctx, body, false)
	testing.expect(t, !thor2d.Physics_Body_Is_Bullet(&ctx, body))

	thor2d.Physics_Body_Set_Fixed_Rotation(&ctx, body, true)
	testing.expect(t, thor2d.Physics_Body_Is_Fixed_Rotation(&ctx, body))
	thor2d.Physics_Body_Set_Fixed_Rotation(&ctx, body, false)
	testing.expect(t, !thor2d.Physics_Body_Is_Fixed_Rotation(&ctx, body))

	testing.expect(t, thor2d.Physics_Body_Is_Sleep_Allowed(&ctx, body))
	thor2d.Physics_Body_Set_Sleep_Allowed(&ctx, body, false)
	testing.expect(t, !thor2d.Physics_Body_Is_Sleep_Allowed(&ctx, body))
	thor2d.Physics_Body_Set_Sleep_Allowed(&ctx, body, true)
	testing.expect(t, thor2d.Physics_Body_Is_Sleep_Allowed(&ctx, body))
}

@(test)
test_v10p_body_world_local_transforms :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	world, _ := thor2d.Create_Physics_World(&ctx)
	defer thor2d.Destroy_All_Physics(&ctx)
	def := thor2d.Default_Physics_Body_Def()
	def.Position = thor2d.Vec2{10, 20}
	def.Rotation = math.PI/2
	body, _ := thor2d.Create_Physics_Body(&ctx, world, def)

	// 90-degree rotation maps local +X to world +Y.
	wp, wp_err := thor2d.Physics_Body_World_Point(&ctx, body, thor2d.Vec2{1, 0})
	testing.expect(t, wp_err == .None)
	testing.expect(t, abs(wp.X-10) < 1e-3 && abs(wp.Y-21) < 1e-3)

	lp, lp_err := thor2d.Physics_Body_Local_Point(&ctx, body, thor2d.Vec2{10, 21})
	testing.expect(t, lp_err == .None)
	testing.expect(t, abs(lp.X-1) < 1e-3 && abs(lp.Y) < 1e-3)

	wv, wv_err := thor2d.Physics_Body_World_Vector(&ctx, body, thor2d.Vec2{1, 0})
	testing.expect(t, wv_err == .None)
	testing.expect(t, abs(wv.X) < 1e-3 && abs(wv.Y-1) < 1e-3)

	lv, lv_err := thor2d.Physics_Body_Local_Vector(&ctx, body, thor2d.Vec2{0, 1})
	testing.expect(t, lv_err == .None)
	testing.expect(t, abs(lv.X-1) < 1e-3 && abs(lv.Y) < 1e-3)

	// Round-trip at an arbitrary angle and offset.
	def2 := thor2d.Default_Physics_Body_Def()
	def2.Position = thor2d.Vec2{-7, 3}
	def2.Rotation = 0.7
	body2, _ := thor2d.Create_Physics_Body(&ctx, world, def2)
	p := thor2d.Vec2{4, -2}
	w, _ := thor2d.Physics_Body_World_Point(&ctx, body2, p)
	back, back_err := thor2d.Physics_Body_Local_Point(&ctx, body2, w)
	testing.expect(t, back_err == .None)
	testing.expect(t, abs(back.X-p.X) < 1e-3 && abs(back.Y-p.Y) < 1e-3)

	_, bad_err := thor2d.Physics_Body_World_Point(&ctx, thor2d.Physics_Body{}, p)
	testing.expect(t, bad_err == .Invalid_Handle)
	_, bad_err2 := thor2d.Physics_Body_Local_Vector(&ctx, thor2d.Physics_Body{}, p)
	testing.expect(t, bad_err2 == .Invalid_Handle)
}

@(test)
test_v10p_shape_filter_roundtrip :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	world, _ := thor2d.Create_Physics_World(&ctx)
	defer thor2d.Destroy_All_Physics(&ctx)
	body, _ := thor2d.Create_Physics_Body(&ctx, world, thor2d.Default_Physics_Body_Def())
	shape, _ := thor2d.Create_Box_Shape(&ctx, body, 8, 8)

	testing.expect(t, thor2d.Physics_Shape_Set_Filter(&ctx, shape, 0x2, 0x4, -7) == .None)
	category, mask, group, filter_err := thor2d.Physics_Shape_Filter(&ctx, shape)
	testing.expect(t, filter_err == .None)
	testing.expect(t, category == 0x2 && mask == 0x4 && group == -7)

	testing.expect(t, thor2d.Physics_Shape_Set_Filter(&ctx, shape, 1, 0xFFFF, 0) == .None)
	category, mask, group, _ = thor2d.Physics_Shape_Filter(&ctx, shape)
	testing.expect(t, category == 1 && mask == 0xFFFF && group == 0)

	testing.expect(t, thor2d.Physics_Shape_Set_Filter(&ctx, thor2d.Physics_Shape{}, 1, 1, 0) == .Invalid_Handle)
	_, _, _, bad_err := thor2d.Physics_Shape_Filter(&ctx, thor2d.Physics_Shape{})
	testing.expect(t, bad_err == .Invalid_Handle)
}

@(test)
test_v10p_world_and_body_enumeration :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	world, _ := thor2d.Create_Physics_World(&ctx)
	defer thor2d.Destroy_All_Physics(&ctx)
	ground, dyn := v10p_make_contact_pair(t, &ctx, world)
	_, _ = thor2d.Create_Box_Shape(&ctx, dyn, 4, 4)
	joint, joint_err := thor2d.Create_Physics_Joint(&ctx, world, thor2d.Physics_Joint_Def{
		Kind = .Distance, Body_A = ground, Body_B = dyn, Length = 20,
		// Jointed bodies skip collision by default; opt in so the pair
		// below still reports contacts.
		Collide_Connected = true,
	})
	testing.expect(t, joint_err == .None)

	testing.expect(t, thor2d.Physics_World_Body_Count(&ctx, world) == 2)
	testing.expect(t, thor2d.Physics_World_Joint_Count(&ctx, world) == 1)
	bodies := thor2d.Physics_World_Bodies(&ctx, world)
	defer delete(bodies)
	testing.expect(t, len(bodies) == 2)
	joints := thor2d.Physics_World_Joints(&ctx, world)
	defer delete(joints)
	testing.expect(t, len(joints) == 1 && joints[0] == joint)

	shapes := thor2d.Physics_Body_Shapes(&ctx, dyn)
	defer delete(shapes)
	testing.expect(t, len(shapes) == 2)
	body_joints := thor2d.Physics_Body_Joints(&ctx, dyn)
	defer delete(body_joints)
	testing.expect(t, len(body_joints) == 1 && body_joints[0] == joint)
	ground_joints := thor2d.Physics_Body_Joints(&ctx, ground)
	defer delete(ground_joints)
	testing.expect(t, len(ground_joints) == 1)

	// Unknown handles read as empty, never as fake data.
	testing.expect(t, thor2d.Physics_World_Body_Count(&ctx, thor2d.Physics_World{}) == 0)
	testing.expect(t, thor2d.Physics_World_Joint_Count(&ctx, thor2d.Physics_World{}) == 0)
	testing.expect(t, thor2d.Physics_World_Contact_Count(&ctx, thor2d.Physics_World{}) == 0)
	empty_shapes := thor2d.Physics_Body_Shapes(&ctx, thor2d.Physics_Body{})
	defer delete(empty_shapes)
	testing.expect(t, len(empty_shapes) == 0)

	thor2d.Step_Physics(&ctx, world, 1.0/60.0)
	testing.expect(t, thor2d.Physics_World_Contact_Count(&ctx, world) >= 1)
	contacts := thor2d.Physics_World_Contacts(&ctx, world)
	defer delete(contacts)
	testing.expect(t, len(contacts) == thor2d.Physics_World_Contact_Count(&ctx, world))
	body_contacts := thor2d.Physics_Body_Contacts(&ctx, dyn)
	defer delete(body_contacts)
	if testing.expect(t, len(body_contacts) >= 1) {
		testing.expect(t, (body_contacts[0].Body_A == dyn || body_contacts[0].Body_B == dyn))
	}
}

@(test)
test_v10p_fixture_added_to_live_body :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	world, _ := thor2d.Create_Physics_World(&ctx)
	defer thor2d.Destroy_All_Physics(&ctx)
	def := thor2d.Default_Physics_Body_Def()
	def.Enable_Sleep = false
	body, _ := thor2d.Create_Physics_Body(&ctx, world, def)
	_, _ = thor2d.Create_Box_Shape(&ctx, body, 8, 8)
	for _ in 0..<5 {
		thor2d.Step_Physics(&ctx, world, 1.0/60.0)
	}
	mass_before, _, _ := thor2d.Physics_Body_Mass_Data(&ctx, body)

	// New fixtures attach to an already-simulated body with no cache fixup.
	extra, extra_err := thor2d.Create_Circle_Shape(&ctx, body, 4)
	testing.expect(t, extra_err == .None && !thor2d.Physics_Shape_Invalid(extra))
	shapes := thor2d.Physics_Body_Shapes(&ctx, body)
	defer delete(shapes)
	testing.expect(t, len(shapes) == 2)
	mass_after, _, _ := thor2d.Physics_Body_Mass_Data(&ctx, body)
	testing.expect(t, mass_after > mass_before)
	bounds := thor2d.Physics_Shape_Bounds(&ctx, extra)
	testing.expect(t, bounds.W > 0 && bounds.H > 0)
	for _ in 0..<5 {
		thor2d.Step_Physics(&ctx, world, 1.0/60.0)
	}
}

@(test)
test_v10p_joint_introspection :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	world, _ := thor2d.Create_Physics_World(&ctx)
	defer thor2d.Destroy_All_Physics(&ctx)
	def_a := thor2d.Default_Physics_Body_Def()
	def_a.Type = .Static
	def_a.Position = thor2d.Vec2{10, 20}
	body_a, _ := thor2d.Create_Physics_Body(&ctx, world, def_a)
	def_b := thor2d.Default_Physics_Body_Def()
	def_b.Position = thor2d.Vec2{30, 40}
	body_b, _ := thor2d.Create_Physics_Body(&ctx, world, def_b)

	revolute, rev_err := thor2d.Create_Physics_Joint(&ctx, world, thor2d.Physics_Joint_Def{
		Kind = .Revolute, Body_A = body_a, Body_B = body_b,
		Anchor_A = thor2d.Vec2{1, 2}, Anchor_B = thor2d.Vec2{3, 4},
	})
	testing.expect(t, rev_err == .None)

	kind, kind_err := thor2d.Physics_Joint_Type(&ctx, revolute)
	testing.expect(t, kind_err == .None && kind == .Revolute)
	ja, jb, bodies_err := thor2d.Physics_Joint_Bodies(&ctx, revolute)
	testing.expect(t, bodies_err == .None && ja == body_a && jb == body_b)

	// Local anchors (1,2)/(3,4) on bodies at (10,20)/(30,40), zero rotation.
	aa, ab, anchors_err := thor2d.Physics_Joint_Anchors(&ctx, revolute)
	testing.expect(t, anchors_err == .None)
	testing.expect(t, abs(aa.X-11) < 1e-3 && abs(aa.Y-22) < 1e-3)
	testing.expect(t, abs(ab.X-33) < 1e-3 && abs(ab.Y-44) < 1e-3)

	testing.expect(t, thor2d.Physics_Joint_Revolute_Set_Limits(&ctx, revolute, -0.5, 0.5) == .None)
	lo, hi, enabled, lim_err := thor2d.Physics_Joint_Revolute_Limits(&ctx, revolute)
	testing.expect(t, lim_err == .None && enabled && lo == -0.5 && hi == 0.5)
	testing.expect(t, thor2d.Physics_Joint_Revolute_Set_Motor(&ctx, revolute, 2, 10, true) == .None)
	speed, max_torque, motor_on, motor_err := thor2d.Physics_Joint_Revolute_Motor(&ctx, revolute)
	testing.expect(t, motor_err == .None && motor_on && speed == 2 && max_torque == 10)
	_, angle_err := thor2d.Physics_Joint_Revolute_Angle(&ctx, revolute)
	testing.expect(t, angle_err == .None)

	distance, dist_err := thor2d.Create_Physics_Joint(&ctx, world, thor2d.Physics_Joint_Def{
		Kind = .Distance, Body_A = body_a, Body_B = body_b, Length = 30,
	})
	testing.expect(t, dist_err == .None)
	distance_kind, _ := thor2d.Physics_Joint_Type(&ctx, distance)
	testing.expect(t, distance_kind == .Distance)
	// Limit/motor procs are joint-type-specific and fail loudly off-kind.
	testing.expect(t, thor2d.Physics_Joint_Revolute_Set_Limits(&ctx, distance, -1, 1) == .Invalid_Data)
	_, _, _, wrong_lim := thor2d.Physics_Joint_Revolute_Limits(&ctx, distance)
	testing.expect(t, wrong_lim == .Invalid_Data)
	_, prismatic_err := thor2d.Physics_Joint_Prismatic_Translation(&ctx, distance)
	testing.expect(t, prismatic_err == .Invalid_Data)

	prismatic, prism_err := thor2d.Create_Physics_Joint(&ctx, world, thor2d.Physics_Joint_Def{
		Kind = .Prismatic, Body_A = body_a, Body_B = body_b,
		Anchor_A = thor2d.Vec2{0, 0}, Anchor_B = thor2d.Vec2{0, 0},
		Axis = thor2d.Vec2{1, 0},
	})
	testing.expect(t, prism_err == .None)
	testing.expect(t, thor2d.Physics_Joint_Prismatic_Set_Limits(&ctx, prismatic, -5, 5) == .None)
	plo, phi, penabled, plim_err := thor2d.Physics_Joint_Prismatic_Limits(&ctx, prismatic)
	testing.expect(t, plim_err == .None && penabled && plo == -5 && phi == 5)
	testing.expect(t, thor2d.Physics_Joint_Prismatic_Set_Motor(&ctx, prismatic, 3, 20, true) == .None)
	pspeed, pmax, pon, pmotor_err := thor2d.Physics_Joint_Prismatic_Motor(&ctx, prismatic)
	testing.expect(t, pmotor_err == .None && pon && pspeed == 3 && pmax == 20)
	_, translation_err := thor2d.Physics_Joint_Prismatic_Translation(&ctx, prismatic)
	testing.expect(t, translation_err == .None)

	_, bad_kind := thor2d.Physics_Joint_Type(&ctx, thor2d.Physics_Joint{})
	testing.expect(t, bad_kind == .Invalid_Handle)
	_, _, bad_anchors := thor2d.Physics_Joint_Anchors(&ctx, thor2d.Physics_Joint{})
	testing.expect(t, bad_anchors == .Invalid_Handle)
	_, _, bad_bodies := thor2d.Physics_Joint_Bodies(&ctx, thor2d.Physics_Joint{})
	testing.expect(t, bad_bodies == .Invalid_Handle)
}

@(test)
test_v10p_contact_control_is_unsupported :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	world, _ := thor2d.Create_Physics_World(&ctx)
	defer thor2d.Destroy_All_Physics(&ctx)
	_, _ = v10p_make_contact_pair(t, &ctx, world)
	thor2d.Step_Physics(&ctx, world, 1.0/60.0)
	contacts := thor2d.Physics_World_Contacts(&ctx, world)
	defer delete(contacts)
	if !testing.expect(t, len(contacts) >= 1) {
		return
	}
	// Box2D 3.x contacts are transient: no enable or per-contact material
	// override exists, so valid contacts report .Unsupported (never faked).
	testing.expect(t, thor2d.Physics_Contact_Set_Enabled(&ctx, world, contacts[0], false) == .Unsupported)
	testing.expect(t, thor2d.Physics_Contact_Set_Friction(&ctx, world, contacts[0], 0.9) == .Unsupported)
	testing.expect(t, thor2d.Physics_Contact_Set_Restitution(&ctx, world, contacts[0], 0.5) == .Unsupported)
	// Bad handles still fail as bad handles.
	garbage := thor2d.Physics_Contact_Data{}
	testing.expect(t, thor2d.Physics_Contact_Set_Enabled(&ctx, world, garbage, false) == .Invalid_Handle)
	testing.expect(t, thor2d.Physics_Contact_Set_Friction(&ctx, world, garbage, 1) == .Invalid_Handle)
	testing.expect(t, thor2d.Physics_Contact_Set_Restitution(&ctx, world, garbage, 1) == .Invalid_Handle)
	testing.expect(t, thor2d.Physics_Contact_Set_Enabled(&ctx, thor2d.Physics_World{}, contacts[0], false) == .Invalid_Handle)
}
