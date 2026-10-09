class_name FixedCameraZone
extends Area3D

## Zona editável: a forma ativa a vista e ViewAnchor define a pose da câmera.
@export_range(0.1, 3.0, 0.05) var transition_duration: float = 0.65

@onready var view_anchor: Marker3D = $ViewAnchor
var _camera_rig: Node3D

func _ready() -> void:
	_camera_rig = get_tree().current_scene.get_node("CameraRig") as Node3D
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _exit_tree() -> void:
	if is_instance_valid(_camera_rig):
		_camera_rig.call("unregister_fixed_zone", self)

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		_camera_rig.call("register_fixed_zone", self)

func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		_camera_rig.call("unregister_fixed_zone", self)
