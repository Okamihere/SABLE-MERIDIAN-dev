extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(30.0).timeout
	push_error("Combat stage 2 test timed out")
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
	var combat = player.combat
	var weapon = player.equipment.weapon

	combat._start_attack(weapon.heavy, 0)
	await _frames(24)
	combat._buffer_action(&"light")
	await _frames(8)
	assert(combat._current_attack == weapon.heavy, "Heavy recovery must not be cancelled by a buffered light")
	await _frames(8)
	assert(combat._current_attack == weapon.light_chain[0], "Buffered light must start after heavy recovery")
	combat.cancel_attack()
	player.state_machine.set_state(PlayerStateMachine.State.IDLE)

	combat._start_attack(weapon.light_chain[3], 4)
	await _frames(25)
	combat._buffer_action(&"heavy")
	await _frames(8)
	assert(combat._current_attack == weapon.light_chain[3], "Finisher must retain its recovery")
	await _frames(9)
	assert(combat._current_attack == weapon.heavy, "Buffered heavy must start after finisher recovery")
	combat.cancel_attack()
	player.state_machine.set_state(PlayerStateMachine.State.IDLE)

	player._dodge_cooldown_left = 0.0
	combat._start_attack(weapon.heavy, 0)
	Input.action_press("dodge")
	await _frames(1)
	Input.action_release("dodge")
	await _frames(5)
	assert(combat.is_attacking() and player.state_machine.state != PlayerStateMachine.State.DODGE, "Early dodge must wait for the cancel window")
	await _frames(12)
	assert(not combat.is_attacking() and player.state_machine.state == PlayerStateMachine.State.DODGE, "Buffered dodge must activate when legal")
	Input.action_press("light_attack")
	await _frames(1)
	Input.action_release("light_attack")
	assert(combat.is_attacking() and player.state_machine.state == PlayerStateMachine.State.DODGE, "Attack during dash must preserve dash state")
	await _frames(35)
	assert(player.state_machine.state != PlayerStateMachine.State.DODGE and not combat.is_attacking(), "Dash and its attack must finish normally")
	Input.action_press("light_attack")
	await _frames(1)
	Input.action_release("light_attack")
	assert(combat.is_attacking(), "Attack immediately after dash must be accepted")
	combat.cancel_attack()
	player.state_machine.set_state(PlayerStateMachine.State.IDLE)
	assert(player.is_on_floor())

	var spell = weapon.skills[0]
	player.mana.current_mana = player.mana.max_mana
	combat._start_attack(weapon.light_chain[0], 1)
	var mana_before: float = player.mana.current_mana
	player._cast_spell(spell)
	assert(player.mana.current_mana == mana_before and player.spell_manager.get_cooldown_remaining(spell) == 0.0, "Zero-startup skill must respect attack cancel window")
	await _frames(8)
	assert(combat.can_cancel_to_skill())
	player._cast_spell(spell)
	assert(player.mana.current_mana < mana_before and player.spell_manager.get_cooldown_remaining(spell) > 0.0, "Legal weave must spend mana and start cooldown")
	await _frames(25)
	combat.cancel_attack()
	player.state_machine.set_state(PlayerStateMachine.State.IDLE)

	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	Input.action_press("light_attack")
	await _frames(1)
	Input.action_release("light_attack")
	assert(combat._current_attack == weapon.air_light and player.state_machine.state == PlayerStateMachine.State.AIR_ATTACK, "Rising attack must use air light")
	combat.cancel_attack()
	player.state_machine.set_state(PlayerStateMachine.State.JUMP)
	for index in 30:
		await _frames(1)
		if player.velocity.y < 0.0:
			break
	assert(not player.is_on_floor() and player.velocity.y < 0.0)
	Input.action_press("heavy_attack")
	await _frames(1)
	Input.action_release("heavy_attack")
	assert(combat._current_attack == weapon.air_heavy, "Falling attack must use air heavy")
	combat.cancel_attack()
	player.state_machine.set_state(PlayerStateMachine.State.FALL)
	await _frames(45)
	assert(player.is_on_floor())
	Input.action_press("light_attack")
	await _frames(1)
	Input.action_release("light_attack")
	assert(combat._current_attack == weapon.light_chain[0], "Attack immediately after landing must use ground light")
	Input.action_press("heavy_attack")
	await _frames(1)
	Input.action_release("heavy_attack")
	Input.action_press("light_attack")
	await _frames(1)
	Input.action_release("light_attack")
	await _frames(13)
	assert(combat._current_attack == weapon.light_chain[1], "Latest rapid command must select only one follow-up")
	await _frames(15)
	assert(combat._current_attack != weapon.light_chain[2], "Rapid inputs must not create a second hidden follow-up")
	print("PASS: heavy/finisher recovery, buffered dodge, dash attack, skill window/cost, air/landing attacks, rapid input")
	quit(0)
