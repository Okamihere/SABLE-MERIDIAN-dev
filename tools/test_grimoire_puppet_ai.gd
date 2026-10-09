extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(20.0).timeout
	push_error("Grimoire puppet AI test timed out")
	quit(1)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _solid(parent: Node3D, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	body.global_position = position
	return body

func _dummy(parent: Node3D, position: Vector3) -> Node3D:
	var enemy := load("res://scenes/enemies/training_dummy.tscn").instantiate() as Node3D
	parent.add_child(enemy)
	enemy.global_position = position
	return enemy

func _run() -> void:
	var arena := Node3D.new()
	arena.name = "PuppetTestArena"
	root.add_child(arena)
	current_scene = arena
	_solid(arena, Vector3(0, -0.5, 0), Vector3(24, 1, 24))
	var player = load("res://scenes/player/player_rig.tscn").instantiate()
	arena.add_child(player)
	player.global_position = Vector3(0, 0.05, 0)
	var puppet = load("res://scenes/effects/grimoire_puppet.tscn").instantiate()
	arena.add_child(puppet)
	puppet.activate(player, load("res://resources/spells/living_grimoire_r.tres"))
	await _frames(25)
	assert(not puppet.is_in_group(&"enemies"))
	var initial_x: float = puppet.global_position.x
	player.global_position = Vector3(4, 0.05, 0)
	await _frames(65)
	assert(puppet.global_position.x > initial_x + 0.7, "Puppet did not follow player")
	assert(puppet.global_position.distance_to(player.global_position) > 0.7)
	var first := _dummy(arena, Vector3(7, 0.05, 4))
	var second := _dummy(arena, Vector3(2, 0.05, 5))
	await _frames(25)
	assert(puppet.target != null, "No visible enemy selected")
	player.lock_on.current_target = first
	await _frames(25)
	assert(puppet.target == first, "Lock-on target not prioritized")
	player.lock_on.current_target = second
	await _frames(25)
	assert(puppet.target == second, "Lock-on switch not followed")
	second.queue_free()
	player.lock_on.clear_target()
	await _frames(25)
	assert(puppet.target == first, "Did not reacquire a valid enemy")
	first.queue_free()
	await _frames(25)
	assert(puppet.target == null and puppet.mode in [puppet.Mode.FOLLOWING, puppet.Mode.WAITING])

	# Parede entre jogador e marionete: ela não deve atravessá-la.
	var wall := _solid(arena, Vector3(1.0, 1.2, 0), Vector3(0.6, 2.4, 2.4))
	puppet.global_position = Vector3(0, 0.2, 0)
	player.global_position = Vector3(5, 0.05, 0)
	var hidden := _dummy(arena, Vector3(6, 0.05, 0))
	await _frames(20)
	assert(puppet.target == null, "Enemy behind wall was acquired")
	hidden.queue_free()
	var blocked_distance: float = puppet.global_position.distance_to(player.global_position)
	await _frames(25)
	assert(puppet.global_position.x < 1.5 or absf(puppet.global_position.z) > 1.0, "Puppet crossed the wall")
	await _frames(100)
	assert(puppet.global_position.distance_to(player.global_position) < blocked_distance - 0.5, "Puppet stayed stuck at wall")
	wall.queue_free()
	var low_step := _solid(arena, Vector3(8.2, 0.2, 0), Vector3(1.2, 0.4, 1.2))
	await _frames(2)
	puppet.global_position = Vector3(7.3, 0.2, 0)
	assert(puppet._move_safely(Vector3.RIGHT, 0.7) and puppet.global_position.y > 0.5, "Puppet could not climb a low step")
	assert(puppet._move_safely(Vector3.RIGHT, 1.1) and puppet.global_position.y < 0.3, "Puppet could not descend a low step")
	low_step.queue_free()
	puppet.global_position = Vector3(-9, 0.2, 0)
	await _frames(3)
	assert(puppet.mode == puppet.Mode.RETURNING and puppet.target == null)
	var far_x: float = puppet.global_position.x
	await _frames(25)
	assert(puppet.global_position.x > far_x, "Puppet did not return toward player")

	# Plataforma isolada: a sonda de chão deve recusar um passo sobre a borda.
	_solid(arena, Vector3(31, -0.5, 0), Vector3(4, 1, 4))
	_solid(arena, Vector3(38, -0.5, 0), Vector3(4, 1, 4))
	player.set_physics_process(false)
	player.global_position = Vector3(31, 0.05, 0)
	puppet.target = null
	puppet.global_position = Vector3(32.7, 0.2, 0)
	var across_gap := _dummy(arena, Vector3(37, 0.05, 0))
	assert(not puppet._target_valid(across_gap), "Enemy across gap was considered reachable")
	var edge: Vector3 = puppet.global_position
	assert(not puppet._move_safely(Vector3.RIGHT, 0.7), "Puppet stepped off the platform")
	assert(puppet.global_position == edge)
	puppet.duration = puppet._elapsed + 0.35
	await _frames(30)
	assert(get_nodes_in_group(&"grimoire_puppets").is_empty(), "Puppet did not clean up")
	print("PASS: follow, target selection and switching, obstacle, ledge and cleanup")
	quit()
