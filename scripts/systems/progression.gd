extends Node

## Persistência exclusiva das orbes. Não substitui o futuro save completo do jogo.
##
## Cada orbe tem ID estável; o mesmo ID só concede uma melhoria.
## O progresso é salvo em um arquivo ConfigFile no diretório user://.
## O orçamento base de saltos de parede é 2; cada orbe coletado adiciona +1.
##
## Uso típico:
##   - Adicionar como autoload no project.godot
##   - Chamar [method collect] quando o jogador coletar uma orbe
##   - Verificar [method max_wall_jumps] para o orçamento atual

## Emitido quando uma orbe é coletada. Parâmetro: novo máximo de saltos.
signal upgraded(maximum: int)
signal world_completed(world_id: StringName, total_keys: int)
signal world_progress_changed(total_keys: int)

## Caminho padrão do arquivo de save.
const SAVE_PATH := "user://wall_orbs.cfg"
const WORLD_SAVE_PATH := "user://hub_worlds.cfg"
const WORLD_IDS := [&"world_01", &"world_02", &"world_03", &"world_04", &"world_05", &"world_06", &"world_07", &"world_08"]

## Dicionário de IDs de orbes coletados.
var collected: Dictionary = {}
## Caminho do arquivo de save (pode ser alterado para testes).
var save_path: String = SAVE_PATH
var world_save_path: String = WORLD_SAVE_PATH
var completed_worlds: Dictionary = {}
var hub_return_world: StringName = &""

## Carrega o progresso salvo ao iniciar.
func _ready() -> void:
	load_progress()
	load_world_progress()

func is_world_complete(world_id: StringName) -> bool:
	return completed_worlds.has(world_id)

func key_count() -> int:
	return completed_worlds.size()

## Cada mundo concede exatamente uma chave, mesmo após revisitas.
func complete_world(world_id: StringName) -> bool:
	if not WORLD_IDS.has(world_id) or is_world_complete(world_id):
		return false
	completed_worlds[world_id] = true
	var config := ConfigFile.new()
	config.set_value("worlds", "completed", completed_worlds.keys())
	if config.save(world_save_path) != OK:
		push_warning("Não foi possível salvar as chaves; progresso mantido nesta sessão.")
	world_completed.emit(world_id, key_count())
	world_progress_changed.emit(key_count())
	return true

func load_world_progress() -> void:
	completed_worlds.clear()
	var config := ConfigFile.new()
	if config.load(world_save_path) != OK:
		return
	var ids = config.get_value("worlds", "completed", [])
	if ids is Array:
		for id in ids:
			var world_id := StringName(str(id))
			if WORLD_IDS.has(world_id):
				completed_worlds[world_id] = true

## Retorna o número máximo de saltos de parede.
## @return Quantidade máxima de saltos (2 + número de orbes coletados).
func max_wall_jumps() -> int:
	return 2 + collected.size()

## Coleta uma orbe e concede a melhoria permanente.
## @param id Identificador único da orbe.
## @return true se a orbe foi coletada, false se já foi coletada ou ID inválido.
func collect(id: String) -> bool:
	if id.is_empty() or collected.has(id):
		return false
	collected[id] = true
	var config := ConfigFile.new()
	config.set_value("wall_orbs", "ids", collected.keys())
	if config.save(save_path) != OK:
		push_warning("Não foi possível salvar as orbes; melhoria mantida nesta sessão.")
	upgraded.emit(max_wall_jumps())
	return true

## Carrega o progresso salvo do arquivo de save.
func load_progress() -> void:
	collected.clear()
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	var ids = config.get_value("wall_orbs", "ids", [])
	if ids is Array:
		for id in ids:
			if id is String and not id.is_empty():
				collected[id] = true

## Usado por Novo Jogo: limpa as melhorias persistidas e a sessão atual.
func clear_progress() -> void:
	collected.clear()
	completed_worlds.clear()
	hub_return_world = &""
	if FileAccess.file_exists(save_path):
		var result := DirAccess.remove_absolute(save_path)
		if result != OK:
			push_warning("Não foi possível apagar o progresso anterior: %s" % error_string(result))
	if FileAccess.file_exists(world_save_path):
		var result := DirAccess.remove_absolute(world_save_path)
		if result != OK:
			push_warning("Não foi possível apagar o progresso dos mundos: %s" % error_string(result))
	world_progress_changed.emit(0)
