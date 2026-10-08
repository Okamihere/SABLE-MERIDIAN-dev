extends Node3D

@export var world_id: StringName = &"world_01"
@export var world_title := "MUNDO 01"
@export_file("*.tscn") var destination_scene: String

@onready var threshold: Area3D = $Threshold
@onready var status_label: Label3D = $Status
@onready var panel: MeshInstance3D = $Panel

var _player_inside: PlayerController

func _ready() -> void:
	threshold.body_entered.connect(_on_entered)
	threshold.body_exited.connect(_on_exited)
	Progression.world_completed.connect(_on_world_completed)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_player_inside) or AreaTransition.is_travelling:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		Progression.hub_return_world = world_id
		GameManager.reset_style()
		AreaTransition.travel_to(destination_scene)

func _on_entered(body: Node3D) -> void:
	if body is PlayerController and body.is_alive():
		_player_inside = body as PlayerController
		AreaTransition.prepare_scene(destination_scene)
		var hud := get_tree().current_scene.get_node_or_null("HUD")
		if hud != null:
			hud.show_notice(world_title, "F  •  ENTRAR", 2.0)

func _on_exited(body: Node3D) -> void:
	if body == _player_inside:
		_player_inside = null

func _on_world_completed(_id: StringName, _keys: int) -> void:
	_refresh()

func _refresh() -> void:
	var complete := Progression.is_world_complete(world_id)
	var number := String(world_id).trim_prefix("world_")
	var direction := "< %s" % number if position.x < 0 else "%s >" % number
	status_label.text = "%s\n%s" % [direction, "CONCLUÍDO" if complete else "PENDENTE"]
	status_label.modulate = Color(0.72, 0.95, 0.76) if complete else Color(0.82, 0.69, 0.91)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.55, 0.31, 0.72) if complete else Color(0.34, 0.16, 0.48, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.21, 0.7, 0.38) if complete else Color(0.55, 0.24, 0.72)
	panel.material_override = material
