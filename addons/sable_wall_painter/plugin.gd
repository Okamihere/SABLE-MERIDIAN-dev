@tool
extends EditorPlugin

const STROKE := preload("res://addons/sable_wall_painter/wall_stroke.gd")
const LIBRARY := preload("res://resources/gridmap/sable_graybox_mesh_library.tres")
const TOOLTIP := "Pinte paredes retas automaticamente. Use Selecionar no GridMap para ocultar a previsualizacao nativa."
const MAX_OVERLAY_CELLS := 32

var _toolbar: HBoxContainer
var _toggle: Button
var _item_picker: OptionButton
var _rotation_picker: OptionButton
var _layer_picker: SpinBox
var _grid: GridMap
var _painting := false
var _path: Array[Vector3i] = []
var _hover_valid := false
var _hover_cell := Vector3i.ZERO
var _hover_occupied := false
var _stroke_invalid := false
var _preview: Array[MeshInstance3D] = []
var _overlay_cells: Array[Dictionary] = []
var _preview_camera: Camera3D
var _turn_mesh: BoxMesh
var _valid_material: StandardMaterial3D
var _blocked_material: StandardMaterial3D
var _turn_material: StandardMaterial3D


func _enter_tree() -> void:
	# This list receives input before the built-in GridMap painter in Godot 4.7.2.
	set_input_event_forwarding_always_enabled()
	set_force_draw_over_forwarding_enabled()
	_valid_material = _preview_material(Color(0.35, 0.95, 0.66, 0.55))
	_blocked_material = _preview_material(Color(1.0, 0.25, 0.3, 0.65))
	_turn_material = _preview_material(Color(1.0, 0.7, 0.18, 0.65))
	_turn_mesh = BoxMesh.new()
	_toolbar = HBoxContainer.new()
	_toggle = Button.new()
	_toggle.text = "Autoalinhar paredes"
	_toggle.toggle_mode = true
	_toggle.tooltip_text = TOOLTIP
	_toggle.toggled.connect(_on_toggled)
	_toolbar.add_child(_toggle)
	_item_picker = OptionButton.new()
	_item_picker.add_item("01 Parede", 1)
	_item_picker.add_item("05 Wall Jump", 5)
	_item_picker.item_selected.connect(_on_setting_changed)
	_toolbar.add_child(_item_picker)
	_rotation_picker = OptionButton.new()
	for quarter in range(4):
		_rotation_picker.add_item("%d°" % (quarter * 90), quarter)
	_rotation_picker.item_selected.connect(_on_setting_changed)
	_rotation_picker.tooltip_text = "Lado inicial da parede. A direcao do arrasto decide o eixo."
	_toolbar.add_child(_rotation_picker)
	_layer_picker = SpinBox.new()
	_layer_picker.min_value = -64
	_layer_picker.max_value = 64
	_layer_picker.step = 1
	_layer_picker.custom_minimum_size.x = 68
	_layer_picker.tooltip_text = "Camada Y do GridMap"
	_layer_picker.value_changed.connect(_on_layer_changed)
	_toolbar.add_child(_layer_picker)
	_toolbar.hide()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)


func _exit_tree() -> void:
	_cancel_stroke()
	_clear_preview()
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)
	_toolbar.queue_free()


func _handles(object: Object) -> bool:
	return object is GridMap


func _edit(object: Object) -> void:
	var candidate := object as GridMap
	var next_grid: GridMap = null
	if candidate != null and candidate.name == &"Walls" and candidate.mesh_library == LIBRARY:
		next_grid = candidate
	if _grid != next_grid:
		_cancel_stroke()
		_clear_preview()
		_grid = next_grid
		_toggle.set_pressed_no_signal(false)
	_toolbar.visible = _grid != null


func _make_visible(visible: bool) -> void:
	if not visible:
		_cancel_stroke()
		_clear_preview()
		_grid = null
		_toggle.set_pressed_no_signal(false)
	_toolbar.visible = visible and _grid != null


func _on_toggled(enabled: bool) -> void:
	_cancel_stroke()
	_clear_preview()
	_set_status("Arraste em X/Z" if enabled else "")


func _on_setting_changed(_index: int) -> void:
	_cancel_stroke()
	_refresh_preview()


func _on_layer_changed(_value: float) -> void:
	_cancel_stroke()
	_hover_valid = false
	_refresh_preview()


