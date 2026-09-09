package thor2d

Rects_Overlap :: proc(a, b: Rect) -> bool {
	return a.X < b.X+b.W && a.X+a.W > b.X && a.Y < b.Y+b.H && a.Y+a.H > b.Y
}

Point_In_Rect :: proc(point: Vec2, rect: Rect) -> bool {
	return point.X >= rect.X && point.X <= rect.X+rect.W && point.Y >= rect.Y && point.Y <= rect.Y+rect.H
}

Circle_Overlap :: proc(a_center: Vec2, a_radius: f32, b_center: Vec2, b_radius: f32) -> bool {
	delta := Vec2_Sub(a_center, b_center)
	radius := a_radius + b_radius
	return Vec2_Length_Squared(delta) <= radius*radius
}
