extends Node3D

## Adereços 3D compactos ao lado do AnimatedSprite3D, ligados ao equipamento atual.
const STAFF := preload("res://scenes/player/mage_staff.tscn")
const BLADE := preload("res://scenes/player/card_blade.tscn")
const GRIMOIRE_MODEL := preload("res://assets/3d model/grimorio.glb")

var _props: Dictionary = {}
var _equipped: StringName = &""
var _player: PlayerController
var _sprite: AnimatedSprite3D
var _sprite_rest := Vector3.ZERO
var _action_kind: StringName = &""
var _action_id: StringName = &""
var _action_stage := 0
var _action_time := 0.0
var _action_duration := 0.0
var _settle := 0.0
var _last_pose := {"position": Vector3.ZERO, "body": Vector3.ZERO, "lean": 0.0, "tilt": 0.0, "pitch": 0.0}

const SETTLE_TIME := 0.12

# Cada linha contém preparação, contato e recuperação em coordenadas de câmera
# (lateral, altura, profundidade). O quarto golpe usa um arco orbital próprio.
const BASIC_PATHS := {
	&"staff": [
		[Vector3(-0.25, -0.35, -0.22), Vector3(0.38, 0.28, 0.55), Vector3(0.12, 0.12, -0.12)],
		[Vector3(0.4, 0.44, -0.2), Vector3(-0.48, -0.4, 0.45), Vector3(-0.08, -0.12, -0.2)],
		[Vector3(-0.52, 0.13, 0.05), Vector3(0.43, 0.58, 0.67), Vector3(0.22, -0.2, -0.12)],
	],
	&"card_daggers": [
		[Vector3(-0.45, -0.12, -0.3), Vector3(0.5, 0.18, 0.65), Vector3(0.2, 0.04, -0.2)],
		[Vector3(0.47, 0.16, -0.28), Vector3(-0.53, 0.3, 0.7), Vector3(-0.14, -0.1, -0.18)],
		[Vector3(-0.28, -0.42, -0.2), Vector3(0.25, 0.62, 0.84), Vector3(-0.18, 0.15, -0.22)],
	],
	&"puppet_strings": [
		[Vector3(-0.36, 0.4, -0.16), Vector3(0.13, 0.64, 0.76), Vector3(0.38, 0.05, -0.08)],
		[Vector3(0.23, -0.35, -0.25), Vector3(-0.44, 0.5, 0.57), Vector3(-0.12, 0.2, -0.31)],
		[Vector3(-0.3, 0.66, -0.3), Vector3(0.51, -0.16, 0.59), Vector3(0.12, -0.22, 0.04)],
	],
	&"cane_blade": [
		[Vector3(-0.54, 0.36, -0.22), Vector3(0.65, -0.27, 0.52), Vector3(0.08, -0.17, -0.2)],
		[Vector3(0.38, -0.42, -0.33), Vector3(-0.18, 0.67, 0.71), Vector3(-0.2, 0.05, -0.19)],
		[Vector3(-0.15, 0.67, -0.16), Vector3(0.04, -0.55, 0.89), Vector3(0.4, -0.16, -0.14)],
	],
	&"living_grimoire": [
		[Vector3(-0.36, -0.18, -0.23), Vector3(0.14, 0.65, 0.47), Vector3(0.31, 0.17, -0.13)],
		[Vector3(0.26, 0.54, -0.35), Vector3(-0.28, 0.22, 0.67), Vector3(-0.22, -0.12, -0.22)],
		[Vector3(-0.49, 0.16, -0.22), Vector3(0.39, 0.78, 0.62), Vector3(0.11, -0.23, -0.17)],
	],
}
const FINISHERS := {
	&"staff": Vector4(0.72, 0.15, 1.65, 0.34),
	&"card_daggers": Vector4(0.87, -0.35, -1.82, 0.15),
	&"puppet_strings": Vector4(0.98, 0.55, 1.95, 0.57),
	&"cane_blade": Vector4(0.79, -0.65, -1.7, 0.27),
	&"living_grimoire": Vector4(0.9, 0.9, 1.78, 0.69),
}
const SKILL_PATHS := {
	&"cursed_deck": [Vector3(-0.35, -0.35, -0.28), Vector3(0.15, 0.96, 0.72), Vector3(0.32, 0.2, -0.18)],
	&"staff_e": [Vector3(0.43, 0.23, -0.25), Vector3(-0.6, 0.14, 0.8), Vector3(-0.22, -0.37, -0.16)],
	&"staff_r": [Vector3(-0.28, -0.54, -0.34), Vector3(0.07, 1.2, 0.48), Vector3(0.48, 0.43, -0.2)],
	&"dagger_q": [Vector3(-0.58, -0.22, -0.4), Vector3(0.72, 0.45, 0.92), Vector3(-0.3, 0.28, -0.3)],
	&"dagger_e": [Vector3(0.48, 0.39, -0.42), Vector3(-0.71, -0.28, 0.97), Vector3(0.2, 0.46, -0.29)],
	&"dagger_r": [Vector3(-0.17, 0.72, -0.45), Vector3(0.8, 0.03, 1.03), Vector3(-0.43, -0.25, -0.15)],
	&"strings_q": [Vector3(0.22, -0.63, -0.3), Vector3(-0.37, 0.81, 0.84), Vector3(0.38, 0.31, -0.16)],
	&"strings_e": [Vector3(-0.52, 0.18, -0.27), Vector3(0.32, 1.04, 0.63), Vector3(-0.18, 0.48, -0.38)],
	&"strings_r": [Vector3(0.58, 0.55, -0.4), Vector3(-0.72, 0.95, 0.73), Vector3(0.31, -0.14, -0.29)],
	&"cane_q": [Vector3(-0.61, 0.12, -0.4), Vector3(0.21, -0.42, 1.17), Vector3(0.4, 0.19, -0.31)],
	&"cane_e": [Vector3(0.42, 0.76, -0.24), Vector3(-0.47, -0.58, 0.65), Vector3(-0.24, 0.12, -0.35)],
	&"cane_r": [Vector3(-0.45, -0.47, -0.43), Vector3(0.83, 0.58, 1.01), Vector3(-0.11, -0.43, -0.2)],
	&"grimoire_q": [Vector3(0.35, 0.56, -0.3), Vector3(-0.25, 0.87, 0.98), Vector3(-0.42, 0.14, -0.2)],
	&"grimoire_e": [Vector3(-0.3, -0.27, -0.44), Vector3(0.56, 0.72, 0.69), Vector3(0.08, 0.43, -0.34)],
	&"grimoire_r": [Vector3(0.15, -0.55, -0.37), Vector3(-0.52, 1.17, 0.81), Vector3(0.49, 0.28, -0.21)],
}
const HEAVY_PATHS := {
	&"staff": [Vector3(-0.65, -0.58, -0.48), Vector3(0.62, 0.84, 1.11), Vector3(0.16, -0.39, -0.3)],
	&"card_daggers": [Vector3(0.63, -0.52, -0.47), Vector3(-0.76, 0.72, 1.16), Vector3(-0.31, 0.21, -0.36)],
	&"puppet_strings": [Vector3(-0.71, 0.69, -0.39), Vector3(0.34, 1.12, 0.98), Vector3(0.56, -0.44, -0.3)],
	&"cane_blade": [Vector3(0.72, 0.79, -0.52), Vector3(-0.57, -0.77, 1.2), Vector3(-0.4, 0.34, -0.31)],
	&"living_grimoire": [Vector3(-0.66, -0.45, -0.49), Vector3(0.69, 1.03, 1.07), Vector3(0.24, 0.52, -0.38)],
}

