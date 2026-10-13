@tool
extends RefCounted

## Gera assets estáticos no editor. Não participa do SceneTree durante o jogo.
const OUTPUT_LIBRARY := "res://resources/gridmap/sable_architecture_kit.tres"
const OUTPUT_PREVIEW := "res://scenes/levels/gridmap_architecture_kit_preview.tscn"
const GRAYBOX: MeshLibrary = preload("res://resources/gridmap/sable_graybox_mesh_library.tres")
const STONE: StandardMaterial3D = preload("res://materials/stone.tres")
const LIGHT_STONE: StandardMaterial3D = preload("res://materials/stone_light.tres")
const PALETTE: SableArtPalette = preload("res://resources/palettes/sable_default.tres")
const SKY_MATERIAL: Material = preload("res://materials/contemplative_sky.tres")
const NAMES := [
	"00_Parede_Inteira", "01_Parede_Gasta", "02_Arco", "03_Arco_Fraturado",
	"04_Coluna", "05_Coluna_Alta", "06_Escada", "07_Escada_Gasta",
	"08_Ruina_De_Parede", "09_Ruina_Baixa"
]

static func build_library(seed: int) -> MeshLibrary:
	var library := MeshLibrary.new()
	library.set_meta(&"sable_architecture_seed", seed)
	for id in NAMES.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + id * 7919
		library.create_item(id)
		library.set_item_name(id, NAMES[id])
		library.set_item_mesh(id, _mesh_for(id, rng))
		library.set_item_shapes(id, _shapes_for(id, rng))
	return library

static func save_outputs(seed: int) -> Error:
	var generated := build_library(seed)
	var library := load(OUTPUT_LIBRARY) as MeshLibrary if ResourceLoader.exists(OUTPUT_LIBRARY) else null
	if library == null:
		library = generated
		library.take_over_path(OUTPUT_LIBRARY)
	else:
		# Atualiza o Resource em uso pela prévia aberta, mantendo os IDs do kit.
		for id in NAMES.size():
			if not library.get_item_list().has(id):
				library.create_item(id)
			library.set_item_name(id, generated.get_item_name(id))
			library.set_item_mesh(id, generated.get_item_mesh(id))
			library.set_item_shapes(id, generated.get_item_shapes(id))
		library.set_meta(&"sable_architecture_seed", seed)
	var err := ResourceSaver.save(library, OUTPUT_LIBRARY)
	if err != OK:
		return err
	var preview := build_preview(library, seed)
	err = ResourceSaver.save(preview, OUTPUT_PREVIEW)
	return err

static func build_preview(library: MeshLibrary, seed: int) -> PackedScene:
	var root := Node3D.new()
	root.name = "ArchitectureKitPreview"
	root.set_meta(&"sable_architecture_seed", seed)
	var floor := GridMap.new()
	floor.name = "GrayboxFloor"
	floor.mesh_library = GRAYBOX
	floor.cell_size = Vector3(2, 1, 2)
	floor.cell_center_y = false
	root.add_child(floor)
	floor.owner = root
	var pieces := GridMap.new()
	pieces.name = "ArchitectureKit"
	pieces.mesh_library = library
	pieces.cell_size = Vector3(2, 1, 2)
	pieces.cell_center_y = false
	root.add_child(pieces)
	pieces.owner = root
	for id in NAMES.size():
		var cx := (id % 5) * 3
		var cz := int(id / 5) * 4
		pieces.set_cell_item(Vector3i(cx, 0, cz), id)
		for x in range(cx - 1, cx + 2):
			for z in range(cz - 1, cz + 2):
				floor.set_cell_item(Vector3i(x, 0, z), 0)
		var label := Label3D.new()
		label.name = "Label_%02d" % id
		label.text = NAMES[id].trim_prefix("%02d_" % id).replace("_", " ")
		label.font_size = 48
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = pieces.map_to_local(Vector3i(cx, 0, cz)) + Vector3(0, 3.3, 0)
		root.add_child(label)
		label.owner = root
	var environment_node := WorldEnvironment.new()
	environment_node.name = "PreviewEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = SKY_MATERIAL
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = PALETTE.ambient
	environment.ambient_light_energy = 0.9
	environment_node.environment = environment
	root.add_child(environment_node)
	environment_node.owner = root
	var light := DirectionalLight3D.new()
	light.name = "PreviewLight"
	light.rotation_degrees = Vector3(-50, -25, 0)
	light.light_energy = 1.4
	root.add_child(light)
	light.owner = root
	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.position = Vector3(13, 9, 24)
	camera.basis = Basis.looking_at(Vector3(13, 1, 6) - camera.position, Vector3.UP)
	camera.fov = 70.0
	camera.current = true
	root.add_child(camera)
	camera.owner = root
	var scene := PackedScene.new()
	assert(scene.pack(root) == OK)
	root.free()
	return scene

