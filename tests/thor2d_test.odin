package tests

import "core:testing"
import thor2d "thor2d:thor2d"

@(test)
test_vec2_math :: proc(t: ^testing.T) {
	a := thor2d.Vec2{2, 3}
	b := thor2d.Vec2{4, -1}
	got := thor2d.Vec2_Add(a, b)
	testing.expect(t, got.X == 6 && got.Y == 2)
	testing.expect(t, thor2d.Vec2_Length_Squared(a) == 13)
}

@(test)
test_geometry :: proc(t: ^testing.T) {
	testing.expect(t, thor2d.Rects_Overlap(thor2d.Rect{0, 0, 10, 10}, thor2d.Rect{5, 5, 10, 10}))
	testing.expect(t, !thor2d.Rects_Overlap(thor2d.Rect{0, 0, 10, 10}, thor2d.Rect{20, 20, 10, 10}))
	testing.expect(t, thor2d.Point_In_Rect(thor2d.Vec2{4, 4}, thor2d.Rect{0, 0, 10, 10}))
	testing.expect(t, thor2d.Circle_Overlap(thor2d.Vec2{0, 0}, 4, thor2d.Vec2{7, 0}, 4))
}

@(test)
test_config_validation :: proc(t: ^testing.T) {
	config := thor2d.Default_Config()
	testing.expect(t, config.Width > 0 && config.Height > 0)
	testing.expect(t, thor2d.Error_String(.None) == "no error")
}

@(test)
test_v02_types_and_handles :: proc(t: ^testing.T) {
	quad := thor2d.New_Quad(thor2d.Texture{42}, thor2d.Rect{4, 8, 16, 24})
	testing.expect(t, quad.Source.X == 4 && quad.Source.H == 24)
	testing.expect(t, thor2d.Event_Kind.Quit != thor2d.Event_Kind.Key_Pressed)
	testing.expect(t, thor2d.Texture_Invalid(thor2d.Texture{}))
	testing.expect(t, thor2d.Canvas_Invalid(thor2d.Canvas{}))
	testing.expect(t, thor2d.Shader_Invalid(thor2d.Shader{}))
	testing.expect(t, thor2d.Sprite_Batch_Invalid(thor2d.Sprite_Batch{}))
	testing.expect(t, thor2d.Particle_System_Invalid(thor2d.Particle_System{}))
}

@(test)
test_transform_composition_and_restore :: proc(t: ^testing.T) {
	transform := thor2d.Identity_Transform()
	thor2d.Transform_Translate(&transform, thor2d.Vec2{10, 20})
	thor2d.Transform_Scale(&transform, thor2d.Vec2{2, 3})
	thor2d.Transform_Rotate(&transform, 90)
	point := thor2d.Transform_Point(transform, thor2d.Vec2{1, 0})
	testing.expect(t, thor2d.Abs_F32(point.X - 10) < 0.01)
	testing.expect(t, thor2d.Abs_F32(point.Y - 22) < 0.01)

	saved := transform
	thor2d.Transform_Translate(&transform, thor2d.Vec2{100, 100})
	transform = saved
	testing.expect(t, transform.Position.X == saved.Position.X && transform.Position.Y == saved.Position.Y)
}

@(test)
test_camera_coordinate_conversion :: proc(t: ^testing.T) {
	camera := thor2d.Camera_2D{Target = thor2d.Vec2{100, 50}, Offset = thor2d.Vec2{320, 180}, Zoom = 2}
	screen := thor2d.Camera_Point_To_Screen(camera, thor2d.Vec2{110, 60})
	testing.expect(t, screen.X == 340 && screen.Y == 200)
	world := thor2d.Camera_Screen_To_Point(camera, screen)
	testing.expect(t, thor2d.Abs_F32(world.X-110) < 0.01 && thor2d.Abs_F32(world.Y-60) < 0.01)
}

