extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(18.0).timeout
	push_error("Hub progress test timed out")
	quit(1)

func _run() -> void:
	var progress := root.get_node("Progression")
	progress.save_path = "user://test_hub_orbs.cfg"
	progress.world_save_path = "user://test_hub_worlds.cfg"
	progress.clear_progress()
	assert(progress.key_count() == 0)
	assert(not progress.is_world_complete(&"world_01"))
	assert(not progress.complete_world(&"bad_world"))
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	for i in 5:
		await process_frame
	var player = current_scene.get_node("Player")
	assert(not player.equipment.has_weapon(&"echo_blade"))
	player.equip_staff()
	assert(progress.complete_world(&"world_01"))
	assert(progress.key_count() == 1)
	assert(not progress.complete_world(&"world_01"))
	assert(player.equipment.has_weapon(&"echo_blade"))
	assert(player.equipment.weapon.weapon_id == &"echo_blade")
	assert(player.equipment.weapon.is_playable())
	assert(player.weapon_display._props[&"echo_blade"].visible)
	player.combat._start_attack(player.equipment.weapon.light_chain[0], 1)
	assert(player.combat._current_attack == player.equipment.weapon.light_chain[0])
	player.combat.cancel_attack()
	assert(player.equipment.request_weapon(&"staff"))
	assert(player.equipment.request_weapon(&"echo_blade"))
	progress.completed_worlds.clear()
	progress.load_world_progress()
	assert(progress.is_world_complete(&"world_01"))
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	for i in 5:
		await process_frame
	player = current_scene.get_node("Player")
	assert(player.equipment.has_weapon(&"echo_blade"))
	assert(player.equipment.weapon.weapon_id == &"echo_blade")
	assert(InputMap.has_action("weapon_echo_blade"))
	for index in range(2, 9):
		assert(progress.complete_world(StringName("world_%02d" % index)))
	assert(progress.key_count() == 8)
	progress.completed_worlds.clear()
	progress.load_world_progress()
	assert(progress.key_count() == 8)
	progress.clear_progress()
	assert(progress.key_count() == 0)
	print("PASS: world keys, persistence, weapon reward and restoration")
	quit()
