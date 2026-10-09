extends SceneTree

const ROOM := "res://scenes/levels/start_room.tscn"
func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(25.0).timeout
	push_error("Grimoire puppet test timed out")
	quit(1)

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _puppets() -> Array[Node]:
	return get_nodes_in_group(&"grimoire_puppets")

func _run() -> void:
	change_scene_to_file(ROOM)
	await _frames(10)
	var spell := load("res://resources/spells/living_grimoire_r.tres")
	var player = current_scene.get_node("Player")
	var mana_before: float = player.mana.current_mana
	assert(spell.ability_id == &"grimoire_r" and spell.mana_cost == 34.0 and spell.cooldown == 18.0 and spell.damage == 0.0)
	assert(player.spell_manager.cast_spell(spell, player))
	assert(is_equal_approx(player.mana.current_mana, mana_before - 34.0))
	assert(player.spell_manager.get_cooldown_remaining(spell) > 17.0)
	await _frames(25)
	assert(_puppets().size() == 1)
	var puppet = _puppets()[0]
	assert(puppet.summoner == player and puppet.duration == 12.0)
	assert(puppet.slap_damage == 6.0 and puppet.headbutt_damage == 10.0 and puppet.final_damage == 14.0 and puppet.attack_interval == 1.75)
	assert(puppet.global_position.distance_to(player.global_position) < 3.0)
	assert(puppet.find_children("*", "PhysicsBody3D").is_empty())
	player.spell_manager.reset_cooldown(spell)
	var mana_after_first: float = player.mana.current_mana
	assert(not player.spell_manager.cast_spell(spell, player))
	assert(is_equal_approx(player.mana.current_mana, mana_after_first))
	assert(_puppets().size() == 1)
	await create_timer(12.1).timeout
	await _frames(2)
	assert(_puppets().is_empty())
	assert(player.spell_manager.cast_spell(spell, player))
	await _frames(25)
	assert(_puppets().size() == 1)
	change_scene_to_file(ROOM)
	await _frames(10)
	assert(_puppets().is_empty())
	player = current_scene.get_node("Player")
	var configurable = load("res://scenes/effects/grimoire_puppet.tscn").instantiate()
	configurable.duration = 0.5
	current_scene.add_child(configurable)
	configurable.activate(player, spell)
	await create_timer(0.65).timeout
	await _frames(2)
	assert(_puppets().is_empty())
	assert(player.spell_manager.cast_spell(spell, player))
	await _frames(25)
	assert(_puppets().size() == 1)
	player.health.died.emit()
	await _frames(2)
	assert(_puppets().is_empty())
	print("PASS: mana, cooldown, spawn, single puppet, duration, scene change and death despawn")
	quit()
