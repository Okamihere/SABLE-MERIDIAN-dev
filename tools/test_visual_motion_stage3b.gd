extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(25.0).timeout
	push_error("Visual motion stage 3B test timed out")
	quit(1)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _run() -> void:
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await _frames(50)
	var player = current_scene.get_node("Player")
	var display = player.weapon_display
	var sprite = player.get_node("DirectionalSprite")
	display.show_weapon(&"")
	assert(player.is_on_floor() and display._equipped == &"", "Visual motion must work with no weapon shown")
	assert(absf(display._motion_offset.y) < 0.02 and absf(display._motion_roll) < 0.01)
	Input.action_press("move_right")
	await _frames(18)
	var right_roll: float = display._motion_roll
	assert(absf(right_roll) > 0.008, "Ground movement must produce a subtle screen-space lean")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _frames(22)
	assert(display._motion_roll * right_roll < 0.0, "Changing direction must reverse the visual lean")
	Input.action_release("move_left")
	await _frames(25)
	assert(absf(display._motion_roll) < 0.01, "Movement lean must return to neutral")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	assert(not player.is_on_floor() and display._motion_scale.y > 1.0, "Ascent must stretch the sprite subtly")
	var saw_fall := false
	var saw_landing := false
	for index in 70:
		await _frames(1)
		if not player.is_on_floor() and player.velocity.y < -1.0 and display._motion_scale.y < 1.0:
			saw_fall = true
		if player.is_on_floor() and display._landing_time > 0.0 and display._motion_scale.y < 1.0:
			saw_landing = true
	assert(saw_fall and saw_landing, "Fall and landing must each have a distinct visual response")
	await _frames(24)
	assert(absf(display._motion_scale.y - 1.0) < 0.01 and absf(display._motion_offset.y) < 0.02, "Landing must settle to the base pose")
	player._dodge_cooldown_left = 0.0
	Input.action_press("move_right")
	Input.action_press("dodge")
	await _frames(3)
	Input.action_release("dodge")
	assert(player.state_machine.state == PlayerStateMachine.State.DODGE and absf(display._motion_roll) > 0.02, "Dash must have a restrained lean")
	Input.action_release("move_right")
	await _frames(32)
	assert(absf(display._motion_roll) < 0.01 and absf(display._motion_scale.y - 1.0) < 0.01, "Dash pose must recover")
	player.equip_staff()
	player.combat._start_attack(player.combat.LIGHT_1, 1)
	await _frames(5)
	assert(absf(display._motion_roll) < 0.01, "Attack pose must take priority over locomotion lean")
	player.combat._hold_impact_visuals(0.05)
	assert(not display.is_processing() and not sprite.is_processing(), "Hitstop must pause sprite and weapon presentation together")
	var frozen_position: Vector3 = sprite.position
	await _frames(2)
	assert(sprite.position.is_equal_approx(frozen_position), "Visual pose must remain fixed during hitstop")
	await create_timer(0.06, true, false, true).timeout
	assert(display.is_processing() and sprite.is_processing(), "Hitstop must restore visual processing")
	player.combat.cancel_attack()
	display.play_skill(&"cursed_deck", 0.25)
	await _frames(5)
	assert(display._action_kind == &"skill" and absf(display._motion_roll) < 0.01, "Skill pose must take priority over locomotion lean")
	display.stop_action()
	var wheel = current_scene.get_node("HUD").weapon_wheel
	wheel.open_wheel()
	await _frames(5)
	assert(wheel.is_open() and display.is_processing(), "Weapon wheel must not suspend visual updates")
	wheel.close_wheel(false)
	print("PASS: unarmed idle, direction reversal, jump/fall/landing, dash recovery, attack/skill priority, hitstop sync, wheel")
	quit(0)
