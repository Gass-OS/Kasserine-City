extends Node

const Sfx = preload("res://scripts/sfx.gd")

const STATES = {
    "clear": {"rain": 0.0, "cloud": 0.0, "dust": 0.0, "name": "CLEAR"},
    "cloudy": {"rain": 0.0, "cloud": 0.6, "dust": 0.0, "name": "CLOUDY"},
    "rain": {"rain": 0.7, "cloud": 0.85, "dust": 0.0, "name": "RAIN"},
    "storm": {"rain": 1.0, "cloud": 1.0, "dust": 0.0, "name": "STORM"},
    "sirocco": {"rain": 0.0, "cloud": 0.25, "dust": 0.85, "name": "SIROCCO"},
}
const ORDER = ["clear", "clear", "clear", "cloudy", "cloudy", "rain", "rain", "storm", "sirocco"]

var world: Node3D
var dn
var player: Node3D
var state := "clear"
var timer := 70.0
var rain := 0.0
var cloud := 0.0
var dust := 0.0
var wetness := 0.0
var flash_t := 0.0
var next_flash := 6.0
var rain_fx: CPUParticles3D
var rain_sound: AudioStreamPlayer
var wind_sound: AudioStreamPlayer
var label: Label

func _ready() -> void:
    for i in range(6):
        await get_tree().process_frame
    world = get_parent() as Node3D
    dn = world.get_node_or_null("DayNight")
    player = world.get_node_or_null("Player") as Node3D
    if dn == null or player == null:
        return
    rain_fx = CPUParticles3D.new()
    rain_fx.amount = 800
    rain_fx.lifetime = 0.9
    rain_fx.local_coords = false
    rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    rain_fx.emission_box_extents = Vector3(16.0, 0.5, 16.0)
    rain_fx.direction = Vector3(0.12, -1.0, 0.05)
    rain_fx.spread = 2.0
    rain_fx.gravity = Vector3(0, -22.0, 0)
    rain_fx.initial_velocity_min = 14.0
    rain_fx.initial_velocity_max = 18.0
    var bm := BoxMesh.new()
    bm.size = Vector3(0.012, 0.5, 0.012)
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color = Color(0.75, 0.82, 1.0, 0.35)
    bm.material = m
    rain_fx.mesh = bm
    rain_fx.emitting = false
    world.add_child(rain_fx)
    rain_sound = AudioStreamPlayer.new()
    rain_sound.stream = Sfx.get_sound("rain")
    rain_sound.volume_db = -70.0
    add_child(rain_sound)
    rain_sound.play()
    wind_sound = AudioStreamPlayer.new()
    wind_sound.stream = Sfx.get_sound("wind")
    wind_sound.volume_db = -70.0
    add_child(wind_sound)
    wind_sound.play()
    var layer := CanvasLayer.new()
    layer.layer = 12
    add_child(layer)
    label = Label.new()
    label.position = Vector2(1086, 130)
    label.add_theme_font_size_override("font_size", 15)
    label.add_theme_constant_override("outline_size", 6)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    layer.add_child(label)

func _announce(s: String) -> void:
    var r := world.get_node_or_null("Radio")
    if r == null:
        return
    var msg := ""
    match s:
        "rain":
            msg = "Rain moving in over Kasserine. Roads will be slick, all units drive carefully."
        "storm":
            msg = "Severe thunderstorm warning. Expect low visibility and flooding."
        "sirocco":
            msg = "Sirocco winds are bringing dust. Visibility is reduced."
        "clear":
            msg = "Weather update: skies are clearing."
    if msg != "":
        r.call("say", "Dispatch", msg, false)

func _next_state() -> void:
    var s: String = ORDER[randi() % ORDER.size()]
    var tries := 0
    while s == state and tries < 10:
        s = ORDER[randi() % ORDER.size()]
        tries += 1
    if s == "storm" and state != "rain":
        s = "rain"
    state = s
    timer = randf_range(100.0, 190.0)
    rain_fx.amount = 450 if state == "rain" else 900
    _announce(s)

func _thunder() -> void:
    Sfx.play(self, "thunder", -4.0)

