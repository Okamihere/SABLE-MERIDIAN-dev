extends SceneTree

const BUILDER := preload("res://scripts/editor/sable_architecture_kit_builder.gd")
const GRAYBOX := preload("res://resources/gridmap/sable_graybox_mesh_library.tres")
const STONE := preload("res://materials/stone.tres")
const LIGHT_STONE := preload("res://materials/stone_light.tres")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var first: MeshLibrary = BUILDER.build_library(1731)
	var repeat: MeshLibrary = BUILDER.build_library(1731)
	var changed: MeshLibrary = BUILDER.build_library(1732)
	assert(first.get_item_list() == PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]))
	var variation_found := false
	for id in 10:
		var mesh := first.get_item_mesh(id)
		assert(mesh != null and mesh.get_surface_count() == 2, "Peça sem dois materiais compartilhados: %d" % id)
		assert(mesh.surface_get_material(0) == STONE and mesh.surface_get_material(1) == LIGHT_STONE)
		var bounds := mesh.get_aabb()
		assert(bounds.position.x >= -1.01 and bounds.end.x <= 1.01)
		assert(bounds.position.z >= -1.01 and bounds.end.z <= 1.01)
		assert(bounds.position.y >= -0.21 and bounds.end.y <= 2.81)
		var triangles := 0
		for surface in mesh.get_surface_count():
			triangles += mesh.surface_get_array_len(surface) / 3
		assert(triangles <= 180, "Geometria pesada demais: %d" % id)
		assert(first.get_item_shapes(id).size() >= 2, "Peça sem colisão: %d" % id)
		assert(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == repeat.get_item_mesh(id).surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "Seed não reproduz peça %d" % id)
		if mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] != changed.get_item_mesh(id).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			variation_found = true
	assert(variation_found, "Mudança de seed não altera geometria")
	for id in [0, 1]: assert(first.get_item_shapes(id) == GRAYBOX.get_item_shapes(1))
	for id in [2, 3]: assert(first.get_item_shapes(id) == GRAYBOX.get_item_shapes(6))
	for id in [6, 7]: assert(first.get_item_shapes(id) == GRAYBOX.get_item_shapes(11))

	var saved := load(BUILDER.OUTPUT_LIBRARY) as MeshLibrary
	assert(saved != null and saved.get_meta(&"sable_architecture_seed") == 1731)
	assert(change_scene_to_file(BUILDER.OUTPUT_PREVIEW) == OK)
	for frame in 8: await physics_frame
	var kit := current_scene.get_node("ArchitectureKit") as GridMap
	var floor := current_scene.get_node("GrayboxFloor") as GridMap
	assert(kit.mesh_library == saved and kit.get_used_cells().size() == 10)
	assert(floor.mesh_library == GRAYBOX and kit.cell_size == Vector3(2, 1, 2) and not kit.cell_center_y)
	for id in 10:
		assert(kit.get_cell_item(Vector3i((id % 5) * 3, 0, int(id / 5) * 4)) == id)
	var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	assert(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(1, 0.4, -1), Vector3(1, 0.4, 2), 1)).is_empty(), "Parede sem colisão")
	assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(13, 1.0, -1), Vector3(13, 1.0, 2), 1)).is_empty(), "Vão do arco bloqueado")
	var stair_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(7, 3, 9), Vector3(7, -1, 9), 1))
	assert(not stair_hit.is_empty() and stair_hit.position.y > 0.3, "Escada sem rampa de colisão")

	var world_01 := (load("res://scenes/levels/worlds/world_01.tscn") as PackedScene).instantiate()
	assert(world_01.get_node("FloorsAndRamps").mesh_library == GRAYBOX)
	assert(world_01.get_node("FloorsAndRamps").get_used_cells().size() >= 190)
	assert(world_01.get_node("Walls").mesh_library == GRAYBOX)
	world_01.free()
	print("ARCHITECTURE KIT PASS: seed, 10 encaixes, materiais, colisões, prévia e Mundo 01 preservado")
	quit(0)
