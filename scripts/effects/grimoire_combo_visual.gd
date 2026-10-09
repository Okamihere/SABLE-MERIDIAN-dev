extends Node3D

## Geometria cenográfica dos quatro projéteis leves. Nunca controla dano ou hitboxes.
const INK := Color(0.075, 0.025, 0.11)
const PAPER := Color(0.76, 0.68, 0.55)
const VIOLET := Color(0.53, 0.29, 0.75)
const GOLD := Color(0.68, 0.43, 0.17)

var _stage := 0
var _impact := false
var _age := 0.0
var _blade: Node3D
var _materials: Dictionary = {}

func configure(stage: int, impact: bool = false) -> void:
	_stage = stage
	_impact = impact
	match stage:
		1: _page()
		2: _hand()
		3: _swarm()
		4: _guillotine()
	if impact:
		_burst()
		scale = Vector3.ONE * 0.65
	elif stage == 4:
		scale = Vector3.ONE * 0.78

func _process(delta: float) -> void:
	_age += delta
	if _impact:
		var t := clampf(_age / 0.28, 0.0, 1.0)
		scale = Vector3.ONE * (0.65 + (1.45 if _stage == 4 else 0.75) * sin(PI * t))
		if _stage == 4 and is_instance_valid(_blade):
			_blade.position.y = lerpf(0.64, -0.38, clampf(t * 2.4, 0.0, 1.0))
		if t >= 1.0:
			queue_free()
		return
	match _stage:
		1:
			rotation.z = sin(_age * 15.0) * 0.23
		2:
			rotation.z = -0.45 + sin(minf(_age * 23.0, PI)) * 0.85
		3:
			rotation.z += delta * 13.0
		4:
			if is_instance_valid(_blade):
				_blade.position.y = 0.28 + sin(_age * 13.0) * 0.09

func _page() -> void:
	_box(self, "LivingPage", Vector3.ZERO, Vector3(0.54, 0.68, 0.035), PAPER)
	_box(self, "InkSpine", Vector3(-0.25, 0, 0.03), Vector3(0.055, 0.66, 0.025), INK)
	_box(self, "CutLine", Vector3(0.03, 0, 0.04), Vector3(0.34, 0.045, 0.025), VIOLET).rotation.z = -0.68
	_box(self, "FangedCorner", Vector3(0.21, -0.3, 0.03), Vector3(0.12, 0.1, 0.04), INK).rotation.z = -0.45

func _hand() -> void:
	_box(self, "InkPalm", Vector3(0, 0.12, 0), Vector3(0.64, 0.52, 0.14), INK)
	_box(self, "Cuff", Vector3(0, -0.26, 0), Vector3(0.43, 0.19, 0.16), VIOLET)
	for i in 4:
		var length := 0.3 + 0.08 * sin(float(i) * 1.7)
		_box(self, "Finger%d" % i, Vector3(-0.24 + float(i) * 0.16, 0.49 + length * 0.5, 0), Vector3(0.105, length, 0.11), INK)
	_box(self, "Thumb", Vector3(-0.43, 0.05, 0), Vector3(0.13, 0.34, 0.12), INK).rotation.z = -0.65
	_box(self, "PalmMark", Vector3(0, 0.15, 0.085), Vector3(0.22, 0.18, 0.025), GOLD).rotation.z = PI * 0.25

func _swarm() -> void:
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var page := _box(self, "CursedPage%d" % i, Vector3(cos(angle) * 0.39, sin(angle) * 0.36, 0.04 * float(i % 2)), Vector3(0.25, 0.34, 0.025), PAPER)
		page.rotation.z = angle + 0.42
	_box(self, "InkHeart", Vector3.ZERO, Vector3(0.19, 0.19, 0.18), INK).rotation.z = PI * 0.25

func _guillotine() -> void:
	_box(self, "LeftPost", Vector3(-0.59, 0.08, 0), Vector3(0.13, 1.55, 0.13), INK)
	_box(self, "RightPost", Vector3(0.59, 0.08, 0), Vector3(0.13, 1.55, 0.13), INK)
	_box(self, "Crown", Vector3(0, 0.88, 0), Vector3(1.36, 0.17, 0.15), GOLD)
	_blade = Node3D.new()
	_blade.name = "PaperBlade"
	_blade.position.y = 0.28
	add_child(_blade)
	_box(_blade, "IvoryBlade", Vector3.ZERO, Vector3(1.13, 0.34, 0.085), PAPER)
	_box(_blade, "InkEdge", Vector3(0, -0.2, 0.01), Vector3(1.2, 0.07, 0.105), INK)
	_box(_blade, "Seal", Vector3(0, 0.07, 0.057), Vector3(0.2, 0.17, 0.025), VIOLET).rotation.z = PI * 0.25

func _burst() -> void:
	for i in 4:
		var angle := TAU * float(i) / 4.0
		_box(self, "InkBurst%d" % i, Vector3(cos(angle) * 0.55, sin(angle) * 0.53, 0), Vector3(0.1, 0.42, 0.06), INK).rotation.z = angle - PI * 0.5

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