func _process(_delta: float) -> void:
	# Undo/Redo can change the cell under a stationary cursor.
	if _toggle != null and _toggle.button_pressed and _hover_valid and not _painting and is_instance_valid(_grid):
		var occupied := _grid.get_cell_item(_hover_cell) != GridMap.INVALID_CELL_ITEM
		if occupied != _hover_occupied:
			_refresh_preview()


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _toggle == null or not _toggle.button_pressed or not is_instance_valid(_grid):
		return AFTER_GUI_INPUT_PASS
	_preview_camera = camera
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _painting:
			_cancel_stroke()
			_refresh_preview()
			return AFTER_GUI_INPUT_STOP
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_update_hover(camera, event.position)
		if event.pressed:
			_cancel_stroke()
			_painting = _hover_valid
			if _painting:
				STROKE.add_cell(_path, _hover_cell)
		else:
			if _painting:
				_add_hover_to_stroke()
				_commit_stroke()
			_painting = false
		_refresh_preview()
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion:
		_update_hover(camera, event.position)
		if _painting and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_add_hover_to_stroke()
		_refresh_preview()
		return AFTER_GUI_INPUT_STOP if event.button_mask & MOUSE_BUTTON_MASK_LEFT else AFTER_GUI_INPUT_PASS
	return AFTER_GUI_INPUT_PASS


func _forward_3d_force_draw_over_viewport(overlay: Control) -> void:
	if _toggle == null or not _toggle.button_pressed or not is_instance_valid(_grid) or not is_instance_valid(_preview_camera):
		return
	if not Rect2(Vector2.ZERO, overlay.size).has_point(overlay.get_local_mouse_position()):
		return
	for index in range(maxi(0, _overlay_cells.size() - MAX_OVERLAY_CELLS), _overlay_cells.size()):
		_draw_cell_outline(overlay, _overlay_cells[index])


func _draw_cell_outline(overlay: Control, entry: Dictionary) -> void:
	var cell: Vector3i = entry.cell
	var center := _grid.map_to_local(cell)
	var half_x := _grid.cell_size.x * 0.5
	var half_z := _grid.cell_size.z * 0.5
	var corners := PackedVector2Array()
	for offset in [Vector3(-half_x, 0, -half_z), Vector3(half_x, 0, -half_z), Vector3(half_x, 0, half_z), Vector3(-half_x, 0, half_z)]:
		var point := _grid.to_global(center + offset)
		if _preview_camera.is_position_behind(point):
			return
		corners.append(_preview_camera.unproject_position(point))
	var color := _valid_material.albedo_color
	if entry.turn:
		color = _turn_material.albedo_color
	elif entry.blocked:
		color = _blocked_material.albedo_color
	color.a = 0.95
	overlay.draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]), color, 2.0, true)
	if entry.turn or entry.blocked:
		overlay.draw_line(corners[0], corners[2], color, 2.0, true)
		if entry.turn or entry.get("invalid", false):
			overlay.draw_line(corners[1], corners[3], color, 2.0, true)
		return
	var mesh := LIBRARY.get_item_mesh(_selected_item())
	var bounds := mesh.get_aabb()
	var mid_y := bounds.position.y + bounds.size.y * 0.7
	var mid_z := bounds.position.z + bounds.size.z * 0.5
	var basis := _grid.get_basis_with_orthogonal_index(_orientation_index(entry.quarter))
	var item_transform := Transform3D(basis, center) * LIBRARY.get_item_mesh_transform(_selected_item())
	var start := _grid.to_global(item_transform * Vector3(bounds.position.x, mid_y, mid_z))
	var end := _grid.to_global(item_transform * Vector3(bounds.end.x, mid_y, mid_z))
	if not _preview_camera.is_position_behind(start) and not _preview_camera.is_position_behind(end):
		overlay.draw_line(_preview_camera.unproject_position(start), _preview_camera.unproject_position(end), color, 3.0, true)


func _update_hover(camera: Camera3D, screen_position: Vector2) -> void:
	_hover_valid = false
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var local_origin := _grid.to_local(ray_origin)
	var local_direction := _grid.global_transform.basis.inverse() * ray_direction
	if absf(local_direction.y) < 0.0001:
		return
	var layer := int(_layer_picker.value)
	var plane_y := _grid.map_to_local(Vector3i(0, layer, 0)).y
	var distance := (plane_y - local_origin.y) / local_direction.y
	if distance < 0.0:
		return
	var local_hit := local_origin + local_direction * distance
	local_hit.y = plane_y
	_hover_cell = _grid.local_to_map(local_hit)
	_hover_cell.y = layer
	_hover_valid = true


func _add_hover_to_stroke() -> void:
	if _stroke_invalid or not _hover_valid:
		return
	if not STROKE.add_cell(_path, _hover_cell):
		_stroke_invalid = true
		_set_status("Diagonal/retorno ambiguo: solte e recomece")


