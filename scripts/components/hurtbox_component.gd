class_name HurtboxComponent
extends Area3D

## Área que recebe golpes e os encaminha ao personagem responsável.
##
## Usa HealthComponent como alternativa quando não há receptor personalizado.
## Configurada para detectar hitboxes nas camadas 4 (PlayerHitbox) e 5 (EnemyHitbox).
##
## Uso típico:
##   - Adicionar como filho de um CharacterBody3D
##   - Definir [member receiver_path] para o nó que receberá o golpe
##   - Opcionalmente definir [member health_component_path] para dano automático

## Emitido quando um golpe é recebido. Parâmetro: hitbox que acertou.
signal hit_received(hitbox: HitboxComponent)

## Caminho para o nó que receberá o golpe (deve ter método receive_hitbox).
@export var receiver_path: NodePath = NodePath("..")
## Caminho para um HealthComponent (usado se receiver_path não tiver receive_hitbox).
@export var health_component_path: NodePath
## Flash local em malhas do nó Visual após dano aceito.
@export var impact_flash_enabled: bool = true
@export_range(0.0, 0.2, 0.005) var impact_flash_duration: float = 0.09

## Referência ao nó receptor do golpe.
var _receiver: Node
## Referência ao HealthComponent (se configurado).
var _health: HealthComponent
## Malha de debug visual (visível apenas com DEBUG_COMBAT ativo).
var _debug_mesh: MeshInstance3D
var _flash_material: StandardMaterial3D
var _flash_tween: Tween
var _previous_overlays: Dictionary = {}

## Configura camadas de colisão e conecta sinais.
func _ready() -> void:
	collision_layer = 1 << 5
	collision_mask = (1 << 3) | (1 << 4)
	monitoring = true
	monitorable = true
	_receiver = get_node_or_null(receiver_path)
	if not health_component_path.is_empty():
		_health = get_node_or_null(health_component_path) as HealthComponent
	_create_debug_mesh()

## Recebe um golpe de uma hitbox.
## @param hitbox A hitbox que acertou esta hurtbox.
## @return true se o golpe foi aceito, false caso contrário.
func receive_hit(hitbox: HitboxComponent) -> bool:
	if not is_instance_valid(hitbox):
		return false
	if is_instance_valid(_receiver) and _receiver.has_method("receive_hitbox"):
		var accepted: bool = _receiver.call("receive_hitbox", hitbox)
		if accepted:
			hit_received.emit(hitbox)
			_flash_impact(hitbox)
		return accepted
	if is_instance_valid(_health):
		var result := _health.damage(hitbox.damage)
		if result:
			hit_received.emit(hitbox)
			_flash_impact(hitbox)
		return result
	return false

func _flash_impact(hitbox: HitboxComponent) -> void:
	if not impact_flash_enabled or impact_flash_duration <= 0.0:
		return
	var visual := get_node_or_null("../Visual")
	if visual == null:
		return
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_material.no_depth_test = false
		_flash_material.disable_receive_shadows = true
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not _previous_overlays.has(mesh):
			_previous_overlays[mesh] = mesh.material_overlay
		mesh.material_overlay = _flash_material
	var heavy := hitbox.hit_stop_duration >= 0.045 or hitbox.launch_force > 0.0
	_flash_material.albedo_color = Color(0.95, 0.74, 1.0, 0.55 if heavy else 0.36)
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_material, "albedo_color:a", 0.0, impact_flash_duration * (1.2 if heavy else 1.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.finished.connect(_restore_impact_overlays)

func _restore_impact_overlays() -> void:
	for mesh in _previous_overlays:
		if is_instance_valid(mesh):
			mesh.material_overlay = _previous_overlays[mesh]
	_previous_overlays.clear()

## Atualiza a visibilidade da malha de debug.
func _process(_delta: float) -> void:
	if is_instance_valid(_debug_mesh):
		_debug_mesh.visible = GameManager.DEBUG_COMBAT

## Cria a malha de debug visual baseada na forma da collision shape.
func _create_debug_mesh() -> void:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.name = "DebugHurtbox"
	_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 0.75, 1.0, 0.16)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if shape_node.shape is CapsuleShape3D:
		var shape := shape_node.shape as CapsuleShape3D
		var mesh := CapsuleMesh.new()
		mesh.radius = shape.radius
		mesh.height = shape.height
		_debug_mesh.mesh = mesh
	elif shape_node.shape is BoxShape3D:
		var shape := shape_node.shape as BoxShape3D
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		_debug_mesh.mesh = mesh
	elif shape_node.shape is SphereShape3D:
		var shape := shape_node.shape as SphereShape3D
		var mesh := SphereMesh.new()
		mesh.radius = shape.radius
		mesh.height = shape.radius * 2.0
		_debug_mesh.mesh = mesh
	else:
		return
	_debug_mesh.material_override = material
	add_child(_debug_mesh)
