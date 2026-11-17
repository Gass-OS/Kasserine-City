extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const CharacterModel = preload("res://scripts/character_model.gd")

func _ready():
    _create_environment()
    _create_city()
    _tn_extras()
    _create_nature_and_vehicles()
    _create_props()
    _create_park()
    _create_hospital_details()
    _create_street_signs()
    _create_weather()
    var player = CharacterBody3D.new()
    player.set_script(PlayerScript)
    player.name = "Player"
    add_child(player)
    player.position = Vector3(0, 1, 12)
    _create_people()
    var gameplay = Node.new()
    gameplay.name = "Gameplay"
    gameplay.set_script(preload("res://scripts/gameplay.gd"))
    add_child(gameplay)
    # v0.4 (B): opening cinematic on first launch (plays once per
    # install — Settings.intro_seen). Skippable with the SKIP button.
    if not Settings.intro_seen:
        var film := Node.new()
        film.set_script(preload("res://scripts/intro_film.gd"))
        add_child(film)

func _create_environment():
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.48, 0.70, 0.88)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.78, 0.82, 0.9)
    env.ambient_light_energy = 0.8

    var world = WorldEnvironment.new()
    world.environment = env
    add_child(world)

    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 1.2
    sun.shadow_enabled = true
    # Large flat boxes (walls, roads, sand) showed a speckled "shadow acne"
    # pattern with the default bias. A slightly larger bias + normal bias
    # keeps the shadows clean without detaching them.
    # v0.3.1: the whole 220 m sand slab showed a strong wavy concentric
    # moire ripple — acne across the full shadow frustum. Three changes:
    # the frustum is tightened to 80 m (smaller shadow texels), the bias
    # is raised again, and the ground slab itself no longer receives
    # shadows (see _create_city). Shadow map size is raised to 4096 on
    # mobile in project.godot for the same reason.
    sun.shadow_bias = 0.08
    sun.shadow_normal_bias = 0.5
    sun.directional_shadow_max_distance = 80.0
    add_child(sun)

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, solid := false, visual_lift := 0.0, no_shadow_recv := false):
    var mesh_instance = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    if no_shadow_recv:
        # Big flat surfaces (the 220 m ground slab) are the canvas where
        # directional-shadow acne shows up as a wavy moire ripple, so they
        # opt out of receiving shadows entirely.
        material.disable_receive_shadows = true
    mesh_instance.material_override = material
    # visual_lift moves ONLY the visible mesh. The collision shape stays at
    # pos: a CharacterBody3D capsule stalls on a 2-4 cm vertical step
    # (measured headless: it climbed a 0.04 m step but stopped moving
    # forward at the edge), while the flat ground slab underneath already
    # carries the player at y = 0. The raised road tops read as curbs.
    mesh_instance.position = pos + Vector3(0, visual_lift, 0)
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

func _create_city():
    # Ground slab top is exactly y = 0, flush with the road collision
    # tops below, so the player's feet rest on the visible surface
    # everywhere. (It used to sit at -0.05 while the roads sat at +0.06
    # with no collision, so the player fell through the road visuals and
    # the legs sank 11 cm.) The slab does not receive shadows: on a flat
    # 220 m surface the directional light's shadow map shows up as a wavy
    # moire ripple, and no bias fully removes it.
    _box(self, Vector3(220, 1, 220), Vector3(0, -0.5, 0), Color(0.66, 0.58, 0.4), true, 0.0, true)

    var road = Color(0.16, 0.17, 0.18)
    var line = Color(0.92, 0.83, 0.55)

    # Road tops used to sit at exactly y = 0.0, coplanar with the ground
    # slab top, so the roads flickered and disappeared at grazing angles
    # (classic z-fighting). The visible road surface is now lifted above
    # the ground — N-S 0.02, E-W 0.04, so the two directions no longer
    # fight each other at intersections either — while the collision
    # stays flat at y = 0 (see _box: visual_lift). Lane lines sit 1 cm
    # above their road's visible top.
    for i in range(-4, 5):
        var p = float(i) * 24.0
        _box(self, Vector3(8, 0.08, 210), Vector3(p, -0.04, 0), road, true, 0.02)
        _box(self, Vector3(210, 0.08, 8), Vector3(0, -0.04, p), road, true, 0.04)
        for j in range(-9, 10):
            _box(self, Vector3(0.16, 0.02, 2.5), Vector3(p, 0.04, j * 11.0), line)
            _box(self, Vector3(2.5, 0.02, 0.16), Vector3(j * 11.0, 0.06, p), line)

    var rng = RandomNumberGenerator.new()
    rng.seed = 302610
    var palette = [
        Color(0.79, 0.70, 0.55),
        Color(0.86, 0.79, 0.65),
        Color(0.72, 0.68, 0.57),
        Color(0.83, 0.82, 0.74),
        Color(0.68, 0.59, 0.46)
    ]

    for x in range(-4, 4):
        for z in range(-4, 4):
            if x >= -2 and x <= 1 and z >= -2 and z <= 1:
                continue
            if x == -3 and z == 2:
                continue  # Park block (v0.3) — built by _create_park().
            var cx = x * 24.0 + 12.0 + rng.randf_range(-1.5, 1.5)
            var cz = z * 24.0 + 12.0 + rng.randf_range(-1.5, 1.5)
            var w = rng.randf_range(6.5, 9.5)
            var d = rng.randf_range(6.5, 9.5)
            var h = rng.randf_range(5.0, 13.0)
            var k = fmod(absf(sin(float(x) * 12.9898 + float(z) * 78.233)) * 43758.5453, 1.0)
            if maxf(absf(x), absf(z)) >= 2 and k > 0.4:
                h += (k - 0.4) * 14.0
            _tn_building(cx, cz, w, d, h, rng.randi_range(0, palette.size() - 1))

    var sign = Label3D.new()
    sign.text = "KASSERINE CITY"
    sign.font_size = 64
    sign.position = Vector3(0, 7, -28)
    sign.modulate = Color(1.0, 0.83, 0.35)
    add_child(sign)


var citizens: Array[Node3D] = []
var citizen_routes: Array = []
var citizen_route_indices: Array[int] = []
var citizen_speeds: Array[float] = []
var citizen_waits: Array[float] = []
# v0.4: intro film flag — true while the opening cinematic plays, so
# the story cards and other popups wait their turn.
var intro_playing := false
# v0.4 (G): weather — 0 clear, 1 cloudy, 2 rain. Changes on a timer.
var weather := 0
var weather_timer := 90.0
# v0.4.4: manual weather override (diagnostic). While set, the auto
# timer is parked at 600 s so it cannot override the choice right
# away; the storm flag means frequent lightning (Orage).
var weather_manual := false
var weather_storm := false
var weather_dark := 0.0
var lightning_flash := 0.0
var lightning_timer := 12.0
var rain_particles: GPUParticles3D
var city_clock := 0.0
# v0.4.3: heartbeat + long-frame watch for the daytime-freeze hunt.
# The freeze (08:24, clear day) never reproduced headless — 300 s,
# max frame 46 ms, zero errors — so if it freezes again on the phone
# the logcat trail is the evidence: a heartbeat every 5 s pins the
# exact game time of the freeze, and a long-frame line catches hitches
# that recover (a permanent hang prints nothing after the last HB).
var _hb_acc := 0.0

# ===== v0.3: night criminals, prayer, most wanted =====
var criminal_indices: Array[int] = [16, 19, 22]
var criminal_caught: Array[bool] = [false, false, false]
var criminal_markers: Array[Label3D] = []
var criminal_active := false
var criminal_saved_speeds: Array[float] = []
# v0.4.2: night-transition stagger queue (see _update_night_criminals).
# The on-device freeze hangs the app with no GDScript error, and no
# `while` loop exists in any per-frame path (audited all scripts), so
# the prime suspect is a native/rendering hang from several light /
# material / particle state changes landing in one frame at the
# transition. The marker flips are staggered one per frame and every
# step is printed, so a logcat after a freeze shows how far it got.
var night_transition_queue: Array[int] = []
var night_transition_target := false
var wanted_index := 21
var wanted_spots: Array[Vector3] = [Vector3(-24, 0, 6), Vector3(24, 0, -6), Vector3(-60, 0, 54)]
var wanted_spot := Vector3.ZERO
var wanted_active := false
var wanted_arrested := false
var prayer_times: Array[float] = [5.0 / 24.0, 12.5 / 24.0, 16.0 / 24.0, 18.5 / 24.0, 20.0 / 24.0]
var prayer_active := false
var prayer_timer := 0.0
var prayer_last_index := -1
var prayer_saved_routes: Array = []
var prayer_saved_waits: Array[float] = []
var prayer_group: Array[int] = [2, 3, 4, 5, 6, 7]
var prayer_prev_t := 0.0
var prayer_queued := -1
var mosque_pos := Vector3(12, 0, -36)

var traffic_cars: Array[Node3D] = []
var traffic_paths: Array = []
var traffic_targets: Array[int] = []
var traffic_speeds: Array[float] = []
# v0.4 (F): per-frame actual speed (follow logic slows a car below its
# base speed; the car behind it must slow to the ACTUAL speed).
var traffic_current_speeds: Array[float] = []

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
        Vector3(-6, 0, 22),
        Vector3(-3, 0, -7),
        Vector3(10, 0, 14),
        Vector3(-14, 0, -6),
        Vector3(16, 0, 6),
        Vector3(-8, 0, 18),
        Vector3(20, 0, -20),
        Vector3(30, 0, 30),
        Vector3(-30, 0, 30),
        Vector3(30, 0, -30),
        Vector3(-30, 0, -30),
        Vector3(42, 0, 42),
        Vector3(-42, 0, 42),
        Vector3(42, 0, -42),
        Vector3(-42, 0, -42)
    ]
    for i in range(places.size()):
        var person = Node3D.new()
        person.name = "Citizen_%02d" % i
        person.position = places[i]
        add_child(person)
        citizens.append(person)
        _human(person, i)

        # Night criminals (v0.3): a red "!" appears over them after dark.
        var ck := criminal_indices.find(i)
        if ck >= 0:
            var mark := Label3D.new()
            mark.text = "!"
            mark.font_size = 72
            mark.position = Vector3(0, 3.0, 0)
            mark.modulate = Color(1.0, 0.2, 0.15)
            mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            mark.visible = false
            person.add_child(mark)
            criminal_markers.append(mark)

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
    guide.billboard = BaseMaterial3D.BILLBOARD_ENABLED
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

