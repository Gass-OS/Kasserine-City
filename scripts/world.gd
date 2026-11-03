extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const CharacterModel = preload("res://scripts/character_model.gd")

# STAGE16_DYNAMIC_WEATHER
var city_environment: Environment
var city_sky_material: ProceduralSkyMaterial
var city_sun: DirectionalLight3D
var city_rain: GPUParticles3D

# STAGE18_DOORS_SUN_MOON_WET_ROADS
# STAGE17_NIGHT_LIGHTING
var window_lit_material: StandardMaterial3D
var window_dark_material: StandardMaterial3D
var lamp_glow_material: StandardMaterial3D
var street_lamp_lights: Array[OmniLight3D] = []

# STAGE18_DOORS_SUN_MOON_WET_ROADS
var city_sun_visual: MeshInstance3D
var city_moon_visual: MeshInstance3D
var road_surface_material: StandardMaterial3D


func _ready():
    _create_environment()
    _create_city()
    _create_nature_and_vehicles()
    var player = CharacterBody3D.new()
    player.set_script(PlayerScript)
    player.name = "Player"
    add_child(player)
    player.position = Vector3(0, 1, 12)
    _create_people()
    var city_audio = Node3D.new()
    city_audio.name = "CityAudio"
    city_audio.set_script(preload("res://scripts/city_audio.gd"))
    add_child(city_audio)

    var gameplay = Node.new()
    gameplay.name = "Gameplay"
    gameplay.set_script(preload("res://scripts/gameplay.gd"))
    add_child(gameplay)

func _create_environment():
    # Bright, warm arcade-art direction: clear Mediterranean sky and soft distance haze.
    var env = Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky = Sky.new()
    var sky_material = ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.08, 0.30, 0.62)
    sky_material.sky_horizon_color = Color(0.55, 0.72, 0.88)
    sky_material.ground_bottom_color = Color(0.42, 0.31, 0.22)
    sky_material.ground_horizon_color = Color(0.78, 0.72, 0.58)
    sky_material.sun_angle_max = 24.0
    sky.sky_material = sky_material
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.78, 0.84, 1.0)
    env.ambient_light_energy = 0.65
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.adjustment_enabled = true
    env.adjustment_brightness = 0.97
    env.adjustment_contrast = 1.08
    env.adjustment_saturation = 1.08
    env.fog_enabled = true
    env.fog_light_color = Color(0.78, 0.85, 0.94)
    env.fog_density = 0.0008
    city_environment = env
    city_sky_material = sky_material

    var world = WorldEnvironment.new()
    world.environment = env
    add_child(world)

    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_color = Color(1.0, 0.90, 0.76)
    sun.light_energy = 0.90
    sun.shadow_enabled = true
    add_child(sun)
    city_sun = sun

    # Visible sun in the sky.
    var sun_visual := MeshInstance3D.new()
    sun_visual.name = "VisibleSun"
    var sun_mesh := SphereMesh.new()
    sun_mesh.radius = 4.8
    sun_mesh.height = 9.6
    sun_visual.mesh = sun_mesh
    var sun_material := StandardMaterial3D.new()
    sun_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sun_material.emission_enabled = true
    sun_material.albedo_color = Color(1.0, 0.78, 0.40)
    sun_material.emission = Color(1.0, 0.62, 0.24)
    sun_material.emission_energy_multiplier = 2.4
    sun_visual.material_override = sun_material
    add_child(sun_visual)
    city_sun_visual = sun_visual

    # Visible moon for the night sky.
    var moon_visual := MeshInstance3D.new()
    moon_visual.name = "VisibleMoon"
    var moon_mesh := SphereMesh.new()
    moon_mesh.radius = 3.7
    moon_mesh.height = 7.4
    moon_visual.mesh = moon_mesh
    var moon_material := StandardMaterial3D.new()
    moon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    moon_material.emission_enabled = true
    moon_material.albedo_color = Color(0.72, 0.80, 1.0)
    moon_material.emission = Color(0.40, 0.49, 0.72)
    moon_material.emission_energy_multiplier = 0.8
    moon_visual.material_override = moon_material
    moon_visual.visible = false
    add_child(moon_visual)
    city_moon_visual = moon_visual

    # Shared glossy-capable road material. Rain changes its roughness.
    road_surface_material = StandardMaterial3D.new()
    road_surface_material.albedo_color = Color(0.14, 0.16, 0.19)
    road_surface_material.roughness = 0.92
    road_surface_material.metallic = 0.0
    road_surface_material.specular = 0.72

    # Shared warm window materials.
    window_lit_material = StandardMaterial3D.new()
    window_lit_material.albedo_color = Color(1.0, 0.72, 0.34)
    window_lit_material.roughness = 0.62
    window_lit_material.emission_enabled = true
    window_lit_material.emission = Color(1.0, 0.48, 0.12)
    window_lit_material.emission_energy_multiplier = 0.0

    window_dark_material = StandardMaterial3D.new()
    window_dark_material.albedo_color = Color(0.055, 0.10, 0.15)
    window_dark_material.roughness = 0.58

    # Shared amber street-lamp glow.
    lamp_glow_material = StandardMaterial3D.new()
    lamp_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    lamp_glow_material.emission_enabled = true
    lamp_glow_material.albedo_color = Color(1.0, 0.68, 0.30)
    lamp_glow_material.emission = Color(1.0, 0.52, 0.18)
    lamp_glow_material.emission_energy_multiplier = 0.0

    # Lightweight rain effect for mobile devices.
    var rain = CPUParticles3D.new()
    rain.name = "CityRain"
    rain.amount = 300
    rain.lifetime = 1.4
    rain.emitting = false
    rain.position = Vector3(0, 14, 0)
    rain.visibility_aabb = AABB(
        Vector3(-120, -25, -120),
        Vector3(240, 55, 240)
    )

    var rain_process = ParticleProcessMaterial.new()
    rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    rain_process.emission_box_extents = Vector3(105, 8, 105)
    rain_process.direction = Vector3(0, -1, 0)
    rain_process.spread = 5.0
    rain_process.gravity = Vector3(0, -24, 0)
    rain_process.initial_velocity_min = 10.0
    rain_process.initial_velocity_max = 14.0
    rain.process_material = rain_process

    var rain_mesh = QuadMesh.new()
    rain_mesh.size = Vector2(0.035, 0.55)
    var rain_material = StandardMaterial3D.new()
    rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    rain_material.albedo_color = Color(0.62, 0.78, 1.0, 0.48)
    rain_mesh.material = rain_material
    rain.draw_pass_1 = rain_mesh

    add_child(rain)
    city_rain = rain

