extends SceneTree

const WEAPONS := [&"staff", &"card_daggers", &"puppet_strings", &"cane_blade", &"living_grimoire", &"echo_blade"]
var _display_script: Script

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_display_script = load("res://scripts/player/weapon_display.gd")
	assert(_display_script != null)
	var signatures := {}
	for weapon in WEAPONS:
		var period: float = _display_script.IDLE_PERIODS[weapon]
		var first: Dictionary = _display_script.sample_idle(weapon, 0.0)
		var last: Dictionary = _display_script.sample_idle(weapon, period)
		var signature := ""
		for key in first:
			assert(_distance(first[key], last[key]) < 0.00001, "Idle não fecha o loop: %s" % weapon)
			assert(_distance(_display_script.sample_idle(weapon, 0.001)[key], _display_script.sample_idle(weapon, period + 0.001)[key]) < 0.00001)
		for fraction in [0.17, 0.38, 0.61, 0.83]:
			var pose: Dictionary = _display_script.sample_idle(weapon, period * fraction)
			var travel: Vector3 = pose.position
			signature += "%.4f,%.4f,%.4f,%.4f,%.4f;" % [travel.x, travel.y, travel.z, pose.tilt, pose.pitch]
		assert(not signatures.has(signature), "Idle repetido: %s" % weapon)
		signatures[signature] = true
	assert(change_scene_to_file("res://scenes/levels/start_room.tscn") == OK)
	for i in 10:
		await process_frame
	var player := current_scene.get_node("Player")
	var display := player.get_node("WeaponDisplay")
	for weapon in WEAPONS:
		display.show_weapon(weapon)
		display._process(0.1)
		assert(display._idle_blend > 0.0, "Idle não iniciou: %s" % weapon)
		var phase: float = display._idle_time
		display.show_weapon(weapon)
		assert(is_equal_approx(display._idle_time, phase), "Idle reiniciou ao manter arma: %s" % weapon)
		display.play_basic(weapon, 1, 0.5)
		display._process(0.02)
		assert(display._idle_blend == 0.0, "Idle não parou no ataque: %s" % weapon)
		display.stop_action()
		display._process(0.02)
		assert(display._idle_blend > 0.0, "Idle não retornou: %s" % weapon)
	display.play_skill(&"staff_e", 0.5)
	display._process(0.02)
	assert(display._idle_blend == 0.0 and display._action_kind == &"skill", "Idle não cedeu à skill")
	display.stop_action()
	player.state_machine.set_state(PlayerStateMachine.State.MOVE)
	display._process(0.02)
	assert(display._idle_blend == 0.0, "Idle não parou no movimento")
	player.state_machine.set_state(PlayerStateMachine.State.DODGE)
	display._process(0.02)
	assert(display._idle_blend == 0.0, "Idle não parou na esquiva")
	player.state_machine.set_state(PlayerStateMachine.State.IDLE)
	display._process(0.02)
	assert(display._idle_blend > 0.0, "Idle não retomou após esquiva")
	print("WEAPON IDLE PASS: 6 loops únicos, transições e fase preservada")
	quit(0)

func _distance(a: Variant, b: Variant) -> float:
	if a is Vector3:
		return (a as Vector3).distance_to(b)
	return absf(float(a) - float(b))
