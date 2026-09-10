package tests

import corehash "core:hash"
import "core:testing"
import thor2d "thor2d:thor2d"

v09_abs_diff :: proc(a, b: f32) -> f32 {
	d := a - b
	return d if d >= 0 else -d
}

v09_read_u32_be :: proc(b: []u8, at: int) -> u32 {
	return u32(b[at])<<24 | u32(b[at+1])<<16 | u32(b[at+2])<<8 | u32(b[at+3])
}

@(test)
test_v09_paste_clipping :: proc(t: ^testing.T) {
	black := thor2d.Color{0, 0, 0, 255}
	red := thor2d.Color{255, 0, 0, 255}
	src, src_err := thor2d.New_Image_Data(2, 2, red)
	testing.expect(t, src_err == .None)
	defer thor2d.Destroy_Image_Data(&src)

	// Bottom-right corner clip: only dst (3,3) is covered.
	dst, dst_err := thor2d.New_Image_Data(4, 4, black)
	testing.expect(t, dst_err == .None)
	defer thor2d.Destroy_Image_Data(&dst)
	testing.expect(t, thor2d.Paste_Image(&dst, &src, 3, 3) == .None)
	for y := 0; y < 4; y += 1 {
		for x := 0; x < 4; x += 1 {
			c, _ := thor2d.Get_Image_Pixel(&dst, x, y)
			want_red := x == 3 && y == 3
			testing.expect(t, (c == red) == want_red)
		}
	}

	// Top-left corner clip: only dst (0,0) is covered.
	dst2, _ := thor2d.New_Image_Data(4, 4, black)
	defer thor2d.Destroy_Image_Data(&dst2)
	testing.expect(t, thor2d.Paste_Image(&dst2, &src, -1, -1) == .None)
	for y := 0; y < 4; y += 1 {
		for x := 0; x < 4; x += 1 {
			c, _ := thor2d.Get_Image_Pixel(&dst2, x, y)
			testing.expect(t, (c == red) == (x == 0 && y == 0))
		}
	}

	// Fully out-of-bounds paste is a successful no-op.
	before := thor2d.Image_Data_Bytes(&dst2)
	testing.expect(t, thor2d.Paste_Image(&dst2, &src, 10, 10) == .None)
	after := thor2d.Image_Data_Bytes(&dst2)
	testing.expect(t, len(before) == len(after))
	for i := 0; i < len(before); i += 1 {
		if before[i] != after[i] {
			testing.expect(t, false)
			break
		}
	}

	// Nil handles are rejected, never faked.
	testing.expect(t, thor2d.Paste_Image(nil, &src, 0, 0) == .Invalid_Data)
	testing.expect(t, thor2d.Paste_Image(&dst2, nil, 0, 0) == .Invalid_Data)
}

@(test)
test_v09_map_roundtrip :: proc(t: ^testing.T) {
	img, img_err := thor2d.New_Image_Data(2, 1, thor2d.Color{0, 0, 0, 255})
	testing.expect(t, img_err == .None)
	defer thor2d.Destroy_Image_Data(&img)
	testing.expect(t, thor2d.Set_Image_Pixel(&img, 0, 0, thor2d.Color{10, 20, 30, 40}) == .None)
	testing.expect(t, thor2d.Set_Image_Pixel(&img, 1, 0, thor2d.Color{200, 150, 100, 255}) == .None)

	invert :: proc(c: thor2d.Color) -> thor2d.Color {
		return thor2d.Color{255 - c.R, 255 - c.G, 255 - c.B, c.A}
	}
	testing.expect(t, thor2d.Map_Pixel(&img, invert) == .None)
	a, _ := thor2d.Get_Image_Pixel(&img, 0, 0)
	testing.expect(t, a == thor2d.Color{245, 235, 225, 40})
	b, _ := thor2d.Get_Image_Pixel(&img, 1, 0)
	testing.expect(t, b == thor2d.Color{55, 105, 155, 255})

	// Double inversion round-trips to the original pixels.
	testing.expect(t, thor2d.Map_Pixel(&img, invert) == .None)
	a2, _ := thor2d.Get_Image_Pixel(&img, 0, 0)
	testing.expect(t, a2 == thor2d.Color{10, 20, 30, 40})

	testing.expect(t, thor2d.Map_Pixel(nil, invert) == .Invalid_Data)
	testing.expect(t, thor2d.Map_Pixel(&img, nil) == .Invalid_Data)
}

