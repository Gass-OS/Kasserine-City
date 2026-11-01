extends Node

const KenneyKit = preload("res://scripts/kenney.gd")
const PITCH := 24.0
const WALK := 5.75
const SHOPS = [
    ["مقهى", "Café", Color(0.45, 0.25, 0.12), "cafe"],
    ["مقهى", "Café Ennakhil", Color(0.35, 0.2, 0.1), "cafe"],
    ["صيدلية", "Pharmacie", Color(0.08, 0.45, 0.25), "pharmacy"],
    ["بقالة", "Épicerie", Color(0.7, 0.3, 0.1), "shop"],
    ["مخبزة", "Boulangerie", Color(0.75, 0.55, 0.2), "shop"],
    ["مكتبة", "Librairie", Color(0.2, 0.3, 0.55), "shop"],
    ["حلاقة", "Salon de coiffure", Color(0.5, 0.15, 0.2), "shop"],
    ["محل", "Alimentation Générale", Color(0.15, 0.4, 0.5), "shop"],
    ["اتصالات", "Téléphonie", Color(0.55, 0.1, 0.45), "shop"],
]

var world: Node3D
var rng := RandomNumberGenerator.new()
var mats := {}
var count := 0

func _ready() -> void:
    for i in range(6):
        await get_tree().process_frame
    world = get_parent() as Node3D
    if world == null:
        return
    var rects = world.get("building_rects")
    if rects == null or rects.size() == 0:
        return
    rng.seed = 8080
    var k := 0
    for bx in range(-4, 4):
        for bz in range(-4, 4):
            if count >= 90:
                return
            _block(bx, bz, rects)
            k += 1
            if k % 4 == 0:
                await get_tree().process_frame

func _m(key: String, color: Color, rough := 0.8) -> StandardMaterial3D:
    if mats.has(key):
        return mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    mats[key] = m
    return m

func _block(bx: int, bz: int, rects: Array) -> void:
    var cx := float(bx) * PITCH + 12.0
    var cz := float(bz) * PITCH + 12.0
    var minx := 1.0e9
    var maxx := -1.0e9
    var minz := 1.0e9
    var maxz := -1.0e9
    var any := false
    for r in rects:
        var rc: Rect2 = r
        var ctr := rc.position + rc.size * 0.5
        if absf(ctr.x - cx) < 12.0 and absf(ctr.y - cz) < 12.0:
            any = true
            minx = minf(minx, rc.position.x)
            maxx = maxf(maxx, rc.position.x + rc.size.x)
            minz = minf(minz, rc.position.y)
            maxz = maxf(maxz, rc.position.y + rc.size.y)
    if not any:
        return
    var ox := float(bx) * PITCH
    var oz := float(bz) * PITCH
    var hi := PITCH - WALK
    var nd := (minz - oz) - 0.4 - WALK
    var sd := hi - ((maxz - oz) + 0.4)
    var wd := (minx - ox) - 0.4 - WALK
    var ed := hi - ((maxx - ox) + 0.4)
    if nd >= 3.2:
        _row(ox + WALK, ox + hi, oz + WALK, oz + WALK + nd, 0)
    if sd >= 3.2:
        _row(ox + WALK, ox + hi, oz + hi - sd, oz + hi, 1)
    if wd >= 3.2:
        _row(ox + WALK, ox + WALK + wd, minz, maxz, 2)
    if ed >= 3.2:
        _row(ox + hi - ed, ox + hi, minz, maxz, 3)

func _row(x0: float, x1: float, z0: float, z1: float, side: int) -> void:
    var along_x := side < 2
    var length := (x1 - x0) if along_x else (z1 - z0)
    var depth := minf((z1 - z0) if along_x else (x1 - x0), 5.8)
    var n := maxi(1, int(length / 6.0))
    var w := minf((length - float(n - 1) * 0.3) / float(n), 7.5)
    if w < 3.0:
        return
    var yaws := [PI, 0.0, -PI * 0.5, PI * 0.5]
    for k in range(n):
        var off := (float(k) + 0.5) * (length / float(n))
        var cx: float
        var cz: float
        if along_x:
            cx = x0 + off
            cz = (z0 + depth * 0.5) if side == 0 else (z1 - depth * 0.5)
        else:
            cz = z0 + off
            cx = (x0 + depth * 0.5) if side == 2 else (x1 - depth * 0.5)
        _shop(cx, cz, w, depth, rng.randf_range(4.2, 7.4), float(yaws[side]), SHOPS[rng.randi() % SHOPS.size()])
        count += 1

