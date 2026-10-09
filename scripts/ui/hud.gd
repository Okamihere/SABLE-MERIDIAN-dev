extends CanvasLayer

## HUD permanente pequeno; eventos importantes aparecem como avisos temporários.

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_trail: ProgressBar = %HealthTrail
@onready var health_value: Label = get_node_or_null("%HealthValue") as Label
@onready var mana_bar: ProgressBar = %ManaBar
@onready var mana_trail: ProgressBar = %ManaTrail
@onready var mana_value: Label = get_node_or_null("%ManaValue") as Label
@onready var lock_indicator: Label = %LockIndicator
@onready var hit_flash: ColorRect = $Root/Vitals/HitFlash
@onready var notice: PanelContainer = $Root/Notice
@onready var notice_title: Label = %NoticeTitle
@onready var notice_detail: Label = %NoticeDetail
@onready var wall_hint: PanelContainer = $Root/WallHint
@onready var weapon_wheel = $WeaponWheel
@onready var vitals: Control = $Root/Vitals
@onready var weapons_and_skills: Sprite2D = $WeaponsAndSkills

var _player: PlayerController
var _health_tween: Tween
var _health_trail_tween: Tween
var _mana_tween: Tween
var _mana_trail_tween: Tween
var _wall_tween: Tween
var _last_mana: float = 0.0
var _last_target: Node3D
var _wall_shown: bool = false
var _wall_base_y: float = 0.0
var _notice_queue: Array[Dictionary] = []
var _notice_busy: bool = false
var _style_debug: Label
var _vitals_base_position := Vector2.ZERO
var _weapons_base_position := Vector2.ZERO
var _vitals_intro_offset := Vector2.ZERO
var _camera_sway := Vector2.ZERO
var _last_camera_rotation := Vector3.ZERO
var _sampled_camera: Camera3D

