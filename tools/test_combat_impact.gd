extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(20.0).timeout
	push_error("Combat impact test timed out")
	quit(1)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _run() -> void:
	change_scene_to_file("res://scenes/levels/main.tscn")
	await _frames(40)
	var player = current_scene.get_node("Player")
	player.equip_staff()
	var combat = player.combat
	var rig = current_scene.get_node("CameraRig")
	var enemies = get_nodes_in_group("enemies")
	assert(enemies.size() >= 2)
	for enemy in enemies:
		enemy.set_physics_process(false)
	var light = player.get_node("Hitboxes/LightHitbox")
	var heavy = player.get_node("Hitboxes/HeavyHitbox")
	combat.visual_hitstop_max_duration = 0.055
	assert(Engine.time_scale == 1.0)
	combat._start_attack(combat.LIGHT_1, 1)
	assert(not combat._visual_hold_active and rig._shake_strength == 0.0, "A missed attack must not trigger impact feedback")
	light.begin_attack()
	var health_before: float = enemies[0].health.current_health
	var yaw_before: float = rig._yaw
	var pitch_before: float = rig._pitch
	light._on_area_entered(enemies[0].hurtbox)
	assert(enemies[0].health.current_health < health_before, "A confirmed light hit must damage the enemy")
	assert(combat._visual_hold_active and Engine.time_scale == 1.0, "Visual hitstop must leave simulation time unchanged")
	assert(player.is_physics_processing() and combat.is_physics_processing(), "Hitstop must preserve player and combat physics")
	assert(rig._shake_strength > 0.0, "A confirmed hit must trigger camera feedback")
	assert(rig._yaw == yaw_before and rig._pitch == pitch_before, "Impact must not redirect aim")
	assert(not enemies[0].hurtbox._previous_overlays.is_empty(), "A confirmed hit must flash the target")
	var first_deadline: int = combat._visual_hold_until_usec
	light._on_area_entered(enemies[1].hurtbox)
	assert(combat._visual_hold_until_usec >= first_deadline)
	assert(combat._visual_hold_until_usec - Time.get_ticks_usec() <= 60000, "Multiple targets must not add hitstop durations")
	light.end_attack()
	await _frames(12)
	assert(not combat._visual_hold_active and Engine.time_scale == 1.0)
	assert(enemies[0].hurtbox._previous_overlays.is_empty(), "Target flash must restore original overlays")
	assert(rig._shake_strength <= 0.001 and absf(rig.camera.v_offset) < 0.03, "Camera feedback must settle")
	combat.cancel_attack()
	combat._start_attack(combat.HEAVY, 0)
	heavy.begin_attack()
	heavy._on_area_entered(enemies[0].hurtbox)
	assert(combat._visual_hold_active and Engine.time_scale == 1.0)
	assert(combat._visual_hold_until_usec - Time.get_ticks_usec() >= 45000, "Heavy hit must hold visuals longer than light hit")
	heavy.end_attack()
	await _frames(12)
	assert(not combat._visual_hold_active)
	rig.hit_feedback_strength = 0.0
	rig._shake_strength = 0.0
	rig.hit_impulse(0.12, true)
	assert(rig._shake_strength == 0.0, "Camera hit feedback must be disableable")
	print("PASS: confirmed light/heavy hits, miss, simultaneous targets, local visual hold, flash restore, camera toggle")
	quit(0)