func _bx(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
    var bm := BoxMesh.new()
    bm.size = size
    var mi := MeshInstance3D.new()
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    mi.rotation_degrees = rot
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.visibility_range_end = 140.0
    parent.add_child(mi)

func _shop(cx: float, cz: float, w: float, d: float, h: float, yaw: float, def: Array) -> void:
    var holder := Node3D.new()
    holder.position = Vector3(cx, 0.26, cz)
    holder.rotation.y = yaw
    world.add_child(holder)
    var tones := [Color(0.88, 0.84, 0.76), Color(0.84, 0.76, 0.62), Color(0.8, 0.7, 0.55), Color(0.9, 0.88, 0.82)]
    var tone: Color = tones[rng.randi() % tones.size()]
    var accent: Color = def[2]
    var kind: String = def[3]
    var fz := d * 0.5
    world.call("_box", holder, Vector3(w, h, d), Vector3(0, h * 0.5, 0), tone, true)
    _bx(holder, Vector3(w + 0.2, 0.35, d + 0.2), Vector3(0, h + 0.17, 0), _m("ledge" + tone.to_html(), tone.darkened(0.12)))
    var glow = world.call("_glow_mat", Color(1.0, 0.85, 0.55), 2.0)
    _bx(holder, Vector3(w * 0.5, 1.6, 0.1), Vector3(-w * 0.15, 1.35, fz + 0.05), glow)
    _bx(holder, Vector3(1.0, 2.1, 0.1), Vector3(w * 0.28, 1.05, fz + 0.05), _m("door", Color(0.3, 0.17, 0.08)))
    _bx(holder, Vector3(w * 0.92, 0.08, 1.15), Vector3(0, 2.55, fz + 0.55), _m("aw" + accent.to_html(), accent), Vector3(14, 0, 0))
    _bx(holder, Vector3(w * 0.86, 0.6, 0.12), Vector3(0, 3.1, fz + 0.07), _m("sign", Color(0.08, 0.08, 0.1)))
    var l := Label3D.new()
    var fr: String = def[1]
    l.text = String(def[0]) + "\n" + fr
    l.font_size = 56
    l.pixel_size = 0.0065 if fr.length() <= 12 else 0.0046
    l.outline_size = 8
    l.modulate = Color(1.0, 0.95, 0.8)
    l.position = Vector3(0, 3.1, fz + 0.15)
    holder.add_child(l)
    if h >= 5.8:
        var glass = world.call("_glass_mat")
        for s in [-1.0, 1.0]:
            _bx(holder, Vector3(0.9, 1.3, 0.08), Vector3(s * w * 0.25, h - 1.4, fz + 0.04), glass)
    if kind == "pharmacy":
        var gg = world.call("_glow_mat", Color(0.1, 1.0, 0.4), 3.0)
        _bx(holder, Vector3(0.56, 0.16, 0.08), Vector3(w * 0.36, 3.1, fz + 0.16), gg)
        _bx(holder, Vector3(0.16, 0.56, 0.08), Vector3(w * 0.36, 3.1, fz + 0.16), gg)
    if kind == "cafe":
        var wood := _m("wood", Color(0.35, 0.22, 0.12))
        # Keep outdoor seating close to the shop frontage so chairs
        # remain inside the sidewalk clearance instead of the road.
        var cafe_front_offset := minf(0.75, maxf(0.45, d * 0.12))
        for tx in [-w * 0.22, w * 0.22]:
            var cm := CylinderMesh.new()
            cm.top_radius = 0.38
            cm.bottom_radius = 0.38
            cm.height = 0.05
            cm.radial_segments = 12
            var top := MeshInstance3D.new()
            top.mesh = cm
            top.material_override = wood
            top.position = Vector3(tx, 0.72, fz + cafe_front_offset)
            holder.add_child(top)
            _bx(holder, Vector3(0.08, 0.7, 0.08), Vector3(tx, 0.36, fz + cafe_front_offset), wood)
            for cs in [-0.65, 0.65]:
                _bx(holder, Vector3(0.4, 0.06, 0.4), Vector3(tx + cs, 0.46, fz + cafe_front_offset), wood)
                _bx(holder, Vector3(0.4, 0.45, 0.05), Vector3(tx + cs, 0.7, fz + cafe_front_offset + signf(cs) * 0.2), wood)
        _parasol(holder, Vector3(0.0, 0.0, fz + cafe_front_offset), w)

func _parasol(parent: Node3D, pos: Vector3, w: float) -> void:
    var path := "res://assets/kenney/commercial/detail-parasol-a.glb"
    var ps := KenneyKit._scene(path)
    if ps == null:
        return
    var inst := ps.instantiate() as Node3D
    if inst == null:
        return
    var a := KenneyKit._aabb(inst)
    if a.size.x < 0.01 or a.size.y < 0.01:
        inst.free()
        return
    var k := minf(w * 0.7, 2.6) / maxf(a.size.x, a.size.z)
    var b := Basis.from_scale(Vector3.ONE * k)
    var c := a.position + a.size * 0.5
    inst.transform = Transform3D(b, pos - (b * Vector3(c.x, a.position.y, c.z)))
    parent.add_child(inst)