func _update_dynamic_weather():
    if city_environment == null or city_sun == null:
        return

    # One complete day/night cycle lasts four minutes.
    var daylight = 0.5 + 0.5 * sin(
        city_clock * TAU / 240.0 + PI / 2.0
    )
    daylight = clampf(daylight, 0.0, 1.0)
    daylight = daylight * daylight * (3.0 - 2.0 * daylight)

    city_sun.rotation_degrees = Vector3(
        lerpf(12.0, -48.0, daylight),
        -32.0 + city_clock * 0.08,
        0.0
    )
    city_sun.light_energy = lerpf(0.06, 0.90, daylight)
    city_sun.light_color = Color(0.42, 0.52, 0.78).lerp(
        Color(1.0, 0.90, 0.76), daylight
    )

    # Move the visible sun and moon around the city with the day cycle.
    var orbit_angle = PI / 2.0 - city_clock * TAU / 240.0
    var sun_direction = Vector3(
        cos(orbit_angle), sin(orbit_angle), -0.32
    ).normalized()

    if city_sun_visual != null:
        city_sun_visual.position = sun_direction * 105.0
        city_sun_visual.visible = daylight > 0.10

    if city_moon_visual != null:
        city_moon_visual.position = -sun_direction * 105.0
        city_moon_visual.visible = daylight < 0.58

    # Keep nighttime scenery visible without turning night into daytime.
    city_environment.ambient_light_color = Color(
        0.30, 0.34, 0.48
    ).lerp(Color(0.78, 0.84, 1.0), daylight)
    city_environment.ambient_light_energy = lerpf(
        0.40, 0.65, daylight
    )

    # Smooth activation at sunset and sunrise.
    var night_factor = clampf((0.68 - daylight) / 0.48, 0.0, 1.0)
    night_factor = night_factor * night_factor * (3.0 - 2.0 * night_factor)

    if window_lit_material != null:
        window_lit_material.emission_energy_multiplier = 2.6 * night_factor

    if lamp_glow_material != null:
        lamp_glow_material.emission_energy_multiplier = 2.1 * night_factor

    for lamp_light in street_lamp_lights:
        if is_instance_valid(lamp_light):
            lamp_light.light_energy = 1.65 * night_factor

    city_sky_material.sky_top_color = Color(
        0.012, 0.025, 0.09
    ).lerp(Color(0.08, 0.30, 0.62), daylight)
    city_sky_material.sky_horizon_color = Color(
        0.07, 0.09, 0.18
    ).lerp(Color(0.55, 0.72, 0.88), daylight)

    # More noticeable rain periods, compatible with mobile rendering.
    var rain_phase = fposmod(city_clock, 180.0)
    var raining = rain_phase > 85.0 and rain_phase < 145.0
    if city_rain != null:
        city_rain.emitting = raining

    # Wet asphalt becomes darker and smoother. Street lamps provide
    # direct specular highlights on the wet road surface.
    if road_surface_material != null:
        var wet_factor = 1.0 if raining else 0.0
        road_surface_material.albedo_color = Color(0.14, 0.16, 0.19).lerp(
            Color(0.075, 0.09, 0.12), wet_factor
        )
        road_surface_material.roughness = lerpf(0.92, 0.18, wet_factor)
        road_surface_material.metallic = lerpf(0.0, 0.14, wet_factor)
        road_surface_material.specular = 0.78

    var fog_amount = lerpf(0.0007, 0.0018, 1.0 - daylight)
    if raining:
        fog_amount += 0.0012
    city_environment.fog_density = fog_amount
    city_environment.fog_light_color = Color(
        0.20, 0.25, 0.38
    ).lerp(Color(0.78, 0.85, 0.94), daylight)

    city_environment.adjustment_brightness = lerpf(
        0.92, 0.97, daylight
    )

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, solid := false):
    var mesh_instance = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.94
    material.metallic = 0.0
    material.specular = 0.22
    mesh_instance.material_override = material
    mesh_instance.position = pos
    parent.add_child(mesh_instance)

    if solid:
        var body = StaticBody3D.new()
        body.position = pos
        var shape = CollisionShape3D.new()
        var box = BoxShape3D.new()
        box.size = size
        shape.shape = box
        body.add_child(shape)
        parent.add_child(body)

    return mesh_instance


