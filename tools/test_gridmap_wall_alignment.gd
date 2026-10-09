extends SceneTree

const LIBRARY := preload("res://resources/gridmap/sable_graybox_mesh_library.tres")
const CELL_SIZE := Vector3(2, 1, 2)
const EPSILON := 0.001

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var grid := GridMap.new()
	grid.mesh_library = LIBRARY
	grid.cell_size = CELL_SIZE
	grid.cell_center_y = false
	root.add_child(grid)
	var wall_bounds := LIBRARY.get_item_mesh(1).get_aabb()
	assert(wall_bounds.position.is_equal_approx(Vector3(-1, -0.2, -1)))
	assert(wall_bounds.size.is_equal_approx(Vector3(2, 1, 0.25)))
	assert(LIBRARY.get_item_mesh_transform(1).is_equal_approx(Transform3D.IDENTITY))
	var wall_shapes := LIBRARY.get_item_shapes(1)
	assert((wall_shapes[0] as BoxShape3D).size.is_equal_approx(Vector3(2, 1, 0.25)))
	assert((wall_shapes[1] as Transform3D).origin.is_equal_approx(Vector3(0, 0.3, -0.875)))
	var corner_shapes := LIBRARY.get_item_shapes(2)
	assert((corner_shapes[0] as BoxShape3D).size.is_equal_approx(Vector3(2, 1, 0.25)))
	assert((corner_shapes[1] as Transform3D).origin.is_equal_approx(Vector3(0, 0.3, -0.875)))
	assert((corner_shapes[2] as BoxShape3D).size.is_equal_approx(Vector3(0.25, 1, 1.75)))
	assert((corner_shapes[3] as Transform3D).origin.is_equal_approx(Vector3(-0.875, 0.3, 0.125)))
	for degrees in [0, 90, 180, 270]:
		var basis := Basis(Vector3.UP, deg_to_rad(float(degrees)))
		var turn := Basis(Vector3.UP, PI / 2.0)
		var orientation := grid.get_orthogonal_index_from_basis(basis)
		var next_orientation := grid.get_orthogonal_index_from_basis(basis * turn)
		var lane := int(degrees / 90) * 8
		var corner_cell := Vector3i(lane + 3, 0, lane + 3)
		var x_step := _cell_direction(basis * Vector3.RIGHT)
		var z_step := _cell_direction(basis * Vector3.BACK)
		for index in range(3):
			grid.set_cell_item(corner_cell - x_step * (3 - index), 1, orientation)
		grid.set_cell_item(corner_cell, 2, orientation)
		for index in range(1, 4):
			grid.set_cell_item(corner_cell + z_step * index, 1, next_orientation)
		var first_center := grid.map_to_local(corner_cell - x_step * 3)
		for index in range(2):
			var current := first_center + basis * Vector3(float(index) * 2.0, 0, 0)
			var following := current + basis * Vector3(2, 0, 0)
			_assert_point(current + basis * Vector3(1, 0, -0.875), following + basis * Vector3(-1, 0, -0.875))
		var corner_center := grid.map_to_local(corner_cell)
		var last_center := grid.map_to_local(corner_cell - x_step)
		_assert_point(last_center + basis * Vector3(1, 0, -0.875), corner_center + basis * Vector3(-1, 0, -0.875))
		var turned := basis * turn
		var next_center := grid.map_to_local(corner_cell + z_step)
		_assert_point(corner_center + basis * Vector3(-0.875, 0, 1), next_center + turned * Vector3(1, 0, -0.875))
		for index in range(1, 3):
			var current := grid.map_to_local(corner_cell + z_step * index)
			var following := grid.map_to_local(corner_cell + z_step * (index + 1))
			_assert_point(current + turned * Vector3(-1, 0, -0.875), following + turned * Vector3(1, 0, -0.875))
		for cell in grid.get_used_cells():
			var saved_orientation := grid.get_cell_item_orientation(cell)
			assert(saved_orientation == orientation or saved_orientation == next_orientation)
			assert(grid.get_cell_item_basis(cell).is_equal_approx(grid.get_basis_with_orthogonal_index(saved_orientation)))
		grid.clear()
	grid.queue_free()
	print("PASS: walls in four rotations, straight runs, corners, direction changes and saved orientations")
	quit()

func _cell_direction(direction: Vector3) -> Vector3i:
	return Vector3i(roundi(direction.x), 0, roundi(direction.z))

func _assert_point(a: Vector3, b: Vector3) -> void:
	assert(a.distance_to(b) < EPSILON, "Wall seam mismatch: %s vs %s" % [a, b])