func _ready() -> void:
	get_viewport().size_changed.connect(_apply_responsive_layout)
	GameManager.player_registered.connect(_bind_player)
	GameManager.style_changed.connect(_on_style_changed)
	GameManager.debug_changed.connect(_on_debug_changed)
	Progression.upgraded.connect(_on_orb_upgraded)
	_style_debug = Label.new()
	_style_debug.name = "StyleDebug"
	_style_debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_debug.add_theme_color_override("font_color", Color(0.75, 0.94, 0.97))
	add_child(_style_debug)
	_on_style_changed(GameManager.combo_count, GameManager.style_score, GameManager.style_rank)
	_on_debug_changed(GameManager.DEBUG_COMBAT)
	_weapons_base_position = weapons_and_skills.position
	_apply_responsive_layout()
	if GameManager.player is PlayerController:
		_bind_player(GameManager.player)
	vitals.modulate.a = 0.0
	_vitals_intro_offset = Vector2(-18.0, 0.0)
	_apply_sway_position()
	var intro := create_tween().set_parallel(true)
	intro.tween_property(self, "_vitals_intro_offset", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro.tween_property(vitals, "modulate:a", 1.0, 0.35)

func _process(delta: float) -> void:
	_update_camera_sway(delta)
	_update_lock_indicator()
	_update_wall_hint()

func _update_camera_sway(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var target := Vector2.ZERO
	if camera != null:
		var rotation_now := camera.global_rotation
		if camera == _sampled_camera:
			var yaw_change := angle_difference(_last_camera_rotation.y, rotation_now.y)
			var pitch_change := angle_difference(_last_camera_rotation.x, rotation_now.x)
			# Ignore cortes bruscos de câmera; o HUD não deve saltar entre enquadramentos.
			if absf(yaw_change) < 0.3 and absf(pitch_change) < 0.3:
				target = (Vector2(-yaw_change * 4.3, pitch_change * 3.7) / maxf(delta, 0.001)).limit_length(8.0)
		_sampled_camera = camera
		_last_camera_rotation = rotation_now
	else:
		_sampled_camera = null
	_camera_sway = _camera_sway.lerp(target, 1.0 - exp(-delta * 15.0))
	_apply_sway_position()

func _apply_sway_position() -> void:
	vitals.position = _vitals_base_position + _vitals_intro_offset + _camera_sway
	weapons_and_skills.position = _weapons_base_position + _camera_sway * 0.7

func _bind_player(player: Node) -> void:
	if not (player is PlayerController):
		return
	_unbind_player()
	_player = player as PlayerController
	weapon_wheel.bind_equipment(_player.equipment)
	health_bar.max_value = _player.health.max_health
	health_bar.value = _player.health.current_health
	health_trail.max_value = health_bar.max_value
	health_trail.value = health_bar.value
	if health_value != null:
		health_value.text = "%d / %d" % [ceili(health_bar.value), ceili(health_bar.max_value)]
	mana_bar.max_value = _player.mana.max_mana
	mana_bar.value = _player.mana.current_mana
	mana_trail.max_value = mana_bar.max_value
	mana_trail.value = mana_bar.value
	_last_mana = mana_bar.value
	if mana_value != null:
		mana_value.text = "%d / %d" % [ceili(mana_bar.value), ceili(mana_bar.max_value)]
	_player.mana.changed.connect(_on_mana_changed)
	_player.health.damaged.connect(_on_player_damaged)
	_player.health.healed.connect(_on_player_healed)
	_player.health.died.connect(_on_player_died)

func _unbind_player() -> void:
	if not is_instance_valid(_player):
		return
	if weapon_wheel.visible:
		weapon_wheel.close_wheel(false)
	if _player.health.damaged.is_connected(_on_player_damaged):
		_player.health.damaged.disconnect(_on_player_damaged)
	if _player.health.healed.is_connected(_on_player_healed):
		_player.health.healed.disconnect(_on_player_healed)
	if _player.health.died.is_connected(_on_player_died):
		_player.health.died.disconnect(_on_player_died)
	if _player.mana.changed.is_connected(_on_mana_changed):
		_player.mana.changed.disconnect(_on_mana_changed)

func _on_player_damaged(_amount: float, current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_trail.max_value = maximum
	if health_value != null:
		health_value.text = "%d / %d" % [ceili(current), ceili(maximum)]
	if is_instance_valid(_health_tween):
		_health_tween.kill()
	_health_tween = create_tween()
	_health_tween.tween_property(health_bar, "value", current, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_health_trail_tween):
		_health_trail_tween.kill()
	_health_trail_tween = create_tween()
	_health_trail_tween.tween_interval(0.24)
	_health_trail_tween.tween_property(health_trail, "value", current, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hit_flash.modulate.a = 1.0
	create_tween().tween_property(hit_flash, "modulate:a", 0.0, 0.36)

func _on_player_healed(_amount: float, current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_trail.max_value = maximum
	if health_value != null:
		health_value.text = "%d / %d" % [ceili(current), ceili(maximum)]
	if is_instance_valid(_health_tween):
		_health_tween.kill()
	if is_instance_valid(_health_trail_tween):
		_health_trail_tween.kill()
	_health_tween = create_tween()
	_health_tween.tween_property(health_bar, "value", current, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	health_trail.value = current

func _on_mana_changed(current: float, maximum: float) -> void:
	mana_bar.max_value = maximum
	mana_trail.max_value = maximum
	if mana_value != null:
		mana_value.text = "%d / %d" % [ceili(current), ceili(maximum)]
	if current < _last_mana - 0.1:
		if is_instance_valid(_mana_tween):
			_mana_tween.kill()
		_mana_tween = create_tween()
		_mana_tween.tween_property(mana_bar, "value", current, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if is_instance_valid(_mana_trail_tween):
			_mana_trail_tween.kill()
		_mana_trail_tween = create_tween()
		_mana_trail_tween.tween_interval(0.16)
		_mana_trail_tween.tween_property(mana_trail, "value", current, 0.3)
	else:
		if is_instance_valid(_mana_tween):
			_mana_tween.kill()
		mana_bar.value = current
		if current >= mana_trail.value:
			mana_trail.value = current
	_last_mana = current

func _on_player_died() -> void:
	if weapon_wheel.visible:
		weapon_wheel.close_wheel(false)
	show_notice("VOCÊ CAIU", "Retornando ao início da área...", 1.7)

func _on_orb_upgraded(maximum: int) -> void:
	show_notice("ORBE ENCONTRADA", "Agora você pode saltar %d vezes entre paredes." % maximum, 3.4)

func _on_style_changed(combo: int, score: int, rank: String) -> void:
	_style_debug.text = "Combo: %d\nStyle: %d\nRank: %s" % [combo, score, rank]

func _on_debug_changed(enabled: bool) -> void:
	_style_debug.visible = enabled

## Outros sistemas também podem mostrar eventos sem criar texto permanente.
func show_notice(title: String, detail: String, duration: float = 3.0) -> void:
	_notice_queue.append({"title": title, "detail": detail, "duration": duration})
	if not _notice_busy:
		_show_next_notice()

func _show_next_notice() -> void:
	if _notice_queue.is_empty():
		_notice_busy = false
		return
	_notice_busy = true
	var item: Dictionary = _notice_queue.pop_front()
	notice_title.text = item["title"]
	notice_detail.text = item["detail"]
	_layout_notice()
	var final_position := notice.position
	notice.visible = true
	notice.modulate.a = 0.0
	notice.scale = Vector2(0.96, 0.96)
	notice.position.y -= 18.0
	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(notice, "position", final_position, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.tween_property(notice, "modulate:a", 1.0, 0.28)
	entrance.tween_property(notice, "scale", Vector2.ONE, 0.42)
	await entrance.finished
	if not is_instance_valid(notice) or not is_inside_tree():
		return
	await get_tree().create_timer(float(item["duration"])).timeout
	if not is_instance_valid(notice) or not is_inside_tree():
		return
	var exit_tween := create_tween().set_parallel(true)
	exit_tween.tween_property(notice, "position:y", final_position.y - 12.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(notice, "modulate:a", 0.0, 0.3)
	await exit_tween.finished
	if not is_instance_valid(notice) or not is_inside_tree():
		return
	notice.visible = false
	_show_next_notice()

func _update_wall_hint() -> void:
	var should_show := is_instance_valid(_player) and _player.wall_movement.gripping and not NpcInteraction.is_dialogue_active()
	if should_show == _wall_shown:
		return
	_wall_shown = should_show
	if is_instance_valid(_wall_tween):
		_wall_tween.kill()
	_wall_tween = create_tween().set_parallel(true)
	if should_show:
		wall_hint.visible = true
		wall_hint.modulate.a = 0.0
		wall_hint.position.y = _wall_base_y + 8.0
		_wall_tween.tween_property(wall_hint, "modulate:a", 1.0, 0.22)
		_wall_tween.tween_property(wall_hint, "position:y", _wall_base_y, 0.22)
	else:
		_wall_tween.tween_property(wall_hint, "modulate:a", 0.0, 0.18)
		_wall_tween.tween_property(wall_hint, "position:y", _wall_base_y + 8.0, 0.18)
		_wall_tween.finished.connect(func() -> void:
			if not _wall_shown:
				wall_hint.visible = false
		)

func _update_lock_indicator() -> void:
	var target: Node3D = _player.get_lock_target() if is_instance_valid(_player) else null
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(target) or camera == null:
		lock_indicator.visible = false
		_last_target = null
		return
	var anchor := target.global_position + Vector3.UP * 1.25
	if camera.is_position_behind(anchor):
		lock_indicator.visible = false
		return
	var screen := camera.unproject_position(anchor)
	var viewport_size := get_viewport().get_visible_rect().size
	if screen.x < 0.0 or screen.y < 0.0 or screen.x > viewport_size.x or screen.y > viewport_size.y:
		lock_indicator.visible = false
		return
	lock_indicator.position = (screen / scale - lock_indicator.size * 0.5).clamp(Vector2.ZERO, ($Root as Control).size - lock_indicator.size)
	lock_indicator.visible = true
	if target != _last_target:
		_last_target = target
		lock_indicator.scale = Vector2(0.45, 0.45)
		create_tween().tween_property(lock_indicator, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lock_indicator.modulate.a = 0.86 + 0.14 * sin(Time.get_ticks_msec() * 0.006)

func _apply_responsive_layout() -> void:
	var pixels := get_viewport().get_visible_rect().size
	if pixels.x <= 0.0 or pixels.y <= 0.0:
		return
	var factor := clampf(minf(pixels.x / 1280.0, pixels.y / 720.0), 0.75, 1.0)
	scale = Vector2.ONE * factor
	var area := pixels / factor
	var margin := 12.0 if area.x < 600.0 else 20.0
	if is_instance_valid(_style_debug):
		_style_debug.position = Vector2(area.x - margin - 170.0, margin)
		_style_debug.size = Vector2(170.0, 65.0)
	var root_control := $Root as Control
	root_control.position = Vector2.ZERO
	root_control.size = area
	weapon_wheel.size = area
	weapon_wheel.position = Vector2.ZERO
	_vitals_base_position = Vector2(margin, margin)
	vitals.size = Vector2(286.0, 110.0)
	_apply_sway_position()
	_layout_notice()
	wall_hint.size = Vector2(260.0, 40.0)
	wall_hint.position = Vector2((area.x - wall_hint.size.x) * 0.5, area.y - margin - wall_hint.size.y)
	_wall_base_y = wall_hint.position.y

func _layout_notice() -> void:
	var area := ($Root as Control).size
	if area.x <= 0.0:
		return
	var margin := 12.0 if area.x < 600.0 else 20.0
	var width := minf(520.0, area.x - margin * 2.0)
	notice.custom_minimum_size = Vector2(width, 94.0)
	notice.size = Vector2(width, 94.0)
	notice.pivot_offset = notice.size * 0.5
	var y := 142.0 if area.x < 1100.0 else margin
	notice.position = Vector2((area.x - width) * 0.5, y)