func _human(root: Node3D, index: int):
    var model = CharacterModel.build(index)
    if model != null:
        root.add_child(model)
        return
    _human_fallback(root, index)


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
    _create_animal(Vector3(-54, 0, 54), Color(0.30, 0.22, 0.15), "DOG")
    _create_animal(Vector3(54, 0, -54), Color(0.80, 0.70, 0.50), "CAT")

    _create_street_lights()

    # Five AI cars follow connected loops on the actual road grid.
    # v0.4.2: sportier mix — sedan-sports / taxi / race /
    # hatchback-sports / police / suv-luxury.
    _create_traffic_car(Vector3(-24, 0, -24), Color(0.72, 0.12, 0.10),
        [Vector3(-24, 0, -24), Vector3(0, 0, -24),
         Vector3(0, 0, 0), Vector3(-24, 0, 0)], 4.2, 0)
    _create_traffic_car(Vector3(0, 0, -24), Color(0.12, 0.32, 0.72),
        [Vector3(0, 0, -24), Vector3(24, 0, -24),
         Vector3(24, 0, 0), Vector3(0, 0, 0)], 4.6, 1)
    _create_traffic_car(Vector3(-24, 0, 0), Color(0.82, 0.78, 0.63),
        [Vector3(-24, 0, 0), Vector3(-24, 0, 24),
         Vector3(0, 0, 24), Vector3(0, 0, 0)], 3.8, 4)
    _create_traffic_car(Vector3(0, 0, 0), Color(0.15, 0.48, 0.28),
        [Vector3(0, 0, 0), Vector3(24, 0, 0),
         Vector3(24, 0, 24), Vector3(0, 0, 24)], 4.4, 5)
    _create_traffic_car(Vector3(24, 0, 0), Color(0.12, 0.12, 0.14),
        [Vector3(24, 0, 0), Vector3(48, 0, 0),
         Vector3(48, 0, 24), Vector3(24, 0, 24)], 4.0, 2)

    # Three more cars (v0.3): 5 -> 8, all on the road grid.
    _create_traffic_car(Vector3(48, 0, -24), Color(0.90, 0.75, 0.15),
        [Vector3(48, 0, -24), Vector3(48, 0, 0),
         Vector3(72, 0, 0), Vector3(72, 0, -24)], 4.1, 3)
    _create_traffic_car(Vector3(-48, 0, 24), Color(0.50, 0.25, 0.60),
        [Vector3(-48, 0, 24), Vector3(-24, 0, 24),
         Vector3(-24, 0, 48), Vector3(-48, 0, 48)], 4.3, 0)
    _create_traffic_car(Vector3(0, 0, 48), Color(0.90, 0.90, 0.88),
        [Vector3(0, 0, 48), Vector3(0, 0, 72),
         Vector3(24, 0, 72), Vector3(24, 0, 48)], 3.9, 1)

    # Parked cars parallel-parked ON the road edges (v0.4.2): 3.9 m from
    # the road centre line, aligned with the road. The old spots were
    # 2 m off the road edge on the sand (the green SUV at (-5.4, 18)
    # sat on a plaza corner overlapping a bin). 3.9 m clears the
    # traffic lane boxes (lane at 1.5 m + 1.0 m half-box = 2.5 m edge;
    # car half-width 1.09 m -> inner edge at 2.81 m) with ~0.3 m to
    # spare, and keeps the car visibly parked at the curb.
    # The police car by the POLICE station (36, -36) is the DRIVABLE
    # one — walk up to it and press USE.
    police_car = _create_car(Vector3(20.1, 0, -36), Color(0.92, 0.92, 0.9), 0.0, 2, "PoliceCar")
    _create_car(Vector3(-6, 0, 20.1), Color(0.95, 0.8, 0.15), -PI * 0.5, 3, "ParkedCar0")
    _create_car(Vector3(20.1, 0, -6), Color(0.2, 0.5, 0.75), 0.0, 0, "ParkedCar1")
    _create_car(Vector3(-20.1, 0, -14), Color(0.55, 0.15, 0.2), PI, 1, "ParkedCar2")

func _create_tree(pos: Vector3, scale_factor: float):
    var tree = Node3D.new()
    tree.name = "Tree"
    tree.position = pos
    tree.scale = Vector3.ONE * scale_factor
    add_child(tree)

    _box(tree, Vector3(0.45, 2.4, 0.45), Vector3(0, 1.2, 0),
        Color(0.30, 0.19, 0.10))

    var crown = MeshInstance3D.new()
    var crown_mesh = SphereMesh.new()
    crown_mesh.radius = 1.35
    crown_mesh.height = 2.7
    crown.mesh = crown_mesh
    crown.position.y = 3.0
    var foliage = StandardMaterial3D.new()
    foliage.albedo_color = Color(0.12, 0.35, 0.16)
    foliage.roughness = 1.0
    crown.material_override = foliage
    tree.add_child(crown)

func _add_windows_old(cx: float, cz: float, w: float, d: float, h: float):
    var glass = Color(0.18, 0.34, 0.42)
    var rows = int(max(1.0, floor((h - 2.0) / 2.4)))
    for row in range(rows):
        var wy = 1.5 + float(row) * 2.2
        for side in [-1.0, 1.0]:
            for col in range(2):
                var wx = cx + (float(col) - 0.5) * w * 0.48
                _box(self, Vector3(0.85, 0.9, 0.08),
                    Vector3(wx, wy, cz + side * (d / 2.0 + 0.045)), glass)
                var wz = cz + (float(col) - 0.5) * d * 0.48
                _box(self, Vector3(0.08, 0.9, 0.85),
                    Vector3(cx + side * (w / 2.0 + 0.045), wy, wz), glass)

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

func _create_car_old(pos: Vector3, paint: Color, angle: float) -> Node3D:
    var car = Node3D.new()
    car.name = "ParkedCar"
    car.position = pos
    car.rotation.y = angle
    add_child(car)

    _box(car, Vector3(1.8, 0.62, 3.2), Vector3(0, 0.65, 0), paint)
    _box(car, Vector3(1.38, 0.62, 1.55), Vector3(0, 1.15, -0.12),
        Color(0.18, 0.25, 0.29))

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

    return car

func _create_traffic_car(start: Vector3, paint: Color,
        route: Array, speed: float, model_idx: int = -1):
    var car := _create_car(start, paint, 0.0, model_idx, "TrafficCar")
    traffic_cars.append(car)
    traffic_paths.append(route)
    traffic_targets.append(1)
    traffic_speeds.append(speed)
    traffic_current_speeds.append(speed)

func _car_heading(j: int) -> Vector3:
    # Current movement direction of traffic car j (toward its target),
    # used by the follow logic. Returns ZERO if it cannot be computed.
    if j >= traffic_paths.size() or j >= traffic_targets.size():
        return Vector3.ZERO
    var route: Array = traffic_paths[j]
    if route.size() < 2 or j >= traffic_cars.size():
        return Vector3.ZERO
    var diff: Vector3 = (route[traffic_targets[j]] as Vector3) - traffic_cars[j].position
    diff.y = 0.0
    if diff.length() < 0.01:
        return Vector3.ZERO
    return diff.normalized()

func _update_traffic(delta: float):
    for i in range(traffic_cars.size()):
        # v0.4 (G): harden — path/target/speed must exist for this car.
        if i >= traffic_paths.size() or i >= traffic_targets.size() or i >= traffic_speeds.size():
            continue
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
        # v0.4 (F): right-hand traffic — drive 1.5 m to the right of the
        # road centre line, so a car coming the other way passes with
        # ~3 m clearance instead of driving through it head-on. The
        # offset is recomputed from the current direction, so the car
        # follows an inset rectangle and rounds the corners by 1.5 m.
        var side := direction.cross(Vector3.UP)
        var lane_target: Vector3 = target + side * 1.5
        var lane_diff := lane_target - car.position
        lane_diff.y = 0.0
        var lane_dist := lane_diff.length()
        if lane_dist < 0.65:
            traffic_targets[i] = (traffic_targets[i] + 1) % route.size()
            continue
        var lane_dir := lane_diff.normalized()
        # v0.4 (F): follow logic — if a car is ahead of me within 6 m,
        # slow to its actual speed (or stop under 3 m) instead of
        # driving through it. At a shared corner two loops cross, so a
        # car also YIELDS to a crossing car: the lower index has
        # priority, the higher index stops — that way one car always
        # keeps moving and there is no deadlock.
        var speed := traffic_speeds[i]
        for j in range(traffic_cars.size()):
            if j == i:
                continue
            if j >= traffic_current_speeds.size():
                continue
            var other: Node3D = traffic_cars[j]
            var to_other: Vector3 = other.position - car.position
            to_other.y = 0.0
            var d := to_other.length()
            if d > 6.0 or d < 0.01:
                continue
            var ahead := to_other.normalized().dot(lane_dir)
            if ahead < 0.2:
                continue  # behind me or beside me
            if d < 3.0 and j < i:
                speed = 0.0  # yield at a crossing (lower index first)
                continue
            if ahead < 0.5:
                continue  # not clearly ahead of me
            if lane_dir.dot(_car_heading(j)) < 0.5:
                continue  # different heading (crossing / oncoming)
            if d < 3.0:
                speed = 0.0
            else:
                speed = minf(speed, traffic_current_speeds[j] * 0.9)
        # v0.4.2: yield to the DRIVEN police car — the player car is not
        # in traffic_cars, so without this traffic would drive straight
        # through it. Same rules as the follow logic above.
        var pl := get_node_or_null("Player")
        if pl != null and pl.get("driving") == true:
            var to_pl: Vector3 = (pl as Node3D).global_position - car.position
            to_pl.y = 0.0
            var dpl := to_pl.length()
            if dpl > 0.01 and dpl < 6.0:
                var ahead_pl := to_pl.normalized().dot(lane_dir)
                if ahead_pl > 0.5:
                    if dpl < 3.0:
                        speed = 0.0
                    else:
                        speed = minf(speed, (pl as CharacterBody3D).velocity.length() * 0.9)
        if i < traffic_current_speeds.size():
            traffic_current_speeds[i] = speed
        # Wheels must touch the VISIBLE road top (N-S roads 0.02, E-W
        # roads 0.04). The car collision stays flat at y = 0, so this
        # only moves the visual body; it snaps 2 cm at a turn, which is
        # invisible at driving distance.
        car.position.y = 0.02 if absf(lane_dir.z) > absf(lane_dir.x) else 0.04
        car.position += lane_dir * minf(speed * delta, lane_dist)
        car.rotation.y = atan2(-lane_dir.x, -lane_dir.z)

