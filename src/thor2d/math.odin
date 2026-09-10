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
	// v0.10 raw-matrix override (LOVE Transform:getMatrix/setMatrix
	// exactness). Transform_2D is TRS-only, which cannot represent shear or
	// perspective: Transform_Set_Matrix stores the raw Matrix_4 here and sets
	// Has_Matrix, and Transform_Point/Transform_Point_Inverse honor it
	// exactly. Any TRS-mutating proc (Translate/Rotate/Scale/
	// Set_Transformation) clears the override and works on the TRS fields;
	// Combine/Inverse preserve exactness by multiplying/inverting matrices
	// when either input carries an override. Zero value (false) keeps the
	// historical TRS behavior bit-for-bit.
	Has_Matrix: bool,
	Matrix: Matrix_4,
}

Identity_Transform :: proc() -> Transform_2D {
	return Transform_2D{Scale = Vec2{1, 1}}
}

Transform_Translate :: proc(transform: ^Transform_2D, offset: Vec2) {
	if transform != nil {
		// TRS edits clear a raw-matrix override (documented projection:
		// the matrix cannot be edited component-wise, so the TRS fields
		// take over from here).
		transform.Has_Matrix = false
		transform.Position = Vec2_Add(transform.Position, offset)
	}
}

Transform_Rotate :: proc(transform: ^Transform_2D, angle: f32) {
	if transform != nil {
		transform.Has_Matrix = false
		transform.Rotation += angle
	}
}

Transform_Scale :: proc(transform: ^Transform_2D, factor: Vec2) {
	if transform != nil {
		transform.Has_Matrix = false
		transform.Scale.X *= factor.X
		transform.Scale.Y *= factor.Y
	}
}

