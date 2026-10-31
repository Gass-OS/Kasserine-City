extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const CharacterModel = preload("res://scripts/character_model.gd")

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
    var gameplay = Node.new()
    gameplay.name = "Gameplay"
    gameplay.set_script(preload("res://scripts/gameplay.gd"))
    add_child(gameplay)

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
    add_child(sun)

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, solid := false):
    var mesh_instance = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var material = StandardMaterial3D.new()
    material.albedo_color = color
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
    _box(self, Vector3(220, 1, 220), Vector3(0, -0.55, 0), Color(0.42, 0.48, 0.31), true)

    var road = Color(0.16, 0.17, 0.18)
    var line = Color(0.92, 0.83, 0.55)

    for i in range(-4, 5):
        var p = float(i) * 24.0
        _box(self, Vector3(8, 0.08, 210), Vector3(p, 0.02, 0), road)
        _box(self, Vector3(210, 0.08, 8), Vector3(0, 0.03, p), road)
        for j in range(-9, 10):
            _box(self, Vector3(0.16, 0.02, 2.5), Vector3(p, 0.075, j * 11.0), line)
            _box(self, Vector3(2.5, 0.02, 0.16), Vector3(j * 11.0, 0.08, p), line)

    # Sidewalks on both sides of every road, outside the driving lanes.
    var sidewalk = Color(0.64, 0.62, 0.55)
    for i in range(-4, 5):
        var p := float(i) * 24.0
        for side in [-1.0, 1.0]:
            _box(self, Vector3(1.4, 0.08, 210),
                Vector3(p + side * 4.8, 0.0, 0), sidewalk)
            _box(self, Vector3(210, 0.08, 1.4),
                Vector3(0, 0.0, p + side * 4.8), sidewalk)

    var rng = RandomNumberGenerator.new()
    rng.seed = 302610
    var palette = [
        Color(0.79, 0.70, 0.55),
        Color(0.86, 0.79, 0.65),
        Color(0.72, 0.68, 0.57),
        Color(0.83, 0.82, 0.74),
        Color(0.68, 0.59, 0.46)
    ]

    # CITY_LAYOUT_V2: buildings occupy the blocks BETWEEN roads.
    # Road centres are 24 m apart and each road is 8 m wide.
    for x in range(-4, 4):
        for z in range(-4, 4):
            var cx: float = (float(x) + 0.5) * 24.0
            var cz: float = (float(z) + 0.5) * 24.0

            # Keep the central four plots open for the town centre.
            var is_center_plaza := absf(cx) == 12.0 and absf(cz) == 12.0

            # Reserve plots for SCHOOL, POLICE, HOSPITAL and CAFE.
            var is_landmark_plot := absf(cx) == 36.0 and absf(cz) == 36.0

            # Reserve four plots around the outer town for parks and a kiosk.
            var is_service_plot := absf(cx) == 60.0 and absf(cz) == 60.0

            if is_center_plaza or is_landmark_plot or is_service_plot:
                continue

            # Small variation within the plot; keep generous road clearance.
            cx += rng.randf_range(-1.0, 1.0)
            cz += rng.randf_range(-1.0, 1.0)
            var w = rng.randf_range(7.0, 10.0)
            var d = rng.randf_range(7.0, 10.0)
            var h = rng.randf_range(4.0, 11.0)
            _box(self, Vector3(w, h, d), Vector3(cx, h / 2.0, cz),
                palette[rng.randi_range(0, palette.size() - 1)], true)
            _add_windows(cx, cz, w, d, h)

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
        Vector3(-6, 0, 22)
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

    _create_street_lights()
    _create_city_details()

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

func _add_windows(cx: float, cz: float, w: float, d: float, h: float):
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

func _create_car(pos: Vector3, paint: Color, angle: float) -> Node3D:
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
    _add_windows(pos.x, pos.z, size.x, size.z, size.y)

    var sign := Label3D.new()
    sign.text = title
    sign.font_size = 32
    sign.position = pos + Vector3(0, size.y + 1.0, 0)
    sign.modulate = Color(1.0, 0.91, 0.62)
    add_child(sign)

func _create_street_lamp(pos: Vector3):
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

