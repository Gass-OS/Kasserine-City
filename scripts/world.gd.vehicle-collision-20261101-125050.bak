extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const CharacterModel = preload("res://scripts/character_model.gd")

func _ready():
    _create_environment()
    _create_city()
    _tn_extras()
    _create_nature_and_vehicles()
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

func _create_environment():
    # Cinematic Mediterranean sky, tuned for the existing Android renderer.
    var env = Environment.new()
    env.background_mode = Environment.BG_SKY

    var sky = Sky.new()
    var sky_material = ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.12, 0.29, 0.52)
    sky_material.sky_horizon_color = Color(0.72, 0.78, 0.82)
    sky_material.ground_bottom_color = Color(0.24, 0.21, 0.17)
    sky_material.ground_horizon_color = Color(0.68, 0.62, 0.51)
    sky_material.sun_angle_max = 18.0
    sky.sky_material = sky_material
    env.sky = sky
    env.background_energy_multiplier = 1.0

    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_color = Color(0.82, 0.85, 0.92)
    env.ambient_light_energy = 0.75

    # Gentle atmospheric depth without expensive screen-space effects.
    env.fog_enabled = true
    env.fog_light_color = Color(0.66, 0.74, 0.81)
    env.fog_density = 0.0012

    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.0

    var world = WorldEnvironment.new()
    world.name = "CinematicWorldEnvironment"
    world.environment = env
    add_child(world)

    var sun = DirectionalLight3D.new()
    sun.name = "MediterraneanSun"
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_color = Color(1.0, 0.92, 0.80)
    sun.light_energy = 1.2
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 90.0
    add_child(sun)

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, solid := false):
    var mesh_instance = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.88
    material.metallic = 0.0
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

