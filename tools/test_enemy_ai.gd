extends SceneTree

const CHASE := 1
const ATTACK := 2

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var packed := load("res://scenes/enemies/basic_enemy.tscn") as PackedScene
	var enemy = packed.instantiate()
	arena.add_child(enemy)
	var target := Node3D.new()
	arena.add_child(target)
	enemy._player = target
	enemy._attack_cooldown_left = 0.0
	target.position = Vector3(0, 0, 2.65)
	enemy._update_chase(0.1)
	assert(enemy.state == CHASE and enemy.velocity.z > 0.0, "Deve perseguir fora do alcance físico")
	target.position.z = 2.1
	enemy._update_chase(0.1)
	assert(enemy.state == ATTACK, "Deve atacar quando o alvo entra no alcance")
	target.position.z = 5.0
	enemy._update_attack(enemy.ATTACK_WINDUP + 0.02)
	assert(enemy.state == CHASE and not enemy.attack_hitbox._attack_enabled, "Deve cancelar preparação fora do alcance")
	enemy._attack_cooldown_left = 0.0
	target.position.z = 2.1
	enemy._update_chase(0.1)
	enemy._update_attack(enemy.ATTACK_WINDUP + 0.02)
	assert(enemy.attack_hitbox._attack_enabled, "Ataque no alcance deve manter hitbox ativa")
	enemy.attack_hitbox.end_attack()
	enemy.state = CHASE
	enemy._attack_cooldown_left = 0.5
	target.position.z = 5.0
	var neighbor = packed.instantiate()
	arena.add_child(neighbor)
	neighbor.position = Vector3(0.3, 0, 0.2)
	enemy.velocity = Vector3.ZERO
	enemy._update_chase(0.1)
	assert(enemy.velocity.z > 0.0, "Separação entre inimigos não deve travar perseguição")
	print("ENEMY AI PASS: perseguição, alcance, cancelamento e separação")
	quit(0)
