extends Node3D

## Origami cenográfico da Página Errante; não controla movimento, colisão ou dano.
const PAPER := Color(0.77, 0.67, 0.55)
const INK := Color(0.07, 0.025, 0.11)
const VIOLET := Color(0.47, 0.24, 0.67)
const GOLD := Color(0.72, 0.43, 0.18)

var _age := 0.0
var _impact := false
var _left_wing: Node3D
var _right_wing: Node3D
var _mask: Node3D
var _page: Node3D
var _body: Node3D
var _upper_jaw: Node3D
var _lower_jaw: Node3D
var _impact_mask: Node3D
var _shards: Array[MeshInstance3D] = []
var _shard_directions: Array[Vector3] = []
var _materials: Dictionary = {}

func configure(impact: bool = false) -> void:
	_impact = impact
	if impact:
		_impact_geometry()
		return
	_page = _box(self, "UnfoldingPage", Vector3.ZERO, Vector3(0.58, 0.76, 0.035), PAPER)
	_left_wing = Node3D.new()
	_left_wing.name = "LeftWing"
	_left_wing.position = Vector3(-0.13, 0.05, 0)
	add_child(_left_wing)
	_right_wing = Node3D.new()
	_right_wing.name = "RightWing"
	_right_wing.position = Vector3(0.13, 0.05, 0)
	add_child(_right_wing)
	for wing in [_left_wing, _right_wing]:
		var side := -1.0 if wing == _left_wing else 1.0
		_box(wing, "ParchmentFeather", Vector3(side * 0.36, 0.02, 0), Vector3(0.82, 0.3, 0.035), PAPER).rotation.z = -side * 0.22
		_box(wing, "InkTip", Vector3(side * 0.81, -0.13, 0.02), Vector3(0.38, 0.13, 0.045), INK).rotation.z = side * 0.25
		_box(wing, "InkVein", Vector3(side * 0.48, 0.025, 0.025), Vector3(0.48, 0.035, 0.025), INK).rotation.z = -side * 0.22
	_body = _box(self, "FoldedBody", Vector3(0, -0.15, 0.04), Vector3(0.4, 0.51, 0.13), INK)
	_body.rotation.z = PI * 0.25
	_mask = Node3D.new()
	_mask.name = "GrotesqueMask"
	_mask.position = Vector3(0, 0.2, 0.14)
	add_child(_mask)
	_box(_mask, "Mask", Vector3.ZERO, Vector3(0.46, 0.38, 0.055), PAPER)
	for side in [-1.0, 1.0]:
		_box(_mask, "Eye", Vector3(side * 0.13, 0.055, 0.045), Vector3(0.09, 0.11, 0.03), VIOLET).rotation.z = side * 0.4
		_box(_mask, "Horn", Vector3(side * 0.18, 0.23, 0), Vector3(0.1, 0.25, 0.04), INK).rotation.z = -side * 0.38
	_box(_mask, "Grimace", Vector3(0, -0.1, 0.047), Vector3(0.27, 0.035, 0.028), INK)
	_box(_mask, "CrookedBeak", Vector3(0, -0.21, 0.06), Vector3(0.18, 0.23, 0.09), GOLD).rotation.z = 0.18
	_page.scale = Vector3.ONE
	_mask.scale = Vector3.ZERO
	_body.scale = Vector3.ZERO
	_left_wing.scale = Vector3.ONE * 0.3
	_right_wing.scale = Vector3.ONE * 0.3
	_left_wing.rotation.z = 0.75
	_right_wing.rotation.z = -0.75

func _process(delta: float) -> void:
	_age += delta
	if _impact:
		_update_impact()
		if _age >= 0.22:
			queue_free()
		return
	var windup := smoothstep(0.0, 0.035, _age)
	var fold := smoothstep(0.035, 0.095, _age)
	_page.scale = Vector3.ONE * (1.0 + windup * 0.18 - fold * 1.08)
	_mask.scale = Vector3.ONE * fold
	_body.scale = Vector3.ONE * fold
	_left_wing.scale = Vector3.ONE * (0.3 + 0.7 * fold)
	_right_wing.scale = _left_wing.scale
	var flap := sin(_age * 24.0) * 0.29 * fold
	_left_wing.rotation.z = lerpf(0.75, -0.28, fold) + flap
	_right_wing.rotation.z = lerpf(-0.75, 0.28, fold) - flap
	position.y = sin(_age * 17.0) * 0.045 * fold
	rotation.x = -0.1 - 0.29 * fold
	rotation.z = sin(_age * 11.0) * 0.06 * fold

func _impact_geometry() -> void:
	_upper_jaw = _box(self, "UpperBeak", Vector3(0, 0.48, 0), Vector3(0.75, 0.2, 0.065), PAPER)
	_lower_jaw = _box(self, "LowerBeak", Vector3(0, -0.48, 0), Vector3(0.7, 0.2, 0.065), INK)
	for side in [-1.0, 1.0]:
		_box(_upper_jaw, "Fang", Vector3(side * 0.19, -0.14, 0.04), Vector3(0.12, 0.23, 0.045), GOLD).rotation.z = side * 0.2
	_impact_mask = _box(self, "MaskShatter", Vector3.ZERO, Vector3(0.34, 0.39, 0.05), PAPER)
	_impact_mask.visible = false
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var shard := _box(self, "PageShred%d" % i, Vector3.ZERO, Vector3(0.23, 0.16, 0.025) if i % 2 == 0 else Vector3(0.09, 0.29, 0.035), PAPER if i % 2 == 0 else VIOLET)
		shard.rotation.z = angle
		shard.visible = false
		_shards.append(shard)
		_shard_directions.append(Vector3(cos(angle), sin(angle), 0))

func _update_impact() -> void:
	if _age < 0.045:
		var bite := smoothstep(0.0, 0.045, _age)
		_upper_jaw.position.y = lerpf(0.48, 0.08, bite)
		_lower_jaw.position.y = lerpf(-0.48, -0.08, bite)
		scale = Vector3.ONE * (1.2 + bite * 0.9)
		return
	_upper_jaw.visible = false
	_lower_jaw.visible = false
	var rupture := smoothstep(0.045, 0.11, _age)
	var fade := 1.0 - smoothstep(0.11, 0.22, _age)
	_impact_mask.visible = _age < 0.12
	_impact_mask.scale = Vector3.ONE * (1.15 - rupture * 0.6)
	for i in _shards.size():
		_shards[i].visible = true
		_shards[i].position = _shard_directions[i] * (0.15 + rupture * 0.43 + (1.0 - fade) * 0.28)
		_shards[i].rotation.z += (3.0 if i % 2 == 0 else -4.0) * get_process_delta_time()
		_shards[i].scale = Vector3.ONE * maxf(0.0, fade)

func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		_materials[color] = material
	instance.material_override = _materials[color]
	parent.add_child(instance)
	return instance
