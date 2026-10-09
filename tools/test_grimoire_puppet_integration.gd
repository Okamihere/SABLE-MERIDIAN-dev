extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(35.0).timeout
	push_error("Grimoire puppet integration test timed out")
	quit(1)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	change_scene_to_file("res://scenes/levels/fixed_camera_demo.tscn")
	await _frames(70)
	var scene := current_scene
	var player = scene.get_node("Player")
	var rig = scene.get_node("CameraRig")
	var zone := scene.get_node("ZonePriority")
	var dummy := scene.get_node("TrainingDummy") as Node3D
	player.global_position = Vector3(3, 0.05, -4)
	await _frames(70)
	assert(rig.get_active_fixed_zone() == zone and rig.camera.current)
	assert(player.equipment.request_weapon(&"living_grimoire"))
	var spell = load("res://resources/spells/living_grimoire_r.tres")
	assert(player.spell_manager.cast_spell(spell, player))
	await _frames(25)
	var puppets := get_nodes_in_group(&"grimoire_puppets")
	assert(puppets.size() == 1)
	var puppet = puppets[0]
	player.lock_on.acquire_target()
	assert(player.lock_on.get_target() == dummy)
	assert(player.equipment.request_weapon(&"cane_blade"))
	assert(player.equipment.weapon.weapon_id == &"cane_blade" and puppet.summoner == player)
	player._start_dodge()
	await _frames(2)
	assert(player.state_machine.state == PlayerStateMachine.State.DODGE)
	assert(is_instance_valid(puppet) and rig.camera.current)
	await _frames(50)
	player.global_position = Vector3(3, 0.05, -4)
	player.velocity = Vector3.ZERO
	await _frames(70)
	assert(rig.get_active_fixed_zone() == zone)
	var anchor = zone.get_node("ViewAnchor")
	anchor.rotation.y += PI
	await _frames(20)
	assert(rig._fixed_fallback and is_instance_valid(puppet))
	anchor.rotation.y -= PI
	await _frames(165)
	assert(rig.get_active_fixed_zone() == zone and rig.camera.current)
	assert(is_instance_valid(puppet) and puppet.target == dummy)
	player.global_position.y += 1.2
	player.velocity.y = 5.0
	await _frames(2)
	player.combat._start_attack(player.combat.AIR_LIGHT, 0)
	await _frames(8)
	assert(player.state_machine.state == PlayerStateMachine.State.AIR_ATTACK)
	assert(player.get_node("DirectionalSprite")._direction_index in range(8))
	assert(is_instance_valid(puppet) and puppet.summoner == player)
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await _frames(10)
	assert(get_nodes_in_group(&"grimoire_puppets").is_empty())
	assert(get_nodes_in_group(&"game_camera").size() == 1)
	var respawn_player = current_scene.get_node("Player")
	assert(respawn_player.spell_manager.cast_spell(spell, respawn_player))
	await _frames(25)
	assert(get_nodes_in_group(&"grimoire_puppets").size() == 1)
	respawn_player.health.damage(100000.0)
	await _frames(2)
	assert(get_nodes_in_group(&"grimoire_puppets").is_empty())
	await create_timer(2.15).timeout
	await _frames(10)
	assert(current_scene.get_node("Player") != respawn_player)
	assert(get_nodes_in_group(&"grimoire_puppets").is_empty())
	print("PASS: fixed camera, fallback, lock-on, dodge, weapon swap, aerial combat, scene cleanup and respawn")
	quit(0)
