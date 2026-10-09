extends Node3D

## Armadilha do Grimório: mesmo dano e duração do selo anterior, com apoio no piso.
const HITBOX_SCRIPT := preload("res://scripts/components/hitbox_component.gd")
const VISUAL_SCRIPT := preload("res://scripts/effects/grimoire_e_visual.gd")
const DURATION := 3.4
const RAY_DEPTH := 2.8
const LEVEL_TOLERANCE := 0.85

var _age := 0.0
var _hitbox: HitboxComponent
var _visual: Node3D

func can_activate(caster: Node3D) -> bool:
	return not _find_surface(caster).is_empty()

func activate(caster: Node3D, spell: SpellResource) -> void:
	var surface := _find_surface(caster)
	if surface.is_empty():
		queue_free()
		return
	global_position = surface.position + Vector3.UP * 0.3
	_visual = VISUAL_SCRIPT.new()
	_visual.name = "MandatoryApplauseVisual"
	add_child(_visual)
	_visual.configure()
	var area := Area3D.new()
	area.set_script(HITBOX_SCRIPT)
	area.name = "ApplauseHitbox"
	area.collision_layer = 8
	area.collision_mask = 32
	add_child(area)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 1.4, 4.0)
	shape.shape = box
	area.add_child(shape)
	_hitbox = area as HitboxComponent
	_hitbox.source = caster
	_hitbox.damage = spell.damage
	_hitbox.knockback = 0.0
	_hitbox.hit_stun = 0.65
	_hitbox.launch_force = 0.0
	_hitbox.attack_id = spell.ability_id
	_hitbox.style_points = 95
	_hitbox.style_weapon_id = get_meta("style_weapon_id", &"")
	_hitbox.hit_landed.connect(_on_hit_landed)
	_hitbox.begin_attack()

func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		_hitbox.end_attack()
		queue_free()

func _on_hit_landed(hurtbox: HurtboxComponent, box: HitboxComponent) -> void:
	if is_instance_valid(_hitbox.source) and _hitbox.source is PlayerController:
		_hitbox.source.combat.register_magic_hit(hurtbox, box)
	if is_instance_valid(_visual):
		_visual.mark_impact(hurtbox.global_position)

func _find_surface(caster: Node3D) -> Dictionary:
	var forward := caster.global_basis.z.normalized()
	if caster.has_method("get_lock_target"):
		var target := caster.get_lock_target() as Node3D
		if is_instance_valid(target):
			forward = target.global_position - caster.global_position
			forward.y = 0.0
			if forward.length_squared() > 0.001:
				forward = forward.normalized()
			else:
				forward = caster.global_basis.z.normalized()
	var support := _ground_at(caster, caster.global_position)
	if support.is_empty():
		return {}
	for distance in [2.2, 1.5, 0.8, 0.0]:
		var candidate := _ground_at(caster, caster.global_position + forward * distance)
		if not candidate.is_empty() and absf(candidate.position.y - support.position.y) <= LEVEL_TOLERANCE:
			return candidate
	return {}

func _ground_at(caster: Node3D, point: Vector3) -> Dictionary:
	var from := Vector3(point.x, caster.global_position.y + 0.3, point.z)
	var query := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * RAY_DEPTH, 1)
	if caster is CollisionObject3D:
		query.exclude = [(caster as CollisionObject3D).get_rid()]
	var hit := caster.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.7:
		return {}
	return hit