@(test)
test_inverse_transform_and_text_types :: proc(t: ^testing.T) {
	transform := thor2d.Transform_2D{Position = thor2d.Vec2{10, 20}, Scale = thor2d.Vec2{2, 3}, Rotation = 35}
	point := thor2d.Vec2{4, -2}
	transformed := thor2d.Transform_Point(transform, point)
	restored := thor2d.Transform_Point_Inverse(transform, transformed)
	testing.expect(t, thor2d.Abs_F32(restored.X-point.X) < 0.01 && thor2d.Abs_F32(restored.Y-point.Y) < 0.01)
	testing.expect(t, thor2d.Text_Invalid(thor2d.Text{}))
	testing.expect(t, thor2d.Event_Kind.Touch_Moved != thor2d.Event_Kind.File_Dropped)
}

@(test)
test_particle_defaults_are_deterministic :: proc(t: ^testing.T) {
	a := thor2d.Default_Particle_Config(64)
	b := thor2d.Default_Particle_Config(64)
	testing.expect(t, a.Max_Particles == b.Max_Particles)
	testing.expect(t, a.Lifetime_Min == b.Lifetime_Min && a.Lifetime_Max == b.Lifetime_Max)
	testing.expect(t, a.Start_Color.A == 255 && a.End_Color.A == 0)
}

@(test)
test_ecs_generational_sparse_set :: proc(t: ^testing.T) {
	registry := thor2d.New_Registry()
	defer thor2d.Destroy_Registry(&registry)
	first := thor2d.Create_Entity(&registry)
	second := thor2d.Create_Entity(&registry)
	thor2d.Add_Component(&registry, first, thor2d.Transform_2D_Default())
	thor2d.Add_Component(&registry, second, thor2d.Transform_2D{Position = thor2d.Vec2{4, 5}, Scale = thor2d.Vec2{1, 1}})
	testing.expect(t, thor2d.Entity_Alive(&registry, first))
	testing.expect(t, thor2d.Has_Component(&registry, second, thor2d.Transform_2D))
	thor2d.Destroy_Entity(&registry, first)
	testing.expect(t, !thor2d.Entity_Alive(&registry, first))
	reused := thor2d.Create_Entity(&registry)
	testing.expect(t, reused != first && thor2d.Entity_Alive(&registry, reused))
	count := 0
	iterator := thor2d.Query(&registry, thor2d.Transform_2D)
	for {
		_, _, ok := thor2d.Query_Next(&iterator)
		if !ok {
			break
		}
		count += 1
	}
	testing.expect(t, count == 1)
}

@(test)
test_box2d_world_and_fixed_step :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	world, err := thor2d.Create_Physics_World(&ctx)
	testing.expect(t, err == .None && !thor2d.Physics_World_Invalid(world))
	body_def := thor2d.Physics_Body_Def{Type = .Dynamic, Position = thor2d.Vec2{0, 0}, Gravity_Scale = 1, Enable_Sleep = false}
	body, body_err := thor2d.Create_Physics_Body(&ctx, world, body_def)
	testing.expect(t, body_err == .None && !thor2d.Physics_Body_Invalid(body))
	shape, shape_err := thor2d.Create_Box_Shape(&ctx, body, 16, 16)
	testing.expect(t, shape_err == .None && !thor2d.Physics_Shape_Invalid(shape))
	thor2d.Step_Physics(&ctx, world, 1.0/60.0)
	position := thor2d.Physics_Body_Position(&ctx, body)
	testing.expect(t, position.Y > 0)
	thor2d.Destroy_All_Physics(&ctx)
}

