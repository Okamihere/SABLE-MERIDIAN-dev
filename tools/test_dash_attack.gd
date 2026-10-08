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
	print("DASH ATTACK PASS: golpes leve e pesado, deslocamento e transições")
	quit(0)
