extends SceneTree

const LIBRARY := preload("res://resources/gridmap/sable_graybox_mesh_library.tres")

func _initialize() -> void:
	run.call_deferred()
	timeout.call_deferred()

func timeout() -> void:
	await create_timer(35.0).timeout
	push_error("GridMap regression timeout")
	quit(1)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func world_ray(from: Vector3, to: Vector3) -> Dictionary:
	return root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))

func run() -> void:
	var expected_ids := PackedInt32Array()
	for id in range(33):
		expected_ids.append(id)
	assert(LIBRARY.get_item_list() == expected_ids)
	for id in range(32):
		assert(LIBRARY.get_item_mesh(id) != null)
		assert(LIBRARY.get_item_shapes(id).size() >= 2)
	assert(LIBRARY.get_item_name(32) == "32_Agua_Estilizada")
	assert(LIBRARY.get_item_mesh(32) != null)
	assert(LIBRARY.get_item_shapes(32).is_empty())
	for id in range(12, 32):
		assert(LIBRARY.get_item_name(id).begins_with("%02d_" % id))
	var floor_bounds := LIBRARY.get_item_mesh(0).get_aabb()
	assert(is_zero_approx(floor_bounds.position.y) and is_zero_approx(floor_bounds.size.y), "Floor visual should be flat")
	var floor_shapes := LIBRARY.get_item_shapes(0)
	var floor_collision := floor_shapes[0] as BoxShape3D
	var floor_collision_transform := floor_shapes[1] as Transform3D
	var floor_underside := floor_collision_transform.origin.y - floor_collision.size.y * 0.5
	for id in [1, 2, 5]:
		var bounds := LIBRARY.get_item_mesh(id).get_aabb()
		assert(is_equal_approx(bounds.position.y, -0.2))
		assert(is_equal_approx(bounds.end.y, 0.8))
		assert(is_equal_approx(bounds.end.y, floor_underside + 1.0), "Wall must meet the underside of the next floor")

	change_scene_to_file("res://scenes/levels/gridmap_graybox_demo.tscn")
	await frames(10)
	var floors := current_scene.get_node("FloorsAndRamps") as GridMap
	var walls := current_scene.get_node("Walls") as GridMap
	var player := current_scene.get_node("Player") as CharacterBody3D
	var camera := current_scene.get_node("CameraRig/SpringArm3D/Camera3D") as Camera3D
	assert(floors.mesh_library == walls.mesh_library)
	for grid in [floors, walls]:
		assert(grid.cell_size == Vector3(2, 1, 2) and not grid.cell_center_y)
		assert(grid.collision_layer == 1 and grid.collision_mask == 1)
	assert(floors.map_to_local(Vector3i.ZERO) == Vector3(1, 0, 1))
	assert(camera.current and camera.get_parent().collision_mask == 1)
	assert(player.collision_layer == 2 and player.collision_mask == 5)
	assert(absf(world_ray(Vector3(1, 3, 1), Vector3(1, -1, 1)).position.y - 0.5) < 0.04)
	assert(absf(world_ray(Vector3(1, 3, -1), Vector3(1, -1, -1)).position.y - 1.0) < 0.04)
	assert(walls.get_cell_item(Vector3i(5, 0, 2)) == 6)
	assert(walls.get_cell_item(Vector3i(7, 0, 2)) == 7)
	assert(walls.get_cell_item(Vector3i(4, 0, 1)) == 8)
	assert(walls.get_cell_item(Vector3i(8, 0, 0)) == 9)
	assert(floors.get_cell_item(Vector3i(8, 0, 0)) == 10)
	assert(floors.get_cell_item(Vector3i(6, 0, 2)) == 11)
	assert(floors.get_cell_item(Vector3i(9, 3, 4)) == 10)
	for id in range(12, 16):
		assert(walls.get_cell_item(Vector3i(id - 1, 0, 2)) == id)
	assert(walls.get_cell_item(Vector3i(10, 0, 5)) == 16)
	assert(walls.get_cell_item(Vector3i(16, 0, 5)) == 17)
	assert(floors.get_cell_item(Vector3i(10, 3, 5)) == 20)
	assert(floors.get_cell_item(Vector3i(12, 0, -2)) == 21)
	assert(floors.get_cell_item(Vector3i(15, 0, -2)) == 22)
	assert(walls.get_cell_item(Vector3i(13, 2, -2)) == 23)
	assert(floors.get_cell_item(Vector3i(13, 0, 0)) == 24)
	assert(floors.get_cell_item(Vector3i(13, 0, -2)) == 25)
	assert(walls.get_cell_item(Vector3i(24, 0, 1)) == 26)
	assert(walls.get_cell_item(Vector3i(15, 1, -2)) == 27)
	assert(walls.get_cell_item(Vector3i(15, 0, -3)) == 28)
	assert(walls.get_cell_item(Vector3i(23, 0, 2)) == 29)
	assert(walls.get_cell_item(Vector3i(22, 0, 1)) == 30)
	assert(walls.get_cell_item(Vector3i(26, 0, 1)) == 31)
	for id in [6, 7]:
		assert(LIBRARY.get_item_shapes(id).size() == 6)
		assert(is_equal_approx(LIBRARY.get_item_mesh(id).get_aabb().end.y, 2.8))
		assert(is_equal_approx(LIBRARY.get_item_mesh(id).get_aabb().end.y, floor_underside + 3.0))
	assert(LIBRARY.get_item_shapes(8).size() == 2)
	assert(LIBRARY.get_item_shapes(9).size() == 2)
	assert(LIBRARY.get_item_shapes(10).size() == 2)
	assert(LIBRARY.get_item_shapes(11).size() == 2)
	for y in range(3):
		assert(walls.get_cell_item(Vector3i(9, y, 4)) == 8)
	var replacement := LIBRARY.duplicate() as MeshLibrary
	replacement.set_item_mesh(11, BoxMesh.new())
	floors.mesh_library = replacement
	walls.mesh_library = replacement
	assert(floors.get_cell_item(Vector3i(6, 0, 2)) == 11)
	assert(walls.get_cell_item(Vector3i(5, 0, 2)) == 6)
	floors.mesh_library = LIBRARY
	walls.mesh_library = LIBRARY

	var fixture := GridMap.new()
	fixture.mesh_library = LIBRARY
	fixture.cell_size = Vector3(2, 1, 2)
	fixture.cell_center_y = false
	fixture.collision_layer = 1
	current_scene.add_child(fixture)
	var cell := Vector3i(20, 0, 20)
	var center := fixture.map_to_local(cell)
	for degrees in [0, 90, 180, 270]:
		var basis := Basis(Vector3.UP, deg_to_rad(float(degrees)))
		var orientation := fixture.get_orthogonal_index_from_basis(basis)
		fixture.set_cell_item(cell, 1, orientation)
		await frames(2)
		var interior := center + Vector3.UP * 0.4
		var wall_hit := world_ray(interior, interior + basis * Vector3(0, 0, -1.5))
		assert(not wall_hit.is_empty())
		assert(wall_hit.normal.dot(basis * Vector3.BACK) > 0.9)
		fixture.set_cell_item(cell, 2, orientation)
		await frames(2)
		assert(not world_ray(interior, interior + basis * Vector3(-1.5, 0, 0)).is_empty())
		assert(not world_ray(interior, interior + basis * Vector3(0, 0, -1.5)).is_empty())
		fixture.set_cell_item(cell, 4, orientation)
		await frames(2)
		var low := center + basis * Vector3(0, 0, 0.5)
		var high := center + basis * Vector3(0, 0, -0.5)
		assert(absf(world_ray(low + Vector3.UP * 2, low - Vector3.UP).position.y - 0.25) < 0.04)
		assert(absf(world_ray(high + Vector3.UP * 2, high - Vector3.UP).position.y - 0.75) < 0.04)
		for portal_id in [6, 7]:
			fixture.set_cell_item(cell, portal_id, orientation)
			await frames(2)
			var entry := center + basis * Vector3(0, 1, 1.5)
			var exit := center + basis * Vector3(0, 1, -1.5)
			assert(world_ray(entry, exit).is_empty(), "Portal center must remain open")
			var post_entry := center + basis * Vector3(-0.85, 1, 1.5)
			var post_exit := center + basis * Vector3(-0.85, 1, -1.5)
			assert(not world_ray(post_entry, post_exit).is_empty(), "Portal post must be solid")
			assert(not world_ray(entry + Vector3.UP * 1.4, exit + Vector3.UP * 1.4).is_empty(), "Portal lintel must be solid")
		fixture.set_cell_item(cell, 8, orientation)
		await frames(2)
		assert(not world_ray(center + basis * Vector3(-1, 0.3, 0), center + basis * Vector3(1, 0.3, 0)).is_empty())
		fixture.set_cell_item(cell, 9, orientation)
		await frames(2)
		assert(not world_ray(interior, interior + basis * Vector3(0, 0, -1.5)).is_empty())
		assert(world_ray(interior + Vector3.UP, interior + Vector3.UP + basis * Vector3(0, 0, -1.5)).is_empty())
		fixture.set_cell_item(cell, 10, orientation)
		await frames(2)
		assert(absf(world_ray(center + Vector3.UP * 2, center - Vector3.UP).position.y) < 0.03)
		assert(world_ray(center + basis * Vector3(-1, -0.4, 0.5), center + basis * Vector3(1, -0.4, 0.5)).is_empty(), "Balcony brackets are visual")
		fixture.set_cell_item(cell, 11, orientation)
		await frames(2)
		assert(absf(world_ray(low + Vector3.UP * 2, low - Vector3.UP).position.y - 0.25) < 0.04)
		assert(absf(world_ray(high + Vector3.UP * 2, high - Vector3.UP).position.y - 0.75) < 0.04)
		for portal_id in [12, 13, 15, 23, 27]:
			fixture.set_cell_item(cell, portal_id, orientation)
			await frames(2)
			var entry_new := center + basis * Vector3(0, 1, 1.5)
			var exit_new := center + basis * Vector3(0, 1, -1.5)
			assert(world_ray(entry_new, exit_new).is_empty(), "New portal opening must be clear")
			var post_new := center + basis * Vector3(-0.9, 1, 1.5)
			assert(not world_ray(post_new, post_new + basis * Vector3(0, 0, -3)).is_empty())
		fixture.set_cell_item(cell, 14, orientation)
		await frames(2)
		var window_ray := center + basis * Vector3(0, 0.4, 1.5)
		assert(not world_ray(window_ray, window_ray + basis * Vector3(0, 0, -3)).is_empty())
		for column_id in [16, 17]:
			fixture.set_cell_item(cell, column_id, orientation)
			await frames(2)
			assert(not world_ray(center + basis * Vector3(-1, 0.4, 0), center + basis * Vector3(1, 0.4, 0)).is_empty())
		fixture.set_cell_item(cell, 18, orientation)
		await frames(2)
		assert(absf(world_ray(center + Vector3.UP, center - Vector3.UP).position.y) < 0.03)
		assert(world_ray(center + basis * Vector3(0.75, 1, 0), center + basis * Vector3(0.75, -1, 0)).is_empty())
		for id in [19, 20, 21, 22, 25]:
			fixture.set_cell_item(cell, id, orientation)
			await frames(2)
			var expected_height := 0.0 if id in [19, 20] else (2.0 if id == 25 else 0.8)
			assert(absf(world_ray(center + Vector3.UP * 4, center - Vector3.UP).position.y - expected_height) < 0.04)
		for id in [26, 28, 30, 31]:
			fixture.set_cell_item(cell, id, orientation)
			await frames(2)
			var front := center + basis * Vector3(0, 0.4, 0.5)
			assert(not world_ray(front, front + basis * Vector3(0, 0, -1.5)).is_empty())
		fixture.set_cell_item(cell, 29, orientation)
		await frames(2)
		var alcove_center := center + basis * Vector3(0, 0.4, 0)
		assert(not world_ray(alcove_center, alcove_center + basis * Vector3(0, 0, -1.5)).is_empty())
		assert(world_ray(alcove_center, alcove_center + basis * Vector3(0, 0, 1.5)).is_empty())
		fixture.set_cell_item(cell, 24, orientation)
		await frames(2)
		var stair_low := center + basis * Vector3(1, 0, 0.5)
		var stair_high := center + basis * Vector3(1, 0, -2.5)
		assert(absf(world_ray(stair_low + Vector3.UP * 4, stair_low - Vector3.UP).position.y - 0.25) < 0.05)
		assert(absf(world_ray(stair_high + Vector3.UP * 4, stair_high - Vector3.UP).position.y - 1.75) < 0.05)
	fixture.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)

	for x in range(2, 4):
		for z in range(0, 4):
			floors.set_cell_item(Vector3i(x, 4, z), 0)
	await frames(2)
	assert(absf(world_ray(Vector3(5, 7, 3), Vector3(5, 3, 3)).position.y - 4.0) < 0.03)
	assert(absf(world_ray(Vector3(5, 2, 3), Vector3(5, -1, 3)).position.y) < 0.03)
	player.set_physics_process(false)
	player.global_position = Vector3(5, 4.5, 3)
	for i in range(50):
		player.velocity = Vector3(0, -5, 0)
		player.move_and_slide()
		await physics_frame
	assert(player.is_on_floor() and absf(player.global_position.y - 3.925) < 0.05)
	player.global_position = Vector3(7.2, 2.2, 3)
	player.velocity = Vector3.ZERO
	player.move_and_slide()
	await frames(2)
	assert(player.wall_movement.find_wall(player, Vector3.RIGHT).x < -0.9)
	player.velocity.y = -2.0
	player.wall_movement.update_motion(player, Vector3.RIGHT, 0.016, true)
	assert(player.wall_movement.gripping)
	Input.action_press("jump")
	player.wall_movement.update_motion(player, Vector3.RIGHT, 0.016, true)
	Input.action_release("jump")
	assert(player.wall_movement.used_jumps == 1 and player.velocity.y > 0 and player.velocity.x < 0)
	player.global_position = Vector3(1, 0.1, 2.8)
	player.velocity = Vector3.ZERO
	await frames(2)
	for i in range(180):
		player.velocity = Vector3(0, -3, -2.5)
		player.move_and_slide()
		await physics_frame
	assert(player.global_position.y > 0.9 and player.is_on_floor(), "Player must reach the upper platform via the ramp")
	for portal_x in [11.0, 15.0]:
		player.global_position = Vector3(portal_x, 0.1, 6)
		player.velocity = Vector3.ZERO
		await frames(2)
		for i in range(100):
			player.velocity = Vector3(0, -3, -2.5)
			player.move_and_slide()
			await physics_frame
		assert(player.global_position.z < 4.0 and player.is_on_floor(), "Player must pass through the portal")
	player.global_position = Vector3(13, 0.1, 6.8)
	player.velocity = Vector3.ZERO
	await frames(2)
	for i in range(180):
		player.velocity = Vector3(0, -3, -2.5)
		player.move_and_slide()
		await physics_frame
	assert(player.global_position.y > 0.9 and player.is_on_floor(), "Player must climb the visual stairs")
	player.global_position = Vector3(27, 0.1, 2.8)
	player.velocity = Vector3.ZERO
	await frames(2)
	for i in range(340):
		player.velocity = Vector3(0, -3, -2.5)
		player.move_and_slide()
		await physics_frame
	assert(player.global_position.y > 1.8 and player.is_on_floor(), "Player must climb the monumental stairs onto the elevated platform")
	print("PASS: 33 IDs, pivots, four rotations, portals, collisions, two floors, ramp, stairs, balcony, camera, wall jump")
	quit()
