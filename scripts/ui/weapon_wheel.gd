class_name WeaponWheel
extends Control

## Visual e navegação da roda; EquipmentComponent continua sendo a fonte de verdade.
@export var weapon_ids: Array[StringName] = [
	&"staff", &"card_daggers", &"puppet_strings",
	&"cane_blade", &"living_grimoire", &"echo_blade",
]

const INK := Color(0.025, 0.018, 0.043, 0.91)
const IVORY := Color(0.94, 0.88, 0.96)
const VIOLET := Color(0.65, 0.32, 0.94)
const GOLD := Color(0.76, 0.59, 0.39)
const MOUSE_DEADZONE := 62.0
const STICK_DEADZONE := 0.32
const ANGLE_HYSTERESIS := 0.10
const OPEN_DURATION := 0.22
const CLOSE_DURATION := 0.16

var equipment: EquipmentComponent
var _shown_ids: Array[StringName] = []
var selected_index := -1
var _previous_mouse_mode: Input.MouseMode
var _stick := Vector2.ZERO
var _is_open := false
var _open_amount := 0.0:
	set(value):
		_open_amount = clampf(value, 0.0, 1.0)
		self_modulate.a = _open_amount
		queue_redraw()
var _transition: Tween
var _slot_energy := PackedFloat32Array()
var _confirm_index := -1
var _confirm_flash := 0.0
var _pulse_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	Progression.weapon_acquired.connect(_on_weapon_acquired)

func _exit_tree() -> void:
	if visible and not get_tree().paused:
		Input.mouse_mode = _previous_mouse_mode

func bind_equipment(value: EquipmentComponent) -> void:
	if equipment != null and equipment.weapon_changed.is_connected(_on_weapon_changed):
		equipment.weapon_changed.disconnect(_on_weapon_changed)
	equipment = value
	if equipment != null and not equipment.weapon_changed.is_connected(_on_weapon_changed):
		equipment.weapon_changed.connect(_on_weapon_changed)
	_refresh_shown_ids()
	queue_redraw()

func _on_weapon_changed(_weapon: WeaponData) -> void:
	queue_redraw()

func _on_weapon_acquired(_id: StringName) -> void:
	_refresh_shown_ids()
	queue_redraw()

func _refresh_shown_ids() -> void:
	var selected_id: StringName = _shown_ids[selected_index] if selected_index >= 0 and selected_index < _shown_ids.size() else &""
	_shown_ids.clear()
	if equipment != null:
		for id in weapon_ids:
			if equipment.has_weapon(id):
				_shown_ids.append(id)
	selected_index = _shown_ids.find(selected_id) if selected_id != &"" else -1
	_slot_energy = PackedFloat32Array()
	_slot_energy.resize(_shown_ids.size())

func get_displayed_weapon_ids() -> Array[StringName]:
	return _shown_ids.duplicate()

func _process(delta: float) -> void:
	_pulse_time += delta
	var smoothing := 1.0 - exp(-delta * 17.0)
	for index in _slot_energy.size():
		var target := 1.0 if _is_open and index == selected_index else 0.0
		_slot_energy[index] = lerpf(_slot_energy[index], target, smoothing)
	_confirm_flash = maxf(0.0, _confirm_flash - delta / CLOSE_DURATION)
	queue_redraw()