func _create_city():
    _box(self, Vector3(360, 1, 360), Vector3(0, -0.55, 0), Color(0.66, 0.58, 0.4), true)

    var road = Color(0.16, 0.17, 0.18)
    var line = Color(0.92, 0.83, 0.55)

    for i in range(-7, 8):
        var p = float(i) * 24.0
        _box(self, Vector3(8, 0.08, 348), Vector3(p, 0.02, 0), road)
        _box(self, Vector3(348, 0.08, 8), Vector3(0, 0.03, p), road)
        for j in range(-15, 16):
            _box(self, Vector3(0.16, 0.02, 2.5), Vector3(p, 0.075, j * 11.0), line)
            _box(self, Vector3(2.5, 0.02, 0.16), Vector3(j * 11.0, 0.08, p), line)

    var rng = RandomNumberGenerator.new()
    rng.seed = 302610
    var palette = [
        Color(0.79, 0.70, 0.55),
        Color(0.86, 0.79, 0.65),
        Color(0.72, 0.68, 0.57),
        Color(0.83, 0.82, 0.74),
        Color(0.68, 0.59, 0.46)
    ]

    _create_road_details()
    _create_sidewalks_and_parking()

    for x in range(-7, 7):
        for z in range(-6, 6):
            if x >= -2 and x <= 1 and z >= -2 and z <= 1:
                continue
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
        Vector3(-6, 0, 22),
        Vector3(-6, 0, -10),
        Vector3(18, 0, -10),
        Vector3(-6, 0, 10),
        Vector3(18, 0, 10),
        Vector3(-30, 0, -10),
        Vector3(-6, 0, -34),
        Vector3(10, 0, -34),
        Vector3(34, 0, -10),
        Vector3(-34, 0, 10),
        Vector3(-10, 0, 34),
        Vector3(18, 0, 34),
        Vector3(42, 0, 10),
        Vector3(58, 0, -10),
        Vector3(-58, 0, 10)
    ]
    for i in range(places.size()):
        var person = Node3D.new()
        person.name = "Citizen_%02d" % i
        person.position = places[i]
        add_child(person)
        citizens.append(person)
        _human(person, i)

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

    # Stage 14: additional civic buildings in the central district.
    _create_landmark_building("PHARMACY", Vector3(-36, 0, -12),
        Vector3(9, 4, 8), Color(0.72, 0.82, 0.70))
    _create_landmark_building("POST OFFICE", Vector3(-12, 0, -36),
        Vector3(10, 4.5, 9), Color(0.79, 0.68, 0.48))
    _create_landmark_building("FIRE STATION", Vector3(-12, 0, -12),
        Vector3(10, 5, 9), Color(0.72, 0.30, 0.24))
    _create_landmark_building("LIBRARY", Vector3(-12, 0, 12),
        Vector3(10, 5, 9), Color(0.72, 0.67, 0.55))
    _create_landmark_building("STADIUM", Vector3(12, 0, -12),
        Vector3(11, 5, 10), Color(0.48, 0.62, 0.43))
    _create_landmark_building("MUNICIPALITY", Vector3(12, 0, 12),
        Vector3(10, 5, 9), Color(0.78, 0.73, 0.62))
    _create_landmark_building("BAKERY", Vector3(12, 0, 36),
        Vector3(9, 4, 8), Color(0.82, 0.61, 0.38))
    _create_landmark_building("BUS STATION", Vector3(36, 0, 12),
        Vector3(10, 4, 9), Color(0.48, 0.60, 0.68))

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
        Vector3(-94, 0, 35), Vector3(-94, 0, 0),
        Vector3(-145, 0, -110), Vector3(-110, 0, -145),
        Vector3(110, 0, -145), Vector3(145, 0, -110),
        Vector3(145, 0, 110), Vector3(110, 0, 145),
        Vector3(-110, 0, 145), Vector3(-145, 0, 110),
        Vector3(-145, 0, -45), Vector3(145, 0, 45),
        Vector3(-45, 0, 145), Vector3(45, 0, -145),
        Vector3(-130, 0, 0), Vector3(130, 0, 0),
        Vector3(0, 0, 130), Vector3(0, 0, -130),
        Vector3(-174, 0, -120), Vector3(-120, 0, -174),
        Vector3(120, 0, -174), Vector3(174, 0, -120),
        Vector3(174, 0, 120), Vector3(120, 0, 174),
        Vector3(-120, 0, 174), Vector3(-174, 0, 120)
    ]
    for i in range(tree_positions.size()):
        var tree_pos: Vector3 = tree_positions[i]
        # Move trees clear of road lanes and intersections.
        var road_x := roundf(tree_pos.x / 24.0) * 24.0
        var road_z := roundf(tree_pos.z / 24.0) * 24.0
        if absf(tree_pos.x - road_x) < 3.0:
            tree_pos.x += 8.0 if tree_pos.x >= 0.0 else -8.0
        if absf(tree_pos.z - road_z) < 3.0:
            tree_pos.z += 8.0 if tree_pos.z >= 0.0 else -8.0
        _create_tree(tree_pos, 0.8 + float(i % 4) * 0.12)

    _create_animal(Vector3(-12, 0, 9), Color(0.55, 0.32, 0.16), "DOG")
    _create_animal(Vector3(12, 0, -10), Color(0.72, 0.65, 0.48), "CAT")
    _create_animal(Vector3(42, 0, 15), Color(0.36, 0.30, 0.24), "DOG")
    _create_animal(Vector3(-42, 0, -15), Color(0.75, 0.68, 0.52), "CAT")
    _create_animal(Vector3(68, 0, 68), Color(0.46, 0.28, 0.14), "DOG")
    # Stage 14: more local street animals.
    _create_animal(Vector3(-58, 0, 42), Color(0.72, 0.65, 0.48), "CAT")
    _create_animal(Vector3(58, 0, -42), Color(0.55, 0.32, 0.16), "DOG")
    _create_animal(Vector3(-82, 0, 72), Color(0.78, 0.72, 0.60), "SHEEP")
    _create_animal(Vector3(82, 0, -72), Color(0.68, 0.58, 0.42), "GOAT")
    _create_animal(Vector3(112, 0, 82), Color(0.82, 0.76, 0.62), "CHICKEN")
    _create_animal(Vector3(-112, 0, -82), Color(0.42, 0.30, 0.20), "DOG")

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


    # Stage 14: parked street vehicles.
    _create_car(Vector3(7.5, 0, -54), Color(0.78, 0.76, 0.68), 0.0)
    _create_car(Vector3(7.5, 0, -6), Color(0.12, 0.28, 0.62), 0.0)
    _create_car(Vector3(7.5, 0, 42), Color(0.72, 0.16, 0.12), 0.0)
    _create_car(Vector3(31.5, 0, 90), Color(0.18, 0.42, 0.25), 0.0)

    # Local motorcycles parked along the sidewalks.
    _create_motorcycle(Vector3(-7.5, 0, -78), Color(0.75, 0.12, 0.08), 0.0)
    _create_motorcycle(Vector3(-7.5, 0, -30), Color(0.12, 0.14, 0.16), 0.0)
    _create_motorcycle(Vector3(-7.5, 0, 18), Color(0.08, 0.30, 0.72), 0.0)
    _create_motorcycle(Vector3(-7.5, 0, 66), Color(0.78, 0.68, 0.12), 0.0)
    _create_motorcycle(Vector3(31.5, 0, -78), Color(0.16, 0.16, 0.18), 0.0)
    _create_motorcycle(Vector3(31.5, 0, 18), Color(0.68, 0.12, 0.10), 0.0)

