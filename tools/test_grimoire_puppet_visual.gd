extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(20.0).timeout
	push_error("Grimoire puppet visual test timed out")
	quit(1)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	floor_shape.shape = box
	floor.add_child(floor_shape)
	arena.add_child(floor)
	floor.position.y = -0.5
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.global_position = Vector3(3.6, 2.6, 4.2)
	camera.look_at(Vector3(1.1, 1.2, 0))
	camera.current = true
	var light := DirectionalLight3D.new()
	arena.add_child(light)
	light.rotation_degrees = Vector3(-45, 25, 0)
	var player = load("res://scenes/player/player_rig.tscn").instantiate()
	arena.add_child(player)
	player.global_position = Vector3(0, 0.05, 0)
	await _frames(5)
	var display = player.weapon_display
	display.show_weapon(&"living_grimoire")
	display.play_skill(&"grimoire_r", 0.28)
	await _frames(5)
	assert(display._grimoire_ritual.visible and absf(display._grimoire_model.rotation.x) > 0.01)
	var puppet = load("res://scenes/effects/grimoire_puppet.tscn").instantiate()
	arena.add_child(puppet)
	puppet.activate(player, load("res://resources/spells/living_grimoire_r.tres"))
	puppet.set_physics_process(false)
	puppet._next_attack_at = INF
	assert(puppet.visual.scale.x < 1.0 and puppet.summon_tome.visible and puppet.pull_threads.visible)
	assert(puppet.stage_vfx.find_children("SummonCurtain", "Node3D", true, false).size() == 1)
	for name in ["Summon", "Movement", "Cue", "SlapImpact", "HeadImpact", "FinalImpact", "Farewell"]:
		assert(puppet.get_node("Audio/" + name).stream != null, "Missing sound: " + name)
	await _frames(8)
	if puppet._elapsed < puppet.SUMMON_TIME:
		assert(puppet.visual.position.y < 0.0 and puppet.visual.scale.x < 1.0)
		assert(puppet.loose_pages[0].visible)
		assert(absf(puppet.left_page_hinge.rotation.z) < 1.3)
	await create_timer(0.7).timeout
	assert(not puppet.summon_tome.visible and not puppet.pull_threads.visible)
	assert(puppet.stage_vfx.find_children("SummonCurtain", "Node3D", true, false).is_empty())
	assert(not puppet.warp_ring.visible)
	assert(not display._grimoire_ritual.visible)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/sable_grimoire_puppet_idle.png")
	var enemy = load("res://scenes/enemies/basic_enemy.tscn").instantiate()
	enemy.get_node("HealthComponent").max_health = 500.0
	arena.add_child(enemy)
	enemy.global_position = puppet.global_position + puppet.global_basis.z * 1.7
	enemy.set_physics_process(false)
	await _frames(2)
	assert(puppet._can_strike(enemy, puppet.slap_range), "Visual test target is out of range")
	puppet._start_attack(puppet.AttackKind.SLAP, enemy)
	assert(puppet.stage_vfx.find_children("AttackOmen", "Node3D", true, false).size() == 1)
	puppet._update_attack(0.08)
	puppet._animate_attack()
	assert(puppet._attack_phase == puppet.AttackPhase.WINDUP and puppet.left_arm.position.z < 0.0)
	puppet._update_attack(0.1)
	puppet._animate_attack()
	assert(puppet._attack_phase == puppet.AttackPhase.ACTIVE and puppet.left_arm.scale.y > 3.0)
	assert(puppet.ink_particles.emitting and puppet.warp_ring.visible)
	puppet._update_attack(0.5)
	assert(puppet._attack_kind == puppet.AttackKind.NONE and is_equal_approx(puppet.left_arm.scale.y, 1.0))
	puppet._start_attack(puppet.AttackKind.HEADBUTT, enemy)
	assert(puppet.stage_vfx.find_children("AttackOmen", "Node3D", true, false).size() == 1)
	puppet._update_attack(0.25)
	puppet._animate_attack()
	assert(puppet._attack_phase == puppet.AttackPhase.WINDUP and puppet.visual.rotation.x < -0.15)
	puppet._update_attack(0.16)
	puppet._animate_attack()
	assert(puppet._attack_phase == puppet.AttackPhase.ACTIVE and puppet.head.scale.x > 1.1)
	puppet._clear_attack()
	puppet._start_attack(puppet.AttackKind.FINAL, enemy)
	assert(puppet.stage_vfx.find_children("AttackOmen", "Node3D", true, false).size() == 1)
	puppet._update_attack(0.3)
	puppet._animate_attack()
	assert(puppet._attack_phase == puppet.AttackPhase.ACTIVE and puppet.left_arm.scale.y >= 2.0 and puppet.right_arm.scale.y >= 2.0)
	assert(puppet.pull_threads.visible == false and puppet.warp_ring.visible)
	for kind in [puppet.AttackKind.SLAP, puppet.AttackKind.HEADBUTT, puppet.AttackKind.FINAL]:
		puppet.stage_vfx.play_hit(kind, enemy.global_position + Vector3.UP)
		await _frames(1)
		assert(arena.find_children("Puppet*Impact", "Node3D", true, false).size() == 1)
		await _frames(18)
		assert(arena.find_children("Puppet*Impact", "Node3D", true, false).is_empty(), "Impact VFX was retained")
	puppet.despawn()
	await _frames(2)
	assert(get_nodes_in_group(&"grimoire_puppets").is_empty())
	assert(arena.find_children("PuppetFarewellKnot", "Node3D", true, false).size() == 1)
	await _frames(14)
	assert(arena.find_children("PuppetFarewellKnot", "Node3D", true, false).is_empty(), "Farewell VFX was retained")
	assert(arena.find_children("InkParticles", "CPUParticles3D").is_empty())
	enemy.queue_free()
	await _frames(2)
	var farewell = load("res://scenes/effects/grimoire_puppet.tscn").instantiate()
	farewell.duration = 1.3
	arena.add_child(farewell)
	farewell.activate(player, load("res://resources/spells/living_grimoire_r.tres"))
	await create_timer(0.85).timeout
	assert(farewell._farewell_cued and farewell.sound_farewell.playing)
	assert(farewell._bowing and farewell.pull_threads.visible and farewell.summon_tome.visible)
	assert(farewell.stage_vfx.find_children("FarewellThreads", "Node3D", true, false).size() == 1)
	await create_timer(0.6).timeout
	await _frames(2)
	assert(get_nodes_in_group(&"grimoire_puppets").is_empty())
	assert(arena.find_children("InkParticles", "CPUParticles3D").is_empty())
	print("PASS: grimoire opening, summoning, attack poses, farewell bow, VFX, audio references and cleanup")
	quit()