func _ensure_slot_energy() -> void:
	if _slot_energy.size() != _shown_ids.size():
		_slot_energy.resize(_shown_ids.size())

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_wheel") and not event.is_echo():
		if not _is_open and _can_open():
			open_wheel()
			get_viewport().set_input_as_handled()
		return
	if not _is_open:
		return
	if event.is_action_released("weapon_wheel"):
		close_wheel(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_menu"):
		close_wheel(false)
	elif event is InputEventMouseMotion:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		select_vector(local - size * 0.5, MOUSE_DEADZONE)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_RIGHT_X:
			_stick.x = event.axis_value
		elif event.axis == JOY_AXIS_RIGHT_Y:
			_stick.y = event.axis_value
		else:
			return
		select_vector(_stick, STICK_DEADZONE)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_UP:
				step_selection(-1)
			KEY_RIGHT, KEY_DOWN:
				step_selection(1)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func _can_open() -> bool:
	return equipment != null and equipment.weapon != null and not _shown_ids.is_empty() and not get_tree().paused \
		and not NpcInteraction.is_dialogue_active() and not AreaTransition.is_travelling

func is_open() -> bool:
	return _is_open

func open_wheel() -> void:
	_refresh_shown_ids()
	if not _can_open():
		return
	if _transition != null and _transition.is_running():
		_transition.kill()
	_ensure_slot_energy()
	var reopening := visible
	_is_open = true
	selected_index = -1
	_confirm_index = -1
	_confirm_flash = 0.0
	_stick = Vector2.ZERO
	if not reopening:
		_previous_mouse_mode = Input.mouse_mode
		_open_amount = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	set_process(true)
	_transition = create_tween()
	_transition.tween_property(self, "_open_amount", 1.0, OPEN_DURATION if not reopening else 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func close_wheel(confirm: bool) -> void:
	if not _is_open:
		return
	_is_open = false
	if confirm and selected_index >= 0 and selected_index < _shown_ids.size():
		var id := _shown_ids[selected_index]
		if equipment.has_weapon(id):
			if equipment.request_weapon(id):
				_confirm_index = selected_index
				_confirm_flash = 1.0
	if not get_tree().paused:
		Input.mouse_mode = _previous_mouse_mode
	if _transition != null and _transition.is_running():
		_transition.kill()
	_transition = create_tween()
	_transition.tween_property(self, "_open_amount", 0.0, CLOSE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_transition.finished.connect(_finish_close)

func _finish_close() -> void:
	if _is_open:
		return
	visible = false
	set_process(false)
	_confirm_index = -1

func step_selection(direction: int) -> void:
	if _shown_ids.is_empty():
		return
	if selected_index < 0:
		selected_index = _equipped_index()
	selected_index = posmod(selected_index + direction, _shown_ids.size())
	queue_redraw()

func select_vector(direction: Vector2, deadzone: float) -> void:
	if direction.length() < deadzone or _shown_ids.is_empty():
		if selected_index != -1:
			selected_index = -1
			queue_redraw()
		return
	var step := TAU / float(_shown_ids.size())
	var angle := wrapf(direction.angle() + PI * 0.5, 0.0, TAU)
	var candidate := int(floor((angle + step * 0.5) / step)) % _shown_ids.size()
	if selected_index >= 0 and candidate != selected_index:
		var old_center := float(selected_index) * step
		var distance := absf(wrapf(angle - old_center + PI, 0.0, TAU) - PI)
		if distance < step * 0.5 + ANGLE_HYSTERESIS:
			return
	if candidate != selected_index:
		selected_index = candidate
		queue_redraw()

func _equipped_index() -> int:
	return _shown_ids.find(equipment.weapon.weapon_id) if equipment != null and equipment.weapon != null else -1

func _draw() -> void:
	if not visible or _shown_ids.is_empty():
		return
	_ensure_slot_energy()
	var center := size * 0.5
	var radius := minf(178.0, size.y * 0.29)
	var inner := radius * 0.36
	var count := _shown_ids.size()
	var step := TAU / float(count)
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.009, 0.024, 0.48))
	var visual_scale := lerpf(0.89, 1.0, 1.0 - pow(1.0 - _open_amount, 3.0))
	draw_set_transform(center * (1.0 - visual_scale), 0.0, Vector2.ONE * visual_scale)
	draw_circle(center, radius + 36.0, Color(0.18, 0.075, 0.27, 0.11))
	draw_circle(center, radius + 29.0, Color(0.12, 0.055, 0.19, 0.20))
	draw_arc(center, radius + 20.0, 0.0, TAU, 96, GOLD.darkened(0.55), 1.0, true)
	for index in count:
		var id := _shown_ids[index]
		var data := equipment.WEAPONS.get(id) as WeaponData if equipment != null else null
		var available := data != null and equipment.has_weapon(id)
		var active := index == _equipped_index()
		var energy := _slot_energy[index]
		var pulse := energy * (0.83 + 0.17 * sin(_pulse_time * 4.0))
		var confirm_glow := _confirm_flash if index == _confirm_index else 0.0
		var reveal := clampf((_open_amount - float(index) * 0.025) * 1.45, 0.0, 1.0)
		reveal = 1.0 - pow(1.0 - reveal, 2.0)
		var angle := -PI * 0.5 + float(index) * step
		var from := angle - step * 0.5 + 0.017
		var to := angle + step * 0.5 - 0.017
		var outer := lerpf(inner + 8.0, radius, reveal)
		if energy > 0.01 or confirm_glow > 0.01:
			var glow := pulse + confirm_glow * 0.8
			_draw_sector(center, inner - 7.0, outer + 18.0, from, to, Color(0.51, 0.15, 0.85, 0.10 * glow))
			_draw_sector(center, inner - 4.0, outer + 10.0, from, to, Color(0.70, 0.32, 1.0, 0.17 * glow))
		var fill := INK.lerp(Color(0.31, 0.115, 0.46, 0.97), energy)
		if not available:
			fill = Color(0.025, 0.025, 0.04, 0.79).lerp(Color(0.16, 0.08, 0.23, 0.89), energy * 0.7)
		fill.a *= reveal
		_draw_sector(center, inner, outer, from, to, fill)
		var edge := (GOLD.darkened(0.26) if active else Color(0.38, 0.30, 0.45, 0.60)).lerp(VIOLET, energy)
		edge.a *= reveal
		draw_arc(center, outer, from, to, 18, edge, 1.0 + energy * 2.2, true)
		if energy > 0.01:
			draw_arc(center, outer + 5.0, from, to, 18, Color(0.75, 0.36, 1.0, pulse * 0.42), 4.0, true)
		if confirm_glow > 0.01:
			draw_arc(center, outer + 8.0, from, to, 18, Color(0.95, 0.78, 1.0, confirm_glow * 0.75), 5.0, true)
		if active:
			draw_arc(center, inner + 7.0, from + 0.04, to - 0.04, 14, GOLD * Color(1, 1, 1, reveal), 2.0, true)
		var icon_pos := center + Vector2.RIGHT.rotated(angle) * ((inner + outer) * 0.55 + energy * 4.0)
		if energy > 0.01:
			draw_circle(icon_pos, 33.0, Color(0.64, 0.26, 0.95, 0.07 * pulse))
			draw_circle(icon_pos, 24.0, Color(0.72, 0.38, 1.0, 0.10 * pulse))
		var icon_color := IVORY if available else Color(0.47, 0.43, 0.51)
		icon_color = icon_color.lerp(Color.WHITE, energy * 0.28)
		icon_color.a *= reveal
		_draw_icon(id, icon_pos, icon_color, energy > 0.35)
		if not available and reveal > 0.0:
			draw_line(icon_pos + Vector2(-12, 13), icon_pos + Vector2(12, -13), Color(0.68, 0.43, 0.55, reveal), 2.0, true)
	draw_circle(center, inner + 4.0, Color(0.54, 0.31, 0.72, 0.40))
	draw_circle(center, inner, Color(0.035, 0.025, 0.065, 0.98))
	draw_arc(center, inner - 6.0, 0.0, TAU, 60, GOLD.darkened(0.25), 1.2, true)
	_draw_center_mark(center)
	var shown := selected_index if selected_index >= 0 else _equipped_index()
	if shown >= 0:
		var selected_id := _shown_ids[shown]
		var selected_data := equipment.WEAPONS.get(selected_id) as WeaponData
		var name_text := selected_data.display_name.to_upper() if selected_data != null else "SLOT VAZIO"
		var state_text := "EQUIPADA" if shown == _equipped_index() else ("SOLTE PARA EQUIPAR" if equipment.has_weapon(selected_id) else "BLOQUEADA")
		draw_string(font, center + Vector2(-220, radius + 47), name_text, HORIZONTAL_ALIGNMENT_CENTER, 440, 22, IVORY)
		draw_string(font, center + Vector2(-220, radius + 69), state_text, HORIZONTAL_ALIGNMENT_CENTER, 440, 12, VIOLET if equipment.has_weapon(selected_id) else GOLD)
	draw_string(font, center + Vector2(-220, -radius - 32), "ARSENAL  /  SABLE MERIDIAN", HORIZONTAL_ALIGNMENT_CENTER, 440, 12, GOLD)

func _draw_sector(center: Vector2, inner: float, outer: float, from: float, to: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 19:
		points.append(center + Vector2.RIGHT.rotated(lerpf(from, to, float(i) / 18.0)) * outer)
	for i in 19:
		points.append(center + Vector2.RIGHT.rotated(lerpf(to, from, float(i) / 18.0)) * inner)
	draw_colored_polygon(points, color)

func _draw_center_mark(center: Vector2) -> void:
	var top := center + Vector2(0, -19)
	draw_colored_polygon(PackedVector2Array([top, center + Vector2(12, 0), center + Vector2(0, 19), center + Vector2(-12, 0)]), GOLD)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -13), center + Vector2(8, 0), center + Vector2(0, 13), center + Vector2(-8, 0)]), INK)
	draw_circle(center, 3.0, VIOLET)