func _create_tree(pos: Vector3, scale_factor: float, foliage_color: Color = Color(0.12, 0.35, 0.16)):
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
    foliage.albedo_color = foliage_color
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
        route: Array, speed: float):
    var car := _create_car(start, paint, 0.0)
    traffic_cars.append(car)
    traffic_paths.append(route)
    traffic_targets.append(1)
    traffic_speeds.append(speed)

func _update_traffic(delta: float) -> void:
    # Keep enough space between vehicles to prevent body overlap.
    var min_spacing := 5.2

    for i in range(traffic_cars.size()):
        var car: Node3D = traffic_cars[i]
        if not is_instance_valid(car):
            continue

        var route: Array = traffic_paths[i]
        if route.size() < 2:
            continue

        var target_index := posmod(traffic_targets[i], route.size())
        var target: Vector3 = route[target_index]
        var difference := target - car.position
        difference.y = 0.0
        var distance := difference.length()

        if distance < 0.65:
            traffic_targets[i] = (target_index + 1) % route.size()
            continue

        var direction := difference.normalized()
        var step := minf(traffic_speeds[i] * delta, distance)
        var next_position := car.position + direction * step
        var blocked := false

        # Check every other traffic vehicle before moving.
        for j in range(traffic_cars.size()):
            if i == j:
                continue

            var other: Node3D = traffic_cars[j]
            if not is_instance_valid(other):
                continue

            var current_gap := Vector2(
                car.position.x - other.position.x,
                car.position.z - other.position.z
            ).length()

            var next_gap := Vector2(
                next_position.x - other.position.x,
                next_position.z - other.position.z
            ).length()

            if next_gap < min_spacing:
                # Allow a car to escape an existing close position,
                # but block movement that maintains or reduces the gap.
                if next_gap <= current_gap + 0.02:
                    blocked = true
                    break

        if blocked:
            continue

        car.position = next_position
        car.rotation.y = atan2(-direction.x, -direction.z)

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
        var route: Array = citizen_routes[i]
        if route.size() < 2:
            continue

        if citizen_waits[i] > 0.0:
            citizen_waits[i] = maxf(0.0, citizen_waits[i] - delta)
            continue

        var person := citizens[i]
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

func _process(delta):
    city_clock += delta
    _update_pedestrians(delta)
    _update_traffic(delta)

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
    m.albedo_color = Color(0.13, 0.2, 0.28)
    m.metallic = 0.6
    m.roughness = 0.15
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
    var tone := Color.from_hsv(rng.randf_range(0.04, 0.12), rng.randf_range(0.03, 0.14), rng.randf_range(0.68, 0.88))
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
    lamp.add_child(pool)

    var light := OmniLight3D.new()
    light.name = "StreetLampLight"
    light.position = Vector3(0.85, 4.05, 0)
    light.light_color = Color(1.0, 0.78, 0.48)
    light.light_energy = 0.0
    light.omni_range = 14.0
    light.shadow_enabled = false
    light.add_to_group("street_lamp_light")
    lamp.add_child(light)

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

