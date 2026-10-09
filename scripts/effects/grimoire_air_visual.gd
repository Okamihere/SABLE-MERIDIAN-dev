extends Node3D

## Silhuetas de invocação aérea do Grimório. Dano e alcance seguem as hitboxes do jogador.
const PAPER := Color(0.78, 0.68, 0.53)
const INK := Color(0.07, 0.025, 0.11)
const VIOLET := Color(0.47, 0.25, 0.67)
const GOLD := Color(0.72, 0.44, 0.18)
const FOLD_SFX := preload("res://assets/audio/sfx/MI_SFX 11.wav")
const SWEEP_SFX := preload("res://assets/audio/sfx/MI_SFX 25.wav")
const DROP_SFX := preload("res://assets/audio/sfx/MI_SFX 30.wav")
const IMPACT_SFX := preload("res://assets/audio/sfx/MI_SFX 42.wav")

var _caster: PlayerController
var _attack: AttackData
var _heavy := false
var _second_cut := false
var _age := 0.0
var _sweep_played := false
var _impact_played := false
var _leaving := false
var _left: Node3D
var _right: Node3D
var _blade: Node3D
var _mask: Node3D
var _trails: Array[Node3D] = []
var _materials: Dictionary = {}

func configure(caster: PlayerController, attack: AttackData) -> void:
	_caster = caster
	_attack = attack
	_heavy = attack.attack_id == &"grimoire_air_heavy"
	_second_cut = not _heavy and caster.combat._grimoire_air_count == 2
	if _heavy:
		_curtain()
	else:
		_winged_mask()
	var hitbox: HitboxComponent = caster.combat._active_hitbox
	if hitbox != null:
		hitbox.hit_landed.connect(_on_hit_landed)
	_play_sound(FOLD_SFX, -15.0 if _heavy else -18.0, caster.global_position)

func _process(delta: float) -> void:
	if not is_instance_valid(_caster) or _caster.combat._current_attack != _attack:
		_fade_out()
		return
	_age += delta
	var forward := _caster.global_basis.z.normalized()
	var origin := _caster.global_position + Vector3.UP * 1.25
	# Mantém a invocação acima da silhueta do inimigo, inclusive em combate vertical.
	var desired := _caster.global_position + Vector3.UP * (1.92 if _heavy else 2.18) + forward * (1.8 if _heavy else 2.0)
	var query := PhysicsRayQueryParameters3D.create(origin, desired, 1)
	query.exclude = [_caster.get_rid()]
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	global_position = wall.position - forward * 0.25 if not wall.is_empty() else desired
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		look_at(camera.global_position, Vector3.UP, true)
	var total := _attack.startup + _attack.active + _attack.recovery
	var t := clampf(_age / total, 0.0, 1.0)
	var strike := _attack.startup / total
	var fade := 1.0 - smoothstep(0.76, 1.0, t)
	if not _sweep_played and t >= strike:
		_sweep_played = true
		_play_sound(DROP_SFX if _heavy else SWEEP_SFX, -12.0 if _heavy else -16.0, global_position)
	if _heavy:
		var fall := smoothstep(strike * 0.78, strike + 0.23, t)
		_blade.position.y = lerpf(1.24, -0.57, fall) + 0.11 * sin(PI * smoothstep(0.57, 0.81, t))
		_blade.rotation.z = 0.1 * sin(t * TAU * 3.0) * (1.0 - fall) - 0.11 * sin(PI * smoothstep(strike, strike + 0.27, t))
		_blade.scale = Vector3(0.64 + 0.36 * smoothstep(0.05, strike, t), 1.0 - 0.2 * sin(PI * smoothstep(strike, strike + 0.3, t)), 1.0)
		_mask.scale = Vector3.ONE * (1.0 + 0.28 * sin(PI * smoothstep(strike, strike + 0.28, t)))
		rotation.z = sin(t * TAU * 2.0) * 0.055 * fade
	else:
		var open := smoothstep(0.0, strike * 0.7, t)
		var slash := smoothstep(strike * 0.72, strike + 0.26, t)
		var direction := -1.0 if _second_cut else 1.0
		_left.rotation.z = direction * lerpf(-0.42 + 0.9 * open, -0.7, slash)
		_right.rotation.z = -direction * lerpf(-0.42 + 0.9 * open, -0.7, slash)
		for trail in _trails:
			trail.visible = t >= strike * 0.8 and t < strike + 0.43
			trail.scale.x = 0.45 + 0.55 * (1.0 - smoothstep(strike + 0.05, strike + 0.43, t))
		rotation.z = direction * sin(PI * slash) * 0.15
	scale = Vector3.ONE * minf(1.0, _age / 0.045) * fade

func _fade_out() -> void:
	if _leaving:
		return
	_leaving = true
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.03).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)

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
		for feather in 3:
			var length := 0.96 - feather * 0.15
			_box(wing, "LivingPage%d" % feather, Vector3(side * (0.31 + length * 0.36), 0.29 - feather * 0.22, feather * 0.018), Vector3(length, 0.22, 0.035), PAPER).rotation.z = side * (0.32 - feather * 0.24)
			_box(wing, "InkQuill%d" % feather, Vector3(side * (0.79 - feather * 0.09), 0.18 - feather * 0.22, 0.035), Vector3(0.26, 0.045, 0.05), INK).rotation.z = side * (0.32 - feather * 0.24)
		var trail := Node3D.new()
		trail.name = "ShortInkAndPaperTrail"
		wing.add_child(trail)
		_box(trail, "InkCut", Vector3(side * 1.05, -0.27, -0.05), Vector3(0.5, 0.055, 0.025), VIOLET).rotation.z = -side * 0.44
		_box(trail, "PaperCut", Vector3(side * 0.8, -0.37, -0.07), Vector3(0.32, 0.04, 0.025), PAPER).rotation.z = -side * 0.44
		trail.visible = false
		_trails.append(trail)
	_box(self, "InkMask", Vector3(0, 0.09, 0.07), Vector3(0.36, 0.38, 0.12), INK)
	_box(self, "PaperFace", Vector3(0, 0.1, 0.15), Vector3(0.23, 0.27, 0.035), PAPER)
	_box(self, "VioletGrin", Vector3(0, -0.015, 0.18), Vector3(0.17, 0.045, 0.025), VIOLET)
	for side in [-1.0, 1.0]:
		_box(self, "Horn", Vector3(side * 0.16, 0.34, 0.08), Vector3(0.08, 0.22, 0.06), INK).rotation.z = -side * 0.45