func _create_landmark_building(title: String, pos: Vector3,
        size: Vector3, color: Color):
    _tn_building(pos.x, pos.z, size.x, size.z, size.y, posmod(int(pos.x * 0.5 + pos.z), 5), false)

    var sign := Label3D.new()
    sign.text = title
    sign.font_size = 32
    sign.position = pos + Vector3(0, size.y + 1.0, 0)
    sign.modulate = Color(1.0, 0.91, 0.62)
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(sign)

func _create_street_lamp_old(pos: Vector3):
    var lamp := Node3D.new()
    lamp.name = "StreetLamp"
    lamp.position = pos
    add_child(lamp)

    _box(lamp, Vector3(0.18, 3.6, 0.18),
        Vector3(0, 1.8, 0), Color(0.16, 0.17, 0.19))
    _box(lamp, Vector3(0.9, 0.14, 0.18),
        Vector3(0.35, 3.5, 0), Color(0.16, 0.17, 0.19))
    _box(lamp, Vector3(0.45, 0.2, 0.36),
        Vector3(0.72, 3.42, 0), Color(1.0, 0.88, 0.55))

func _create_street_lights():
    # Lamps stand just outside the 8 m roads, clear of the lane centers.
    for road_index in range(-3, 4):
        var p := float(road_index) * 24.0
        for side in [-1.0, 1.0]:
            for along in range(-3, 4):
                var q := float(along) * 24.0
                _create_street_lamp(Vector3(p + side * 5.2, 0, q + 5.2))

func _update_pedestrians(delta: float):
    for i in range(citizens.size()):
        # v0.4 (G): harden — routes/speeds must exist for this citizen.
        if i >= citizen_routes.size() or i >= citizen_speeds.size():
            continue
        var person := citizens[i]
        # Night criminals (v0.3): they run from the player when he gets
        # close, instead of following their normal patrol route.
        if criminal_active:
            var ck := criminal_indices.find(i)
            if ck >= 0 and not criminal_caught[ck]:
                var pl := get_node_or_null("Player") as Node3D
                if pl != null:
                    var away: Vector3 = person.position - pl.global_position
                    away.y = 0.0
                    if away.length() < 9.0 and away.length() > 0.01:
                        var dir2 := away.normalized()
                        person.position += dir2 * 3.2 * delta
                        person.rotation.y = atan2(-dir2.x, -dir2.z)
                        continue
        # Prayer gathering (v0.3): walk to the mosque rows and stand there.
        if prayer_active and prayer_group.has(i):
            var spot: Vector3 = _prayer_spot(i)
            var diff: Vector3 = spot - person.position
            diff.y = 0.0
            if diff.length() > 0.3:
                var d2 := diff.normalized()
                person.position += d2 * citizen_speeds[i] * delta
                person.rotation.y = atan2(-d2.x, -d2.z)
            else:
                person.rotation.y = 0.0  # Face the mosque (-Z).
            continue

        var route: Array = citizen_routes[i]
        if route.size() < 2:
            continue

        if citizen_waits[i] > 0.0:
            citizen_waits[i] = maxf(0.0, citizen_waits[i] - delta)
            continue

        var target: Vector3 = route[citizen_route_indices[i]]
        var current := person.position
        var difference := target - current
        difference.y = 0.0

        if difference.length() < 0.18:
            citizen_route_indices[i] = (
                citizen_route_indices[i] + 1
            ) % route.size()
            citizen_waits[i] = 0.3 + float(i % 4) * 0.35
            continue

        var direction := difference.normalized()
        person.position += direction * citizen_speeds[i] * delta
        person.rotation.y = atan2(-direction.x, -direction.z)

func _create_weather() -> void:
    # Rain: a box of falling streaks that follows the player. Created
    # once, silent until the weather turns to rain.
    rain_particles = GPUParticles3D.new()
    rain_particles.name = "Rain"
    rain_particles.amount = 1200
    rain_particles.lifetime = 0.7
    rain_particles.emitting = false
    var mat := ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(20, 1, 20)
    mat.direction = Vector3(0, -1, 0)
    mat.spread = 4.0
    mat.initial_velocity_min = 22.0
    mat.initial_velocity_max = 30.0
    mat.gravity = Vector3(0, -9.8, 0)
    rain_particles.process_material = mat
    var streak := BoxMesh.new()
    streak.size = Vector3(0.03, 0.55, 0.03)
    var sm := StandardMaterial3D.new()
    sm.albedo_color = Color(0.65, 0.75, 0.9, 0.55)
    sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    streak.material = sm
    rain_particles.draw_pass_1 = streak
    rain_particles.position = Vector3(0, 10, 0)
    add_child(rain_particles)

func _apply_weather() -> void:
    # Overcast darkening read by daynight.gd (0 clear, 0.25 cloudy, 0.55 rain).
    weather_dark = 0.0 if weather == 0 else (0.25 if weather == 1 else 0.55)
    print("[WEATHER] change -> %d dark=%.2f" % [weather, weather_dark])
    if rain_particles != null:
        rain_particles.emitting = weather == 2
    var ca := get_node_or_null("CityAudio")
    if ca != null and ca.has_method("set_rain"):
        ca.set_rain(weather == 2)

func set_weather_manual(w: int, storm: bool) -> void:
    # v0.4.4: manual weather control from the HUD button. Sets the
    # weather immediately through the existing system (_apply_weather
    # drives weather_dark, rain particles and rain audio), then parks
    # the auto timer at 600 s so the choice sticks. Orage = rain +
    # an immediate lightning flash + thunder, then frequent lightning
    # while it lasts. When the timer finally rolls, manual mode ends.
    weather = w
    weather_storm = storm
    weather_manual = true
    weather_timer = 600.0
    _apply_weather()
    if storm:
        lightning_flash = 1.0
        lightning_timer = 3.0
        var ca := get_node_or_null("CityAudio")
        if ca != null and ca.has_method("play_thunder"):
            ca.play_thunder()
    print("[WEATHER] manual -> %d storm=%s (holds 600 s)" % [w, str(storm)])

func _update_weather(delta: float) -> void:
    weather_timer -= delta
    if weather_timer <= 0.0:
        # v0.4.4: a manual choice ending here also clears the storm.
        weather_manual = false
        weather_storm = false
        var roll := randf()
        if roll < 0.5:
            weather = 0
            weather_timer = randf_range(90.0, 180.0)
        elif roll < 0.8:
            weather = 1
            weather_timer = randf_range(60.0, 120.0)
        else:
            weather = 2
            weather_timer = randf_range(60.0, 120.0)
        _apply_weather()
    # Rain follows the player; lightning only while raining.
    var pl := get_node_or_null("Player") as Node3D
    if rain_particles != null and pl != null:
        rain_particles.global_position = pl.global_position + Vector3(0, 10, 0)
    if weather == 2:
        lightning_timer -= delta
        if lightning_timer <= 0.0:
            # v0.4.4: frequent lightning while a manual Orage lasts.
            lightning_timer = randf_range(3.0, 8.0) if weather_storm else randf_range(8.0, 20.0)
            lightning_flash = 1.0
            var ca := get_node_or_null("CityAudio")
            if ca != null and ca.has_method("play_thunder"):
                ca.play_thunder()
    if lightning_flash > 0.0:
        lightning_flash = maxf(0.0, lightning_flash - delta * 4.0)

func _process(delta):
    city_clock += delta
    # v0.4.3: freeze diagnostics — see _hb_acc declaration above.
    if delta > 0.5:
        print("[FREEZE-WATCH] long frame %.2fs clock=%.1f" % [delta, city_clock])
    _hb_acc += delta
    if _hb_acc >= 5.0:
        _hb_acc = 0.0
        var dn := get_node_or_null("DayNight")
        var gp := get_node_or_null("Gameplay")
        var dlg := get_node_or_null("Dialogue")
        var pl := get_node_or_null("Player") as Node3D
        var t: float = float(dn.get("t")) if dn != null else -1.0
        var m: int = int(gp.get("mission")) if gp != null else -1
        # v0.4.4 FREEZE FORENSICS: the last [HB] before a freeze must
        # name the state of EVERY timed suspect at that moment — the
        # v0.4.3 line only had weather + dlg_busy. Weather + its
        # timer (first change fires at 90 s), radio power + burst,
        # dialogue busy + its timer, nearest citizen distance, night
        # value, glow material count, visible dialogue bubbles.
        var dlg_busy := false
        var dlg_timer := -1.0
        if dlg != null:
            dlg_busy = bool(dlg.get("busy"))
            var dtv = dlg.get("timer")
            if dtv != null:
                dlg_timer = float(dtv)
        var radio_on := false
        var radio_burst := 0.0
        if gp != null:
            radio_on = bool(gp.get("radio_on"))
            var rb = gp.get("radio_burst_left")
            if rb != null:
                radio_burst = float(rb)
        var nearest_cit := 999.0
        if pl != null:
            for c in citizens:
                var d: float = (c as Node3D).global_position.distance_to(pl.global_position)
                if d < nearest_cit:
                    nearest_cit = d
        var night_v := -1.0
        if dn != null:
            night_v = 1.0 - clampf(sin((t - 0.25) * TAU) * 2.5 + 0.35, 0.0, 1.0)
        var bub := 0
        if dlg != null:
            var bb = dlg.get("bubbles")
            if bb != null:
                for k in (bb as Dictionary).values():
                    if k != null and is_instance_valid(k) and (k as Node3D).visible:
                        bub += 1
        var db: bool = dlg_busy
        var pp := str(pl.global_position) if pl != null else "?"
        print("[HB] t=%.3f clock=%.1f mission=%d weather=%d wt=%.0f radio=%s burst=%.1f dlg=%s dlgt=%.1f near=%.1f night=%.2f glow=%d bub=%d pos=%s" % [t, city_clock, m, weather, weather_timer, str(radio_on), radio_burst, str(db), dlg_timer, nearest_cit, night_v, glow_materials.size(), bub, pp])
    _update_night_criminals()
    _update_prayer(delta)
    _update_weather(delta)
    _update_pedestrians(delta)
    _update_traffic(delta)
    _update_driven_car()
    _update_siren()

    animal_clock += delta
    for i in range(animal_nodes.size()):
        var angle = animal_clock * 0.32 + float(i) * 1.7
        animal_nodes[i].position = animal_origins[i] + Vector3(
            sin(angle) * 1.2, 0, cos(angle) * 0.9
        )
        animal_nodes[i].rotation.y = angle


