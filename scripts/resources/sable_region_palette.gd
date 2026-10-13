@tool
extends Resource
class_name SableRegionPalette

## Multiplicadores locais: 1 preserva a paleta principal.
@export var ambient_tint := Color.WHITE:
	set(value):
		ambient_tint = value
		emit_changed()
@export var light_tint := Color.WHITE:
	set(value):
		light_tint = value
		emit_changed()
@export var fog_tint := Color.WHITE:
	set(value):
		fog_tint = value
		emit_changed()
@export var accent_tint := Color.WHITE:
	set(value):
		accent_tint = value
		emit_changed()
@export var terrain_tint := Color.WHITE:
	set(value):
		terrain_tint = value
		emit_changed()
