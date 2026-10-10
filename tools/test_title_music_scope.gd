extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(20.0).timeout
	push_error("Title music scope test timed out")
	quit(1)

func _frames(count: int) -> void:
	for index in count:
		await process_frame

func _run() -> void:
	var music = root.get_node("MusicManager")
	assert(music._player.stream == null and not music._player.playing, "Autoload must not start title music before scene selection")
	change_scene_to_file("res://scenes/levels/start_room.tscn")
	await _frames(8)
	assert(music._player.stream == music.GAMEPLAY_TRACK and music._player.stream != music.TITLE_TRACK, "Direct gameplay launch must never start title music")
	music.play_title_music()
	music.play_music(music.TITLE_TRACK, false)
	assert(music._player.stream == music.GAMEPLAY_TRACK, "Title music requests must be rejected outside title scenes")
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await create_timer(1.5).timeout
	assert(music._player.stream == music.TITLE_TRACK and music._player.playing, "Title scene must play its theme")
	change_scene_to_file("res://scenes/levels/vertical_pilot.tscn")
	await _frames(2)
	assert(music._player.stream == music.GAMEPLAY_TRACK and music._player.stream != music.TITLE_TRACK, "Leaving title must cut its theme before gameplay")
	change_scene_to_file("res://scenes/ui/press_start.tscn")
	await create_timer(1.5).timeout
	assert(music._player.stream == music.TITLE_TRACK and music._player.playing, "Initial press-start scene must play the title theme")
	change_scene_to_file("res://scenes/levels/main.tscn")
	await _frames(2)
	assert(music._player.stream == music.GAMEPLAY_TRACK and music._player.stream != music.TITLE_TRACK, "Title theme must stop immediately on every exit")
	print("PASS: direct gameplay boot, title and press-start music, immediate exit, rejected off-title requests")
	quit(0)
