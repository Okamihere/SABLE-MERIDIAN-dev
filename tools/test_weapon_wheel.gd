extends SceneTree

func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()

func watchdog() -> void:
	await create_timer(12).timeout
	push_error("weapon wheel test timeout")
	quit(1)

func frames(count: int = 2) -> void:
	for i in count:
		await physics_frame
		await process_frame

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	var progress = root.get_node("Progression")
	progress.weapon_save_path = "user://test_weapon_wheel_owned.cfg"
	progress.owned_weapons.clear()
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await frames(35)
	var player = current_scene.get_node("Player")
	var hud := current_scene.get_node("HUD")
	var wheel = hud.weapon_wheel
	player.equip_staff()
	assert(wheel.equipment == player.equipment)
	assert(wheel.weapon_ids.size() == 6)
	assert(wheel.get_displayed_weapon_ids() == [&"staff"], "Only acquired staff should appear")
	assert(not wheel.visible)
	assert(player.equipment.weapon.weapon_id == &"staff")
	assert(not player.equipment.has_weapon(&"echo_blade"))
	assert(not player.equipment.request_weapon(&"echo_blade"), "Unacquired weapon cannot equip")
	for id in [&"card_daggers", &"puppet_strings", &"cane_blade", &"living_grimoire"]:
		assert(player.equipment.unlock_weapon(id), "Simulated boss pickup must grant weapon")
	assert(wheel.get_displayed_weapon_ids().size() == 5)
	assert(not wheel.get_displayed_weapon_ids().has(&"echo_blade"))
	var initial_mouse_mode := Input.mouse_mode
	key(KEY_V, true)
	await frames()
	assert(wheel.visible)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	assert(wheel.selected_index == -1)
	wheel.select_vector(Vector2(0, -100), 62.0)
	assert(wheel.selected_index == 0)
	wheel.select_vector(Vector2.RIGHT.rotated(-PI / 2.0 + deg_to_rad(38.0)) * 100.0, 62.0)
	assert(wheel.selected_index == 0, "hysteresis must hold near boundary")
	wheel.select_vector(Vector2.RIGHT.rotated(-PI / 2.0 + deg_to_rad(48.0)) * 100.0, 62.0)
	assert(wheel.selected_index == 1)
	wheel.select_vector(Vector2(1, 1), 62.0)
	assert(wheel.selected_index == -1, "center is neutral")
	key(KEY_RIGHT, true)
	await frames()
	assert(wheel.selected_index == 1)
	key(KEY_RIGHT, false)
	key(KEY_V, false)
	await frames()
	assert(not wheel.is_open() and wheel.visible, "closing animation remains visible briefly")
	await create_timer(0.23).timeout
	assert(not wheel.visible)
	assert(player.equipment.weapon.weapon_id == &"card_daggers")
	assert(root.get_node("GameManager").equipped_weapon_id == &"card_daggers")
	assert(Input.mouse_mode == initial_mouse_mode)
	key(KEY_V, true)
	await frames()
	var motion := InputEventMouseMotion.new()
	motion.position = wheel.get_global_transform_with_canvas() * (wheel.size * 0.5 + Vector2(0, -110))
	wheel._input(motion)
	await frames()
	assert(wheel.selected_index == 0, "mouse points to upper slot")
	wheel.select_vector(Vector2(110, 0), 62.0)
	await frames()
	assert(wheel._slot_energy[1] < 1.0, "rapid switch blends without snapping")
	wheel.select_vector(Vector2(0, -110), 62.0)
	key(KEY_V, false)
	await frames()
	await create_timer(0.23).timeout
	assert(player.equipment.weapon.weapon_id == &"staff")
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	shoulder.pressed = true
	Input.parse_input_event(shoulder)
	await frames()
	assert(wheel.visible, "gamepad shoulder opens wheel")
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_RIGHT_X
	axis.axis_value = 0.8
	Input.parse_input_event(axis)
	await frames()
	assert(wheel.selected_index != -1, "right stick selects")
	wheel.selected_index = 0
	shoulder.pressed = false
	Input.parse_input_event(shoulder)
	await frames()
	await create_timer(0.23).timeout
	assert(player.equipment.weapon.weapon_id == &"staff", "Gamepad confirmation keeps selected owned weapon")
	wheel.weapon_ids.append(&"")
	wheel.open_wheel()
	assert(wheel.get_displayed_weapon_ids().size() == 5, "Empty catalog entry stays hidden")
	wheel.selected_index = 5
	wheel.close_wheel(true)
	assert(player.equipment.weapon.weapon_id == &"staff", "empty slot cannot equip")
	wheel.open_wheel()
	assert(wheel.is_open() and wheel.visible, "reopen interrupts closing tween")
	key(KEY_ESCAPE, true)
	await frames()
	assert(not wheel.is_open(), "pause closes wheel")
	assert(paused, "pause menu still opens")
	await create_timer(0.23).timeout
	assert(not wheel.visible, "close animation completes while paused")
	root.get_node("PauseMenu").resume_game()
	key(KEY_ESCAPE, false)
	await frames()
	assert(hud.get_node("Root").get_child_count() == 4, "existing HUD stays intact")
	print("PASS: acquired-only wheel, transitions, fast selection, mouse, keyboard, gamepad, deadzone, hysteresis, real equipment, empty slots, HUD")
	call_deferred("quit")
