extends SceneTree

const LEVELS := [
	"start_room", "main", "vertical_pilot", "world_01", "world_02", "world_03",
	"world_04", "world_05", "world_06", "world_07", "world_08",
]

func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()

func _watchdog() -> void:
	await create_timer(90.0).timeout
	push_error("Skybox validation timed out")
	quit(1)

func _run() -> void:
	var sky_ids := {}
	var cloud_reference := load("res://materials/contemplative_sky.tres") as ShaderMaterial
	for level in LEVELS:
		var path: String = "res://scenes/levels/" + level + ".tscn"
		assert(change_scene_to_file(path) == OK, "Cena não carregou: %s" % level)
		for frame in 4:
			await physics_frame
			await process_frame
		assert(current_scene != null and current_scene.scene_file_path == path, "Cena não abriu: %s" % level)
		var environments := current_scene.find_children("*", "WorldEnvironment", true, false)
		assert(environments.size() == 1, "WorldEnvironment ausente ou duplicado: %s" % level)
		var environment: Environment = (environments[0] as WorldEnvironment).environment
		assert(environment != null and environment.background_mode == Environment.BG_SKY, "Sky não ativo: %s" % level)
		assert(environment.sky != null and environment.sky.sky_material != null, "Material de céu ausente: %s" % level)
		_assert_cloud_sky(environment.sky, cloud_reference, level)
		assert(environment.fog_sky_affect <= 0.21, "Névoa oculta o céu: %s" % level)
		if level in ["start_room", "main"]:
			assert(not current_scene.get_node("StarDome").visible, "Cúpula antiga oculta o céu: %s" % level)
		assert(not sky_ids.has(environment.sky.get_instance_id()), "Sky compartilhado entre cenas: %s" % level)
		sky_ids[environment.sky.get_instance_id()] = true
	for title_scene in ["title_screen", "press_start"]:
		var path: String = "res://scenes/ui/" + title_scene + ".tscn"
		assert(change_scene_to_file(path) == OK, "Cena não carregou: %s" % title_scene)
		for frame in 4:
			await physics_frame
			await process_frame
		var environments := current_scene.find_children("*", "WorldEnvironment", true, false)
		assert(environments.size() == 1, "WorldEnvironment ausente ou duplicado: %s" % title_scene)
		var environment: Environment = (environments[0] as WorldEnvironment).environment
		assert(environment != null and environment.background_mode == Environment.BG_SKY, "Sky não ativo: %s" % title_scene)
		_assert_night_sky(environment.sky, title_scene)
	print("SKYBOX PASS: 11 níveis com nuvens animadas e 2 cenas de abertura")
	quit(0)

func _assert_cloud_sky(sky: Sky, reference: ShaderMaterial, scene_name: String) -> void:
	assert(sky != null and sky.sky_material is ShaderMaterial, "Sky sem material animado: %s" % scene_name)
	var material := sky.sky_material as ShaderMaterial
	assert(material.shader == reference.shader, "Shader de nuvens ausente: %s" % scene_name)

func _assert_night_sky(sky: Sky, scene_name: String) -> void:
	assert(sky != null and sky.sky_material is ProceduralSkyMaterial, "Sky sem material: %s" % scene_name)
	var reference := (load("res://materials/night_sky.tres") as Sky).sky_material as ProceduralSkyMaterial
	var material := sky.sky_material as ProceduralSkyMaterial
	assert(material.sky_top_color == reference.sky_top_color and material.sky_horizon_color == reference.sky_horizon_color, "Céu diferente: %s" % scene_name)
	assert(material.ground_bottom_color == reference.ground_bottom_color and material.ground_horizon_color == reference.ground_horizon_color, "Horizonte diferente: %s" % scene_name)