static func _mesh_for(id: int, rng: RandomNumberGenerator) -> Mesh:
	var dark := SurfaceTool.new()
	dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	dark.set_material(STONE)
	var light := SurfaceTool.new()
	light.begin(Mesh.PRIMITIVE_TRIANGLES)
	light.set_material(LIGHT_STONE)
	match id:
		0, 1:
			_wall(dark, light, rng, id == 1)
		2, 3:
			_arch(dark, light, rng, id == 3)
		4, 5:
			_column(dark, light, rng, id == 5)
		6, 7:
			_stairs(dark, light, rng, id == 7)
		8:
			_ruin_wall(dark, light, rng)
		9:
			_ruin_low(dark, light, rng)
	var mesh := ArrayMesh.new()
	dark.generate_normals()
	dark.commit(mesh)
	light.generate_normals()
	light.commit(mesh)
	return mesh

static func _wall(dark: SurfaceTool, light: SurfaceTool, rng: RandomNumberGenerator, worn: bool) -> void:
	if worn:
		var seam := rng.randf_range(-0.24, 0.22)
		_box(dark, Vector3(-1, -0.2, -1), Vector3(seam - 0.03, 0.8, -0.78))
		_box(dark, Vector3(seam + 0.03, -0.2, -1), Vector3(1, 0.7, -0.78))
		_box(light, Vector3(seam - 0.035, -0.2, -0.77), Vector3(seam + 0.035, 0.58, -0.71))
	else:
		_box(dark, Vector3(-1, -0.2, -1), Vector3(1, 0.8, -0.78))
		_box(light, Vector3(-1, 0.59, -0.77), Vector3(1, 0.68, -0.72))
	var chip_x := rng.randf_range(-0.75, 0.65)
	_box(light, Vector3(chip_x, -0.18, -0.77), Vector3(chip_x + 0.16, 0.03, -0.7))

static func _arch(dark: SurfaceTool, light: SurfaceTool, rng: RandomNumberGenerator, broken: bool) -> void:
	var pier := 0.26 + rng.randf_range(-0.025, 0.025)
	_box(dark, Vector3(-1, -0.2, -1), Vector3(-1 + pier, 2.15, -0.78))
	_box(dark, Vector3(1 - pier, -0.2, -1), Vector3(1, 2.15, -0.78))
	# Duas pedras inclinadas deixam a leitura gótica, com vão livre >= 1,4 m.
	_extrude(light, [Vector2(-1, 2.15), Vector2(0, 2.15), Vector2(0, 2.8), Vector2(-1, 2.35)], -1, -0.78)
	_extrude(light, [Vector2(0, 2.15), Vector2(1, 2.15), Vector2(1, 2.35), Vector2(0, 2.8)], -1, -0.78)
	var band_y := 0.3 + rng.randf_range(-0.08, 0.08)
	_box(light, Vector3(-1, band_y, -0.77), Vector3(-1 + pier, band_y + 0.1, -0.71))
	if broken:
		_box(dark, Vector3(1 - pier, 1.5, -0.77), Vector3(1, 1.63, -0.68))
	else:
		_box(light, Vector3(1 - pier, band_y, -0.77), Vector3(1, band_y + 0.1, -0.71))

static func _column(dark: SurfaceTool, light: SurfaceTool, rng: RandomNumberGenerator, tall: bool) -> void:
	var top := 2.8 if tall else 0.8
	var radius := 0.24 if tall else 0.2
	_box(dark, Vector3(-0.31, -0.2, -0.31), Vector3(0.31, 0.03, 0.31))
	_cylinder(dark, radius, 0.03, top - 0.16, 6, rng.randf_range(0.0, 0.4))
	_box(light, Vector3(-0.29, top - 0.16, -0.29), Vector3(0.29, top, 0.29))

static func _stairs(dark: SurfaceTool, light: SurfaceTool, rng: RandomNumberGenerator, worn: bool) -> void:
	for step in 5:
		var z0 := -1.0 + step * 0.4
		var top := 1.0 - step * 0.2
		var wear := rng.randf_range(0.015, 0.055) if worn else 0.0
		_box(dark, Vector3(-1, -0.2, z0), Vector3(1, top - wear, z0 + 0.4))
		_box(light, Vector3(-1, top - wear - 0.06, z0 + 0.33), Vector3(1, top - wear + 0.005, z0 + 0.39))

