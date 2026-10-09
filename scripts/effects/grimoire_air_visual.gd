extends Node3D

## Silhuetas de invocação aérea do Grimório. Dano e alcance seguem as hitboxes do jogador.
const PAPER := Color(0.78, 0.68, 0.53)
const INK := Color(0.07, 0.025, 0.11)
const VIOLET := Color(0.47, 0.25, 0.67)
const GOLD := Color(0.72, 0.44, 0.18)

var _caster: PlayerController
var _attack: AttackData
var _heavy := false
var _age := 0.0
var _left: Node3D
var _right: Node3D
var _blade: Node3D
var _materials: Dictionary = {}

func configure(caster: PlayerController, attack: AttackData) -> void:
	_caster = caster
	_attack = attack
	_heavy = attack.attack_id == &"grimoire_air_heavy"
	if _heavy:
		_curtain()
	else:
		_winged_mask()

func _process(delta: float) -> void:
	if not is_instance_valid(_caster) or _caster.combat._current_attack != _attack:
		queue_free()
		return
	_age += delta
	var forward := _caster.global_basis.z.normalized()
	var origin := _caster.global_position + Vector3.UP * 1.25
	var desired := _caster.global_position + Vector3.UP * (1.5 if _heavy else 1.55) + forward * (1.8 if _heavy else 2.0)
	var query := PhysicsRayQueryParameters3D.create(origin, desired, 1)
	query.exclude = [_caster.get_rid()]
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	global_position = wall.position - forward * 0.25 if not wall.is_empty() else desired
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		look_at(camera.global_position, Vector3.UP, true)
	var total := _attack.startup + _attack.active + _attack.recovery
	var t := clampf(_age / total, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.73, 1.0, t)
	if _heavy:
		var fall := smoothstep(0.12, 0.54, t)
		_blade.position.y = lerpf(1.05, -0.45, fall)
		_blade.scale.x = 0.6 + 0.4 * smoothstep(0.0, 0.22, t)
		rotation.z = sin(t * TAU * 2.0) * 0.06 * fade
	else:
		var slash := smoothstep(0.08, 0.53, t)
		_left.rotation.z = lerpf(0.75, -0.52, slash)
		_right.rotation.z = lerpf(-0.75, 0.52, slash)
		rotation.z = sin(t * TAU * 2.0) * 0.15
	scale = Vector3.ONE * minf(1.0, _age / 0.045) * fade

func _winged_mask() -> void:
	_left = Node3D.new()
	_left.name = "LeftPageWing"
	_left.position = Vector3(-0.18, 0.1, 0)
	add_child(_left)
	_right = Node3D.new()
	_right.name = "RightPageWing"
	_right.position = Vector3(0.18, 0.1, 0)
	add_child(_right)
	for wing in [_left, _right]:
		var side := -1.0 if wing == _left else 1.0
		_box(wing, "ParchmentBlade", Vector3(side * 0.52, 0.1, 0), Vector3(1.08, 0.28, 0.04), PAPER).rotation.z = -side * 0.2
		_box(wing, "InkEdge", Vector3(side * 0.95, -0.07, 0.02), Vector3(0.4, 0.08, 0.05), INK).rotation.z = side * 0.28
	_box(self, "InkMask", Vector3(0, 0.09, 0.07), Vector3(0.36, 0.38, 0.12), INK)
	_box(self, "PaperFace", Vector3(0, 0.1, 0.15), Vector3(0.23, 0.27, 0.035), PAPER)
	_box(self, "VioletGrin", Vector3(0, -0.015, 0.18), Vector3(0.17, 0.045, 0.025), VIOLET)
	for side in [-1.0, 1.0]:
		_box(self, "Horn", Vector3(side * 0.16, 0.34, 0.08), Vector3(0.08, 0.22, 0.06), INK).rotation.z = -side * 0.45

func _curtain() -> void:
	_box(self, "LeftPost", Vector3(-0.92, 0.12, 0), Vector3(0.13, 1.55, 0.16), INK)
	_box(self, "RightPost", Vector3(0.92, 0.12, 0), Vector3(0.13, 1.55, 0.16), INK)
	_box(self, "GildedRail", Vector3(0, 0.96, 0), Vector3(2.05, 0.16, 0.17), GOLD)
	_blade = Node3D.new()
	_blade.name = "FallingPaperCurtain"
	add_child(_blade)
	for i in 3:
		_box(_blade, "InkPanel%d" % i, Vector3((float(i) - 1.0) * 0.59, 0, 0), Vector3(0.62, 0.8, 0.08), INK)
		_box(_blade, "PaperHem%d" % i, Vector3((float(i) - 1.0) * 0.59, -0.45, 0.03), Vector3(0.58, 0.12, 0.06), PAPER)
	_box(_blade, "StageMask", Vector3(0, 0.09, 0.09), Vector3(0.28, 0.26, 0.05), VIOLET).rotation.z = PI * 0.25

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
