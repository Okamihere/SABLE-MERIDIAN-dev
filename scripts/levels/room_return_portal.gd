extends Node3D

@export_file("*.tscn") var destination_scene: String
@export var destination_name := "SALA ANTERIOR"
@export var return_world_id: StringName = &""
@export var use_arrival_position := false
@export var arrival_position := Vector3.ZERO
@export var arrival_rotation_y := 0.0

@onready var threshold: Area3D = $Threshold

var _player_inside: PlayerController
var _activated := false

func _ready() -> void:
	threshold.body_entered.connect(_on_entered)
	threshold.body_exited.connect(_on_exited)

func _physics_process(_delta: float) -> void:
	if _activated or AreaTransition.is_travelling or not is_instance_valid(_player_inside):
		return
	var local_position := to_local(_player_inside.global_position)
	if not _player_inside.is_alive() or local_position.z < 0.0 or absf(local_position.x) > 2.5:
		return
	_activated = true
	if return_world_id != &"":
		Progression.hub_return_world = return_world_id
	GameManager.reset_style()
	if use_arrival_position:
		AreaTransition.travel_to(destination_scene, {"position": arrival_position, "rotation_y": arrival_rotation_y})
	else:
		AreaTransition.travel_to(destination_scene)

func _on_entered(body: Node3D) -> void:
	if body is PlayerController and body.is_alive():
		_player_inside = body as PlayerController
		AreaTransition.prepare_scene(destination_scene)
		var hud := get_tree().current_scene.get_node_or_null("HUD")
		if hud != null:
			hud.show_notice(destination_name, "ATRAVESSE O ARCO", 2.0)

func _on_exited(body: Node3D) -> void:
	if body == _player_inside:
		_player_inside = null
