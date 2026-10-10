extends SceneTree

const VISUAL := preload("res://scripts/effects/grimoire_combo_visual.gd")

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(12.0).timeout
	push_error("Grimoire light combo test timed out")
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
	var weapon = player.equipment.weapon
	var dummy = scene.get_node("TrainingDummy")
	dummy.queue_free()
	var enemy = load("res://scenes/enemies/basic_enemy.tscn").instantiate()
	enemy.get_node("HealthComponent").max_health = 500.0
	scene.add_child(enemy)
	enemy.global_position = Vector3(0, 0.05, -0.5)
	enemy.set_physics_process(false)
	player.global_position = Vector3(0, 0.05, -4)
	player.rotation.y = 0.0
	player.lock_on.current_target = enemy
	await _frames(12)
	assert(player.is_on_floor(), "Player must settle on the floor before testing grounded projectiles")
	var hits: Array[float] = []
	enemy.health.damaged.connect(func(amount: float, _remaining: float, _maximum: float) -> void: hits.append(amount))
	var mana_before: float = player.mana.current_mana
	player.combat._start_attack(weapon.light_chain[0], 1)
	await _frames(2)
	assert(player.weapon_display._grimoire_ritual.visible, "Book did not open in anticipation")
	for expected in [1, 2, 3]:
		player.combat._buffer_action(&"light")
		await _frames(14)
		assert(player.combat.get_chain_index() == expected + 1, "Buffered combo stopped at stage %d" % expected)
	await _frames(100)
	assert(hits == [9.0, 11.0, 13.0, 18.0], "Damage or hit count changed: %s" % str(hits))
	assert(is_equal_approx(player.mana.current_mana, mana_before))
	assert(not player.combat.is_attacking() and player.combat.get_chain_index() == 0)
	assert(scene.find_children("GrimoireComboImpact", "Node3D", true, false).is_empty())
	assert(scene.find_children("GrimoireComboSound", "AudioStreamPlayer3D", true, false).is_empty(), "Combo SFX were retained")
	for stage in range(1, 5):
		var visual = VISUAL.new()
		scene.add_child(visual)
		visual.configure(stage)
		assert(visual.get_child_count() >= 4, "Stage %d has no distinct geometry" % stage)
		if stage == 4:
			assert(visual.get_node("PaperBlade") != null)
		visual.queue_free()
	await _frames(2)
	var impact = VISUAL.new()
	scene.add_child(impact)
	impact.configure(4, true)
	await _frames(20)
	assert(not is_instance_valid(impact), "Final impact did not clean up")
	player.combat._start_attack(weapon.light_chain[0], 1)
	player.combat._buffer_action(&"light")
	await _frames(16)
	assert(player.combat._current_attack == weapon.light_chain[1])
	player.combat._buffer_action(&"heavy")
	await _frames(14)
	assert(player.combat._current_attack == weapon.launcher, "Second hit did not branch into launcher")
	await _frames(12)
	assert(player.combat.can_cancel_to_dodge())
	player._start_dodge()
	assert(not player.combat.is_attacking())
	await _frames(35)
	player.global_position = Vector3(0, 1.8, -4)
	player.velocity.y = 3.0
	await _frames(2)
	player.combat._start_attack(weapon.air_light, 0)
	assert(player.combat._current_delivery == "melee")
	await _frames(3)
	assert(player.get_node("DirectionalSprite")._direction_index in range(8))
	assert(is_equal_approx(player.mana.current_mana, mana_before))
	print("PASS: four-hit damage, buffer, book poses, distinct VFX, launcher branch, dodge, air attack and cleanup")
	quit(0)
