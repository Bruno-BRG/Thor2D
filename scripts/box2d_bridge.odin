package vendor_box2d

import math "core:math"

// Private Thor2D adapters for data and constructors not exposed by the
// generated Odin binding. bootstrap_box2d.sh installs this beside vendor:box2d.
Thor2D_Contact_Event :: struct {
	Shape_A, Shape_B: ShapeId,
	Position: Vec2,
	Normal: Vec2,
	Normal_Impulse: f32,
	Tangent_Impulse: f32,
}

Thor2D_Sensor_Event :: struct {
	Sensor, Visitor: ShapeId,
}

Thor2D_Hit_Event :: struct {
	Shape_A, Shape_B: ShapeId,
	Point, Normal: Vec2,
	Approach_Speed: f32,
}

Thor2D_Ray_Result :: struct {
	Shape: ShapeId,
	Point: Vec2,
	Normal: Vec2,
	Fraction: f32,
	Hit: bool,
}

Thor2D_Create_Box_Shape :: proc(body: BodyId, half_width, half_height, density, friction, restitution: f32, sensor, contact_events, sensor_events: bool, category_bits, mask_bits: u64, group_index: i32) -> ShapeId {
	def := DefaultShapeDef()
	def.density = density
	def.material.friction = friction
	def.material.restitution = restitution
	def.isSensor = sensor
	def.enableContactEvents = contact_events
	def.enableSensorEvents = sensor_events
	if category_bits != 0 { def.filter.categoryBits = category_bits }
	if mask_bits != 0 { def.filter.maskBits = mask_bits }
	def.filter.groupIndex = group_index
	box := MakeBox(half_width, half_height)
	return CreatePolygonShape(body, def, &box)
}

Thor2D_Create_Circle_Shape :: proc(body: BodyId, radius, density, friction, restitution: f32, sensor, contact_events, sensor_events: bool, category_bits, mask_bits: u64, group_index: i32) -> ShapeId {
	def := DefaultShapeDef()
	def.density = density
	def.material.friction = friction
	def.material.restitution = restitution
	def.isSensor = sensor
	def.enableContactEvents = contact_events
	def.enableSensorEvents = sensor_events
	if category_bits != 0 { def.filter.categoryBits = category_bits }
	if mask_bits != 0 { def.filter.maskBits = mask_bits }
	def.filter.groupIndex = group_index
	circle := Circle{radius = radius}
	return CreateCircleShape(body, def, &circle)
}

Thor2D_Create_Segment_Shape :: proc(body: BodyId, x1, y1, x2, y2, density, friction, restitution: f32, sensor, contact_events, sensor_events: bool, category_bits, mask_bits: u64, group_index: i32) -> ShapeId {
	def := DefaultShapeDef()
	def.density = density
	def.material.friction = friction
	def.material.restitution = restitution
	def.isSensor = sensor
	def.enableContactEvents = contact_events
	def.enableSensorEvents = sensor_events
	if category_bits != 0 { def.filter.categoryBits = category_bits }
	if mask_bits != 0 { def.filter.maskBits = mask_bits }
	def.filter.groupIndex = group_index
	segment := Segment{point1 = Vec2{x1, y1}, point2 = Vec2{x2, y2}}
	return CreateSegmentShape(body, def, &segment)
}

Thor2D_Create_Capsule_Shape :: proc(body: BodyId, half_length, radius, density, friction, restitution: f32, sensor, contact_events, sensor_events: bool, category_bits, mask_bits: u64, group_index: i32) -> ShapeId {
	def := DefaultShapeDef()
	def.density = density
	def.material.friction = friction
	def.material.restitution = restitution
	def.isSensor = sensor
	def.enableContactEvents = contact_events
	def.enableSensorEvents = sensor_events
	if category_bits != 0 { def.filter.categoryBits = category_bits }
	if mask_bits != 0 { def.filter.maskBits = mask_bits }
	def.filter.groupIndex = group_index
	capsule := Capsule{center1 = Vec2{-half_length, 0}, center2 = Vec2{half_length, 0}, radius = radius}
	return CreateCapsuleShape(body, def, &capsule)
}

