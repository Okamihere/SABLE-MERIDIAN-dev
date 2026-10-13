@tool
extends Node
class_name SablePaletteRegion

## Adicione este nó como filho direto de um mundo para variar sua atmosfera.
@export var profile: SableRegionPalette:
	set(value):
		if Engine.is_editor_hint() and is_inside_tree() and profile != null and profile.changed.is_connected(queue_redraw_preview):
			profile.changed.disconnect(queue_redraw_preview)
		profile = value
		if Engine.is_editor_hint() and is_inside_tree() and profile != null:
			profile.changed.connect(queue_redraw_preview)
		queue_redraw_preview()
@export var tint_targets: Array[NodePath] = []:
	set(value):
		tint_targets = value
		queue_redraw_preview()

const ART_DIRECTION = preload("res://scripts/systems/art_direction.gd")
const BASE_PALETTE: SableArtPalette = preload("res://resources/palettes/sable_default.tres")

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	BASE_PALETTE.changed.connect(queue_redraw_preview)
	if profile != null:
		profile.changed.connect(queue_redraw_preview)
	queue_redraw_preview()

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		return
	if BASE_PALETTE.changed.is_connected(queue_redraw_preview):
		BASE_PALETTE.changed.disconnect(queue_redraw_preview)
	if profile != null and profile.changed.is_connected(queue_redraw_preview):
		profile.changed.disconnect(queue_redraw_preview)

func queue_redraw_preview() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		call_deferred("_preview")

func _preview() -> void:
	if get_parent() != null and profile != null:
		ART_DIRECTION.apply_shared_assets(BASE_PALETTE)
		ART_DIRECTION.apply_scene_visuals(get_parent(), BASE_PALETTE, profile, self)
