extends RefCounted

const MAX_CELLS := 512


static func add_cell(path: Array[Vector3i], target: Vector3i) -> bool:
	if path.is_empty():
		path.append(target)
		return true
	var start: Vector3i = path.back()
	var delta: Vector3i = target - start
	if delta == Vector3i.ZERO:
		return true
	if delta.y != 0 or (delta.x != 0 and delta.z != 0):
		return false
	var axis_step := Vector3i(signi(delta.x), 0, signi(delta.z))
	var distance := absi(delta.x) + absi(delta.z)
	if path.size() + distance > MAX_CELLS:
		return false
	for index in range(1, distance + 1):
		if path.has(start + axis_step * index):
			return false
	for index in range(1, distance + 1):
		path.append(start + axis_step * index)
	return true


static func plan(path: Array[Vector3i], reference_quarter: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(path.size()):
		var before := Vector3i.ZERO if index == 0 else path[index] - path[index - 1]
		var after := Vector3i.ZERO if index == path.size() - 1 else path[index + 1] - path[index]
		var turn := before != Vector3i.ZERO and after != Vector3i.ZERO and _axis(before) != _axis(after)
		if turn:
			result.append({"cell": path[index], "turn": true, "quarter": -1})
			continue
		var step := after if after != Vector3i.ZERO else before
		var quarter := posmod(reference_quarter, 4) if step == Vector3i.ZERO else _choose_quarter(_axis(step), reference_quarter)
		result.append({"cell": path[index], "turn": false, "quarter": quarter})
	return result


static func _axis(step: Vector3i) -> int:
	return 0 if step.x != 0 else 1


static func _choose_quarter(axis: int, reference_quarter: int) -> int:
	var first := 0 if axis == 0 else 1
	var second := first + 2
	var reference := posmod(reference_quarter, 4)
	var first_turns := posmod(first - reference, 4)
	var second_turns := posmod(second - reference, 4)
	var first_cost := mini(first_turns, 4 - first_turns)
	var second_cost := mini(second_turns, 4 - second_turns)
	if first_cost != second_cost:
		return first if first_cost < second_cost else second
	return first if first_turns < second_turns else second
