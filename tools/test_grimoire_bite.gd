extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(10.0).timeout
	push_error("Grimoire bite test timed out")
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
	assert(weapon.heavy.damage == 15 and is_equal_approx(weapon.heavy.startup, 0.16))
	assert(is_equal_approx(weapon.heavy.active, 0.18) and is_equal_approx(weapon.heavy.recovery, 0.26))
	assert(is_equal_approx(weapon.heavy_range, 6.5))
	scene.get_node("TrainingDummy").queue_free()
	var enemy = load("res://scenes/enemies/basic_enemy.tscn").instantiate()
	enemy.get_node("HealthComponent").max_health = 500.0
	scene.add_child(enemy)
	enemy.global_position = Vector3(0, 0.05, -0.5)
	enemy.set_physics_process(false)
	player.global_position = Vector3(0, 0.05, -4)
	player.rotation.y = 0.0
	player.lock_on.current_target = enemy
	await _frames(12)
	assert(player.is_on_floor())
	var hits: Array[float] = []
	enemy.health.damaged.connect(func(amount: float, _remaining: float, _maximum: float) -> void: hits.append(amount))
	var mana_before: float = player.mana.current_mana
	player.combat._start_attack(weapon.heavy, 0)
	await _frames(2)
	assert(player.combat._current_delivery == "seal")
	assert(player.weapon_display._grimoire_ritual.visible, "The book did not react")
	assert(not scene.find_children("ManuscriptBiteOmen", "Node3D", true, false).is_empty())
	await _frames(12)
	var mouths := scene.find_children("ManuscriptBite", "Node3D", true, false)
	assert(mouths.size() == 1, "The bite did not replace the seal")
	assert(mouths[0].get_node("UpperJaw") != null and mouths[0].get_node("LowerJaw") != null)
	assert(mouths[0]._impact_age >= 0.0 and mouths[0].get_node("ImpactPages") != null, "Bite impact feedback was not triggered")
	assert(hits == [15.0], "Heavy damage or hit count changed: %s" % str(hits))
	assert(enemy.state == enemy.State.LAUNCHED and enemy.velocity.y >= 7.5, "Heavy launcher changed")
	assert(is_equal_approx(player.mana.current_mana, mana_before))
	await _frames(28)
	assert(scene.find_children("ManuscriptBite", "Node3D", true, false).is_empty(), "Bite effect was retained")
	assert(scene.find_children("ManuscriptBiteOmen", "Node3D", true, false).is_empty(), "Omen was retained")
	await _frames(10)
	player.combat._start_attack(weapon.heavy, 0)
	await _frames(22)
	assert(player.combat.can_cancel_to_dodge(), "Heavy dodge window changed")
	player._start_dodge()
	assert(not player.combat.is_attacking())
	await _frames(35)
	assert(scene.find_children("ManuscriptBite", "Node3D", true, false).is_empty())
	assert(scene.find_children("ManuscriptBiteOmen", "Node3D", true, false).is_empty())
	player.combat._start_attack(weapon.light_chain[0], 1)
	player.combat._buffer_action(&"light")
	await _frames(16)
	assert(player.combat._current_attack == weapon.light_chain[1])
	player.combat._buffer_action(&"heavy")
	await _frames(14)
	assert(player.combat._current_attack == weapon.launcher, "The second light did not branch to launcher")
	assert(scene.find_children("ManuscriptBiteOmen", "Node3D", true, false).is_empty(), "Launcher became a bite")
	for i in 18:
		if player.combat.can_cancel_to_dodge():
			break
		await _frames(1)
	assert(player.combat.can_cancel_to_dodge(), "Launcher cancel unavailable")
	player._start_dodge()
	assert(not player.combat.is_attacking())
	await _frames(35)
	player.global_position = Vector3(0, 1.8, -4)
	player.velocity.y = 3.0
	await _frames(2)
	player.combat._start_attack(weapon.air_heavy, 0)
	assert(player.combat._current_delivery == "melee", "Aerial heavy route changed")
	assert(is_equal_approx(player.mana.current_mana, mana_before))
	assert(scene.find_children("Bite*Sound", "AudioStreamPlayer3D", true, false).is_empty(), "Bite audio was retained")
	print("PASS: bite damage, launch, anticipation, effect cleanup, light-to-launcher, dodge and aerial route")
	quit(0)
