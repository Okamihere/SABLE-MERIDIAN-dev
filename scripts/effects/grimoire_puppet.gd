class_name GrimoirePuppet
extends Node3D

## Acompanhante da skill R. Usa sondas locais de física e hitbox do combate.
enum State { SUMMONING, IDLE, MOVING, ATTACKING, DESPAWNING }
enum Mode { WAITING, FOLLOWING, PURSUING, RETURNING }
enum AttackKind { NONE, SLAP, HEADBUTT, FINAL }
enum AttackPhase { NONE, WINDUP, ACTIVE, RECOVERY }

const ACTIVE_GROUP := &"grimoire_puppets"
const SUMMON_TIME := 0.3
const DESPAWN_TIME := 0.25
const SCAN_INTERVAL := 0.25
const FLOOR_MASK := 1
const FINAL_WINDUP := 0.28
const FINAL_ACTIVE := 0.14
const FINAL_RECOVERY := 0.28
const FINAL_TIME := FINAL_WINDUP + FINAL_ACTIVE + FINAL_RECOVERY + 0.08

@export_range(0.5, 120.0, 0.1) var duration := 12.0
@export_range(1.0, 12.0, 0.1) var follow_distance := 1.8
@export_range(1.0, 8.0, 0.1) var attack_distance := 2.7
@export_range(2.0, 30.0, 0.5) var search_range := 14.0
@export_range(3.0, 30.0, 0.5) var return_distance := 12.0
@export_range(1.0, 10.0, 0.1) var move_speed := 4.8
@export_range(0.1, 2.0, 0.05) var max_step_height := 0.65
@export_category("Combat")
@export_range(1.0, 50.0, 1.0) var slap_damage := 6.0
@export_range(1.0, 50.0, 1.0) var headbutt_damage := 10.0
@export_range(1.0, 80.0, 1.0) var final_damage := 14.0
@export_range(1.0, 5.0, 0.1) var slap_range := 2.8
@export_range(1.0, 5.0, 0.1) var headbutt_range := 3.0
@export_range(1.0, 5.0, 0.1) var final_range := 3.1
@export_range(0.9, 5.0, 0.05) var attack_interval := 1.75

@onready var visual: Node3D = $Visual
@onready var head: Node3D = $Visual/Head
@onready var left_arm: Node3D = $Visual/LeftArm
@onready var right_arm: Node3D = $Visual/RightArm
@onready var left_leg: Node3D = $Visual/LeftLeg
@onready var right_leg: Node3D = $Visual/RightLeg
@onready var control_bar: Node3D = $Visual/ControlBar
@onready var attack_hitbox: HitboxComponent = $AttackHitbox
@onready var stage_vfx: Variant = $VFX
@onready var summon_tome: Node3D = $VFX/SummonTome
@onready var left_page_hinge: Node3D = $VFX/SummonTome/LeftPageHinge
@onready var right_page_hinge: Node3D = $VFX/SummonTome/RightPageHinge
@onready var loose_pages: Array[Node3D] = [$VFX/LoosePageA, $VFX/LoosePageB, $VFX/LoosePageC]
@onready var pull_threads: Node3D = $VFX/PullThreads
@onready var ink_particles: CPUParticles3D = $VFX/InkParticles
@onready var violet_particles: CPUParticles3D = $VFX/VioletParticles
@onready var warp_ring: MeshInstance3D = $VFX/WarpRing
@onready var sound_summon: AudioStreamPlayer3D = $Audio/Summon
@onready var sound_movement: AudioStreamPlayer3D = $Audio/Movement
@onready var sound_cue: AudioStreamPlayer3D = $Audio/Cue
@onready var sound_slap: AudioStreamPlayer3D = $Audio/SlapImpact
@onready var sound_head: AudioStreamPlayer3D = $Audio/HeadImpact
@onready var sound_final: AudioStreamPlayer3D = $Audio/FinalImpact
@onready var sound_farewell: AudioStreamPlayer3D = $Audio/Farewell

