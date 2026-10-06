extends Control

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const CRT_SHADER := preload("res://shaders/press_start_crt.gdshader")
const CAMERA_MOVE_TIME := 1.35
const FADE_IN_TIME := 1.0
const INTRO_FOCUS := Vector3(0, 1.35, 1.7)
const TITLE_FOCUS := Vector3(0, 1.75, 0)

@onready var preview: Node3D = $TitlePreview
@onready var preview_camera: Camera3D = $TitlePreview/Camera
@onready var intro_viewport: SubViewport = $IntroViewport
@onready var prompt: Label = $IntroViewport/ScreenUi/Prompt
@onready var screen_light: OmniLight3D = $TitlePreview/ScreenGlow

var _starting := false
var _time := 0.0
var _flight_time := 0.0
var _flight_to := Vector3.ZERO
var _intro_pcam: PhantomCamera3D
var _title_pcam: PhantomCamera3D

func _ready() -> void:
	preview.set("cinematic_preview", true)
	get_viewport().size_changed.connect(_update_cinematic_camera)
	_update_cinematic_camera()
	_setup_phantom_camera()
	preview.get_node("Stage/CoffeeTable").scale.x = 1.12
	var sofa: Node3D = preview.get_node("Stage/SofaFacingTelevision")
	sofa.position.z = 3.3
	sofa.scale.x = 1.2
	preview.get_node("Television/AntennaLeft").visible = false
	preview.get_node("Television/AntennaRight").visible = false
	_build_crt_screen()
	_configure_lighting()
	_build_backdrop()
	_apply_low_res_materials()

func _update_cinematic_camera() -> void:
	if _starting:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return
	var aspect := viewport_size.x / viewport_size.y
	var half_fov := deg_to_rad(preview_camera.fov) * 0.5
	var distance := maxf(6.4, 4.35 / (2.0 * tan(half_fov) * aspect))
	preview_camera.position = Vector3(0, 3.35, distance)
	preview_camera.look_at(INTRO_FOCUS)
	if is_instance_valid(_intro_pcam):
		_intro_pcam.global_transform = preview_camera.global_transform
	if is_instance_valid(_title_pcam):
		_title_pcam.position = Vector3(0, 2.0, preview.get("_camera_distance"))
		_title_pcam.look_at(TITLE_FOCUS)

func _setup_phantom_camera() -> void:
	var host := PhantomCameraHost.new()
	host.name = "PhantomCameraHost"
	host.interpolation_mode = PhantomCameraHost.InterpolationMode.IDLE
	preview_camera.add_child(host)
	_intro_pcam = PhantomCamera3D.new()
	_intro_pcam.name = "IntroFraming"
	_intro_pcam.tween_on_load = false
	_intro_pcam.priority = 1
	preview.add_child(_intro_pcam)
	_intro_pcam.global_transform = preview_camera.global_transform
	_title_pcam = PhantomCamera3D.new()
	_title_pcam.name = "TelevisionFraming"
	_title_pcam.priority = 0
	var camera_tween := PhantomCameraTween.new()
	camera_tween.duration = CAMERA_MOVE_TIME
	camera_tween.transition = PhantomCameraTween.TransitionType.SINE
	camera_tween.ease = PhantomCameraTween.EaseType.EASE_IN_OUT
	_title_pcam.tween_resource = camera_tween
	preview.add_child(_title_pcam)
	_title_pcam.position = Vector3(0, 2.0, preview.get("_camera_distance"))
	_title_pcam.look_at(TITLE_FOCUS)

func _build_crt_screen() -> void:
	var screen: MeshInstance3D = preview.get("screen_mesh")
	var size := (screen.mesh as QuadMesh).size
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 16:
		for column in 28:
			var u0 := float(column) / 28.0
			var u1 := float(column + 1) / 28.0
			var v0 := float(row) / 16.0
			var v1 := float(row + 1) / 16.0
			for uv in [Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1)]:
				var p: Vector2 = uv * 2.0 - Vector2.ONE
				var bulge: float = 0.09 * (1.0 - p.x * p.x) * (1.0 - p.y * p.y)
				surface.set_uv(uv)
				surface.add_vertex(Vector3((uv.x - 0.5) * size.x, (0.5 - uv.y) * size.y, bulge))
	surface.generate_normals()
	screen.mesh = surface.commit()
	var crt := ShaderMaterial.new()
	crt.shader = CRT_SHADER
	crt.set_shader_parameter("screen_texture", intro_viewport.get_texture())
	screen.material_override = crt