func _ready() -> void:
	_player = get_parent() as PlayerController
	_sprite = get_node_or_null("../DirectionalSprite") as AnimatedSprite3D
	if _sprite != null:
		_sprite_rest = _sprite.position
	_props[&"staff"] = _make_staff()
	_props[&"card_daggers"] = _make_daggers()
	_props[&"puppet_strings"] = _make_strings()
	_props[&"cane_blade"] = _make_cane()
	_props[&"living_grimoire"] = _make_grimoire()
	for prop in _props.values():
		prop.visible = false

func show_weapon(id: StringName) -> void:
	stop_action()
	_equipped = id
	for key in _props:
		(_props[key] as Node3D).visible = key == id

func _process(delta: float) -> void:
	if _equipped == &"" or not is_instance_valid(_player):
		return
	if _action_kind != &"":
		_action_time += delta
		if _action_time >= _action_duration:
			stop_action()
	var pose := _current_pose(delta)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var toward_camera := camera.global_position - _player.global_position
	toward_camera.y = 0.0
	toward_camera = toward_camera.normalized()
	var attacking := _player.combat != null and _player.combat.is_attacking()
	var offset := right * (0.57 if attacking else 0.68) + toward_camera * (0.32 if attacking else 0.43)
	if attacking:
		offset += _player.global_basis.z * 0.28
	var travel: Vector3 = pose.position
	offset += right * travel.x + toward_camera * travel.z
	var height := 1.02 if attacking else 0.92
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var bob := 0.025 * sin(Time.get_ticks_msec() * 0.012) * clampf(speed / 7.0, 0.0, 1.0)
	var target := _player.to_local(_player.global_position + offset + Vector3.UP * (height + bob + travel.y))
	position = position.lerp(target, clampf(delta * 30.0, 0.0, 1.0))
	if _sprite != null:
		var body: Vector3 = pose.body
		var body_world := right * body.x + toward_camera * body.z + Vector3.UP * body.y
		_sprite.position = _sprite_rest + _player.global_basis.inverse() * body_world
		_sprite.rotation.z = pose.lean
	look_at(camera.global_position, Vector3.UP)
	rotate_y(PI)
	var prop := _props.get(_equipped) as Node3D
	if prop == null:
		return
	var attack_tilt := 0.0
	var idle_tilt := 0.0
	match _equipped:
		&"staff":
			attack_tilt = -0.75
			idle_tilt = -0.42
		&"card_daggers": attack_tilt = -0.48
		&"puppet_strings": attack_tilt = 0.32
		&"cane_blade": attack_tilt = -0.9
		&"living_grimoire":
			attack_tilt = 0.18
			idle_tilt = -0.18
	prop.rotation.z = lerp_angle(prop.rotation.z, (attack_tilt if attacking else idle_tilt) + pose.tilt, clampf(delta * 24.0, 0.0, 1.0))
	prop.rotation.x = pose.pitch

