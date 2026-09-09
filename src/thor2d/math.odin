package thor2d

import math "core:math"

Vec2_Add :: proc(a, b: Vec2) -> Vec2 {
	return Vec2{a.X + b.X, a.Y + b.Y}
}

Vec2_Sub :: proc(a, b: Vec2) -> Vec2 {
	return Vec2{a.X - b.X, a.Y - b.Y}
}

Vec2_Scale :: proc(value: Vec2, scalar: f32) -> Vec2 {
	return Vec2{value.X * scalar, value.Y * scalar}
}

Vec2_Length_Squared :: proc(value: Vec2) -> f32 {
	return value.X*value.X + value.Y*value.Y
}

Clamp :: proc(value, minimum, maximum: f32) -> f32 {
	if value < minimum {
		return minimum
	}
	if value > maximum {
		return maximum
	}
	return value
}

Abs_F32 :: proc(value: f32) -> f32 {
	return math.abs(value)
}

Sin :: proc(value: f32) -> f32 {
	return f32(math.sin(f64(value)))
}

New_Bezier_Curve :: proc(control_points: []Vec2) -> (Bezier_Curve, Error) {
	if len(control_points) < 2 {
		return Bezier_Curve{}, .Invalid_Config
	}
	curve := Bezier_Curve{Control_Points = make([dynamic]Vec2, len(control_points))}
	copy(curve.Control_Points[:], control_points)
	return curve, .None
}

Destroy_Bezier_Curve :: proc(curve: ^Bezier_Curve) {
	if curve != nil {
		delete(curve.Control_Points)
		curve^ = Bezier_Curve{}
	}
}

Bezier_Point :: proc(curve: ^Bezier_Curve, amount: f32) -> Vec2 {
	if curve == nil || len(curve.Control_Points) == 0 {
		return Vec2{}
	}
	if len(curve.Control_Points) == 1 {
		return curve.Control_Points[0]
	}
	points := make([dynamic]Vec2, len(curve.Control_Points))
	defer delete(points)
	copy(points[:], curve.Control_Points[:])
	t := Clamp(amount, 0, 1)
	for count := len(points)-1; count > 0; count -= 1 {
		for i := 0; i < count; i += 1 {
			points[i] = Vec2{
				Lerp(points[i].X, points[i+1].X, t),
				Lerp(points[i].Y, points[i+1].Y, t),
			}
		}
	}
	return points[0]
}

Bezier_Tangent :: proc(curve: ^Bezier_Curve, amount: f32) -> Vec2 {
	if curve == nil || len(curve.Control_Points) < 2 {
		return Vec2{}
	}
	derivative := make([dynamic]Vec2, len(curve.Control_Points)-1)
	defer delete(derivative)
	degree := f32(len(curve.Control_Points)-1)
	for i := 0; i < len(derivative); i += 1 {
		derivative[i] = Vec2_Scale(Vec2_Sub(curve.Control_Points[i+1], curve.Control_Points[i]), degree)
	}
	derived_curve := Bezier_Curve{Control_Points = derivative}
	return Bezier_Point(&derived_curve, amount)
}

Polygon_Cross :: proc(a, b, c: Vec2) -> f32 {
	return (b.X-a.X)*(c.Y-a.Y) - (b.Y-a.Y)*(c.X-a.X)
}

Polygon_Area :: proc(points: []Vec2) -> f32 {
	if len(points) < 3 {
		return 0
	}
	area: f32
	for i := 0; i < len(points); i += 1 {
		next := (i+1)%len(points)
		area += points[i].X*points[next].Y - points[next].X*points[i].Y
	}
	return area * 0.5
}

Is_Convex_Polygon :: proc(points: []Vec2) -> bool {
	if len(points) < 3 {
		return false
	}
	sign: f32
	for i := 0; i < len(points); i += 1 {
		cross := Polygon_Cross(points[i], points[(i+1)%len(points)], points[(i+2)%len(points)])
		if Abs_F32(cross) < 0.000001 {
			continue
		}
		if sign == 0 {
			sign = cross
		} else if sign*cross < 0 {
			return false
		}
	}
	return sign != 0
}

point_in_triangle :: proc(point, a, b, c: Vec2) -> bool {
	cross_a := Polygon_Cross(a, b, point)
	cross_b := Polygon_Cross(b, c, point)
	cross_c := Polygon_Cross(c, a, point)
	has_negative := cross_a < -0.000001 || cross_b < -0.000001 || cross_c < -0.000001
	has_positive := cross_a > 0.000001 || cross_b > 0.000001 || cross_c > 0.000001
	return !(has_negative && has_positive)
}

