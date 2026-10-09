extends Node3D

## Fragmentos cenográficos da Página Errante; não participam de colisão ou dano.
const FRAGMENT_COUNT := 4
const SPAWN_INTERVAL := 0.035
const FRAGMENT_LIFETIME := 0.16
const PAPER := Color(0.77, 0.67, 0.55)
const INK := Color(0.31, 0.12, 0.41)

var _fragments: Array[MeshInstance3D] = []
var _ages: Array[float] = []
var _cursor := 0
var _spawn_clock := SPAWN_INTERVAL
var _released := false

func _ready() -> void:
	var paper_mesh := BoxMesh.new()
	paper_mesh.size = Vector3(0.3, 0.21, 0.018)
	var ink_mesh := BoxMesh.new()
	ink_mesh.size = Vector3(0.21, 0.16, 0.025)
	var paper_material := StandardMaterial3D.new()
	paper_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paper_material.albedo_color = PAPER
	var ink_material := StandardMaterial3D.new()
	ink_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink_material.albedo_color = INK
	for i in FRAGMENT_COUNT:
		var piece := MeshInstance3D.new()
		piece.name = "PaperFragment" if i % 2 == 0 else "InkFragment"
		piece.mesh = paper_mesh if i % 2 == 0 else ink_mesh
		piece.material_override = paper_material if i % 2 == 0 else ink_material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.visible = false
		add_child(piece)
		_fragments.append(piece)
		_ages.append(FRAGMENT_LIFETIME)

func emit_at(world_position: Vector3, delta: float) -> void:
	if _released:
		return
	_spawn_clock += delta
	if _spawn_clock < SPAWN_INTERVAL:
		return
	_spawn_clock = 0.0
	var piece := _fragments[_cursor]
	piece.global_position = world_position + Vector3(float(_cursor % 2) * 0.18 - 0.09, -0.08, 0)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		piece.look_at(camera.global_position, Vector3.UP, true)
	piece.rotate_z(float(_cursor) * 0.72)
	piece.scale = Vector3.ONE
	piece.visible = true
	_ages[_cursor] = 0.0
	_cursor = (_cursor + 1) % FRAGMENT_COUNT

func release() -> void:
	_released = true

func _process(delta: float) -> void:
	var active := false
	for i in FRAGMENT_COUNT:
		if _ages[i] >= FRAGMENT_LIFETIME:
			continue
		_ages[i] += delta
		var t := clampf(_ages[i] / FRAGMENT_LIFETIME, 0.0, 1.0)
		_fragments[i].scale = Vector3.ONE * (1.0 - t)
		_fragments[i].rotate_z(delta * (4.0 if i % 2 == 0 else -5.0))
		_fragments[i].visible = t < 1.0
		active = active or t < 1.0
	if _released and not active:
		queue_free()
