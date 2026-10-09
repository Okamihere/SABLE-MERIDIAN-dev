extends Node3D

## Camadas de palco independentes do modelo substituível da marionete.
const INK := Color(0.055, 0.025, 0.085)
const PAPER := Color(0.75, 0.66, 0.54)
const VIOLET := Color(0.47, 0.22, 0.68)
const GOLD := Color(0.62, 0.36, 0.15)
const SLAP := 1
const HEADBUTT := 2
const FINAL := 3

var _materials: Dictionary = {}
var _omen: Node3D
var _omen_tween: Tween

func play_summon() -> void:
	var curtain := Node3D.new()
	curtain.name = "SummonCurtain"
	add_child(curtain)
	for side in [-1.0, 1.0]:
		_box(curtain, "InkWing", Vector3(side * 0.68, 1.05, -0.28), Vector3(0.55, 1.35, 0.06), INK).rotation.z = -side * 0.3
		_box(curtain, "TornPage", Vector3(side * 0.89, 0.69, -0.21), Vector3(0.32, 0.14, 0.035), PAPER).rotation.z = side * 0.24
		_box(curtain, "PullThread", Vector3(side * 0.32, 1.3, 0.4), Vector3(0.024, 1.7, 0.024), GOLD).rotation.z = side * 0.23
	_box(curtain, "StageArch", Vector3(0, 1.81, -0.29), Vector3(1.72, 0.11, 0.07), GOLD)
	curtain.scale = Vector3(0.2, 0.25, 0.2)
	var tween := curtain.create_tween()
	tween.tween_property(curtain, "scale", Vector3.ONE * 1.14, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(curtain, "scale", Vector3.ONE * 0.8, 0.09)
	tween.tween_property(curtain, "scale", Vector3.ZERO, 0.13)
	tween.finished.connect(curtain.queue_free)

func play_windup(kind: int, duration: float) -> void:
	clear_omen()
	_omen = Node3D.new()
	_omen.name = "AttackOmen"
	add_child(_omen)
	match kind:
		SLAP:
			_omen.position = Vector3(-0.2, 1.32, 1.18)
			for i in 3:
				_box(_omen, "SlapInkLine", Vector3(0, (float(i) - 1.0) * 0.15, 0), Vector3(0.95 - float(i) * 0.16, 0.045, 0.03), VIOLET if i == 1 else INK).rotation.z = -0.16
			_box(_omen, "PagePalm", Vector3(0.52, 0, 0.04), Vector3(0.25, 0.34, 0.03), PAPER).rotation.z = -0.2
		HEADBUTT:
			_omen.position = Vector3(0, 1.62, 0.82)
			for side in [-1.0, 1.0]:
				_box(_omen, "InkHorn", Vector3(side * 0.34, 0.18, 0), Vector3(0.12, 0.58, 0.035), INK).rotation.z = -side * 0.55
				_box(_omen, "PaperFang", Vector3(side * 0.22, -0.22, 0.04), Vector3(0.1, 0.34, 0.03), PAPER).rotation.z = side * 0.25
			_box(_omen, "ThirdEye", Vector3(0, 0.12, 0.07), Vector3(0.15, 0.15, 0.03), VIOLET).rotation.z = PI * 0.25
		FINAL:
			_omen.position = Vector3(0, 1.14, 1.26)
			for side in [-1.0, 1.0]:
				_box(_omen, "FinalCurtain", Vector3(side * 0.92, 0, 0), Vector3(0.36, 1.25, 0.06), INK).rotation.z = side * 0.12
				_box(_omen, "PaperHem", Vector3(side * 0.92, -0.63, 0.04), Vector3(0.34, 0.1, 0.03), PAPER)
			_box(_omen, "CenterBell", Vector3(0, 0.55, 0.05), Vector3(0.2, 0.2, 0.04), GOLD).rotation.z = PI * 0.25
	_omen.scale = Vector3(0.25, 0.75, 0.25)
	_omen_tween = _omen.create_tween()
	_omen_tween.tween_property(_omen, "scale", Vector3.ONE, maxf(duration * 0.88, 0.08)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func play_release(kind: int) -> void:
	if not is_instance_valid(_omen):
		return
	if is_instance_valid(_omen_tween):
		_omen_tween.kill()
	var old := _omen
	_omen = null
	var tween := old.create_tween()
	if kind == FINAL:
		tween.tween_property(old, "scale", Vector3(0.08, 1.2, 1.0), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(old, "scale", Vector3(1.4, 0.2, 1.0), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(old, "scale", Vector3.ZERO, 0.07)
	tween.finished.connect(old.queue_free)

func play_hit(kind: int, at: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var burst := Node3D.new()
	burst.name = "PuppetFinalImpact" if kind == FINAL else ("PuppetHeadImpact" if kind == HEADBUTT else "PuppetSlapImpact")
	scene.add_child(burst)
	burst.global_position = at + Vector3.UP * (0.3 if kind == FINAL else 0.16)
	var camera := get_viewport().get_camera_3d()
	if camera != null and burst.global_position.distance_squared_to(camera.global_position) > 0.01:
		burst.look_at(camera.global_position, Vector3.UP, true)
	var count := 8 if kind == FINAL else (6 if kind == HEADBUTT else 4)
	var radius := 0.77 if kind == FINAL else (0.52 if kind == HEADBUTT else 0.38)
	for i in count:
		var angle := TAU * float(i) / float(count) + (PI * 0.25 if kind == SLAP else 0.0)
		_box(burst, "InkStroke", Vector3(cos(angle) * radius, sin(angle) * radius, 0), Vector3(0.06, 0.29 if kind == FINAL else 0.22, 0.025), VIOLET if i % 2 else INK).rotation.z = angle - PI * 0.5
		if i % 2 == 0:
			_box(burst, "TornPage", Vector3(cos(angle) * radius * 1.22, sin(angle) * radius * 1.22, 0.04), Vector3(0.13, 0.18, 0.02), PAPER).rotation.z = angle
	if kind == HEADBUTT:
		_box(burst, "HeadbuttCompression", Vector3(0, 0, 0.07), Vector3(0.32, 0.48, 0.025), PAPER).rotation.z = PI * 0.25
	elif kind == FINAL:
		_box(burst, "FinalFlash", Vector3(0, 0, 0.07), Vector3(0.53, 0.53, 0.025), VIOLET).rotation.z = PI * 0.25
		_box(burst, "PaperSeal", Vector3(0, 0, 0.1), Vector3(0.26, 0.26, 0.025), PAPER).rotation.z = PI * 0.25
	else:
		_box(burst, "SlapSlash", Vector3(0, 0, 0.07), Vector3(0.85, 0.08, 0.025), PAPER).rotation.z = -0.18
	var tween := burst.create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * (1.32 if kind == FINAL else 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "scale", Vector3.ZERO, 0.13)
	tween.finished.connect(burst.queue_free)

func play_farewell() -> void:
	clear_omen()
	var threads := Node3D.new()
	threads.name = "FarewellThreads"
	add_child(threads)
	for side in [-1.0, 1.0]:
		_box(threads, "GoldenThread", Vector3(side * 0.38, 1.2, 0.4), Vector3(0.026, 2.1, 0.026), GOLD).rotation.z = side * 0.16
		_box(threads, "ProtestingPage", Vector3(side * 0.68, 0.55, 0.35), Vector3(0.25, 0.34, 0.025), PAPER).rotation.z = side * 0.31
	var tween := threads.create_tween()
	tween.tween_property(threads, "position:y", 0.7, 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(threads, "scale", Vector3(0.38, 1.22, 0.38), 0.52)
	tween.tween_property(threads, "scale", Vector3.ZERO, 0.2)
	tween.finished.connect(threads.queue_free)

func play_despawn() -> void:
	clear_omen()
	var scene := get_tree().current_scene
	if scene == null:
		return
	var knot := Node3D.new()
	knot.name = "PuppetFarewellKnot"
	scene.add_child(knot)
	knot.global_position = global_position + Vector3.UP * 1.1
	for side in [-1.0, 1.0]:
		_box(knot, "SnappedThread", Vector3(side * 0.22, 0.1, 0), Vector3(0.025, 0.86, 0.025), GOLD).rotation.z = side * 0.45
		_box(knot, "InkProtest", Vector3(side * 0.34, -0.17, 0), Vector3(0.25, 0.36, 0.03), INK).rotation.z = -side * 0.29
	var tween := knot.create_tween()
	tween.tween_property(knot, "position:y", knot.position.y + 0.55, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(knot, "scale", Vector3.ZERO, 0.18)
	tween.finished.connect(knot.queue_free)

func clear_omen() -> void:
	if is_instance_valid(_omen_tween):
		_omen_tween.kill()
	if is_instance_valid(_omen):
		_omen.queue_free()
	_omen = null

func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		_materials[color] = material
	part.material_override = _materials[color]
	parent.add_child(part)
	return part
