extends Node3D

## Apenas apresentação da Mordida do Manuscrito; a hitbox continua no projétil.
const INK := Color(0.075, 0.025, 0.11)
const PAPER := Color(0.78, 0.69, 0.55)
const VIOLET := Color(0.48, 0.25, 0.67)
const GOLD := Color(0.72, 0.46, 0.19)
const OMEN_SFX := preload("res://assets/audio/sfx/abs-popup-2-fast.wav")
const SNAP_SFX := preload("res://assets/audio/sfx/MI_SFX 29.wav")
const IMPACT_SFX := preload("res://assets/audio/sfx/MI_SFX 42.wav")

var _summoning := false
var _age := 0.0
var _impact_age := -1.0
var _snapped := false
var _upper: Node3D
var _lower: Node3D
var _burst: Node3D
var _paper: Node3D
var _escape_pages: Node3D
var _materials: Dictionary = {}

func configure(summoning: bool = false) -> void:
	_summoning = summoning
	_upper = Node3D.new()
	_upper.name = "UpperJaw"
	add_child(_upper)
	_lower = Node3D.new()
	_lower.name = "LowerJaw"
	add_child(_lower)
	_box(self, "InkThroat", Vector3(0, 0, -0.22), Vector3(2.15, 1.16, 0.11), INK)
	_box(_upper, "UpperInk", Vector3(0, 0.2, 0), Vector3(2.65, 0.4, 0.4), INK)
	_box(_lower, "LowerInk", Vector3(0, -0.2, 0), Vector3(2.65, 0.4, 0.4), INK)
	_box(_upper, "Brow", Vector3(0, 0.55, 0.05), Vector3(2.16, 0.15, 0.17), VIOLET)
	_box(_lower, "Chin", Vector3(0, -0.55, 0.05), Vector3(1.85, 0.15, 0.17), VIOLET)
	for side in [-1.0, 1.0]:
		_box(_upper, "InkHorn%s" % str(side), Vector3(side * 1.06, 0.61, 0.02), Vector3(0.19, 0.67, 0.18), INK).rotation.z = side * -0.36
		_box(_lower, "TornPage%s" % str(side), Vector3(side * 1.04, -0.55, 0.02), Vector3(0.22, 0.34, 0.13), PAPER).rotation.z = side * 0.38
		_box(_upper, "CheekBlade%s" % str(side), Vector3(side * 1.36, 0.02, 0.01), Vector3(0.23, 0.82, 0.19), INK).rotation.z = side * 0.53
		_box(_lower, "LowerFang%s" % str(side), Vector3(side * 1.12, 0.15, 0.08), Vector3(0.23, 0.7, 0.16), PAPER).rotation.z = side * -0.18
		_box(_upper, "Eye%s" % str(side), Vector3(side * 0.72, 0.4, 0.22), Vector3(0.25, 0.075, 0.035), GOLD).rotation.z = side * -0.35
	for i in 7:
		var x := -0.86 + float(i) * 0.285
		_box(_upper, "UpperPageTooth%d" % i, Vector3(x, -0.19, 0.07), Vector3(0.17, 0.49 + 0.12 * float(i % 2), 0.17), PAPER).rotation.z = (0.14 if i % 2 == 0 else -0.14)
		_box(_lower, "LowerPageTooth%d" % i, Vector3(x + 0.08, 0.19, 0.07), Vector3(0.17, 0.47, 0.17), PAPER).rotation.z = (-0.14 if i % 2 == 0 else 0.14)
	_box(self, "Spine", Vector3(0, 0, -0.13), Vector3(2.4, 0.12, 0.15), VIOLET)
	_box(_upper, "Seal", Vector3(0, 0.42, 0.13), Vector3(0.3, 0.22, 0.05), GOLD).rotation.z = PI * 0.25
	_burst = Node3D.new()
	_burst.name = "InkImpact"
	_burst.visible = false
	_burst.position.z = 0.48
	add_child(_burst)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		_box(_burst, "InkStroke%d" % i, Vector3(cos(angle) * 0.9, sin(angle) * 0.85, 0), Vector3(0.13, 0.72, 0.06), VIOLET if i % 3 == 0 else INK).rotation.z = angle - PI * 0.5
	_paper = Node3D.new()
	_paper.name = "ImpactPages"
	_paper.visible = false
	_paper.position.z = 0.54
	add_child(_paper)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		_box(_paper, "PageFragment%d" % i, Vector3(cos(angle) * 1.1, sin(angle) * 1.1, 0), Vector3(0.23, 0.3, 0.025), PAPER).rotation.z = angle + 0.3
	if summoning:
		_escape_pages = Node3D.new()
		_escape_pages.name = "EscapingPages"
		add_child(_escape_pages)
		for i in 4:
			var angle := TAU * float(i) / 4.0
			_box(_escape_pages, "Page%d" % i, Vector3(cos(angle) * 1.3, sin(angle) * 0.9, 0.32), Vector3(0.34, 0.45, 0.025), PAPER).rotation.z = angle + 0.25
		scale = Vector3.ONE * 0.15
		_play_sound("Omen", OMEN_SFX, -12.0)

