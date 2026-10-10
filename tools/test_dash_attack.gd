extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

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
	Input.action_press("dodge")
	await _frames(1)
	Input.action_release("dodge")
	assert(player.state_machine.state == PlayerStateMachine.State.DODGE)
	Input.action_press("heavy_attack")
	await _frames(1)
	Input.action_release("heavy_attack")
	assert(player.combat.is_attacking(), "Golpe pesado deve começar durante o dash")
	assert(player.state_machine.state == PlayerStateMachine.State.DODGE, "Ataque não deve interromper o dash")
	assert(player.weapon_display._action_kind == &"heavy", "Visual do golpe deve continuar durante o dash")
	var dash_position: Vector3 = player.global_position
	await _frames(6)
	assert(player.state_machine.state == PlayerStateMachine.State.DODGE)
	assert(player.global_position.distance_to(dash_position) > 0.5, "Dash deve manter deslocamento durante o ataque")
	assert(player._is_invulnerable(), "Ataque não deve remover a janela de invulnerabilidade do dash")
	await _frames(14)
	assert(player.state_machine.state == PlayerStateMachine.State.ATTACK, "Ataque deve continuar após o dash")
	await _frames(30)
	assert(not player.combat.is_attacking(), "Golpe pesado deve terminar normalmente")
	player._dodge_cooldown_left = 0.0
	Input.action_press("dodge")
	await _frames(1)
	Input.action_release("dodge")
	Input.action_press("light_attack")
	await _frames(1)
	Input.action_release("light_attack")
	assert(player.combat.is_attacking() and player.state_machine.state == PlayerStateMachine.State.DODGE, "Golpe leve deve começar durante o dash")
	await _frames(24)
	assert(player.state_machine.state != PlayerStateMachine.State.DODGE, "Dash deve encerrar após o golpe leve")
	await _frames(30)
	assert(not player.combat.is_attacking() and player.is_on_floor())
	var test_origin: Vector3 = player.global_position
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	var normal_start: Vector3 = player.global_position
	await _frames(15)
	var normal_distance := Vector2(player.global_position.x - normal_start.x, player.global_position.z - normal_start.z).length()
	Input.action_release("move_forward")
	await _frames(45)
	assert(player.is_on_floor(), "O salto normal deve terminar antes do próximo teste")
	player.global_position = test_origin
	player.velocity = Vector3.ZERO
	player.state_machine.set_state(PlayerStateMachine.State.IDLE)
	player._dodge_cooldown_left = 0.0
	await _frames(3)
	assert(player.is_on_floor())
	Input.action_press("move_forward")
	Input.action_press("dodge")
	await _frames(2)
	Input.action_release("dodge")
	assert(player.state_machine.state == PlayerStateMachine.State.DODGE)
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	assert(player.state_machine.state == PlayerStateMachine.State.JUMP, "Pular durante o dash deve iniciar salto")
	assert(player.velocity.y > 0.0, "Pulo deve aplicar impulso vertical")
	var dash_jump_start: Vector3 = player.global_position
	var steer_direction: Vector3 = player._camera_relative_direction(Vector2.RIGHT)
	var lateral_before: float = Vector3(player.velocity.x, 0.0, player.velocity.z).dot(steer_direction)
	Input.action_release("move_forward")
	Input.action_press("move_right")
	await _frames(6)
	var lateral_after: float = Vector3(player.velocity.x, 0.0, player.velocity.z).dot(steer_direction)
	assert(lateral_after > lateral_before + 0.2, "Dash jump deve aceitar pequena correção lateral")
	assert(Vector2(player.velocity.x, player.velocity.z).length() <= player.dodge_speed + 0.01, "Correção lateral não deve aumentar a velocidade do dash")
	Input.action_release("move_right")
	Input.action_press("move_forward")
	await _frames(9)
	var dash_jump_distance := Vector2(player.global_position.x - dash_jump_start.x, player.global_position.z - dash_jump_start.z).length()
	Input.action_release("move_forward")
	assert(dash_jump_distance > normal_distance * 1.35, "Pulo durante o dash deve alcançar mais longe que pulo normal")
	print("DASH ATTACK/JUMP PASS: golpes, salto durante dash e alcance horizontal")
	quit(0)