func _add_native_edge_building(cx: float, cz: float, rng: RandomNumberGenerator, suburban: bool):
    var w = rng.randf_range(8.0, 10.5)
    var d = rng.randf_range(8.0, 10.5)
    var h = rng.randf_range(5.0, 9.0) if suburban else rng.randf_range(8.0, 14.0)

    var palettes = [
        Color(0.72, 0.59, 0.43),
        Color(0.78, 0.68, 0.54),
        Color(0.66, 0.58, 0.48),
        Color(0.82, 0.74, 0.62),
        Color(0.67, 0.68, 0.62),
        Color(0.75, 0.61, 0.49)
    ]
    var wall = palettes[rng.randi_range(0, palettes.size() - 1)]
    var trim = wall.darkened(0.22)
    var roof = wall.darkened(0.34)

    # Main structure and roof edge.
    _box(self, Vector3(w, h, d), Vector3(cx, h * 0.5, cz), wall, true)
    _box(self, Vector3(w + 0.28, 0.28, d + 0.28),
        Vector3(cx, h + 0.12, cz), roof)

    # Native windows and front entrance.
    _add_windows(cx, cz, w, d, h)
    _stage21_building_detail(cx, cz, w, d, h, wall, rng, suburban)

    # Ground-floor shopfronts on selected non-residential buildings.
    if not suburban and rng.randf() < 0.62:
        var shop_color = [Color(0.12, 0.39, 0.48), Color(0.62, 0.25, 0.12),
            Color(0.18, 0.43, 0.27), Color(0.68, 0.47, 0.16)][rng.randi_range(0, 3)]
        var front_z = cz + d * 0.5 + 0.08
        _box(self, Vector3(w * 0.72, 1.35, 0.12),
            Vector3(cx, 1.25, front_z), shop_color)
        _box(self, Vector3(w * 0.84, 0.22, 0.65),
            Vector3(cx, 2.12, front_z + 0.22), trim)
        var shop_label = Label3D.new()
        shop_label.text = ["EPICERIE", "CAFE", "ALIMENTATION", "SERVICES"][rng.randi_range(0, 3)]
        shop_label.font_size = 30
        shop_label.pixel_size = 0.008
        shop_label.position = Vector3(cx, 2.15, front_z + 0.57)
        shop_label.modulate = Color(1.0, 0.91, 0.72)
        add_child(shop_label)

# STAGE21_COMPLETE_GRAPHICS_UPGRADE
func _stage21_building_detail(cx: float, cz: float, w: float,
        d: float, h: float, wall: Color,
        rng: RandomNumberGenerator, suburban: bool = false):
    var trim = wall.darkened(0.20)
    var highlight = wall.lightened(0.13)
    var front_z = cz + d * 0.5

    # Vertical façade corner pilasters.
    for side in [-1.0, 1.0]:
        _box(self, Vector3(0.16, maxf(2.0, h - 0.45), 0.13),
            Vector3(cx + side * (w * 0.46), h * 0.5,
                front_z + 0.075), trim)

    # Fine horizontal floor bands and a stronger roof cornice.
    for floor_y in range(3, int(h), 3):
        _box(self, Vector3(w + 0.10, 0.10, 0.15),
            Vector3(cx, float(floor_y), front_z + 0.07), highlight)

    _box(self, Vector3(w + 0.42, 0.16, 0.22),
        Vector3(cx, h + 0.24, front_z + 0.06), trim)

    # Occasional projecting balconies on residential façades.
    var balcony_chance = 0.30 if not suburban else 0.10
    if h > 6.0 and rng.randf() < balcony_chance:
        var by = rng.randf_range(3.0, maxf(3.2, h - 1.5))
        var bx = cx + rng.randf_range(-w * 0.22, w * 0.22)
        var bz = front_z + 0.48
        var rail = Color(0.24, 0.27, 0.28)

        _box(self, Vector3(2.0, 0.14, 0.85),
            Vector3(bx, by, bz), highlight)
        _box(self, Vector3(2.0, 0.07, 0.07),
            Vector3(bx, by + 0.65, bz + 0.38), rail)

        for rx in [-0.90, -0.45, 0.0, 0.45, 0.90]:
            _box(self, Vector3(0.055, 0.65, 0.055),
                Vector3(bx + rx, by + 0.33, bz + 0.38), rail)

    # A small rooftop water tank on selected buildings.
    if rng.randf() < 0.20:
        var tank = MeshInstance3D.new()
        var tank_mesh = CylinderMesh.new()
        tank_mesh.top_radius = 0.48
        tank_mesh.bottom_radius = 0.52
        tank_mesh.height = 1.05
        tank.mesh = tank_mesh
        tank.position = Vector3(
            cx + rng.randf_range(-w * 0.25, w * 0.25),
            h + 0.78,
            cz + rng.randf_range(-d * 0.25, d * 0.25)
        )
        var tank_material = StandardMaterial3D.new()
        tank_material.albedo_color = Color(0.48, 0.57, 0.62)
        tank_material.roughness = 0.72
        tank.material_override = tank_material
        add_child(tank)