var summoner: PlayerController
var state := State.SUMMONING
var mode := Mode.WAITING
var target: Node3D
var _elapsed := 0.0
var _scan_left := 0.0
var _stuck_time := 0.0
var _avoid_side := 1.0
var _returning := false
var _attack_kind := AttackKind.NONE
var _attack_phase := AttackPhase.NONE
var _attack_target: Node3D
var _attack_elapsed := 0.0
var _attack_count := 0
var _next_attack_at := 0.0
var _hitbox_live := false
var _lunge_travel := 0.0
var _finale_started := false
var _bowing := false
var _farewell_cued := false
var _next_motion_cue := 2.8
var _warp_tween: Tween

## SpellManager consulta antes de gastar mana ou iniciar cooldown.
func can_activate(caster: Node3D) -> bool:
	if not caster is PlayerController:
		return false
	for node in caster.get_tree().get_nodes_in_group(ACTIVE_GROUP):
		if node is GrimoirePuppet and node.summoner == caster and not node.is_queued_for_deletion():
			return false
	return true

func activate(caster: Node3D, _spell: SpellResource) -> void:
	summoner = caster as PlayerController
	add_to_group(ACTIVE_GROUP)
	# Sem colisão: a aparição ao lado do jogador não interrompe seu movimento.
	global_position = summoner.global_position + summoner.global_basis.x * follow_distance + Vector3.UP * 0.2
	for offset in [summoner.global_basis.x * follow_distance, -summoner.global_basis.x * follow_distance, -summoner.global_basis.z * follow_distance, Vector3.ZERO]:
		var floor_point := _floor_at(summoner.global_position + offset)
		if floor_point != Vector3.INF and _path_clear(summoner.global_position + Vector3.UP * 0.2, floor_point):
			global_position = floor_point
			break
	global_rotation.y = summoner.global_rotation.y
	visual.scale = Vector3.ZERO
	var hit_shape := attack_hitbox.get_node("CollisionShape3D") as CollisionShape3D
	hit_shape.shape = hit_shape.shape.duplicate()
	attack_hitbox.source = summoner
	attack_hitbox.style_weapon_id = &"living_grimoire"
	attack_hitbox.hit_filter = _can_hit_hurtbox
	attack_hitbox.hit_landed.connect(_on_hit_landed)
	summoner.health.died.connect(despawn)
	summon_tome.scale = Vector3.ONE * 0.15
	pull_threads.visible = true
	for page in loose_pages:
		page.visible = true
	_emit_ink(Vector3(0, 0.35, 0.4), true)
	_pulse_warp(1.25)
	stage_vfx.play_summon()
	sound_summon.play()

