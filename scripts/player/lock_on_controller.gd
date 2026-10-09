class_name LockOnController
extends Node

## Escolhe alvos pela proximidade e posição na tela.
##
## Libera referências inválidas, alvos mortos e alvos fora do alcance.
## O sistema de lock-on usa um score baseado na distância ao centro da tela
## e na distância do jogador para selecionar o melhor alvo.
##
## Uso típico:
##   - Adicionar como filho do jogador
##   - Chamar [method toggle_lock] para alternar lock-on
##   - Conectar [signal target_changed] para reagir a mudanças de alvo

## Emitido quando o alvo muda. Parâmetro: novo alvo (ou null se liberado).
signal target_changed(target: Node3D)

## Distância máxima para adquirir um alvo.
@export var max_distance: float = 24.0
## Peso da distância ao centro da tela no cálculo de score.
@export var center_weight: float = 10.0
## Peso da distância do jogador no cálculo de score.
@export var distance_weight: float = 0.35
## Margem da tela usada na troca de alvos.
@export_range(0.0, 0.25, 0.01) var screen_margin: float = 0.06

## Alvo atual de lock-on (null se não há alvo).
var current_target: Node3D

## Alterna entre adquirir e liberar alvo.
func toggle_lock() -> void:
	if is_instance_valid(current_target):
		clear_target()
	else:
		acquire_target()

## Adquire o melhor alvo disponível baseado em score.
## @return O alvo adquirido, ou null se nenhum alvo válido foi encontrado.
func acquire_target() -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	var origin := get_parent() as Node3D
	var best_score := INF
	var best_target: Node3D
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not (candidate is Node3D):
			continue
		var enemy := candidate as Node3D
		if enemy.has_method("is_alive") and not enemy.call("is_alive"):
			continue
		if not _can_select(enemy, camera, viewport_size, origin):
			continue
		var distance := origin.global_position.distance_to(enemy.global_position)
		var screen_pos := camera.unproject_position(_target_center(enemy))
		var center_distance := screen_pos.distance_to(screen_center) / maxf(1.0, viewport_size.length())
		var score := center_distance * center_weight + distance * distance_weight
		if score < best_score:
			best_score = score
			best_target = enemy
	current_target = best_target
	target_changed.emit(current_target)
	return current_target

## Troca para o alvo visível mais próximo à esquerda (-1) ou à direita (1).
func switch_target(direction: int) -> Node3D:
	var previous := get_target()
	var camera := get_viewport().get_camera_3d()
	if previous == null or camera == null or direction == 0:
		return previous
	var viewport_size := get_viewport().get_visible_rect().size
	var origin := get_parent() as Node3D
	var previous_screen := camera.unproject_position(_target_center(previous))
	var best_score := INF
	var best_target: Node3D
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not (candidate is Node3D) or candidate == previous:
			continue
		var enemy := candidate as Node3D
		if not _can_select(enemy, camera, viewport_size, origin, true):
			continue
		var screen := camera.unproject_position(_target_center(enemy))
		var horizontal := (screen.x - previous_screen.x) * direction
		if horizontal <= 12.0:
			continue
		var score := horizontal + absf(screen.y - previous_screen.y) * 0.45
		if score < best_score:
			best_score = score
			best_target = enemy
	if best_target != null:
		current_target = best_target
		target_changed.emit(current_target)
	return current_target

func _can_select(enemy: Node3D, camera: Camera3D, viewport_size: Vector2, origin: Node3D, require_on_screen: bool = false) -> bool:
	if enemy.has_method("is_alive") and not enemy.call("is_alive"):
		return false
	if origin.global_position.distance_to(enemy.global_position) > max_distance:
		return false
	var center := _target_center(enemy)
	if camera.is_position_behind(center):
		return false
	if require_on_screen:
		var screen := camera.unproject_position(center)
		if screen.x < viewport_size.x * screen_margin or screen.x > viewport_size.x * (1.0 - screen_margin) or screen.y < viewport_size.y * screen_margin or screen.y > viewport_size.y * (1.0 - screen_margin):
			return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, center, 1)
	return origin.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _target_center(target: Node3D) -> Vector3:
	return target.global_position + Vector3.UP * get_target_size(target).y * 0.5

## Estima as dimensões visuais com a colisão e a escala do visual do inimigo.
static func get_target_size(target: Node3D) -> Vector2:
	var size := Vector2(1.4, 2.25)
	var collider := target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null and collider.shape != null:
		if collider.shape is CapsuleShape3D:
			var capsule := collider.shape as CapsuleShape3D
			size.x = maxf(size.x, capsule.radius * 2.0)
			size.y = maxf(size.y, collider.position.y + capsule.height * 0.5 + 0.3)
		elif collider.shape is BoxShape3D:
			var box := collider.shape as BoxShape3D
			size.x = maxf(size.x, box.size.x)
			size.y = maxf(size.y, collider.position.y + box.size.y * 0.5 + 0.3)
	var visual := target.get_node_or_null("Visual") as Node3D
	if visual != null:
		size *= Vector2(maxf(1.0, visual.scale.x), maxf(1.0, visual.scale.y))
	return size

## Libera o alvo atual.
func clear_target() -> void:
	current_target = null
	target_changed.emit(null)

## Retorna o alvo atual, verificando se ainda é válido.
## @return O alvo atual, ou null se inválido/fora do alcance/morto.
func get_target() -> Node3D:
	if not is_instance_valid(current_target):
		current_target = null
		return null
	if (get_parent() as Node3D).global_position.distance_to(current_target.global_position) > max_distance:
		clear_target()
		return null
	if is_instance_valid(current_target):
		if current_target.has_method("is_alive") and not current_target.call("is_alive"):
			clear_target()
	return current_target

## Rotaciona o corpo em direção ao alvo.
## @param body O nó 3D a ser rotacionado.
## @param delta Tempo desde o último frame.
## @param rotation_speed Velocidade de rotação.
func face_target(body: Node3D, delta: float, rotation_speed: float) -> void:
	var target := get_target()
	if target == null:
		return
	var direction := target.global_position - body.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var target_yaw := atan2(direction.x, direction.z)
	body.rotation.y = lerp_angle(body.rotation.y, target_yaw, clampf(rotation_speed * delta, 0.0, 1.0))