func _create_city():
    _box(self, Vector3(340, 1, 340), Vector3(0, -0.55, 0), Color(0.42, 0.48, 0.31), true)

    var road = Color(0.14, 0.16, 0.19)
    for i in range(-6, 7):
        var p = float(i) * 24.0
        var vertical_road = _box(
            self, Vector3(8, 0.08, 306), Vector3(p, 0.02, 0), road
        )
        vertical_road.material_override = road_surface_material

        var horizontal_road = _box(
            self, Vector3(306, 0.08, 8), Vector3(0, 0.03, p), road
        )
        horizontal_road.material_override = road_surface_material

    # STAGE15_SIDEWALKS_AND_CROSSINGS_FINAL
    var sidewalk_color = Color(0.36, 0.34, 0.30)
    var crossing_color = Color(0.72, 0.70, 0.62)

    for i in range(-6, 7):
        var p = float(i) * 24.0

        for side in [-1.0, 1.0]:
            for block in range(-6, 6):
                var q = float(block) * 24.0 + 12.0

                _box(self, Vector3(1.2, 0.12, 16.0),
                    Vector3(p + side * 4.8, 0.09, q),
                    sidewalk_color)

                _box(self, Vector3(16.0, 0.12, 1.2),
                    Vector3(q, 0.09, p + side * 4.8),
                    sidewalk_color)

    # STAGE21: restrained zebra crossings at alternating intersections.
    # No decorative white lane lines across normal road sections.
    for x in range(-6, 7, 2):
        for z in range(-6, 7, 2):
            var ix = float(x) * 24.0
            var iz = float(z) * 24.0

            for side in [-1.0, 1.0]:
                for stripe in range(4):
                    var offset = (float(stripe) - 1.5) * 0.72

                    _box(self, Vector3(6.0, 0.025, 0.28),
                        Vector3(ix, 0.075, iz + side * 5.65 + offset),
                        crossing_color)

                    _box(self, Vector3(0.28, 0.025, 6.0),
                        Vector3(ix + side * 5.65 + offset, 0.075, iz),
                        crossing_color)

    var rng = RandomNumberGenerator.new()
    rng.seed = 302610
    # Saturated but sun-washed colours: terracotta, mint, lemon, turquoise and cream.
    var palette = [
        Color(0.94, 0.43, 0.28),
        Color(0.98, 0.77, 0.32),
        Color(0.28, 0.72, 0.68),
        Color(0.38, 0.59, 0.88),
        Color(0.96, 0.85, 0.70),
        Color(0.79, 0.62, 0.84),
        Color(0.70, 0.82, 0.47)
    ]

    # Buildings belong in the green plots BETWEEN roads, never on road centres.
    for x in range(-4, 4):
        for z in range(-4, 4):
            # Preserve the central public square and all four landmark plots.
            if (x == 0 and z == 0) or \
                    (x == -2 and z == -2) or \
                    (x == 1 and z == -2) or \
                    (x == -2 and z == 1) or \
                    (x == 1 and z == 1):
                continue
            var cx = x * 24.0 + 12.0 + rng.randf_range(-1.5, 1.5)
            var cz = z * 24.0 + 12.0 + rng.randf_range(-1.5, 1.5)
            var w = rng.randf_range(7.0, 11.0)
            var d = rng.randf_range(7.0, 11.0)
            var h = rng.randf_range(4.0, 13.0)
            var building_color: Color = palette[rng.randi_range(0, palette.size() - 1)]
            _box(self, Vector3(w, h, d), Vector3(cx, h / 2.0, cz), building_color, true)
            # Thin sunlit roof rim gives simple geometry a deliberate toy-like silhouette.
            _box(self, Vector3(w + 0.32, 0.22, d + 0.32),
                Vector3(cx, h + 0.11, cz), building_color.lightened(0.16))
            _add_windows(cx, cz, w, d, h)
            _stage21_building_detail(cx, cz, w, d, h,
                building_color, rng, false)

    # STAGE20_NATIVE_EDGE_BUILDINGS
    # Keep all 80 outer plots, but build them with native Godot geometry.
    for x in range(-6, 6):
        for z in range(-6, 6):
            if x >= -4 and x <= 3 and z >= -4 and z <= 3:
                continue
            var cx = float(x) * 24.0 + 12.0
            var cz = float(z) * 24.0 + 12.0
            var suburban = abs(x) >= 5 or abs(z) >= 5
            _add_native_edge_building(cx, cz, rng, suburban)

    var sign := Label3D.new()
    sign.text = "KASSERINE CITY"
    sign.font_size = 64
    sign.position = Vector3(0, 7, -28)
    sign.modulate = Color(1.0, 0.83, 0.35)
    add_child(sign)


var citizens: Array[Node3D] = []
var citizen_anims: Array = []
var citizen_routes: Array = []
var citizen_route_indices: Array[int] = []
var citizen_speeds: Array[float] = []
var citizen_waits: Array[float] = []
var city_clock := 0.0

var traffic_cars: Array[Node3D] = []
var traffic_paths: Array = []
var traffic_targets: Array[int] = []
var traffic_speeds: Array[float] = []

func _create_people():
    var places = [
        Vector3(3, 0, 7),
        Vector3(-7, 0, 9),
        Vector3(8, 0, -8),
        Vector3(-10, 0, -12),
        Vector3(14, 0, 12),
        Vector3(-15, 0, 15),
        Vector3(20, 0, -13),
        Vector3(-19, 0, -19),
        Vector3(6, 0, -22),
        Vector3(-6, 0, 22)
    ]
    for i in range(places.size()):
        var person = CharacterBody3D.new()
        person.name = "Citizen_%02d" % i
        person.position = places[i]
        person.collision_layer = 2
        person.collision_mask = 1
        person.floor_snap_length = 0.25

        var collider = CollisionShape3D.new()
        var capsule = CapsuleShape3D.new()
        capsule.radius = 0.32
        capsule.height = 1.8
        collider.shape = capsule
        collider.position.y = 0.9
        person.add_child(collider)

        add_child(person)
        citizens.append(person)
        citizen_anims.append(_human(person, i))

        # Keep Amine in place so the introductory mission remains reliable.
        var route: Array[Vector3] = []
        if i > 0:
            var start: Vector3 = places[i]
            var offset := 2.0 + float(i % 3) * 0.45
            route = [
                start,
                start + Vector3(offset, 0, 0),
                start + Vector3(offset, 0, offset),
                start + Vector3(0, 0, offset)
            ]
        citizen_routes.append(route)
        citizen_route_indices.append(1 if i > 0 else 0)
        citizen_speeds.append(0.75 + float(i % 4) * 0.18)
        citizen_waits.append(float(i % 3) * 0.6)

    var guide = Label3D.new()
    guide.text = "AMINE - MISSIONS"
    guide.font_size = 36
    guide.position = Vector3(0, 2.5, 0)
    guide.modulate = Color.YELLOW
    citizens[0].add_child(guide)

    _landmark("MARKET", Vector3(-24, 3, 0))
    _landmark("GARAGE", Vector3(24, 3, 0))

    _create_landmark_building("SCHOOL", Vector3(-36, 0, -36),
        Vector3(10, 5, 9), Color(0.82, 0.69, 0.43))
    _create_landmark_building("POLICE", Vector3(36, 0, -36),
        Vector3(9, 5, 9), Color(0.48, 0.59, 0.72))
    _create_landmark_building("HOSPITAL", Vector3(-36, 0, 36),
        Vector3(11, 5.5, 10), Color(0.82, 0.84, 0.79))
    _create_landmark_building("CAFE", Vector3(36, 0, 36),
        Vector3(8, 3.5, 8), Color(0.73, 0.48, 0.31))

