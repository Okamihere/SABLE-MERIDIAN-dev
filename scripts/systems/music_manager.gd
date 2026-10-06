extends Node

## Música ambiente global do jogo, separada por contexto.
##
## TITLE toca "Phantom-Fool-s-Lullaby" (fool = o veyl protagonista).
## GAMEPLAY toca GAMEPLAY_TRACK (provisória: ver abaixo).
## Uma única instância (Autoload) com um único AudioStreamPlayer.
## Troca de faixa com fade-out/in curto (~1.4 s, sem silêncio longo).
## Loop simples via `finished` (imports .wav sem loop nativo).
## Fades mexem só no volume_db do player; buses Master/Music intocados.
##
## GAMEPLAY_TRACK é provisória: nenhum nome deixa evidente qual é o tema
## principal de gameplay ("From_The_Ashes" sugere ação/renascimento;
## "Misery_Loves_Company" soa mais sombria; "music-box" combina com título).
## Para trocar, altere a constante abaixo.

## Tema da tela inicial (fixo por direção).
const TITLE_TRACK := preload("res://assets/audio/music/Sable_Meridian.wav")
## Tema da gameplay (PROVISÓRIO — ver comentário acima).
const GAMEPLAY_TRACK := preload("res://assets/audio/music/05.From_The_Ashes.wav")

## Contextos preparados (TITLE/GAMEPLAY ativos; resto é futuro, não implementar).
enum Context { NONE, TITLE, GAMEPLAY }

const FADE_OUT_TIME := 0.6
const FADE_IN_TIME := 0.8
const SILENT_DB := -40.0

var current_context: Context = Context.NONE

var _player: AudioStreamPlayer
var _fade_tween: Tween
var _transition_gen: int = 0
var _transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_music_bus()
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = "Music"
	add_child(_player)
	_player.finished.connect(_on_track_finished)
	if get_tree().has_signal("scene_changed"):
		get_tree().scene_changed.connect(_on_scene_changed)
	# Boot cai na tela inicial: tema do título, com fade-in discreto.
	_switch_to(TITLE_TRACK, Context.TITLE, true)


func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")


## Tema do título (chamado na entrada da tela inicial / retorno a ela).
func play_title_music() -> void:
	_switch_to(TITLE_TRACK, Context.TITLE)


## Tema da gameplay (chamado na entrada da gameplay).
func play_gameplay_music() -> void:
	_switch_to(GAMEPLAY_TRACK, Context.GAMEPLAY)


## Toca uma faixa avulsa sem contexto (compatibilidade/futuro).
func play_music(stream: AudioStream, fade_in: bool = true) -> void:
	if stream == null or _player == null:
		return
	_transition_gen += 1
	_transitioning = false
	_kill_fade()
	if _player.stream == stream and _player.playing:
		current_context = Context.NONE
		return
	current_context = Context.NONE
	_player.stream = stream
	_player.volume_db = SILENT_DB if fade_in else 0.0
	_player.play()
	if fade_in:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player, "volume_db", 0.0, FADE_IN_TIME)


## Troca com fade-out/in; mesma faixa em reprodução não reinicia.
## Chamadas concorrentes ou cena trocada no meio: só a última vale.
func _switch_to(stream: AudioStream, context: Context, fade_in: bool = true) -> void:
	if stream == null or _player == null:
		return
	if _player.stream == stream and _player.playing and not _transitioning:
		current_context = context
		return
	_transition_gen += 1
	var generation := _transition_gen
	_transitioning = true
	current_context = context
	_switch_async(stream, generation, fade_in, _player.playing)


func _switch_async(stream: AudioStream, generation: int, fade_in: bool, fade_out: bool) -> void:
	_kill_fade()
	if fade_out:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player, "volume_db", SILENT_DB, FADE_OUT_TIME)
		await _fade_tween.finished
		if generation != _transition_gen or not is_instance_valid(_player):
			return
	_player.stream = stream
	_player.volume_db = SILENT_DB if fade_in else 0.0
	_player.play()
	if fade_in:
		_kill_fade()
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player, "volume_db", 0.0, FADE_IN_TIME)
		await _fade_tween.finished
		if generation != _transition_gen:
			return
	if generation == _transition_gen:
		_transitioning = false


func _kill_fade() -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null


## Loop simples: repete a faixa atual; nunca ressuscita faixa anterior,
## pois só toca o stream corrente (e nunca durante transição alheia).
func _on_track_finished() -> void:
	if _transitioning or not is_instance_valid(_player):
		return
	_player.play()


## Contexto pela cena atual (grupo "title_screen", já usado no projeto).
## Fase -> fase mantém a faixa (guard em _switch_to evita restart).
func _on_scene_changed() -> void:
	_apply_context_for_current_scene.call_deferred()


func _apply_context_for_current_scene() -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	if get_tree().current_scene.is_in_group("title_screen"):
		play_title_music()
	else:
		play_gameplay_music()


## Apenas o player global conta como música (checagem de sanidade).
func player_count() -> int:
	var total := 0
	for child in get_children():
		if child is AudioStreamPlayer:
			total += 1
	return total