# ===== Stage 2: modern look + night lighting =====
var glow_materials: Array = []
var _glow_cache := {}
var _pool_material: StandardMaterial3D

func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
    var key := "%s_%s" % [color.to_html(), energy]
    if _glow_cache.has(key):
        return _glow_cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color.darkened(0.55)
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = 0.0
    m.set_meta("glow", energy)
    glow_materials.append(m)
    _glow_cache[key] = m
    return m

func _pool_mat() -> StandardMaterial3D:
    if _pool_material != null:
        return _pool_material
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(1, 1, 1), Color(0, 0, 0)])
    g.offsets = PackedFloat32Array([0.0, 1.0])
    var tex := GradientTexture2D.new()
    tex.gradient = g
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    tex.width = 128
    tex.height = 128
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_texture = tex
    m.albedo_color = Color(0, 0, 0, 1)
    m.set_meta("pool", true)
    glow_materials.append(m)
    _pool_material = m
    return m

func _glass_mat() -> StandardMaterial3D:
    var key := "glass"
    if _glow_cache.has(key):
        return _glow_cache[key]
    var m := StandardMaterial3D.new()
    # v0.4.1: was metallic 0.6 / roughness 0.15 — with the sky as the
    # reflection source every window was a little mirror blowing out
    # white in the sun. Dark, rough, almost no metal now.
    m.albedo_color = Color(0.08, 0.12, 0.18)
    m.metallic = 0.1
    m.roughness = 0.5
    _glow_cache[key] = m
    return m

func _glow_dot(pos: Vector3, color: Color, size: float, energy: float):
    var mi := MeshInstance3D.new()
    var s := SphereMesh.new()
    s.radius = size
    s.height = size * 2.0
    s.radial_segments = 8
    s.rings = 4
    mi.mesh = s
    mi.material_override = _glow_mat(color, energy)
    mi.position = pos
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)

func _window_multimesh(xforms: Array, mat: Material):
    if xforms.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    var quad := QuadMesh.new()
    quad.size = Vector2(1.3, 1.8)
    mm.mesh = quad
    mm.instance_count = xforms.size()
    for i in range(xforms.size()):
        mm.set_instance_transform(i, xforms[i])
    var inst := MultiMeshInstance3D.new()
    inst.multimesh = mm
    inst.material_override = mat
    inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(inst)

func _add_windows(cx: float, cz: float, w: float, d: float, h: float):
    var rng := RandomNumberGenerator.new()
    rng.seed = int(absf(cx) * 73.0 + absf(cz) * 131.0 + h * 17.0) + 11
    var floors := int((h - 2.0) / 3.2)
    var tone := Color.from_hsv(rng.randf_range(0.04, 0.12), rng.randf_range(0.03, 0.14), rng.randf_range(0.55, 0.7))
    if floors >= 1:
        var lit_xf: Array = []
        var dark_xf: Array = []
        var faces := [
            [Vector3(0, 0, d * 0.5 + 0.04), 0.0, w],
            [Vector3(0, 0, -d * 0.5 - 0.04), PI, w],
            [Vector3(w * 0.5 + 0.04, 0, 0), PI * 0.5, d],
            [Vector3(-w * 0.5 - 0.04, 0, 0), -PI * 0.5, d],
        ]
        for face in faces:
            var origin: Vector3 = face[0]
            var yaw: float = face[1]
            var span: float = face[2]
            var cols := int(span / 2.6)
            if cols < 1:
                continue
            var spacing := span / float(cols)
            var bs := Basis(Vector3.UP, yaw)
            for c in range(cols):
                var along := -span * 0.5 + (c + 0.5) * spacing
                for r in range(floors):
                    var offset := Vector3(along, 2.4 + r * 3.2, 0.0)
                    var xf := Transform3D(bs, Vector3(cx, 0.0, cz) + origin + bs * offset)
                    if rng.randf() < 0.5:
                        lit_xf.append(xf)
                    else:
                        dark_xf.append(xf)
        _window_multimesh(dark_xf, _glass_mat())
        _window_multimesh(lit_xf, _glow_mat(Color(1.0, 0.82, 0.5), 2.2))
        for r in range(3, floors, 3):
            _box(self, Vector3(w + 0.3, 0.22, d + 0.3), Vector3(cx, 0.8 + r * 3.2, cz), tone)
    _box(self, Vector3(w + 0.2, 0.5, d + 0.2), Vector3(cx, h + 0.25, cz), tone)
    if floors >= 3:
        var crown_h := 2.4
        _box(self, Vector3(w * 0.62, crown_h, d * 0.62), Vector3(cx, h + 0.5 + crown_h * 0.5, cz), tone.darkened(0.35))
        _box(self, Vector3(w * 0.3, 0.9, d * 0.3), Vector3(cx + w * 0.12, h + 0.5 + crown_h + 0.45, cz - d * 0.1), tone)
        if h > 16.0:
            var top := h + 0.5 + crown_h
            _box(self, Vector3(0.1, 4.5, 0.1), Vector3(cx, top + 2.25, cz), Color(0.2, 0.2, 0.22))
            _glow_dot(Vector3(cx, top + 4.6, cz), Color(1.0, 0.1, 0.1), 0.18, 4.0)

func _create_street_lamp(pos: Vector3):
    var lamp := Node3D.new()
    lamp.name = "StreetLamp"
    lamp.position = pos
    add_child(lamp)
    # v0.4.2: lamp head position for the night OmniLight pool
    # (night_glow.gd snaps the 6 nearest lights to these heads).
    lamp_positions.append(pos + Vector3(0.85, 4.28, 0))
    var metal := Color(0.16, 0.17, 0.19)
    _box(lamp, Vector3(0.14, 4.4, 0.14), Vector3(0, 2.2, 0), metal)
    _box(lamp, Vector3(1.1, 0.1, 0.12), Vector3(0.45, 4.35, 0), metal)
    var head := MeshInstance3D.new()
    var hm := BoxMesh.new()
    hm.size = Vector3(0.7, 0.08, 0.3)
    head.mesh = hm
    head.material_override = _glow_mat(Color(1.0, 0.85, 0.5), 3.0)
    head.position = Vector3(0.85, 4.28, 0)
    head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    lamp.add_child(head)
    var pool := MeshInstance3D.new()
    var pq := QuadMesh.new()
    pq.size = Vector2(8, 8)
    pool.mesh = pq
    pool.material_override = _pool_mat()
    pool.rotation_degrees.x = -90
    pool.position = Vector3(0.85, 0.22, 0)
    pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pool.free()

