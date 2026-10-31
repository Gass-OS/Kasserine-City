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

    var rng = RandomNumberGenerator.new()
    rng.seed = 302610
    var palette = [
        Color(0.79, 0.70, 0.55),
        Color(0.86, 0.79, 0.65),
        Color(0.72, 0.68, 0.57),
        Color(0.83, 0.82, 0.74),
        Color(0.68, 0.59, 0.46)
    ]

    for x in range(-4, 5):
        for z in range(-4, 5):
            if abs(x) <= 1 and abs(z) <= 1:
                continue
            var cx = x * 24.0 + rng.randf_range(-4, 4)
            var cz = z * 24.0 + rng.randf_range(-4, 4)
            var w = rng.randf_range(7.0, 11.0)
            var d = rng.randf_range(7.0, 11.0)
            var h = rng.randf_range(5.0, 13.0)
            var k = fmod(absf(sin(float(x) * 12.9898 + float(z) * 78.233)) * 43758.5453, 1.0)
            if maxf(absf(x), absf(z)) >= 2 and k > 0.4:
                h += (k - 0.4) * 45.0
            _box(self, Vector3(w, h, d), Vector3(cx, h / 2.0, cz), palette[rng.randi_range(0, palette.size() - 1)], true)
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

func _create_car(pos: Vector3, paint: Color, angle: float) -> Node3D:
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