@(test)
test_v09_encode_png :: proc(t: ^testing.T) {
	img, img_err := thor2d.New_Image_Data(3, 2, thor2d.Color{0, 0, 0, 255})
	testing.expect(t, img_err == .None)
	defer thor2d.Destroy_Image_Data(&img)
	colors := [6]thor2d.Color{
		{255, 0, 0, 255}, {0, 255, 0, 255}, {0, 0, 255, 255},
		{255, 255, 0, 128}, {0, 255, 255, 1}, {255, 0, 255, 0},
	}
	for i := 0; i < 6; i += 1 {
		testing.expect(t, thor2d.Set_Image_Pixel(&img, i%3, i/3, colors[i]) == .None)
	}

	png, enc_err := thor2d.Encode_Image_PNG(&img)
	testing.expect(t, enc_err == .None)
	defer thor2d.Destroy_Byte_Buffer(&png)
	bytes := png.Bytes[:]
	testing.expect(t, len(bytes) > 8+13+12+12)

	// PNG signature.
	sig := [8]u8{137, 80, 78, 71, 13, 10, 26, 10}
	for i := 0; i < 8; i += 1 {
		testing.expect(t, bytes[i] == sig[i])
	}

	// Walk chunks: IHDR first with matching dimensions, IEND last, CRCs valid.
	idat := make([dynamic]u8, 0, 64)
	defer delete(idat)
	at := 8
	first := true
	seen_iend := false
	for at+8 <= len(bytes) {
		length := int(v09_read_u32_be(bytes, at))
		kind := string(bytes[at+4:at+8])
		testing.expect(t, at+12+length <= len(bytes))
		data := bytes[at+8:at+8+length]
		stored_crc := v09_read_u32_be(bytes, at+8+length)
		testing.expect(t, corehash.crc32(bytes[at+4:at+8+length]) == stored_crc)
		if first {
			testing.expect(t, kind == "IHDR" && length == 13)
			testing.expect(t, int(v09_read_u32_be(data, 0)) == 3)
			testing.expect(t, int(v09_read_u32_be(data, 4)) == 2)
			testing.expect(t, data[8] == 8 && data[9] == 6) // 8-bit RGBA
			first = false
		}
		if kind == "IDAT" {
			append(&idat, ..data)
		}
		if kind == "IEND" {
			testing.expect(t, length == 0)
			seen_iend = true
			at += 12 + length
			break
		}
		at += 12 + length
	}
	testing.expect(t, seen_iend && at == len(bytes) && len(idat) > 0)

	// IDAT must be a zlib stream of filter-0 scanlines reproducing the pixels.
	stride := 3*4
	raw_size := (stride+1)*2
	framed := make([dynamic]u8, 0, 8+len(idat))
	defer delete(framed)
	for i := 0; i < 8; i += 1 {
		append(&framed, u8(raw_size >> (uint(i) * 8)))
	}
	append(&framed, ..idat[:])
	raw, dec_err := thor2d.Decompress_Data(thor2d.Compressed_Data{Buffer = thor2d.Byte_Buffer{Bytes = framed}, Format = .ZLIB})
	testing.expect(t, dec_err == .None)
	defer thor2d.Destroy_Byte_Buffer(&raw)
	testing.expect(t, len(raw.Bytes) == raw_size)
	for y := 0; y < 2; y += 1 {
		row := raw.Bytes[y*(stride+1):(y+1)*(stride+1)]
		testing.expect(t, row[0] == 0)
		for x := 0; x < 3; x += 1 {
			want := colors[y*3+x]
			got := thor2d.Color{row[1+x*4], row[1+x*4+1], row[1+x*4+2], row[1+x*4+3]}
			testing.expect(t, got == want)
		}
	}

	testing.expect(t, proc() -> bool {
		_, err := thor2d.Encode_Image_PNG(nil)
		return err == .Invalid_Data
	}())
}

