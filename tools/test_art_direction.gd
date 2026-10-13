extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var art := root.get_node("ArtDirection")
	var palette := load("res://resources/palettes/sable_default.tres") as SableArtPalette
	var library := load("res://resources/gridmap/sable_graybox_mesh_library.tres") as MeshLibrary
	assert(library.get_item_list().size() == 33, "Peças do editor de mapas foram alteradas")
	var floor_material := library.get_item_mesh(0).surface_get_material(0) as StandardMaterial3D
	var old_mid := palette.stone_mid
	palette.stone_mid = Color(0.34, 0.24, 0.3)
	await process_frame
	assert(floor_material.albedo_color.is_equal_approx(palette.stone_mid), "GridMap não acompanha a paleta")
	palette.stone_mid = old_mid
	await process_frame
	var region := SableRegionPalette.new()
	var region_edits := [0]
	region.changed.connect(func() -> void: region_edits[0] += 1)
	region.accent_tint = Color(0.9, 0.8, 1.0)
	assert(region_edits[0] == 1, "Perfil regional não avisa o editor quando é editado")

	assert(change_scene_to_file("res://scenes/levels/worlds/world_02.tscn") == OK)
	for frame in 6:
		await physics_frame
		await process_frame
	assert(art.get_color(&"violet") != palette.violet, "Variação regional não aplicada")
	var player := current_scene.get_node("Player")
	assert(player.get_node("DirectionalSprite").sprite_frames != null, "Sprite perdeu sua fonte original")
	var terrain := current_scene.get_node("world_2/Plane") as MeshInstance3D
	var source := terrain.mesh.surface_get_material(0) as StandardMaterial3D
	var tinted := terrain.get_surface_override_material(0) as StandardMaterial3D
	assert(tinted != null and tinted != source, "Material importado não recebeu ajuste reversível")
	assert(tinted.albedo_texture == source.albedo_texture, "Textura importada foi perdida")

	assert(change_scene_to_file("res://scenes/levels/worlds/world_01.tscn") == OK)
	for frame in 6:
		await physics_frame
		await process_frame
	assert(art.get_color(&"violet").is_equal_approx(palette.violet), "Variação vazou para outro mundo")
	print("ART DIRECTION PASS: paleta, GridMap, sprite e variação regional")
	quit(0)
