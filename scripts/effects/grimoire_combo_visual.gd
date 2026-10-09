extends Node3D

## Geometria cenográfica dos quatro projéteis leves. Nunca controla dano ou hitboxes.
const INK := Color(0.075, 0.025, 0.11)
const PAPER := Color(0.76, 0.68, 0.55)
const VIOLET := Color(0.53, 0.29, 0.75)
const GOLD := Color(0.68, 0.43, 0.17)
const PAGE_SFX := preload("res://assets/audio/sfx/MI_SFX 11.wav")
const HAND_SFX := preload("res://assets/audio/sfx/MI_SFX 15.wav")
const SWARM_SFX := preload("res://assets/audio/sfx/MI_SFX 26.wav")
const GUILLOTINE_SFX := preload("res://assets/audio/sfx/MI_SFX 30.wav")
const GUILLOTINE_CUE := preload("res://assets/audio/sfx/abs-popup-2-fast.wav")

var _stage := 0
var _impact := false
var _age := 0.0
var _blade: Node3D
var _trail: Node3D
var _swarm_pages: Array[MeshInstance3D] = []
var _ink_burst: Node3D
var _paper_burst: Node3D
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
		_play_sound(_stage_sound(), -7.0 if stage == 4 else -11.0)
		scale = Vector3.ONE * (1.0 if stage == 4 else 0.65)
	elif stage == 4:
		scale = Vector3.ONE
		_play_sound(GUILLOTINE_CUE, -13.0)

func _process(delta: float) -> void:
	_age += delta
	if _impact:
		var duration: float = [0.0, 0.16, 0.22, 0.24, 0.3][_stage]
		var t := clampf(_age / duration, 0.0, 1.0)
		var fade := 1.0 - smoothstep(0.75, 1.0, t)
		match _stage:
			1:
				scale = Vector3.ONE * (0.7 + 0.95 * sin(PI * t)) * fade
				rotation.z = -0.55 + 1.1 * smoothstep(0.0, 0.48, t)
			2:
				var slap := smoothstep(0.08, 0.3, t) * (1.0 - smoothstep(0.36, 0.75, t))
				scale = Vector3(1.0 + 0.38 * slap, 1.0 - 0.28 * slap, 1.0) * fade
				rotation.z = -0.62 + 0.9 * smoothstep(0.05, 0.32, t) - 0.24 * smoothstep(0.45, 0.85, t)
			3:
				scale = Vector3.ONE * (0.8 + 0.65 * sin(PI * t)) * fade
				_update_swarm(_age, 0.35 + 0.85 * t)
			4:
				var crash := smoothstep(0.28, 0.52, t) * (1.0 - smoothstep(0.58, 0.85, t))
				scale = Vector3(1.1 + 0.28 * crash, 1.1 - 0.3 * crash, 1.0) * fade
				position.y = 0.65
				_blade.position.y = lerpf(0.87, -0.48, smoothstep(0.05, 0.43, t))
				_blade.rotation.z = 0.07 * sin(t * TAU * 2.0) * (1.0 - t)
		_ink_burst.scale = Vector3.ONE * (0.65 + (1.45 if _stage == 4 else 0.75) * t) * fade
		_paper_burst.scale = Vector3.ONE * (0.55 + (1.2 if _stage == 4 else 0.75) * t) * fade
		_paper_burst.rotation.z += delta * (5.0 if _stage == 3 else 2.0)
		if t >= 1.0:
			queue_free()
		return
	match _stage:
		1:
			rotation.z = -0.4 + 0.6 * smoothstep(0.0, 0.12, _age)
			_trail.scale.x = 1.0 + 0.75 * smoothstep(0.0, 0.1, _age)
		2:
			var slap := smoothstep(0.035, 0.11, _age)
			rotation.z = -0.75 + 1.2 * slap - 0.18 * smoothstep(0.12, 0.2, _age)
			scale = Vector3(1.0 + 0.22 * slap, 1.0 - 0.15 * slap, 1.0)
		3:
			_update_swarm(_age, 0.42)
		4:
			_blade.position.y = 0.55 + 0.06 * sin(_age * 10.0)
			rotation.z = 0.035 * sin(_age * 8.0)

func _update_swarm(time: float, radius: float) -> void:
	for i in _swarm_pages.size():
		var angle := TAU * float(i) / float(_swarm_pages.size()) + time * 11.0 + 0.12 * sin(time * 19.0 + float(i))
		var page := _swarm_pages[i]
		page.position = Vector3(cos(angle) * radius, sin(angle) * radius * 0.82, 0.04 * float(i % 2))
		page.rotation.z = angle + 0.45

