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
	# v0.4.2: only the sun ever casts shadows. The moon's shadow flag
	# is set off explicitly (it defaults off, but a shadow-casting
	# light appearing at the night transition would be another
	# render-state change in the same frame as everything else).
	moon.shadow_enabled = false
	root.add_child(moon)
	var layer := CanvasLayer.new()
	add_child(layer)
	clock = Label.new()
	clock.add_theme_font_size_override("font_size", 34)
	clock.add_theme_constant_override("outline_size", 6)
	clock.add_theme_color_override("font_outline_color", Color.BLACK)
	clock.position = Vector2(get_viewport().get_visible_rect().size.x - 170.0, 70.0)
	layer.add_child(clock)
	_fx_setup()

# v0.3.1: day and night are exactly half the cycle each (20 min + 20 min
# of a 2400 s day_length). Was 0.22/0.78 (night 44%, day 56%).
func is_night() -> bool:
	return t < 0.25 or t > 0.75

func _process(delta: float) -> void:
	if env == null or sky_mat == null or sun == null or moon == null:
		return
	t = fposmod(t + delta / Settings.day_length, 1.0)
	var d := sin((t - 0.25) * TAU)
	var day := clampf(d * 2.5 + 0.35, 0.0, 1.0)
	# v0.4 (G): weather darkening + lightning flash, read from the world.
	var w := get_parent()
	var dark := 0.0
	var flash := 0.0
	if w != null:
		var dv = w.get("weather_dark")
		if dv != null:
			dark = float(dv)
		var fv = w.get("lightning_flash")
		if fv != null:
			flash = float(fv)
	day = clampf(day * (1.0 - dark * 0.6), 0.0, 1.0)
	var warm := pow(clampf(1.0 - absf(d), 0.0, 1.0), 4.0)
	sun.rotation_degrees = Vector3(-(t - 0.25) * 360.0, -35.0, 0.0)
	# v0.4.1: sun 1.3 -> 1.15 (part of the building blow-out fix).
	sun.light_energy = day * 1.15
	sun.light_color = Color(1, 1, 1).lerp(Color(1.0, 0.6, 0.35), warm)
	# v0.4.2 FREEZE FIX: the sun's visibility was toggled off every
	# night (day <= 0.01) and back on at dawn. Toggling a shadow-casting
	# directional light rebuilds the shadow state on the mobile GPU —
	# the prime suspect for the on-device freeze, which hangs the app
	# (no force-close, no GDScript error) at the transition. The sun
	# now stays visible forever; its energy fades smoothly to 0 at
	# night, so the render state never switches.
	moon.rotation_degrees = Vector3(-(t - 0.25) * 360.0 + 180.0, -35.0, 0.0)
	# v0.4.1 NIGHT FIX: the old night floor was effectively black on a
	# phone screen — moon 0.3, ambient 0.5 at (0.08,0.1,0.2), sky top
	# (0.02,0.03,0.09), and ACES crushing the shadows. Night is now a
	# visible deep blue: moon 0.75, brighter sky and ambient, so the
	# scene is NEVER black. Lit windows + car headlights still add
	# their own light on top (night_glow.gd).
	moon.light_energy = (1.0 - day) * 0.75
	var top := Color(0.06, 0.09, 0.18).lerp(Color(0.22, 0.46, 0.88), day)
	var hor := Color(0.14, 0.17, 0.28).lerp(Color(0.68, 0.8, 0.92), day).lerp(Color(1.0, 0.5, 0.25), warm * 0.8)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = top.darkened(0.5)
	env.ambient_light_color = Color(0.18, 0.22, 0.34).lerp(Color(0.75, 0.8, 0.9), day)
	# v0.4.1: ambient energy floor 0.5 -> 0.85 at night, 1.0 -> 0.9 by
	# day (less blow-out); lightning still spikes it.
	env.ambient_light_energy = lerpf(0.85, 0.9, day) + flash * 1.2
	var hrs := t * 24.0
	_fx_update(day, warm, hor)
	clock.text = "%02d:%02d" % [int(hrs), int(fmod(hrs, 1.0) * 60.0)]

func _fx_setup() -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	env.glow_enabled = Settings.quality >= 1
	env.glow_intensity = 0.8
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = Settings.quality >= 1
	env.fog_density = 0.004
	env.fog_sky_affect = 0.5
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

func _fx_update(day: float, warm: float, hor: Color) -> void:
	env.fog_light_color = hor
	# v0.4 (G): rain thickens the fog (dark = weather_dark from the world).
	var w := get_parent()
	var dark := 0.0
	if w != null:
		var dv = w.get("weather_dark")
		if dv != null:
			dark = float(dv)
	env.fog_density = lerpf(0.007, 0.0035, day) + dark * 0.004
	env.glow_intensity = lerpf(1.0, 0.6, day)
	# v0.4.1: brighter at night (1.15 -> 1.3) so the raised light floor
	# is not crushed back to black; slightly dimmer by day (1.0 -> 0.95).
	env.tonemap_exposure = lerpf(1.3, 0.95, day)
