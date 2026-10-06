extends SceneTree

const WEAPONS := [&"staff", &"card_daggers", &"puppet_strings", &"cane_blade", &"living_grimoire"]
const SKILLS := [&"cursed_deck", &"staff_e", &"staff_r", &"dagger_q", &"dagger_e", &"dagger_r", &"strings_q", &"strings_e", &"strings_r", &"cane_q", &"cane_e", &"cane_r", &"grimoire_q", &"grimoire_e", &"grimoire_r"]
var _motion: Script

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_motion = load("res://scripts/player/weapon_display.gd")
	assert(_motion != null)
	var signatures := {}
	for weapon in WEAPONS:
		for stage in range(1, 5):
			_check_motion(&"basic", weapon, stage, signatures)
		_check_motion(&"heavy", weapon, 0, signatures)
		_check_finisher(weapon)
	for ability in SKILLS:
		_check_motion(&"skill", ability, 0, signatures)
	assert(signatures.size() == 40, "All 40 actions need different trajectories")
	print("PASS: 20 basics, 5 heavies, 15 skills; distinct paths and wide finishers")
	quit()

func _check_motion(kind: StringName, id: StringName, stage: int, signatures: Dictionary) -> void:
	var signature := ""
	var movement := 0.0
	for time in [0.16, 0.3, 0.46, 0.62, 0.78]:
		var pose: Dictionary = _motion.sample_motion(kind, id, stage, time)
		var point: Vector3 = pose.position
		movement += point.length()
		signature += "%.3f,%.3f,%.3f;" % [point.x, point.y, point.z]
	assert(movement > 0.3, "Visible travel missing: %s %s %d" % [kind, id, stage])
	assert(not signatures.has(signature), "Duplicate path: %s %s %d" % [kind, id, stage])
	signatures[signature] = true
	assert((_motion.sample_motion(kind, id, stage, 0.0).position as Vector3).length() < 0.001)
	assert((_motion.sample_motion(kind, id, stage, 1.0).position as Vector3).length() < 0.001)

func _check_finisher(weapon: StringName) -> void:
	var previous_angle := 0.0
	var arc := 0.0
	for index in range(17):
		var t := 0.04 + float(index) * 0.021
		var point: Vector3 = _motion.sample_motion(&"basic", weapon, 4, t).position
		var angle := atan2(point.z, point.x)
		if index > 0:
			arc += absf(wrapf(angle - previous_angle, -PI, PI))
		previous_angle = angle
	assert(arc > PI, "Finisher must arc around body before 40%%: %s" % weapon)
	var contact: Vector3 = _motion.sample_motion(&"basic", weapon, 4, 0.45).position
	assert(contact.z > 0.6, "Finisher must advance before impact: %s" % weapon)