func _car_mesh(car: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot_y := 0.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.rotation_degrees.y = rot_y
    car.add_child(mi)
    return mi

func _car_box(car: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var bm := BoxMesh.new()
    bm.size = size
    return _car_mesh(car, bm, pos, mat)

# v0.4 (E): Kenney Car Kit (CC0, kenney.nl) — assets/cars/. The GLBs
# face +Z, so the model is rotated PI inside the car (traffic drives
# toward -Z). Ground offsets measured headless: the wheel bottoms sit
# 0.6 m (suv: 1.0 m) below the model origin, times the 1.45 scale.
const CAR_MODELS := ["res://assets/cars/sedan-sports.glb", "res://assets/cars/taxi.glb", "res://assets/cars/police.glb", "res://assets/cars/suv-luxury.glb", "res://assets/cars/race.glb", "res://assets/cars/hatchback-sports.glb"]
# v0.4.2: sportier Kenney variants (same CC0 Car Kit) — sedan-sports
# and hatchback-sports sit lower with a spoiler, race is a low
# open-wheeler, suv-luxury is the sleeker SUV. Taxi + police keep
# their identities. Measured headless at 1.45 scale (probe_cars.gd):
# wheel bottoms of ALL 8 models are at y = 0.000 (police -0.013).
# v0.4.1 FIX (flying cars): the Kenney GLB origins sit AT ground level
# — the v0.4 offsets 0.87 / 1.45 assumed the origin was above the
# wheels, so every car floated. Correct offset is 0.0: the traffic
# code already puts the car root on the road top (0.02/0.04) and
# parked cars sit on the ground at y = 0.
const CAR_MODEL_Y := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const CAR_MODEL_SCALE := 1.45

# v0.4.2: the drivable police car (near the POLICE station) + siren
# light-bar materials (pulsed while the siren is on). Set in
# _create_nature_and_vehicles / _create_car.
var police_car: Node3D = null
var siren_red_mat: StandardMaterial3D = null
var siren_blue_mat: StandardMaterial3D = null
# v0.4.2: lamp head positions (world space) for the night OmniLight
# pool in night_glow.gd. Filled by _create_street_lamp.
var lamp_positions: Array[Vector3] = []

# v0.4.2: combined local AABB of a GLB model (unscaled model space —
# the 1.45 scale is applied by the caller). Used to size the collision
# box and to place headlights / mirrors / spotlight on the REAL car
# ends instead of the old fixed z = +/-2.17, which floated up to 0.9 m
# in front of the shorter GLB cars.
func _model_aabb(model: Node3D) -> AABB:
    var aabb := AABB()
    var first := true
    var stack: Array[Node] = [model]
    while not stack.is_empty():
        var n: Node = stack.pop_back()
        if n is MeshInstance3D:
            var mi := n as MeshInstance3D
            if mi.mesh != null:
                var ga := mi.get_aabb()
                for cx in [ga.position.x, ga.end.x]:
                    for cy in [ga.position.y, ga.end.y]:
                        for cz in [ga.position.z, ga.end.z]:
                            var c: Vector3 = mi.transform * Vector3(cx, cy, cz)
                            if first:
                                aabb = AABB(c, Vector3.ZERO)
                                first = false
                            else:
                                aabb = aabb.expand(c)
        for ch in n.get_children():
            stack.append(ch)
    return aabb

func _create_car(pos: Vector3, paint: Color, angle: float, model_idx: int = -1, car_name: String = "Car") -> Node3D:
    # AnimatableBody3D: a physics body driven by code. Traffic moves it by
    # setting its position, and the player CharacterBody3D now collides
    # with it instead of walking straight through the car.
    var car := AnimatableBody3D.new()
    car.name = car_name
    car.sync_to_physics = false
    car.position = pos
    car.rotation.y = angle
    add_child(car)

    # v0.4 (E): Kenney GLB model when requested and loadable; otherwise
    # the procedural box car below is the fallback.
    var model: Node3D = null
    var model_aabb := AABB(Vector3(-0.95, 0, -2.15), Vector3(1.9, 1.5, 4.3))
    if model_idx >= 0:
        var mpath: String = CAR_MODELS[model_idx % CAR_MODELS.size()]
        var packed := load(mpath) as PackedScene
        if packed != null:
            model = packed.instantiate() as Node3D
            model.scale = Vector3.ONE * CAR_MODEL_SCALE
            model.rotation.y = PI
            model.position.y = CAR_MODEL_Y[model_idx % CAR_MODEL_Y.size()]
            car.add_child(model)
            model_aabb = _model_aabb(model)
    # Car-space extents (model +Z is the front; the PI rotation maps it
    # to the car's -Z). All light / mirror / collision placement below
    # is derived from these, so every model gets parts on its own ends.
    var half_w := model_aabb.size.x * CAR_MODEL_SCALE * 0.5
    var front_z := -model_aabb.end.z * CAR_MODEL_SCALE
    var rear_z := -model_aabb.position.z * CAR_MODEL_SCALE
    var mid_z := (front_z + rear_z) * 0.5
    var top_y := model_aabb.end.y * CAR_MODEL_SCALE

    var car_body := CollisionShape3D.new()
    var car_box := BoxShape3D.new()
    if model != null:
        # Box hugs the real model (+15 cm sides, +25 cm length) instead
        # of the old fixed 2.0 x 1.4 x 3.8, which was up to 0.9 m longer
        # than the car and made the player bump into thin air.
        car_box.size = Vector3(
            model_aabb.size.x * CAR_MODEL_SCALE + 0.15,
            1.3,
            model_aabb.size.z * CAR_MODEL_SCALE + 0.25)
        car_body.position = Vector3(0, 0.65, mid_z)
    else:
        car_box.size = Vector3(1.9, 1.5, 4.35)
        car_body.position = Vector3(0, 0.85, 0)
    car_body.shape = car_box
    car.add_child(car_body)
    # v0.4.2: the shape is disabled while the player drives this car
    # (the player capsule is the collision then — otherwise the driver
    # collides with his own car). Kept as metadata for gameplay.gd.
    car.set_meta("collision_shape", car_body)

    var body := StandardMaterial3D.new()
    body.albedo_color = paint
    body.metallic = 0.65
    body.roughness = 0.28

    if model == null:

        var glass := StandardMaterial3D.new()
        glass.albedo_color = Color(0.05, 0.09, 0.13)
        glass.metallic = 0.8
        glass.roughness = 0.08
        var trim := StandardMaterial3D.new()
        trim.albedo_color = Color(0.04, 0.04, 0.05)
        trim.roughness = 0.7

        _car_box(car, Vector3(1.86, 0.55, 4.3), Vector3(0, 0.62, 0), body)
        _car_box(car, Vector3(1.84, 0.12, 4.32), Vector3(0, 0.42, 0), trim)
        _car_box(car, Vector3(1.6, 0.5, 1.5), Vector3(0, 1.145, 0.15), glass)
        _car_box(car, Vector3(1.6, 0.07, 1.5), Vector3(0, 1.43, 0.15), body)
        var wf := PrismMesh.new()
        wf.left_to_right = 0.0
        wf.size = Vector3(0.9, 0.5, 1.6)
        _car_mesh(car, wf, Vector3(0, 1.145, -1.05), glass, 90.0)
        var wr := PrismMesh.new()
        wr.left_to_right = 1.0
        wr.size = Vector3(0.6, 0.5, 1.6)
        _car_mesh(car, wr, Vector3(0, 1.145, 1.2), glass, 90.0)

        var rubber := StandardMaterial3D.new()
        rubber.albedo_color = Color(0.05, 0.05, 0.06)
        rubber.roughness = 0.9
        var rim := StandardMaterial3D.new()
        rim.albedo_color = Color(0.75, 0.77, 0.8)
        rim.metallic = 0.9
        rim.roughness = 0.25
        for side in [-1.0, 1.0]:
            for end in [-1.0, 1.0]:
                var wm := CylinderMesh.new()
                wm.top_radius = 0.34
                wm.bottom_radius = 0.34
                wm.height = 0.26
                wm.radial_segments = 16
                var wheel := _car_mesh(car, wm, Vector3(side * 0.88, 0.34, end * 1.3), rubber)
                wheel.rotation_degrees.z = 90
                var rmesh := CylinderMesh.new()
                rmesh.top_radius = 0.2
                rmesh.bottom_radius = 0.2
                rmesh.height = 0.28
                rmesh.radial_segments = 12
                var rimn := _car_mesh(car, rmesh, Vector3(side * 0.9, 0.34, end * 1.3), rim)
                rimn.rotation_degrees.z = 90

    var head_mat := _glow_mat(Color(1.0, 0.95, 0.8), 4.0)
    var tail_mat := _glow_mat(Color(1.0, 0.1, 0.1), 2.5)
    # v0.4.2: lights + mirrors sit on the REAL car ends (derived from
    # the model AABB above). The old fixed z = +/-2.17 floated up to
    # 0.9 m in front of the shorter GLB cars.
    var light_y := clampf(top_y * 0.45, 0.4, 0.75)
    var mirror_y := clampf(top_y * 0.62, 0.55, 1.0)
    for side in [-1.0, 1.0]:
        _car_box(car, Vector3(0.4, 0.12, 0.06), Vector3(side * half_w * 0.55, light_y, front_z - 0.03), head_mat)
        _car_box(car, Vector3(0.4, 0.1, 0.06), Vector3(side * half_w * 0.55, light_y + 0.02, rear_z + 0.03), tail_mat)
        _car_box(car, Vector3(0.12, 0.1, 0.2), Vector3(side * (half_w + 0.06), mirror_y, front_z * 0.45), body)

    # v0.4.2: red/blue siren light bar on the police car roof (the
    # Kenney police light bar is painted into the body texture, so the
    # flashing needs its own emissive boxes). Pulsed by _process while
    # the player drives with the siren on.
    if model != null and model_idx % CAR_MODELS.size() == 2:
        # Dedicated materials (NOT via _glow_mat: those are registered
        # in glow_materials and night_glow would overwrite the pulse
        # every 0.3 s). Emission starts at 0 — the siren pulse below
        # drives them, and only while the player drives with siren on.
        siren_red_mat = StandardMaterial3D.new()
        siren_red_mat.albedo_color = Color(0.45, 0.04, 0.04)
        siren_red_mat.emission_enabled = true
        siren_red_mat.emission = Color(1.0, 0.08, 0.08)
        siren_red_mat.emission_energy_multiplier = 0.0
        siren_blue_mat = StandardMaterial3D.new()
        siren_blue_mat.albedo_color = Color(0.04, 0.1, 0.45)
        siren_blue_mat.emission_enabled = true
        siren_blue_mat.emission = Color(0.1, 0.25, 1.0)
        siren_blue_mat.emission_energy_multiplier = 0.0
        _car_box(car, Vector3(0.38, 0.1, 0.34), Vector3(-0.26, top_y + 0.06, 0.15), siren_red_mat)
        _car_box(car, Vector3(0.38, 0.1, 0.34), Vector3(0.26, top_y + 0.06, 0.15), siren_blue_mat)

    var spot := SpotLight3D.new()
    spot.position = Vector3(0, light_y, front_z - 0.15)
    spot.rotation_degrees = Vector3(-4, 0, 0)
    spot.spot_range = 18.0
    spot.spot_angle = 30.0
    spot.light_color = Color(1.0, 0.92, 0.75)
    spot.light_energy = 0.0
    spot.visible = false
    # v0.4.2: only the sun ever casts shadows. A shadow-casting light
    # whose visibility toggles at the night transition is a prime
    # suspect for the on-device freeze (mobile GPU state rebuild).
    spot.shadow_enabled = false
    spot.add_to_group("car_headlight")
    car.add_child(spot)
    return car

# ===== Stage 6: Tunisian architecture =====
const TN_SHOPS = ["مخبزة", "صيدلية", "مقهى", "سوق", "ورشة", "مكتبة", "حلاقة", "Boulangerie", "Pharmacie", "Café", "Épicerie"]
var _tn_cache := {}

func _tn_mat(key: String, color: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
    if _tn_cache.has(key):
        return _tn_cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    m.metallic = metal
    _tn_cache[key] = m
    return m

func _arch_mesh(w: float, h: float) -> ArrayMesh:
    var key := "arch_%.2f_%.2f" % [w, h]
    if _tn_cache.has(key):
        return _tn_cache[key]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_normal(Vector3(0, 0, 1))
    var r := w * 0.5
    var y0 := -h * 0.5
    var yc := h * 0.5 - r
    var pa := Vector3(-r, y0, 0.0)
    var pb := Vector3(r, y0, 0.0)
    var pc := Vector3(r, yc, 0.0)
    var pd := Vector3(-r, yc, 0.0)
    for v in [pa, pb, pc, pa, pc, pd]:
        st.add_vertex(v)
    var seg := 10
    for i in range(seg):
        var t0 := PI * float(i) / float(seg)
        var t1 := PI * float(i + 1) / float(seg)
        st.add_vertex(Vector3(0.0, yc, 0.0))
        st.add_vertex(Vector3(r * cos(t0), yc + r * sin(t0), 0.0))
        st.add_vertex(Vector3(r * cos(t1), yc + r * sin(t1), 0.0))
    var mesh := st.commit()
    _tn_cache[key] = mesh
    return mesh

func _tn_multimesh(xforms: Array, mesh: Mesh, mat: Material) -> void:
    if xforms.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = xforms.size()
    for i in range(xforms.size()):
        mm.set_instance_transform(i, xforms[i])
    var inst := MultiMeshInstance3D.new()
    inst.multimesh = mm
    inst.material_override = mat
    inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(inst)

func _tn_node(mesh: Mesh, mat: Material, xf: Transform3D) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.transform = xf
    add_child(mi)

func _tn_boxnode(size: Vector3, mat: Material, xf: Transform3D) -> void:
    var bm := BoxMesh.new()
    bm.size = size
    _tn_node(bm, mat, xf)

func _tn_label(text: String, xf: Transform3D, size: int, px: float, color: Color) -> void:
    var l := Label3D.new()
    l.text = text
    l.font_size = size
    l.pixel_size = px
    l.modulate = color
    l.outline_size = 10
    l.outline_modulate = Color(0, 0, 0, 0.9)
    l.transform = xf
    add_child(l)

func _tn_dome(pos: Vector3, rad: float, mat: Material) -> void:
    var dm := SphereMesh.new()
    dm.radius = rad
    dm.height = rad
    dm.is_hemisphere = true
    _tn_node(dm, mat, Transform3D(Basis.IDENTITY, pos))

func _tn_building(cx: float, cz: float, w: float, d: float, h: float, style: int, with_sign := true) -> void:
    # v0.4.1: wall tones darkened x0.72 — the old near-white albedos
    # (0.95/0.93) under sun 1.3 + ambient 1.0 + sky reflection blew out
    # to blinding white on the phone. Warm sand now, still Kasserine.
    var tones: Array = [Color(0.68, 0.67, 0.64), Color(0.65, 0.61, 0.53), Color(0.62, 0.55, 0.43), Color(0.67, 0.65, 0.59), Color(0.59, 0.5, 0.37)]
    var tone: Color = tones[posmod(style, tones.size())]
    var rng := RandomNumberGenerator.new()
    rng.seed = int(absf(cx) * 71.0 + absf(cz) * 113.0 + h * 13.0) + style * 7 + 5
    _box(self, Vector3(w, h, d), Vector3(cx, h / 2.0, cz), tone, true)
    _box(self, Vector3(w + 0.3, 0.7, d + 0.3), Vector3(cx, h + 0.35, cz), tone.darkened(0.05))
    _box(self, Vector3(w - 0.4, 0.06, d - 0.4), Vector3(cx, h + 0.72, cz), Color(0.5, 0.46, 0.42))
    var roof_y := h + 0.75
    var roll := rng.randf()
    if roll < 0.25:
        var cm := CylinderMesh.new()
        cm.top_radius = 0.7
        cm.bottom_radius = 0.7
        cm.height = 1.3
        _tn_node(cm, _tn_mat("tank", Color(0.25, 0.27, 0.3), 0.5, 0.4), Transform3D(Basis.IDENTITY, Vector3(cx + w * 0.2, roof_y + 0.65, cz - d * 0.2)))
    elif roll < 0.45:
        _box(self, Vector3(2.2, 2.2, 2.2), Vector3(cx - w * 0.2, roof_y + 1.1, cz + d * 0.15), tone)
    elif roll < 0.62:
        var dmat: Material = _tn_mat("dome_w", Color(0.69, 0.69, 0.68), 0.5)
        if rng.randf() < 0.4:
            dmat = _tn_mat("dome_b", Color(0.12, 0.38, 0.66), 0.4, 0.2)
        _tn_dome(Vector3(cx, roof_y, cz), minf(w, d) * 0.26, dmat)

    var faces: Array = [
        [Vector3(0, 0, d * 0.5), 0.0, w],
        [Vector3(0, 0, -d * 0.5), PI, w],
        [Vector3(w * 0.5, 0, 0), PI * 0.5, d],
        [Vector3(-w * 0.5, 0, 0), -PI * 0.5, d],
    ]
    # The door faces the plaza (city centre) instead of a random side, so
    # entrances always open onto the public square, not into a back wall.
    var to_center := Vector2(-cx, -cz)
    var door_face := 0
    if to_center.length() > 0.01:
        to_center = to_center.normalized()
        var face_normals: Array = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
        var best_dot := -2.0
        for fi in range(4):
            var dn: Vector2 = face_normals[fi]
            var dd: float = dn.dot(to_center)
            if dd > best_dot:
                best_dot = dd
                door_face = fi
    var has_sign := with_sign and h >= 6.5 and rng.randf() < 0.5
    var floors := maxi(1, int((h - 1.0) / 3.2))
    var frames: Array = []
    var dark: Array = []
    var lit: Array = []
    for fi in range(faces.size()):
        var origin: Vector3 = faces[fi][0]
        var yaw: float = faces[fi][1]
        var span: float = faces[fi][2]
        var cols := int(span / 2.5)
        if cols < 1:
            continue
        var spacing := span / float(cols)
        var bs := Basis(Vector3.UP, yaw)
        var base := Vector3(cx, 0.0, cz) + origin
        for c in range(cols):
            var along := -span * 0.5 + (float(c) + 0.5) * spacing
            for r in range(floors):
                var y := 1.9 + float(r) * 3.2
                if y + 1.2 > h - 0.4:
                    continue
                if fi == door_face and c == (cols >> 1):
                    if r == 0 or (has_sign and r <= 1):
                        continue
                frames.append(Transform3D(bs, base + bs * Vector3(along, y, 0.06)))
                var gx := Transform3D(bs, base + bs * Vector3(along, y - 0.02, 0.12))
                if rng.randf() < 0.45:
                    lit.append(gx)
                else:
                    dark.append(gx)
    _tn_multimesh(frames, _arch_mesh(1.5, 2.4), _tn_mat("blue", Color(0.1, 0.32, 0.62), 0.6))
    _tn_multimesh(dark, _arch_mesh(1.1, 2.0), _glass_mat())
    _tn_multimesh(lit, _arch_mesh(1.1, 2.0), _glow_mat(Color(1.0, 0.82, 0.5), 2.2))

    var df: Array = faces[door_face]
    var dorigin: Vector3 = df[0]
    var dspan: float = df[2]
    var dbs := Basis(Vector3.UP, float(df[1]))
    var dcols := maxi(1, int(dspan / 2.5))
    var dalong := -dspan * 0.5 + (float(dcols >> 1) + 0.5) * (dspan / float(dcols))
    var dbase := Vector3(cx, 0.0, cz) + dorigin
    _tn_node(_arch_mesh(2.3, 3.5), _tn_mat("doorframe", tone.darkened(0.15)), Transform3D(dbs, dbase + dbs * Vector3(dalong, 1.75, 0.05)))
    _tn_node(_arch_mesh(1.8, 3.1), _tn_mat("door", Color(0.08, 0.28, 0.55), 0.6), Transform3D(dbs, dbase + dbs * Vector3(dalong, 1.55, 0.1)))
    if has_sign:
        var txt: String = TN_SHOPS[rng.randi() % TN_SHOPS.size()]
        var pcols: Array = [Color(0.08, 0.3, 0.2), Color(0.35, 0.1, 0.12), Color(0.1, 0.22, 0.45)]
        var pcol: Color = pcols[rng.randi() % 3]
        _tn_boxnode(Vector3(3.4, 0.8, 0.1), _tn_mat("plq" + pcol.to_html(), pcol, 0.7), Transform3D(dbs, dbase + dbs * Vector3(dalong, 4.1, 0.08)))
        _tn_label(txt, Transform3D(dbs, dbase + dbs * Vector3(dalong, 4.1, 0.16)), 64, 0.0085, Color(1, 1, 1))

    # Real balconies on the door face, one per upper floor, each aligned
    # under a window next to the door (slab + front and side railings).
    var bcol := (dcols >> 1) + 1
    if bcol >= dcols:
        bcol = (dcols >> 1) - 1
    if bcol >= 0:
        var balong := -dspan * 0.5 + (float(bcol) + 0.5) * (dspan / float(dcols))
        var slab_mat: Material = _tn_mat("balc", tone.darkened(0.12), 0.9)
        var rail_mat: Material = _tn_mat("rail", Color(0.16, 0.16, 0.19), 0.5, 0.6)
        for r in range(1, floors):
            var wy := 1.9 + float(r) * 3.2
            if wy + 1.2 > h - 0.4:
                continue
            var sy := wy - 1.3
            _tn_boxnode(Vector3(2.0, 0.12, 1.0), slab_mat, Transform3D(dbs, dbase + dbs * Vector3(balong, sy, 0.55)))
            _tn_boxnode(Vector3(2.0, 0.9, 0.06), rail_mat, Transform3D(dbs, dbase + dbs * Vector3(balong, sy + 0.51, 1.02)))
            for side in [-0.97, 0.97]:
                _tn_boxnode(Vector3(0.06, 0.9, 1.0), rail_mat, Transform3D(dbs, dbase + dbs * Vector3(balong + side, sy + 0.51, 0.55)))

func _tn_mosque(pos: Vector3) -> void:
    var white := Color(0.69, 0.68, 0.65)
    var green := _tn_mat("dome_g", Color(0.12, 0.5, 0.35), 0.35, 0.25)
    _box(self, Vector3(14, 8, 11), pos + Vector3(0, 4, 0), white, true)
    _box(self, Vector3(14.4, 0.7, 11.4), pos + Vector3(0, 8.35, 0), white)
    # v0.3.1: the thin green trim band that wrapped the mosque at y 6.3
    # read on the phone as a stray glitch stripe at the top edge. Removed;
    # the green domes already carry the mosque's identity.
    _tn_dome(pos + Vector3(0, 8.7, 0), 4.2, green)
    _tn_dome(pos + Vector3(-4.8, 8.7, 3.2), 1.6, green)
    _tn_dome(pos + Vector3(4.8, 8.7, 3.2), 1.6, green)
    var mx := pos.x - 8.4
    var mz := pos.z + 2.0
    _box(self, Vector3(3.0, 19.0, 3.0), Vector3(mx, 9.5, mz), white, true)
    _box(self, Vector3(3.9, 0.4, 3.9), Vector3(mx, 19.2, mz), Color(0.12, 0.5, 0.35))
    _box(self, Vector3(2.0, 3.4, 2.0), Vector3(mx, 21.1, mz), white)
    var cone := CylinderMesh.new()
    cone.top_radius = 0.0
    cone.bottom_radius = 1.5
    cone.height = 2.6
    _tn_node(cone, green, Transform3D(Basis.IDENTITY, Vector3(mx, 24.1, mz)))
    var fin := SphereMesh.new()
    fin.radius = 0.25
    fin.height = 0.5
    _tn_node(fin, _tn_mat("gold", Color(0.9, 0.75, 0.3), 0.3, 0.8), Transform3D(Basis.IDENTITY, Vector3(mx, 25.6, mz)))
    var slits: Array = []
    for yy in [6.0, 11.0, 15.5]:
        slits.append(Transform3D(Basis.IDENTITY, Vector3(mx, yy, mz + 1.55)))
        slits.append(Transform3D(Basis(Vector3.UP, PI), Vector3(mx, yy, mz - 1.55)))
        slits.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(mx + 1.55, yy, mz)))
        slits.append(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(mx - 1.55, yy, mz)))
    _tn_multimesh(slits, _arch_mesh(0.5, 1.6), _tn_mat("slit", Color(0.08, 0.1, 0.12), 0.4))
    var wins: Array = []
    for k in range(5):
        wins.append(Transform3D(Basis.IDENTITY, pos + Vector3(-6.0 + float(k) * 3.0, 3.8, 5.56)))
    _tn_multimesh(wins, _arch_mesh(1.3, 3.0), _tn_mat("mwin", Color(0.12, 0.5, 0.35), 0.5))
    _tn_node(_arch_mesh(4.0, 5.9), _tn_mat("mframe", Color(0.12, 0.5, 0.35), 0.5), Transform3D(Basis.IDENTITY, pos + Vector3(0, 2.95, 5.52)))
    _tn_node(_arch_mesh(3.2, 5.2), _tn_mat("mdoor", Color(0.35, 0.2, 0.1), 0.7), Transform3D(Basis.IDENTITY, pos + Vector3(0, 2.6, 5.58)))
    _tn_label("الجامع الكبير", Transform3D(Basis.IDENTITY, pos + Vector3(0, 7.2, 5.62)), 96, 0.01, Color(1.0, 0.95, 0.7))

