# thor2d.Physics

LOVE equivalent: `love.physics` (Box2D). Sources: `physics_box2d.odin`, `physics_extra.odin`, `physics.odin`.

## Description

Fixed-step Box2D 3.1.1 worlds in pixel units. `Config.Pixels_Per_Meter` sets
the Box2D length scale; `Set_Meter/Get_Meter` mirror LOVE for porting.
Seven joint kinds work; four LOVE joints were removed upstream in Box2D 3.x
and return `.Unsupported` with no fake handle.

## Types

`Physics_World`, `Physics_Body`, `Physics_Shape`, `Physics_Joint`,
`Physics_Body_Def`, `Physics_Shape_Def`, `Physics_World_Def`,
`Physics_Joint_Def`, `Physics_Joint_Kind`, `Physics_Event`, `Physics_Raycast_Hit`,
`Physics_Query_Filter/Result`, `Physics_Contact_Data`, `Physics_Contact_Callback`,
`Rigid_Body_2D`.

## Functions

- `Create_Physics_World(ctx, def)` / `Destroy_Physics_World` / `Destroy_All_Physics` / `Set_Gravity` — LOVE `newWorld`.
- `Create_Physics_Body(ctx, world, def)` / `Destroy_Physics_Body` — LOVE `newBody` (+ velocity, damping, sleep, bullet, tags).
- `Create_Box_Shape/Create_Circle_Shape/Create_Segment_Shape/Create_Capsule_Shape/Create_Polygon_Shape/Create_Chain_Shape` / `Destroy_Shape` — LOVE `newRectangleShape/newCircleShape/newEdgeShape/newPolygonShape/newChainShape` (+ capsule extra).
- `Create_Physics_Joint(ctx, world, def)` — LOVE `newDistanceJoint/newRevoluteJoint/newWeldJoint/newMotorJoint/newMouseJoint/newPrismaticJoint/newWheelJoint`. `Pulley/Rope/Friction/Gear` return `.Unsupported` (Box2D 3.x removed them).
- `Set_Meter(ctx, s)` / `Get_Meter(ctx)` — LOVE `setMeter/getMeter`.
- `Get_Physics_Distance(ctx, a, b)` — LOVE `getDistance` as documented AABB approximation (Box2D 3.x has no public exact query in this backend).
- `Physics_Raycast_Closest/All`, `Physics_Overlap_AABB`, `Physics_Shape_Cast_Circle`, `Physics_Shape_Contains_Point`, `Physics_Shape_Bounds` — LOVE world queries.
- `Step_Physics/Step_All_Physics`, `Poll_Physics_Event`, `Sync_Physics_Entity` — stepping + ECS sync.
- `Physics_Shape_Set_Friction/Set_Restitution/Set_Density` + `Physics_Shape_Friction/Restitution/Density` — LOVE `Fixture:setFriction/setRestitution/setDensity` at runtime (chains apply to/read from their segments). `Physics_Shape_Set_Sensor/Is_Sensor` — LOVE `Fixture:setSensor/isSensor`; the setter is a no-op success when the state already matches and `.Unsupported` otherwise (Box2D 3.x forbids sensor<->solid transitions; set `Physics_Shape_Def.Sensor` at creation).
- `Rects_Overlap`, `Point_In_Rect`, `Circle_Overlap` — pure helpers, no backend.
- v0.10 wave 2 runtime depth (all in `physics_extra.odin`, headless-safe):
  - `Set_Physics_Callbacks` (+ `Physics_Contact_Callback`) — LOVE `World:setCallbacks`.
  - `Physics_Body_Set_Angular_Velocity` (+ existing getter) — LOVE `Body:setAngularVelocity`.
  - `Physics_Body_Mass_Data` / `Physics_Body_Reset_Mass` — LOVE `Body:getMass/getInertia/resetMassData`.
  - `Physics_Body_Set_Active/Is_Active`, `Set_Bullet/Is_Bullet`, `Set_Fixed_Rotation/Is_Fixed_Rotation`, `Set_Sleep_Allowed/Is_Sleep_Allowed` — LOVE `Body:setActive/isActive`, `setBullet/isBullet`, `setFixedRotation/isFixedRotation`, `setSleepingAllowed/isSleepingAllowed`.
  - `Physics_Body_World_Point/Local_Point/World_Vector/Local_Vector` — LOVE `Body:getWorldPoint/getLocalPoint/getWorldVector/getLocalVector` (pure CPU math on the body transform, radians).
  - `Physics_Body_Contacts/Shapes/Joints` — per-body enumeration from the step's contact cache / handle tables (caller deletes).
  - `Physics_Shape_Set_Filter` + `Physics_Shape_Filter` getter — LOVE `Fixture:setFilter/getFilter` (real Box2D filter; chains apply to all segments).
  - `Physics_World_Bodies/Joints/Contacts` + `Physics_World_Body_Count/Joint_Count/Contact_Count` — LOVE `World:getBodyCount/getJointCount/getContactCount` and lists (caller deletes; contacts are the step's cache, not a live manifold query).
  - `Physics_Contact_Set_Enabled/Set_Friction/Set_Restitution` — LOVE `Contact:setEnabled/setFriction/setRestitution`, always `.Unsupported` on valid contacts (Box2D 3.x contacts are transient; see below).
  - `Physics_Joint_Bodies/Type/Anchors` — LOVE `Joint:getBodies/getType/getAnchors` (anchors in world coordinates).
  - `Physics_Joint_Revolute_Set_Limits/Limits/Set_Motor/Motor/Angle`, `Physics_Joint_Prismatic_Set_Limits/Limits/Set_Motor/Motor/Translation` — LOVE revolute/prismatic limits + motors (radians, pixels/s); off-kind use is `.Invalid_Data`.
  - New fixtures attach to live simulated bodies with no extra step: `Create_*_Shape` works at any time (covered by `test_v10p_fixture_added_to_live_body`).

## Wave 2 callback semantics (v0.10)

Callbacks fire post-step from `Step_Physics`/`Step_All_Physics` — outside the
Box2D solve — after the poll queue is filled, so callbacks AND
`Poll_Physics_Event` observe the same step (callbacks first, queue left
intact). Creating or destroying bodies/shapes/joints inside a callback is
allowed and takes effect next step; nil unregisters. Sensor overlaps stay
poll-only (`Physics_Contact_Data` carries no sensor flag, so callbacks could
not tell them apart). Event mapping:

| LOVE callback | Thor2D source event |
| --- | --- |
| `beginContact` (`begin`) | `Contact_Begin` |
| `endContact` (`end`) | `Contact_End` |
| `preSolve` (`pre_solve`) | `Contact_Begin` (begin-step approximation; cannot disable the contact — see `.Unsupported` below) |
| `postSolve` (`post_solve`) | `Contact_Hit` (hit reporting is enabled while registered; hits also appear in the poll queue) |

Real vs `.Unsupported`: fixture filters, mass data, body flags, transforms,
enumeration, and joint introspection/limits/motors are real Box2D 3.x state.
Per-contact `Set_Enabled/Set_Friction/Set_Restitution` return `.Unsupported`
by design — contacts are transient manifold snapshots with no enable or
material-override channel in this backend, and post-step callbacks could not
affect the current solve anyway. Faking them via the sensor bit was rejected
(it would change fixture identity, not the contact); use
`Physics_Shape_Set_Filter` or destroy the fixture instead.

```odin
on_begin := proc(ctx: ^thor2d.Context, contact: thor2d.Physics_Contact_Data) {
    _ = contact
    // post-step: safe to create/destroy bodies here.
}
thor2d.Set_Physics_Callbacks(ctx, world, on_begin, nil, nil, nil)
thor2d.Step_Physics(ctx, world, 1.0/60.0)
// The same step is still fully pollable:
for event, ok := thor2d.Poll_Physics_Event(ctx, world); ok; {
    _ = event
}
```

## Enums

`Physics_Joint_Kind`: Distance, Revolute, Weld, Motor, Mouse, Prismatic, Wheel (+ Pulley, Rope, Friction, Gear as explicit `.Unsupported`).

## Examples

```odin
world, _ := thor2d.Create_Physics_World(ctx, thor2d.Default_Physics_World_Def())
body, _ := thor2d.Create_Physics_Body(ctx, world, thor2d.Default_Physics_Body_Def())
shape, _ := thor2d.Create_Box_Shape(ctx, body, 32, 16, thor2d.Default_Physics_Shape_Def())
joint, err := thor2d.Create_Physics_Joint(ctx, world, thor2d.Physics_Joint_Def{Kind = .Distance, Body_A = a, Body_B = b})
```

## See Also

[Math](Math.md), [Timer](Timer.md).