func _process(delta: float) -> void:
    if dn == null or player == null or rain_fx == null:
        return
    var env = dn.get("env")
    var sun = dn.get("sun")
    var sky_mat = dn.get("sky_mat")
    if env == null or sun == null or sky_mat == null:
        return
    timer -= delta
    if timer <= 0.0:
        _next_state()
    var st: Dictionary = STATES[state]
    rain = move_toward(rain, float(st["rain"]), delta * 0.09)
    cloud = move_toward(cloud, float(st["cloud"]), delta * 0.08)
    dust = move_toward(dust, float(st["dust"]), delta * 0.07)
    var wet_target := 1.0 if rain > 0.25 else 0.0
    wetness = move_toward(wetness, wet_target, delta * (0.06 if wet_target > wetness else 0.012))
    var t: float = dn.get("t")
    var sun_angle := sin((t - 0.25) * TAU)
    var day := clampf(sun_angle * 2.5 + 0.35, 0.0, 1.0)
    var warm := pow(clampf(1.0 - absf(sun_angle), 0.0, 1.0), 4.0)
    var gloom := clampf(cloud * 0.8 + rain * 0.5 + dust * 0.5, 0.0, 1.0)
    if state == "storm":
        next_flash -= delta
        if next_flash <= 0.0:
            flash_t = 0.3
            next_flash = randf_range(5.0, 14.0)
            get_tree().create_timer(randf_range(0.6, 2.4)).timeout.connect(_thunder)
    var flash := 0.0
    if flash_t > 0.0:
        flash_t -= delta
        flash = clampf(flash_t / 0.3, 0.0, 1.0)
        if int(flash_t * 40.0) % 3 != 0:
            flash *= 0.4
    sun.light_energy = day * 0.95 * (1.0 - 0.7 * gloom)
    var moon = dn.get("moon")
    if moon != null:
        moon.light_energy = (1.0 - day) * 0.3 * (1.0 - 0.6 * gloom)
    var gray := Color(0.52, 0.54, 0.58) * (0.22 + 0.78 * day)
    var haze := Color(0.85, 0.64, 0.38) * (0.28 + 0.72 * day)
    gray.a = 1.0
    haze.a = 1.0
    var base_top := Color(0.02, 0.03, 0.09).lerp(Color(0.22, 0.46, 0.88), day)
    var base_hor := Color(0.06, 0.07, 0.14).lerp(Color(0.68, 0.8, 0.92), day).lerp(Color(1.0, 0.5, 0.25), warm * 0.8)
    var top: Color = base_top.lerp(gray, gloom * 0.75).lerp(haze, dust * 0.8)
    var hor: Color = base_hor.lerp(gray.lightened(0.1), gloom * 0.8).lerp(haze, dust * 0.9)
    top = top.lerp(Color(0.85, 0.9, 1.0), flash * 0.7)
    hor = hor.lerp(Color(0.9, 0.93, 1.0), flash * 0.7)
    sky_mat.sky_top_color = top
    sky_mat.sky_horizon_color = hor
    sky_mat.ground_horizon_color = hor
    sky_mat.ground_bottom_color = top.darkened(0.5)
    env.fog_light_color = base_hor.lerp(gray.lightened(0.08), rain * 0.6).lerp(haze, dust * 0.85)
    var base_fog := lerpf(0.007, 0.0035, day)
    env.fog_density = base_fog * (1.0 + rain * 2.2 + dust * 3.5 + cloud * 0.5)
    env.ambient_light_energy = lerpf(0.5, 0.7, day) + 2.2 * flash
    var mpl := world.get_node_or_null("MaterialsPlus")
    if mpl != null:
        var rm = mpl.get("road_mat")
        if rm != null:
            rm.albedo_color = Color(0.16, 0.17, 0.18).darkened(0.4 * wetness)
            var dry_roughness := lerpf(0.3, 0.8, day)
            rm.roughness = lerpf(dry_roughness, 0.12, wetness)
    rain_fx.emitting = rain > 0.04
    rain_fx.global_position = player.global_position + Vector3(0, 14.0, 0)
    rain_sound.volume_db = lerpf(-70.0, -9.0, rain)
    wind_sound.volume_db = lerpf(-70.0, -14.0, clampf(dust + rain * 0.5 + cloud * 0.15, 0.0, 1.0))
    var temp := 18.0 + 11.0 * day - 5.0 * rain - 2.0 * cloud + 7.0 * dust
    label.text = "%s  %d°C" % [String(st["name"]), int(temp)]
