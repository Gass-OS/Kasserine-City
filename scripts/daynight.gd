extends Node

var t := 0.32
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var clock: Label

var weather_gloom := 0.0
var weather_dust := 0.0
var weather_flash := 0.0
var weather_rain := 0.0
var weather_cloud := 0.0

func set_weather_effects(gloom: float, dust: float, flash: float,
        rain: float, cloud: float) -> void:
        weather_gloom = clampf(gloom, 0.0, 1.0)
        weather_dust = clampf(dust, 0.0, 1.0)
        weather_flash = clampf(flash, 0.0, 1.0)
        weather_rain = clampf(rain, 0.0, 1.0)
        weather_cloud = clampf(cloud, 0.0, 1.0)

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_setup()

func _first(node: Node, cls: String) -> Node:
	for c in node.get_children():
		if c.is_class(cls):
			return c
		var r := _first(c, cls)
		if r:
			return r
	return null

func _setup() -> void:
	var root := get_parent()
	sun = _first(root, "DirectionalLight3D") as DirectionalLight3D
	if sun == null:
		sun = DirectionalLight3D.new()
		root.add_child(sun)
	var we := _first(root, "WorldEnvironment") as WorldEnvironment
	if we == null:
		we = WorldEnvironment.new()
		root.add_child(we)
	if we.environment == null:
		we.environment = Environment.new()
	env = we.environment
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	sun.shadow_enabled = Settings.quality >= 1
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	root.add_child(moon)
	var layer := CanvasLayer.new()
	add_child(layer)
	clock = Label.new()
	clock.add_theme_font_size_override("font_size", 28)
	clock.add_theme_constant_override("outline_size", 6)
	clock.add_theme_color_override("font_outline_color", Color.BLACK)
	clock.position = Vector2(get_viewport().get_visible_rect().size.x - 130.0, 64.0)
	layer.add_child(clock)
	_fx_setup()

func is_night() -> bool:
	return t < 0.22 or t > 0.78

func _process(delta: float) -> void:
	if env == null or not is_instance_valid(env):
		return
	if sun == null or not is_instance_valid(sun):
		return
	if moon == null or not is_instance_valid(moon):
		return
	if sky_mat == null or not is_instance_valid(sky_mat):
		return
	if clock == null or not is_instance_valid(clock):
		return

	var cycle_length := clampf(Settings.day_length, 60.0, 600.0)
	t = fposmod(t + delta / cycle_length, 1.0)
	var d := sin((t - 0.25) * TAU)
	var day := clampf(d * 2.5 + 0.35, 0.0, 1.0)
	var warm := pow(clampf(1.0 - absf(d), 0.0, 1.0), 4.0)
	sun.rotation_degrees = Vector3(-(t - 0.25) * 360.0, -35.0, 0.0)
	sun.light_energy = day * 0.95 * (1.0 - 0.7 * weather_gloom)
	sun.light_color = Color(1, 1, 1).lerp(Color(1.0, 0.6, 0.35), warm)
	sun.visible = true
	moon.rotation_degrees = Vector3(-(t - 0.25) * 360.0 + 180.0, -35.0, 0.0)
	moon.light_energy = (1.0 - day) * 0.3 * (1.0 - 0.6 * weather_gloom)
	var gray := Color(0.52, 0.54, 0.58) * (0.22 + 0.78 * day)
	var haze := Color(0.85, 0.64, 0.38) * (0.28 + 0.72 * day)
	var base_top := Color(0.02, 0.03, 0.09).lerp(Color(0.22, 0.46, 0.88), day)
	var base_hor := Color(0.06, 0.07, 0.14).lerp(Color(0.68, 0.8, 0.92), day).lerp(Color(1.0, 0.5, 0.25), warm * 0.8)
	var top: Color = base_top.lerp(gray, weather_gloom * 0.75).lerp(haze, weather_dust * 0.8)
	var hor: Color = base_hor.lerp(gray.lightened(0.1), weather_gloom * 0.8).lerp(haze, weather_dust * 0.9)
	top = top.lerp(Color(0.85, 0.9, 1.0), weather_flash * 0.7)
	hor = hor.lerp(Color(0.9, 0.93, 1.0), weather_flash * 0.7)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = top.darkened(0.5)
	env.ambient_light_color = Color(0.08, 0.1, 0.2).lerp(Color(0.75, 0.8, 0.9), day)
	env.ambient_light_energy = lerpf(0.5, 0.7, day) + 2.2 * weather_flash
	var hrs := t * 24.0
	_fx_update(day, warm, hor)
	env.fog_light_color = hor.lerp(Color(0.52, 0.54, 0.58), weather_rain * 0.6).lerp(Color(0.85, 0.64, 0.38), weather_dust * 0.85)
	env.fog_density = lerpf(0.007, 0.0035, day) * (1.0 + weather_rain * 2.2 + weather_dust * 3.5 + weather_cloud * 0.5)
	clock.text = "%02d:%02d" % [int(hrs), int(fmod(hrs, 1.0) * 60.0)]

func _fx_setup() -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.22
	env.glow_enabled = Settings.quality >= 1
	env.glow_intensity = 0.8
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.5
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = Settings.quality >= 1
	env.fog_density = 0.004
	env.fog_sky_affect = 0.5
	_fx_hq()
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

func _fx_update(day: float, warm: float, hor: Color) -> void:
	env.fog_light_color = hor
	env.fog_density = lerpf(0.007, 0.0035, day)
	env.glow_intensity = lerpf(1.0, 0.2, day)
	env.tonemap_exposure = lerpf(1.15, 0.85, day)

func _fx_hq() -> void:
	var m := RenderingServer.get_current_rendering_method()
	if m == "forward_plus" and Settings.quality >= 2:
		env.ssao_enabled = true
		env.ssao_radius = 2.0
		env.ssao_intensity = 2.0
		env.ssr_enabled = true
		env.ssr_max_steps = 48