func play_basic(weapon_id: StringName, stage: int, duration: float) -> void:
	if stage < 1 or stage > 4 or not BASIC_PATHS.has(weapon_id):
		return
	show_weapon(weapon_id)
	_action_kind = &"basic"
	_action_id = weapon_id
	_action_stage = stage
	_action_time = 0.0
	_action_duration = maxf(duration, 0.05)
	_settle = 0.0

func play_skill(ability_id: StringName, duration: float) -> void:
	if not SKILL_PATHS.has(ability_id):
		return
	_action_kind = &"skill"
	_action_id = ability_id
	_action_stage = 0
	_action_time = 0.0
	_action_duration = maxf(duration, 0.05)
	_settle = 0.0

func play_heavy(weapon_id: StringName, duration: float) -> void:
	if not HEAVY_PATHS.has(weapon_id):
		return
	show_weapon(weapon_id)
	_action_kind = &"heavy"
	_action_id = weapon_id
	_action_stage = 0
	_action_time = 0.0
	_action_duration = maxf(duration, 0.05)
	_settle = 0.0

func resume_attack(weapon_id: StringName, stage: int, duration: float, elapsed: float, heavy: bool) -> void:
	if heavy:
		play_heavy(weapon_id, duration)
	else:
		play_basic(weapon_id, stage, duration)
	_action_time = clampf(elapsed, 0.0, _action_duration)

func stop_action() -> void:
	_action_kind = &""
	_action_time = 0.0
	_settle = SETTLE_TIME

func _current_pose(delta: float) -> Dictionary:
	if _action_kind != &"":
		_last_pose = sample_motion(_action_kind, _action_id, _action_stage, clampf(_action_time / _action_duration, 0.0, 1.0))
		return _last_pose
	if _settle > 0.0:
		_settle = maxf(0.0, _settle - delta)
		var weight := _settle / SETTLE_TIME
		return {"position": _last_pose.position * weight, "body": _last_pose.body * weight,
			"lean": _last_pose.lean * weight, "tilt": _last_pose.tilt * weight, "pitch": _last_pose.pitch * weight}
	return {"position": Vector3.ZERO, "body": Vector3.ZERO, "lean": 0.0, "tilt": 0.0, "pitch": 0.0}

## Amostra determinística usada também pelo teste das 40 trajetórias.
static func sample_motion(kind: StringName, id: StringName, stage: int, progress: float) -> Dictionary:
	var t := clampf(progress, 0.0, 1.0)
	var travel := Vector3.ZERO
	var sweep := 0.0
	if kind == &"basic" and BASIC_PATHS.has(id):
		if stage == 4:
			var finish: Vector4 = FINISHERS[id]
			# A órbita termina antes da janela de impacto (~40% da duração).
			var orbit := _ease(clampf((t - 0.02) / 0.36, 0.0, 1.0))
			var angle := finish.y + orbit * finish.z * PI
			var radius := finish.x * sin(PI * clampf(t / 0.76, 0.0, 1.0))
			var orbital := Vector3(cos(angle) * radius, finish.w * sin(PI * t), sin(angle) * radius)
			var end_angle := finish.y + finish.z * PI
			var end_radius := finish.x * sin(PI * 0.38 / 0.76)
			var orbit_end := Vector3(cos(end_angle) * end_radius, finish.w * sin(PI * 0.38), sin(end_angle) * end_radius)
			var contact := Vector3(0.12 * signf(finish.z), -0.12 + finish.w * 0.28, 1.2 + finish.x * 0.16)
			if t < 0.38:
				travel = orbital
			elif t < 0.48:
				travel = orbit_end.lerp(contact, _ease((t - 0.38) / 0.1))
			elif t < 0.72:
				travel = contact.lerp(Vector3(-contact.x * 0.8, finish.w * 0.4, -0.2), _ease((t - 0.48) / 0.24))
			else:
				travel = Vector3(-contact.x * 0.8, finish.w * 0.4, -0.2).lerp(Vector3.ZERO, _ease((t - 0.72) / 0.28))
			sweep = finish.z * sin(PI * t)
		elif stage >= 1 and stage <= 3:
			var basic: Array = BASIC_PATHS[id]
			travel = _sample_track(basic[stage - 1], t)
	elif kind == &"skill" and SKILL_PATHS.has(id):
		travel = _sample_track(SKILL_PATHS[id], t)
	elif kind == &"heavy" and HEAVY_PATHS.has(id):
		travel = _sample_track(HEAVY_PATHS[id], t)
	var body := Vector3(travel.x * 0.19, travel.y * 0.17 - 0.055 * sin(PI * t), travel.z * 0.13)
	var lean := clampf(-travel.x * 0.29 + sweep * 0.11, -0.32, 0.32)
	var tilt := clampf(-travel.x * 0.82 + travel.y * 0.45 + sweep * 0.31, -1.8, 1.8)
	var pitch := clampf(travel.z * 0.54 - travel.y * 0.2, -0.7, 0.7)
	return {"position": travel, "body": body, "lean": lean, "tilt": tilt, "pitch": pitch}

