extends SceneTree

const HUB := "res://scenes/levels/vertical_pilot.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(change_scene_to_file(HUB) == OK, "Hub não carregou")
	for i in 30:
		await physics_frame
		await process_frame
		if current_scene != null:
			break
	assert(current_scene != null, "Hub não foi instanciado")
	for i in 4:
		await physics_frame
	var hub := current_scene
	var doors := hub.get_node("HubDoors")
	assert(doors.get_child_count() == 8, "O hub precisa de oito portas")
	var ids := {}
	for item in doors.get_children():
		var door := item as Node3D
		assert(not ids.has(door.world_id), "ID de mundo duplicado")
		ids[door.world_id] = true
		assert(ResourceLoader.exists(door.destination_scene), "Mundo sem cena: %s" % door.destination_scene)
		var approach: Vector3 = door.global_position + Vector3(-signf(door.position.x) * 3.0, 3.0, 0)
		var query := PhysicsRayQueryParameters3D.create(approach, approach + Vector3.DOWN * 6.0)
		var hit: Dictionary = hub.get_world_3d().direct_space_state.intersect_ray(query)
		assert(not hit.is_empty(), "Patamar inacessível em %s" % door.world_id)
		assert(absf(hit.position.y) < 0.2, "Patamar com altura incorreta em %s" % door.world_id)
	var player := hub.get_node("Player")
	for item in doors.get_children():
		var door := item as Node3D
		player.global_position = Vector3(0, 0.1, door.position.z)
		player.velocity = Vector3.ZERO
		hub.get_node("CameraRig").snap_to_player()
		for i in 4:
			await physics_frame
		var move_action := "move_left" if door.position.x < 0 else "move_right"
		Input.action_press(move_action)
		for i in 150:
			await physics_frame
			if door._player_inside == player:
				break
		Input.action_release(move_action)
		assert(door._player_inside == player, "Player não alcançou %s" % door.world_id)
		for i in 3:
			await physics_frame
	var first := doors.get_node("world_01")
	first._on_entered(player)
	var action := InputEventAction.new()
	action.action = "interact"
	action.pressed = true
	first._unhandled_input(action)
	await root.get_node("AreaTransition").transition_finished
	assert(current_scene.scene_file_path == "res://scenes/levels/world_01.tscn", "Porta 01 não abriu o mundo")
	assert(current_scene.has_node("Player") and current_scene.has_node("CameraRig") and current_scene.has_node("HUD"), "Mundo sem sistemas do Player")
	print("HUB FLOW PASS: Player alcançou 8 portas; transição mundo 01")
	quit(0)
