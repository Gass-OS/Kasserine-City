extends Node

var world: Node3D

func _ready() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    world = get_parent() as Node3D
    if world == null:
        return
    _parked_cars()
    _souk()
    _fountain()
    _trees()

func _parked_cars() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 4242
    var lines := [-72.0, -48.0, -24.0, 0.0, 24.0, 48.0, 72.0]
    var mids := [-60.0, -36.0, -12.0, 12.0, 36.0, 60.0]
    for p in lines:
        for q in mids:
            for side in [-1.0, 1.0]:
                if rng.randf() < 0.22:
                    world.call("_create_car", Vector3(p + side * 3.0, 0.0, q), Color(rng.randf(), rng.randf(), rng.randf()), 0.0 if side > 0.0 else PI)
                if rng.randf() < 0.22:
                    world.call("_create_car", Vector3(q, 0.0, p + side * 3.0), Color(rng.randf(), rng.randf(), rng.randf()), PI * 0.5 if side > 0.0 else -PI * 0.5)

func _stall(pos: Vector3, yaw: float, canopy: Color, good: Color) -> void:
    var root := Node3D.new()
    root.position = pos
    root.rotation.y = yaw
    world.add_child(root)
    world.call("_box", root, Vector3(1.9, 0.9, 0.9), Vector3(0, 0.45, 0), Color(0.45, 0.3, 0.18), true)
    for sx in [-0.95, 0.95]:
        world.call("_box", root, Vector3(0.06, 2.2, 0.06), Vector3(sx, 1.1, -0.4), Color(0.3, 0.22, 0.15))
        world.call("_box", root, Vector3(0.06, 1.9, 0.06), Vector3(sx, 0.95, 0.45), Color(0.3, 0.22, 0.15))
    var cm := BoxMesh.new()
    cm.size = Vector3(2.3, 0.07, 1.7)
    var mi := MeshInstance3D.new()
    mi.mesh = cm
    var mat := StandardMaterial3D.new()
    mat.albedo_color = canopy
    mat.roughness = 0.9
    mi.material_override = mat
    mi.position = Vector3(0, 2.1, 0.0)
    mi.rotation.x = 0.16
    root.add_child(mi)
    for i in range(6):
        var s := SphereMesh.new()
        s.radius = 0.11
        s.height = 0.22
        s.radial_segments = 8
        s.rings = 4
        var g := MeshInstance3D.new()
        g.mesh = s
        var gm := StandardMaterial3D.new()
        gm.albedo_color = good.lerp(Color(1, 1, 1), 0.12 * float(i % 3))
        g.material_override = gm
        g.position = Vector3(-0.7 + float(i) * 0.28, 1.01, 0.0)
        root.add_child(g)

func _souk() -> void:
    var cols := [Color(0.8, 0.2, 0.15), Color(0.1, 0.4, 0.7), Color(0.9, 0.7, 0.15), Color(0.15, 0.55, 0.3), Color(0.85, 0.4, 0.1)]
    var goods := [Color(0.9, 0.2, 0.1), Color(0.95, 0.75, 0.1), Color(0.3, 0.6, 0.15), Color(0.85, 0.45, 0.1), Color(0.5, 0.15, 0.4)]
    var k := 0
    for row in range(2):
        for col in range(4):
            var x := -17.0 + float(row) * 8.0
            var z := 7.5 + float(col) * 3.4
            var yaw := PI * 0.5 if row == 0 else -PI * 0.5
            _stall(Vector3(x, 0.0, z), yaw, cols[k % cols.size()], goods[(k + 2) % goods.size()])
            k += 1
    var l := Label3D.new()
    l.text = "السوق"
    l.font_size = 96
    l.pixel_size = 0.01
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.modulate = Color(1.0, 0.9, 0.5)
    l.outline_size = 12
    l.position = Vector3(-12.5, 5.5, 12.0)
    world.add_child(l)

func _cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, mat: Material) -> void:
    var cm := CylinderMesh.new()
    cm.top_radius = top
    cm.bottom_radius = bottom
    cm.height = h
    cm.radial_segments = 24
    var mi := MeshInstance3D.new()
    mi.mesh = cm
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)

func _fountain() -> void:
    var root := Node3D.new()
    root.position = Vector3(12.0, 0.0, 12.0)
    world.add_child(root)
    var stone := StandardMaterial3D.new()
    stone.albedo_color = Color(0.78, 0.72, 0.62)
    stone.roughness = 0.9
    var water := StandardMaterial3D.new()
    water.albedo_color = Color(0.2, 0.55, 0.75, 0.85)
    water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    water.roughness = 0.1
    water.metallic = 0.3
    _cyl(root, 3.2, 3.4, 0.7, Vector3(0, 0.35, 0), stone)
    _cyl(root, 2.9, 2.9, 0.05, Vector3(0, 0.62, 0), water)
    _cyl(root, 0.35, 0.45, 2.0, Vector3(0, 1.4, 0), stone)
    _cyl(root, 1.1, 0.5, 0.35, Vector3(0, 2.5, 0), stone)
    _cyl(root, 0.06, 0.06, 1.0, Vector3(0, 3.2, 0), water)
    var body := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    var cs := CylinderShape3D.new()
    cs.radius = 3.3
    cs.height = 0.8
    shape.shape = cs
    shape.position = Vector3(0, 0.4, 0)
    body.add_child(shape)
    root.add_child(body)

const KenneyKit = preload("res://scripts/kenney.gd")

func _trees() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 909
    var big: Array = []
    var small: Array = []
    var sb := KenneyKit.height_scale("res://assets/kenney/suburban/tree-large.glb", 6.5)
    var ss := KenneyKit.height_scale("res://assets/kenney/suburban/tree-small.glb", 4.0)
    if sb <= 0.0 and ss <= 0.0:
        return
    for i in range(-4, 5):
        for j in range(-4, 4):
            for side in [-1.0, 1.0]:
                for off in [8.0, 16.0]:
                    var along := float(j) * 24.0 + off + rng.randf_range(-0.6, 0.6)
                    var p := float(i) * 24.0
                    _add_tree(Vector3(along, 0.0, p + side * 4.9), rng, big, small, sb, ss)
                    if absi(i) >= 3:
                        _add_tree(Vector3(p + side * 4.9, 0.0, along), rng, big, small, sb, ss)
    KenneyKit.scatter("res://assets/kenney/suburban/tree-large.glb", big, world, true)
    KenneyKit.scatter("res://assets/kenney/suburban/tree-small.glb", small, world, false)

func _add_tree(pos: Vector3, rng: RandomNumberGenerator, big: Array, small: Array, sb: float, ss: float) -> void:
    if rng.randf() < 0.3:
        return
    var yaw := rng.randf() * TAU
    var use_big := rng.randf() < 0.5
    var s := ss
    if use_big:
        s = sb
    s *= rng.randf_range(0.85, 1.2)
    if s <= 0.0:
        return
    var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), pos)
    if use_big:
        big.append(xf)
    else:
        small.append(xf)
