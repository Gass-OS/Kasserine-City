extends Node

var t := 0.32
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var clock: Label

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

func is_night() -> bool:
	return t < 0.22 or t > 0.78

func _process(delta: float) -> void:
	if env == null:
		return
	t = fposmod(t + delta / Settings.day_length, 1.0)
	var d := sin((t - 0.25) * TAU)
	var day := clampf(d * 2.5 + 0.35, 0.0, 1.0)
	var warm := pow(clampf(1.0 - absf(d), 0.0, 1.0), 4.0)
	sun.rotation_degrees = Vector3(-(t - 0.25) * 360.0, -35.0, 0.0)
	sun.light_energy = day * 1.3
	sun.light_color = Color(1, 1, 1).lerp(Color(1.0, 0.6, 0.35), warm)
	sun.visible = day > 0.01
	moon.rotation_degrees = Vector3(-(t - 0.25) * 360.0 + 180.0, -35.0, 0.0)
	moon.light_energy = (1.0 - day) * 0.3
	var top := Color(0.02, 0.03, 0.09).lerp(Color(0.22, 0.46, 0.88), day)
	var hor := Color(0.06, 0.07, 0.14).lerp(Color(0.68, 0.8, 0.92), day).lerp(Color(1.0, 0.5, 0.25), warm * 0.8)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = top.darkened(0.5)
	env.ambient_light_color = Color(0.08, 0.1, 0.2).lerp(Color(0.75, 0.8, 0.9), day)
	env.ambient_light_energy = lerpf(0.5, 1.0, day)
	var hrs := t * 24.0
	clock.text = "%02d:%02d" % [int(hrs), int(fmod(hrs, 1.0) * 60.0)]
