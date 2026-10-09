extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(18.0).timeout
	push_error("Grimoire air combat test timed out")
	quit(1)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	change_scene_to_file("res://scenes/levels/fixed_camera_demo.tscn")
	await _frames(60)
	var scene := current_scene
	var player = scene.get_node("Player")
	player.equip_staff()
	assert(player.equipment.request_weapon(&"living_grimoire"))
	var weapon = player.equipment.weapon
	assert(weapon.air_light.damage == 10.0 and weapon.air_heavy.damage == 24.0)
	assert(weapon.air_light.attack_id == &"grimoire_air_light" and weapon.air_heavy.attack_id == &"grimoire_air_heavy")
	scene.get_node("TrainingDummy").queue_free()
	var enemy = load("res://scenes/enemies/basic_enemy.tscn").instantiate()
	enemy.get_node("HealthComponent").max_health = 500.0
	scene.add_child(enemy)
	enemy.global_position = Vector3(0, 0.05, -1.8)
	enemy.set_physics_process(false)
	player.global_position = Vector3(0, 0.05, -4)
	player.rotation.y = 0.0
	player.lock_on.current_target = enemy
	await _frames(12)
	assert(player.is_on_floor())
	var hits: Array[float] = []
	enemy.health.damaged.connect(func(amount: float, _remaining: float, _maximum: float) -> void: hits.append(amount))
	var mana_before: float = player.mana.current_mana
	player.combat._start_attack(weapon.light_chain[0], 1)
	player.combat._buffer_action(&"light")
	await _frames(16)
	assert(player.combat._current_attack == weapon.light_chain[1])
	player.combat._buffer_action(&"heavy")
	await _frames(14)
	assert(player.combat._current_attack == weapon.launcher)
	for i in 26:
		if player.combat._attack_elapsed >= weapon.launcher.startup + weapon.launcher.active:
			break
		await _frames(1)
	assert(player.combat._current_attack == weapon.launcher and not player.is_on_floor() and player.velocity.y > 0.0, "Launcher did not lift the player")
	assert(hits.slice(0, 3) == [9.0, 11.0, 19.0], "Ground-to-launcher damage changed: %s" % str(hits))
	# Congela a altura depois de validar o impulso real, para medir a cadeia sem queda do alvo de teste.
	player.global_position = Vector3(0, 2.0, -4)
	player.velocity = Vector3.ZERO
	await _frames(2)
	assert(not player.is_on_floor())
	player.set_physics_process(false)
	enemy.global_position = Vector3(0, 2.0, -1.8)
	player.combat._buffer_action(&"light")
	for i in 14:
		if player.combat._current_attack == weapon.air_light:
			break
		await _frames(1)
	assert(player.combat._current_attack == weapon.air_light)
	await _frames(2)
	assert(player.weapon_display._action_kind == &"air" and player.weapon_display._action_stage == 1)
	assert(player.weapon_display._grimoire_ritual.visible)
	assert(not scene.find_children("GrimoireAirInvocation", "Node3D", true, false).is_empty())
	player.combat._buffer_action(&"light")
	for i in 20:
		if player.combat._grimoire_air_count == 2:
			break
		await _frames(1)
	assert(player.combat._current_attack == weapon.air_light and player.combat._grimoire_air_count == 2)
	player.combat._buffer_action(&"heavy")
	for i in 20:
		if player.combat._current_attack == weapon.air_heavy:
			break
		await _frames(1)
	assert(player.combat._current_attack == weapon.air_heavy and player.combat._grimoire_air_count == 3)
	assert(player.weapon_display._action_kind == &"air" and player.weapon_display._action_stage == 2)
	await _frames(12)
	assert(hits.slice(3) == [10.0, 10.0, 24.0], "Aerial damage or timing changed: %s" % str(hits))
	assert(is_equal_approx(player.mana.current_mana, mana_before))
	player.combat._buffer_action(&"light")
	await _frames(35)
	assert(not player.combat.is_attacking() and player.combat._grimoire_air_count == 3, "Air chain became unbounded")
	assert(scene.find_children("GrimoireAirInvocation", "Node3D", true, false).is_empty(), "Air visual was retained")
	# O limite reinicia apenas depois de tocar o chão.
	player.set_physics_process(true)
	player.global_position = Vector3(0, 0.05, -4)
	player.velocity = Vector3.ZERO
	await _frames(10)
	assert(player.is_on_floor() and player.combat._grimoire_air_count == 0)
	player.global_position = Vector3(0, 1.8, -4)
	player.velocity.y = 3.0
	await _frames(2)
	player.combat._start_attack(weapon.air_heavy, 0)
	for i in 18:
		if player.combat.can_cancel_to_skill():
			break
		await _frames(1)
	assert(player.combat.can_cancel_to_skill())
	player._cast_spell(weapon.skills[0])
	assert(player.spell_manager.is_cast_committed(), "Q did not weave into air heavy")
	await _frames(18)
	assert(player.weapon_display._action_kind == &"air" or not player.combat.is_attacking(), "Air pose did not return after Q")
	assert(is_equal_approx(player.mana.current_mana, mana_before - 14.0))
	print("PASS: ground launcher lift, 10/10/24 aerial chain, cap, reset, Q weave and visual cleanup")
	quit(0)