func _human(root: Node3D, index: int) -> AnimationPlayer:
    var model = CharacterModel.build(index)
    if model != null:
        root.add_child(model)
        return CharacterModel.setup_animations(model)

    _human_fallback(root, index)
    return null

func _human_fallback(root: Node3D, index: int):
    var shirt_colors = [
        Color(0.18, 0.45, 0.8),
        Color(0.8, 0.25, 0.2),
        Color(0.15, 0.55, 0.35),
        Color(0.75, 0.65, 0.25)
    ]
    var shirt = shirt_colors[index % shirt_colors.size()]
    var skin = Color(0.68, 0.43, 0.28)
    _box(root, Vector3(0.65, 0.8, 0.34), Vector3(0, 1.25, 0), shirt)
    _box(root, Vector3(0.34, 0.34, 0.34), Vector3(0, 1.87, 0), skin)
    _box(root, Vector3(0.22, 0.65, 0.23), Vector3(-0.48, 1.22, 0), skin)
    _box(root, Vector3(0.22, 0.65, 0.23), Vector3(0.48, 1.22, 0), skin)
    var trousers = Color(0.13, 0.16, 0.23)
    _box(root, Vector3(0.24, 0.75, 0.28), Vector3(-0.19, 0.45, 0), trousers)
    _box(root, Vector3(0.24, 0.75, 0.28), Vector3(0.19, 0.45, 0), trousers)

func _landmark(title: String, pos: Vector3):
    var sign = Label3D.new()
    sign.text = title
    sign.font_size = 48
    sign.position = pos
    sign.modulate = Color(1, 0.85, 0.25)
    add_child(sign)

func interact():
    get_node("Gameplay").interact()


var animal_nodes: Array[Node3D] = []
var animal_origins: Array[Vector3] = []
var animal_clock := 0.0

func _create_nature_and_vehicles():
    var tree_positions = [
        Vector3(-94, 0, -90), Vector3(-72, 0, -94),
        Vector3(-48, 0, -94), Vector3(-20, 0, -94),
        Vector3(20, 0, -94), Vector3(48, 0, -94),
        Vector3(72, 0, -94), Vector3(94, 0, -70),
        Vector3(94, 0, -35), Vector3(94, 0, 10),
        Vector3(94, 0, 48), Vector3(70, 0, 94),
        Vector3(38, 0, 94), Vector3(0, 0, 94),
        Vector3(-38, 0, 94), Vector3(-75, 0, 70),
        Vector3(-94, 0, 35), Vector3(-94, 0, 0)
    ]
    for i in range(tree_positions.size()):
        _create_tree(tree_positions[i], 0.8 + float(i % 4) * 0.12)

    _create_animal(Vector3(-12, 0, 9), Color(0.55, 0.32, 0.16), "DOG")
    _create_animal(Vector3(12, 0, -10), Color(0.72, 0.65, 0.48), "CAT")
    _create_animal(Vector3(42, 0, 15), Color(0.36, 0.30, 0.24), "DOG")
    _create_animal(Vector3(-42, 0, -15), Color(0.75, 0.68, 0.52), "CAT")
    _create_animal(Vector3(68, 0, 68), Color(0.46, 0.28, 0.14), "DOG")

    # STAGE15_PALM_PLACEMENTS
    _create_palm_tree(Vector3(-103, 0, -55), 0.9)
    _create_palm_tree(Vector3(103, 0, -55), 0.9)
    _create_palm_tree(Vector3(-103, 0, 55), 0.9)
    _create_palm_tree(Vector3(103, 0, 55), 0.9)

    _create_bush(Vector3(-101, 0, -40), 0.8)
    _create_bush(Vector3(-101, 0, -70), 0.8)
    _create_bush(Vector3(101, 0, -40), 0.8)
    _create_bush(Vector3(101, 0, -70), 0.8)
    _create_bush(Vector3(-101, 0, 40), 0.8)
    _create_bush(Vector3(-101, 0, 70), 0.8)
    _create_bush(Vector3(101, 0, 40), 0.8)
    _create_bush(Vector3(101, 0, 70), 0.8)

    _create_street_lights()

    # Five AI cars follow connected loops on the actual road grid.
    _create_traffic_car(Vector3(-24, 0, -24), Color(0.72, 0.12, 0.10),
        [Vector3(-24, 0, -24), Vector3(0, 0, -24),
         Vector3(0, 0, 0), Vector3(-24, 0, 0)], 4.2)
    _create_traffic_car(Vector3(0, 0, -24), Color(0.12, 0.32, 0.72),
        [Vector3(0, 0, -24), Vector3(24, 0, -24),
         Vector3(24, 0, 0), Vector3(0, 0, 0)], 4.6)
    _create_traffic_car(Vector3(-24, 0, 0), Color(0.82, 0.78, 0.63),
        [Vector3(-24, 0, 0), Vector3(-24, 0, 24),
         Vector3(0, 0, 24), Vector3(0, 0, 0)], 3.8)
    _create_traffic_car(Vector3(0, 0, 0), Color(0.15, 0.48, 0.28),
        [Vector3(0, 0, 0), Vector3(24, 0, 0),
         Vector3(24, 0, 24), Vector3(0, 0, 24)], 4.4)
    _create_traffic_car(Vector3(24, 0, 0), Color(0.12, 0.12, 0.14),
        [Vector3(24, 0, 0), Vector3(48, 0, 0),
         Vector3(48, 0, 24), Vector3(24, 0, 24)], 4.0)

