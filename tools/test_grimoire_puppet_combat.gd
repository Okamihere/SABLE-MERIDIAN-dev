extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(30.0).timeout
	push_error("Grimoire puppet combat test timed out")
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

func _enemy(parent: Node3D, position: Vector3) -> Node3D:
	var enemy := load("res://scenes/enemies/basic_enemy.tscn").instantiate() as Node3D
	enemy.get_node("HealthComponent").max_health = 500.0
	parent.add_child(enemy)
	enemy.global_position = position
	enemy.set_physics_process(false)
	return enemy

func _puppet(parent: Node3D, player: Node3D, lifetime: float = 12.0) -> Node3D:
	var puppet := load("res://scenes/effects/grimoire_puppet.tscn").instantiate() as Node3D
	puppet.duration = lifetime
	parent.add_child(puppet)
	puppet.activate(player, load("res://resources/spells/living_grimoire_r.tres"))
	return puppet

func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	_solid(arena, Vector3(0, -0.5, 0), Vector3(24, 1, 24))
	var player = load("res://scenes/player/player_rig.tscn").instantiate()
	arena.add_child(player)
	player.global_position = Vector3(0, 0.05, 0)
	await _frames(10)
	var game_manager = root.get_node("GameManager")
	game_manager.reset_style()
	var first := _enemy(arena, Vector3(1.8, 0.05, 2.3))
	var puppet := _puppet(arena, player)
	await _frames(25)
	assert(puppet._attack_kind == puppet.AttackKind.SLAP and puppet._attack_phase == puppet.AttackPhase.WINDUP)
	assert(first.health.current_health == 500.0, "Damage before slap impact")
	await _frames(20)
	assert(first.health.current_health == 500.0 - puppet.slap_damage, "Slap damage missing or repeated")
	assert(player.health.current_health == player.health.max_health, "Puppet damaged player")
	assert(game_manager.style_meter.combo_count == 1, "Slap did not register style once")
	await _frames(110)
	assert(first.health.current_health == 500.0 - puppet.slap_damage - puppet.headbutt_damage, "Headbutt damage missing or repeated")
	assert(game_manager.style_meter.combo_count == 2, "Headbutt did not register style once")
	assert(player.health.current_health == player.health.max_health)

	# O alvo fica atrás de uma parede antes da próxima janela de ataque.
	var wall := _solid(arena, Vector3(1.8, 1.0, 1.6), Vector3(2.8, 2.0, 0.25))
	await _frames(2)
	var before_wall: float = first.health.current_health
	await _frames(105)
	assert(first.health.current_health == before_wall, "Attack passed through wall")
	wall.queue_free()
	var second := _enemy(arena, Vector3(2.5, 0.05, 2.5))
	player.lock_on.current_target = second
	await _frames(95)
	assert(puppet.target == second, "Puppet ignored switched lock-on target")
	assert(second.health.current_health < 500.0, "Switched target took no damage")
	assert(first.health.current_health == before_wall, "Old target was hit after switch")

	# Perder o alvo durante a antecipação cancela o golpe e fecha a hitbox.
	puppet.despawn()
	await _frames(2)
	first.queue_free()
	second.queue_free()
	player.lock_on.clear_target()
	var interrupted_enemy := _enemy(arena, Vector3(1.8, 0.05, 2.3))
	puppet = _puppet(arena, player)
	await _frames(24)
	assert(puppet._attack_phase == puppet.AttackPhase.WINDUP)
	interrupted_enemy.remove_from_group(&"enemies")
	await _frames(18)
	assert(puppet._attack_kind == puppet.AttackKind.NONE and not puppet.attack_hitbox._attack_enabled, "Attack was not interrupted")
	assert(interrupted_enemy.health.current_health == 500.0)
	puppet.despawn()
	await _frames(2)
	interrupted_enemy.queue_free()

	# Golpe final reservado para o fim da duração.
	var final_enemy := _enemy(arena, Vector3(1.8, 0.05, 2.3))
	puppet = _puppet(arena, player, 2.0)
	puppet._next_attack_at = INF
	await _frames(105)
	assert(final_enemy.health.current_health == 500.0 - puppet.final_damage, "Final clap missing or repeated")
	assert(puppet._finale_started and not puppet._bowing)
	await _frames(30)
	assert(get_nodes_in_group(&"grimoire_puppets").is_empty(), "Final puppet did not despawn")
	final_enemy.queue_free()
	var distant_enemy := _enemy(arena, Vector3(1.8, 0.05, 3.9))
	puppet = _puppet(arena, player)
	puppet.slap_range = 4.0
	puppet.headbutt_range = 4.0
	puppet.attack_distance = 3.6
	puppet.slap_damage = 9.0
	puppet.attack_interval = 1.8
	await _frames(60)
	assert(distant_enemy.health.current_health == 491.0, "Configured slap range or damage was ignored")
	assert(puppet._next_attack_at > puppet._elapsed, "Configured attack interval was ignored")
	puppet.despawn()
	await _frames(2)
	distant_enemy.queue_free()
	var elevated_enemy := _enemy(arena, Vector3(1.8, 1.85, 2.3))
	puppet = _puppet(arena, player)
	await _frames(60)
	assert(puppet.target == elevated_enemy and elevated_enemy.health.current_health == 500.0 - puppet.slap_damage, "Reachable elevated target was not hit once")
	await _frames(130)
	assert(elevated_enemy.health.current_health == 500.0 - puppet.slap_damage - puppet.headbutt_damage, "Elevated target missed headbutt or received extra hits")
	puppet.despawn()
	await _frames(2)
	elevated_enemy.queue_free()

	puppet = _puppet(arena, player, 1.2)
	puppet._next_attack_at = INF
	await _frames(50)
	assert(puppet._bowing and puppet._attack_kind == puppet.AttackKind.NONE, "Puppet did not bow without a target")
	await _frames(45)
	assert(get_nodes_in_group(&"grimoire_puppets").is_empty())
	print("PASS: slap, headbutt, style, ally safety, wall, vertical target, switch, interruption, final clap and bow")
	quit()
