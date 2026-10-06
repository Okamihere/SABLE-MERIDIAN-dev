class_name SpellManager
extends Node

## Gerenciador de magias do jogador.
##
## Controla cooldowns, custo de mana e execução de magias.
## Usa contadores de cooldown e verifica ManaComponent antes de ativar efeitos.
##
## Uso típico:
##   - Adicionar como filho do jogador
##   - Configurar [member mana_component_path] para apontar ao ManaComponent
##   - Chamar [method cast_spell] para conjurar uma magia
##   - Conectar [signal spell_cast] para reagir a magias conjuradas

## Emitido quando uma magia é conjurada com sucesso. Parâmetro: magia conjurada.
signal spell_cast(spell: SpellResource)
signal spell_started(spell: SpellResource)
signal spell_ended(spell: SpellResource)

## Caminho para o ManaComponent do jogador.
@export var mana_component_path: NodePath = NodePath("../ManaComponent")

## Referência ao ManaComponent.
var _mana: ManaComponent
## Dicionário de cooldowns restantes por magia (spell_name → tempo restante).
var _cooldowns: Dictionary = {}
var _current_spell: SpellResource
var _caster: Node3D
var _pending_effect: Node
var _cast_elapsed: float = 0.0
var _effect_fired: bool = false

## Inicializa o SpellManager: obtém referência ao ManaComponent.
func _ready() -> void:
	_mana = get_node_or_null(mana_component_path) as ManaComponent
	if _mana == null:
		push_warning("SpellManager: ManaComponent não encontrado no caminho '%s'" % mana_component_path)

## Processa cooldowns das magias.
func _process(delta: float) -> void:
	for spell_name in _cooldowns.keys():
		if _cooldowns[spell_name] > 0.0:
			_cooldowns[spell_name] = maxf(0.0, _cooldowns[spell_name] - delta)
	if _current_spell == null:
		return
	_cast_elapsed += delta
	if not _effect_fired and _cast_elapsed >= _current_spell.startup_time:
		_activate_current_spell()
	if _current_spell != null and _cast_elapsed >= _current_spell.startup_time + _current_spell.active_time + _current_spell.recovery_time:
		cancel_cast()

## Tenta conjurar uma magia.
## Verifica mana e cooldown antes de executar.
## @param spell A magia a ser conjurada.
## @return true se a magia foi conjurada, false caso contrário.
func cast_spell(spell: SpellResource, caster: Node3D = null) -> bool:
	if spell == null:
		push_warning("SpellManager: tentativa de conjurar magia nula")
		return false
	if spell.effect_scene == null or not spell.effect_scene.can_instantiate():
		push_warning("SpellManager: magia '%s' tem effect_scene inválida ou não instanciável" % spell.spell_name)
		return false
	if not _can_cast(spell):
		return false
	if is_cast_committed():
		return false
	if _mana == null:
		push_warning("SpellManager: ManaComponent não disponível, impossível gastar mana")
		return false
	if caster != null and get_tree().current_scene == null:
		return false
	var effect: Node
	if caster != null:
		effect = spell.effect_scene.instantiate()
		if not effect.has_method("activate"):
			effect.free()
			push_warning("SpellManager: magia '%s' sem método activate" % spell.spell_name)
			return false
	if not _mana.try_spend(spell.mana_cost):
		if effect != null:
			effect.free()
		return false
	_start_cooldown(spell)
	_current_spell = spell
	_caster = caster
	_pending_effect = effect
	if effect != null and caster is PlayerController and caster.equipment.weapon != null:
		effect.set_meta("style_weapon_id", caster.equipment.weapon.weapon_id)
	_cast_elapsed = 0.0
	_effect_fired = false
	spell_started.emit(spell)
	if spell.startup_time <= 0.0:
		_activate_current_spell()
	return true

func _activate_current_spell() -> void:
	if _current_spell == null:
		return
	var spell := _current_spell
	_effect_fired = true
	if _pending_effect != null:
		if is_instance_valid(_caster) and get_tree().current_scene != null:
			get_tree().current_scene.add_child(_pending_effect)
			_pending_effect.activate(_caster, spell)
		else:
			_pending_effect.free()
		_pending_effect = null
	spell_cast.emit(spell)
	if spell.startup_time + spell.active_time + spell.recovery_time <= 0.0:
		cancel_cast()

func is_cast_committed() -> bool:
	return _current_spell != null

func can_cancel_cast() -> bool:
	if _current_spell == null:
		return true
	var threshold := _current_spell.cancel_window_start
	if threshold <= 0.0:
		threshold = _current_spell.startup_time + _current_spell.active_time
	return _cast_elapsed >= threshold

func cancel_cast() -> void:
	var ended_spell := _current_spell
	if _pending_effect != null:
		_pending_effect.free()
		_pending_effect = null
	_current_spell = null
	_caster = null
	_cast_elapsed = 0.0
	_effect_fired = false
	if ended_spell != null:
		spell_ended.emit(ended_spell)

## Verifica se uma magia pode ser conjurada (mana e cooldown).
## @param spell A magia a verificar.
## @return true se pode conjurar, false caso contrário.
func _can_cast(spell: SpellResource) -> bool:
	if _mana != null and _mana.current_mana < spell.mana_cost:
		return false
	if _cooldowns.get(_cooldown_key(spell), 0.0) > 0.0:
		return false
	return true

## Inicia o cooldown de uma magia.
## @param spell A magia em cooldown.
func _start_cooldown(spell: SpellResource) -> void:
	_cooldowns[_cooldown_key(spell)] = spell.cooldown

func _cooldown_key(spell: SpellResource) -> StringName:
	return spell.ability_id if spell.ability_id != &"" else StringName(spell.spell_name)

## Retorna o cooldown restante de uma magia.
## @param spell Recurso da habilidade.
## @return Tempo restante de cooldown (em segundos).
func get_cooldown_remaining(spell: SpellResource) -> float:
	if spell == null:
		return 0.0
	return _cooldowns.get(_cooldown_key(spell), 0.0)

## Regras de relíquias podem devolver uma magia sem alterar seu custo ou dano.
func reset_cooldown(spell: SpellResource) -> void:
	if spell != null:
		_cooldowns[_cooldown_key(spell)] = 0.0

## Retorna se uma magia está pronta para uso.
## @param spell A magia a verificar.
## @return true se está pronta, false caso contrário.
func is_ready(spell: SpellResource) -> bool:
	return _can_cast(spell)