@(test)
test_box2d_polygon_filters_and_joints :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	world, world_err := thor2d.Create_Physics_World(&ctx)
	testing.expect(t, world_err == .None)
	static_def := thor2d.Default_Physics_Body_Def()
	static_def.Type = .Static
	static_body, static_err := thor2d.Create_Physics_Body(&ctx, world, static_def)
	dynamic_body, dynamic_err := thor2d.Create_Physics_Body(&ctx, world, thor2d.Default_Physics_Body_Def())
	testing.expect(t, static_err == .None && dynamic_err == .None)
	shape_def := thor2d.Default_Physics_Shape_Def()
	shape_def.Category_Bits = 1
	shape_def.Mask_Bits = 2
	polygon, polygon_err := thor2d.Create_Polygon_Shape(&ctx, dynamic_body, []thor2d.Vec2{{-1, -1}, {1, -1}, {0, 1}}, 0, shape_def)
	testing.expect(t, polygon_err == .None && !thor2d.Physics_Shape_Invalid(polygon))
	joint_kinds: [4]thor2d.Physics_Joint_Kind = {thor2d.Physics_Joint_Kind.Motor, thor2d.Physics_Joint_Kind.Mouse, thor2d.Physics_Joint_Kind.Prismatic, thor2d.Physics_Joint_Kind.Wheel}
	for kind in joint_kinds {
		joint, joint_err := thor2d.Create_Physics_Joint(&ctx, world, thor2d.Physics_Joint_Def{
			Kind = kind,
			Body_A = static_body,
			Body_B = dynamic_body,
			Axis = thor2d.Vec2{1, 0},
			Max_Force = 10,
			Max_Torque = 10,
		})
		testing.expect(t, joint_err == .None && !thor2d.Physics_Joint_Invalid(joint))
	}
	thor2d.Destroy_All_Physics(&ctx)
}

@(test)
test_data_codecs_and_hashes :: proc(t: ^testing.T) {
	value := "thor2d"
	input := transmute([]byte)value
	encoded, encode_err := thor2d.Encode_Base64(input)
	defer delete(encoded)
	decoded, decode_err := thor2d.Decode_Base64(encoded)
	defer thor2d.Destroy_Byte_Buffer(&decoded)
	testing.expect(t, encode_err == .None && decode_err == .None)
	testing.expect(t, string(decoded.Bytes[:]) == "thor2d")
	hash, hash_err := thor2d.Hash_Hex(.SHA256, input)
	defer delete(hash)
	testing.expect(t, hash_err == .None && len(hash) == 64)
	compressed, compress_err := thor2d.Create_Compressed_Data(input, .LZ4)
	defer thor2d.Destroy_Byte_Buffer(&compressed.Buffer)
	decompressed, decompress_err := thor2d.Decompress_Data(compressed)
	defer thor2d.Destroy_Byte_Buffer(&decompressed)
	testing.expect(t, compress_err == .None && decompress_err == .None)
	testing.expect(t, string(decompressed.Bytes[:]) == "thor2d")
	 gzip, gzip_err := thor2d.Create_Compressed_Data(input, thor2d.Compression_Format.GZIP)
	 gzip_data, gzip_decode_err := thor2d.Decompress_Data(gzip)
	 testing.expect(t, gzip_err == .None && gzip_decode_err == .None && string(gzip_data.Bytes[:]) == "thor2d")
	 thor2d.Destroy_Byte_Buffer(&gzip.Buffer)
	 thor2d.Destroy_Byte_Buffer(&gzip_data)
	 deflate, deflate_err := thor2d.Create_Compressed_Data(input, thor2d.Compression_Format.DEFLATE)
	 deflate_data, deflate_decode_err := thor2d.Decompress_Data(deflate)
	 testing.expect(t, deflate_err == .None && deflate_decode_err == .None && string(deflate_data.Bytes[:]) == "thor2d")
	 thor2d.Destroy_Byte_Buffer(&deflate.Buffer)
	 thor2d.Destroy_Byte_Buffer(&deflate_data)
}