Transform_Point :: proc(transform: Transform_2D, point: Vec2) -> Vec2 {
	if transform.Has_Matrix {
		// Exact raw-matrix path (column-vector convention, translation in
		// column 3 — consistent with Transform_Get_Matrix).
		return Vec2{
			transform.Matrix[0, 0]*point.X + transform.Matrix[0, 1]*point.Y + transform.Matrix[0, 3],
			transform.Matrix[1, 0]*point.X + transform.Matrix[1, 1]*point.Y + transform.Matrix[1, 3],
		}
	}
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
	if transform.Has_Matrix {
		// Exact inverse of the 2D affine subset; singular matrices have no
		// inverse and return the input unchanged (mirrors Transform_Inverse).
		a := transform.Matrix[0, 0]
		b := transform.Matrix[0, 1]
		c := transform.Matrix[1, 0]
		d := transform.Matrix[1, 1]
		tx := transform.Matrix[0, 3]
		ty := transform.Matrix[1, 3]
		det := a*d - b*c
		if Abs_F32(det) < 1e-12 {
			return point
		}
		inv := 1 / det
		delta := Vec2_Sub(point, Vec2{tx, ty})
		return Vec2{(d*delta.X - b*delta.Y)*inv, (a*delta.Y - c*delta.X)*inv}
	}
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

// The Transform object API below mirrors love.math.newTransform methods as
// pure-CPU procs on Transform_2D. Angles are DEGREES, matching Transform_Point
// and Transform_Point_Inverse (LOVE uses radians; convert at the call site).
// Transform_2D stores translation/rotation/scale only, so every proc is exact
// for shear-free transforms and Combine/Inverse project sheared inputs to the
// closest TRS (translation always exact). Transforms with a zero X or Y scale
// are singular and have no inverse; Transform_Inverse returns them unchanged.

// transform_to_affine expresses t as the row-form affine matrix
// [a b tx; c d ty], consistent with Transform_Point.
transform_to_affine :: proc(t: Transform_2D) -> (a, b, c, d, tx, ty: f32) {
	radians := t.Rotation * f32(math.PI) / 180
	cosine := f32(math.cos(f64(radians)))
	sine := f32(math.sin(f64(radians)))
	a = t.Scale.X * cosine
	b = -t.Scale.Y * sine
	c = t.Scale.X * sine
	d = t.Scale.Y * cosine
	tx = t.Position.X
	ty = t.Position.Y
	return
}

affine_combine :: proc(a1, b1, c1, d1, tx1, ty1, a2, b2, c2, d2, tx2, ty2: f32) -> (a, b, c, d, tx, ty: f32) {
	a = a1*a2 + b1*c2
	b = a1*b2 + b1*d2
	c = c1*a2 + d1*c2
	d = c1*b2 + d1*d2
	tx = a1*tx2 + b1*ty2 + tx1
	ty = c1*tx2 + d1*ty2 + ty1
	return
}

// affine_to_transform decomposes a row-form affine matrix back to TRS. The
// decomposition is exact when the matrix is shear-free (everything TRS procs
// produce, including uniform-scale compositions); sheared inputs keep their
// exact translation and take rotation from the first column with scales as
// column lengths, preserving reflection via the determinant sign.
affine_to_transform :: proc(a, b, c, d, tx, ty: f32) -> Transform_2D {
	t := Identity_Transform()
	t.Position = Vec2{tx, ty}
	sx := f32(math.sqrt(f64(a*a + c*c)))
	sy := f32(math.sqrt(f64(b*b + d*d)))
	if sx > 0.0000001 {
		t.Rotation = f32(math.atan2(f64(c), f64(a))) * 180 / f32(math.PI)
	}
	if a*d - b*c < 0 {
		sy = -sy
	}
	t.Scale = Vec2{sx, sy}
	return t
}

// Clone_Transform copies a transform, mirroring love Transform:clone.
Clone_Transform :: proc(t: Transform_2D) -> Transform_2D {
	return t
}

// Transform_Set_Transformation sets position, rotation (degrees), scale, and
// pivot in one call, mirroring love Transform:setTransformation
// (x, y, angle, sx, sy, ox, oy, kx, ky). The pivot is baked exactly into
// Position. Shear (kx, ky) is not representable in Transform_2D: the
// representable fields are still set, but .Unsupported is returned so LOVE
// ports fail loudly instead of rendering wrong. See the file header note.
Transform_Set_Transformation :: proc(t: ^Transform_2D, x, y, angle, sx, sy, ox, oy, kx, ky: f32) -> Error {
	if t == nil {
		return .Invalid_Data
	}
	t.Has_Matrix = false
	t.Position = Vec2{x, y}
	t.Rotation = angle
	t.Scale = Vec2{sx, sy}
	if ox != 0 || oy != 0 {
		radians := angle * f32(math.PI) / 180
		cosine := f32(math.cos(f64(radians)))
		sine := f32(math.sin(f64(radians)))
		t.Position.X -= sx*ox*cosine - sy*oy*sine
		t.Position.Y -= sx*ox*sine + sy*oy*cosine
	}
	if kx != 0 || ky != 0 {
		return .Unsupported
	}
	return .None
}

// Transform_Combine returns a * b as matrices, so Transform_Point(c, p)
// equals Transform_Point(a, Transform_Point(b, p)) for shear-free inputs
// (exact for uniform scales; closest-TRS projection otherwise). When either
// input carries a raw-matrix override, the product is exact (matrix multiply)
// and the result carries the override — sheared combinations round-trip.
Transform_Combine :: proc(a, b: Transform_2D) -> Transform_2D {
	if a.Has_Matrix || b.Has_Matrix {
		ma := Transform_Get_Matrix(a)
		mb := Transform_Get_Matrix(b)
		result := Identity_Transform()
		result.Has_Matrix = true
		result.Matrix = mat4_mul(ma, mb)
		return result
	}
	a1, b1, c1, d1, tx1, ty1 := transform_to_affine(a)
	a2, b2, c2, d2, tx2, ty2 := transform_to_affine(b)
	m1, n1, o1, p1, q1, r1 := affine_combine(a1, b1, c1, d1, tx1, ty1, a2, b2, c2, d2, tx2, ty2)
	return affine_to_transform(m1, n1, o1, p1, q1, r1)
}

// Transform_Apply post-multiplies other by t (other = other * t), mirroring
// love Transform:apply: points flow through t first, then the old other.
Transform_Apply :: proc(other: ^Transform_2D, t: Transform_2D) {
	if other == nil {
		return
	}
	other^ = Transform_Combine(other^, t)
}

// Transform_Inverse returns the matrix inverse as TRS, mirroring love
// Transform:inverse (which also returns a new transform). It round-trips with
// Transform_Point/Transform_Point_Inverse for shear-free inputs. Singular
// inputs (zero X or Y scale) have no inverse and are returned unchanged.
// Raw-matrix overrides invert exactly in the 2D affine subset (singular
// matrices return unchanged, same contract).
Transform_Inverse :: proc(t: Transform_2D) -> Transform_2D {
	if t.Has_Matrix {
		a := t.Matrix[0, 0]
		b := t.Matrix[0, 1]
		c := t.Matrix[1, 0]
		d := t.Matrix[1, 1]
		tx := t.Matrix[0, 3]
		ty := t.Matrix[1, 3]
		det := a*d - b*c
		if Abs_F32(det) < 1e-12 {
			return t
		}
		inv := 1 / det
		result := Identity_Transform()
		result.Has_Matrix = true
		result.Matrix = t.Matrix
		result.Matrix[0, 0] = d*inv
		result.Matrix[0, 1] = -b*inv
		result.Matrix[1, 0] = -c*inv
		result.Matrix[1, 1] = a*inv
		result.Matrix[0, 3] = (b*ty-d*tx)*inv
		result.Matrix[1, 3] = (c*tx-a*ty)*inv
		return result
	}
	a, b, c, d, tx, ty := transform_to_affine(t)
	det := a*d - b*c
	if Abs_F32(det) < 1e-12 {
		return t
	}
	inv := 1 / det
	return affine_to_transform(d*inv, -b*inv, -c*inv, a*inv, (b*ty-d*tx)*inv, (c*tx-a*ty)*inv)
}

// v0.10 LOVE Transform:getMatrix/setMatrix parity (exact round-trip via the
// raw-matrix override; see the Transform_2D field docs). Matrices use the
// column-vector convention with translation in column 3, matching
// Transform_Point: out.x = m[0,0]*x + m[0,1]*y + m[0,3].

// mat4_identity returns the 4x4 identity matrix.
mat4_identity :: proc() -> Matrix_4 {
	m := Matrix_4{}
	m[0, 0] = 1
	m[1, 1] = 1
	m[2, 2] = 1
	m[3, 3] = 1
	return m
}

// mat4_mul is the standard row-major product: (a*b)*p == a*(b*p), so it
// matches Transform_Combine's "b first, then a" order.
mat4_mul :: proc(a, b: Matrix_4) -> Matrix_4 {
	result := Matrix_4{}
	for i in 0..<4 {
		for j in 0..<4 {
			sum: f32
			for k in 0..<4 {
				sum += a[i, k]*b[k, j]
			}
			result[i, j] = sum
		}
	}
	return result
}

// Transform_Get_Matrix mirrors love Transform:getMatrix. Override carriers
// return the stored matrix verbatim; TRS transforms convert exactly
// (translation always exact; the 2D affine occupies rows 0-1, row 2 is
// identity, row 3 is [0,0,0,1]).
Transform_Get_Matrix :: proc(t: Transform_2D) -> Matrix_4 {
	if t.Has_Matrix {
		return t.Matrix
	}
	a, b, c, d, tx, ty := transform_to_affine(t)
	m := mat4_identity()
	m[0, 0] = a
	m[0, 1] = b
	m[0, 3] = tx
	m[1, 0] = c
	m[1, 1] = d
	m[1, 3] = ty
	return m
}

// Transform_Set_Matrix mirrors love Transform:setMatrix: stores m verbatim
// (shear/perspective welcome — this is the exact path TRS cannot express).
// Nil handles map to .Invalid_Data.
Transform_Set_Matrix :: proc(t: ^Transform_2D, m: Matrix_4) -> Error {
	if t == nil {
		return .Invalid_Data
	}
	t.Has_Matrix = true
	t.Matrix = m
	return .None
}

// Transform_Clear_Matrix drops a raw-matrix override and returns to TRS
// behavior (TRS fields are untouched). Nil-safe no-op.
Transform_Clear_Matrix :: proc(t: ^Transform_2D) {
	if t != nil {
		t.Has_Matrix = false
	}
}

// Transform_Has_Matrix reports whether a raw-matrix override is active.
Transform_Has_Matrix :: proc(t: Transform_2D) -> bool {
	return t.Has_Matrix
}

// v0.10 Bezier completion (love.math.newBezierCurve method subset).

// Bezier_Render samples `segments` uniform intervals (segments+1 points,
// endpoints inclusive), mirroring love BezierCurve:render. segments <= 0,
// nil curves, and curves with fewer than 2 points map to .Invalid_Data.
// The caller owns the returned array (delete it).
Bezier_Render :: proc(curve: ^Bezier_Curve, segments: int) -> ([dynamic]Vec2, Error) {
	if curve == nil || len(curve.Control_Points) < 2 || segments <= 0 {
		return nil, .Invalid_Data
	}
	points := make([dynamic]Vec2, 0, segments+1)
	for i := 0; i <= segments; i += 1 {
		append(&points, Bezier_Point(curve, f32(i)/f32(segments)))
	}
	return points, .None
}

// bezier_split divides a control polygon at t via de Casteljau, returning
// the left (p0..B(t)) and right (B(t)..pn) sub-polygons. Both are owned.
bezier_split :: proc(points: []Vec2, t: f32) -> (left, right: [dynamic]Vec2) {
	n := len(points)
	left = make([dynamic]Vec2, 0, n)
	right = make([dynamic]Vec2, 0, n)
	if n == 0 {
		return left, right
	}
	levels := make([dynamic]Vec2, n)
	defer delete(levels)
	copy(levels[:], points)
	append(&left, levels[0])
	append(&right, levels[n-1])
	for count := n-1; count > 0; count -= 1 {
		for i := 0; i < count; i += 1 {
			levels[i] = Vec2{Lerp(levels[i].X, levels[i+1].X, t), Lerp(levels[i].Y, levels[i+1].Y, t)}
		}
		append(&left, levels[0])
		// Right side collects from the tip backwards; reverse at the end.
		append(&right, levels[count-1])
	}
	// Right was collected tip-first; reverse to control-point order.
	for i, j := 0, len(right)-1; i < j; i, j = i+1, j-1 {
		right[i], right[j] = right[j], right[i]
	}
	return left, right
}

// Bezier_Segment extracts the sub-curve over [t0, t1] (mirrors love
// BezierCurve:getSegment), returning it as a new owned Bezier_Curve of the
// same degree. Inputs are clamped to [0, 1]; t1 <= t0, nil curves, and
// curves with fewer than 2 points map to .Invalid_Data.
Bezier_Segment :: proc(curve: ^Bezier_Curve, t0, t1: f32) -> (Bezier_Curve, Error) {
	if curve == nil || len(curve.Control_Points) < 2 {
		return Bezier_Curve{}, .Invalid_Data
	}
	start := Clamp(t0, 0, 1)
	end := Clamp(t1, 0, 1)
	if end <= start {
		return Bezier_Curve{}, .Invalid_Data
	}
	left_unused, right := bezier_split(curve.Control_Points[:], start)
	defer delete(left_unused)
	defer delete(right)
	remapped := (end-start)/(1-start) if start < 1 else 1
	segment_points, right_unused := bezier_split(right[:], Clamp(remapped, 0, 1))
	defer delete(right_unused)
	segment := Bezier_Curve{Control_Points = make([dynamic]Vec2, len(segment_points))}
	copy(segment.Control_Points[:], segment_points[:])
	delete(segment_points)
	return segment, .None
}

// Bezier_Control_Points returns a live view of the control polygon (mirrors
// love BezierCurve:getControlPoint reads). Nil curves yield nil. Mutating the
// view edits the curve; use Bezier_Set_Control_Points to replace.
Bezier_Control_Points :: proc(curve: ^Bezier_Curve) -> []Vec2 {
	if curve == nil {
		return nil
	}
	return curve.Control_Points[:]
}

// Bezier_Set_Control_Points replaces the whole control polygon (mirrors love
// BezierCurve:setControlPoint applied to every point). Fewer than 2 points
// maps to .Invalid_Config (same floor as New_Bezier_Curve); nil curves map
// to .Invalid_Data.
Bezier_Set_Control_Points :: proc(curve: ^Bezier_Curve, points: []Vec2) -> Error {
	if curve == nil {
		return .Invalid_Data
	}
	if len(points) < 2 {
		return .Invalid_Config
	}
	replacement := make([dynamic]Vec2, len(points))
	copy(replacement[:], points)
	delete(curve.Control_Points)
	curve.Control_Points = replacement
	return .None
}

// Bezier_Degree returns len(control points)-1 (0 for nil/degenerate curves).
Bezier_Degree :: proc(curve: ^Bezier_Curve) -> int {
	if curve == nil || len(curve.Control_Points) == 0 {
		return 0
	}
	return len(curve.Control_Points)-1
}