// Triangulate_Polygon uses ear clipping and returns triples of source indices.
// It accepts simple, non-self-intersecting polygons and preserves winding in
// the generated triangles.
Triangulate_Polygon :: proc(points: []Vec2) -> ([dynamic]u32, Error) {
	if len(points) < 3 {
		return nil, .Invalid_Data
	}
	active := make([dynamic]int, len(points))
	defer delete(active)
	if Polygon_Area(points) >= 0 {
		for i := 0; i < len(points); i += 1 {
			active[i] = i
		}
	} else {
		for i := 0; i < len(points); i += 1 {
			active[i] = len(points)-1-i
		}
	}
	triangles := make([dynamic]u32, 0, (len(points)-2)*3)
	guard := 0
	for len(active) > 3 && guard < len(points)*len(points) {
		clipped := false
		for i := 0; i < len(active); i += 1 {
			previous := active[(i+len(active)-1)%len(active)]
			current := active[i]
			next := active[(i+1)%len(active)]
			if Polygon_Cross(points[previous], points[current], points[next]) <= 0 {
				continue
			}
			ear := true
			for candidate in active {
				if candidate == previous || candidate == current || candidate == next {
					continue
				}
				if point_in_triangle(points[candidate], points[previous], points[current], points[next]) {
					ear = false
					break
				}
			}
			if !ear {
				continue
			}
			append(&triangles, u32(previous))
			append(&triangles, u32(current))
			append(&triangles, u32(next))
			for j := i+1; j < len(active); j += 1 {
				active[j-1] = active[j]
			}
			pop(&active)
			clipped = true
			break
		}
		if !clipped {
			delete(triangles)
			return nil, .Invalid_Data
		}
		guard += 1
	}
	if len(active) != 3 {
		delete(triangles)
		return nil, .Invalid_Data
	}
	append(&triangles, u32(active[0]), u32(active[1]), u32(active[2]))
	return triangles, .None
}

Transform_2D :: struct {
	Position: Vec2,
	Scale: Vec2,
	Rotation: f32,
}

Identity_Transform :: proc() -> Transform_2D {
	return Transform_2D{Scale = Vec2{1, 1}}
}

Transform_Translate :: proc(transform: ^Transform_2D, offset: Vec2) {
	if transform != nil {
		transform.Position = Vec2_Add(transform.Position, offset)
	}
}

Transform_Rotate :: proc(transform: ^Transform_2D, angle: f32) {
	if transform != nil {
		transform.Rotation += angle
	}
}

Transform_Scale :: proc(transform: ^Transform_2D, factor: Vec2) {
	if transform != nil {
		transform.Scale.X *= factor.X
		transform.Scale.Y *= factor.Y
	}
}

Transform_Point :: proc(transform: Transform_2D, point: Vec2) -> Vec2 {
	x := point.X * transform.Scale.X
	y := point.Y * transform.Scale.Y
	radians := transform.Rotation * f32(math.PI) / 180
	return Vec2{
		x*f32(math.cos(radians)) - y*f32(math.sin(radians)) + transform.Position.X,
		x*f32(math.sin(radians)) + y*f32(math.cos(radians)) + transform.Position.Y,
	}
}

Camera_Point_To_Screen :: proc(camera: Camera_2D, world: Vec2) -> Vec2 {
	delta := Vec2_Sub(world, camera.Target)
	zoom := camera.Zoom
	if zoom <= 0 {
		zoom = 1
	}
	radians := -camera.Rotation * f32(math.PI) / 180
	cosine := f32(math.cos(radians))
	sine := f32(math.sin(radians))
	rotated := Vec2{delta.X*cosine - delta.Y*sine, delta.X*sine + delta.Y*cosine}
	return Vec2{camera.Offset.X + rotated.X*zoom, camera.Offset.Y + rotated.Y*zoom}
}

Transform_Point_Inverse :: proc(transform: Transform_2D, point: Vec2) -> Vec2 {
	delta := Vec2_Sub(point, transform.Position)
	radians := -transform.Rotation * f32(math.PI) / 180
	cosine := f32(math.cos(radians))
	sine := f32(math.sin(radians))
	rotated := Vec2{delta.X*cosine - delta.Y*sine, delta.X*sine + delta.Y*cosine}
	result := rotated
	if transform.Scale.X != 0 {
		result.X /= transform.Scale.X
	}
	if transform.Scale.Y != 0 {
		result.Y /= transform.Scale.Y
	}
	return result
}

Camera_Screen_To_Point :: proc(camera: Camera_2D, screen: Vec2) -> Vec2 {
	zoom := camera.Zoom
	if zoom <= 0 {
		zoom = 1
	}
	delta := Vec2_Scale(Vec2_Sub(screen, camera.Offset), 1/zoom)
	radians := camera.Rotation * f32(math.PI) / 180
	cosine := f32(math.cos(radians))
	sine := f32(math.sin(radians))
	rotated := Vec2{delta.X*cosine - delta.Y*sine, delta.X*sine + delta.Y*cosine}
	return Vec2_Add(camera.Target, rotated)
}