func _create_tree(pos: Vector3, scale_factor: float):
    var tree = Node3D.new()
    tree.name = "Tree"
    tree.position = pos
    tree.scale = Vector3.ONE * scale_factor
    add_child(tree)

    _box(tree, Vector3(0.45, 2.4, 0.45), Vector3(0, 1.2, 0),
        Color(0.30, 0.19, 0.10))

    # STAGE21: visible low-poly branches under the canopy.
    for side in [-1.0, 1.0]:
        var branch = MeshInstance3D.new()
        var branch_mesh = CylinderMesh.new()
        branch_mesh.top_radius = 0.075
        branch_mesh.bottom_radius = 0.13
        branch_mesh.height = 1.35
        branch.mesh = branch_mesh
        branch.position = Vector3(side * 0.48, 2.15, 0)
        branch.rotation_degrees.z = side * 38.0
        var branch_material = StandardMaterial3D.new()
        branch_material.albedo_color = Color(0.30, 0.19, 0.10)
        branch_material.roughness = 1.0
        branch.material_override = branch_material
        tree.add_child(branch)

    var crown = MeshInstance3D.new()
    var crown_mesh = SphereMesh.new()
    crown_mesh.radius = 1.35
    crown_mesh.height = 2.7
    crown.mesh = crown_mesh
    crown.position.y = 3.0
    var foliage = StandardMaterial3D.new()
    foliage.albedo_color = Color(0.12, 0.43, 0.19)
    foliage.roughness = 1.0
    crown.material_override = foliage
    tree.add_child(crown)

    # Three overlapping crowns make a fuller, playful low-poly canopy.
    for offset in [Vector3(-0.72, 2.72, 0.12), Vector3(0.68, 2.82, 0.08),
            Vector3(0.0, 3.55, -0.08)]:
        var leaf = MeshInstance3D.new()
        var leaf_mesh = SphereMesh.new()
        leaf_mesh.radius = 0.82
        leaf_mesh.height = 1.55
        leaf.mesh = leaf_mesh
        leaf.position = offset
        leaf.material_override = foliage
        tree.add_child(leaf)

func _create_palm_tree(pos: Vector3, scale_factor: float = 1.0):
    var palm = Node3D.new()
    palm.name = "PalmTree"
    palm.position = pos
    palm.scale = Vector3.ONE * scale_factor
    add_child(palm)

    var trunk_material = StandardMaterial3D.new()
    trunk_material.albedo_color = Color(0.43, 0.27, 0.14)
    trunk_material.roughness = 1.0

    var trunk = MeshInstance3D.new()
    var trunk_mesh = CylinderMesh.new()
    trunk_mesh.top_radius = 0.16
    trunk_mesh.bottom_radius = 0.29
    trunk_mesh.height = 5.2
    trunk.mesh = trunk_mesh
    trunk.position.y = 2.6
    trunk.material_override = trunk_material
    palm.add_child(trunk)

    var leaf_material = StandardMaterial3D.new()
    leaf_material.albedo_color = Color(0.12, 0.43, 0.19)
    leaf_material.roughness = 1.0

    for i in range(7):
        var angle = TAU * float(i) / 7.0
        var direction = Vector3(cos(angle), 0.0, sin(angle))

        var leaf = MeshInstance3D.new()
        var leaf_mesh = BoxMesh.new()
        leaf_mesh.size = Vector3(0.24, 0.09, 2.5)
        leaf.mesh = leaf_mesh
        leaf.position = Vector3(0, 5.05, 0) + direction * 1.15
        leaf.rotation.y = -angle
        leaf.rotation.z = -0.38
        leaf.material_override = leaf_material
        palm.add_child(leaf)


func _create_bush(pos: Vector3, size: float = 1.0):
    var bush = Node3D.new()
    bush.name = "Bush"
    bush.position = pos
    add_child(bush)

    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.19, 0.43, 0.20)
    material.roughness = 1.0

    for i in range(3):
        var leaves = MeshInstance3D.new()
        var mesh = SphereMesh.new()
        mesh.radius = 0.48 * size
        mesh.height = 0.72 * size
        leaves.mesh = mesh
        leaves.position = Vector3((i - 1) * 0.38 * size, 0.42 * size, 0)
        leaves.material_override = material
        bush.add_child(leaves)


func _add_windows(cx: float, cz: float, w: float, d: float, h: float):
    var rows = int(max(1.0, floor((h - 2.0) / 2.4)))

    for row in range(rows):
        var wy = 1.5 + float(row) * 2.2

        for side in [-1.0, 1.0]:
            for col in range(2):
                # Stable mixed pattern: roughly three in five windows glow.
                var pattern_seed = int(abs(cx * 7.0 + cz * 11.0)) + row * 3 + col * 5
                var glass_material = window_lit_material if pattern_seed % 5 < 3 else window_dark_material

                var wx = cx + (float(col) - 0.5) * w * 0.48
                var front_window = _box(self, Vector3(0.85, 0.9, 0.08),
                    Vector3(wx, wy, cz + side * (d / 2.0 + 0.045)), Color.WHITE)
                front_window.material_override = glass_material

                var wz = cz + (float(col) - 0.5) * d * 0.48
                var side_window = _box(self, Vector3(0.08, 0.9, 0.85),
                    Vector3(cx + side * (w / 2.0 + 0.045), wy, wz), Color.WHITE)
                side_window.material_override = glass_material

    # Every generated building and landmark receives a visible entrance.
    _add_building_door(cx, cz, d)

