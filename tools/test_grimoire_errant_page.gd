extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(12.0).timeout
	push_error("Errant Page test timed out")
	quit(1)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _enemy(scene: Node, at: Vector3):
	var enemy = load("res://scenes/enemies/basic_enemy.tscn").instantiate()
	enemy.get_node("HealthComponent").max_health = 500.0
	scene.add_child(enemy)
	enemy.global_position = at
	enemy.set_physics_process(false)
	return enemy

func _run() -> void:
	change_scene_to_file("res://scenes/levels/fixed_camera_demo.tscn")
	await _frames(60)
	var scene := current_scene
	var player = scene.get_node("Player")
	player.equip_staff()
	assert(player.equipment.request_weapon(&"living_grimoire"))
	var spell: SpellResource = player.equipment.weapon.skills[0]
	assert(spell.ability_id == &"grimoire_q" and spell.mana_cost == 14.0 and spell.cooldown == 0.9)
	assert(spell.damage == 13.0 and spell.startup_time == 0.08 and spell.active_time == 0.04 and spell.recovery_time == 0.1)
	scene.get_node("TrainingDummy").queue_free()
	var enemy = _enemy(scene, Vector3(1, 0.05, 0))
	player.global_position = Vector3(0, 0.05, -4)
	player.rotation.y = 0.0
	player.lock_on.current_target = enemy
	await _frames(12)
	assert(player.is_on_floor())
	var hits: Array[float] = []
	enemy.health.damaged.connect(func(amount: float, _remaining: float, _maximum: float) -> void: hits.append(amount))
	var mana_before: float = player.mana.current_mana
	assert(player.spell_manager.cast_spell(spell, player))
	await _frames(2)
	assert(player.weapon_display._grimoire_ritual.visible, "Book did not open")
	assert(get_nodes_in_group("cursed_cards").is_empty(), "Projectile fired before startup")
	assert(not player.spell_manager.cast_spell(spell, player), "Cooldown or commitment did not hold")
	await _frames(5)
	var cards := get_nodes_in_group("cursed_cards")
	assert(cards.size() == 1, "Q must fire one page")
	var page = cards[0]
	assert(page._grimoire_q and page.speed == 22.0 and page.homing_strength == 5.0 and page.lifetime == 1.6)
	assert(page._target == enemy and page.visual.get_node("ErrantOrigami/GrotesqueMask") != null)
	assert(page.get_node("ErrantPageFlightSound").playing)
	assert(not scene.find_children("ErrantPageCastSound", "AudioStreamPlayer3D", true, false).is_empty())
	assert(page.hitbox.damage == 18.2)
	await _frames(24)
	assert(hits.size() == 1 and is_equal_approx(hits[0], 18.2), "Lock-on hit changed: %s" % str(hits))
	assert(not scene.find_children("ErrantPageImpactSound", "AudioStreamPlayer3D", true, false).is_empty())
	assert(is_equal_approx(player.mana.current_mana, mana_before - 14.0))
	assert(get_nodes_in_group("cursed_cards").is_empty())
	await _frames(15)
	assert(scene.find_children("ErrantPageImpact", "Node3D", true, false).is_empty())
	assert(scene.find_children("ErrantPageTrail", "Node3D", true, false).is_empty(), "Page trail did not fade after impact")
	await _frames(25)
	assert(scene.find_children("ErrantPageImpactSound", "AudioStreamPlayer3D", true, false).is_empty(), "Impact sound was not released")
	assert(player.spell_manager.is_ready(spell), "0.9s cooldown did not finish")
	enemy.queue_free()
	await _frames(2)
	var enemy_without_lock = _enemy(scene, Vector3(0, 0.05, -0.5))
	var free_hits: Array[float] = []
	enemy_without_lock.health.damaged.connect(func(amount: float, _remaining: float, _maximum: float) -> void: free_hits.append(amount))
	player.lock_on.current_target = null
	player.rotation.y = 0.0
	assert(player.spell_manager.cast_spell(spell, player))
	await _frames(25)
	assert(free_hits.size() == 1 and is_equal_approx(free_hits[0], 18.2), "Free aim hit changed")
	assert(is_equal_approx(player.mana.current_mana, mana_before - 28.0))
	await _frames(46)
	assert(player.spell_manager.is_ready(spell))
	assert(player.spell_manager.cast_spell(spell, player))
	await _frames(8)
	assert(player.spell_manager.can_cancel_cast())
	player._start_dodge()
	assert(not player.spell_manager.is_cast_committed())
	await _frames(45)
	player.global_position = Vector3(0, 1.8, -4)
	player.velocity.y = 3.0
	await _frames(2)
	assert(not player.is_on_floor())
	assert(player.spell_manager.cast_spell(spell, player), "Aerial cast failed")
	await _frames(8)
	assert(not get_nodes_in_group("cursed_cards").is_empty(), "Aerial cast did not fire")
	change_scene_to_file("res://scenes/levels/fixed_camera_demo.tscn")
	await _frames(5)
	assert(get_nodes_in_group("cursed_cards").is_empty())
	assert(current_scene.find_children("ErrantPageTrail", "Node3D", true, false).is_empty())
	print("PASS: mana, cooldown, damage, startup, homing, free aim, dodge, air cast and VFX cleanup")
	quit(0)
