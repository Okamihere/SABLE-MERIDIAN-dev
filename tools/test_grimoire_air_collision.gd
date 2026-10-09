extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

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
	player.equipment.request_weapon(&"living_grimoire")
	scene.get_node("TrainingDummy").queue_free()
	var enemy = load("res://scenes/enemies/basic_enemy.tscn").instantiate()
	scene.add_child(enemy)
	enemy.global_position = Vector3(0, 2.0, -2)
	enemy.set_physics_process(false)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = Vector3(0, 2, -3)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.3)
	shape.shape = box
	wall.add_child(shape)
	scene.add_child(wall)
	player.global_position = Vector3(0, 2.0, -4)
	player.rotation.y = 0.0
	await _frames(2)
	player.set_physics_process(false)
	player.combat._start_attack(player.equipment.weapon.air_light, 0)
	await _frames(15)
	assert(enemy.health.current_health == enemy.health.max_health, "Air light hit through a wall")
	player.combat._start_attack(player.equipment.weapon.air_heavy, 0)
	await _frames(19)
	assert(enemy.health.current_health == enemy.health.max_health, "Air heavy hit through a wall")
	player.combat._start_attack(player.equipment.weapon.light_chain[0], 1)
	assert(not player.combat._active_hitbox.hit_filter.is_valid(), "Air wall filter leaked into ground chain")
	print("PASS: both air hitboxes stop at wall; filter resets")
	quit(0)