func _add_building_door(cx: float, cz: float, depth: float):
    var front_z = cz + depth / 2.0

    # Dark inset and contrasting frame.
    _box(self, Vector3(1.55, 2.42, 0.07),
        Vector3(cx, 1.21, front_z + 0.045), Color(0.10, 0.075, 0.06))

    var frame_color = Color(0.88, 0.76, 0.55)
    _box(self, Vector3(0.13, 2.42, 0.12),
        Vector3(cx - 0.73, 1.21, front_z + 0.12), frame_color)
    _box(self, Vector3(0.13, 2.42, 0.12),
        Vector3(cx + 0.73, 1.21, front_z + 0.12), frame_color)
    _box(self, Vector3(1.59, 0.14, 0.12),
        Vector3(cx, 2.42, front_z + 0.12), frame_color)

    # Wooden door leaf and two inset panels.
    var door_color = Color(0.34, 0.17, 0.09)
    _box(self, Vector3(1.27, 2.18, 0.09),
        Vector3(cx, 1.13, front_z + 0.17), door_color)
    _box(self, Vector3(0.88, 0.66, 0.035),
        Vector3(cx, 1.62, front_z + 0.225), Color(0.47, 0.25, 0.13))
    _box(self, Vector3(0.88, 0.48, 0.035),
        Vector3(cx, 0.72, front_z + 0.225), Color(0.47, 0.25, 0.13))

    # Small metallic handle.
    _box(self, Vector3(0.07, 0.13, 0.055),
        Vector3(cx + 0.43, 1.08, front_z + 0.25), Color(0.92, 0.72, 0.28))

func _create_animal(pos: Vector3, coat: Color, kind: String):
    var animal = Node3D.new()
    animal.name = kind
    animal.position = pos
    add_child(animal)
    animal_nodes.append(animal)
    animal_origins.append(pos)

    var body = MeshInstance3D.new()
    var body_mesh = SphereMesh.new()
    body_mesh.radius = 0.48 if kind == "DOG" else 0.36
    body_mesh.height = 0.75 if kind == "DOG" else 0.58
    body.mesh = body_mesh
    body.position = Vector3(0, 0.58, 0)
    var material = StandardMaterial3D.new()
    material.albedo_color = coat
    body.material_override = material
    animal.add_child(body)

    var head = MeshInstance3D.new()
    var head_mesh = SphereMesh.new()
    head_mesh.radius = 0.25
    head_mesh.height = 0.42
    head.mesh = head_mesh
    head.position = Vector3(0, 0.78, -0.42)
    head.material_override = material
    animal.add_child(head)

    for side in [-1.0, 1.0]:
        for front in [-1.0, 1.0]:
            _box(animal, Vector3(0.13, 0.42, 0.13),
                Vector3(side * 0.24, 0.22, front * 0.25), coat)

    var label = Label3D.new()
    label.text = kind
    label.font_size = 24
    label.position.y = 1.3
    label.modulate = Color(1, 1, 1, 0.85)
    animal.add_child(label)

func _create_car(pos: Vector3, paint: Color, angle: float) -> Node3D:
    var car = Node3D.new()
    car.name = "ParkedCar"
    car.position = pos
    car.rotation.y = angle
    add_child(car)

    _box(car, Vector3(1.8, 0.62, 3.2), Vector3(0, 0.65, 0), paint)
    _box(car, Vector3(1.38, 0.62, 1.55), Vector3(0, 1.15, -0.12),
        Color(0.18, 0.25, 0.29))
    _box(car, Vector3(1.92, 0.16, 0.22), Vector3(0, 0.48, -1.58),
        Color(0.10, 0.11, 0.14))
    _box(car, Vector3(1.92, 0.16, 0.22), Vector3(0, 0.48, 1.58),
        Color(0.10, 0.11, 0.14))
    for side in [-1.0, 1.0]:
        _box(car, Vector3(0.34, 0.20, 0.08),
            Vector3(side * 0.58, 0.78, -1.63), Color(1.0, 0.91, 0.58))
        _box(car, Vector3(0.30, 0.16, 0.08),
            Vector3(side * 0.62, 0.70, 1.63), Color(0.95, 0.16, 0.10))

    for side in [-1.0, 1.0]:
        for end in [-1.0, 1.0]:
            var wheel = MeshInstance3D.new()
            var wheel_mesh = CylinderMesh.new()
            wheel_mesh.top_radius = 0.32
            wheel_mesh.bottom_radius = 0.32
            wheel_mesh.height = 0.18
            wheel.mesh = wheel_mesh
            wheel.rotation_degrees.z = 90
            wheel.position = Vector3(side * 0.91, 0.34, end * 1.0)
            var rubber = StandardMaterial3D.new()
            rubber.albedo_color = Color(0.06, 0.06, 0.07)
            wheel.material_override = rubber
            car.add_child(wheel)

    # STAGE21: side windows and visible vehicle trim.
    var glass = Color(0.12, 0.23, 0.29)
    for side in [-1.0, 1.0]:
        _box(car, Vector3(0.055, 0.31, 0.62),
            Vector3(side * 0.704, 1.18, -0.48), glass)
        _box(car, Vector3(0.055, 0.31, 0.62),
            Vector3(side * 0.704, 1.18, 0.35), glass)

        # Side mirrors.
        _box(car, Vector3(0.22, 0.12, 0.16),
            Vector3(side * 0.98, 1.02, -0.72),
            Color(0.12, 0.14, 0.16))

        # Door handles.
        _box(car, Vector3(0.045, 0.055, 0.20),
            Vector3(side * 0.91, 0.79, 0.10),
            Color(0.72, 0.73, 0.70))

    # Front grille and registration plate.
    _box(car, Vector3(0.72, 0.19, 0.055),
        Vector3(0, 0.57, -1.64), Color(0.09, 0.11, 0.12))
    _box(car, Vector3(0.48, 0.12, 0.045),
        Vector3(0, 0.43, -1.70), Color(0.86, 0.85, 0.76))

    # Rear registration plate.
    _box(car, Vector3(0.48, 0.12, 0.045),
        Vector3(0, 0.43, 1.70), Color(0.86, 0.85, 0.76))

    # Metallic wheel centres.
    for side in [-1.0, 1.0]:
        for end in [-1.0, 1.0]:
            hub = MeshInstance3D.new()
            var hub_mesh = CylinderMesh.new()
            hub_mesh.top_radius = 0.145
            hub_mesh.bottom_radius = 0.145
            hub_mesh.height = 0.19
            hub.mesh = hub_mesh
            hub.rotation_degrees.z = 90
            hub.position = Vector3(side * 1.015, 0.34, end * 1.0)
            var hub_material = StandardMaterial3D.new()
            hub_material.albedo_color = Color(0.56, 0.59, 0.62)
            hub_material.metallic = 0.65
            hub_material.roughness = 0.38
            hub.material_override = hub_material
            car.add_child(hub)

    return car