Thor2D_Create_Polygon_Shape :: proc(body: BodyId, points: []Vec2, radius, density, friction, restitution: f32, sensor, contact_events, sensor_events: bool, category_bits, mask_bits: u64, group_index: i32) -> ShapeId {
	if len(points) < 3 {
		return ShapeId{}
	}
	hull := ComputeHull(points)
	if hull.count < 3 {
		return ShapeId{}
	}
	def := DefaultShapeDef()
	def.density = density
	def.material.friction = friction
	def.material.restitution = restitution
	def.isSensor = sensor
	def.enableContactEvents = contact_events
	def.enableSensorEvents = sensor_events
	if category_bits != 0 {
		def.filter.categoryBits = category_bits
	}
	if mask_bits != 0 {
		def.filter.maskBits = mask_bits
	}
	def.filter.groupIndex = group_index
	polygon := MakePolygon(hull, radius)
	return CreatePolygonShape(body, def, &polygon)
}

Thor2D_Create_Chain_Shape :: proc(body: BodyId, points: []Vec2, loop: bool, friction, restitution: f32, category_bits, mask_bits: u64, group_index: i32) -> ChainId {
	if len(points) < 4 {
		return ChainId{}
	}
	def := DefaultChainDef()
	def.points = raw_data(points)
	def.count = i32(len(points))
	def.isLoop = loop
	category := category_bits
	mask := mask_bits
	if category == 0 {
		category = 1
	}
	if mask == 0 {
		mask = ~u64(0)
	}
	def.filter.categoryBits = category
	def.filter.maskBits = mask
	def.filter.groupIndex = group_index
	material := DefaultSurfaceMaterial()
	if friction >= 0 {
		material.friction = friction
	}
	if restitution >= 0 {
		material.restitution = restitution
	}
	def.materials = &material
	def.materialCount = 1
	return CreateChain(body, def)
}

Thor2D_Make_Query_Filter :: proc(category_bits, mask_bits: u64) -> QueryFilter {
	filter := DefaultQueryFilter()
	category := category_bits
	mask := mask_bits
	if category == 0 {
		category = 1
	}
	if mask == 0 {
		mask = ~u64(0)
	}
	filter.categoryBits = category
	filter.maskBits = mask
	return filter
}

Thor2D_Create_Distance_Joint :: proc(world: WorldId, body_a, body_b: BodyId, anchor_a, anchor_b: Vec2, length: f32, collide_connected: bool) -> JointId {
	def := DefaultDistanceJointDef()
	def.bodyIdA = body_a
	def.bodyIdB = body_b
	def.localAnchorA = anchor_a
	def.localAnchorB = anchor_b
	def.length = length
	def.collideConnected = collide_connected
	return CreateDistanceJoint(world, def)
}

Thor2D_Create_Revolute_Joint :: proc(world: WorldId, body_a, body_b: BodyId, anchor_a, anchor_b: Vec2, collide_connected: bool) -> JointId {
	def := DefaultRevoluteJointDef()
	def.bodyIdA = body_a
	def.bodyIdB = body_b
	def.localAnchorA = anchor_a
	def.localAnchorB = anchor_b
	def.collideConnected = collide_connected
	return CreateRevoluteJoint(world, def)
}

Thor2D_Create_Weld_Joint :: proc(world: WorldId, body_a, body_b: BodyId, anchor_a, anchor_b: Vec2, collide_connected: bool) -> JointId {
	def := DefaultWeldJointDef()
	def.bodyIdA = body_a
	def.bodyIdB = body_b
	def.localAnchorA = anchor_a
	def.localAnchorB = anchor_b
	def.collideConnected = collide_connected
	return CreateWeldJoint(world, def)
}

Thor2D_Create_Motor_Joint :: proc(world: WorldId, body_a, body_b: BodyId, linear_offset: Vec2, angular_offset, max_force, max_torque: f32, collide_connected: bool) -> JointId {
	def := DefaultMotorJointDef()
	def.bodyIdA = body_a
	def.bodyIdB = body_b
	def.linearOffset = linear_offset
	def.angularOffset = angular_offset
	def.maxForce = max_force
	def.maxTorque = max_torque
	def.collideConnected = collide_connected
	return CreateMotorJoint(world, def)
}

