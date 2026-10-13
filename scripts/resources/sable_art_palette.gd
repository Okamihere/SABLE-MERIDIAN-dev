@tool
extends Resource
class_name SableArtPalette

## Cores-base extraídas do Jester e dos materiais já usados no projeto.
@export_group("Personagem e destaques")
@export var ink := Color(0.045, 0.045, 0.075):
	set(value): ink = value; emit_changed()
@export var plum := Color(0.24, 0.075, 0.27):
	set(value): plum = value; emit_changed()
@export var violet := Color(0.55, 0.27, 0.7):
	set(value): violet = value; emit_changed()
@export var wine := Color(0.38, 0.055, 0.19):
	set(value): wine = value; emit_changed()
@export var magenta := Color(0.62, 0.07, 0.31):
	set(value): magenta = value; emit_changed()
@export var gold := Color(0.76, 0.55, 0.25):
	set(value): gold = value; emit_changed()
@export var ivory := Color(0.88, 0.82, 0.68):
	set(value): ivory = value; emit_changed()

@export_group("Arquitetura")
@export var stone_dark := Color(0.105, 0.115, 0.15):
	set(value): stone_dark = value; emit_changed()
@export var stone_mid := Color(0.278, 0.263, 0.31):
	set(value): stone_mid = value; emit_changed()
@export var stone_light := Color(0.19, 0.18, 0.24):
	set(value): stone_light = value; emit_changed()

@export_group("Luz e atmosfera")
@export var ambient := Color(0.7, 0.64, 0.75):
	set(value): ambient = value; emit_changed()
@export var key_light := Color(0.91, 0.84, 0.96):
	set(value): key_light = value; emit_changed()
@export var fog := Color(0.18, 0.12, 0.29):
	set(value): fog = value; emit_changed()
@export var cool_light := Color(0.78, 0.73, 0.93):
	set(value): cool_light = value; emit_changed()
@export var cool_accent := Color(0.28, 0.72, 0.82):
	set(value): cool_accent = value; emit_changed()

func color(role: StringName) -> Color:
	match role:
		&"ink": return ink
		&"plum": return plum
		&"violet": return violet
		&"wine": return wine
		&"magenta": return magenta
		&"gold": return gold
		&"ivory": return ivory
		&"stone_dark": return stone_dark
		&"stone_mid": return stone_mid
		&"stone_light": return stone_light
		&"ambient": return ambient
		&"key_light": return key_light
		&"fog": return fog
		&"cool_light": return cool_light
		&"cool_accent": return cool_accent
	return Color.WHITE
