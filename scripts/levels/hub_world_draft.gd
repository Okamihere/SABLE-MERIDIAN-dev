extends Node3D

## Sete estudos de percurso ligados ao hub. O primeiro mundo tem o ciclo completo.
@export_range(2, 8) var world_index := 2
@export var world_title := "MUNDO"

const HUB_SCENE := "res://scenes/levels/vertical_pilot.tscn"
const ENEMY_SCENE := preload("res://scenes/enemies/basic_enemy.tscn")
const WATER_MAT := preload("res://materials/stylized_water.tres")
const COURSE_Z := [8.0, -3.0, -14.0, -25.0, -37.0, -49.0, -59.0, -72.0]
const OFFSETS := {
	2: [0.0, 0.0, 3.0, 7.0, 7.0, 4.0, 0.0, 0.0],
	3: [0.0, -3.0, -6.0, -3.0, 2.0, 6.0, 3.0, 0.0],
	4: [0.0, 4.0, 7.0, 3.0, -3.0, -7.0, -4.0, 0.0],
	5: [0.0, 0.0, -2.0, -5.0, -5.0, -2.0, 3.0, 6.0],
	6: [0.0, 2.0, 4.0, 0.0, -4.0, -2.0, 2.0, 0.0],
	7: [0.0, -4.0, -8.0, -8.0, -3.0, 2.0, 7.0, 7.0],
	8: [0.0, 3.0, 6.0, 3.0, -3.0, -6.0, -3.0, 0.0],
}
const HEIGHTS := {
	2: [0.0, 0.0, 0.0, 0.0, 0.8, 1.6, 2.4, 2.4],
	3: [0.0, 0.8, 1.6, 2.4, 2.4, 3.2, 4.0, 4.0],
	4: [0.0, 0.0, 0.8, 0.8, 1.6, 1.6, 2.4, 2.4],
	5: [0.0, 0.8, 1.6, 2.4, 3.2, 4.0, 4.8, 4.8],
	6: [0.0, 0.0, 0.0, 0.8, 0.8, 1.6, 1.6, 1.6],
	7: [0.0, 0.8, 0.8, 1.6, 2.4, 2.4, 3.2, 3.2],
	8: [0.0, 0.8, 1.6, 2.4, 3.2, 4.0, 4.8, 5.6],
}

var _inside_return := false

func _ready() -> void:
	_build_course()
	_build_return()
	get_node("Player").position = Vector3(0, 0.05, 10)

func _unhandled_input(event: InputEvent) -> void:
	if _inside_return and event.is_action_pressed("interact") and not event.is_echo() and not AreaTransition.is_travelling:
		get_viewport().set_input_as_handled()
		Progression.hub_return_world = StringName("world_%02d" % world_index)
		AreaTransition.travel_to(HUB_SCENE)