func _commit_stroke() -> void:
	if _stroke_invalid or _path.is_empty() or not is_instance_valid(_grid):
		_cancel_stroke()
		return
	var changes: Array[Dictionary] = []
	for entry in STROKE.plan(_path, _reference_quarter()):
		if entry.turn:
			continue
		var cell: Vector3i = entry.cell
		if _grid.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM:
			continue
		var quarter: int = entry.quarter
		changes.append({"cell": cell, "item": _selected_item(), "orientation": _orientation_index(quarter), "old_item": _grid.get_cell_item(cell), "old_orientation": _grid.get_cell_item_orientation(cell)})
	if not changes.is_empty():
		var undo := get_undo_redo()
		undo.create_action("Pintar paredes alinhadas", UndoRedo.MERGE_DISABLE, _grid)
		for change in changes:
			undo.add_do_method(_grid, &"set_cell_item", change.cell, change.item, change.orientation)
			undo.add_undo_method(_grid, &"set_cell_item", change.cell, change.old_item, change.old_orientation)
		undo.commit_action()
	_cancel_stroke()


func _reference_quarter() -> int:
	return _rotation_picker.get_selected_id()


func _selected_item() -> int:
	return _item_picker.get_selected_id()


func _orientation_index(quarter: int) -> int:
	return _grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, float(quarter) * PI * 0.5))


func _refresh_preview() -> void:
	if _toggle == null or not _toggle.button_pressed or not is_instance_valid(_grid):
		_hide_preview()
		return
	if not _hover_valid:
		_hide_preview()
		return
	if _stroke_invalid:
		_show_marker(_hover_cell, _blocked_material)
		return
	var hover_path: Array[Vector3i] = []
	if _painting:
		hover_path.assign(_path)
	if hover_path.is_empty() or hover_path.back() != _hover_cell:
		if not STROKE.add_cell(hover_path, _hover_cell):
			_show_marker(_hover_cell, _blocked_material)
			return
	var entries := STROKE.plan(hover_path, _reference_quarter())
	_hover_occupied = _grid.get_cell_item(_hover_cell) != GridMap.INVALID_CELL_ITEM
	_ensure_preview_count(entries.size())
	_overlay_cells.clear()
	var has_turn := false
	var has_blocked := false
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var cell: Vector3i = entry.cell
		var node := _preview[index]
		node.visible = true
		if entry.turn:
			has_turn = true
			_set_marker(node, cell, _turn_material)
			_overlay_cells.append({"cell": cell, "quarter": -1, "turn": true, "blocked": false})
		else:
			var occupied := _grid.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM
			has_blocked = has_blocked or occupied
			_set_wall_preview(node, cell, entry.quarter, _blocked_material if occupied else _valid_material)
			_overlay_cells.append({"cell": cell, "quarter": entry.quarter, "turn": false, "blocked": occupied})
	for index in range(entries.size(), _preview.size()):
		_preview[index].hide()
	if has_turn:
		_set_status("Canto reservado: coloque manualmente")
	elif has_blocked:
		_set_status("Vermelho: celula ocupada")
	else:
		_set_status("Arraste em X/Z")
	update_overlays()


func _show_marker(cell: Vector3i, material: Material) -> void:
	_ensure_preview_count(1)
	_set_marker(_preview[0], cell, material)
	_preview[0].show()
	for index in range(1, _preview.size()):
		_preview[index].hide()
	_overlay_cells.assign([{"cell": cell, "quarter": -1, "turn": false, "blocked": true, "invalid": true}])
	update_overlays()


func _set_marker(node: MeshInstance3D, cell: Vector3i, material: Material) -> void:
	_turn_mesh.size = Vector3(_grid.cell_size.x, 0.05, _grid.cell_size.z)
	node.mesh = _turn_mesh
	node.material_override = material
	node.transform = Transform3D(Basis.IDENTITY, _grid.map_to_local(cell) + Vector3.UP * 0.04)


func _set_wall_preview(node: MeshInstance3D, cell: Vector3i, quarter: int, material: Material) -> void:
	var item := _selected_item()
	node.mesh = LIBRARY.get_item_mesh(item)
	node.material_override = material
	var basis := _grid.get_basis_with_orthogonal_index(_orientation_index(quarter))
	node.transform = Transform3D(basis, _grid.map_to_local(cell)) * LIBRARY.get_item_mesh_transform(item)


func _ensure_preview_count(count: int) -> void:
	while _preview.size() < count:
		var node := MeshInstance3D.new()
		node.name = "WallPainterPreview"
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_grid.add_child(node)
		_preview.append(node)


func _hide_preview() -> void:
	for node in _preview:
		if is_instance_valid(node):
			node.hide()
	_overlay_cells.clear()
	update_overlays()


func _clear_preview() -> void:
	for node in _preview:
		if is_instance_valid(node):
			node.queue_free()
	_preview.clear()
	_overlay_cells.clear()
	update_overlays()


func _cancel_stroke() -> void:
	_painting = false
	_path.clear()
	_stroke_invalid = false


func _preview_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = false
	return material


func _set_status(message: String) -> void:
	_toggle.tooltip_text = TOOLTIP if message.is_empty() else TOOLTIP + "\n" + message
