extends Node3D

@onready var player: PlayerController = $Player
@onready var key_sign: Label3D = $HubKeySign

func _ready() -> void:
	Progression.world_completed.connect(_on_world_completed)
	_update_sign()
	if Progression.hub_return_world != &"":
		var door := get_node_or_null("HubDoors/%s" % Progression.hub_return_world)
		if door is Node3D:
			var exit_direction := Vector3(-signf(door.position.x), 0, 0)
			player.global_position = door.global_position + exit_direction * 4.0 + Vector3.UP * 0.1
			$CameraRig.snap_to_player()
		Progression.hub_return_world = &""

func _on_world_completed(_world_id: StringName, _keys: int) -> void:
	_update_sign()

func _update_sign() -> void:
	key_sign.text = "CHAVES  %d / 8\nESCOLHA UM MUNDO" % Progression.key_count()