func _create_traffic_car(start: Vector3, paint: Color,
        route: Array, speed: float):
    var car := _create_car(start, paint, 0.0)
    traffic_cars.append(car)
    traffic_paths.append(route)
    traffic_targets.append(1)
    traffic_speeds.append(speed)

func _update_traffic(delta: float):
    for i in range(traffic_cars.size()):
        var car: Node3D = traffic_cars[i]
        var route: Array = traffic_paths[i]
        if route.size() < 2:
            continue

        var target: Vector3 = route[traffic_targets[i]]
        var difference := target - car.position
        difference.y = 0.0
        var distance := difference.length()

        if distance < 0.65:
            traffic_targets[i] = (traffic_targets[i] + 1) % route.size()
            continue

        var direction := difference.normalized()
        car.position += direction * minf(traffic_speeds[i] * delta, distance)
        car.rotation.y = atan2(-direction.x, -direction.z)

func _create_landmark_building(title: String, pos: Vector3,
        size: Vector3, color: Color):
    _box(self, size, pos + Vector3(0, size.y * 0.5, 0), color, true)
    _box(self, Vector3(size.x + 0.35, 0.24, size.z + 0.35),
        pos + Vector3(0, size.y + 0.12, 0), color.lightened(0.18))
    _add_windows(pos.x, pos.z, size.x, size.z, size.y)

    var landmark_rng = RandomNumberGenerator.new()
    landmark_rng.seed = int(abs(pos.x * 17.0 + pos.z * 31.0)) + 2026
    _stage21_building_detail(pos.x, pos.z, size.x, size.z,
        size.y, color, landmark_rng, false)

    var sign := Label3D.new()
    sign.text = title
    sign.font_size = 32
    sign.position = pos + Vector3(0, size.y + 1.0, 0)
    sign.modulate = Color(1.0, 0.91, 0.62)
    add_child(sign)

func _create_street_lamp(pos: Vector3, add_light: bool = false):
    var lamp := Node3D.new()
    lamp.name = "StreetLamp"
    lamp.position = pos
    add_child(lamp)

    _box(lamp, Vector3(0.18, 3.6, 0.18),
        Vector3(0, 1.8, 0), Color(0.16, 0.17, 0.19))
    _box(lamp, Vector3(0.9, 0.14, 0.18),
        Vector3(0.35, 3.5, 0), Color(0.16, 0.17, 0.19))

    var bulb = _box(lamp, Vector3(0.45, 0.2, 0.36),
        Vector3(0.72, 3.42, 0), Color(1.0, 0.88, 0.55))
    bulb.material_override = lamp_glow_material

    # Only selected lamps get real lights to protect mobile performance.
    if add_light:
        var light := OmniLight3D.new()
        light.light_color = Color(1.0, 0.72, 0.42)
        light.light_energy = 0.0
        light.omni_range = 10.0
        light.shadow_enabled = false
        light.position = Vector3(0.72, 3.25, 0)
        lamp.add_child(light)
        street_lamp_lights.append(light)

func _create_street_lights():
    # Lamps stand just outside the 8 m roads, clear of the lane centers.
    for road_index in range(-3, 4):
        var p := float(road_index) * 24.0

        for side in [-1.0, 1.0]:
            for along in range(-3, 4):
                var q := float(along) * 24.0
                var add_light = road_index % 2 == 0 and along % 2 == 0
                _create_street_lamp(
                    Vector3(p + side * 5.2, 0, q + 5.2), add_light
                )

func _physics_process(delta: float):
    for i in range(citizens.size()):
        var person := citizens[i] as CharacterBody3D
        if person == null:
            continue

        if not person.is_on_floor():
            person.velocity.y -= 18.0 * delta
        else:
            person.velocity.y = 0.0

        var direction := Vector3.ZERO
        var route: Array = citizen_routes[i]

        if route.size() >= 2:
            if citizen_waits[i] > 0.0:
                citizen_waits[i] = maxf(0.0, citizen_waits[i] - delta)
            else:
                var target: Vector3 = route[citizen_route_indices[i]]
                var difference := target - person.global_position
                difference.y = 0.0

                if difference.length() < 0.25:
                    citizen_route_indices[i] = (
                        citizen_route_indices[i] + 1
                    ) % route.size()
                    citizen_waits[i] = 0.3 + float(i % 4) * 0.35
                else:
                    direction = difference.normalized()

        person.velocity.x = direction.x * citizen_speeds[i]
        person.velocity.z = direction.z * citizen_speeds[i]

        if direction.length() > 0.01:
            person.rotation.y = atan2(-direction.x, -direction.z)

        person.move_and_slide()

        var anim = citizen_anims[i] as AnimationPlayer
        if is_instance_valid(anim) and person.is_on_floor():
            var wanted := "run" if direction.length() > 0.01 else "idle"
            if anim.has_animation(wanted):
                if anim.current_animation != wanted:
                    anim.play(wanted, 0.12)
                anim.speed_scale = 0.65



func _process(delta):
    city_clock += delta
    _update_dynamic_weather()
    _update_traffic(delta)

    animal_clock += delta
    for i in range(animal_nodes.size()):
        var angle = animal_clock * 0.32 + float(i) * 1.7
        animal_nodes[i].position = animal_origins[i] + Vector3(
            sin(angle) * 1.2, 0, cos(angle) * 0.9
        )
        animal_nodes[i].rotation.y = angle