@(test)
test_v09_transform_compose_inverse :: proc(t: ^testing.T) {
	// Set_Transformation bakes the pivot: the pivot maps to (x, y).
	tr := thor2d.Identity_Transform()
	testing.expect(t, thor2d.Transform_Set_Transformation(&tr, 10, 20, 30, 2, 3, 4, 5, 0, 0) == .None)
	pivot := thor2d.Transform_Point(tr, thor2d.Vec2{4, 5})
	testing.expect(t, v09_abs_diff(pivot.X, 10) < 0.01 && v09_abs_diff(pivot.Y, 20) < 0.01)
	testing.expect(t, tr.Rotation == 30 && tr.Scale == thor2d.Vec2{2, 3})

	// Shear is not representable in TRS: loud error, never silent.
	testing.expect(t, thor2d.Transform_Set_Transformation(&tr, 0, 0, 0, 1, 1, 0, 0, 1, 0) == .Unsupported)
	testing.expect(t, thor2d.Transform_Set_Transformation(nil, 0, 0, 0, 1, 1, 0, 0, 0, 0) == .Invalid_Data)

	// Clone is an exact copy.
	clone := thor2d.Clone_Transform(tr)
	testing.expect(t, clone == tr)

	// Combine (uniform scales): nested application matches the combined point.
	a := thor2d.Identity_Transform()
	testing.expect(t, thor2d.Transform_Set_Transformation(&a, 10, 20, 30, 2, 2, 0, 0, 0, 0) == .None)
	b := thor2d.Identity_Transform()
	testing.expect(t, thor2d.Transform_Set_Transformation(&b, 5, -3, -15, 1, 1, 0, 0, 0, 0) == .None)
	c := thor2d.Transform_Combine(a, b)
	points := [3]thor2d.Vec2{{0, 0}, {4, -2}, {-7, 9}}
	for p in points {
		nested := thor2d.Transform_Point(a, thor2d.Transform_Point(b, p))
		combined := thor2d.Transform_Point(c, p)
		testing.expect(t, v09_abs_diff(combined.X, nested.X) < 0.01 && v09_abs_diff(combined.Y, nested.Y) < 0.01)
	}

	// Combine (non-uniform scales, no rotation) stays shear-free and exact.
	d := thor2d.Identity_Transform()
	testing.expect(t, thor2d.Transform_Set_Transformation(&d, 1, 2, 0, 2, 3, 0, 0, 0, 0) == .None)
	e := thor2d.Identity_Transform()
	testing.expect(t, thor2d.Transform_Set_Transformation(&e, -4, 6, 0, 0.5, 4, 0, 0, 0, 0) == .None)
	de := thor2d.Transform_Combine(d, e)
	for p in points {
		nested := thor2d.Transform_Point(d, thor2d.Transform_Point(e, p))
		combined := thor2d.Transform_Point(de, p)
		testing.expect(t, v09_abs_diff(combined.X, nested.X) < 0.01 && v09_abs_diff(combined.Y, nested.Y) < 0.01)
	}

	// Apply post-multiplies: Identity.apply(a) behaves like a.
	applied := thor2d.Identity_Transform()
	thor2d.Transform_Apply(&applied, a)
	for p in points {
		got := thor2d.Transform_Point(applied, p)
		want := thor2d.Transform_Point(a, p)
		testing.expect(t, v09_abs_diff(got.X, want.X) < 0.01 && v09_abs_diff(got.Y, want.Y) < 0.01)
	}
	thor2d.Transform_Apply(nil, a) // nil-tolerant, no crash

	// Inverse round-trips consistently with the existing inverse proc.
	inv := thor2d.Transform_Inverse(a)
	for p in points {
		there := thor2d.Transform_Point(a, p)
		back := thor2d.Transform_Point(inv, there)
		testing.expect(t, v09_abs_diff(back.X, p.X) < 0.01 && v09_abs_diff(back.Y, p.Y) < 0.01)
		legacy := thor2d.Transform_Point_Inverse(a, there)
		testing.expect(t, v09_abs_diff(back.X, legacy.X) < 0.01 && v09_abs_diff(back.Y, legacy.Y) < 0.01)
	}

	// Singular transforms have no inverse and come back unchanged.
	singular := thor2d.Identity_Transform()
	singular.Scale = thor2d.Vec2{0, 1}
	testing.expect(t, thor2d.Transform_Inverse(singular) == singular)
}