@(test)
test_image_data_and_rng :: proc(t: ^testing.T) {
	image, image_err := thor2d.New_Image_Data(2, 2, thor2d.Red)
	defer thor2d.Destroy_Image_Data(&image)
	pixel, pixel_err := thor2d.Get_Image_Pixel(&image, 1, 1)
	testing.expect(t, image_err == .None && pixel_err == .None && pixel == thor2d.Red)
	thor2d.Set_Image_Pixel(&image, 0, 0, thor2d.Blue)
	changed, _ := thor2d.Get_Image_Pixel(&image, 0, 0)
	testing.expect(t, changed == thor2d.Blue)
	a := thor2d.New_Random_Generator(42)
	b := thor2d.New_Random_Generator(42)
	testing.expect(t, thor2d.Random_Next_U64(&a) == thor2d.Random_Next_U64(&b))
}

@(test)
test_headless_capability_and_package_mount :: proc(t: ^testing.T) {
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, create_err := thor2d.Create(config)
	testing.expect(t, create_err == .None)
	if create_err != .None {
		return
	}
	testing.expect(t, thor2d.Query_Capability(&ctx, .Headless))
	thor2d.Destroy(&ctx)

	if !thor2d.File_Exists("build/platformer_v03.thor") {
		return
	}
	filesystem, fs_err := thor2d.Init_Filesystem(".", ".thor2d-test-save")
	testing.expect(t, fs_err == .None)
	if fs_err != .None {
		return
	}
	defer thor2d.Destroy_Filesystem(&filesystem)
	mount_err := thor2d.Mount_Archive(&filesystem, "build/platformer_v03.thor")
	testing.expect(t, mount_err == .None)
	if mount_err == .None {
		file, read_err := thor2d.Read_Path(&filesystem, "project.json")
		testing.expect(t, read_err == .None && len(file.Bytes) > 0)
		thor2d.Destroy_File_Data(&file)
		testing.expect(t, thor2d.Unmount_Archive(&filesystem, "build/platformer_v03.thor") == .None)
	}
}

@(test)
test_sound_data_and_video_capability :: proc(t: ^testing.T) {
	data, data_err := thor2d.New_Sound_Data(48000, 2, 32)
	testing.expect(t, data_err == .None && thor2d.Sound_Data_Sample_Count(&data) == 64)
	testing.expect(t, thor2d.Fill_Sine_Wave(&data, 440, 0.25) == .None)
	sample, sample_err := thor2d.Get_Sound_Data_Sample(&data, 1)
	testing.expect(t, sample_err == .None && sample <= 0.25 && sample >= -0.25)
	thor2d.Destroy_Sound_Data(&data)
	config := thor2d.Default_Config()
	config.Headless = true
	ctx, ctx_err := thor2d.Create(config)
	testing.expect(t, ctx_err == .None)
	if ctx_err == .None {
		testing.expect(t, !thor2d.Query_Capability(&ctx, .Video))
		thor2d.Destroy(&ctx)
	}
}

@(test)
test_typed_channel :: proc(t: ^testing.T) {
	channel, err := thor2d.New_Channel(int, 2)
	defer thor2d.Destroy_Channel(&channel)
	testing.expect(t, err == .None)
	testing.expect(t, thor2d.Try_Send(&channel, 7))
	value, received := thor2d.Try_Receive(&channel)
	testing.expect(t, received && value == 7)
}

@(test)
test_v07_data_view_and_binary_pack :: proc(t: ^testing.T) {
	buffer := thor2d.New_Byte_Buffer([]byte{1, 2, 3, 4, 5, 6})
	defer thor2d.Destroy_Byte_Buffer(&buffer)
	view, view_err := thor2d.Byte_Buffer_View(&buffer, 1, 4)
	testing.expect(t, view_err == .None && len(view.Bytes) == 4 && view.Bytes[0] == 2)
	view.Bytes[0] = 9
	testing.expect(t, buffer.Bytes[1] == 9)
	packed := thor2d.Pack_U32(0x78563412)
	defer thor2d.Destroy_Byte_Buffer(&packed)
	value, unpack_err := thor2d.Unpack_U32(packed.Bytes[:])
	testing.expect(t, unpack_err == .None && value == 0x78563412)
	float_data := thor2d.Pack_F32(3.5)
	defer thor2d.Destroy_Byte_Buffer(&float_data)
	float_value, float_err := thor2d.Unpack_F32(float_data.Bytes[:])
	testing.expect(t, float_err == .None && thor2d.Abs_F32(float_value-3.5) < 0.0001)
}