func mark_impact() -> void:
	if not _summoning:
		_impact_age = 0.0
		_burst.visible = true
		_paper.visible = true
		_play_sound("Impact", IMPACT_SFX, -6.0)

func _process(delta: float) -> void:
	_age += delta
	if _summoning:
		var t := clampf(_age / 0.38, 0.0, 1.0)
		var recoil := smoothstep(0.04, 0.34, t) * (1.0 - smoothstep(0.66, 1.0, t))
		var convulse := sin(t * TAU * 3.0) * recoil
		scale = Vector3.ONE * (0.15 + 0.22 * recoil)
		rotation.z = 0.23 * convulse
		_upper.position.y = 0.24 + 0.27 * recoil
		_lower.position.y = -0.24 - 0.27 * recoil
		_upper.rotation.z = -0.13 * convulse
		_lower.rotation.z = 0.13 * convulse
		_escape_pages.scale = Vector3.ONE * (0.6 + 0.8 * recoil)
		_escape_pages.rotation.z += delta * 4.5
		return
	var opening := 1.0 - smoothstep(0.035, 0.085, _age)
	var compression := smoothstep(0.08, 0.115, _age) * (1.0 - smoothstep(0.13, 0.2, _age))
	var comic_recoil := smoothstep(0.12, 0.2, _age) * (1.0 - smoothstep(0.26, 0.34, _age))
	var gape := 0.88 * opening + 0.25 * comic_recoil
	_upper.position.y = 0.39 + gape - 0.15 * compression
	_lower.position.y = -0.39 - gape + 0.15 * compression
	_upper.rotation.z = -0.16 * opening + 0.08 * comic_recoil
	_lower.rotation.z = 0.16 * opening - 0.08 * comic_recoil
	var arrival := smoothstep(0.0, 0.055, _age)
	var departure := 1.0 - smoothstep(0.24, 0.36, _age)
	var size := (0.35 + 0.65 * arrival) * departure
	scale = Vector3(size * (1.0 + 0.17 * compression), size * (1.0 - 0.25 * compression), size)
	rotation.z = 0.1 * sin(_age * 45.0) * comic_recoil
	position.y = 0.65 + 0.22 * smoothstep(0.25, 0.36, _age)
	if _age >= 0.085 and not _snapped:
		_snapped = true
		_play_sound("Snap", SNAP_SFX, -10.0)
	if _impact_age >= 0.0:
		_impact_age += delta
		var fade := 1.0 - smoothstep(0.08, 0.26, _impact_age)
		_burst.visible = fade > 0.01
		_paper.visible = _burst.visible
		if _burst.visible:
			_burst.scale = Vector3.ONE * (0.7 + 1.25 * (1.0 - fade))
			_paper.scale = Vector3.ONE * (1.2 + 0.8 * (1.0 - fade))
			_paper.rotation.z += delta * 3.0

func _play_sound(label: String, stream: AudioStream, volume: float) -> void:
	var player := AudioStreamPlayer3D.new()
	player.name = "Bite%sSound" % label
	player.stream = stream
	player.volume_db = volume
	player.bus = &"SFX"
	var scene := get_tree().current_scene
	if scene == null:
		add_child(player)
	else:
		scene.add_child(player)
		player.global_position = global_position
	player.finished.connect(player.queue_free)
	player.play()

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