@(test)
test_v09_shape_material :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	world, world_err := thor2d.Create_Physics_World(&ctx)
	testing.expect(t, world_err == .None)
	defer thor2d.Destroy_All_Physics(&ctx)
	body, body_err := thor2d.Create_Physics_Body(&ctx, world, thor2d.Default_Physics_Body_Def())
	testing.expect(t, body_err == .None)

	def := thor2d.Default_Physics_Shape_Def()
	def.Friction = 0.7
	def.Restitution = 0.25
	def.Density = 2.0
	shape, shape_err := thor2d.Create_Box_Shape(&ctx, body, 32, 16, def)
	testing.expect(t, shape_err == .None)

	// Creation-time values are readable back.
	testing.expect(t, v09_abs_diff(thor2d.Physics_Shape_Friction(&ctx, shape), 0.7) < 0.0001)
	testing.expect(t, v09_abs_diff(thor2d.Physics_Shape_Restitution(&ctx, shape), 0.25) < 0.0001)
	testing.expect(t, v09_abs_diff(thor2d.Physics_Shape_Density(&ctx, shape), 2.0) < 0.0001)
	testing.expect(t, !thor2d.Physics_Shape_Is_Sensor(&ctx, shape))

	// Runtime setters round-trip through the getters.
	testing.expect(t, thor2d.Physics_Shape_Set_Friction(&ctx, shape, 0.1) == .None)
	testing.expect(t, v09_abs_diff(thor2d.Physics_Shape_Friction(&ctx, shape), 0.1) < 0.0001)
	testing.expect(t, thor2d.Physics_Shape_Set_Restitution(&ctx, shape, 0.9) == .None)
	testing.expect(t, v09_abs_diff(thor2d.Physics_Shape_Restitution(&ctx, shape), 0.9) < 0.0001)
	testing.expect(t, thor2d.Physics_Shape_Set_Density(&ctx, shape, 3.0) == .None)
	testing.expect(t, v09_abs_diff(thor2d.Physics_Shape_Density(&ctx, shape), 3.0) < 0.0001)
	testing.expect(t, thor2d.Physics_Shape_Set_Density(&ctx, shape, -1) == .Invalid_Data)

	// Sensor state cannot change after creation: no-op success when matching,
	// .Unsupported otherwise (Box2D 3.x forbids sensor<->solid transitions).
	testing.expect(t, thor2d.Physics_Shape_Set_Sensor(&ctx, shape, false) == .None)
	testing.expect(t, thor2d.Physics_Shape_Set_Sensor(&ctx, shape, true) == .Unsupported)

	sensor_def := thor2d.Default_Physics_Shape_Def()
	sensor_def.Sensor = true
	sensor, sensor_err := thor2d.Create_Circle_Shape(&ctx, body, 8, sensor_def)
	testing.expect(t, sensor_err == .None)
	testing.expect(t, thor2d.Physics_Shape_Is_Sensor(&ctx, sensor))
	testing.expect(t, thor2d.Physics_Shape_Set_Sensor(&ctx, sensor, true) == .None)
	testing.expect(t, thor2d.Physics_Shape_Set_Sensor(&ctx, sensor, false) == .Unsupported)

	// Chain setters apply to every segment and read back.
	chain, chain_err := thor2d.Create_Chain_Shape(&ctx, body, []thor2d.Vec2{{0, 0}, {10, 0}, {10, 10}, {0, 10}}, true)
	testing.expect(t, chain_err == .None)
	testing.expect(t, thor2d.Physics_Shape_Set_Friction(&ctx, chain, 0.9) == .None)
	testing.expect(t, v09_abs_diff(thor2d.Physics_Shape_Friction(&ctx, chain), 0.9) < 0.0001)
	testing.expect(t, thor2d.Physics_Shape_Set_Restitution(&ctx, chain, 0.4) == .None)
	testing.expect(t, v09_abs_diff(thor2d.Physics_Shape_Restitution(&ctx, chain), 0.4) < 0.0001)

	// Unknown handles fail loudly; getters degrade to zero values.
	bogus := thor2d.Physics_Shape{999999}
	testing.expect(t, thor2d.Physics_Shape_Set_Friction(&ctx, bogus, 0.5) == .Invalid_Handle)
	testing.expect(t, thor2d.Physics_Shape_Set_Restitution(&ctx, bogus, 0.5) == .Invalid_Handle)
	testing.expect(t, thor2d.Physics_Shape_Set_Density(&ctx, bogus, 1) == .Invalid_Handle)
	testing.expect(t, thor2d.Physics_Shape_Set_Sensor(&ctx, bogus, false) == .Invalid_Handle)
	testing.expect(t, thor2d.Physics_Shape_Friction(&ctx, bogus) == 0)
	testing.expect(t, thor2d.Physics_Shape_Restitution(&ctx, bogus) == 0)
	testing.expect(t, thor2d.Physics_Shape_Density(&ctx, bogus) == 0)
	testing.expect(t, !thor2d.Physics_Shape_Is_Sensor(&ctx, bogus))
}