func _configure_lighting() -> void:
	var key_light: OmniLight3D = preview.get_node("KeyLight")
	key_light.light_color = Color(0.78, 0.36, 0.4)
	key_light.light_energy = 1.0
	var rim_light: OmniLight3D = preview.get_node("RimLight")
	rim_light.light_color = Color(0.85, 0.46, 0.28)
	rim_light.light_energy = 0.75
	screen_light.light_color = Color(0.35, 0.72, 0.88)
	screen_light.light_energy = 1.65
	screen_light.omni_range = 5.4
	screen_light.shadow_enabled = true
	for side in [-1.0, 1.0]:
		var curtain_fill := OmniLight3D.new()
		curtain_fill.name = "CurtainScreenLight"
		curtain_fill.position = Vector3(side * 1.75, 1.95, 1.3)
		curtain_fill.light_color = Color(0.25, 0.62, 0.78)
		curtain_fill.light_energy = 0.52 if side < 0.0 else 0.27
		curtain_fill.omni_range = 2.5
		preview.add_child(curtain_fill)
	var furniture_light: OmniLight3D = preview.get_node("Stage/FurnitureLight")
	furniture_light.light_color = Color(0.59, 0.43, 0.44)
	furniture_light.light_energy = 0.6
	furniture_light.shadow_enabled = true
	var world: WorldEnvironment = preview.get_node("WorldEnvironment")
	world.environment = world.environment.duplicate()
	world.environment.fog_enabled = true
	world.environment.fog_density = 0.012
	world.environment.fog_light_color = Color(0.08, 0.14, 0.2)
	world.environment.ambient_light_color = Color(0.3, 0.26, 0.29)
	world.environment.ambient_light_energy = 0.52
	world.environment.glow_enabled = true
	world.environment.glow_intensity = 0.65
	world.environment.glow_bloom = 0.04
	world.environment.glow_hdr_threshold = 0.9
	var ember_light := OmniLight3D.new()
	ember_light.name = "EmberLight"
	ember_light.position = Vector3(0.54, 0.61, 2.24)
	ember_light.light_color = Color(1.0, 0.18, 0.04)
	ember_light.light_energy = 0.24
	ember_light.omni_range = 0.35
	preview.add_child(ember_light)
	var sofa_fill := OmniLight3D.new()
	sofa_fill.name = "SofaFill"
	sofa_fill.position = Vector3(0, 1.7, 5.2)
	sofa_fill.light_color = Color(0.48, 0.23, 0.29)
	sofa_fill.light_energy = 0.4
	sofa_fill.omni_range = 3.0
	preview.add_child(sofa_fill)
	var particles: GPUParticles3D = preview.get_node("TitleParticles")
	particles.amount = 28
	_build_dust()

func _build_dust() -> void:
	var dust := CPUParticles3D.new()
	dust.name = "CinematicDust"
	dust.position = Vector3(0, 1.8, 1.2)
	dust.amount = 10
	dust.lifetime = 11.0
	dust.preprocess = 11.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(3.1, 1.5, 1.8)
	dust.gravity = Vector3.ZERO
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 180.0
	dust.initial_velocity_min = 0.005
	dust.initial_velocity_max = 0.025
	dust.color = Color(0.58, 0.78, 0.84, 0.14)
	var particle_mesh := QuadMesh.new()
	particle_mesh.size = Vector2(0.012, 0.012)
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.albedo_color = Color(0.6, 0.8, 0.9, 0.35)
	particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_mesh.material = particle_material
	dust.mesh = particle_mesh
	preview.add_child(dust)

func _build_backdrop() -> void:
	var backdrop := MeshInstance3D.new()
	backdrop.name = "CinematicBackdrop"
	var backdrop_mesh := BoxMesh.new()
	backdrop_mesh.size = Vector3(30, 12, 0.2)
	backdrop.mesh = backdrop_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.012, 0.016, 0.025)
	backdrop.material_override = material
	backdrop.position = Vector3(0, 2, -1.2)
	preview.add_child(backdrop)
	for side in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		wall.name = "SideWall"
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(0.14, 4.8, 6.4)
		wall.mesh = wall_mesh
		var wall_material := StandardMaterial3D.new()
		wall_material.albedo_color = Color(0.055, 0.075, 0.105)
		wall_material.roughness = 0.95
		wall.material_override = wall_material
		wall.position = Vector3(side * 4.2, 1.9, 1.6)
		preview.add_child(wall)

