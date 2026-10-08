extends SceneTree

const HUB := "res://scenes/levels/vertical_pilot.tscn"
const START := "res://scenes/levels/start_room.tscn"

func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")

func _watchdog() -> void:
	await create_timer(65.0).timeout
	push_error("Room backtracking timed out")
	quit(1)

func _interact(portal: Node) -> void:
	var action := InputEventAction.new()
	action.action = "interact"
	action.pressed = true
	portal._unhandled_input(action)
	await root.get_node("AreaTransition").transition_finished

func _cross_return(portal: Node3D, player: Node3D) -> void:
	player.global_position = portal.global_position + portal.global_basis.z * 0.2 + Vector3.UP * 0.05
	portal._on_entered(player)
	portal._physics_process(0.0)
	await root.get_node("AreaTransition").transition_finished

func _run() -> void:
	change_scene_to_file(HUB)
	for i in 20:
		await physics_frame
		await process_frame
	var hub := current_scene
	var player := hub.get_node("Player")
	var entrance := hub.get_node("ReturnToStartRoom")
	player.global_position = Vector3(0, 0.05, 42)
	for i in 4:
		await physics_frame
	await _cross_return(entrance, player)
	assert(current_scene.scene_file_path == START, "Hub não voltou à primeira área")
	player = current_scene.get_node("Player")
	assert(absf(player.global_position.z - 11.0) < 0.5, "Retorno não chegou junto ao FogGate")
	for i in 15:
		await physics_frame
	assert(current_scene.scene_file_path == START, "FogGate devolveu o player imediatamente ao hub")
	var fog_gate := current_scene.get_node("FogGate")
	fog_gate._on_body_entered(player)
	player.global_position = Vector3(0, 0.05, 20)
	await root.get_node("AreaTransition").transition_finished
	assert(current_scene.scene_file_path == HUB, "FogGate não reabriu o hub")
	for index in range(1, 9):
		hub = current_scene
		player = hub.get_node("Player")
		var id := "world_%02d" % index
		var door := hub.get_node("HubDoors/%s" % id)
		door._on_entered(player)
		await _interact(door)
		assert(current_scene.scene_file_path == "res://scenes/levels/" + id + ".tscn", "Porta não entrou em %s" % id)
		player = current_scene.get_node("Player")
		if index == 1:
			var return_portal := current_scene.get_node("ReturnToHubAtEntrance")
			await _cross_return(return_portal, player)
		else:
			current_scene._inside_return = true
			await _interact(current_scene)
		assert(current_scene.scene_file_path == HUB, "Mundo %s não voltou ao hub" % id)
		assert(current_scene.get_node("Player").global_position.distance_to(current_scene.get_node("HubDoors/%s" % id).global_position) < 6.0, "Retorno de %s não chegou à porta" % id)
	print("ROOM BACKTRACK PASS: primeira área e 8 mundos retornam pela entrada")
	quit(0)