func _create_car_s2(pos: Vector3, paint: Color, angle: float) -> Node3D:
    var car := Node3D.new()
    car.name = "ParkedCar"
    car.position = pos
    car.rotation.y = angle
    add_child(car)

    var body := StandardMaterial3D.new()
    body.albedo_color = paint
    body.metallic = 0.65
    body.roughness = 0.28
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
    for side in [-1.0, 1.0]:
        _car_box(car, Vector3(0.4, 0.12, 0.06), Vector3(side * 0.62, 0.72, -2.17), head_mat)
        _car_box(car, Vector3(0.4, 0.1, 0.06), Vector3(side * 0.62, 0.74, 2.17), tail_mat)
        _car_box(car, Vector3(0.12, 0.1, 0.2), Vector3(side * 0.96, 1.0, -0.55), body)

    var spot := SpotLight3D.new()
    spot.position = Vector3(0, 0.75, -2.2)
    spot.rotation_degrees = Vector3(-4, 0, 0)
    spot.spot_range = 18.0
    spot.spot_angle = 30.0
    spot.light_color = Color(1.0, 0.92, 0.75)
    spot.light_energy = 0.0
    spot.visible = false
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

func _tn_building_proc(cx: float, cz: float, w: float, d: float, h: float, style: int, with_sign := true) -> void:
    var tones: Array = [Color(0.86, 0.82, 0.74), Color(0.82, 0.74, 0.6), Color(0.78, 0.66, 0.5), Color(0.84, 0.78, 0.66), Color(0.74, 0.62, 0.46)]
    var tone: Color = tones[posmod(style, tones.size())]
    var rng := RandomNumberGenerator.new()
    rng.seed = int(absf(cx) * 71.0 + absf(cz) * 113.0 + h * 13.0) + style * 7 + 5
    _box(self, Vector3(w, h, d), Vector3(cx, h / 2.0, cz), tone, true)
    _box(self, Vector3(w + 0.3, 0.7, d + 0.3), Vector3(cx, h + 0.35, cz), tone.darkened(0.05))
    _box(self, Vector3(w - 0.4, 0.06, d - 0.4), Vector3(cx, h + 0.72, cz), Color(0.5, 0.46, 0.42))
    if rng.randf() < 0.45:
        _box(self, Vector3(w + 0.16, 0.3, d + 0.16), Vector3(cx, h - 0.45, cz), Color(0.1, 0.32, 0.62))
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
        var dmat: Material = _tn_mat("dome_w", Color(0.96, 0.96, 0.94), 0.5)
        if rng.randf() < 0.4:
            dmat = _tn_mat("dome_b", Color(0.12, 0.38, 0.66), 0.4, 0.2)
        _tn_dome(Vector3(cx, roof_y, cz), minf(w, d) * 0.26, dmat)

    var faces: Array = [
        [Vector3(0, 0, d * 0.5), 0.0, w],
        [Vector3(0, 0, -d * 0.5), PI, w],
        [Vector3(w * 0.5, 0, 0), PI * 0.5, d],
        [Vector3(-w * 0.5, 0, 0), -PI * 0.5, d],
    ]
    var door_face := int(rng.randi() % 4)
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

func _tn_mosque(pos: Vector3) -> void:
    var white := Color(0.86, 0.84, 0.78)
    var green := _tn_mat("dome_g", Color(0.12, 0.5, 0.35), 0.35, 0.25)
    _box(self, Vector3(14, 8, 11), pos + Vector3(0, 4, 0), white, true)
    _box(self, Vector3(14.4, 0.7, 11.4), pos + Vector3(0, 8.35, 0), white)
    _box(self, Vector3(14.1, 0.3, 11.1), pos + Vector3(0, 6.3, 0), Color(0.12, 0.5, 0.35))
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