func _process(delta: float) -> void:
	if summoner == null:
		return
	if not is_instance_valid(summoner) or not summoner.is_alive():
		despawn()
		return
	_elapsed += delta
	if _elapsed >= duration:
		despawn()
		return
	if not _farewell_cued and _elapsed >= duration - 0.9:
		_cue_farewell()
	if _elapsed < SUMMON_TIME:
		state = State.SUMMONING
		visual.scale = Vector3.ONE * clampf(_elapsed / SUMMON_TIME, 0.0, 1.0)
	elif _elapsed >= duration - DESPAWN_TIME and _attack_kind != AttackKind.FINAL:
		state = State.DESPAWNING
		visual.scale = Vector3.ONE * clampf((duration - _elapsed) / DESPAWN_TIME, 0.0, 1.0)
	else:
		if state == State.SUMMONING:
			state = State.IDLE
		visual.scale = Vector3.ONE
	var stride := 8.0 if state == State.MOVING else 2.5
	var pose_time := _elapsed
	if mode == Mode.WAITING and fmod(_elapsed, 2.4) < 0.12:
		pose_time = floorf(_elapsed / 2.4) * 2.4
	visual.position.y = sin(pose_time * stride) * (0.09 if state == State.MOVING else 0.05)
	visual.rotation.z = sin(pose_time * stride * 0.7) * (0.09 if state == State.MOVING else 0.035)
	head.rotation.z = sin(pose_time * 3.7) * 0.08
	left_arm.rotation.z = -0.25 + sin(pose_time * stride) * (0.32 if state == State.MOVING else 0.09)
	right_arm.rotation.z = 0.25 - sin(pose_time * stride + 0.8) * (0.32 if state == State.MOVING else 0.09)
	var leg_swing := sin(pose_time * 8.0) * (0.42 if state == State.MOVING else 0.055)
	left_leg.rotation.x = leg_swing
	right_leg.rotation.x = -leg_swing * 0.82
	control_bar.rotation.y = sin(pose_time * 4.2) * 0.13
	if state == State.MOVING and _elapsed >= _next_motion_cue and not _farewell_cued:
		sound_movement.pitch_scale = 0.92 + 0.07 * sin(_elapsed * 3.0)
		sound_movement.play()
		_next_motion_cue = _elapsed + 3.4
	if _bowing:
		visual.rotation.x = lerpf(visual.rotation.x, 0.6, minf(1.0, delta * 9.0))
	elif _attack_kind != AttackKind.NONE:
		_animate_attack()
	else:
		visual.rotation.x = lerpf(visual.rotation.x, 0.0, minf(1.0, delta * 10.0))
	_update_ritual_visual()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(summoner) or state in [State.SUMMONING, State.DESPAWNING]:
		return
	if not _finale_started and _elapsed >= maxf(SUMMON_TIME, duration - FINAL_TIME):
		_start_finale()
		return
	if _attack_kind != AttackKind.NONE:
		_update_attack(delta)
		return
	var player_distance := _flat_distance(global_position, summoner.global_position)
	if player_distance > return_distance:
		_returning = true
		target = null
	elif player_distance < return_distance * 0.55:
		_returning = false
	_scan_left -= delta
	if _scan_left <= 0.0 and not _returning:
		_scan_left = SCAN_INTERVAL
		_select_target()
	var destination := _follow_position()
	var stopping_distance := 0.55
	if _returning:
		mode = Mode.RETURNING
	elif is_instance_valid(target):
		destination = target.global_position
		stopping_distance = minf(attack_distance, minf(slap_range, headbutt_range) - 0.35)
		mode = Mode.PURSUING
	else:
		mode = Mode.FOLLOWING
	var distance := _flat_distance(global_position, destination)
	if distance <= stopping_distance:
		mode = Mode.WAITING
		state = State.IDLE
		_stuck_time = 0.0
		_face(destination, delta)
		if is_instance_valid(target) and not _returning and _elapsed >= _next_attack_at:
			var kind := AttackKind.SLAP if _attack_count % 2 == 0 else AttackKind.HEADBUTT
			_start_attack(kind, target)
		return
	state = State.MOVING
	var direction := destination - global_position
	direction.y = 0.0
	direction = direction.normalized()
	var step_length := minf(distance - stopping_distance, move_speed * delta * (0.94 + 0.06 * sin(_elapsed * 11.0)))
	if not _move_safely(direction, step_length):
		state = State.IDLE
		_stuck_time += delta
		if _stuck_time >= 1.4:
			if player_distance > follow_distance + 0.8:
				_rejoin_player()
			else:
				target = null
			_stuck_time = 0.0
	else:
		_stuck_time = 0.0
		_face(destination, delta)

func _start_finale() -> void:
	_finale_started = true
	_clear_attack()
	if _returning or mode != Mode.WAITING or _stuck_time > 0.0 or _flat_distance(global_position, summoner.global_position) > return_distance:
		_begin_bow()
		return
	_select_target()
	if _can_strike(target, final_range):
		_start_attack(AttackKind.FINAL, target)
	else:
		_begin_bow()