Thor2D_Create_Mouse_Joint :: proc(world: WorldId, body_a, body_b: BodyId, target: Vec2, max_force: f32, collide_connected: bool) -> JointId {
	def := DefaultMouseJointDef()
	def.bodyIdA = body_a
	def.bodyIdB = body_b
	def.target = target
	def.maxForce = max_force
	def.collideConnected = collide_connected
	return CreateMouseJoint(world, def)
}

Thor2D_Create_Prismatic_Joint :: proc(world: WorldId, body_a, body_b: BodyId, anchor_a, anchor_b, axis: Vec2, collide_connected: bool) -> JointId {
	def := DefaultPrismaticJointDef()
	def.bodyIdA = body_a
	def.bodyIdB = body_b
	def.localAnchorA = anchor_a
	def.localAnchorB = anchor_b
	def.localAxisA = axis
	def.collideConnected = collide_connected
	return CreatePrismaticJoint(world, def)
}

Thor2D_Create_Wheel_Joint :: proc(world: WorldId, body_a, body_b: BodyId, anchor_a, anchor_b, axis: Vec2, collide_connected: bool) -> JointId {
	def := DefaultWheelJointDef()
	def.bodyIdA = body_a
	def.bodyIdB = body_b
	def.localAnchorA = anchor_a
	def.localAnchorB = anchor_b
	def.localAxisA = axis
	def.collideConnected = collide_connected
	return CreateWheelJoint(world, def)
}

Thor2D_Rotation_Angle :: proc(rotation: Rot) -> f32 {
	return f32(math.atan2(rotation.s, rotation.c))
}

Thor2D_Collect_Contact_Events :: proc(world: WorldId, begin, end: ^[dynamic]Thor2D_Contact_Event) {
	events := World_GetContactEvents(world)
	for i := 0; i < int(events.beginCount); i += 1 {
		value := events.beginEvents[i]
		contact := Thor2D_Contact_Event{Shape_A = value.shapeIdA, Shape_B = value.shapeIdB}
		if value.manifold.pointCount > 0 {
			point := value.manifold.points[0]
			contact.Position = point.point
			contact.Normal = value.manifold.normal
			contact.Normal_Impulse = point.totalNormalImpulse
			contact.Tangent_Impulse = point.tangentImpulse
		}
		append(begin, contact)
	}
	for i := 0; i < int(events.endCount); i += 1 {
		value := events.endEvents[i]
		append(end, Thor2D_Contact_Event{Shape_A = value.shapeIdA, Shape_B = value.shapeIdB})
	}
}

Thor2D_Collect_Hit_Events :: proc(world: WorldId, hits: ^[dynamic]Thor2D_Hit_Event) {
	events := World_GetContactEvents(world)
	for i := 0; i < int(events.hitCount); i += 1 {
		value := events.hitEvents[i]
		append(hits, Thor2D_Hit_Event{
			Shape_A = value.shapeIdA,
			Shape_B = value.shapeIdB,
			Point = value.point,
			Normal = value.normal,
			Approach_Speed = value.approachSpeed,
		})
	}
}

Thor2D_Collect_Sensor_Events :: proc(world: WorldId, begin, end: ^[dynamic]Thor2D_Sensor_Event) {
	events := World_GetSensorEvents(world)
	for i := 0; i < int(events.beginCount); i += 1 {
		value := events.beginEvents[i]
		append(begin, Thor2D_Sensor_Event{Sensor = value.sensorShapeId, Visitor = value.visitorShapeId})
	}
	for i := 0; i < int(events.endCount); i += 1 {
		value := events.endEvents[i]
		append(end, Thor2D_Sensor_Event{Sensor = value.sensorShapeId, Visitor = value.visitorShapeId})
	}
}

Thor2D_Raycast_Closest :: proc(world: WorldId, origin, translation: Vec2) -> Thor2D_Ray_Result {
	result := World_CastRayClosest(world, origin, translation, DefaultQueryFilter())
	return Thor2D_Ray_Result{Shape = result.shapeId, Point = result.point, Normal = result.normal, Fraction = result.fraction, Hit = result.hit}
}