# ===== Stage 7: real Kenney models =====
const KenneyKit = preload("res://scripts/kenney.gd")
var _car_counter := 0

func _create_car(pos: Vector3, paint: Color, angle: float) -> Node3D:
    _car_counter += 1
    var spawned = KenneyKit.car(_car_counter + int(paint.r * 9.0 + paint.g * 5.0))
    if spawned == null:
        return _create_car_s2(pos, paint, angle)
    var car := Node3D.new()
    car.name = "ParkedCar"
    car.position = pos
    car.rotation.y = angle
    add_child(car)
    car.add_child(spawned["node"])
    var dims: Vector3 = spawned["size"]
    var hz := dims.z * 0.5
    var hx := dims.x * 0.32
    var hy := dims.y * 0.4
    var head_mat := _glow_mat(Color(1.0, 0.95, 0.8), 4.0)
    var tail_mat := _glow_mat(Color(1.0, 0.1, 0.1), 2.5)
    for side in [-1.0, 1.0]:
        _car_box(car, Vector3(0.36, 0.14, 0.06), Vector3(side * hx, hy, -hz - 0.02), head_mat)
        _car_box(car, Vector3(0.34, 0.12, 0.06), Vector3(side * hx, hy + 0.02, hz + 0.02), tail_mat)
    var spot := SpotLight3D.new()
    spot.position = Vector3(0, hy, -hz)
    spot.rotation_degrees = Vector3(-4, 0, 0)
    spot.spot_range = 18.0
    spot.spot_angle = 30.0
    spot.light_color = Color(1.0, 0.92, 0.75)
    spot.light_energy = 0.0
    spot.visible = false
    spot.add_to_group("car_headlight")
    car.add_child(spot)
    return car

func _add_kenney_windows(holder: Node3D, seed_value: int) -> void:
    if holder == null or not is_instance_valid(holder):
        return

    var dims: Vector3 = holder.get_meta("building_local_dimensions", Vector3.ZERO)
    var building_yaw: float = float(holder.get_meta("building_yaw", 0.0))
    if dims.x <= 0.1 or dims.y <= 0.1 or dims.z <= 0.1:
        return

    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var floors := maxi(1, int((dims.y - 2.0) / 3.2))
    var center := holder.position
    var building_basis := Basis(Vector3.UP, building_yaw)

    var faces: Array = [
        [Vector3(0, 0, dims.z * 0.5 + 0.07), 0.0, dims.x],
        [Vector3(0, 0, -dims.z * 0.5 - 0.07), PI, dims.x],
        [Vector3(dims.x * 0.5 + 0.07, 0, 0), PI * 0.5, dims.z],
        [Vector3(-dims.x * 0.5 - 0.07, 0, 0), -PI * 0.5, dims.z],
    ]

    var lit_xforms: Array = []
    var dark_xforms: Array = []

    for face in faces:
        var origin: Vector3 = face[0]
        var face_yaw: float = face[1]
        var span: float = face[2]
        var cols := maxi(1, int(span / 2.6))
        var spacing := span / float(cols)
        var face_basis := Basis(Vector3.UP, face_yaw)
        var world_basis := building_basis * face_basis

        for col in range(cols):
            var along := -span * 0.5 + (float(col) + 0.5) * spacing
            for floor_index in range(floors):
                var y := 1.9 + float(floor_index) * 3.2
                if y + 1.0 >= dims.y - 0.25:
                    continue

                var local_pos := origin + face_basis * Vector3(along, y, 0.0)
                var world_pos := center + building_basis * local_pos
                var xf := Transform3D(world_basis, world_pos)

                if rng.randf() < 0.48:
                    lit_xforms.append(xf)
                else:
                    dark_xforms.append(xf)

    _window_multimesh(dark_xforms, _glass_mat())
    _window_multimesh(lit_xforms, _glow_mat(Color(1.0, 0.82, 0.5), 2.2))