func _start_attack(kind: AttackKind, victim: Node3D) -> void:
	var reach := final_range if kind == AttackKind.FINAL else (headbutt_range if kind == AttackKind.HEADBUTT else slap_range)
	if not _can_strike(victim, reach):
		if kind == AttackKind.FINAL:
			_begin_bow()
		return
	_attack_kind = kind
	_attack_phase = AttackPhase.WINDUP
	_attack_target = victim
	_attack_elapsed = 0.0
	_lunge_travel = 0.0
	state = State.ATTACKING
	mode = Mode.WAITING
	_face(victim.global_position, 1.0)
	_configure_hitbox()
	sound_cue.pitch_scale = 1.22 if kind == AttackKind.SLAP else (0.82 if kind == AttackKind.HEADBUTT else 0.68)
	sound_cue.play()
	stage_vfx.play_windup(kind, 0.16 if kind == AttackKind.SLAP else (0.38 if kind == AttackKind.HEADBUTT else FINAL_WINDUP))
	if kind == AttackKind.FINAL:
		_pulse_warp(1.6)
	if kind != AttackKind.FINAL:
		_attack_count += 1
		_next_attack_at = _elapsed + attack_interval

func _update_attack(delta: float) -> void:
	if _flat_distance(global_position, summoner.global_position) > return_distance or not _can_strike(_attack_target, _current_reach() + 0.4):
		_abort_attack()
		return
	_attack_elapsed += delta
	var windup := 0.16 if _attack_kind == AttackKind.SLAP else (0.38 if _attack_kind == AttackKind.HEADBUTT else FINAL_WINDUP)
	var active := 0.12 if _attack_kind == AttackKind.SLAP else (0.17 if _attack_kind == AttackKind.HEADBUTT else FINAL_ACTIVE)
	var recovery := 0.26 if _attack_kind == AttackKind.SLAP else (0.42 if _attack_kind == AttackKind.HEADBUTT else FINAL_RECOVERY)
	if _attack_elapsed < windup:
		_attack_phase = AttackPhase.WINDUP
		_face(_attack_target.global_position, delta)
	elif _attack_elapsed < windup + active:
		_attack_phase = AttackPhase.ACTIVE
		if _attack_kind == AttackKind.HEADBUTT and _lunge_travel < 0.8:
			var step := minf(0.8 - _lunge_travel, 5.5 * delta)
			if not _move_safely(global_basis.z, step):
				_abort_attack()
				return
			_lunge_travel += step
		if not _hitbox_live:
			attack_hitbox.begin_attack()
			_hitbox_live = true
			_emit_attack_impact()
	else:
		if _hitbox_live:
			attack_hitbox.end_attack()
			_hitbox_live = false
		_attack_phase = AttackPhase.RECOVERY
		if _attack_elapsed >= windup + active + recovery:
			var was_final := _attack_kind == AttackKind.FINAL
			_clear_attack()
			state = State.DESPAWNING if was_final else State.IDLE

func _current_reach() -> float:
	match _attack_kind:
		AttackKind.SLAP: return slap_range
		AttackKind.HEADBUTT: return headbutt_range
		AttackKind.FINAL: return final_range
	return 0.0

