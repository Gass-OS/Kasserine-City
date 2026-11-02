extends Node

const KenneyKit = preload("res://scripts/kenney.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
const BASE := 0.26

var world: Node3D
var player: Node3D
var mats := {}
var sb := 0.0
var ss := 0.0
var tree_big: Array = []
var tree_small: Array = []
var bench_seat: Array = []
var bench_back: Array = []
var tbl_xf: Array = []
var leg_xf: Array = []
var chair_xf: Array = []
var walkers: Array = []
var pets: Array = []
var team: Array = []
var ball: MeshInstance3D
var ball_target := Vector3.ZERO
var ball_t := 0.0
var pitch_c := Vector3(12.0, BASE + 0.09, -12.0)
var ready_ok := false

func _ready() -> void:
    for i in range(8):
        await get_tree().process_frame

    world = get_parent() as Node3D
    if world == null:
        return

    player = world.get_node_or_null("Player") as Node3D
    sb = KenneyKit.height_scale("res://assets/kenney/suburban/tree-large.glb", 6.0)
    ss = KenneyKit.height_scale("res://assets/kenney/suburban/tree-small.glb", 4.0)

    # Use four unused central plots. Preserve all original landmarks.
    _playground(Vector3(-36, 0, 12))
    await get_tree().process_frame

    _police(Vector3(36, 0, -12))
    _cafe(Vector3(12, 0, -36))
    await get_tree().process_frame

    _taxi(Vector3(-12, 0, 36))

    _flush()
    _make_pets()
    ready_ok = true

func _m(key: String, color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
    if mats.has(key):
        return mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    m.metallic = metal
    mats[key] = m
    return m

func _zone(c: Vector3) -> Node3D:
    var root := Node3D.new()
    root.position = Vector3(c.x, BASE, c.z)
    world.add_child(root)
    var rects = world.get("building_rects")
    if rects != null:
        rects.append(Rect2(c.x - 8.0, c.z - 8.0, 16.0, 16.0))
    return root

func _b(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, solid := false) -> MeshInstance3D:
    var bm := BoxMesh.new()
    bm.size = size
    var mi := MeshInstance3D.new()
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    if solid:
        var body := StaticBody3D.new()
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = size
        cs.shape = bs
        body.position = pos
        body.add_child(cs)
        parent.add_child(body)
    return mi

func _cy(parent: Node3D, rt: float, rb: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
    var cm := CylinderMesh.new()
    cm.top_radius = rt
    cm.bottom_radius = rb
    cm.height = h
    cm.radial_segments = 16
    var mi := MeshInstance3D.new()
    mi.mesh = cm
    mi.material_override = mat
    mi.position = pos
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi

func _lab(parent: Node3D, text: String, pos: Vector3, fsize: int, px: float, color: Color) -> void:
    var l := Label3D.new()
    l.text = text
    l.font_size = fsize
    l.pixel_size = px
    l.modulate = color
    l.outline_size = 10
    l.position = pos
    l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
    parent.add_child(l)

func _glow(color: Color, energy: float) -> Material:
    return world.call("_glow_mat", color, energy)

func _lamp(parent: Node3D, pos: Vector3) -> void:
    _b(parent, Vector3(0.1, 3.2, 0.1), pos + Vector3(0, 1.6, 0), _m("metal", Color(0.16, 0.17, 0.19), 0.6, 0.4))
    _b(parent, Vector3(0.34, 0.12, 0.34), pos + Vector3(0, 3.25, 0), _glow(Color(1.0, 0.85, 0.5), 3.0))

func _person(pos: Vector3, skin: int, s: float) -> Node3D:
    var n := Node3D.new()
    n.position = pos
    world.add_child(n)
    var model: Node3D = CharacterModel.build(skin)
    if model != null:
        model.scale = Vector3.ONE * 0.45 * s
        n.add_child(model)
    n.add_to_group("anim_body")
    return n

func _hull(parent: Node3D, pos: Vector3, dims: Vector3, yaw: float) -> void:
    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    var sideways := absf(sin(yaw)) > 0.5
    bs.size = Vector3(dims.z if sideways else dims.x, dims.y, dims.x if sideways else dims.z)
    cs.shape = bs
    body.position = pos + Vector3(0, dims.y * 0.5, 0)
    body.add_child(cs)
    parent.add_child(body)

func _car(parent: Node3D, idx: int, pos: Vector3, yaw: float) -> void:
    var spawned = KenneyKit.car(idx)
    if spawned == null:
        return
    var h: Node3D = spawned["node"]
    h.position = pos
    h.rotation.y = yaw
    parent.add_child(h)
    _hull(parent, pos, spawned["size"], yaw)

func _pcar(pos: Vector3, color: Color, yaw: float) -> void:
    var c = world.call("_create_car", pos, color, yaw)
    if c != null:
        (c as Node3D).set_meta("keep", true)

func _bench(pos: Vector3, yaw: float) -> void:
    var R := Basis(Vector3.UP, yaw)
    bench_seat.append(Transform3D(R * Basis.from_scale(Vector3(1.6, 0.12, 0.5)), pos + R * Vector3(0, 0.45, 0)))
    bench_back.append(Transform3D(R * Basis.from_scale(Vector3(1.6, 0.5, 0.1)), pos + R * Vector3(0, 0.78, -0.22)))

func _tree(pos: Vector3, big: bool) -> void:
    var s := sb if big else ss
    if s <= 0.0:
        return
    var xf := Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * s * randf_range(0.85, 1.2)), pos)
    if big:
        tree_big.append(xf)
    else:
        tree_small.append(xf)

func _walker(n: Node3D, center: Vector3, radius: float, speed: float) -> void:
    walkers.append({"n": n, "c": center, "r": radius, "t": n.position, "w": randf() * 2.0, "sp": speed})

func _park_legacy(c: Vector3) -> void:
    var r := _zone(c)
    _b(r, Vector3(15.6, 0.05, 15.6), Vector3(0, 0.03, 0), _m("grass", Color(0.2, 0.42, 0.18), 1.0))
    var path := _m("path", Color(0.74, 0.67, 0.52), 0.95)
    _b(r, Vector3(1.8, 0.06, 15.6), Vector3(0, 0.04, 0), path)
    _b(r, Vector3(15.6, 0.06, 1.8), Vector3(0, 0.04, 0), path)
    _cy(r, 3.1, 3.1, 0.1, Vector3(-4.2, 0.05, -4.2), _m("stone", Color(0.7, 0.68, 0.62)))
    _cy(r, 2.6, 2.6, 0.12, Vector3(-4.2, 0.06, -4.2), _m("water", Color(0.15, 0.45, 0.6), 0.08, 0.2))
    for b in [Vector3(2.0, 0.05, 4.5), Vector3(-2.0, 0.05, 4.5), Vector3(4.5, 0.05, 2.0), Vector3(4.5, 0.05, -2.0)]:
        _bench(r.position + b, PI * 0.5 if absf(b.x) < 3.0 else 0.0)
    for p in [Vector2(-6, 5), Vector2(6, 5), Vector2(6, -6), Vector2(-6.5, -0.5), Vector2(3.5, 2.8), Vector2(-3, 2.8), Vector2(5, -2.4)]:
        _tree(r.position + Vector3(p.x, 0.05, p.y), randf() < 0.5)
    for lp in [Vector3(-1.4, 0.05, -1.4), Vector3(1.4, 0.05, 1.4), Vector3(-1.4, 0.05, 6.8), Vector3(6.8, 0.05, -1.4)]:
        _lamp(r, lp)
    _lab(r, "الحديقة العامة\nJardin Public", Vector3(0, 4.6, 7.4), 64, 0.012, Color(1.0, 0.95, 0.7))

func _playground(c: Vector3) -> void:
    var r := _zone(c)
    _b(r, Vector3(14.0, 0.05, 14.0), Vector3(0, 0.03, 0), _m("rubber", Color(0.62, 0.22, 0.18), 1.0))
    var metal := _m("metal", Color(0.16, 0.17, 0.19), 0.6, 0.4)
    var bright := _m("playblue", Color(0.15, 0.4, 0.8))
    for px in [-3.7, -2.3]:
        for pz in [-4.2, -2.8]:
            _b(r, Vector3(0.12, 1.6, 0.12), Vector3(px, 0.8, pz), metal)
    _b(r, Vector3(1.8, 0.14, 1.6), Vector3(-3.0, 1.6, -3.5), bright)
    var ramp := _b(r, Vector3(1.0, 0.1, 3.6), Vector3(-3.0, 0.85, -1.1), _m("playred", Color(0.85, 0.2, 0.15)))
    ramp.rotation_degrees = Vector3(-28, 0, 0)
    for sx in [2.0, 4.0]:
        _b(r, Vector3(0.12, 2.6, 0.12), Vector3(sx, 1.3, -3.5), metal)
    _b(r, Vector3(2.3, 0.1, 0.1), Vector3(3.0, 2.6, -3.5), metal)
    for sx in [2.6, 3.4]:
        _b(r, Vector3(0.5, 0.06, 0.3), Vector3(sx, 0.7, -3.5), bright)
        _b(r, Vector3(0.04, 1.9, 0.04), Vector3(sx - 0.2, 1.65, -3.5), metal)
        _b(r, Vector3(0.04, 1.9, 0.04), Vector3(sx + 0.2, 1.65, -3.5), metal)
    _b(r, Vector3(0.3, 0.3, 0.4), Vector3(0, 0.2, 3.0), metal)
    var board := _b(r, Vector3(3.2, 0.1, 0.4), Vector3(0, 0.45, 3.0), _m("playyellow", Color(0.9, 0.75, 0.15)))
    board.rotation_degrees = Vector3(0, 0, 10)
    _b(r, Vector3(3.2, 0.2, 3.2), Vector3(4.0, 0.12, 3.5), _m("sandbox", Color(0.8, 0.7, 0.5), 1.0))
    _lab(r, "ملعب الأطفال\nAire de jeux", Vector3(0, 4.2, 7.0), 64, 0.012, Color(1.0, 0.95, 0.7))
    for k in range(4):
        var pos := r.position + Vector3(randf_range(-5, 5), 0.05, randf_range(-5, 5))
        _walker(_person(pos, k, 0.62), r.position, 5.5, 1.6)


func _stadium_legacy(c: Vector3) -> void:
    var r := _zone(c)
    _b(r, Vector3(15.6, 0.04, 15.6), Vector3(0, 0.02, 0), _m("concrete", Color(0.6, 0.6, 0.58), 0.95))
    _b(r, Vector3(14.0, 0.06, 9.0), Vector3(0, 0.05, 0), _m("pitch", Color(0.15, 0.5, 0.18), 1.0))
    var line := _m("line", Color(0.95, 0.95, 0.92))
    _b(r, Vector3(14.0, 0.02, 0.12), Vector3(0, 0.09, 4.5), line)
    _b(r, Vector3(14.0, 0.02, 0.12), Vector3(0, 0.09, -4.5), line)
    _b(r, Vector3(0.12, 0.02, 9.0), Vector3(7.0, 0.09, 0), line)
    _b(r, Vector3(0.12, 0.02, 9.0), Vector3(-7.0, 0.09, 0), line)
    _b(r, Vector3(0.12, 0.02, 9.0), Vector3(0, 0.09, 0), line)
    _cy(r, 1.4, 1.4, 0.02, Vector3(0, 0.09, 0), line)
    _cy(r, 1.28, 1.28, 0.03, Vector3(0, 0.095, 0), _m("pitch", Color(0.15, 0.5, 0.18), 1.0))

    for gx in [-7.0, 7.0]:
        _b(r, Vector3(0.1, 2.0, 0.1), Vector3(gx, 1.0, -1.8), line)
        _b(r, Vector3(0.1, 2.0, 0.1), Vector3(gx, 1.0, 1.8), line)
        _b(r, Vector3(0.1, 0.1, 3.7), Vector3(gx, 2.0, 0), line)

    var red := _m("seatred", Color(0.8, 0.12, 0.1))
    var blue := _m("seatblue", Color(0.12, 0.3, 0.7))
    for side in [-1.0, 1.0]:
        for k in range(3):
            _b(r, Vector3(14.4, 0.45 * float(k + 1), 0.7), Vector3(0, 0.22 * float(k + 1), side * (5.8 + 0.7 * float(k))), red if k % 2 == 0 else blue, true)

    var glow := _glow(Color(1.0, 1.0, 0.9), 3.5)
    for fx in [-7.4, 7.4]:
        for fz in [-7.4, 7.4]:
            _b(r, Vector3(0.15, 6.0, 0.15), Vector3(fx, 3.0, fz), _m("metal", Color(0.16, 0.17, 0.19), 0.6, 0.4))
            _b(r, Vector3(0.9, 0.4, 0.2), Vector3(fx, 6.1, fz), glow)

    _lab(r, "ملعب الحي\nStade du Quartier", Vector3(0, 5.4, 7.6), 64, 0.012, Color(1.0, 0.95, 0.7))

    var sm := SphereMesh.new()
    sm.radius = 0.22
    sm.height = 0.44
    ball = MeshInstance3D.new()
    ball.mesh = sm
    ball.material_override = _m("ball", Color(0.97, 0.97, 0.97), 0.5)
    world.add_child(ball)
    ball.global_position = pitch_c + Vector3(0, 0.22, 0)
    ball_target = ball.global_position

    for k in range(6):
        var home := Vector3(-4.0 + float(k % 3) * 4.0, 0.0, -2.0 + float(k / 3) * 4.0)
        var p := _person(pitch_c + home, k % 4, 1.0)
        p.set_meta("home", home)
        team.append(p)


func _police(c: Vector3) -> void:
    var r := _zone(c)
    var pole := _m("metal", Color(0.16, 0.17, 0.19), 0.6, 0.4)

    for fx in [-6.2, -4.8]:
        _b(r, Vector3(0.1, 7.0, 0.1), Vector3(fx, 3.5, -6.5), pole)

    _b(r, Vector3(1.6, 0.9, 0.03), Vector3(-5.4, 6.4, -6.5), _m("flagred", Color(0.85, 0.1, 0.12)))
    _cy(r, 0.28, 0.28, 0.04, Vector3(-5.4, 6.4, -6.47), _m("flagwhite", Color(0.97, 0.97, 0.97))).rotation_degrees = Vector3(90, 0, 0)

    _b(r, Vector3(0.14, 1.1, 0.14), Vector3(-1.5, 0.55, 5.8), _m("white", Color(0.92, 0.92, 0.9)))
    _b(r, Vector3(0.14, 1.1, 0.14), Vector3(2.5, 0.55, 5.8), _m("white", Color(0.92, 0.92, 0.9)))
    _b(r, Vector3(4.0, 0.12, 0.12), Vector3(0.5, 1.0, 5.8), _m("stripe", Color(0.85, 0.15, 0.12)))

    _b(r, Vector3(2.2, 2.6, 2.2), Vector3(4.6, 1.3, 5.2), _m("booth", Color(0.82, 0.84, 0.86)), true)
    _b(r, Vector3(1.6, 0.9, 0.05), Vector3(4.6, 1.7, 4.08), _glow(Color(0.6, 0.85, 1.0), 1.5))

    _car(r, 9, Vector3(-3.5, 0.0, 1.0), PI * 0.5)
    _car(r, 9, Vector3(-3.5, 0.0, -2.0), PI * 0.5)
    _car(r, 9, Vector3(3.5, 0.0, -1.0), PI * 0.5)

    _lab(r, "الشرطة الوطنية\nPolice Nationale", Vector3(0, 5.0, 6.8), 64, 0.012, Color(0.7, 0.85, 1.0))

    for k in range(2):
        _walker(
            _person(r.position + Vector3(-1.0 + float(k) * 3.0, 0.0, 3.2), 0, 1.0),
            r.position + Vector3(1.0, 0.0, 3.2),
            1.5,
            0.9
        )


func _cafe(c: Vector3) -> void:
    var r := _zone(c)
    _b(r, Vector3(11.0, 0.04, 8.5), Vector3(0, 0.03, 1.5), _m("rug", Color(0.55, 0.22, 0.16), 1.0))
    var post := _m("post", Color(0.3, 0.2, 0.12))

    for sx in [-5.2, 5.2]:
        for sz in [-1.8, 4.8]:
            _b(r, Vector3(0.14, 3.1, 0.14), Vector3(sx, 1.55, sz), post)

    _b(r, Vector3(11.6, 0.1, 7.2), Vector3(0, 3.15, 1.5), _m("canopy", Color(0.9, 0.78, 0.5)))

    for k in range(5):
        _b(r, Vector3(0.9, 0.11, 7.2), Vector3(-4.8 + float(k) * 2.4, 3.16, 1.5), _m("stripe", Color(0.85, 0.15, 0.12)))

    world.call("_box", r, Vector3(7.0, 3.4, 3.0), Vector3(0, 1.7, -5.8), Color(0.85, 0.8, 0.7), true)
    _b(r, Vector3(5.0, 1.3, 0.06), Vector3(0, 1.7, -4.28), _glow(Color(1.0, 0.85, 0.55), 2.0))
    _lab(r, "مقهى المدينة\nCafé de la Médina", Vector3(0, 4.7, -4.2), 64, 0.011, Color(1.0, 0.92, 0.7))

    var spots := [
        Vector2(-3.4, 0.2),
        Vector2(0.0, 0.2),
        Vector2(3.4, 0.2),
        Vector2(-3.4, 3.2),
        Vector2(0.0, 3.2),
        Vector2(3.4, 3.2)
    ]

    for p in spots:
        var tp: Vector3 = r.position + Vector3(p.x, 0.0, p.y)
        tbl_xf.append(Transform3D(Basis.IDENTITY, tp + Vector3(0, 0.75, 0)))
        leg_xf.append(Transform3D(Basis.IDENTITY, tp + Vector3(0, 0.37, 0)))

        for cs in [-0.8, 0.8]:
            chair_xf.append(Transform3D(Basis.IDENTITY, tp + Vector3(cs, 0.22, 0)))

    for k in range(4):
        var sp: Vector2 = spots[k]
        var pos := r.position + Vector3(sp.x + 0.8, 0.0, sp.y)
        _walker(_person(pos, (k + 1) % 4, 1.0), pos, 0.0, 0.0)


func _gas(c: Vector3) -> void:
    var r := _zone(c)

    var concrete := _m("gas_concrete", Color(0.35, 0.36, 0.34))
    var red := _m("gas_red", Color(0.85, 0.08, 0.06))
    var white := _m("gas_white", Color(0.92, 0.91, 0.85))
    var dark := _m("gas_dark", Color(0.12, 0.13, 0.14))
    var yellow := _m("gas_yellow", Color(1.0, 0.75, 0.08))

    _b(r, Vector3(19, 0.18, 15), Vector3(0, 0.09, 0), concrete)

    # Main station building
    _b(r, Vector3(8, 3.8, 5), Vector3(0, 1.9, -7), white)
    _b(r, Vector3(8.5, 0.3, 5.5), Vector3(0, 3.9, -7), red)

    _b(r, Vector3(5.5, 0.9, 0.12), Vector3(0, 2.5, -4.42), dark)
    _lab(r, "GASS FUEL", Vector3(0, 2.65, -4.3), 64, 0.012, Color(1, 0.85, 0.2))

    # Large fuel canopy
    _b(r, Vector3(15, 0.3, 7), Vector3(0, 4.0, 1.5), red)

    for x in [-6.5, 6.5]:
        for z in [-1.0, 4.0]:
            _b(r, Vector3(0.3, 3.9, 0.3), Vector3(x, 2.0, z), white)

    # Three fuel pumps
    for x in [-4.0, 0.0, 4.0]:
        _b(r, Vector3(1.5, 0.18, 1.5), Vector3(x, 0.2, 1.5), white)
        _b(r, Vector3(0.9, 1.7, 0.65), Vector3(x, 1.1, 1.5), red)
        _b(r, Vector3(0.7, 0.48, 0.08), Vector3(x, 1.45, 1.14), dark)
        _b(r, Vector3(0.5, 0.12, 0.08), Vector3(x, 1.85, 1.14), yellow)
        _b(r, Vector3(0.08, 0.9, 0.08), Vector3(x + 0.53, 1.15, 1.5), dark)

    # Safety markings
    for x in [-7.0, 7.0]:
        _b(r, Vector3(0.18, 0.04, 5.5), Vector3(x, 0.21, 1.5), yellow)

    # Station sign
    _b(r, Vector3(0.25, 5.5, 0.25), Vector3(8.0, 2.75, -5.0), dark)
    _b(r, Vector3(2.8, 1.3, 0.2), Vector3(8.0, 5.7, -5.0), red)
    _lab(r, "GASS\nFUEL", Vector3(8.0, 6.0, -4.8), 64, 0.012, Color(1, 1, 0.8))

    # Night illumination
    _b(r, Vector3(13, 0.12, 5), Vector3(0, 3.83, 1.5), _glow(Color(1.0, 0.85, 0.55), 2.0))


func _taxi(c: Vector3) -> void:
    var r := _zone(c)

    var asphalt := _m("taxi_asphalt", Color(0.25, 0.26, 0.25))
    var yellow := _m("taxi_yellow", Color(1.0, 0.72, 0.05))
    var white := _m("taxi_white", Color(0.9, 0.9, 0.85))
    var dark := _m("taxi_dark", Color(0.12, 0.13, 0.14))
    var metal := _m("taxi_metal", Color(0.4, 0.43, 0.44))

    _b(r, Vector3(19, 0.16, 12), Vector3(0, 0.08, 0), asphalt)

    # Taxi parking bays
    for i in range(4):
        var x := -7.0 + float(i) * 4.6
        _b(r, Vector3(0.12, 0.035, 7.0), Vector3(x, 0.18, 0), white)

    # Taxi rank canopy
    _b(r, Vector3(15, 0.25, 3.8), Vector3(0, 3.4, -3.0), yellow)

    for x in [-6.5, 0.0, 6.5]:
        _b(r, Vector3(0.18, 3.2, 0.18), Vector3(x, 1.7, -3.0), metal)

    # Rank sign
    _b(r, Vector3(0.2, 4.5, 0.2), Vector3(8.5, 2.25, -3.0), dark)
    _b(r, Vector3(3.2, 1.2, 0.2), Vector3(8.5, 4.7, -3.0), yellow)
    _lab(r, "TAXI\nTAXI", Vector3(8.5, 4.95, -2.8), 64, 0.012, dark.color)

    # Waiting benches
    for x in [-4.0, 0.0, 4.0]:
        _b(r, Vector3(2.0, 0.15, 0.65), Vector3(x, 0.65, -4.0), yellow)
        _b(r, Vector3(2.0, 0.9, 0.12), Vector3(x, 1.05, -4.25), metal)

    # Waiting passengers
    for i in range(3):
        var pos := r.position + Vector3(-3.0 + float(i) * 3.0, 0.0, -5.5)
        _walker(_person(pos, i, 1.0), pos, 0.0, 0.0)

    # Street lamps
    for x in [-8.0, 8.0]:
        _b(r, Vector3(0.15, 5.0, 0.15), Vector3(x, 2.5, 4.0), dark)
        _b(r, Vector3(0.9, 0.15, 0.9), Vector3(x, 5.0, 4.0), _glow(Color(1.0, 0.85, 0.55), 2.0))

    # Direction arrows
    for x in [-5.0, 0.0, 5.0]:
        _b(r, Vector3(1.5, 0.035, 0.12), Vector3(x, 0.19, 4.5), white)


func _park(c: Vector3) -> void:
    var r := _zone(c)

    var grass := _m("park_grass", Color(0.22, 0.42, 0.2))
    var path := _m("park_path", Color(0.72, 0.65, 0.51))
    var water := _m("park_water", Color(0.08, 0.42, 0.62), 0.25)
    var wood := _m("park_wood", Color(0.38, 0.22, 0.12))
    var metal := _m("park_metal", Color(0.25, 0.29, 0.28))
    var flower := _m("park_flowers", Color(0.9, 0.25, 0.35))

    # Park ground and walking paths
    _b(r, Vector3(25, 0.2, 23), Vector3(0, 0.1, 0), grass)
    _b(r, Vector3(22, 0.06, 2.0), Vector3(0, 0.23, 7), path)
    _b(r, Vector3(2.0, 0.06, 18), Vector3(-8, 0.23, 0), path)

    # Decorative pond
    _b(r, Vector3(8.0, 0.35, 5.5), Vector3(3, 0.3, -2), water)
    _b(r, Vector3(8.5, 0.15, 0.2), Vector3(3, 0.53, -4.7), path)

    # Pond border
    for x in [-4.0, 4.0]:
        _b(r, Vector3(0.25, 0.55, 6.0), Vector3(3 + x, 0.4, -2), path)

    for z in [-2.8, 2.8]:
        _b(r, Vector3(8.0, 0.55, 0.25), Vector3(3, 0.4, -2 + z), path)

    # Kenney instanced trees
    for i in range(9):
        var x := -10.0 + float(i % 3) * 10.0
        var z := -9.0 + float(i / 3) * 8.0
        _tree(r.position + Vector3(x, 0.05, z), true)

    # Instanced benches
    for x in [-5.0, 0.0, 7.0]:
        _bench(r.position + Vector3(x, 0.0, 7.0), 0.0)

    # Flower beds
    for x in [-9.0, -3.0, 9.0]:
        _b(r, Vector3(2.0, 0.25, 1.2), Vector3(x, 0.35, -8.0), flower)

    # Playground safety floor
    _b(r, Vector3(8.0, 0.18, 6.0), Vector3(7.0, 0.25, 8.0), path)

    # Swing frame
    _b(r, Vector3(0.16, 3.0, 0.16), Vector3(4.0, 1.8, 7.0), metal)
    _b(r, Vector3(0.16, 3.0, 0.16), Vector3(10.0, 1.8, 7.0), metal)
    _b(r, Vector3(6.2, 0.18, 0.18), Vector3(7.0, 3.3, 7.0), metal)

    for x in [5.0, 7.0, 9.0]:
        _b(r, Vector3(0.06, 1.4, 0.06), Vector3(x, 2.5, 7.0), metal)
        _b(r, Vector3(0.9, 0.12, 0.45), Vector3(x, 1.8, 7.0), flower)

    # Slide
    _b(r, Vector3(1.0, 2.0, 0.2), Vector3(10.0, 1.5, 9.5), metal)
    _b(r, Vector3(2.0, 0.12, 1.0), Vector3(10.0, 0.5, 10.0), flower)

    # Park visitors
    for i in range(5):
        var pos := r.position + Vector3(-7.0 + float(i) * 3.0, 0.0, 4.0)
        _walker(_person(pos, i, 1.0), pos, 0.0, 0.0)

    # Park lamps
    for x in [-10.0, 10.0]:
        _b(r, Vector3(0.14, 4.5, 0.14), Vector3(x, 2.25, 2.0), metal)
        _b(r, Vector3(0.8, 0.15, 0.8), Vector3(x, 4.5, 2.0), _glow(Color(1.0, 0.85, 0.55), 2.0))

    _lab(r, "PARC MUNICIPAL\nالحديقة البلدية", Vector3(0, 5.0, -10.5), 64, 0.012, Color(0.85, 1.0, 0.75))


func _stadium(c: Vector3) -> void:
    var r := _zone(c)

    var grass := _m("stadium_grass", Color(0.12, 0.38, 0.16))
    var line := _m("stadium_lines", Color(0.95, 0.95, 0.88))
    var metal := _m("stadium_metal", Color(0.25, 0.28, 0.3))
    var seat := _m("stadium_seats", Color(0.85, 0.12, 0.08))
    var white := _m("stadium_white", Color(0.9, 0.9, 0.85))

    # Football pitch
    _b(r, Vector3(28, 0.2, 19), Vector3(0, 0.1, 0), grass)

    # Pitch boundary lines
    _b(r, Vector3(26, 0.035, 0.13), Vector3(0, 0.22, -8.5), line)
    _b(r, Vector3(26, 0.035, 0.13), Vector3(0, 0.22, 8.5), line)
    _b(r, Vector3(0.13, 0.035, 17), Vector3(-13, 0.22, 0), line)
    _b(r, Vector3(0.13, 0.035, 17), Vector3(13, 0.22, 0), line)

    # Halfway line and centre circle approximation
    _b(r, Vector3(0.12, 0.035, 17), Vector3(0, 0.23, 0), line)
    _b(r, Vector3(4.0, 0.035, 0.12), Vector3(0, 0.23, 0), line)
    _b(r, Vector3(0.12, 0.035, 4.0), Vector3(0, 0.23, 0), line)

    # Goals
    for z in [-8.5, 8.5]:
        _b(r, Vector3(5.0, 0.15, 0.15), Vector3(0, 2.5, z), white)
        for x in [-2.5, 2.5]:
            _b(r, Vector3(0.15, 2.5, 0.15), Vector3(x, 1.35, z), white)

    # Spectator stands
    for z in [-12.0, 12.0]:
        _b(r, Vector3(24, 0.6, 2.0), Vector3(0, 0.5, z), metal)
        for row in range(3):
            _b(r, Vector3(23, 0.35, 0.5),
                Vector3(0, 1.0 + float(row) * 0.4, z + float(row) * 0.6), seat)

    # Floodlight towers
    for x in [-14.0, 14.0]:
        for z in [-10.0, 10.0]:
            _b(r, Vector3(0.25, 9.0, 0.25), Vector3(x, 4.5, z), metal)
            _b(r, Vector3(1.5, 0.5, 0.5), Vector3(x, 9.0, z), _glow(Color(1.0, 0.95, 0.8), 2.0))

    # Football players
    for i in range(10):
        var x := -9.0 + float(i % 5) * 4.5
        var z := -5.0 + float(i / 5) * 10.0
        var pos := r.position + Vector3(x, 0.0, z)
        _walker(_person(pos, i % 4, 1.0), pos, 0.0, 0.0)

    # Stadium entrance sign
    _lab(r, "STADE MUNICIPAL\nملعب البلدية",
        Vector3(0, 4.5, -13.5), 64, 0.012, Color(1.0, 0.9, 0.55))


func _emergency(c: Vector3) -> void:
    var r := _zone(c)

    var concrete := _m("emergency_concrete", Color(0.58, 0.6, 0.58))
    var white := _m("emergency_white", Color(0.94, 0.94, 0.9))
    var red := _m("emergency_red", Color(0.82, 0.06, 0.06))
    var blue := _m("emergency_blue", Color(0.05, 0.3, 0.75))
    var dark := _m("emergency_dark", Color(0.12, 0.14, 0.16))

    # Emergency parking ground
    _b(r, Vector3(24, 0.18, 20), Vector3(0, 0.09, 0), concrete)

    # Emergency building
    _b(r, Vector3(10, 4.5, 6), Vector3(0, 2.25, -7), white)
    _b(r, Vector3(10.3, 0.3, 6.3), Vector3(0, 4.65, -7), red)

    # Emergency entrance
    _b(r, Vector3(3.0, 2.8, 0.15), Vector3(0, 1.5, -3.9), blue)
    _lab(r, "URGENCES\nالاستعجالي", Vector3(0, 5.5, -3.7),
        64, 0.012, Color(1, 1, 1))

    # Ambulance bays
    for x in [-7.0, -2.5]:
        _b(r, Vector3(3.5, 0.06, 6.0), Vector3(x, 0.22, 2), white)
        _b(r, Vector3(0.12, 0.04, 6.0), Vector3(x - 1.7, 0.26, 2), red)
        _b(r, Vector3(0.12, 0.04, 6.0), Vector3(x + 1.7, 0.26, 2), red)

    # Ambulance vehicle representations
    for x in [-7.0, -2.5]:
        _b(r, Vector3(2.5, 1.2, 4.2), Vector3(x, 0.95, 2), white)
        _b(r, Vector3(1.4, 0.9, 0.12), Vector3(x, 1.0, -0.15), blue)
        _b(r, Vector3(0.5, 0.5, 0.08), Vector3(x, 1.5, -0.2), red)

        for wx in [-0.8, 0.8]:
            _b(r, Vector3(0.55, 0.55, 0.08),
                Vector3(x + wx, 1.1, -0.13), blue)

    # Helipad
    _b(r, Vector3(10, 0.2, 9), Vector3(7, 0.18, 5), dark)
    _b(r, Vector3(7, 0.05, 0.16), Vector3(7, 0.32, 5), white)
    _b(r, Vector3(0.16, 0.05, 7), Vector3(7, 0.32, 5), white)

    # H marking
    _b(r, Vector3(0.3, 0.06, 2.5), Vector3(6, 0.38, 5), white)
    _b(r, Vector3(0.3, 0.06, 2.5), Vector3(8, 0.38, 5), white)
    _b(r, Vector3(2.3, 0.06, 0.3), Vector3(7, 0.38, 5), white)

    # Helipad warning lights
    for x in [3.0, 11.0]:
        for z in [1.0, 9.0]:
            _b(r, Vector3(0.35, 0.25, 0.35),
                Vector3(x, 0.4, z), _glow(Color(0.1, 0.65, 1.0), 2.0))

    # Medical staff and visitors
    for i in range(5):
        var pos := r.position + Vector3(-4.0 + float(i) * 2.0, 0.0, -1.0)
        _walker(_person(pos, i % 4, 1.0), pos, 0.0, 0.0)

    # Emergency information sign
    _b(r, Vector3(0.2, 4.5, 0.2), Vector3(11.0, 2.25, -5.0), dark)
    _b(r, Vector3(3.0, 1.2, 0.2), Vector3(11.0, 4.7, -5.0), red)
    _lab(r, "24H\nEMERGENCY", Vector3(11.0, 4.95, -4.8),
        64, 0.012, Color(1, 1, 1))


func _supermarket(c: Vector3) -> void:
    var r := _zone(c)

    var wall := _m("market_wall", Color(0.82, 0.81, 0.75))
    var red := _m("market_red", Color(0.78, 0.08, 0.06))
    var glass := _m("market_glass", Color(0.12, 0.42, 0.55), 0.25)
    var metal := _m("market_metal", Color(0.35, 0.38, 0.4))
    var floor := _m("market_floor", Color(0.62, 0.62, 0.57))
    var green := _m("market_green", Color(0.15, 0.48, 0.2))
    var yellow := _m("market_yellow", Color(1.0, 0.75, 0.12))

    # Supermarket ground
    _b(r, Vector3(25, 0.2, 22), Vector3(0, 0.1, 0), floor)

    # Main building
    _b(r, Vector3(16, 5.5, 10), Vector3(0, 2.85, -6), wall)
    _b(r, Vector3(16.5, 0.35, 10.5), Vector3(0, 5.75, -6), red)

    # Front windows
    _b(r, Vector3(11, 2.5, 0.12), Vector3(0, 2.6, -0.92), glass)

    # Entrance doors
    _b(r, Vector3(2.5, 2.8, 0.16), Vector3(0, 1.5, -0.8), metal)
    _b(r, Vector3(1.0, 2.5, 0.08), Vector3(-0.5, 1.5, -0.68), glass)
    _b(r, Vector3(1.0, 2.5, 0.08), Vector3(0.5, 1.5, -0.68), glass)

    # Supermarket sign
    _b(r, Vector3(9, 1.1, 0.2), Vector3(0, 4.7, -0.8), green)
    _lab(r, "SUPERMARCHE\nالسوبرماركت",
        Vector3(0, 4.95, -0.6), 64, 0.012, Color(1, 1, 1))

    # Interior shopping shelves
    for x in [-5.0, -2.5, 2.5, 5.0]:
        _b(r, Vector3(1.2, 1.8, 5.0), Vector3(x, 1.0, -6), metal)

        for y in [0.55, 1.1, 1.65]:
            _b(r, Vector3(1.35, 0.12, 5.2),
                Vector3(x, y, -6), green)

    # Checkout counters
    for x in [-4.0, 0.0, 4.0]:
        _b(r, Vector3(2.4, 0.9, 1.0), Vector3(x, 0.55, -1.5), red)
        _b(r, Vector3(0.7, 0.12, 0.6), Vector3(x, 1.05, -1.5), metal)

    # Shopping carts
    for i in range(4):
        var x := -4.5 + float(i) * 3.0
        _b(r, Vector3(1.0, 0.7, 0.8), Vector3(x, 0.8, 3.0), metal)
        _b(r, Vector3(1.1, 0.08, 0.08), Vector3(x, 1.2, 2.55), metal)

        for wx in [-0.35, 0.35]:
            _b(r, Vector3(0.15, 0.15, 0.15),
                Vector3(x + wx, 0.2, 3.3), metal)

    # Customer parking
    for i in range(5):
        var x := -9.0 + float(i) * 4.5
        _b(r, Vector3(0.12, 0.04, 5.0),
            Vector3(x, 0.22, 8.0), yellow)

    # Customers
    for i in range(6):
        var pos := r.position + Vector3(-6.0 + float(i) * 2.4, 0.0, 1.0)
        _walker(_person(pos, i % 4, 1.0), pos, 0.0, 0.0)

    # Exterior lighting
    for x in [-7.0, 7.0]:
        _b(r, Vector3(0.14, 4.5, 0.14), Vector3(x, 2.25, 1.0), metal)
        _b(r, Vector3(0.8, 0.15, 0.8),
            Vector3(x, 4.5, 1.0), _glow(Color(1.0, 0.85, 0.55), 2.0))


func _police_compound(c: Vector3) -> void:
    var r := _zone(c)

    var wall := _m("police_wall", Color(0.72, 0.75, 0.77))
    var blue := _m("police_blue", Color(0.04, 0.16, 0.55))
    var white := _m("police_white", Color(0.94, 0.94, 0.9))
    var dark := _m("police_dark", Color(0.12, 0.14, 0.17))
    var concrete := _m("police_concrete", Color(0.38, 0.4, 0.4))
    var red := _m("police_red", Color(0.8, 0.04, 0.04))

    _b(r, Vector3(25, 0.2, 22), Vector3(0, 0.1, 0), concrete)

    # Police station
    _b(r, Vector3(12, 5.5, 7), Vector3(0, 2.85, -7), wall)
    _b(r, Vector3(12.4, 0.35, 7.4), Vector3(0, 5.75, -7), blue)

    # Main entrance
    _b(r, Vector3(2.4, 3.0, 0.15), Vector3(0, 1.6, -3.4), blue)
    _b(r, Vector3(1.0, 2.5, 0.08), Vector3(-0.55, 1.5, -3.28), white)
    _b(r, Vector3(1.0, 2.5, 0.08), Vector3(0.55, 1.5, -3.28), white)

    _lab(r, "POLICE\nالشرطة", Vector3(0, 4.8, -3.2),
        64, 0.012, Color(1, 1, 1))

    # Garage
    _b(r, Vector3(8, 4.0, 6), Vector3(7.0, 2.0, -6), dark)
    _b(r, Vector3(6.5, 3.0, 0.15), Vector3(7.0, 1.7, -2.9), blue)

    # Patrol car parking bays
    for x in [-7.0, -2.0, 3.0]:
        _b(r, Vector3(3.8, 0.06, 6.0), Vector3(x, 0.22, 4.0), white)

    # Police vehicle representations
    for x in [-7.0, -2.0, 3.0]:
        _b(r, Vector3(2.3, 1.0, 4.0), Vector3(x, 0.8, 4.0), white)
        _b(r, Vector3(2.35, 0.35, 1.2), Vector3(x, 1.1, 3.5), blue)
        _b(r, Vector3(0.8, 0.12, 0.25), Vector3(x, 1.4, 3.0),
            _glow(Color(0.1, 0.3, 1.0), 2.0))

    # Security barriers
    for x in [-9.0, 9.0]:
        _b(r, Vector3(0.3, 1.4, 0.3), Vector3(x, 0.8, 9.0), red)
        _b(r, Vector3(3.5, 0.15, 0.15), Vector3(x, 1.5, 9.0), white)

    # Officers and visitors
    for i in range(5):
        var pos := r.position + Vector3(-5.0 + float(i) * 2.5, 0.0, -1.0)
        _walker(_person(pos, i % 4, 1.0), pos, 0.0, 0.0)

    # Compound floodlights
    for x in [-10.0, 10.0]:
        _b(r, Vector3(0.16, 5.0, 0.16), Vector3(x, 2.5, 5.0), dark)
        _b(r, Vector3(0.9, 0.18, 0.9), Vector3(x, 5.0, 5.0),
            _glow(Color(0.6, 0.75, 1.0), 2.0))


func _residential(c: Vector3) -> void:
    var r := _zone(c)

    var wall := _m("res_wall", Color(0.76, 0.66, 0.53))
    var cream := _m("res_cream", Color(0.91, 0.84, 0.7))
    var balcony := _m("res_balcony", Color(0.3, 0.32, 0.32))
    var glass := _m("res_glass", Color(0.12, 0.3, 0.42), 0.2)
    var wood := _m("res_wood", Color(0.35, 0.22, 0.13))
    var green := _m("res_green", Color(0.2, 0.42, 0.18))
    var road := _m("res_ground", Color(0.39, 0.4, 0.37))

    _b(r, Vector3(27, 0.2, 25), Vector3(0, 0.1, 0), road)

    # Four residential buildings
    for i in range(4):
        var x := -10.0 + float(i) * 6.7
        var z := -5.0 if i % 2 == 0 else 6.0
        var height := 8.0 if i % 2 == 0 else 6.0

        _b(r, Vector3(5.8, height, 6.0),
            Vector3(x, height * 0.5, z), wall if i % 2 == 0 else cream)

        # Front windows
        for floor in range(1, int(height / 3.0) + 1):
            for wx in [-1.6, 1.6]:
                var wy := float(floor) * 2.5
                _b(r, Vector3(1.1, 1.3, 0.12),
                    Vector3(x + wx, wy, z - 3.06), glass)

                # Balcony floor and railing
                _b(r, Vector3(1.7, 0.12, 0.8),
                    Vector3(x + wx, wy - 0.8, z - 3.45), balcony)
                _b(r, Vector3(1.7, 0.12, 0.12),
                    Vector3(x + wx, wy - 0.25, z - 3.8), balcony)

                for side in [-0.8, 0.8]:
                    _b(r, Vector3(0.1, 0.65, 0.1),
                        Vector3(x + wx + side, wy - 0.55, z - 3.8), balcony)

        # Rooftop
        _b(r, Vector3(6.0, 0.25, 6.2),
            Vector3(x, height + 0.12, z), cream)

    # Ground-floor shops
    for x in [-10.0, -3.3, 3.4, 10.0]:
        _b(r, Vector3(4.0, 2.8, 0.12),
            Vector3(x, 1.4, 9.1), glass)
        _b(r, Vector3(4.2, 0.35, 0.3),
            Vector3(x, 3.0, 9.0), green)

    # Small gardens
    for x in [-11.0, -4.0, 4.0, 11.0]:
        _b(r, Vector3(2.0, 0.15, 2.0),
            Vector3(x, 0.25, -10.0), green)
        _b(r, Vector3(0.25, 2.0, 0.25),
            Vector3(x, 1.2, -10.0), wood)
        _b(r, Vector3(2.0, 1.8, 2.0),
            Vector3(x, 2.7, -10.0), green)

    # Street residents
    for i in range(8):
        var pos := r.position + Vector3(-10.0 + float(i) * 2.8, 0.0, 2.0)
        _walker(_person(pos, i % 4, 1.0), pos, 0.0, 0.0)

    # Street lamps
    for x in [-12.0, 12.0]:
        _b(r, Vector3(0.15, 5.0, 0.15),
            Vector3(x, 2.5, 0.0), balcony)
        _b(r, Vector3(0.8, 0.15, 0.8),
            Vector3(x, 5.0, 0.0), _glow(Color(1.0, 0.82, 0.55), 2.0))


func _mountains(c: Vector3) -> void:
    var r := _zone(c)

    var rock := _m("mountain_rock", Color(0.42, 0.36, 0.29))
    var rock_light := _m("mountain_light", Color(0.59, 0.49, 0.37))
    var sand := _m("mountain_sand", Color(0.72, 0.59, 0.39))
    var road := _m("mountain_road", Color(0.25, 0.26, 0.25))
    var green := _m("mountain_green", Color(0.22, 0.35, 0.19))
    var white := _m("mountain_white", Color(0.91, 0.87, 0.75))

    # Mountain terrain
    _b(r, Vector3(40, 0.5, 35), Vector3(0, 0.25, 0), sand)

    # Rocky mountain formations
    var peaks := [
        Vector3(-15, 7, -12),
        Vector3(-5, 10, -15),
        Vector3(7, 8, -14),
        Vector3(17, 6, -10),
        Vector3(-17, 6, 5),
        Vector3(17, 9, 7)
    ]

    for i in range(peaks.size()):
        var p: Vector3 = peaks[i]
        _b(r, Vector3(9, p.y * 2.0, 8),
            Vector3(p.x, p.y, p.z), rock if i % 2 == 0 else rock_light)

        _b(r, Vector3(5, 2.0, 4),
            Vector3(p.x + 1.0, p.y * 1.7, p.z - 1.0), rock_light)

    # Mountain vegetation
    for i in range(12):
        var x := -17.0 + float(i % 6) * 6.5
        var z := -8.0 + float(i / 6) * 16.0
        _b(r, Vector3(0.35, 1.5, 0.35),
            Vector3(x, 0.8, z), rock)
        _b(r, Vector3(1.5, 1.5, 1.5),
            Vector3(x, 1.8, z), green)

    # City entrance road
    _b(r, Vector3(12, 0.16, 22),
        Vector3(0, 0.12, 10), road)

    # Entrance gate pillars
    for x in [-7.0, 7.0]:
        _b(r, Vector3(1.0, 5.5, 1.0),
            Vector3(x, 2.75, 0), white)

        _b(r, Vector3(1.3, 0.5, 1.3),
            Vector3(x, 5.7, 0), sand)

    # Welcome arch
    _b(r, Vector3(15.5, 0.8, 1.0),
        Vector3(0, 5.3, 0), white)

    _lab(r, "KASSERINE\nالقصرين",
        Vector3(0, 6.0, 0.7), 64, 0.015,
        Color(0.95, 0.82, 0.48))

    # Scenic viewpoint platform
    _b(r, Vector3(9, 0.4, 7),
        Vector3(12, 0.5, -12), white)

    # Viewpoint railing
    for x in [-4.0, 4.0]:
        _b(r, Vector3(0.15, 1.2, 7),
            Vector3(12 + x, 1.2, -15.5), rock)

    _b(r, Vector3(9, 0.15, 0.15),
        Vector3(12, 1.5, -15.5), rock)

    # Viewpoint sign
    _lab(r, "PANORAMA KASSERINE",
        Vector3(12, 3.0, -12), 64, 0.012, white.color)

    # Roadside lighting
    for x in [-5.0, 5.0]:
        _b(r, Vector3(0.15, 5.0, 0.15),
            Vector3(x, 2.5, 8), rock)
        _b(r, Vector3(0.8, 0.15, 0.8),
            Vector3(x, 5.0, 8),
            _glow(Color(1.0, 0.82, 0.55), 2.0))


func _wildlife(c: Vector3) -> void:
    var r := _zone(c)

    var brown := _m("animal_brown", Color(0.48, 0.29, 0.17))
    var dark := _m("animal_dark", Color(0.16, 0.17, 0.18))
    var cream := _m("animal_cream", Color(0.82, 0.75, 0.62))
    var grey := _m("animal_grey", Color(0.48, 0.49, 0.46))
    var green := _m("animal_green", Color(0.2, 0.4, 0.18))

    # Small animal resting areas
    for i in range(3):
        var x := -8.0 + float(i) * 8.0
        _b(r, Vector3(3.0, 0.12, 2.5),
            Vector3(x, 0.15, 0), green)

        _b(r, Vector3(1.5, 0.8, 0.12),
            Vector3(x, 0.55, -1.1), brown)

    # Street dogs
    for i in range(5):
        var pos := r.position + Vector3(-9.0 + float(i) * 4.0, 0.0, 3.0)
        _b(r, Vector3(0.8, 0.55, 1.2),
            pos + Vector3(0, 0.45, 0), brown)

        _b(r, Vector3(0.35, 0.4, 0.4),
            pos + Vector3(0, 0.75, -0.65), brown)

        for lx in [-0.3, 0.3]:
            for lz in [-0.35, 0.35]:
                _b(r, Vector3(0.13, 0.35, 0.13),
                    pos + Vector3(lx, 0.2, lz), dark)

        _b(r, Vector3(0.12, 0.12, 0.7),
            pos + Vector3(0, 0.65, 0.85), brown)

    # Street cats
    for i in range(6):
        var pos := r.position + Vector3(-10.0 + float(i) * 4.0, 0.0, -5.0)

        _b(r, Vector3(0.65, 0.4, 0.85),
            pos + Vector3(0, 0.3, 0), grey)

        _b(r, Vector3(0.42, 0.4, 0.42),
            pos + Vector3(0, 0.55, -0.5), grey)

        for x in [-0.2, 0.2]:
            _b(r, Vector3(0.15, 0.3, 0.12),
                pos + Vector3(x, 0.15, 0.0), dark)

        _b(r, Vector3(0.1, 0.1, 0.65),
            pos + Vector3(0, 0.5, 0.65), grey)

    # Pigeons and birds
    for i in range(12):
        var x := -9.0 + float(i % 6) * 3.5
        var z := -9.0 + float(i / 6) * 12.0
        var pos := r.position + Vector3(x, 0.0, z)

        _b(r, Vector3(0.22, 0.22, 0.35),
            pos + Vector3(0, 0.3, 0), grey)

        _b(r, Vector3(0.08, 0.08, 0.35),
            pos + Vector3(0, 0.32, 0.2), dark)

    # Bird resting trees
    for x in [-10.0, 0.0, 10.0]:
        _b(r, Vector3(0.3, 3.5, 0.3),
            Vector3(x, 1.75, 8.0), brown)

        _b(r, Vector3(2.5, 2.0, 2.5),
            Vector3(x, 4.0, 8.0), green)

    # Water bowls for animals
    for x in [-7.0, 0.0, 7.0]:
        _b(r, Vector3(0.8, 0.12, 0.8),
            Vector3(x, 0.2, -8.0), grey)

    # Small shelters
    for x in [-8.0, 8.0]:
        _b(r, Vector3(2.0, 1.4, 1.8),
            Vector3(x, 0.8, 9.0), brown)

        _b(r, Vector3(2.3, 0.25, 2.0),
            Vector3(x, 1.65, 9.0), dark)


func _square(c: Vector3) -> void:
    var r := _zone(c)

    var stone := _m("square_stone", Color(0.65, 0.61, 0.53))
    var dark := _m("square_dark", Color(0.25, 0.26, 0.25))
    var water := _m("square_water", Color(0.08, 0.42, 0.65), 0.2)
    var white := _m("square_white", Color(0.9, 0.86, 0.75))
    var green := _m("square_green", Color(0.18, 0.38, 0.16))
    var wood := _m("square_wood", Color(0.38, 0.22, 0.13))

    # Public square
    _b(r, Vector3(28, 0.25, 25), Vector3(0, 0.12, 0), stone)

    # Decorative tiled sections
    for x in [-9.0, -3.0, 3.0, 9.0]:
        for z in [-8.0, 0.0, 8.0]:
            _b(r, Vector3(5.0, 0.035, 5.0),
                Vector3(x, 0.27, z), white)

    # Central fountain base
    _b(r, Vector3(7.0, 0.5, 7.0),
        Vector3(0, 0.55, 0), dark)

    # Fountain water
    _b(r, Vector3(5.8, 0.2, 5.8),
        Vector3(0, 0.9, 0), water)

    # Fountain central column
    _b(r, Vector3(0.8, 2.5, 0.8),
        Vector3(0, 2.2, 0), white)

    # Fountain upper basin
    _b(r, Vector3(3.0, 0.25, 3.0),
        Vector3(0, 3.5, 0), white)

    _b(r, Vector3(1.0, 0.5, 1.0),
        Vector3(0, 3.9, 0), water)

    # Benches
    for x in [-10.0, 10.0]:
        for z in [-5.0, 5.0]:
            _b(r, Vector3(2.2, 0.15, 0.65),
                Vector3(x, 0.7, z), wood)

            _b(r, Vector3(2.2, 0.8, 0.15),
                Vector3(x, 1.1, z + 0.25), wood)

    # Flower planters
    for x in [-11.0, 11.0]:
        for z in [-10.0, 10.0]:
            _b(r, Vector3(2.0, 0.5, 2.0),
                Vector3(x, 0.5, z), dark)

            _b(r, Vector3(1.6, 0.7, 1.6),
                Vector3(x, 1.0, z), green)

    # Palm tree trunks and crowns
    for x in [-12.0, 12.0]:
        _b(r, Vector3(0.5, 4.0, 0.5),
            Vector3(x, 2.0, 0), wood)

        for k in range(5):
            _b(r, Vector3(2.5, 0.15, 0.45),
                Vector3(x, 4.2, 0), green)

    # Rubbish bins
    for x in [-7.0, 7.0]:
        _b(r, Vector3(0.7, 1.0, 0.7),
            Vector3(x, 0.65, 0), dark)

        _b(r, Vector3(0.8, 0.12, 0.8),
            Vector3(x, 1.2, 0), white)

    # Decorative lamps
    for x in [-12.0, 12.0]:
        for z in [-8.0, 8.0]:
            _b(r, Vector3(0.16, 5.0, 0.16),
                Vector3(x, 2.5, z), dark)

            _b(r, Vector3(0.9, 0.2, 0.9),
                Vector3(x, 5.0, z),
                _glow(Color(1.0, 0.82, 0.55), 2.0))

    # Square visitors
    for i in range(8):
        var pos := r.position + Vector3(
            -9.0 + float(i) * 2.5, 0.0, 9.0
        )
        _walker(_person(pos, i % 4, 1.0), pos, 0.0, 0.0)

    # Square sign
    _lab(r, "PLACE CENTRALE\nساحة المدينة",
        Vector3(0, 5.5, -11.0), 64, 0.012,
        Color(1.0, 0.9, 0.65))


func _traffic_details(c: Vector3) -> void:
    var r := _zone(c)

    var asphalt := _m("traffic_asphalt", Color(0.23, 0.24, 0.24))
    var white := _m("traffic_white", Color(0.95, 0.95, 0.9))
    var yellow := _m("traffic_yellow", Color(0.95, 0.72, 0.08))
    var dark := _m("traffic_dark", Color(0.12, 0.13, 0.14))
    var red := _m("traffic_red", Color(0.9, 0.04, 0.03))
    var green := _m("traffic_green", Color(0.05, 0.75, 0.15))

    # Road junction surface
    _b(r, Vector3(26, 0.12, 22), Vector3(0, 0.06, 0), asphalt)

    # Zebra crossing on both sides
    for z in [-7.0, 7.0]:
        for i in range(9):
            var x := -8.0 + float(i) * 2.0
            _b(r, Vector3(1.0, 0.035, 3.0),
                Vector3(x, 0.14, z), white)

    # Road centre markings
    for i in range(7):
        _b(r, Vector3(2.0, 0.035, 0.14),
            Vector3(-6.0 + float(i) * 2.0, 0.14, 0), yellow)

    # Traffic light poles
    for x in [-11.0, 11.0]:
        for z in [-5.0, 5.0]:
            _b(r, Vector3(0.16, 4.5, 0.16),
                Vector3(x, 2.25, z), dark)

            _b(r, Vector3(0.7, 1.8, 0.5),
                Vector3(x, 4.2, z), dark)

            _b(r, Vector3(0.3, 0.3, 0.12),
                Vector3(x, 4.8, z - 0.28), _glow(red.color, 2.0))

            _b(r, Vector3(0.3, 0.3, 0.12),
                Vector3(x, 4.2, z - 0.28), yellow)

            _b(r, Vector3(0.3, 0.3, 0.12),
                Vector3(x, 3.6, z - 0.28), _glow(green.color, 2.0))

    # Stop lines
    for z in [-5.0, 5.0]:
        _b(r, Vector3(18, 0.06, 0.18),
            Vector3(0, 0.17, z), white)

    # Stop signs
    for x in [-12.0, 12.0]:
        _b(r, Vector3(0.14, 2.5, 0.14),
            Vector3(x, 1.25, -9.0), dark)

        _b(r, Vector3(1.1, 1.1, 0.16),
            Vector3(x, 2.7, -9.0), red)

        _lab(r, "STOP",
            Vector3(x, 2.7, -8.85), 48, 0.01, white.color)

    # Pedestrian waiting islands
    for x in [-10.0, 10.0]:
        _b(r, Vector3(2.0, 0.15, 2.0),
            Vector3(x, 0.2, 0), yellow)

    # Safety barriers
    for x in [-8.0, 8.0]:
        _b(r, Vector3(0.15, 1.0, 4.0),
            Vector3(x, 0.6, 9.0), dark)

    # Pedestrians waiting near crossings
    for i in range(6):
        var pos := r.position + Vector3(
            -7.0 + float(i) * 2.8, 0.0, -9.0
        )
        _walker(_person(pos, i % 4, 1.0), pos, 0.0, 0.0)


func _bus_station(c: Vector3) -> void:
    var r := _zone(c)

    var concrete := _m("bus_concrete", Color(0.38, 0.4, 0.4))
    var blue := _m("bus_blue", Color(0.04, 0.25, 0.65))
    var white := _m("bus_white", Color(0.9, 0.91, 0.88))
    var glass := _m("bus_glass", Color(0.12, 0.35, 0.42))
    var dark := _m("bus_dark", Color(0.08, 0.09, 0.1))
    var yellow := _m("bus_yellow", Color(0.95, 0.72, 0.08))

    # Main station platform
    _b(r, Vector3(30, 0.3, 20),
        Vector3(0, 0.15, 0), concrete)

    # Bus bays
    for i in range(3):
        var x := -9.0 + float(i) * 9.0

        _b(r, Vector3(7.5, 0.06, 0.18),
            Vector3(x, 0.34, -8.0), yellow)

        # Shelter roof
        _b(r, Vector3(7.0, 0.2, 2.8),
            Vector3(x, 3.5, 5.0), blue)

        # Shelter supports
        for sx in [-3.2, 3.2]:
            for sz in [-1.0, 1.0]:
                _b(r, Vector3(0.14, 3.3, 0.14),
                    Vector3(x + sx, 1.65, 5.0 + sz), dark)

        # Rear glass panels
        _b(r, Vector3(6.2, 2.1, 0.1),
            Vector3(x, 1.9, 6.2), glass)

        # Passenger bench
        _b(r, Vector3(3.0, 0.16, 0.55),
            Vector3(x, 0.9, 4.8), dark)

        _b(r, Vector3(3.0, 0.9, 0.14),
            Vector3(x, 1.35, 5.05), dark)

        # Route information sign
        _b(r, Vector3(0.15, 2.4, 0.15),
            Vector3(x - 3.4, 1.2, 3.0), dark)

        _b(r, Vector3(1.2, 1.0, 0.12),
            Vector3(x - 3.4, 2.5, 3.0), blue)

        _lab(r, "BUS",
            Vector3(x - 3.4, 2.5, 2.9), 42, 0.01, white.color)

    # Three parked city buses
    for i in range(3):
        var x := -9.0 + float(i) * 9.0

        _b(r, Vector3(6.5, 2.7, 3.0),
            Vector3(x, 1.55, -3.5), white)

        _b(r, Vector3(6.5, 0.55, 3.05),
            Vector3(x, 0.55, -3.5), blue)

        # Front windshield
        _b(r, Vector3(0.12, 1.5, 2.5),
            Vector3(x + 3.27, 2.0, -3.5), glass)

        # Side windows
        for j in range(4):
            _b(r, Vector3(1.0, 0.85, 0.08),
                Vector3(x - 2.0 + float(j) * 1.3,
                    2.15, -1.96), glass)

        # Wheels
        for wx in [-2.1, 2.1]:
            _b(r, Vector3(0.9, 0.9, 0.35),
                Vector3(x + wx, 0.55, -1.85), dark)

    # Station entrance
    _b(r, Vector3(10, 3.5, 0.2),
        Vector3(0, 2.0, 9.5), blue)

    _lab(r, "GASS CITY BUS STATION",
        Vector3(0, 4.0, 9.35), 60, 0.01, white.color)

    # Waiting passengers
    for i in range(8):
        var pos := r.position + Vector3(
            -10.0 + float(i) * 2.8,
            0.0,
            7.0
        )
        _walker(_person(pos, i % 4, 1.0), pos, 0.0, 0.0)

    # Station lighting
    for x in [-10.0, 0.0, 10.0]:
        _b(r, Vector3(0.12, 3.5, 0.12),
            Vector3(x, 1.75, 9.0), dark)
        _b(r, Vector3(0.8, 0.15, 0.8),
            Vector3(x, 3.5, 9.0), _glow(Color(1.0, 0.85, 0.55), 1.8))


func _transport_connections(c: Vector3) -> void:
    var r := _zone(c)

    var asphalt := _m("transport_asphalt", Color(0.22, 0.23, 0.24))
    var white := _m("transport_white", Color(0.94, 0.94, 0.88))
    var yellow := _m("transport_yellow", Color(0.95, 0.72, 0.06))
    var blue := _m("transport_blue", Color(0.04, 0.25, 0.7))
    var dark := _m("transport_dark", Color(0.09, 0.1, 0.11))

    # Road connection
    _b(r, Vector3(32, 0.12, 12),
        Vector3(0, 0.06, 0), asphalt)

    # Bus stopping bays
    for x in [-10.0, 0.0, 10.0]:
        _b(r, Vector3(7.0, 0.04, 0.18),
            Vector3(x, 0.14, -4.0), yellow)

        _b(r, Vector3(0.18, 0.04, 4.0),
            Vector3(x - 3.5, 0.14, -2.0), white)

        _b(r, Vector3(0.18, 0.04, 4.0),
            Vector3(x + 3.5, 0.14, -2.0), white)

    # Taxi pickup lane
    _b(r, Vector3(9.0, 0.1, 5.0),
        Vector3(0, 0.12, 5.0), blue)

    _lab(r, "TAXI PICKUP",
        Vector3(0, 0.3, 5.0), 42, 0.01, white.color)

    # Taxi waiting signs
    for x in [-5.0, 5.0]:
        _b(r, Vector3(0.14, 2.5, 0.14),
            Vector3(x, 1.25, 7.0), dark)

        _b(r, Vector3(1.5, 0.9, 0.14),
            Vector3(x, 2.6, 7.0), yellow)

        _lab(r, "TAXI",
            Vector3(x, 2.6, 6.88), 42, 0.01, dark.color)

    # Passenger drop-off area
    _b(r, Vector3(12.0, 0.1, 3.0),
        Vector3(0, 0.12, -7.0), yellow)

    _lab(r, "DROP OFF",
        Vector3(0, 0.3, -7.0), 40, 0.01, dark.color)

    # Directional arrows
    for x in [-10.0, 0.0, 10.0]:
        _b(r, Vector3(2.0, 0.04, 0.18),
            Vector3(x, 0.15, 1.0), white)

        _b(r, Vector3(0.18, 0.04, 0.8),
            Vector3(x + 0.8, 0.15, 1.4), white)

        _b(r, Vector3(0.18, 0.04, 0.8),
            Vector3(x + 1.2, 0.15, 1.4), white)



func _batch_box(xforms: Array, size: Vector3, material: Material) -> void:
    if xforms.is_empty():
        return
    var mesh := BoxMesh.new()
    mesh.size = size
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = xforms.size()
    for i in range(xforms.size()):
        mm.set_instance_transform(i, xforms[i] as Transform3D)
    var inst := MultiMeshInstance3D.new()
    inst.multimesh = mm
    inst.material_override = material
    inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world.add_child(inst)


func _flush() -> void:
    KenneyKit.scatter("res://assets/kenney/suburban/tree-large.glb", tree_big, world)
    KenneyKit.scatter("res://assets/kenney/suburban/tree-small.glb", tree_small, world)

    var wood := _m("batch_wood", Color(0.38, 0.22, 0.12))
    var dark_wood := _m("batch_dark_wood", Color(0.29, 0.17, 0.10))
    _batch_box(bench_seat, Vector3.ONE, wood)
    _batch_box(bench_back, Vector3.ONE, dark_wood)

    var table := _m("batch_cafe_table", Color(0.48, 0.29, 0.16))
    var chair := _m("batch_cafe_chair", Color(0.22, 0.25, 0.27))
    _batch_box(tbl_xf, Vector3(1.2, 0.12, 1.2), table)
    _batch_box(leg_xf, Vector3(0.12, 0.74, 0.12), dark_wood)
    _batch_box(chair_xf, Vector3(0.55, 0.12, 0.5), chair)


func _make_pets() -> void:
    if world == null or not world.has_method("_create_animal"):
        return
    # Keep animals inside the playground grounds, away from traffic.
    world.call("_create_animal", Vector3(-40.0, 0.0, 16.0), Color(0.48, 0.31, 0.19), "DOG")
    world.call("_create_animal", Vector3(-32.0, 0.0, 16.0), Color(0.72, 0.62, 0.48), "CAT")
