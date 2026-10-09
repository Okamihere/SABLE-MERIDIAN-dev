extends Node3D

## Cenografia leve; o alcance e os acertos pertencem à hitbox persistente.
const PAPER := Color(0.76, 0.66, 0.52)
const INK := Color(0.075, 0.025, 0.11)
const VIOLET := Color(0.47, 0.25, 0.67)
const GOLD := Color(0.74, 0.45, 0.19)
const SUMMON_SFX := preload("res://assets/audio/sfx/spirit_smoke_1.mp3")
const CLAP_SFX := preload("res://assets/audio/sfx/MI_SFX 25.wav")
const LATE_SFX := preload("res://assets/audio/sfx/abs-popup-1-fast.wav")

var _age := 0.0
var _claps := 0
var _late_flash := 0.0
var _late_sound_cooldown := 0.0
var _left: Node3D
var _right: Node3D
var _seal: Node3D
var _burst: Node3D
var _paper: Node3D
var _late_burst: Node3D
var _clap_sound: AudioStreamPlayer3D
var _late_sound: AudioStreamPlayer3D
var _materials: Dictionary = {}

func configure() -> void:
	_seal = Node3D.new()
	_seal.name = "TheatreSeal"
	add_child(_seal)
	_ring(_seal, "DangerBoundary", 2.0, 0.09, INK)
	_ring(_seal, "PaperBoundary", 1.77, 0.035, PAPER)
	_ring(_seal, "InnerStage", 0.63, 0.045, VIOLET)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		_box(_seal, "PageMark%d" % i, Vector3(cos(angle) * 1.87, 0.025, sin(angle) * 1.87), Vector3(0.21, 0.025, 0.11), GOLD).rotation.y = -angle
		_box(_seal, "StageRay%d" % i, Vector3(cos(angle) * 1.18, 0.018, sin(angle) * 1.18), Vector3(0.75, 0.018, 0.025), VIOLET).rotation.y = -angle
	_left = _hand("LeftHand", -1.0)
	_right = _hand("RightHand", 1.0)
	_burst = Node3D.new()
	_burst.name = "InkClap"
	_burst.visible = false
	_burst.position.y = 1.0
	add_child(_burst)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		_box(_burst, "InkStroke%d" % i, Vector3(cos(angle) * 0.4, sin(angle) * 0.4, 0), Vector3(0.09, 0.58, 0.055), INK).rotation.z = angle - PI * 0.5
	_paper = Node3D.new()
	_paper.name = "ScatteredPages"
	_paper.visible = false
	_paper.position.y = 1.0
	add_child(_paper)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		_box(_paper, "Page%d" % i, Vector3(cos(angle) * 0.28, sin(angle) * 0.28, 0), Vector3(0.18, 0.24, 0.025), PAPER).rotation.z = angle + 0.4
	_late_burst = Node3D.new()
	_late_burst.name = "LateInkFlecks"
	_late_burst.visible = false
	add_child(_late_burst)
	for i in 5:
		var angle := TAU * float(i) / 5.0
		_box(_late_burst, "Fleck%d" % i, Vector3(cos(angle) * 0.17, sin(angle) * 0.17, 0), Vector3(0.07, 0.17, 0.04), INK).rotation.z = angle
	_sound("Summon", SUMMON_SFX, -9.0).play()
	_clap_sound = _sound("Clap", CLAP_SFX, -3.0)
	_late_sound = _sound("LateHit", LATE_SFX, -15.0)

func mark_impact(world_position: Vector3) -> void:
	# Acertos posteriores recebem um detalhe local, sem repetir o aplauso principal.
	if _age < 0.42:
		return
	_late_burst.position = to_local(world_position) + Vector3.UP * 0.25
	_late_flash = 0.15
	_late_burst.visible = true
	if _late_sound_cooldown <= 0.0:
		_late_sound.play()
		_late_sound_cooldown = 0.22