func _apply_low_res_materials() -> void:
	var fabric := _noise_texture("fabric", 64, 518)
	var wood := _noise_texture("wood", 64, 911)
	var floor_texture := _noise_texture("floor", 64, 271)
	var metal := _noise_texture("metal", 64, 63)
	var stage: Node3D = preview.get_node("Stage")
	for path in ["CurtainLeft/FacetedFabric", "CurtainRight/FacetedFabric", "CurtainCrown/FacetedCrown"]:
		_texture_mesh(stage.get_node(path), fabric, 0.95)
	var table: Node3D = stage.get_node("CoffeeTable")
	for child in table.get_children():
		if child is MeshInstance3D:
			_texture_mesh(child, wood, 0.6)
	var sofa: Node3D = stage.get_node("SofaFacingTelevision")
	for child in sofa.get_children():
		if child is MeshInstance3D and child.name != "BackSeam":
			_texture_mesh(child, fabric, 0.94)
	var floor_mesh: MeshInstance3D = stage.get_node("LivingRoomFloor")
	_texture_mesh(floor_mesh, floor_texture, 0.98)
	(floor_mesh.material_override as StandardMaterial3D).albedo_color = Color(0.19, 0.12, 0.14)
	var television: Node3D = preview.get_node("Television")
	for child in television.get_children():
		if child is MeshInstance3D and child.name in ["OuterCase", "CaseInset", "ControlBay"]:
			_texture_mesh(child, metal, 0.7)
		elif child is MeshInstance3D and child.name in ["LeftTrim", "RightTrim", "TopTrim", "BottomTrim", "DialRim"]:
			_texture_mesh(child, metal, 0.72)
			(child.material_override as StandardMaterial3D).metallic = 0.35
	for child in preview.get_children():
		if child is MeshInstance3D and child.name == "SideWall":
			_texture_mesh(child, floor_texture, 0.95)

func _texture_mesh(mesh: MeshInstance3D, texture: Texture2D, roughness: float) -> void:
	var original := mesh.material_override as StandardMaterial3D
	if original == null:
		return
	var material := original.duplicate() as StandardMaterial3D
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = roughness
	mesh.material_override = material

func _noise_texture(kind: String, side: int, seed_value: int) -> Texture2D:
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in side:
		for x in side:
			var grain := rng.randf_range(-0.045, 0.045)
			match kind:
				"fabric":
					grain += 0.04 * sin(float(x) * 0.47 + 0.5 * sin(float(y) * 0.3))
				"wood":
					grain += 0.07 * sin(float(y) * 0.42 + 0.45 * sin(float(x) * 0.2))
					if rng.randf() < 0.008:
						grain -= 0.12
				"floor":
					grain += 0.05 * sin(float(x) * 0.53) * sin(float(y) * 0.38)
				"metal":
					grain *= 0.45
			var shade := clampf(0.89 + grain, 0.52, 1.0)
			image.set_pixel(x, y, Color(shade, shade * 0.98, shade * 0.95))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
	_time += delta
	var prompt_brightness := 0.78 + 0.22 * sin(_time * 2.4)
	if _starting:
		_flight_time = minf(_flight_time + delta, CAMERA_MOVE_TIME)
		var progress := _flight_time / CAMERA_MOVE_TIME
		var eased := progress * progress * (3.0 - 2.0 * progress)
		prompt_brightness *= 1.0 - eased
	prompt.modulate.a = prompt_brightness
	screen_light.light_energy = 1.65 + 0.025 * sin(_time * 5.1)

func _input(event: InputEvent) -> void:
	if _starting:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_start()
	elif event is InputEventJoypadButton and event.pressed:
		_start()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start()

func _start() -> void:
	_starting = true
	UiSfx.play_confirm()
	get_viewport().set_input_as_handled()
	var title_distance: float = preview.get("_camera_distance")
	_flight_to = Vector3(0, 2.0, title_distance)
	_title_pcam.position = _flight_to
	_title_pcam.look_at(TITLE_FOCUS)
	_title_pcam.priority = 2
	_finish_transition()

func _finish_transition() -> void:
	var veil_layer := CanvasLayer.new()
	veil_layer.layer = 250
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0, 0, 0, 0)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil_layer.add_child(veil)
	get_tree().root.add_child(veil_layer)
	var tree := get_tree()
	var scene_path := TITLE_SCENE
	var fade := veil_layer.create_tween()
	fade.tween_property(veil, "color:a", 1.0, FADE_IN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_interval(CAMERA_MOVE_TIME - FADE_IN_TIME + 0.05)
	fade.tween_callback(func(): tree.change_scene_to_file(scene_path))
	fade.tween_interval(0.12)
	fade.tween_property(veil, "color:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_callback(veil_layer.queue_free)