func _tn_building(cx: float, cz: float, w: float, d: float, h: float, style: int, with_sign := true) -> void:
    if with_sign and posmod(int(absf(cx) * 0.13 + absf(cz) * 0.29) + style, 3) != 0:
        var tints: Array = [Color(0.9, 0.82, 0.68), Color(0.86, 0.76, 0.6), Color(0.82, 0.8, 0.72), Color(0.92, 0.72, 0.52), Color(0.72, 0.8, 0.86)]
        var seed_value := style * 977 + int(absf(cx) * 31.0 + absf(cz) * 17.0)
        var holder = KenneyKit.building(cx, cz, w, d, h, seed_value, tints[posmod(style, tints.size())])
        if holder != null:
            add_child(holder)
            _add_kenney_windows(holder, seed_value)
            return
    _tn_building_proc(cx, cz, w, d, h, style, with_sign)


# Stage 14: simple low-poly motorcycle model.
func _create_motorcycle(pos: Vector3, paint: Color, angle: float) -> Node3D:
    var bike := Node3D.new()
    bike.name = "ParkedMotorcycle"
    bike.position = pos
    bike.rotation.y = angle
    add_child(bike)

    var frame_mat := StandardMaterial3D.new()
    frame_mat.albedo_color = Color(0.12, 0.13, 0.14)
    frame_mat.metallic = 0.45
    frame_mat.roughness = 0.42

    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = paint
    body_mat.metallic = 0.25
    body_mat.roughness = 0.38

    var rubber := StandardMaterial3D.new()
    rubber.albedo_color = Color(0.035, 0.035, 0.04)
    rubber.roughness = 0.92

    # Two wheels, with their cylinder axes turned across the motorcycle.
    for z_offset in [-0.62, 0.62]:
        var wheel := MeshInstance3D.new()
        var wheel_mesh := CylinderMesh.new()
        wheel_mesh.top_radius = 0.34
        wheel_mesh.bottom_radius = 0.34
        wheel_mesh.height = 0.13
        wheel.mesh = wheel_mesh
        wheel.material_override = rubber
        wheel.position = Vector3(0, 0.35, z_offset)
        wheel.rotation.x = PI * 0.5
        bike.add_child(wheel)

    _box(bike, Vector3(0.16, 0.16, 0.95),
        Vector3(0, 0.65, 0), frame_mat.albedo_color)
    _box(bike, Vector3(0.38, 0.24, 0.42),
        Vector3(0, 0.83, -0.12), paint)
    _box(bike, Vector3(0.28, 0.12, 0.42),
        Vector3(0, 0.96, 0.38), Color(0.07, 0.07, 0.075))
    _box(bike, Vector3(0.62, 0.07, 0.09),
        Vector3(0, 1.03, -0.57), frame_mat.albedo_color)

    var lamp := MeshInstance3D.new()
    var lamp_mesh := SphereMesh.new()
    lamp_mesh.radius = 0.11
    lamp_mesh.height = 0.22
    lamp.mesh = lamp_mesh
    lamp.position = Vector3(0, 0.86, -0.67)

    var lamp_mat := StandardMaterial3D.new()
    lamp_mat.albedo_color = Color(1.0, 0.9, 0.62)
    lamp_mat.emission_enabled = true
    lamp_mat.emission = Color(1.0, 0.8, 0.4)
    lamp_mat.emission_energy_multiplier = 1.5
    lamp.material_override = lamp_mat
    bike.add_child(lamp)

    return bike


# Stage 14: road markings and pedestrian crossings.
func _create_road_details() -> void:
    var marking := Color(0.92, 0.89, 0.76)
    var yellow := Color(0.88, 0.68, 0.16)

    # Dashed center markings on the two main streets.
    for i in range(-13, 14):
        var p := float(i) * 12.0
        _box(self, Vector3(0.16, 0.025, 3.5),
            Vector3(0, 0.075, p), yellow)
        _box(self, Vector3(3.5, 0.025, 0.16),
            Vector3(p, 0.075, 0), yellow)

    # Four intersections with zebra crossings on every approach.
    for ix in [-48.0, 48.0]:
        for iz in [-48.0, 48.0]:
            for stripe in range(-3, 4):
                var offset := float(stripe) * 0.88

                # Crossings across north/south-running roads.
                for side in [-1.0, 1.0]:
                    _box(self, Vector3(0.62, 0.025, 0.72),
                        Vector3(ix + offset, 0.085,
                            iz + side * 5.0), marking)

                # Crossings across east/west-running roads.
                for side in [-1.0, 1.0]:
                    _box(self, Vector3(0.72, 0.025, 0.62),
                        Vector3(ix + side * 5.0, 0.085,
                            iz + offset), marking)