func _draw_icon(id: StringName, at: Vector2, color: Color, selected: bool) -> void:
	var weight := 2.8 if selected else 2.2
	var accent := VIOLET
	accent.a *= color.a
	match id:
		&"staff":
			draw_line(at + Vector2(-12, 22), at + Vector2(11, -18), color, weight, true)
			draw_arc(at + Vector2(13, -19), 8, 0.25, TAU - 0.25, 20, color, weight, true)
			draw_circle(at + Vector2(13, -19), 3, accent)
		&"card_daggers":
			for side: float in [-1.0, 1.0]:
				var x: float = side * 10.0
				draw_line(at + Vector2(x - side * 5, 17), at + Vector2(x + side * 5, -18), color, weight, true)
				draw_line(at + Vector2(x - side * 9, 7), at + Vector2(x + side * 4, 11), color, weight, true)
		&"puppet_strings":
			draw_line(at + Vector2(-18, -18), at + Vector2(18, -18), color, weight, true)
			for x: float in [-12.0, 0.0, 12.0]:
				draw_line(at + Vector2(x, -18), at + Vector2(x, 12), color, 1.4, true)
			draw_circle(at + Vector2(0, 16), 5, color)
		&"cane_blade":
			draw_arc(at + Vector2(9, -15), 9, PI, TAU, 14, color, weight, true)
			draw_line(at + Vector2(0, -15), at + Vector2(-8, 21), color, weight, true)
			draw_line(at + Vector2(-8, 21), at + Vector2(-3, 15), color, weight, true)
		&"living_grimoire":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-19, -15), at + Vector2(-2, -11), at + Vector2(-2, 18), at + Vector2(-19, 13)]), color)
			draw_colored_polygon(PackedVector2Array([at + Vector2(19, -15), at + Vector2(2, -11), at + Vector2(2, 18), at + Vector2(19, 13)]), color)
			draw_circle(at, 3, accent)
		&"echo_blade":
			draw_line(at + Vector2(-15, 19), at + Vector2(12, -17), color, weight, true)
			draw_line(at + Vector2(-10, 8), at + Vector2(0, 15), color, weight, true)
			draw_arc(at + Vector2(1, -1), 21, -1.35, 0.3, 18, accent, 1.6, true)
		_:
			draw_circle(at, 10, color, false, weight, true)
