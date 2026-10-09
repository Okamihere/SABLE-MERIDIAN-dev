extends SceneTree

func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()

func watchdog() -> void:
	await create_timer(35.0).timeout
	push_error("Fixed camera test timed out")
	quit(1)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func make_wall(scene: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	scene.add_child(wall)
	wall.global_position = at
	return wall

func run() -> void:
	change_scene_to_file("res://scenes/levels/fixed_camera_demo.tscn")
	await frames(70)
	var scene = current_scene
	var player = scene.get_node("Player")
	var rig = scene.get_node("CameraRig")
	var near_zone = scene.get_node("ZoneNear")
	var priority_zone = scene.get_node("ZonePriority")
	var dummy = scene.get_node("TrainingDummy")
	assert(rig.get_active_fixed_zone() == near_zone and rig.camera.current)
	assert(player.is_on_floor() and rig.spring_arm.collision_mask == 1)
	assert(absf(rig.spring_arm.spring_length) < 0.01)
	assert(get_nodes_in_group("game_camera").size() == 1)
	assert(near_zone.get_node("CollisionShape3D").shape != priority_zone.get_node("CollisionShape3D").shape)

	Input.action_press("move_forward")
	await frames(1)
	var before = player._camera_relative_direction(Vector2(0, -1))
	player.global_position = Vector3(3, 0.05, -4)
	player.velocity = Vector3.ZERO
	await frames(4)
	assert(rig.get_active_fixed_zone() == priority_zone and rig.is_view_transitioning())
	assert(before.dot(player._camera_relative_direction(Vector2(0, -1))) > 0.99)
	player._start_dodge()
	assert(player._dodge_direction.dot(before) > 0.99)
	Input.action_release("move_forward")
	player._camera_relative_direction(Vector2.ZERO)
	await frames(25)
	player.global_position = Vector3(3, 0.05, -4)
	player.velocity = Vector3.ZERO
	await frames(70)
	assert(rig.get_active_fixed_zone() == priority_zone and absf(rig.spring_arm.spring_length) < 0.01)
	player.lock_on.acquire_target()
	assert(player.lock_on.get_target() == dummy)

	var blocked := make_wall(scene, Vector3(4.5, 3, -7.5), Vector3(1.5, 3, 1.5))
	await frames(20)
	assert(rig._fixed_fallback and rig.get_active_fixed_zone() == null)
	await frames(65)
	assert(rig.camera.current and rig.spring_arm.spring_length > 3.0)
	blocked.queue_free()
	await frames(160)
	assert(rig.get_active_fixed_zone() == priority_zone and not rig._fixed_fallback)

	var anchor = priority_zone.get_node("ViewAnchor")
	anchor.rotation.y += PI
	await frames(20)
	assert(rig._fixed_fallback and rig.get_active_fixed_zone() == null)
	anchor.rotation.y -= PI
	await frames(160)
	assert(rig.get_active_fixed_zone() == priority_zone)

	player.global_position.y += 1.2
	player.velocity.y = 5.0
	await frames(2)
	player.combat._start_attack(player.combat.AIR_LIGHT, 0)
	assert(player.state_machine.state == PlayerStateMachine.State.AIR_ATTACK)
	await frames(8)
	assert(rig.camera.current and player.lock_on.get_target() == dummy)
	assert(player.get_node("DirectionalSprite")._direction_index in range(8))
	player.lock_on.clear_target()
	player.combat.cancel_attack()
	player.global_position = Vector3(-8, 0.05, -4)
	player.velocity = Vector3.ZERO
	await frames(80)
	assert(rig.get_active_fixed_zone() == null and rig.spring_arm.spring_length > 3.0)
	var free_distance = rig.camera.global_position.distance_to(rig.global_position)
	var collision_wall := make_wall(scene, rig.global_position.lerp(rig.camera.global_position, 0.5), Vector3(2, 2, 2))
	await frames(12)
	assert(rig.camera.global_position.distance_to(rig.global_position) < free_distance - 0.5)
	collision_wall.queue_free()
	print("PASS: fixed camera transitions, priority, movement, dodge, collision, lock-on, aerial combat, fallback and restore")
	quit(0)