# Stage 14: raised sidewalks and roadside parking markings.
func _create_sidewalks_and_parking() -> void:
    var sidewalk := Color(0.48, 0.47, 0.43)
    var curb := Color(0.72, 0.69, 0.61)
    var white := Color(0.92, 0.91, 0.82)

    # Sidewalks run beside every road in the expanded grid.
    # Their top surface is 20 cm above the road surface.
    for i in range(-7, 8):
        var p := float(i) * 24.0

        for side in [-1.0, 1.0]:
            _box(self, Vector3(1.4, 0.4, 348),
                Vector3(p + side * 5.0, 0.07, 0), sidewalk)
            _box(self, Vector3(348, 0.4, 1.4),
                Vector3(0, 0.07, p + side * 5.0), sidewalk)

            # Light curb edge facing the roadway.
            _box(self, Vector3(0.16, 0.12, 348),
                Vector3(p + side * 4.22, 0.13, 0), curb)
            _box(self, Vector3(348, 0.12, 0.16),
                Vector3(0, 0.13, p + side * 4.22), curb)

    # Four marked parallel parking bays in a dedicated outer parking area.
    # Parking apron beside the road, not on the driving lane.
    var parking_x := 129.0
    var parking_z := 132.0
    _box(self, Vector3(5.8, 0.08, 14.4),
        Vector3(parking_x, 0.065, 137.0), Color(0.16, 0.17, 0.18))

    for i in range(4):
        var z := parking_z + float(i) * 3.2

        _box(self, Vector3(0.12, 0.025, 2.8),
            Vector3(parking_x - 1.35, 0.075, z), white)
        _box(self, Vector3(0.12, 0.025, 2.8),
            Vector3(parking_x + 1.35, 0.075, z), white)

    _box(self, Vector3(2.8, 0.025, 0.12),
        Vector3(parking_x, 0.075, parking_z - 1.4), white)
    _box(self, Vector3(2.8, 0.025, 0.12),
        Vector3(parking_x, 0.075, parking_z + 3.2 * 3 + 1.4), white)

    # Benches placed on sidewalks, away from junctions.
    _create_street_bench(Vector3(5.0, 0.27, 72.0))
    _create_street_bench(Vector3(-5.0, 0.27, -72.0))
    _create_street_bench(Vector3(53.0, 0.27, 96.0))
    _create_street_bench(Vector3(-53.0, 0.27, -96.0))

    # Public rubbish bins along pedestrian routes.
    _create_rubbish_bin(Vector3(5.0, 0.27, 36.0))
    _create_rubbish_bin(Vector3(-5.0, 0.27, -36.0))
    _create_rubbish_bin(Vector3(53.0, 0.27, 48.0))
    _create_rubbish_bin(Vector3(-53.0, 0.27, -48.0))
    _create_rubbish_bin(Vector3(29.0, 0.27, 96.0))
    _create_rubbish_bin(Vector3(-29.0, 0.27, -96.0))

    # Bus shelter beside the existing bus station.
    _create_bus_stop(Vector3(53.0, 0.27, 12.0))
    # Plaza moved into the open central block, away from traffic lanes.
    _create_public_plaza(Vector3(36.0, 0.0, 36.0))