func _tn_palms() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 777
    var trunks: Array = []
    var fronds: Array = []
    for i in range(-2, 3):
        for side in [-1.0, 1.0]:
            for j in range(-4, 4):
                var pos := Vector3(float(i) * 24.0 + float(side) * 5.6, 0.0, float(j) * 24.0 + 14.0 + rng.randf_range(-1.0, 1.0))
                var s := rng.randf_range(0.8, 1.25)
                var lean := rng.randf_range(-0.08, 0.08)
                var tb := Basis(Vector3.RIGHT, lean) * Basis.from_scale(Vector3(s, s, s))
                trunks.append(Transform3D(tb, pos + Vector3(0, 3.0 * s, 0)))
                var top := pos + Vector3(0, 6.0 * s, 0)
                var yaw0 := rng.randf() * TAU
                for k in range(9):
                    var fb := Basis(Vector3.UP, yaw0 + float(k) * TAU / 9.0) * Basis(Vector3.RIGHT, deg_to_rad(-28.0 + rng.randf_range(-6.0, 6.0)))
                    fronds.append(Transform3D(fb.scaled(Vector3(s, s, s)), top + fb * Vector3(0, 0, -1.55 * s)))
    var tm := CylinderMesh.new()
    tm.top_radius = 0.16
    tm.bottom_radius = 0.28
    tm.height = 6.0
    tm.radial_segments = 8
    _tn_multimesh(trunks, tm, _tn_mat("trunk", Color(0.45, 0.36, 0.26), 0.95))
    var fm := BoxMesh.new()
    fm.size = Vector3(0.55, 0.04, 3.1)
    _tn_multimesh(fronds, fm, _tn_mat("frond", Color(0.18, 0.42, 0.14), 0.8))