func _can_strike(victim: Variant, reach: float) -> bool:
	if not is_instance_valid(victim) or not victim is Node3D or not victim.is_in_group(&"enemies"):
		return false
	if victim.has_method("is_alive") and not victim.call("is_alive"):
		return false
	if _flat_distance(global_position, victim.global_position) > reach or absf(victim.global_position.y - global_position.y) > 2.0:
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.1, victim.global_position + Vector3.UP * 1.0, FLOOR_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _configure_hitbox() -> void:
	var shape := (attack_hitbox.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	attack_hitbox.launch_force = 0.0
	match _attack_kind:
		AttackKind.SLAP:
			attack_hitbox.position = Vector3(0, 1.15, slap_range * 0.55)
			shape.size = Vector3(1.2, 1.3, slap_range * 0.7)
			attack_hitbox.damage = slap_damage
			attack_hitbox.knockback = 9.0
			attack_hitbox.hit_stun = 0.18
			attack_hitbox.hit_stop_duration = 0.015
			attack_hitbox.attack_id = &"grimoire_puppet_slap"
			attack_hitbox.style_points = 40
		AttackKind.HEADBUTT:
			attack_hitbox.position = Vector3(0, 1.25, headbutt_range * 0.43)
			shape.size = Vector3(1.1, 1.1, headbutt_range * 0.65)
			attack_hitbox.damage = headbutt_damage
			attack_hitbox.knockback = 6.0
			attack_hitbox.hit_stun = 0.25
			attack_hitbox.hit_stop_duration = 0.025
			attack_hitbox.attack_id = &"grimoire_puppet_headbutt"
			attack_hitbox.style_points = 75
		AttackKind.FINAL:
			attack_hitbox.position = Vector3(0, 1.2, final_range * 0.5)
			shape.size = Vector3(2.2, 1.25, final_range * 0.8)
			attack_hitbox.damage = final_damage
			attack_hitbox.knockback = 11.0
			attack_hitbox.hit_stun = 0.3
			attack_hitbox.launch_force = 2.0
			attack_hitbox.hit_stop_duration = 0.035
			attack_hitbox.attack_id = &"grimoire_puppet_final"
			attack_hitbox.style_points = 110

func _can_hit_hurtbox(hurtbox: HurtboxComponent) -> bool:
	if _attack_phase != AttackPhase.ACTIVE or not is_instance_valid(_attack_target) or not _attack_target.is_ancestor_of(hurtbox):
		return false
	if not _can_strike(_attack_target, _current_reach() + 0.4):
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.1, hurtbox.global_position, FLOOR_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _on_hit_landed(hurtbox: HurtboxComponent, box_hit: HitboxComponent) -> void:
	if is_instance_valid(summoner) and is_instance_valid(summoner.combat):
		summoner.combat.register_magic_hit(hurtbox, box_hit)
	match _attack_kind:
		AttackKind.SLAP: sound_slap.play()
		AttackKind.HEADBUTT: sound_head.play()
		AttackKind.FINAL: sound_final.play()
	_emit_violet(to_local(hurtbox.global_position))
	stage_vfx.play_hit(_attack_kind, hurtbox.global_position)

func _cue_farewell() -> void:
	_farewell_cued = true
	sound_farewell.play()
	_emit_ink(Vector3(0, 0.35, 0.4), true)
	_pulse_warp(1.55)
	stage_vfx.play_farewell()

func _update_ritual_visual() -> void:
	var appearing := _elapsed < 0.55
	var leaving := _farewell_cued
	summon_tome.visible = appearing or leaving
	pull_threads.visible = appearing or leaving
	if not appearing and not leaving:
		for page in loose_pages:
			page.visible = false
		return
	var progress := clampf(_elapsed / SUMMON_TIME, 0.0, 1.0) if appearing else clampf((_elapsed - (duration - 0.9)) / 0.9, 0.0, 1.0)
	var opened := progress if appearing else 1.0 - progress
	summon_tome.scale = Vector3.ONE * (0.15 + 0.85 * opened)
	left_page_hinge.rotation.z = -1.3 * (1.0 - opened)
	right_page_hinge.rotation.z = 1.3 * (1.0 - opened)
	pull_threads.scale.y = 0.35 + 0.65 * opened
	pull_threads.rotation.y = sin(_elapsed * 15.0) * (0.09 if appearing else 0.16)
	for i in loose_pages.size():
		var page := loose_pages[i]
		page.visible = progress < 0.75
		var flight := progress if appearing else 1.0 - progress
		page.position = Vector3((float(i) - 1.0) * 0.3 + sin(_elapsed * 12.0 + float(i) * 2.0) * 0.1, 0.28 + flight * (0.9 + float(i) * 0.15), 0.48 + cos(_elapsed * 10.0 + float(i)) * 0.15)
		page.rotation = Vector3(0.35 + _elapsed * (3.0 + float(i)), _elapsed * (4.0 - float(i)), 0.28 * sin(_elapsed * 9.0 + float(i)))
		page.scale = Vector3.ONE * 0.55
	if appearing:
		visual.position.y -= 0.85 * (1.0 - progress)
	elif leaving:
		var pull := clampf((_elapsed - (duration - DESPAWN_TIME)) / DESPAWN_TIME, 0.0, 1.0)
		if _attack_kind == AttackKind.FINAL and _attack_phase != AttackPhase.RECOVERY:
			pull = 0.0
		visual.position.y += pull * 1.5
		if _attack_kind == AttackKind.NONE:
			head.rotation.y = sin(_elapsed * 31.0) * 0.26 * (1.0 - pull)
			left_arm.rotation.z -= 0.3 * (1.0 - pull)
			right_arm.rotation.z += 0.3 * (1.0 - pull)

func _emit_ink(local_position: Vector3, include_violet: bool = false) -> void:
	ink_particles.position = local_position
	ink_particles.restart()
	ink_particles.emitting = true
	if include_violet:
		_emit_violet(local_position + Vector3.UP * 0.3)

func _emit_violet(local_position: Vector3) -> void:
	violet_particles.position = local_position
	violet_particles.restart()
	violet_particles.emitting = true

func _pulse_warp(radius: float, height: float = 0.16) -> void:
	if is_instance_valid(_warp_tween):
		_warp_tween.kill()
	warp_ring.visible = true
	warp_ring.position.y = height
	warp_ring.scale = Vector3.ONE * 0.12
	warp_ring.transparency = 0.0
	_warp_tween = create_tween().set_parallel(true)
	_warp_tween.tween_property(warp_ring, "scale", Vector3.ONE * radius, 0.27).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_warp_tween.tween_property(warp_ring, "transparency", 1.0, 0.27)
	_warp_tween.chain().tween_callback(func() -> void: warp_ring.visible = false)

func _emit_attack_impact() -> void:
	stage_vfx.play_release(_attack_kind)
	match _attack_kind:
		AttackKind.SLAP:
			_emit_ink(Vector3(-0.42, 1.15, 1.65))
			_pulse_warp(1.05, 1.1)
		AttackKind.HEADBUTT:
			_emit_ink(Vector3(0, 1.45, 1.2), true)
			_pulse_warp(1.35, 1.25)
		AttackKind.FINAL:
			_emit_ink(Vector3(0, 1.15, 1.6), true)
			_pulse_warp(2.15, 1.1)

func _animate_attack() -> void:
	var windup := 0.16 if _attack_kind == AttackKind.SLAP else (0.38 if _attack_kind == AttackKind.HEADBUTT else FINAL_WINDUP)
	var anticipation := clampf(_attack_elapsed / windup, 0.0, 1.0)
	match _attack_kind:
		AttackKind.SLAP:
			if _attack_phase == AttackPhase.WINDUP:
				left_arm.position = Vector3(-0.37 - anticipation * 0.14, 0.91 + anticipation * 0.15, -anticipation * 0.23)
				left_arm.rotation.x = -0.65 * anticipation
				left_arm.rotation.z = -0.25 - anticipation * 0.95
				left_arm.scale.y = 1.0 + anticipation * 0.38
				head.rotation.z = -0.22 * anticipation
			elif _attack_phase == AttackPhase.ACTIVE:
				left_arm.position = Vector3(-0.28, 1.1, 0.53)
				left_arm.rotation.x = 1.28
				left_arm.rotation.z = -0.18
				left_arm.scale.y = 3.65
				head.rotation.z = 0.18
			else:
				var release := clampf((_attack_elapsed - 0.28) / 0.26, 0.0, 1.0)
				left_arm.position = Vector3(-0.28, 1.1, 0.53).lerp(Vector3(-0.37, 0.91, 0), release)
				left_arm.rotation.x = lerpf(0.65, -0.25, release)
				left_arm.scale.y = lerpf(1.8, 1.0, release)
				head.rotation.z = 0.18 * (1.0 - release)
		AttackKind.HEADBUTT:
			if _attack_phase == AttackPhase.WINDUP:
				visual.rotation.x = -0.4 * anticipation
				head.position.z = -0.2 * anticipation
				head.rotation.x = -0.25 * anticipation
				left_arm.rotation.z -= 0.55 * anticipation
				right_arm.rotation.z += 0.55 * anticipation
			elif _attack_phase == AttackPhase.ACTIVE:
				visual.rotation.x = 0.46
				head.position.z = 0.42
				head.rotation.x = 0.28
				head.scale = Vector3.ONE * 1.28
				left_leg.rotation.x = -0.68
				right_leg.rotation.x = 0.55
			else:
				var stumble := clampf((_attack_elapsed - 0.55) / 0.42, 0.0, 1.0)
				visual.rotation.x = lerpf(0.31, -0.14, stumble)
				head.position.z = lerpf(0.35, 0.0, stumble)
				head.rotation.z = sin(stumble * PI * 2.0) * 0.22
				head.scale = Vector3.ONE * lerpf(1.13, 1.0, stumble)
		AttackKind.FINAL:
			if _attack_phase == AttackPhase.WINDUP:
				left_arm.position.x = -0.37 - anticipation * 0.35
				right_arm.position.x = 0.37 + anticipation * 0.35
				left_arm.rotation.z = -0.25 - anticipation * 0.85
				right_arm.rotation.z = 0.25 + anticipation * 0.85
				visual.rotation.x = -0.2 * anticipation
			elif _attack_phase == AttackPhase.ACTIVE:
				left_arm.position = Vector3(-0.1, 1.13, 0.55)
				right_arm.position = Vector3(0.1, 1.13, 0.55)
				left_arm.rotation.x = 1.15
				right_arm.rotation.x = 1.15
				left_arm.scale.y = 2.0
				right_arm.scale.y = 2.0
				visual.rotation.x = 0.23
			else:
				var flourish := clampf((_attack_elapsed - 0.42) / FINAL_RECOVERY, 0.0, 1.0)
				left_arm.position = Vector3(-0.1, 1.13, 0.55).lerp(Vector3(-0.55, 0.85, -0.07), flourish)
				right_arm.position = Vector3(0.1, 1.13, 0.55).lerp(Vector3(0.55, 0.85, -0.07), flourish)
				left_arm.rotation.x = 1.15 * (1.0 - flourish)
				right_arm.rotation.x = 1.15 * (1.0 - flourish)
				left_arm.scale.y = lerpf(2.0, 1.0, flourish)
				right_arm.scale.y = left_arm.scale.y
				visual.rotation.x = 0.23 * (1.0 - flourish)

func _abort_attack() -> void:
	var was_final := _attack_kind == AttackKind.FINAL
	_clear_attack()
	if was_final:
		_begin_bow()
	else:
		state = State.IDLE
		_next_attack_at = _elapsed + 0.3

func _clear_attack() -> void:
	stage_vfx.clear_omen()
	if _hitbox_live:
		attack_hitbox.end_attack()
		_hitbox_live = false
	_attack_kind = AttackKind.NONE
	_attack_phase = AttackPhase.NONE
	_attack_target = null
	left_arm.scale = Vector3.ONE
	right_arm.scale = Vector3.ONE
	head.scale = Vector3.ONE
	left_arm.position = Vector3(-0.37, 0.91, 0)
	right_arm.position = Vector3(0.37, 0.91, 0)
	left_arm.rotation.x = 0.0
	right_arm.rotation.x = 0.0
	head.position = Vector3(0, 1.48, 0)
	head.rotation = Vector3.ZERO
	visual.rotation.x = 0.0

func _begin_bow() -> void:
	_bowing = true
	state = State.DESPAWNING
	mode = Mode.WAITING

func _select_target() -> void:
	var locked := summoner.get_lock_target()
	if _target_valid(locked):
		target = locked
		return
	if _target_valid(target):
		return
	target = null
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group(&"enemies"):
		if not _target_valid(candidate):
			continue
		var distance := _flat_distance(global_position, candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			target = candidate

func _target_valid(candidate: Variant) -> bool:
	if not is_instance_valid(candidate) or not candidate is Node3D or not candidate.is_in_group(&"enemies"):
		return false
	if candidate.has_method("is_alive") and not candidate.call("is_alive"):
		return false
	var body := candidate as Node3D
	if _flat_distance(summoner.global_position, body.global_position) > search_range or absf(body.global_position.y - global_position.y) > 3.0:
		return false
	var from := global_position + Vector3.UP * 1.2
	var to := body.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to, FLOOR_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty() and _ground_route_to(body.global_position)

func _ground_route_to(destination: Vector3) -> bool:
	var distance := _flat_distance(global_position, destination)
	var steps := maxi(1, ceili(distance / 1.2))
	var last_y := global_position.y
	for i in range(1, steps + 1):
		var point := global_position.lerp(destination, float(i) / float(steps))
		var floor_point := _floor_at(point)
		if floor_point == Vector3.INF or absf(floor_point.y - last_y) > max_step_height:
			return false
		last_y = floor_point.y
	return true

func _follow_position() -> Vector3:
	return summoner.global_position + summoner.global_basis.x * follow_distance - summoner.global_basis.z * 0.5

func _move_safely(direction: Vector3, step_length: float) -> bool:
	if step_length <= 0.001:
		return false
	for angle in [0.0, _avoid_side * 0.85, -_avoid_side * 0.85, _avoid_side * 1.55, -_avoid_side * 1.55]:
		var heading := direction.rotated(Vector3.UP, angle)
		var candidate := global_position + heading * step_length
		var floor_point := _floor_at(candidate)
		if floor_point == Vector3.INF or absf(floor_point.y - global_position.y) > max_step_height:
			continue
		if not _path_clear(global_position, floor_point):
			continue
		global_position = floor_point
		if angle != 0.0:
			_avoid_side = signf(angle)
		return true
	return false

func _path_clear(from: Vector3, to: Vector3) -> bool:
	var side := (to - from).cross(Vector3.UP).normalized() * 0.24
	for offset in [Vector3.ZERO, side, -side]:
		var query := PhysicsRayQueryParameters3D.create(from + offset + Vector3.UP * 0.8, to + offset + Vector3.UP * 0.8, FLOOR_MASK)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true

func _floor_at(point: Vector3) -> Vector3:
	var start_y := maxf(point.y, summoner.global_position.y) + 2.0
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, start_y, point.z), Vector3(point.x, start_y - 5.0, point.z), FLOOR_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.7:
		return Vector3.INF
	return hit.position + Vector3.UP * 0.2

func _rejoin_player() -> void:
	for offset in [summoner.global_basis.x * follow_distance, -summoner.global_basis.x * follow_distance, -summoner.global_basis.z * follow_distance]:
		var point := _floor_at(summoner.global_position + offset)
		if point != Vector3.INF and _path_clear(summoner.global_position + Vector3.UP * 0.2, point):
			global_position = point
			_returning = false
			target = null
			_next_attack_at = maxf(_next_attack_at, _elapsed + 0.35)
			break
	_stuck_time = 0.0

func _face(point: Vector3, delta: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1.0, 8.0 * delta))

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## Reserva os estados de locomoção e ataque para a próxima etapa.
func set_action_state(next_state: State) -> void:
	if state == State.DESPAWNING or next_state not in [State.IDLE, State.MOVING, State.ATTACKING]:
		return
	state = next_state

func despawn() -> void:
	if state == State.DESPAWNING and is_queued_for_deletion():
		return
	if is_instance_valid(attack_hitbox):
		_clear_attack()
	if is_instance_valid(stage_vfx):
		stage_vfx.play_despawn()
	state = State.DESPAWNING
	queue_free()