# Stage 14: low-poly public street bench.
func _create_street_bench(pos: Vector3) -> void:
    var wood := Color(0.40, 0.22, 0.11)
    var metal := Color(0.12, 0.13, 0.14)

    _box(self, Vector3(1.6, 0.12, 0.42),
        pos + Vector3(0, 0.42, 0), wood)
    _box(self, Vector3(1.6, 0.55, 0.10),
        pos + Vector3(0, 0.76, 0.16), wood)
    for x in [-0.62, 0.62]:
        _box(self, Vector3(0.10, 0.32, 0.34),
            pos + Vector3(x, 0.16, 0), metal)

# Stage 14: public rubbish bin.
func _create_rubbish_bin(pos: Vector3) -> void:
    var bin_color := Color(0.16, 0.34, 0.24)
    _box(self, Vector3(0.42, 0.62, 0.42),
        pos + Vector3(0, 0.31, 0), bin_color)
    _box(self, Vector3(0.48, 0.08, 0.48),
        pos + Vector3(0, 0.66, 0), Color(0.10, 0.12, 0.11))


# Stage 14: covered public bus stop.
func _create_bus_stop(pos: Vector3) -> void:
    var metal := Color(0.12, 0.16, 0.19)
    var roof_color := Color(0.18, 0.25, 0.30)
    var glass := Color(0.35, 0.58, 0.64, 0.55)
    var blue := Color(0.05, 0.25, 0.72)

    # Shelter roof and four supports.
    _box(self, Vector3(3.8, 0.16, 2.0),
        pos + Vector3(0, 2.35, 0), roof_color)

    for x in [-1.7, 1.7]:
        for z in [-0.82, 0.82]:
            _box(self, Vector3(0.10, 2.3, 0.10),
                pos + Vector3(x, 1.15, z), metal)

    # Rear transparent shelter panels.
    _box(self, Vector3(3.4, 1.55, 0.06),
        pos + Vector3(0, 1.35, 0.82), glass)

    # Passenger bench.
    _box(self, Vector3(2.0, 0.12, 0.42),
        pos + Vector3(0, 0.52, 0.35), Color(0.38, 0.23, 0.13))
    _box(self, Vector3(2.0, 0.48, 0.10),
        pos + Vector3(0, 0.82, 0.53), Color(0.38, 0.23, 0.13))

    # Blue bus-stop sign on a separate pole.
    _box(self, Vector3(0.10, 2.5, 0.10),
        pos + Vector3(2.25, 1.25, -0.35), metal)
    _box(self, Vector3(0.65, 0.75, 0.12),
        pos + Vector3(2.25, 2.35, -0.35), blue)


# Stage 14: landscaped pedestrian pocket plaza.
func _create_public_plaza(pos: Vector3) -> void:
    var paving := Color(0.57, 0.54, 0.47)
    var border := Color(0.34, 0.35, 0.31)
    var soil := Color(0.25, 0.17, 0.10)
    var flower := Color(0.85, 0.28, 0.38)

    # Paved pedestrian gathering area.
    _box(self, Vector3(8.0, 0.10, 8.0),
        pos + Vector3(0, 0.05, 0), paving)

    # Four low flower planters.
    for offset in [
        Vector3(-2.8, 0, -2.8),
        Vector3(2.8, 0, -2.8),
        Vector3(-2.8, 0, 2.8),
        Vector3(2.8, 0, 2.8)
    ]:
        _box(self, Vector3(1.35, 0.38, 1.35),
            pos + offset + Vector3(0, 0.24, 0), border)
        _box(self, Vector3(1.12, 0.10, 1.12),
            pos + offset + Vector3(0, 0.48, 0), soil)
        _create_tree(pos + offset + Vector3(0, 0.53, 0),
            0.75, Color(0.20, 0.42, 0.19))

    # Two public benches.
    _create_street_bench(pos + Vector3(-1.8, 0.10, 0))
    _create_street_bench(pos + Vector3(1.8, 0.10, 0))

    # Decorative flower clusters.
    for offset in [
        Vector3(-0.9, 0.58, -2.8),
        Vector3(0.9, 0.58, -2.8),
        Vector3(-0.9, 0.58, 2.8),
        Vector3(0.9, 0.58, 2.8)
    ]:
        _box(self, Vector3(0.22, 0.18, 0.22),
            pos + offset, flower)