func _curtain() -> void:
	for side in [-1.0, 1.0]:
		_box(self, "CurtainPost", Vector3(side * 0.94, 0.17, 0), Vector3(0.11, 1.5, 0.14), INK)
		_box(self, "TornValance", Vector3(side * 0.55, 0.89, 0), Vector3(0.52, 0.24, 0.06), PAPER).rotation.z = side * 0.2
	_box(self, "GildedRail", Vector3(0, 0.98, 0), Vector3(2.0, 0.12, 0.16), GOLD)
	_blade = Node3D.new()
	_blade.name = "FallingInkCurtain"
	add_child(_blade)
	for i in 5:
		var x := (float(i) - 2.0) * 0.37
		_box(_blade, "RaggedInk%d" % i, Vector3(x, -0.07, 0), Vector3(0.27, 0.82 + float(i % 2) * 0.25, 0.06), INK)
		_box(_blade, "PaperTooth%d" % i, Vector3(x, -0.48 - float(i % 2) * 0.12, 0.045), Vector3(0.24, 0.19, 0.04), PAPER).rotation.z = (-1.0 if i % 2 else 1.0) * 0.22
	for side in [-1.0, 1.0]:
		_box(_blade, "InkHorn", Vector3(side * 0.72, 0.56, 0.06), Vector3(0.17, 0.6, 0.05), INK).rotation.z = -side * 0.48
		_box(_blade, "PaperFang", Vector3(side * 0.23, -0.25, 0.12), Vector3(0.13, 0.37, 0.035), PAPER).rotation.z = -side * 0.15
	_mask = Node3D.new()
	_mask.name = "CurtainMaw"
	_blade.add_child(_mask)
	_box(_mask, "Face", Vector3(0, 0.1, 0.11), Vector3(0.44, 0.3, 0.06), VIOLET)
	_box(_mask, "Maw", Vector3(0, -0.1, 0.15), Vector3(0.3, 0.11, 0.05), INK)
	for side in [-1.0, 1.0]:
		_box(_mask, "Eye", Vector3(side * 0.12, 0.16, 0.16), Vector3(0.06, 0.05, 0.03), PAPER)

func _on_hit_landed(hurtbox: HurtboxComponent, hitbox: HitboxComponent) -> void:
	if _impact_played or not is_instance_valid(_caster) or _caster.combat._current_attack != _attack or hitbox.attack_id != _attack.attack_id:
		return
	_impact_played = true
	_spawn_impact(hurtbox.global_position)
	_play_sound(IMPACT_SFX, -8.0 if _heavy else -13.0, hurtbox.global_position)

func _spawn_impact(at: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var burst := Node3D.new()
	burst.name = "AirCurtainImpact" if _heavy else "AirPageImpact"
	scene.add_child(burst)
	var camera := get_viewport().get_camera_3d()
	burst.global_position = at + Vector3.UP * (0.58 if _heavy else 0.32)
	if camera != null and burst.global_position.distance_squared_to(camera.global_position) > 0.01:
		# Sai da silhueta do alvo sem deslocar o ponto de dano ou a hitbox.
		burst.global_position += camera.global_basis.x * (0.43 if _heavy else 0.26)
		burst.global_position += (camera.global_position - burst.global_position).normalized() * 0.34
		burst.look_at(camera.global_position, Vector3.UP, true)
	_box(burst, "InkCompression", Vector3.ZERO, Vector3(0.54 if _heavy else 0.31, 0.54 if _heavy else 0.31, 0.03), VIOLET).rotation.z = PI * 0.25
	_box(burst, "PaperFlash", Vector3(0, 0, 0.04), Vector3(0.32 if _heavy else 0.19, 0.32 if _heavy else 0.19, 0.025), PAPER).rotation.z = PI * 0.25
	var count := 8 if _heavy else 5
	for i in count:
		var angle := TAU * float(i) / float(count)
		var radius := 1.0 if _heavy else 0.55
		_box(burst, "InkSplinter%d" % i, Vector3(cos(angle) * radius, sin(angle) * radius, 0), Vector3(0.065, 0.42 if _heavy else 0.25, 0.025), INK if i % 2 else VIOLET).rotation.z = angle - PI * 0.5
		if i % 2 == 0:
			_box(burst, "PaperShard%d" % i, Vector3(cos(angle) * radius * 1.25, sin(angle) * radius * 1.25, 0.03), Vector3(0.12, 0.19, 0.02), PAPER).rotation.z = angle
	var tween := burst.create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * (1.4 if _heavy else 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "scale", Vector3.ZERO, 0.13)
	tween.finished.connect(burst.queue_free)

func _play_sound(stream: AudioStream, volume: float, at: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "GrimoireAirSound"
	player.stream = stream
	player.volume_db = volume
	player.bus = &"SFX"
	scene.add_child(player)
	player.global_position = at
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