func _build_course() -> void:
	var offsets: Array = OFFSETS[world_index]
	var heights: Array = HEIGHTS[world_index]
	var stone := _material(Color(0.28, 0.29, 0.34))
	var route := _material(Color(0.52, 0.50, 0.60))
	var section_depths: Array[float] = []
	var section_centers: Array[float] = []
	for i in COURSE_Z.size():
		var depth: float = 21.0 if i == 3 or i == 7 else 13.0
		var north_edge: float = COURSE_Z[i] + depth * 0.5
		var south_edge: float = COURSE_Z[i] - depth * 0.5
		if i > 0:
			var previous_depth: float = 21.0 if i - 1 == 3 else 13.0
			var previous_south: float = COURSE_Z[i - 1] - previous_depth * 0.5
			if north_edge > previous_south:
				if i == 3:
					section_depths[i - 1] -= north_edge - previous_south
					section_centers[i - 1] += (north_edge - previous_south) * 0.5
				elif i == 4:
					north_edge = previous_south
				else:
					var seam: float = (north_edge + previous_south) * 0.5
					section_depths[i - 1] -= seam - previous_south
					section_centers[i - 1] += (seam - previous_south) * 0.5
					north_edge = seam
		section_depths.append(north_edge - south_edge)
		section_centers.append((north_edge + south_edge) * 0.5)
	for i in COURSE_Z.size():
		var width := 22.0 if i == 3 or i == 7 else (7.0 if world_index == 6 and i in [1, 2, 4, 5] else 11.0)
		var depth: float = section_depths[i]
		var center := Vector3(offsets[i], heights[i] - 0.5, section_centers[i])
		_box("Section%02d" % i, center, Vector3(width, 1, depth), route if i in [1, 4, 6] else stone, true)
		if world_index == 2:
			# Mundo 2 tem tematica aquatica: lamina d'agua sobre cada secao.
			_water("Water%02d" % i, Vector3(center.x, heights[i] + 0.03, center.z), Vector2(width - 0.4, depth - 0.4))
		if i > 0 and i < 7:
			# Pilares baixos organizam combate sem bloquear o eixo de travessia.
			_box("ButtressL%02d" % i, center + Vector3(-width * 0.5 + 0.7, 2.5, 0), Vector3(1.4, 5, 1.4), stone, true)
			_box("ButtressR%02d" % i, center + Vector3(width * 0.5 - 0.7, 2.5, 0), Vector3(1.4, 5, 1.4), stone, true)
		if i > 0 and heights[i] > heights[i - 1]:
			# Passo visual e colidível em cada mudança de altura; diferença máxima 0,8 m.
			var mid := Vector3((offsets[i] + offsets[i - 1]) * 0.5, (heights[i] + heights[i - 1]) * 0.5 - 0.5, (COURSE_Z[i] + COURSE_Z[i - 1]) * 0.5)
			_box("Rise%02d" % i, mid, Vector3(6, 1, 5), route, true)
			if world_index == 2:
				_water("WaterRise%02d" % i, Vector3(mid.x, (heights[i] + heights[i - 1]) * 0.5 + 0.03, mid.z), Vector2(5.6, 4.6))
	# Marcos espaciais diferentes para orientar cada percurso.
	match world_index:
		2: _box("MirrorWall", Vector3(13, 6, -24), Vector3(1.2, 12, 23), route, true)
		3: _box("WellCore", Vector3(0, 7, -31), Vector3(5, 14, 5), stone, true)
		4: _box("BrokenNave", Vector3(-13, 6, -27), Vector3(2, 12, 29), stone, true)
		5: _box("ArchiveTower", Vector3(-13, 11, -50), Vector3(7, 22, 7), stone, true)
		6: _box("BridgeVoidMarker", Vector3(12, -4, -43), Vector3(6, 5, 17), stone, false)
		7: _box("EmptyBoxSeats", Vector3(14, 8, -48), Vector3(5, 16, 24), stone, true)
		8: _box("SilentTower", Vector3(0, 14, -86), Vector3(16, 17, 3), stone, true)
	_label(world_title + "\nEXPLORAÇÃO", Vector3(0, 4, 3))
	_label("COMBATE", Vector3(offsets[3], heights[3] + 4, COURSE_Z[3]))
	for side in [-1.0, 1.0]:
		var enemy := ENEMY_SCENE.instantiate() as Node3D
		enemy.position = Vector3(offsets[3] + side * 4.0, heights[3] + 0.05, COURSE_Z[3])
		add_child(enemy)
	_label("TRAVESSIA", Vector3(offsets[5], heights[5] + 4, COURSE_Z[5]))
	_label("ARENA FINAL  •  BOSS EM PRODUÇÃO", Vector3(offsets[7], heights[7] + 5, COURSE_Z[7]))
	_box("BossMarker", Vector3(offsets[7], heights[7] + 2, COURSE_Z[7] - 4), Vector3(2.5, 4, 2.5), _material(Color(0.48, 0.18, 0.26)), false)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -20, 0)
	light.light_energy = 0.8
	add_child(light)

func _build_return() -> void:
	_make_return(Vector3(0, 0, 11), "ReturnToHub", "F  •  VOLTAR AO HUB")
	var offsets: Array = OFFSETS[world_index]
	var heights: Array = HEIGHTS[world_index]
	_make_return(Vector3(offsets[7], heights[7], COURSE_Z[7] + 5), "ReturnFromFinalArena", "F  •  VOLTAR AO HUB")

func _make_return(at: Vector3, node_name: String, caption: String) -> void:
	var gate := Area3D.new()
	gate.name = node_name
	gate.position = at
	gate.collision_layer = 0
	gate.collision_mask = 2
	add_child(gate)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 4, 3)
	shape_node.shape = shape
	shape_node.position.y = 2
	gate.add_child(shape_node)
	gate.body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerController:
			_inside_return = true)
	gate.body_exited.connect(func(body: Node3D) -> void:
		if body is PlayerController:
			_inside_return = false)
	_label(caption, at + Vector3(0, 3.8, 1))

func _water(title: String, at: Vector3, size_xz: Vector2) -> void:
	var plane := PlaneMesh.new()
	plane.material = WATER_MAT
	plane.size = size_xz
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var film := MeshInstance3D.new()
	film.name = title
	film.mesh = plane
	film.position = at
	add_child(film)

func _box(title: String, at: Vector3, dimensions: Vector3, material: Material, solid: bool) -> void:
	var block := CSGBox3D.new()
	block.name = title
	block.position = at
	block.size = dimensions
	block.material = material
	add_child(block)
	if solid:
		var body := StaticBody3D.new()
		body.name = "Body"
		block.add_child(body)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		body.add_child(collision)

func _label(copy: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = copy
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.007
	label.font_size = 40
	label.outline_size = 8
	add_child(label)

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	return result