@(test)
test_v07_sound_data_conversion :: proc(t: ^testing.T) {
	data, err := thor2d.New_Sound_Data(4, 1, 4)
	testing.expect(t, err == .None)
	data.Samples[0] = 0
	data.Samples[1] = 1
	data.Samples[2] = 0
	data.Samples[3] = -1
	clone, clone_err := thor2d.Clone_Sound_Data(&data)
	defer thor2d.Destroy_Sound_Data(&data)
	defer thor2d.Destroy_Sound_Data(&clone)
	clone.Samples[0] = 7
	testing.expect(t, clone_err == .None && data.Samples[0] == 0 && thor2d.Sound_Data_Frame_Count(&data) == 4)
	converted, converted_err := thor2d.Convert_Sound_Data(&data, 8, 2)
	defer thor2d.Destroy_Sound_Data(&converted)
	testing.expect(t, converted_err == .None && thor2d.Sound_Data_Frame_Count(&converted) == 8 && len(converted.Samples) == 16)
}

@(test)
test_v07_math_geometry :: proc(t: ^testing.T) {
	curve, curve_err := thor2d.New_Bezier_Curve([]thor2d.Vec2{{0, 0}, {2, 2}, {4, 0}})
	defer thor2d.Destroy_Bezier_Curve(&curve)
	point := thor2d.Bezier_Point(&curve, 0.5)
	testing.expect(t, curve_err == .None && thor2d.Abs_F32(point.X-2) < 0.001 && thor2d.Abs_F32(point.Y-1) < 0.001)
	polygon := []thor2d.Vec2{{0, 0}, {4, 0}, {4, 4}, {0, 4}}
	testing.expect(t, thor2d.Is_Convex_Polygon(polygon))
	triangles, triangulate_err := thor2d.Triangulate_Polygon(polygon)
	defer delete(triangles)
	testing.expect(t, triangulate_err == .None && len(triangles) == 6)
}

@(test)
test_public_event_queue_and_project_manifest :: proc(t: ^testing.T) {
	ctx := thor2d.Context{}
	thor2d.Push_Event(&ctx, thor2d.Event{Kind = .File_Dropped, Path = "assets/test.png"})
	event, ok := thor2d.Poll_Event(&ctx)
	defer thor2d.Destroy_Event(&event)
	defer thor2d.Destroy(&ctx)
	testing.expect(t, ok && event.Kind == .File_Dropped && event.Path == "assets/test.png")

	project := thor2d.New_Project("Test", "test.project")
	defer thor2d.Destroy_Project(&project)
	asset_id, asset_err := thor2d.Add_Project_Asset(&project, "textures/player.png", "texture")
	testing.expect(t, asset_err == .None && asset_id == thor2d.Asset_Id_From_Path("textures/player.png"))
	testing.expect(t, thor2d.Validate_Project(&project) == .None)
	encoded, encode_err := thor2d.Encode_JSON(&project)
	defer thor2d.Destroy_Byte_Buffer(&encoded)
	testing.expect(t, encode_err == .None)
	decoded: thor2d.Project
	testing.expect(t, thor2d.Decode_JSON(encoded.Bytes[:], &decoded) == .None)
	testing.expect(t, decoded.Schema_Version == 1 && decoded.Project_Id == "test.project")
	thor2d.Destroy_Project(&decoded)
}