# Extra town scenery: small parks, café terrace, planters and kiosk.
func _create_city_details():
    # Three pocket parks occupy plots intentionally left free of buildings.
    var park_centres = [
        Vector3(-60, 0, -60),
        Vector3(60, 0, -60),
        Vector3(-60, 0, 60)
    ]
    for centre in park_centres:
        for dx in [-4.0, 4.0]:
            for dz in [-4.0, 4.0]:
                _create_tree(centre + Vector3(dx, 0, dz), 0.78)
        _create_bench(centre + Vector3(0, 0, -6.0))
        _create_planter(centre + Vector3(-6.0, 0, 0), Color(0.18, 0.42, 0.20))
        _create_planter(centre + Vector3(6.0, 0, 0), Color(0.24, 0.48, 0.22))

    # A small magazine kiosk in its own reserved plot.
    var kiosk := Node3D.new()
    kiosk.name = "MagazineKiosk"
    kiosk.position = Vector3(60, 0, 60)
    add_child(kiosk)
    _box(kiosk, Vector3(3.4, 2.35, 2.4), Vector3(0, 1.175, 0),
        Color(0.79, 0.67, 0.45), true)
    _box(kiosk, Vector3(3.8, 0.16, 2.8), Vector3(0, 2.42, 0),
        Color(0.72, 0.16, 0.12))
    _box(kiosk, Vector3(2.2, 0.9, 0.10), Vector3(0, 1.35, -1.25),
        Color(0.22, 0.36, 0.42))
    _box(kiosk, Vector3(2.4, 0.12, 0.55), Vector3(0, 1.0, -1.55),
        Color(0.45, 0.25, 0.13))
    var kiosk_label := Label3D.new()
    kiosk_label.text = "MAGAZINES"
    kiosk_label.font_size = 24
    kiosk_label.position = Vector3(0, 2.0, -1.34)
    kiosk_label.modulate = Color(1.0, 0.95, 0.75)
    kiosk.add_child(kiosk_label)
    _create_planter(Vector3(57.7, 0, 62.0), Color(0.18, 0.42, 0.20))
    _create_planter(Vector3(62.3, 0, 62.0), Color(0.24, 0.48, 0.22))

    # Café terrace beside the CAFE building at (36, 36).
    for z in [34.0, 38.0]:
        _create_cafe_table(Vector3(41.5, 0, z))
    _create_planter(Vector3(41.4, 0, 31.5), Color(0.72, 0.25, 0.24))
    _create_planter(Vector3(41.4, 0, 40.5), Color(0.20, 0.42, 0.20))

func _create_planter(pos: Vector3, leaf_colour: Color):
    var pot := Node3D.new()
    pot.name = "FlowerPot"
    pot.position = pos
    add_child(pot)
    _box(pot, Vector3(0.72, 0.42, 0.72), Vector3(0, 0.21, 0),
        Color(0.60, 0.31, 0.19))
    var plant := MeshInstance3D.new()
    var plant_mesh := SphereMesh.new()
    plant_mesh.radius = 0.34
    plant_mesh.height = 0.65
    plant.mesh = plant_mesh
    plant.position.y = 0.58
    var material := StandardMaterial3D.new()
    material.albedo_color = leaf_colour
    material.roughness = 1.0
    plant.material_override = material
    pot.add_child(plant)

func _create_bench(pos: Vector3):
    var bench := Node3D.new()
    bench.name = "ParkBench"
    bench.position = pos
    add_child(bench)
    var wood := Color(0.39, 0.23, 0.13)
    var metal := Color(0.17, 0.18, 0.19)
    _box(bench, Vector3(1.65, 0.13, 0.48), Vector3(0, 0.52, 0), wood)
    _box(bench, Vector3(1.65, 0.12, 0.12), Vector3(0, 0.88, -0.19), wood)
    for x in [-0.62, 0.62]:
        _box(bench, Vector3(0.12, 0.48, 0.12), Vector3(x, 0.26, 0), metal)
        _box(bench, Vector3(0.12, 0.45, 0.12), Vector3(x, 0.70, -0.19), metal)

func _create_cafe_table(pos: Vector3):
    var table := Node3D.new()
    table.name = "CafeTable"
    table.position = pos
    add_child(table)
    _box(table, Vector3(0.95, 0.10, 0.95), Vector3(0, 0.78, 0),
        Color(0.48, 0.27, 0.15))
    _box(table, Vector3(0.14, 0.72, 0.14), Vector3(0, 0.38, 0),
        Color(0.22, 0.22, 0.23))
    for side in [-1.0, 1.0]:
        var chair_x := side * 0.88
        _box(table, Vector3(0.48, 0.10, 0.48),
            Vector3(chair_x, 0.43, 0), Color(0.18, 0.31, 0.42))
        _box(table, Vector3(0.48, 0.48, 0.10),
            Vector3(chair_x, 0.68, -0.19), Color(0.18, 0.31, 0.42))
        for leg_x in [-0.16, 0.16]:
            _box(table, Vector3(0.07, 0.42, 0.07),
                Vector3(chair_x + leg_x, 0.21, -0.12), Color(0.16, 0.17, 0.18))
            _box(table, Vector3(0.07, 0.42, 0.07),
                Vector3(chair_x + leg_x, 0.21, 0.12), Color(0.16, 0.17, 0.18))

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