func _tn_extras() -> void:
    _tn_mosque(Vector3(12, 0, -36))
    _tn_palms()

# ===== v0.2: street props so the city feels lived-in =====
func _create_bench(pos: Vector3, angle: float) -> void:
    var bench := Node3D.new()
    bench.name = "Bench"
    bench.position = pos
    bench.rotation.y = angle
    add_child(bench)
    var wood := Color(0.45, 0.3, 0.16)
    var iron := Color(0.12, 0.12, 0.14)
    _box(bench, Vector3(1.8, 0.08, 0.5), Vector3(0, 0.45, 0), wood)
    _box(bench, Vector3(1.8, 0.5, 0.08), Vector3(0, 0.75, -0.22), wood)
    _box(bench, Vector3(0.08, 0.45, 0.45), Vector3(-0.8, 0.22, 0), iron)
    _box(bench, Vector3(0.08, 0.45, 0.45), Vector3(0.8, 0.22, 0), iron)

func _create_bin(pos: Vector3) -> void:
    var bin := Node3D.new()
    bin.name = "Bin"
    bin.position = pos
    add_child(bin)
    var body := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.32
    cm.bottom_radius = 0.28
    cm.height = 0.75
    body.mesh = cm
    body.position.y = 0.38
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.12, 0.35, 0.2)
    body.material_override = m
    bin.add_child(body)
    _box(bin, Vector3(0.7, 0.06, 0.7), Vector3(0, 0.78, 0), Color(0.1, 0.1, 0.11))

func _create_stall(pos: Vector3, awning: Color) -> void:
    var stall := Node3D.new()
    stall.name = "MarketStall"
    stall.position = pos
    stall.rotation.y = PI * 0.25
    add_child(stall)
    _box(stall, Vector3(2.4, 0.8, 1.2), Vector3(0, 0.45, 0), Color(0.35, 0.25, 0.15))
    _box(stall, Vector3(2.4, 0.12, 1.4), Vector3(0, 0.95, 0), Color(0.5, 0.35, 0.2))
    for sx in [-1.1, 1.1]:
        _box(stall, Vector3(0.08, 2.2, 0.08), Vector3(sx, 1.1, -0.6), Color(0.15, 0.15, 0.16))
        _box(stall, Vector3(0.08, 2.2, 0.08), Vector3(sx, 1.1, 0.6), Color(0.15, 0.15, 0.16))
    _box(stall, Vector3(2.6, 0.08, 1.8), Vector3(0, 2.25, 0), awning)
    _box(stall, Vector3(0.5, 0.25, 0.4), Vector3(-0.7, 1.15, 0), Color(0.9, 0.4, 0.1))
    _box(stall, Vector3(0.5, 0.25, 0.4), Vector3(0.1, 1.15, 0), Color(0.85, 0.75, 0.2))
    _box(stall, Vector3(0.5, 0.25, 0.4), Vector3(0.8, 1.15, 0), Color(0.3, 0.6, 0.2))

func _create_fountain(pos: Vector3) -> void:
    var f := Node3D.new()
    f.name = "Fountain"
    f.position = pos
    add_child(f)
    var stone := StandardMaterial3D.new()
    stone.albedo_color = Color(0.75, 0.72, 0.65)
    var basin := MeshInstance3D.new()
    var bm := CylinderMesh.new()
    bm.top_radius = 3.0
    bm.bottom_radius = 3.2
    bm.height = 0.7
    basin.mesh = bm
    basin.position.y = 0.35
    basin.material_override = stone
    f.add_child(basin)
    var water := MeshInstance3D.new()
    var wm := CylinderMesh.new()
    wm.top_radius = 2.7
    wm.bottom_radius = 2.7
    wm.height = 0.08
    water.mesh = wm
    water.position.y = 0.62
    var wmat := StandardMaterial3D.new()
    wmat.albedo_color = Color(0.15, 0.45, 0.65)
    wmat.metallic = 0.3
    wmat.roughness = 0.15
    water.material_override = wmat
    f.add_child(water)
    _box(f, Vector3(0.5, 1.1, 0.5), Vector3(0, 1.1, 0), Color(0.75, 0.72, 0.65))
    var top := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.32
    sm.height = 0.64
    top.mesh = sm
    top.position.y = 1.85
    top.material_override = stone
    f.add_child(top)

func _create_props() -> void:
    # Benches around the plaza (all clear of the road strips).
    var bench_spots: Array = [
        [Vector3(6, 0, -6), 0.0],
        [Vector3(-6, 0, -6), PI * 0.5],
        [Vector3(6, 0, 18), PI],
        [Vector3(-6, 0, 18), -PI * 0.5],
        [Vector3(-18, 0, -6), PI * 0.5],
        [Vector3(18, 0, 6), 0.0],
    ]
    for s in bench_spots:
        _create_bench(s[0], float(s[1]))
    # Bins beside benches and walkways.
    for p in [Vector3(7.5, 0, -6), Vector3(-7.5, 0, 18), Vector3(-19.5, 0, -6), Vector3(19.5, 0, 6), Vector3(-18, 0, 6), Vector3(18, 0, -6), Vector3(5.5, 0, 10), Vector3(-5.5, 0, -10)]:
        _create_bin(p)
    # Market stalls near the MARKET sign.
    _create_stall(Vector3(-30, 0, 6), Color(0.85, 0.3, 0.2))
    _create_stall(Vector3(-30, 0, -6), Color(0.2, 0.5, 0.75))
    _create_stall(Vector3(-18, 0, 8), Color(0.9, 0.7, 0.15))
    # Fountain in the plaza, clear of roads and traffic routes.
    _create_fountain(Vector3(-12, 0, -12))

# ===== v0.3: park, hospital details, street signs =====
func _create_park() -> void:
    # Block (-60, 60): 16x16 lawn between the road strips, clear of traffic.
    _box(self, Vector3(16, 0.04, 16), Vector3(-60, -0.02, 60), Color(0.25, 0.5, 0.22))
    _box(self, Vector3(16, 0.02, 1.4), Vector3(-60, 0.01, 60), Color(0.8, 0.72, 0.55))
    _box(self, Vector3(1.4, 0.02, 16), Vector3(-60, 0.01, 60), Color(0.8, 0.72, 0.55))
    _create_tree(Vector3(-66, 0, 54), 1.0)
    _create_tree(Vector3(-54, 0, 54), 1.1)
    _create_tree(Vector3(-66, 0, 66), 0.9)
    _create_tree(Vector3(-54, 0, 66), 1.0)
    _create_bench(Vector3(-60, 0, 54), PI)
    _create_bench(Vector3(-60, 0, 66), 0.0)
    _create_fountain(Vector3(-60, 0, 60))
    _landmark("PARK", Vector3(-60, 4, 60))