func _process(delta: float) -> void:
	_age += delta
	_late_flash = maxf(0.0, _late_flash - delta)
	_late_sound_cooldown = maxf(0.0, _late_sound_cooldown - delta)
	_seal.scale = Vector3.ONE * smoothstep(0.0, 0.12, _age) * (1.0 - smoothstep(3.23, 3.4, _age))
	_seal.rotation.y += delta * 0.11
	# Três palmas mantêm a área ameaçadora durante toda a janela de 3,4 s.
	var cycle := fposmod(_age, 1.0)
	var slam := smoothstep(0.22, 0.32, cycle)
	var release := smoothstep(0.37, 0.7, cycle)
	var anticipation := smoothstep(0.07, 0.2, cycle) * (1.0 - slam)
	var reach := slam * (1.0 - release)
	var offset := 2.47 + 0.36 * anticipation - 2.0 * reach - 0.37 * release
	var entrance := smoothstep(0.0, 0.18, _age)
	var exit := 1.0 - smoothstep(3.08, 3.4, _age)
	var size := entrance * exit
	var squash := 1.0 - 0.22 * smoothstep(0.29, 0.34, cycle) * (1.0 - smoothstep(0.37, 0.48, cycle))
	_left.position = Vector3(-offset, 0.95 - 0.34 * (1.0 - entrance) + 0.13 * anticipation, 0)
	_right.position = Vector3(offset, 0.95 - 0.34 * (1.0 - entrance) + 0.13 * anticipation, 0)
	_left.scale = Vector3(size * squash, size / maxf(squash, 0.01), size)
	_right.scale = _left.scale
	var wobble := sin((cycle - 0.4) * 24.0) * (1.0 - smoothstep(0.4, 0.9, cycle))
	_left.rotation.z = -0.23 * anticipation + 0.26 * reach - 0.12 * wobble * release
	_right.rotation.z = 0.23 * anticipation - 0.26 * reach + 0.12 * wobble * release
	var expected_claps := mini(3, int(floor(_age)) + (1 if cycle >= 0.31 else 0))
	if expected_claps > _claps:
		_claps = expected_claps
		_clap_sound.volume_db = -3.0 if _claps == 1 else -8.0
		_clap_sound.play()
	var flash := smoothstep(0.3, 0.34, cycle) * (1.0 - smoothstep(0.44, 0.61, cycle))
	_burst.visible = flash > 0.01 and _age < 3.0
	_paper.visible = _burst.visible
	if _burst.visible:
		_burst.scale = Vector3.ONE * (0.65 + 1.05 * (1.0 - flash))
		_paper.scale = Vector3.ONE * (0.55 + 1.5 * (1.0 - flash))
		_paper.rotation.z += delta * 1.8
	_late_burst.visible = _late_flash > 0.0
	if _late_burst.visible:
		_late_burst.scale = Vector3.ONE * (0.45 + 0.7 * (1.0 - _late_flash / 0.15))

func _hand(label: String, side: float) -> Node3D:
	var hand := Node3D.new()
	hand.name = label
	add_child(hand)
	_box(hand, "InkPalm", Vector3(side * 0.22, 0, 0), Vector3(0.66, 0.78, 0.2), INK)
	_box(hand, "PaperCuff", Vector3(side * 0.65, -0.08, 0), Vector3(0.36, 0.48, 0.18), PAPER)
	_box(hand, "InkWrist", Vector3(side * 0.96, -0.08, -0.02), Vector3(0.36, 0.31, 0.16), INK)
	for i in 4:
		var finger_y := -0.28 + float(i) * 0.18
		_box(hand, "PageFinger%d" % i, Vector3(-side * 0.27, finger_y, 0.02), Vector3(0.56 + 0.08 * float(i % 2), 0.12, 0.14), PAPER)
		_box(hand, "InkNail%d" % i, Vector3(-side * 0.61, finger_y, 0.03), Vector3(0.16, 0.09, 0.11), INK)
	_box(hand, "Thumb", Vector3(-side * 0.05, -0.46, 0.03), Vector3(0.35, 0.13, 0.14), PAPER).rotation.z = side * 0.48
	_box(hand, "PalmSigil", Vector3(side * 0.2, 0.05, 0.115), Vector3(0.19, 0.22, 0.03), VIOLET).rotation.z = PI * 0.25
	return hand

func _sound(label: String, stream: AudioStream, volume: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = label
	player.stream = stream
	player.volume_db = volume
	player.bus = &"SFX"
	add_child(player)
	return player

func _ring(parent: Node3D, label: String, radius: float, width: float, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width
	mesh.outer_radius = radius
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance

func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		_materials[color] = material
	return _materials[color]
