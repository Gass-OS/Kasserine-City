extends Node3D

const PlayerScript = preload("res://scripts/player.gd")

func _ready():
    _create_environment()
    _create_city()
    var player = CharacterBody3D.new()
    player.set_script(PlayerScript)
    player.name = "Player"
    add_child(player)
    player.position = Vector3(0, 1, 12)

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
            var h = rng.randf_range(4.0, 13.0)
            _box(self, Vector3(w, h, d), Vector3(cx, h / 2.0, cz), palette[rng.randi_range(0, palette.size() - 1)], true)

    var sign = Label3D.new()
    sign.text = "KASSERINE CITY"
    sign.font_size = 64
    sign.position = Vector3(0, 7, -28)
    sign.modulate = Color(1.0, 0.83, 0.35)
    add_child(sign)
