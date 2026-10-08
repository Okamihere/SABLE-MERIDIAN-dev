extends Node3D

## Mundo 01: o Coro Afundado. A saída só abre após vencer o maestro.
const HUB_SCENE := "res://scenes/levels/vertical_pilot.tscn"
const WORLD_ID := &"world_01"

@onready var boss: BasicEnemy = $BossConductor
@onready var return_area: Area3D = $ReturnPortal/Area3D
@onready var return_marker: MeshInstance3D = $ReturnPortal/Marker

var _return_open := false
var _travelling := false


func _ready() -> void:
	boss.health.max_health = 220.0
	boss.health.current_health = 220.0
	boss.get_node("Visual").scale = Vector3(1.45, 1.45, 1.45)
	boss.health.died.connect(_on_boss_died)
	return_area.body_entered.connect(_on_return_body_entered)
	_open_return(Progression.is_world_complete(WORLD_ID))


func _on_boss_died() -> void:
	Progression.complete_world(WORLD_ID)
	_open_return(true)


func _open_return(value: bool) -> void:
	_return_open = value
	return_marker.visible = value
	return_area.monitoring = value
	if value:
		AreaTransition.prepare_scene(HUB_SCENE)


func _on_return_body_entered(body: Node3D) -> void:
	if not _return_open or _travelling or not (body is PlayerController):
		return
	if not (body as PlayerController).is_alive():
		return
	_travelling = true
	Progression.hub_return_world = WORLD_ID
	GameManager.reset_style()
	AreaTransition.travel_to(HUB_SCENE)
