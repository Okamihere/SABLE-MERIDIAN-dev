extends SceneTree

const WORLD := "res://scenes/levels/worlds/world_01.tscn"
const GRAYBOX := preload("res://resources/gridmap/sable_graybox_mesh_library.tres")
const ARCHITECTURE := preload("res://resources/gridmap/sable_architecture_kit.tres")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(change_scene_to_file(WORLD) == OK)
	for frame in 10: await physics_frame
	var world := current_scene as Node3D
	var player := world.get_node("Player") as CharacterBody3D
	var path := world.get_node("DestinationPath") as GridMap
	assert(path.mesh_library == GRAYBOX and path.get_used_cells().size() == 24)
	assert(path.cell_size == Vector3(2, 1, 2) and not path.cell_center_y)
	assert(path.get_cell_item(Vector3i(3, 2, -18)) == 0)
	assert(path.get_cell_item(Vector3i(3, 1, -20)) == 11)
	assert(path.get_cell_item_orientation(Vector3i(3, 1, -20)) == 10)
	assert(path.get_cell_item(Vector3i(3, 0, -23)) == 0)
	assert(path.get_cell_item(Vector3i(5, 4, -28)) == 11)
	for name in ["ArchitectureUpperRoute", "ArchitectureLowerRoute", "ArchitectureRightMass", "ArchitectureStairGuard"]:
		var grid := world.get_node(name) as GridMap
		assert(grid.mesh_library == ARCHITECTURE)
		assert(grid.collision_layer == 1)
	assert(is_equal_approx((world.get_node("ArchitectureRightMass") as GridMap).position.y, 4.7))
	assert(floor_hit(world, Vector3(0, 0, -42)).is_empty(), "O vão central do mirante foi fechado")
	for sample in [
		Vector3(7, 2, -35), Vector3(7, 2, -37),
		Vector3(7, 1.5, -39), Vector3(7, 1, -41),
		Vector3(7, 0.5, -43), Vector3(7, 0, -45),
		Vector3(8, 0, -47), Vector3(11, 0, -45),
		Vector3(11, 0.5, -47), Vector3(11, 1.5, -49),
		Vector3(11, 2.5, -51), Vector3(11, 3.5, -53),
		Vector3(11, 4.5, -55), Vector3(9, 5, -57),
		Vector3(8, 4.7, -55), Vector3(11, 2, -39),
		Vector3(0, 0, -51)
	]:
		var hit := floor_hit(world, sample)
		assert(not hit.is_empty(), "Piso ausente em %s" % sample)
		assert(absf(hit.position.y - sample.y) < 0.4, "Altura de piso incorreta em %s: %s" % [sample, hit.position.y])

	# Personagem real: saída lateral do mirante, descida, escadaria e topo da massa.
	player.global_position = Vector3(4, 2.2, -35)
	player.velocity = Vector3.ZERO
	await walk(&"move_right", 28)
	assert(player.is_on_floor() and player.global_position.x > 6.0)
	await walk(&"move_forward", 75)
	assert(player.is_on_floor() and player.global_position.z < -44.0 and absf(player.global_position.y) < 0.3)
	await walk(&"move_right", 35)
	assert(player.is_on_floor() and player.global_position.x > 10.0)
	await walk(&"move_forward", 90)
	assert(player.is_on_floor() and player.global_position.y > 4.5)
	await walk(&"move_left", 14)
	await walk(&"move_back", 15)
	await walk(&"move_left", 12)
	await walk(&"move_back", 12)
	for frame in 20: await physics_frame
	assert(player.is_on_floor() and player.global_position.x < 10.0 and player.global_position.y > 4.5, "Topo da estrutura não é acessível")

	# Desvio elevado e pequena área de ruínas no terreno existente.
	player.global_position = Vector3(11, 2.2, -37)
	player.velocity = Vector3.ZERO
	await walk(&"move_forward", 14)
	assert(player.is_on_floor() and player.global_position.z < -37.5, "Alcova elevada não é acessível")
	player.global_position = Vector3(6, 0.2, -51)
	player.velocity = Vector3.ZERO
	await walk(&"move_left", 40)
	assert(player.is_on_floor() and player.global_position.x < 2.0, "Desvio nas ruínas inferiores não é acessível")
	print("WORLD01 DESTINATION PASS: mirante, descida, terreno, topo e desvios opcionais")
	quit(0)

func floor_hit(world: Node3D, sample: Vector3) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(sample + Vector3.UP * 5.0, sample + Vector3.DOWN * 0.8, 1)
	)

func walk(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in frames: await physics_frame
	Input.action_release(action)
