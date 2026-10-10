extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(30.0).timeout
	push_error("Movement stage 1 test timed out")
	quit(1)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _run() -> void:
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await _frames(50)
	var player = current_scene.get_node("Player")
	player.equip_staff()
	assert(player.is_on_floor())
	var origin: Vector3 = player.global_position
	var full_apex := origin.y
	Input.action_press("jump")
	for index in 70:
		if index == 22:
			Input.action_release("jump")
		await _frames(1)
		full_apex = maxf(full_apex, player.global_position.y)
	assert(player.is_on_floor() and full_apex - origin.y > 1.1 and full_apex - origin.y < 1.7, "Held jump must retain original maximum height")
	player.global_position = origin
	player.velocity = Vector3.ZERO
	await _frames(3)
	var short_apex: float = player.global_position.y
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	for index in 55:
		await _frames(1)
		short_apex = maxf(short_apex, player.global_position.y)
	assert(player.is_on_floor() and short_apex < full_apex - 0.35, "Releasing jump early must make a shorter arc")
	Input.action_press("move_right")
	await _frames(3)
	assert(Vector2(player.velocity.x, player.velocity.z).length() > 1.0, "Ground movement must respond promptly")
	await _frames(25)
	var run_velocity := Vector2(player.velocity.x, player.velocity.z).length()
	assert(run_velocity > player.move_speed and run_velocity <= player.run_speed + 0.01, "Continuous movement must reach run speed without overshoot")
	Input.action_release("move_right")
	await _frames(20)
	assert(Vector2(player.velocity.x, player.velocity.z).length() < 0.25, "Releasing movement must stop without prolonged sliding")
	player.global_position = origin
	player.velocity = Vector3.ZERO
	await _frames(3)
	Input.action_press("jump")
	await _frames(1)
	var air_start: Vector3 = player.global_position
	Input.action_press("move_right")
	await _frames(9)
	Input.action_release("move_right")
	Input.action_release("jump")
	var air_displacement := Vector2(player.global_position.x - air_start.x, player.global_position.z - air_start.z).length()
	assert(air_displacement > 0.15, "Air control must allow a deliberate lateral correction")
	assert(Vector2(player.velocity.x, player.velocity.z).length() <= player.run_speed + 0.01, "Air control must stay within the movement speed limit")
	await _frames(60)
	assert(player.is_on_floor())

	var platform := StaticBody3D.new()
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 0.3, 2.0)
	shape_node.shape = shape
	platform.add_child(shape_node)
	platform.position = origin + Vector3.UP * 10.0
	current_scene.add_child(platform)
	var top: float = platform.global_position.y + 0.15
	player.global_position = Vector3(origin.x, top + 0.2, origin.z)
	player.velocity = Vector3.ZERO
	player.state_machine.set_state(PlayerStateMachine.State.FALL)
	await _frames(20)
	assert(player.is_on_floor(), "Temporary platform must support the player")
	Input.action_press("move_right")
	var left_edge := false
	for index in 35:
		await _frames(1)
		if not player.is_on_floor():
			left_edge = true
			break
	Input.action_release("move_right")
	assert(left_edge and player._coyote_left > 0.0, "Walking off an edge must open coyote time")
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	assert(player.velocity.y > 0.0 and player._ground_jump_consumed, "Coyote jump must work once")
	var velocity_after_jump: float = player.velocity.y
	await _frames(2)
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	assert(player.velocity.y < velocity_after_jump, "Second midair jump must not reset upward velocity")
	await _frames(70)
	player.global_position = Vector3(origin.x, top + 0.2, origin.z)
	player.velocity = Vector3.ZERO
	player.state_machine.set_state(PlayerStateMachine.State.FALL)
	await _frames(20)
	assert(player.is_on_floor())
	Input.action_press("move_right")
	for index in 35:
		await _frames(1)
		if not player.is_on_floor():
			break
	Input.action_release("move_right")
	assert(not player.is_on_floor())
	await _frames(9)
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	assert(player.velocity.y <= 0.0, "Coyote time must expire without allowing a late air jump")

	player.global_position = Vector3(origin.x, top + 2.5, origin.z)
	player.velocity = Vector3(0.0, -6.0, 0.0)
	player.state_machine.set_state(PlayerStateMachine.State.FALL)
	player._ground_jump_consumed = true
	player._coyote_left = 0.0
	var near_landing := false
	for index in 30:
		await _frames(1)
		if not player.is_on_floor() and player.global_position.y < top + 0.75:
			near_landing = true
			break
	assert(near_landing, "Player must approach platform while falling")
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	var buffered_jump := false
	for index in 9:
		await _frames(1)
		if player.velocity.y > 0.0 and not player.is_on_floor():
			buffered_jump = true
			break
	assert(buffered_jump, "Jump pressed before landing must execute after contact")

	var wheel = current_scene.get_node("HUD").weapon_wheel
	wheel.open_wheel()
	assert(wheel.is_open())
	player.global_position = Vector3(origin.x, top + 2.5, origin.z)
	player._dodge_cooldown_left = 0.3
	player.velocity.y = -2.0
	var wheel_y: float = player.global_position.y
	Input.action_press("light_attack")
	await _frames(10)
	Input.action_release("light_attack")
	assert(player.global_position.y < wheel_y - 0.1, "Gravity must continue while the wheel is open")
	assert(player._dodge_cooldown_left < 0.2, "Dodge cooldown must continue while the wheel is open")
	assert(not player.combat.is_attacking(), "Mouse selection must not start an attack while the wheel is open")
	wheel.close_wheel(false)
	player._dodge_cooldown_left = 0.0
	Input.action_press("dodge")
	await _frames(1)
	Input.action_release("dodge")
	assert(player._air_dodge_used and player.state_machine.state == PlayerStateMachine.State.DODGE, "Air dodge must spend its airborne use")
	await _frames(90)
	assert(player.is_on_floor() and not player._air_dodge_used, "Landing must refill the air dodge")
	player.global_position = Vector3(origin.x, top + 2.0, origin.z)
	player.velocity = Vector3(0.0, -3.0, 0.0)
	await _frames(1)
	player.combat._start_attack(player.combat.AIR_LIGHT, 0)
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	assert(player.state_machine.state == PlayerStateMachine.State.AIR_ATTACK and player._jump_buffer_left == 0.0, "Air attacks must reject accidental buffered jumps")
	print("PASS: variable jump, ground/air control, coyote expiry, no extra jump, landing buffer, air dodge refill, air attack guard, wheel physics/combat")
	quit(0)