func _page() -> void:
	_box(self, "LivingPage", Vector3.ZERO, Vector3(0.54, 0.68, 0.035), PAPER)
	_box(self, "InkSpine", Vector3(-0.25, 0, 0.03), Vector3(0.055, 0.66, 0.025), INK)
	_box(self, "CutLine", Vector3(0.03, 0, 0.04), Vector3(0.34, 0.045, 0.025), VIOLET).rotation.z = -0.68
	_box(self, "FangedCorner", Vector3(0.21, -0.3, 0.03), Vector3(0.12, 0.1, 0.04), INK).rotation.z = -0.45
	_trail = Node3D.new()
	_trail.name = "PaperCutTrail"
	add_child(_trail)
	_box(_trail, "IvoryStreak", Vector3(-0.39, -0.07, -0.04), Vector3(0.44, 0.025, 0.025), PAPER).rotation.z = -0.68
	_box(_trail, "InkStreak", Vector3(-0.47, -0.14, -0.05), Vector3(0.39, 0.035, 0.02), INK).rotation.z = -0.68

func _hand() -> void:
	_box(self, "InkPalm", Vector3(0, 0.12, 0), Vector3(0.64, 0.52, 0.14), INK)
	_box(self, "Cuff", Vector3(0, -0.26, 0), Vector3(0.43, 0.19, 0.16), VIOLET)
	for i in 4:
		var length := 0.3 + 0.08 * sin(float(i) * 1.7)
		_box(self, "Finger%d" % i, Vector3(-0.24 + float(i) * 0.16, 0.49 + length * 0.5, 0), Vector3(0.105, length, 0.11), INK)
	_box(self, "Thumb", Vector3(-0.43, 0.05, 0), Vector3(0.13, 0.34, 0.12), INK).rotation.z = -0.65
	_box(self, "PalmMark", Vector3(0, 0.15, 0.085), Vector3(0.22, 0.18, 0.025), GOLD).rotation.z = PI * 0.25
	_box(self, "SlapArc", Vector3(-0.42, 0.05, -0.04), Vector3(0.09, 0.72, 0.035), VIOLET).rotation.z = -0.5

func _swarm() -> void:
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var page := _box(self, "CursedPage%d" % i, Vector3(cos(angle) * 0.39, sin(angle) * 0.36, 0.04 * float(i % 2)), Vector3(0.25, 0.34, 0.025), PAPER)
		page.rotation.z = angle + 0.42
		_swarm_pages.append(page)
	_box(self, "InkHeart", Vector3.ZERO, Vector3(0.19, 0.19, 0.18), INK).rotation.z = PI * 0.25
	_box(self, "ForwardQuill", Vector3(0, 0, 0.18), Vector3(0.07, 0.4, 0.04), VIOLET)

func _guillotine() -> void:
	_box(self, "LeftPost", Vector3(-0.59, 0.18, 0), Vector3(0.13, 2.0, 0.13), INK)
	_box(self, "RightPost", Vector3(0.59, 0.18, 0), Vector3(0.13, 2.0, 0.13), INK)
	_box(self, "Crown", Vector3(0, 1.23, 0), Vector3(1.46, 0.18, 0.15), GOLD)
	_blade = Node3D.new()
	_blade.name = "PaperBlade"
	_blade.position.y = 0.75
	add_child(_blade)
	_box(_blade, "IvoryBlade", Vector3.ZERO, Vector3(1.13, 0.34, 0.085), PAPER)
	_box(_blade, "InkEdge", Vector3(0, -0.2, 0.01), Vector3(1.2, 0.07, 0.105), INK)
	_box(_blade, "Seal", Vector3(0, 0.07, 0.057), Vector3(0.2, 0.17, 0.025), VIOLET).rotation.z = PI * 0.25

func _burst() -> void:
	_ink_burst = Node3D.new()
	_ink_burst.name = "InkBurst"
	_ink_burst.position.z = 0.42 if _stage == 4 else 0.18
	add_child(_ink_burst)
	_paper_burst = Node3D.new()
	_paper_burst.name = "PaperBurst"
	_paper_burst.position.z = 0.48 if _stage == 4 else 0.24
	add_child(_paper_burst)
	var count: int = [0, 3, 4, 6, 8][_stage]
	for i in count:
		var angle := TAU * float(i) / float(count)
		var radius := 1.08 if _stage == 4 else 0.65
		_box(_ink_burst, "InkStroke%d" % i, Vector3(cos(angle) * radius, sin(angle) * radius * 0.92, 0), Vector3(0.09, 0.42, 0.05), VIOLET if _stage == 4 and i % 3 == 0 else INK).rotation.z = angle - PI * 0.5
		if _stage > 1 or i == 0:
			var paper_radius := 1.08 if _stage == 4 else 0.54
			_box(_paper_burst, "PageFragment%d" % i, Vector3(cos(angle) * paper_radius, sin(angle) * paper_radius * 0.92, 0), Vector3(0.16, 0.22, 0.02), PAPER).rotation.z = angle + 0.35

func _stage_sound() -> AudioStream:
	match _stage:
		1: return PAGE_SFX
		2: return HAND_SFX
		3: return SWARM_SFX
	return GUILLOTINE_SFX

func _play_sound(stream: AudioStream, volume: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "GrimoireComboSound"
	player.stream = stream
	player.volume_db = volume
	player.bus = &"SFX"
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
