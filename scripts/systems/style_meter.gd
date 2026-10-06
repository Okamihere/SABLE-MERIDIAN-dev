class_name StyleMeter
extends Node

## Combo conta acertos; Performance recompensa variedade e perde força sem combate.

signal changed(combo: int, score: int, rank: String)
signal combo_changed(combo: int)
signal combo_broken(previous_combo: int, reason: StringName)
signal style_changed(score: int)
signal rank_raised(rank: String)
signal rank_lowered(rank: String)
signal max_rank_reached(rank: String)

@export_range(0.5, 10.0, 0.1) var combo_timeout: float = 3.0
@export_range(0.5, 15.0, 0.1) var decay_delay: float = 4.0
@export_range(0.0, 500.0, 1.0) var decay_points_per_second: float = 40.0
@export_range(0.05, 1.0, 0.05) var decay_interval: float = 0.25
@export_range(0.0, 1.0, 0.05) var damage_penalty_fraction: float = 0.25
@export var damage_penalty_minimum: int = 150
@export var repeat_multipliers: Array[float] = [1.0, 0.7, 0.4, 0.25]
@export var variety_multiplier: float = 1.2
@export var weapon_switch_bonus: int = 45
@export var aerial_hit_bonus: int = 30
@export var skill_hit_bonus: int = 25
@export var finisher_hit_bonus: int = 55
@export var perfect_dodge_bonus: int = 250
@export var rank_names: Array[String] = ["I", "II", "III", "IV", "V", "VI"]
@export var rank_thresholds: Array[int] = [0, 750, 1800, 3500, 6500, 10000]

var combo_count: int = 0
var score: int = 0
var rank: String = "I"
var rank_index: int = 0

var _combo_expire_time: float = 0.0
var _last_style_action_time: float = 0.0
var _decay_elapsed: float = 0.0
var _last_attack_id: StringName = &""
var _last_weapon_id: StringName = &""
var _repeat_count: int = 0
var _recent_attacks: Array[StringName] = []

func _ready() -> void:
	rank = rank_names[0]
	_last_style_action_time = Time.get_ticks_msec() / 1000.0

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if combo_count > 0 and now > _combo_expire_time:
		_break_combo(&"timeout")
		_emit_style()
	if score == 0 or decay_points_per_second <= 0.0 or now - _last_style_action_time < decay_delay:
		return
	_decay_elapsed += delta
	if _decay_elapsed < decay_interval:
		return
	var elapsed := floori(_decay_elapsed / decay_interval) * decay_interval
	_decay_elapsed -= elapsed
	var lost := maxi(1, roundi(decay_points_per_second * elapsed))
	score = maxi(0, score - lost)
	_update_rank()
	_emit_style()

## Chame somente quando o acerto for confirmado pela hitbox.
func register_hit(attack_id: StringName, base_points: int, weapon_id: StringName = &"") -> void:
	combo_count += 1
	_combo_expire_time = Time.get_ticks_msec() / 1000.0 + combo_timeout
	if attack_id == _last_attack_id:
		_repeat_count += 1
	else:
		_repeat_count = 0
	var repetition := repeat_multipliers[mini(_repeat_count, repeat_multipliers.size() - 1)]
	var varied := combo_count > 1 and not _recent_attacks.has(attack_id)
	var multiplier := repetition * (variety_multiplier if varied else 1.0)
	var earned := roundi(base_points * multiplier)
	if weapon_id != &"" and _last_weapon_id != &"" and weapon_id != _last_weapon_id:
		earned += weapon_switch_bonus
	if _is_aerial(attack_id):
		earned += aerial_hit_bonus
	if _is_skill(attack_id):
		earned += skill_hit_bonus
	if _is_finisher(attack_id, weapon_id):
		earned += finisher_hit_bonus
	_last_attack_id = attack_id
	if weapon_id != &"":
		_last_weapon_id = weapon_id
	_recent_attacks.append(attack_id)
	if _recent_attacks.size() > 4:
		_recent_attacks.pop_front()
	score += maxi(0, earned)
	_mark_action()
	_update_rank()
	combo_changed.emit(combo_count)
	_emit_style()

func register_perfect_dodge() -> void:
	score += perfect_dodge_bonus
	_mark_action()
	_update_rank()
	_emit_style()

func player_damaged() -> void:
	_break_combo(&"damage")
	score = maxi(0, score - maxi(damage_penalty_minimum, roundi(score * damage_penalty_fraction)))
	_mark_action()
	_update_rank()
	_emit_style()

func reset() -> void:
	_break_combo(&"reset")
	score = 0
	_last_attack_id = &""
	_last_weapon_id = &""
	_repeat_count = 0
	_recent_attacks.clear()
	_mark_action()
	_update_rank()
	_emit_style()

func _break_combo(reason: StringName) -> void:
	if combo_count == 0:
		return
	var previous := combo_count
	combo_count = 0
	_repeat_count = 0
	_last_attack_id = &""
	_last_weapon_id = &""
	_recent_attacks.clear()
	combo_broken.emit(previous, reason)
	combo_changed.emit(0)

func _mark_action() -> void:
	_last_style_action_time = Time.get_ticks_msec() / 1000.0
	_decay_elapsed = 0.0

func _update_rank() -> void:
	var previous := rank_index
	var highest := mini(rank_names.size(), rank_thresholds.size()) - 1
	rank_index = 0
	for index in range(1, highest + 1):
		if score >= rank_thresholds[index]:
			rank_index = index
	rank = rank_names[rank_index]
	if rank_index > previous:
		rank_raised.emit(rank)
		if rank_index == highest:
			max_rank_reached.emit(rank)
	elif rank_index < previous:
		rank_lowered.emit(rank)

func _emit_style() -> void:
	style_changed.emit(score)
	changed.emit(combo_count, score, rank)

func _is_aerial(attack_id: StringName) -> bool:
	var id := String(attack_id)
	return id.begins_with("air_") or id.contains("_air_")

func _is_skill(attack_id: StringName) -> bool:
	var id := String(attack_id)
	return id.ends_with("_q") or id.ends_with("_e") or id.ends_with("_r") or attack_id == &"cursed_card"

func _is_finisher(attack_id: StringName, weapon_id: StringName) -> bool:
	if attack_id in [&"light_4", &"dagger_light_4", &"strings_light_4", &"cane_light_4", &"grimoire_light_4", &"launcher"]:
		return true
	return false
