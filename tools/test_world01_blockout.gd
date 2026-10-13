extends SceneTree

const WORLD := "res://scenes/levels/worlds/world_01.tscn"
const HUB := "res://scenes/levels/vertical_pilot.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(change_scene_to_file(WORLD) == OK)
	for frame in 10:
		await physics_frame
	assert(current_scene != null)
	var world := current_scene
	var floors := world.get_node("FloorsAndRamps") as GridMap
	var walls := world.get_node("Walls") as GridMap
	var architecture := world.get_node("ArchitectureInitial") as GridMap
	var player := world.get_node("Player") as CharacterBody3D
	var arrivals := world.get_node("ArrivalPoints")
	assert(player.global_position.distance_to(arrivals.get_node("FromHub").global_position) < 0.2)
	assert(floors.get_used_cells().size() >= 180)
	assert(floors.get_cell_item(Vector3i(0, 0, -10)) == 11)
	assert(floors.get_cell_item(Vector3i(0, 1, -12)) == 11)
	assert(floors.get_cell_item(Vector3i(-6, 1, -12)) == 11)
	assert(floors.get_cell_item(Vector3i(-6, 0, -10)) == 11)
	assert(walls.get_cell_item(Vector3i(-4, 0, -7)) == 1)
	assert(architecture.mesh_library == load("res://resources/gridmap/sable_architecture_kit.tres"))
	assert(architecture.cell_size == walls.cell_size and not architecture.cell_center_y)
	assert(architecture.get_used_cells().size() == 12)
	assert(walls.get_cell_item(Vector3i(-4, 0, -5)) == GridMap.INVALID_CELL_ITEM)
	assert(walls.get_cell_item(Vector3i(-4, 0, -6)) == GridMap.INVALID_CELL_ITEM)
	assert(architecture.get_cell_item(Vector3i(-4, 0, -5)) == 0)
	assert(architecture.get_cell_item(Vector3i(-4, 0, -6)) == 1)
	assert(architecture.get_cell_item_orientation(Vector3i(-4, 0, -5)) == 16)
	for cell in architecture.get_used_cells():
		assert(cell.y == 0 and cell.z >= -9 and cell.z <= -4, "Arquitetura fora da região inicial: %s" % cell)
		assert(cell.x != 0, "Eixo central obstruído por arquitetura: %s" % cell)

	# Raios testam superfícies reais: início, subida, bifurcação, mirante e atalho.
	for sample in [
		Vector3(0, 0, 0), Vector3(0, 0, -7), Vector3(0, 0, -17),
		Vector3(0, 0.5, -19), Vector3(0, 1, -21), Vector3(0, 1.5, -23),
		Vector3(0, 2, -27), Vector3(0, 2, -35),
		Vector3(13, 0, -15), Vector3(22, 0, -19),
		Vector3(-11, 2, -29), Vector3(-11, 1.5, -23), Vector3(-11, 1, -21),
		Vector3(-11, 0.5, -19), Vector3(-11, 0, -15),
		Vector3(-11, 0, -3), Vector3(-5, 0, -3)
	]:
		var hit := floor_hit(world, sample)
		assert(not hit.is_empty(), "Falta colisão em %s" % sample)
		assert(absf(hit.position.y - sample.y) < 0.18, "Altura de piso incorreta em %s: %s" % [sample, hit.position.y])
	assert(floor_hit(world, Vector3(0, 0, -42)).is_empty(), "A quebra diante do mirante deve ficar livre")
	assert(not floor_hit(world, Vector3(0, 0, -53)).is_empty(), "A massa distante de CSG perdeu colisão")
	for point_name in ["FutureNorth", "FutureEast"]:
		var point := arrivals.get_node(point_name) as Marker3D
		assert(not floor_hit(world, point.global_position).is_empty(), "Chegada futura fora do piso: %s" % point_name)

	# O personagem real percorre a rota principal sem salto nem dash.
	await walk(&"move_forward", 240)
	assert(player.global_position.z < -33.0 and player.global_position.y > 1.5 and player.is_on_floor(), "Subida principal não é atravessável")
	player.global_position = Vector3(0, 0.2, -15)
	player.velocity = Vector3.ZERO
	await walk(&"move_right", 140)
	assert(player.global_position.x > 18.0 and player.is_on_floor(), "Bifurcação opcional não é atravessável")
	player.global_position = Vector3(0, 2.2, -29)
	player.velocity = Vector3.ZERO
	await walk(&"move_left", 75)
	assert(player.global_position.x < -9.0 and player.is_on_floor(), "Entrada do atalho não é atravessável")
	await walk(&"move_back", 180)
	assert(player.global_position.z > -4.0 and player.is_on_floor(), "Descida do atalho não é atravessável")
	await walk(&"move_right", 68)
	assert(player.global_position.x > -5.0 and player.is_on_floor(), "Atalho não reencontra a entrada")

	var portal := world.get_node("ReturnToHub")
	assert(portal.destination_scene == HUB and portal.return_world_id == &"world_01")
	portal._on_entered(player)
	player.global_position = portal.global_position + Vector3(0, 0.1, 0.5)
	portal._physics_process(0.016)
	await root.get_node("AreaTransition").transition_finished
	assert(current_scene.scene_file_path == HUB, "Portal não retornou ao hub")
	print("WORLD01 BLOCKOUT PASS: spawn, superfícies, verticalidade, bifurcação, atalho, chegadas e hub")
	quit(0)

func floor_hit(world: Node3D, sample: Vector3) -> Dictionary:
	var origin := sample + Vector3.UP * 5.0
	var target := sample + Vector3.DOWN * 0.8
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func walk(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in frames:
		await physics_frame
	Input.action_release(action)
