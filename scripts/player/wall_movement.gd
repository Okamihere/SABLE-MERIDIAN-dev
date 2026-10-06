class_name WallMovement
extends Node

const GRIP_BELLS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/bells/bells_jump_1.wav"),
	preload("res://assets/audio/sfx/bells/bells_jump_2.wav"),
	preload("res://assets/audio/sfx/bells/bells_jump_3.wav"),
]

## Agarre e salto em paredes do mundo. O chão repõe a reserva de saltos.
##
## Segure uma direção contra a parede; Espaço consome um salto e afasta o corpo.
## O sistema usa um orçamento de saltos que é recarregado ao tocar o chão.
## Orbes de melhoria permanente aumentam o orçamento máximo.
##
## Uso típico:
##   - Adicionar como filho do jogador
##   - Chamar [method update_motion] a cada frame após a locomoção
##   - Verificar [member gripping] para saber se está agarrado na parede

## Velocidade do salto de parede.
@export var jump_speed: float = 9.5
## Velocidade de afastamento da parede.
@export var push_speed: float = 7.0
## Duração do agarre na parede (em segundos).
@export var grip_duration: float = 0.4
## Velocidade de deslize quando o agarre acaba.
@export var slide_speed: float = 2.0

## Número de saltos de parede usados.
var used_jumps: int = 0
## Indica se está agarrado na parede.
var gripping: bool = false
## Normal da parede detectada.
var wall_normal: Vector3 = Vector3.ZERO
## Tempo restante de agarre (em segundos).
var _grip_left: float = 0.4
## Tempo restante de detach após salto (em segundos).
var _detach_left: float = 0.0
## Direção do impulso de afastamento.
var _push_direction: Vector3 = Vector3.ZERO
var _grip_count: int = 0
var _grip_announced: bool = false

func _ready() -> void:
	if AudioServer.get_bus_index("VeylBells") == -1:
		AudioServer.add_bus()
		var bus_index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, "VeylBells")
		AudioServer.set_bus_send(bus_index, "SFX")
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.5
		reverb.damping = 0.65
		reverb.wet = 0.16
		AudioServer.add_bus_effect(bus_index, reverb)

func _play_grip_bell() -> void:
	var bell := AudioStreamPlayer3D.new()
	bell.name = "GripBell"
	bell.stream = GRIP_BELLS[_grip_count - 1]
	bell.bus = "VeylBells"
	bell.position = Vector3(0, 1.1, 0)
	bell.unit_size = 10.0
	bell.volume_db = -4.0 + float(_grip_count - 1) * 0.7 + randf_range(-0.35, 0.35)
	bell.pitch_scale = 0.97 + float(_grip_count - 1) * 0.035 + randf_range(-0.012, 0.012)
	add_child(bell)
	bell.finished.connect(bell.queue_free)
	bell.play()

## Reseta o estado do movimento de parede (usado ao tocar o chão).
func reset() -> void:
	used_jumps = 0
	gripping = false
	wall_normal = Vector3.ZERO
	_grip_left = grip_duration
	_detach_left = 0.0
	_grip_count = 0
	_grip_announced = false

## Retorna o número de saltos de parede restantes.
## @return Quantidade de saltos disponíveis.
func remaining() -> int:
	return maxi(0, Progression.max_wall_jumps() - used_jumps)

## Atualiza o movimento de parede.
## Chamado pelo jogador depois da locomoção e antes de move_and_slide.
## @param body O CharacterBody3D do jogador.
## @param direction Direção do input de movimento.
## @param delta Tempo desde o último frame.
## @param allowed Indica se o estado atual permite movimento de parede.
func update_motion(body: CharacterBody3D, direction: Vector3, delta: float, allowed: bool) -> void:
	gripping = false
	wall_normal = Vector3.ZERO
	if body.is_on_floor():
		reset()
		return
	_detach_left = maxf(0.0, _detach_left - delta)
	if not allowed:
		return
	if _detach_left > 0.0:
		# Preserva o impulso inicial mesmo que a direção continue apontando para a parede.
		body.velocity.x = _push_direction.x * push_speed
		body.velocity.z = _push_direction.z * push_speed
		return
	wall_normal = find_wall(body, direction)
	if wall_normal == Vector3.ZERO or remaining() == 0:
		return
	if Input.is_action_just_pressed("jump"):
		used_jumps += 1
		_grip_announced = false
		_push_direction = wall_normal
		body.velocity = wall_normal * push_speed + Vector3.UP * jump_speed
		body.rotation.y = atan2(wall_normal.x, wall_normal.z)
		_detach_left = 0.18
		_grip_left = grip_duration
		return
	if body.velocity.y <= 0.0:
		gripping = true
		if not _grip_announced:
			_grip_announced = true
			_grip_count = mini(_grip_count + 1, GRIP_BELLS.size())
			_play_grip_bell()
		_grip_left = maxf(0.0, _grip_left - delta)
		body.velocity.y = 0.0 if _grip_left > 0.0 else maxf(body.velocity.y, -slide_speed)

## Detecta parede na direção especificada usando raycast.
## Só aceita superfícies verticais da camada World; inimigos não são paredes.
## @param body O CharacterBody3D do jogador.
## @param direction Direção do input de movimento.
## @return Normal da parede detectada, ou Vector3.ZERO se não há parede.
func find_wall(body: CharacterBody3D, direction: Vector3) -> Vector3:
	if direction.length_squared() < 0.01:
		return Vector3.ZERO
	var origin := body.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * 0.75, 1, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.ZERO
	var normal: Vector3 = hit.normal
	if absf(normal.y) > 0.2 or direction.dot(normal) > -0.6:
		return Vector3.ZERO
	return Vector3(normal.x, 0, normal.z).normalized()
