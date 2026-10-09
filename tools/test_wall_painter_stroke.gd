extends SceneTree

const STROKE := preload("res://addons/sable_wall_painter/wall_stroke.gd")


func _initialize() -> void:
	var path: Array[Vector3i] = []
	assert(STROKE.add_cell(path, Vector3i(0, 0, 0)))
	assert(STROKE.add_cell(path, Vector3i(4, 0, 0)))
	assert(path.size() == 5)
	for index in range(5):
		assert(path[index] == Vector3i(index, 0, 0))
	for entry in STROKE.plan(path, 0):
		assert(not entry.turn and entry.quarter == 0)
	for entry in STROKE.plan(path, 2):
		assert(not entry.turn and entry.quarter == 2)
	assert(STROKE.add_cell(path, Vector3i(4, 0, 3)))
	assert(path.size() == 8)
	var entries: Array[Dictionary] = STROKE.plan(path, 0)
	assert(entries[4].turn and entries[4].cell == Vector3i(4, 0, 0))
	for index in range(5, 8):
		assert(not entries[index].turn and entries[index].quarter == 1)
	assert(not STROKE.add_cell(path, Vector3i(6, 0, 5)))
	assert(path.size() == 8)
	assert(not STROKE.add_cell(path, Vector3i(4, 0, 1)))
	assert(path.size() == 8)
	assert(not STROKE.add_cell(path, Vector3i(4, 1, 4)))
	assert(path.size() == 8)
	var z_path: Array[Vector3i] = []
	assert(STROKE.add_cell(z_path, Vector3i(0, 0, 0)))
	assert(STROKE.add_cell(z_path, Vector3i(0, 0, -3)))
	for entry in STROKE.plan(z_path, 3):
		assert(not entry.turn and entry.quarter == 3)
	var single: Array[Vector3i] = [Vector3i(2, 0, 2)]
	assert(STROKE.plan(single, 2)[0].quarter == 2)
	print("PASS: interpolacao X/Z, quatro orientacoes, curva reservada, diagonal/retorno/camada invalidos")
	quit()
