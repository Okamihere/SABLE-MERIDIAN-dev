extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(24.0).timeout
	push_error("Mandatory Applause test timed out")
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
	player.equipment.unlock_weapon(&"living_grimoire")
	assert(player.equipment.request_weapon(&"living_grimoire"))
	var spell: SpellResource = player.equipment.weapon.skills[1]
	assert(spell.ability_id == &"grimoire_e" and spell.spell_name == "Aplausos Obrigatórios")
	assert(spell.mana_cost == 23.0 and spell.cooldown == 5.0 and spell.damage == 10.0)
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
	assert(player.spell_manager.cast_spell(spell, player))
	assert(is_equal_approx(player.mana.current_mana, mana_before - 23.0))
	assert(not player.spell_manager.cast_spell(spell, player), "Cooldown must block recast")
	await _frames(8)
	var effects := scene.find_children("GrimoireMandatoryApplause", "Node3D", true, false)
	assert(effects.size() == 1, "Persistent area did not spawn")
	var effect = effects[0]
	assert(is_equal_approx(effect.global_position.y, 0.3), "Seal did not settle on floor")
	assert(effect.get_node("MandatoryApplauseVisual/TheatreSeal/DangerBoundary") != null)
	assert(effect.get_node("MandatoryApplauseVisual/LeftHand") != null and effect.get_node("MandatoryApplauseVisual/RightHand") != null)
	await _frames(12)
	assert(hits == [10.0], "E damage changed: %s" % str(hits))
	assert(effect._hitbox._already_hit.size() == 1)
	enemy.global_position = Vector3(8, 0.05, -1.8)
	await _frames(3)
	enemy.global_position = Vector3(0, 0.05, -1.8)
	await _frames(12)
	assert(hits == [10.0], "E hit one target more than once")
	await _frames(65)
	var late_enemy = load("res://scenes/enemies/basic_enemy.tscn").instantiate()
	late_enemy.get_node("HealthComponent").max_health = 500.0
	scene.add_child(late_enemy)
	late_enemy.global_position = Vector3(1.2, 0.05, -1.8)
	late_enemy.set_physics_process(false)
	await _frames(4)
	assert(is_equal_approx(late_enemy.health.current_health, 490.0), "A late entrant was not hit by the persistent area")
	assert(effect._visual._late_flash > 0.0, "A late entrant did not receive the small local VFX")
	await _frames(91)
	assert(is_instance_valid(effect), "Area expired before 3.4 seconds")
	await _frames(30)
	assert(not is_instance_valid(effect), "Area did not clean up after 3.4 seconds")
	assert(player.spell_manager.get_cooldown_remaining(spell) > 0.0)
	await _frames(90)
	assert(player.spell_manager.is_ready(spell), "Five-second cooldown did not finish")
	# Piso superior curto: o selo deve recuar para sua borda, sem cair no andar inferior.
	var upper := StaticBody3D.new()
	upper.collision_layer = 1
	upper.position = Vector3(0, 2.9, -4)
	var upper_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.8, 0.2, 2.8)
	upper_shape.shape = box
	upper.add_child(upper_shape)
	scene.add_child(upper)
	player.lock_on.current_target = null
	player.global_position = Vector3(0, 4.5, -4)
	player.velocity = Vector3.ZERO
	await _frames(2)
	assert(not player.is_on_floor())
	assert(player.spell_manager.cast_spell(spell, player), "Aerial cast over upper floor failed")
	await _frames(8)
	var air_effect = scene.find_children("GrimoireMandatoryApplause", "Node3D", true, false)[0]
	assert(is_equal_approx(air_effect.global_position.y, 3.3), "E crossed floors while cast in air")
	assert(air_effect.global_position.z < -2.6, "E did not fall back to supported part of upper floor")
	for i in 8:
		if player.spell_manager.can_cancel_cast():
			break
		await _frames(1)
	assert(player.spell_manager.can_cancel_cast(), "E cancel window changed")
	player._start_dodge()
	assert(not player.spell_manager.is_cast_committed())
	await _frames(25)
	# Sem piso ao alcance, o cast deve ser recusado antes do gasto de mana.
	player.global_position = Vector3(0, 10.0, -4)
	player.velocity = Vector3.ZERO
	player.spell_manager.reset_cooldown(spell)
	var mana_before_void: float = player.mana.current_mana
	assert(not player.spell_manager.cast_spell(spell, player))
	assert(is_equal_approx(player.mana.current_mana, mana_before_void))
	print("PASS: mana, cooldown, 3.4s area, single hit, aerial floor, no cross-floor cast, dodge and cleanup")
	quit(0)