func _create_hospital_details() -> void:
    # Red-cross sign + entrance canopy on the hospital front face (-Z side,
    # facing the plaza). Hospital landmark stands at (-36, 0, 36).
    var white := Color(0.68, 0.68, 0.68)
    var red := Color(0.85, 0.1, 0.12)
    _box(self, Vector3(2.0, 2.0, 0.12), Vector3(-36, 4.2, 30.92), white)
    _box(self, Vector3(0.55, 1.5, 0.14), Vector3(-36, 4.2, 30.9), red)
    _box(self, Vector3(1.5, 0.55, 0.14), Vector3(-36, 4.2, 30.9), red)
    _box(self, Vector3(3.2, 0.15, 1.4), Vector3(-36, 2.7, 30.4), Color(0.9, 0.9, 0.92))
    _box(self, Vector3(0.12, 2.7, 0.12), Vector3(-37.4, 1.35, 29.9), Color(0.15, 0.15, 0.17))
    _box(self, Vector3(0.12, 2.7, 0.12), Vector3(-34.6, 1.35, 29.9), Color(0.15, 0.15, 0.17))

func _create_street_signs() -> void:
    var names: Array = [
        ["Rue de la Kasbah", Vector3(5.5, 0, 5.5)],
        ["Av. Habib Bourguiba", Vector3(-5.5, 0, -5.5)],
        ["Rue des Palmiers", Vector3(29.5, 0, 5.5)],
    ]
    for s in names:
        var pole := Node3D.new()
        pole.name = "StreetSign"
        pole.position = s[1]
        add_child(pole)
        _box(pole, Vector3(0.12, 3.2, 0.12), Vector3(0, 1.6, 0), Color(0.15, 0.15, 0.17))
        var l := Label3D.new()
        l.text = String(s[0])
        l.font_size = 32
        l.position = Vector3(0, 3.4, 0)
        l.modulate = Color(1, 1, 1)
        l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        l.outline_size = 8
        pole.add_child(l)

# ===== v0.3: criminals at night =====
# v0.4.2: while the player drives the police car, the car follows the
# player node (the player capsule is the collision — the car's own
# shape is disabled while driving, see gameplay._enter_car).
func _update_driven_car() -> void:
    var pl := get_node_or_null("Player") as Node3D
    if pl == null or police_car == null or not is_instance_valid(police_car):
        return
    if not (pl.get("driving") == true):
        return
    police_car.global_position = Vector3(pl.global_position.x, 0.02, pl.global_position.z)
    police_car.rotation.y = pl.rotation.y

# v0.4.2: red/blue siren flash on the driven police car roof. Only
# writes the materials when the phase changes (once per ~0.35 s).
var _siren_last := -2

func _update_siren() -> void:
    if siren_red_mat == null or siren_blue_mat == null:
        return
    var pl := get_node_or_null("Player")
    var on: bool = pl != null and pl.get("driving") == true and pl.get("siren_on") == true
    var phase := -1 if not on else int(Time.get_ticks_msec() / 350) % 2
    if phase == _siren_last:
        return
    _siren_last = phase
    if phase < 0:
        siren_red_mat.emission_energy_multiplier = 0.0
        siren_blue_mat.emission_energy_multiplier = 0.0
    elif phase == 0:
        siren_red_mat.emission_energy_multiplier = 5.0
        siren_blue_mat.emission_energy_multiplier = 0.0
    else:
        siren_red_mat.emission_energy_multiplier = 0.0
        siren_blue_mat.emission_energy_multiplier = 5.0

func _update_night_criminals() -> void:
    var dn := get_node_or_null("DayNight")
    var night := false
    if dn != null and dn.has_method("is_night"):
        night = dn.is_night()
    # v0.4.2 STAGGER: drain one queued marker flip per frame (below).
    if not night_transition_queue.is_empty():
        var qk: int = night_transition_queue.pop_front()
        if qk >= 0 and qk < criminal_markers.size():
            criminal_markers[qk].visible = night_transition_target
            print("[NIGHT] step marker %d visible=%s" % [qk, night_transition_target])
        if night_transition_queue.is_empty():
            print("[NIGHT] transition complete night=%s" % night_transition_target)
    if night == criminal_active:
        return
    criminal_active = night
    print("[NIGHT] transition start night=%s" % night)
    if night:
        criminal_saved_speeds.clear()
        for k in range(criminal_indices.size()):
            var ci: int = criminal_indices[k]
            # v0.4 (G): harden — never index past the citizen arrays.
            if ci < 0 or ci >= citizen_speeds.size():
                criminal_saved_speeds.append(0.0)
                continue
            criminal_saved_speeds.append(citizen_speeds[ci])
            if not criminal_caught[k]:
                citizen_speeds[ci] = 3.0
        # Markers flip one per frame (staggered), not all at once.
        night_transition_target = true
        for k in range(criminal_indices.size()):
            if k < criminal_markers.size() and not criminal_caught[k]:
                night_transition_queue.append(k)
    else:
        for k in range(criminal_indices.size()):
            var ci: int = criminal_indices[k]
            if ci < 0 or ci >= citizen_speeds.size():
                continue
            if k < criminal_saved_speeds.size():
                citizen_speeds[ci] = criminal_saved_speeds[k]
        night_transition_target = false
        for k in range(criminal_indices.size()):
            if k < criminal_markers.size():
                night_transition_queue.append(k)

func arrest_criminal(index: int) -> bool:
    var k := criminal_indices.find(index)
    if k < 0 or criminal_caught[k] or not criminal_active:
        return false
    criminal_caught[k] = true
    # v0.4 (G): harden — index is from the citizens list, but guard anyway.
    if index >= 0 and index < citizen_routes.size():
        citizen_routes[index] = []
    if index >= 0 and index < citizen_waits.size():
        citizen_waits[index] = 9999.0
    if index >= 0 and index < citizen_speeds.size():
        citizen_speeds[index] = 0.0
    if k < criminal_markers.size():
        criminal_markers[k].text = "CAUGHT"
        criminal_markers[k].modulate = Color(1.0, 0.85, 0.3)
    return true

func criminals_caught_count() -> int:
    var n := 0
    for c in criminal_caught:
        if c:
            n += 1
    return n

# ===== v0.3: mosque prayer times =====
func _prayer_spot(i: int) -> Vector3:
    var k := prayer_group.find(i)
    if k < 0:
        k = 0
    var row := k / 3
    var col := k % 3
    return Vector3(9.5 + float(col) * 2.5, 0, -27.5 - float(row) * 2.0)

func _update_prayer(delta: float) -> void:
    var dn := get_node_or_null("DayNight")
    if dn == null:
        return
    var t: float = dn.t
    # v0.4: a new game day starts when the clock wraps (t jumps back).
    # Each prayer must fire once per day, so the last-fired marker resets.
    if t < prayer_prev_t:
        prayer_last_index = -1
    prayer_prev_t = t
    if prayer_active:
        prayer_timer -= delta
        if prayer_timer <= 0.0:
            _end_prayer()
        else:
            # v0.4: a 20 s prayer can outlast the gap to the next prayer
            # (16:00 -> 18:30 is only 14.9 s at day_length 240). Watch
            # for the next window passing mid-prayer and queue it, so no
            # prayer is ever swallowed — it fires right after this one.
            _check_prayer_window(t)
            return
    # Not praying (or the prayer just ended): start a queued prayer first.
    if prayer_queued >= 0:
        var q := prayer_queued
        prayer_queued = -1
        _start_prayer(q)
        return
    _check_prayer_window(t)

func _check_prayer_window(t: float) -> void:
    for pi in range(prayer_times.size()):
        if pi == prayer_last_index:
            continue
        var pt: float = prayer_times[pi]
        # v0.4: window widened 0.004 -> 0.02 of a day. The old window was
        # so narrow that a single frame hitch could skip a prayer.
        # 0.02 is still far shorter than the gap between prayers, and
        # prayer_last_index prevents double-firing.
        if t >= pt and t < pt + 0.02:
            if prayer_active:
                prayer_queued = pi
                prayer_last_index = pi
            else:
                _start_prayer(pi)
            return

func _start_prayer(pi: int) -> void:
    prayer_active = true
    prayer_timer = 20.0
    prayer_last_index = pi
    print("[PRAYER] start idx=%d" % pi)
    prayer_saved_routes.clear()
    prayer_saved_waits.clear()
    for i in range(citizens.size()):
        # v0.4 (G): harden — routes/waits must exist for this citizen.
        if i < citizen_routes.size():
            prayer_saved_routes.append(citizen_routes[i].duplicate())
        else:
            prayer_saved_routes.append([])
        if i < citizen_waits.size():
            prayer_saved_waits.append(citizen_waits[i])
        else:
            prayer_saved_waits.append(0.0)
    var gp := get_node_or_null("Gameplay")
    if gp != null and gp.has_method("_notice"):
        gp._notice(Settings.t("prayer_time"))
    # v0.3.1: the adhan, on top of the notice + gathering. Guarded: a
    # missing adhan.mp3 simply means no sound, never a crash.
    var ca := get_node_or_null("CityAudio")
    if ca != null and ca.has_method("play_adhan"):
        ca.play_adhan()

func _end_prayer() -> void:
    prayer_active = false
    print("[PRAYER] end")
    for i in range(citizens.size()):
        if i < prayer_saved_routes.size():
            citizen_routes[i] = prayer_saved_routes[i]
            citizen_waits[i] = 0.5
    var gp := get_node_or_null("Gameplay")
    if gp != null and gp.has_method("_notice"):
        gp._notice(Settings.t("prayer_done"))

# ===== v0.3: most wanted =====
func start_wanted() -> void:
    if wanted_active:
        return
    wanted_active = true
    var rng := RandomNumberGenerator.new()
    rng.seed = 90210
    wanted_spot = wanted_spots[rng.randi() % wanted_spots.size()]
    var c: Node3D = citizens[wanted_index]
    c.position = wanted_spot
    citizen_routes[wanted_index] = []
    citizen_waits[wanted_index] = 9999.0
    # Re-skin him as the criminal from the wanted poster.
    var old := c.get_node_or_null("KenneyCharacter")
    if old != null:
        old.free()
    var model := CharacterModel.build(0)
    if model != null:
        c.add_child(model)

func arrest_wanted() -> void:
    if not wanted_active or wanted_arrested:
        return
    wanted_arrested = true
    var c: Node3D = citizens[wanted_index]
    var mark := Label3D.new()
    mark.text = "CAUGHT"
    mark.font_size = 48
    mark.position = Vector3(0, 3.1, 0)
    mark.modulate = Color(1.0, 0.3, 0.2)
    mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    c.add_child(mark)
