extends SceneTree

const HUB := "res://scenes/levels/vertical_pilot.tscn"
const WORLDS_DIR := "res://scenes/levels/worlds/"

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
		assert(door.destination_scene == WORLDS_DIR + String(door.world_id) + ".tscn", "Porta não aponta para o mundo vazio: %s" % door.world_id)
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
	assert(current_scene.scene_file_path == "res://scenes/levels/worlds/world_01.tscn", "Porta 01 não abriu o mundo vazio")
	assert(current_scene.has_node("Player") and current_scene.has_node("CameraRig") and current_scene.has_node("HUD"), "Mundo sem sistemas do Player")
	var return_portal := current_scene.get_node("ReturnToHub")
	assert(return_portal.destination_scene == HUB and return_portal.return_world_id == &"world_01")
	var world_player := current_scene.get_node("Player")
	return_portal._on_entered(world_player)
	world_player.global_position = return_portal.global_position + Vector3(0, 0.1, 0.5)
	return_portal._physics_process(0.016)
	await root.get_node("AreaTransition").transition_finished
	assert(current_scene.scene_file_path == HUB, "Retorno ao hub falhou")
	for index in range(2, 9):
		var world_id := "world_%02d" % index
		assert(change_scene_to_file(WORLDS_DIR + world_id + ".tscn") == OK)
		for frame in 4:
			await physics_frame
		assert(current_scene.has_node("Player") and current_scene.has_node("CameraRig") and current_scene.has_node("HUD"))
		var portal := current_scene.get_node("ReturnToHub")
		assert(portal.destination_scene == HUB and portal.return_world_id == StringName(world_id))
	print("HUB FLOW PASS: oito portas apontam aos mundos vazios, com HUD e retorno funcional")
	quit(0)
