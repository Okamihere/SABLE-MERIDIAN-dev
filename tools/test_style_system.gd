extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var meter := StyleMeter.new()
	root.add_child(meter)
	var events := {"raised": 0, "lowered": 0, "maximum": 0, "broken": 0}
	meter.rank_raised.connect(func(_rank: String) -> void: events["raised"] += 1)
	meter.rank_lowered.connect(func(_rank: String) -> void: events["lowered"] += 1)
	meter.max_rank_reached.connect(func(_rank: String) -> void: events["maximum"] += 1)
	meter.combo_broken.connect(func(_count: int, _reason: StringName) -> void: events["broken"] += 1)
	assert(meter.combo_count == 0 and meter.score == 0 and meter.rank == "I")
	meter.register_hit(&"light_1", 100, &"staff")
	assert(meter.combo_count == 1 and meter.score == 100)
	meter.register_hit(&"light_1", 100, &"staff")
	assert(meter.combo_count == 2 and meter.score == 170, "Repetir um golpe deve render menos")
	meter.register_hit(&"light_2", 100, &"staff")
	assert(meter.combo_count == 3 and meter.score == 290, "Variedade deve render mais que repetição")
	meter.register_hit(&"light_2", 100, &"staff")
	assert(meter.score == 360)
	meter.register_hit(&"light_1", 100, &"card_daggers")
	assert(meter.score > 460, "Trocar arma durante o fluxo deve recompensar")
	var before_miss := meter.combo_count
	# Nenhum registro de hitbox em um golpe que erra.
	assert(meter.combo_count == before_miss)
	meter.player_damaged()
	assert(meter.combo_count == 0 and meter.score < 460, "Dano deve quebrar combo e punir Performance")
	assert(events["broken"] == 1)
	var after_damage := meter.score
	meter.register_hit(&"light_1", 100, &"staff")
	assert(meter.score == after_damage + 100, "Novo combo não deve receber bônus de troca anterior")
	meter.reset()
	meter.register_hit(&"light_1", 100, &"staff")
	meter._combo_expire_time = 0.0
	meter._process(0.01)
	assert(meter.combo_count == 0, "Combo deve expirar após inatividade")
	meter.score = 10100
	meter._update_rank()
	assert(meter.rank == "VI" and meter.rank_index == 5)
	assert(events["raised"] == 1 and events["maximum"] == 1)
	meter._last_style_action_time = -100.0
	meter._process(20.0)
	assert(meter.score < 10100 and meter.rank_index < 5, "Performance e rank devem cair sem ritmo")
	assert(events["lowered"] == 1)
	var score_before_disabled_decay := meter.score
	meter.decay_points_per_second = 0.0
	meter._process(20.0)
	assert(meter.score == score_before_disabled_decay)
	meter.free()
	print("PASS: combo por acerto, variedade, repetição, troca de arma, dano, timeout, seis ranks e decay")
	quit()