@(test)
test_physics_shapes_joint_and_raycast :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	world, world_err := thor2d.Create_Physics_World(&ctx)
	static_def := thor2d.Default_Physics_Body_Def()
	static_def.Type = .Static
	static_body, static_err := thor2d.Create_Physics_Body(&ctx, world, static_def)
	dynamic_body, dynamic_err := thor2d.Create_Physics_Body(&ctx, world)
	_, capsule_err := thor2d.Create_Capsule_Shape(&ctx, dynamic_body, 4, 8)
	joint, joint_err := thor2d.Create_Physics_Joint(&ctx, world, thor2d.Physics_Joint_Def{Kind = .Distance, Body_A = static_body, Body_B = dynamic_body, Length = 20})
	 hit := thor2d.Physics_Raycast_Closest(&ctx, world, thor2d.Vec2{-100, 0}, thor2d.Vec2{200, 0})
	testing.expect(t, world_err == .None && static_err == .None && dynamic_err == .None)
	testing.expect(t, capsule_err == .None && joint_err == .None && !thor2d.Physics_Joint_Invalid(joint))
	_ = hit
	thor2d.Destroy_All_Physics(&ctx)
}

@(test)
test_physics_chain_overlap_and_raycast :: proc(t: ^testing.T) {
	ctx := thor2d.Context{config = thor2d.Default_Config()}
	world, world_err := thor2d.Create_Physics_World(&ctx)
	static_def := thor2d.Default_Physics_Body_Def()
	static_def.Type = .Static
	body, body_err := thor2d.Create_Physics_Body(&ctx, world, static_def)
	points := []thor2d.Vec2{{-32, -8}, {32, -8}, {32, 8}, {-32, 8}}
	chain, chain_err := thor2d.Create_Chain_Shape(&ctx, body, points, true)
	box, box_err := thor2d.Create_Box_Shape(&ctx, body, 16, 16)
	tag_err := thor2d.Physics_Shape_Set_User_Tag(&ctx, box, 77)
	results := thor2d.Physics_Overlap_AABB(&ctx, world, thor2d.Rect{-40, -8, 80, 16})
	hits := thor2d.Physics_Raycast_All(&ctx, world, thor2d.Vec2{-40, 0}, thor2d.Vec2{80, 0})
	casts := thor2d.Physics_Shape_Cast_Circle(&ctx, world, thor2d.Vec2{-40, 0}, 2, thor2d.Vec2{80, 0})
	chain_found := false
	for result in results {
		if result.Shape == chain {
			chain_found = true
		}
	}
	testing.expect(t, world_err == .None && body_err == .None && chain_err == .None && box_err == .None)
	testing.expect(t, !thor2d.Physics_Shape_Invalid(chain) && !thor2d.Physics_Shape_Invalid(box) && thor2d.Physics_Chain_Segment_Count(&ctx, chain) == 4 && chain_found && len(hits) > 0 && len(casts) > 0 && tag_err == .None && thor2d.Physics_Shape_User_Tag(&ctx, box) == 77)
	delete(results)
	delete(hits)
	delete(casts)
	thor2d.Destroy_All_Physics(&ctx)
}

@(test)
test_action_map_and_query_filter_defaults :: proc(t: ^testing.T) {
	actions := thor2d.New_Action_Map(0.25)
	defer thor2d.Destroy_Action_Map(&actions)
	testing.expect(t, thor2d.Bind_Action_Key(&actions, "jump", .Space) == .None)
	testing.expect(t, thor2d.Bind_Action_Gamepad_Axis(&actions, "move", 0, -1) == .None)
	testing.expect(t, actions.Dead_Zone == 0.25 && len(actions.Bindings["jump"]) == 1 && len(actions.Bindings["move"]) == 1)
}

managed_test_worker :: proc(control: ^thor2d.Thread_Control) -> thor2d.Error {
	if thor2d.Thread_Cancelled(control) {
		return .None
	}
	return .None
}

@(test)
test_managed_thread_lifecycle :: proc(t: ^testing.T) {
	worker, err := thor2d.Start_Managed_Thread(managed_test_worker, "thor2d-test-worker")
	testing.expect(t, err == .None)
	if err == .None {
		thor2d.Join_Thread(&worker)
		testing.expect(t, thor2d.Thread_State_Of(&worker) == .Joined)
	}
}
