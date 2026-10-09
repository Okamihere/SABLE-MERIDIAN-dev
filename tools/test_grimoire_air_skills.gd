extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(12.0).timeout
	push_error("Grimoire air skills test timed out")
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
	player.global_position = Vector3(0, 1.8, -4)
	player.velocity.y = 3.0
	await _frames(2)
	assert(not player.is_on_floor())
	player.set_physics_process(false)
	player.mana.regeneration_enabled = false
	var mana_before: float = player.mana.current_mana
	for spell in weapon.skills:
		player.combat._start_attack(weapon.air_heavy, 0)
		for i in 18:
			if player.combat.can_cancel_to_skill():
				break
			await _frames(1)
		assert(player.combat.can_cancel_to_skill())
		player._cast_spell(spell)
		assert(player.spell_manager.is_cast_committed(), "Air weave failed for %s" % spell.ability_id)
		assert(player.weapon_display._action_kind == &"skill" and player.weapon_display._action_id == spell.ability_id)
		for i in 24:
			if not player.spell_manager.is_cast_committed():
				break
			await _frames(1)
		assert(not player.spell_manager.is_cast_committed())
		if player.combat.is_attacking():
			assert(player.weapon_display._action_kind == &"air" and player.weapon_display._action_stage == 2, "Air pose did not resume after %s" % spell.ability_id)
		player.combat.cancel_attack()
		await _frames(2)
	assert(is_equal_approx(player.mana.current_mana, mana_before - 71.0))
	assert(scene.find_children("GrimoireMandatoryApplause", "Node3D", true, false).size() == 1)
	assert(get_nodes_in_group("grimoire_puppets").size() == 1)
	player.combat._start_attack(weapon.air_light, 0)
	for i in 8:
		if player.combat.can_cancel_to_dodge():
			break
		await _frames(1)
	assert(player.combat.can_cancel_to_dodge())
	player._start_dodge()
	assert(not player.combat.is_attacking())
	await _frames(3)
	assert(scene.find_children("GrimoireAirInvocation", "Node3D", true, false).is_empty())
	print("PASS: air Q/E/R weaving, mana, pose restoration, E surface, R summon and dodge cleanup")
	quit(0)