static func _sample_track(points: Array, t: float) -> Vector3:
	if t < 0.22:
		return Vector3.ZERO.lerp(points[0], _ease(t / 0.22))
	if t < 0.59:
		return (points[0] as Vector3).lerp(points[1], _ease((t - 0.22) / 0.37))
	if t < 0.82:
		return (points[1] as Vector3).lerp(points[2], _ease((t - 0.59) / 0.23))
	return (points[2] as Vector3).lerp(Vector3.ZERO, _ease((t - 0.82) / 0.18))

static func _ease(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _make_staff() -> Node3D:
	var prop := STAFF.instantiate() as Node3D
	prop.name = "EquippedStaff"
	prop.scale = Vector3.ONE * 0.73
	prop.rotation_degrees.z = -24.0
	add_child(prop)
	return prop

func _make_daggers() -> Node3D:
	var holder := Node3D.new()
	holder.name = "EquippedCardDaggers"
	add_child(holder)
	for side in [-1.0, 1.0]:
		var blade := BLADE.instantiate() as Node3D
		blade.position = Vector3(side * 0.11, 0.24, side * 0.025)
		blade.rotation_degrees.z = side * 20.0
		blade.scale = Vector3.ONE * 0.88
		holder.add_child(blade)
	return holder

func _make_strings() -> Node3D:
	var holder := Node3D.new()
	holder.name = "EquippedPuppetStrings"
	add_child(holder)
	var dark := _material(Color(0.12, 0.13, 0.28), 0.0)
	var cyan := _material(Color(0.28, 0.82, 0.92), 1.7)
	_box(holder, Vector3.ZERO, Vector3(0.61, 0.36, 0.23), dark)
	_box(holder, Vector3(0.0, 0.02, 0.14), Vector3(0.41, 0.065, 0.035), cyan)
	for side in [-1.0, 1.0]:
		_box(holder, Vector3(side * 0.22, -0.4, 0.06), Vector3(0.035, 0.7, 0.035), cyan)
		_box(holder, Vector3(side * 0.22, 0.0, 0.14), Vector3(0.07, 0.25, 0.03), cyan)
	return holder

func _make_cane() -> Node3D:
	var holder := Node3D.new()
	holder.name = "EquippedCaneBlade"
	add_child(holder)
	var dark := _material(Color(0.16, 0.11, 0.26), 0.25)
	var gold := _material(Color(0.86, 0.63, 0.28), 0.3)
	_box(holder, Vector3(0.0, 0.0, 0.0), Vector3(0.085, 1.34, 0.085), dark)
	_box(holder, Vector3(0.12, 0.68, 0.0), Vector3(0.33, 0.085, 0.085), gold)
	_box(holder, Vector3(0.27, 0.55, 0.0), Vector3(0.075, 0.27, 0.075), gold)
	_box(holder, Vector3(0.0, -0.68, 0.0), Vector3(0.1, 0.14, 0.1), gold)
	return holder

func _make_grimoire() -> Node3D:
	var holder := Node3D.new()
	holder.name = "EquippedLivingGrimoire"
	add_child(holder)
	var book := GRIMOIRE_MODEL.instantiate() as Node3D
	book.scale = Vector3.ONE * 0.2
	book.position = Vector3(0.046, 0.003, 0.031)
	holder.add_child(book)
	holder.rotation_degrees.z = -10.0
	return holder

func _material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.position = at
	parent.add_child(visual)
	return visual
