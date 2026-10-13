extends Node

## Paleta em uso no jogo. Materiais compartilhados mantêm os mesmos Resources do editor.
const PALETTE: SableArtPalette = preload("res://resources/palettes/sable_default.tres")
const GRID_LIBRARY := "res://resources/gridmap/sable_graybox_mesh_library.tres"
const GRID_REFERENCE := Color(0.2784314, 0.2627451, 0.30980393)
const AMBIENT_REFERENCE := Color(0.7, 0.64, 0.75)
const WHITE_REGION: SableRegionPalette = preload("res://resources/palettes/sable_neutral.tres")

var _region: SableRegionPalette = WHITE_REGION

func _ready() -> void:
	PALETTE.changed.connect(_refresh_palette)
	get_tree().scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_node_added)
	apply_shared_assets(PALETTE)
	call_deferred("_refresh_palette")

func get_color(role: StringName) -> Color:
	var result := PALETTE.color(role)
	match role:
		&"violet", &"wine", &"magenta", &"gold", &"cool_accent":
			return result * _region.accent_tint
		&"ambient":
			return result * _region.ambient_tint
		&"key_light", &"cool_light":
			return result * _region.light_tint
		&"fog":
			return result * _region.fog_tint
	return result

func _refresh_palette() -> void:
	apply_shared_assets(PALETTE)
	if get_tree().current_scene != null:
		_apply_scene(get_tree().current_scene)

func _on_scene_changed() -> void:
	if get_tree().current_scene != null:
		_apply_scene(get_tree().current_scene)

func _apply_scene(scene_root: Node) -> void:
	var anchor := scene_root.get_node_or_null("PaletteRegion") as SablePaletteRegion
	_region = anchor.profile if anchor != null and anchor.profile != null else WHITE_REGION
	apply_scene_visuals(scene_root, PALETTE, _region, anchor)

func _on_node_added(node: Node) -> void:
	# A região deve estar disponível antes do _ready dos efeitos do novo nível.
	if node.get_parent() == get_tree().root and node.scene_file_path != "":
		var anchor := node.get_node_or_null("PaletteRegion") as SablePaletteRegion
		_region = anchor.profile if anchor != null and anchor.profile != null else WHITE_REGION
	if node is OmniLight3D and node.name == &"SpriteFillLight":
		(node as OmniLight3D).light_color = get_color(&"cool_light")

static func apply_shared_assets(palette: SableArtPalette, save_to_disk := false) -> void:
	_set_standard("res://materials/stone.tres", palette.stone_dark, Color.TRANSPARENT, save_to_disk)
	_set_standard("res://materials/stone_light.tres", palette.stone_light, Color.TRANSPARENT, save_to_disk)
	_set_standard("res://materials/accent_magenta.tres", palette.wine, palette.wine.darkened(0.18), save_to_disk)
	_set_standard("res://materials/card_ink.tres", palette.magenta, palette.wine, save_to_disk)
	_set_standard("res://materials/card_ivory.tres", palette.ivory, Color.TRANSPARENT, save_to_disk)
	for path in ["res://materials/stylized_water.tres", "res://materials/stylized_water_gridmap.tres"]:
		var water := load(path) as ShaderMaterial
		water.set_shader_parameter(&"deep_color", palette.ink.lerp(palette.cool_accent, 0.13))
		water.set_shader_parameter(&"shallow_color", palette.cool_accent.darkened(0.48))
		water.set_shader_parameter(&"fresnel_color", palette.cool_accent.lightened(0.23))
		water.set_shader_parameter(&"caustic_color", palette.cool_accent.lightened(0.4))
		if save_to_disk:
			ResourceSaver.save(water)
	var basin_water := load("res://materials/basin_water.tres") as ShaderMaterial
	basin_water.set_shader_parameter(&"deep_color", palette.ink.lerp(palette.cool_accent, 0.17))
	basin_water.set_shader_parameter(&"surface_color", palette.cool_accent.darkened(0.55))
	basin_water.set_shader_parameter(&"glint_color", palette.cool_accent.darkened(0.2))
	if save_to_disk:
		ResourceSaver.save(basin_water)
	var library := load(GRID_LIBRARY) as MeshLibrary
	for item_id in library.get_item_list():
		var mesh := library.get_item_mesh(item_id)
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null:
				continue
			if not material.has_meta(&"sable_original_color"):
				material.set_meta(&"sable_original_color", material.albedo_color)
			var original: Color = material.get_meta(&"sable_original_color")
			material.albedo_color = _scaled(original, palette.stone_mid, GRID_REFERENCE)
	if save_to_disk:
		ResourceSaver.save(library)

static func _set_standard(path: String, albedo: Color, emission: Color, save_to_disk: bool) -> void:
	var material := load(path) as StandardMaterial3D
	material.albedo_color = albedo
	if material.emission_enabled and emission != Color.TRANSPARENT:
		material.emission = emission
	if save_to_disk:
		ResourceSaver.save(material)

static func _scaled(base: Color, target: Color, reference: Color) -> Color:
	return Color(
		clampf(base.r * target.r / reference.r, 0.0, 1.0),
		clampf(base.g * target.g / reference.g, 0.0, 1.0),
		clampf(base.b * target.b / reference.b, 0.0, 1.0),
		base.a
	)

static func apply_scene_visuals(scene_root: Node, palette: SableArtPalette, region: SableRegionPalette, anchor: SablePaletteRegion = null) -> void:
	var world_environment := scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		var environment := world_environment.environment
		if not environment.has_meta(&"sable_original_ambient"):
			environment.set_meta(&"sable_original_ambient", environment.ambient_light_color)
		var original_ambient: Color = environment.get_meta(&"sable_original_ambient")
		environment.ambient_light_color = _scaled(original_ambient, palette.ambient, AMBIENT_REFERENCE) * region.ambient_tint
		if environment.fog_enabled:
			if not environment.has_meta(&"sable_original_fog"):
				environment.set_meta(&"sable_original_fog", environment.fog_light_color)
			var original_fog: Color = environment.get_meta(&"sable_original_fog")
			environment.fog_light_color = original_fog.lerp(palette.fog, 0.2) * region.fog_tint
	for light in scene_root.find_children("*", "DirectionalLight3D", true, false):
		var directional := light as DirectionalLight3D
		if not directional.has_meta(&"sable_original_light"):
			directional.set_meta(&"sable_original_light", directional.light_color)
		var original_light: Color = directional.get_meta(&"sable_original_light")
		directional.light_color = original_light * palette.key_light * region.light_tint
	for fill in scene_root.find_children("SpriteFillLight", "OmniLight3D", true, false):
		(fill as OmniLight3D).light_color = palette.cool_light * region.light_tint
	if anchor == null:
		return
	for path in anchor.tint_targets:
		var target := anchor.get_node_or_null(path) as MeshInstance3D
		if target == null or target.mesh == null:
			continue
		for surface in target.mesh.get_surface_count():
			var material := target.get_surface_override_material(surface) as StandardMaterial3D
			if material == null:
				var source := target.mesh.surface_get_material(surface) as StandardMaterial3D
				if source == null:
					continue
				material = source.duplicate(true) as StandardMaterial3D
				material.set_meta(&"sable_original_color", source.albedo_color)
				target.set_surface_override_material(surface, material)
			if material.has_meta(&"sable_original_color"):
				var original: Color = material.get_meta(&"sable_original_color")
				material.albedo_color = original * region.terrain_tint
