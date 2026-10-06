extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(30.0).timeout
	push_error("Combat timing test timed out")
	quit(1)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _run() -> void:
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await _frames(20)
	var player = current_scene.get_node("Player")
	player.equip_staff()
	var invalid_spell := SpellResource.new()
	invalid_spell.ability_id = &"invalid_effect_test"
	invalid_spell.mana_cost = 9.0
	var empty_effect := Node3D.new()
	invalid_spell.effect_scene = PackedScene.new()
	assert(invalid_spell.effect_scene.pack(empty_effect) == OK)
	empty_effect.free()
	var mana_before_invalid: float = player.mana.current_mana
	assert(not player.spell_manager.cast_spell(invalid_spell, player))
	assert(player.mana.current_mana == mana_before_invalid and player.spell_manager.get_cooldown_remaining(invalid_spell) == 0.0)
	for weapon_id in [&"staff", &"card_daggers", &"puppet_strings", &"cane_blade", &"living_grimoire"]:
		assert(player.equipment.request_weapon(weapon_id))
		var weapon = player.equipment.weapon
		assert(weapon.light_chain.size() == 4, "Every weapon needs a four-hit chain")
		player.combat._start_attack(weapon.light_chain[0], 1)
		assert(player.weapon_display._action_kind == &"basic" and player.weapon_display._action_stage == 1)
		var first = player.combat._current_attack
		player.combat._buffer_action(&"light")
		await _frames(2)
		assert(player.combat._current_attack == first, "Startup must not be skipped: " + str(weapon_id))
		await _frames(12)
		assert(player.combat._current_attack == weapon.light_chain[1], "Buffered chain must advance: " + str(weapon_id))
		for stage in [2, 3]:
			player.combat._buffer_action(&"light")
			await _frames(12)
			assert(player.combat._current_attack == weapon.light_chain[stage], "Chain must reach hit %d: %s" % [stage + 1, weapon_id])
			assert(player.weapon_display._action_stage == stage + 1, "Visible animation must follow the chain")
		await _frames(65)
		assert(not player.combat.is_attacking() and player.combat.get_chain_index() == 0, "Finisher must end the chain")
		player.combat.cancel_attack()
		player.combat._start_attack(weapon.light_chain[0], 1)
		await _frames(25)
		assert(not player.combat.is_attacking())
		await _frames(25)
		assert(player.combat.get_chain_index() == 0, "Idle chain must expire: " + str(weapon_id))
		var spell = weapon.skills[0]
		player.mana.current_mana = player.mana.max_mana
		assert(player.spell_manager.cast_spell(spell, player))
		assert(player.weapon_display._action_kind == &"skill" and player.weapon_display._action_id == spell.ability_id)
		assert(not player.spell_manager.cast_spell(spell, player), "Skill cooldown/commit must stop spam")
		if spell.startup_time > 0.0:
			assert(player.spell_manager.is_cast_committed())
			assert(not player.spell_manager._effect_fired, "Effect must wait for startup")
			player.combat._buffer_action(&"light")
			await _frames(1)
			assert(not player.combat.is_attacking(), "Cast startup must block new basic attack")
			await _frames(22)
			assert(not player.spell_manager.is_cast_committed(), "Cast recovery must end")
			assert(player.spell_manager.get_cooldown_remaining(spell) > 0.0, "Cooldown must outlast recovery")
			assert(player.spell_manager.is_ready(weapon.skills[1]), "Other skill must keep its own cooldown")
			player.combat._buffer_action(&"light")
			player.combat._try_start_buffered()
			assert(player.combat.is_attacking(), "Basic attack must resume during skill cooldown")
			player.combat.cancel_attack()
		else:
			await _frames(1)
		assert(player.equipment.weapon.weapon_id == weapon_id)
	player.mana.current_mana = player.mana.max_mana
	var committed_skill = player.equipment.weapon.skills[2]
	assert(player.spell_manager.cast_spell(committed_skill, player))
	assert(player.equipment.request_weapon(&"staff"))
	assert(player.equipment.weapon.weapon_id == &"staff", "Weapon swap must remain immediate outside basic attacks")
	assert(player.weapon_display._equipped == &"living_grimoire", "Casting visual must finish with the original weapon")
	assert(not player.spell_manager.can_cancel_cast(), "Startup/active must resist early dodge")
	await _frames(12)
	assert(player.spell_manager.can_cancel_cast(), "Recovery must open dodge cancel")
	player._start_dodge()
	assert(not player.spell_manager.is_cast_committed(), "Dodge must cancel remaining cast")
	assert(player.weapon_display._action_kind != &"skill", "Cancelled spell motion must stop")
	assert(player.weapon_display._equipped == &"staff", "Visual must catch up after cast cancel")
	await _frames(20)
	player.combat._start_attack(player.equipment.weapon.light_chain[3], 4)
	await _frames(16)
	player._cast_spell(player.equipment.weapon.skills[1])
	assert(player.weapon_display._action_kind == &"skill", "Weaved skill must have its own animation")
	await _frames(15)
	assert(player.combat.is_attacking() and player.weapon_display._action_kind == &"basic" and player.weapon_display._action_stage == 4, "Basic motion must resume after a weaved skill")
	assert(player.weapon_display._action_time > 0.2, "Resumed motion must keep attack progress")
	print("PASS: five weapon chains, buffer, timeout, skill commitment and independent cooldown")
	quit()
