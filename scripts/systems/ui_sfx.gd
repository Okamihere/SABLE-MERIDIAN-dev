extends Node

const CURSOR := preload("res://assets/audio/ui/interface_sfx/Cursor_tones/cursor_style_3.wav")
const CONFIRM := preload("res://assets/audio/ui/interface_sfx/Confirm_tones/style3/confirm_style_3_003.wav")
const BACK := preload("res://assets/audio/ui/interface_sfx/Back_tones/style3/back_style_3_003.wav")
const ERROR := preload("res://assets/audio/ui/interface_sfx/Error_tones/style3/error_style_3_001.wav")

var _cursor: AudioStreamPlayer
var _confirm: AudioStreamPlayer
var _back: AudioStreamPlayer
var _error: AudioStreamPlayer
var _last_cursor_ms := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	_cursor = _make_player(CURSOR, 5.0)
	_confirm = _make_player(CONFIRM, -9.0)
	_back = _make_player(BACK, -7.0)
	_error = _make_player(ERROR, -7.0)

func _make_player(sound: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = sound
	player.bus = "SFX"
	player.volume_db = volume
	add_child(player)
	return player

func play_cursor() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_cursor_ms < 75:
		return
	_last_cursor_ms = now
	_cursor.play()

func play_confirm() -> void:
	_confirm.play()

func play_back() -> void:
	_back.play()

func play_error() -> void:
	_error.play()