static func _ruin_wall(dark: SurfaceTool, light: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var left_top := rng.randf_range(0.5, 0.78)
	var right_top := rng.randf_range(0.32, 0.63)
	_box(dark, Vector3(-1, -0.2, -1), Vector3(-0.56, left_top, -0.76))
	_box(dark, Vector3(0.56, -0.2, -1), Vector3(1, right_top, -0.76))
	_box(light, Vector3(-0.99, left_top - 0.07, -0.75), Vector3(-0.57, left_top, -0.69))

static func _ruin_low(dark: SurfaceTool, light: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var height := rng.randf_range(0.28, 0.42)
	_box(dark, Vector3(-0.85, -0.2, -0.55), Vector3(-0.15, height, 0.18))
	_box(dark, Vector3(0.25, -0.2, 0.12), Vector3(0.86, height * 0.75, 0.68))
	_box(light, Vector3(-0.62, height - 0.05, -0.54), Vector3(-0.23, height + 0.01, -0.48))

static func _shapes_for(id: int, rng: RandomNumberGenerator) -> Array:
	match id:
		0, 1: return GRAYBOX.get_item_shapes(1)
		2, 3: return GRAYBOX.get_item_shapes(6)
		4: return GRAYBOX.get_item_shapes(8)
		5: return GRAYBOX.get_item_shapes(16)
		6, 7: return GRAYBOX.get_item_shapes(11)
		8:
			return _box_shapes([
				[Vector3(-0.78, 0.15, -0.88), Vector3(0.44, 0.7, 0.24)],
				[Vector3(0.78, 0.06, -0.88), Vector3(0.44, 0.52, 0.24)]
			])
		9:
			return _box_shapes([
				[Vector3(-0.5, 0.04, -0.18), Vector3(0.7, 0.48, 0.73)],
				[Vector3(0.55, 0.005, 0.4), Vector3(0.61, 0.41, 0.56)]
			])
	return []

static func _box_shapes(parts: Array) -> Array:
	var result: Array = []
	for part in parts:
		var shape := BoxShape3D.new()
		shape.size = part[1]
		result.append(shape)
		result.append(Transform3D(Basis(), part[0]))
	return result

static func _box(tool: SurfaceTool, low: Vector3, high: Vector3) -> void:
	var a := Vector3(low.x, low.y, low.z)
	var b := Vector3(high.x, low.y, low.z)
	var c := Vector3(high.x, high.y, low.z)
	var d := Vector3(low.x, high.y, low.z)
	var e := Vector3(low.x, low.y, high.z)
	var f := Vector3(high.x, low.y, high.z)
	var g := Vector3(high.x, high.y, high.z)
	var h := Vector3(low.x, high.y, high.z)
	_quad(tool, e, f, g, h)
	_quad(tool, b, a, d, c)
	_quad(tool, f, b, c, g)
	_quad(tool, a, e, h, d)
	_quad(tool, h, g, c, d)
	_quad(tool, a, b, f, e)

static func _extrude(tool: SurfaceTool, polygon: Array[Vector2], z0: float, z1: float) -> void:
	for i in range(1, polygon.size() - 1):
		_tri(tool, Vector3(polygon[0].x, polygon[0].y, z1), Vector3(polygon[i].x, polygon[i].y, z1), Vector3(polygon[i + 1].x, polygon[i + 1].y, z1))
		_tri(tool, Vector3(polygon[i + 1].x, polygon[i + 1].y, z0), Vector3(polygon[i].x, polygon[i].y, z0), Vector3(polygon[0].x, polygon[0].y, z0))
	for i in polygon.size():
		var j := (i + 1) % polygon.size()
		var a := Vector3(polygon[i].x, polygon[i].y, z0)
		var b := Vector3(polygon[j].x, polygon[j].y, z0)
		_quad(tool, a, b, Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1))

static func _cylinder(tool: SurfaceTool, radius: float, y0: float, y1: float, sides: int, phase: float) -> void:
	for i in sides:
		var a := phase + TAU * float(i) / sides
		var b := phase + TAU * float(i + 1) / sides
		var p := Vector3(cos(a) * radius, y0, sin(a) * radius)
		var q := Vector3(cos(b) * radius, y0, sin(b) * radius)
		_quad(tool, p, Vector3(p.x, y1, p.z), Vector3(q.x, y1, q.z), q)
		_tri(tool, Vector3(0, y1, 0), Vector3(q.x, y1, q.z), Vector3(p.x, y1, p.z))
		_tri(tool, Vector3(0, y0, 0), p, q)

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(tool, a, b, c)
	_tri(tool, a, c, d)

static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)
