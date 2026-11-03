extends Node

const PITCH := 24.0
const LANE := 1.65
const CH := 1.4

var world: Node3D
var player: Node3D
var drive
var fleet: Array = []
var cache: Array = []
var cache_t := 0.0
var snapshot := {}
var check_t := 8.0
var takeover := false

func _ready() -> void:
    for i in range(10):
        await get_tree().process_frame
    world = get_parent() as Node3D
    if world == null:
        return
    player = world.get_node_or_null("Player") as Node3D
    drive = world.get_node_or_null("Drive")
    _tidy_parked()
    _spawn_fleet()
    var tc = world.get("traffic_cars")
    if tc != null:
        for c in tc:
            if is_instance_valid(c):
                snapshot[c] = c.position
                c.add_to_group("ambient_vehicle")

func _mat(color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    m.metallic = metal
    return m

func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.rotation_degrees = rot
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)

func _bx(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
    var b := BoxMesh.new()
    b.size = size
    _add(parent, b, pos, mat, rot)

func _cy(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
    var c := CylinderMesh.new()
    c.top_radius = r
    c.bottom_radius = r
    c.height = h
    c.radial_segments = 10
    _add(parent, c, pos, mat, rot)

func _sp(parent: Node3D, r: float, pos: Vector3, mat: Material) -> void:
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    s.radial_segments = 10
    s.rings = 6
    _add(parent, s, pos, mat)

func _scooter() -> Node3D:
    var root := AnimatableBody3D.new()
    root.name = "Scooter"
    var paint := Color.from_hsv(randf(), 0.65, 0.8)
    var body := _mat(paint, 0.35, 0.4)
    var dark := _mat(Color(0.05, 0.05, 0.06), 0.8)
    var tones := [Color(0.72, 0.52, 0.38), Color(0.55, 0.38, 0.27), Color(0.8, 0.62, 0.48)]
    var skin := _mat(tones[randi() % tones.size()], 0.8)
    var shirt := _mat(Color.from_hsv(randf(), 0.5, 0.75), 0.9)
    var pants := _mat(Color(0.12, 0.15, 0.25), 0.9)
    var helmet := _mat(Color.from_hsv(randf(), 0.2, 0.95), 0.4, 0.2)
    for z in [-0.65, 0.65]:
        _cy(root, 0.28, 0.12, Vector3(0, 0.28, z), dark, Vector3(0, 0, 90))
    _bx(root, Vector3(0.3, 0.12, 1.15), Vector3(0, 0.42, 0.05), body)
    _bx(root, Vector3(0.32, 0.6, 0.1), Vector3(0, 0.75, -0.5), body, Vector3(-12, 0, 0))
    _bx(root, Vector3(0.3, 0.1, 0.55), Vector3(0, 0.68, 0.38), dark)
    _bx(root, Vector3(0.6, 0.05, 0.05), Vector3(0, 1.08, -0.52), dark)
    _bx(root, Vector3(0.14, 0.45, 0.2), Vector3(-0.13, 0.85, 0.0), pants)
    _bx(root, Vector3(0.14, 0.45, 0.2), Vector3(0.13, 0.85, 0.0), pants)
    _bx(root, Vector3(0.36, 0.52, 0.22), Vector3(0, 1.2, 0.25), shirt, Vector3(8, 0, 0))
    _sp(root, 0.13, Vector3(0, 1.62, 0.2), skin)
    _sp(root, 0.15, Vector3(0, 1.67, 0.2), helmet)
    var hl = world.call("_glow_mat", Color(1.0, 0.95, 0.8), 4.0)
    var tl = world.call("_glow_mat", Color(1.0, 0.1, 0.1), 2.5)
    _bx(root, Vector3(0.16, 0.12, 0.05), Vector3(0, 0.98, -0.6), hl)
    _bx(root, Vector3(0.16, 0.1, 0.05), Vector3(0, 0.6, 0.68), tl)
    # Keep the collider attached to the moving physics body.
    var cs := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(0.7, 1.5, 1.9)
    cs.shape = box
    cs.position = Vector3(0, 0.8, 0)
    root.add_child(cs)
    root.set_meta("scooter", true)
    return root

func _loop_route(bx: int, bz: int) -> Array:
    var xw := float(bx) * PITCH
    var xe := xw + PITCH
    var zn := float(bz) * PITCH
    var zs := zn + PITCH
    return [
        Vector3(xw + LANE + CH, 0.06, zn + LANE),
        Vector3(xe - LANE - CH, 0.06, zn + LANE),
        Vector3(xe - LANE, 0.06, zn + LANE + CH),
        Vector3(xe - LANE, 0.06, zs - LANE - CH),
        Vector3(xe - LANE - CH, 0.06, zs - LANE),
        Vector3(xw + LANE + CH, 0.06, zs - LANE),
        Vector3(xw + LANE, 0.06, zs - LANE - CH),
        Vector3(xw + LANE, 0.06, zn + LANE + CH),
    ]

func _spawn_fleet() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 31337
    var blocks: Array = []
    for bx in range(-4, 4):
        for bz in range(-4, 4):
            blocks.append(Vector2i(bx, bz))
    blocks.shuffle()
    var count := 0
    for b in blocks:
        if count >= 46:
            break
        var route := _loop_route(b.x, b.y)
        var is_scooter := rng.randf() < 0.32
        var node: Node3D = null
        if is_scooter:
            node = _scooter()
            world.add_child(node)
        else:
            node = world.call("_create_car", route[0], Color(rng.randf(), rng.randf(), rng.randf()), 0.0, true) as Node3D
        if node == null:
            continue
        var idx := rng.randi() % route.size()
        node.position = route[idx]
        node.add_to_group("ambient_vehicle")
        var base := rng.randf_range(6.0, 9.0) if is_scooter else rng.randf_range(5.0, 8.0)
        fleet.append({"node": node, "route": route, "i": (idx + 1) % route.size(), "base": base, "cur": 0.0, "chk": rng.randf() * 0.2, "stuck": 0.0, "free": 0.0, "brake": false})
        count += 1

func _tidy_parked() -> void:
    var tc = world.get("traffic_cars")
    var kept: Array = []
    for ch in world.get_children():
        if not (ch is Node3D) or not String(ch.name).begins_with("ParkedCar"):
            continue
        if tc != null and tc.has(ch):
            continue
        var c := ch as Node3D
        var ns := absf(cos(c.rotation.y)) > 0.7
        var lat_axis := c.position.x if ns else c.position.z
        var line := roundf(lat_axis / PITCH)
        var off := lat_axis - line * PITCH
        if absf(c.position.x) > 100.0 or absf(c.position.z) > 100.0 or absf(off) > 4.5:
            continue
        var want := 1.0 if posmod(int(line), 2) == 0 else -1.0
        if off * want <= 0.0:
            c.queue_free()
            continue
        var lat := line * PITCH + want * 2.3
        if ns:
            c.position.x = lat
        else:
            c.position.z = lat
        c.position.y = 0.06
        kept.append(c)
    _bays(kept)

func _bays(kept: Array) -> void:
    var xf: Array = []
    for c in kept:
        if not is_instance_valid(c):
            continue
        var ns := absf(cos(c.rotation.y)) > 0.7
        var lat_axis := c.position.x if ns else c.position.z
        var line := roundf(lat_axis / PITCH)
        var off := lat_axis - line * PITCH
        var want := 1.0 if off > 0.0 else -1.0
        var inner := line * PITCH + want * 1.15
        var lat := line * PITCH + want * 2.3
        var al := c.position.z if ns else c.position.x
        if ns:
            xf.append(Transform3D(Basis.from_scale(Vector3(0.1, 1.0, 5.4)), Vector3(inner, 0.083, al)))
            xf.append(Transform3D(Basis.from_scale(Vector3(2.3, 1.0, 0.1)), Vector3(lat, 0.083, al - 2.75)))
            xf.append(Transform3D(Basis.from_scale(Vector3(2.3, 1.0, 0.1)), Vector3(lat, 0.083, al + 2.75)))
        else:
            xf.append(Transform3D(Basis.from_scale(Vector3(5.4, 1.0, 0.1)), Vector3(al, 0.083, inner)))
            xf.append(Transform3D(Basis.from_scale(Vector3(0.1, 1.0, 2.3)), Vector3(al - 2.75, 0.083, lat)))
            xf.append(Transform3D(Basis.from_scale(Vector3(0.1, 1.0, 2.3)), Vector3(al + 2.75, 0.083, lat)))
    if xf.is_empty():
        return
    var bm := BoxMesh.new()
    bm.size = Vector3(1.0, 0.012, 1.0)
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = bm
    mm.instance_count = xf.size()
    for i in range(xf.size()):
        mm.set_instance_transform(i, xf[i])
    var mi := MultiMeshInstance3D.new()
    mi.multimesh = mm
    mi.material_override = _mat(Color(0.92, 0.92, 0.9), 0.8)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world.add_child(mi)

func _refresh() -> void:
    cache.clear()
    for f in fleet:
        if is_instance_valid(f["node"]):
            cache.append([f["node"], (f["node"] as Node3D).global_position])
    var tc = world.get("traffic_cars")
    if tc != null:
        for c in tc:
            if is_instance_valid(c):
                cache.append([c, c.global_position])
    if player != null:
        cache.append([player, player.global_position])
    if drive != null:
        var pc = drive.get("car")
        if pc != null and is_instance_valid(pc):
            cache.append([pc, pc.global_position])

func _blocked(me: Node3D, pos: Vector3, dir: Vector3) -> bool:
    for e in cache:
        if e[0] == me:
            continue
        var to: Vector3 = (e[1] as Vector3) - pos
        to.y = 0.0
        var along := to.dot(dir)
        if along < 0.5 or along > 5.5:
            continue
        if (to - dir * along).length() < 1.5:
            return true
    return false

func _siren_factor(p: Vector3) -> float:
    if drive == null or not bool(drive.get("siren_on")) or not bool(drive.get("driving")):
        return 1.0
    var pc = drive.get("car")
    if pc == null:
        return 1.0
    return 0.25 if p.distance_to(pc.global_position) < 24.0 else 1.0

func _process(delta: float) -> void:
    if world == null:
        return
    cache_t += delta
    if cache_t > 0.1:
        cache_t = 0.0
        _refresh()
    if check_t > 0.0:
        check_t -= delta
        if check_t <= 0.0:
            _check_frozen()
    if takeover:
        _drive_old(delta)
    _drive_fleet(delta)

func _check_frozen() -> void:
    var tc = world.get("traffic_cars")
    if tc == null or tc.size() == 0:
        return
    var moved := 0
    for c in tc:
        if is_instance_valid(c) and snapshot.has(c) and (c.position - snapshot[c]).length() > 0.5:
            moved += 1
    if moved == 0:
        takeover = true

func _drive_old(delta: float) -> void:
    var cars = world.get("traffic_cars")
    var paths = world.get("traffic_paths")
    var tgt = world.get("traffic_targets")
    var spd = world.get("traffic_speeds")
    if cars == null or paths == null or tgt == null or spd == null:
        return
    for i in range(cars.size()):
        var car: Node3D = cars[i]
        if not is_instance_valid(car):
            continue
        var route: Array = paths[i]
        if route.size() < 2:
            continue
        var target: Vector3 = route[tgt[i]]
        var diff := target - car.position
        diff.y = 0.0
        var dist := diff.length()
        if dist < 0.65:
            tgt[i] = (tgt[i] + 1) % route.size()
            continue
        var dir := diff / dist
        var s := maxf(float(spd[i]), 4.0) * _siren_factor(car.global_position)
        if _blocked(car, car.global_position, dir):
            s = 0.0
        car.position += dir * minf(s * delta, dist)
        car.rotation.y = atan2(-dir.x, -dir.z)

func _drive_fleet(delta: float) -> void:
    for f in fleet:
        var n: Node3D = f["node"]
        if not is_instance_valid(n):
            continue
        f["chk"] = float(f["chk"]) - delta
        var route: Array = f["route"]
        var target: Vector3 = route[int(f["i"])]
        var diff := target - n.position
        diff.y = 0.0
        var dist := diff.length()
        if dist < 0.6:
            f["i"] = (int(f["i"]) + 1) % route.size()
            continue
        var dir := diff / dist
        if float(f["chk"]) <= 0.0:
            f["chk"] = 0.12
            var blk := _blocked(n, n.global_position, dir)
            if blk:
                f["stuck"] = float(f["stuck"]) + 0.12
                if float(f["stuck"]) > 2.6:
                    f["free"] = 1.6
                    f["stuck"] = 0.0
            else:
                f["stuck"] = maxf(0.0, float(f["stuck"]) - 0.06)
            f["brake"] = blk and float(f["free"]) <= 0.0
        f["free"] = maxf(0.0, float(f["free"]) - delta)
        var want := float(f["base"]) * _siren_factor(n.global_position)
        if bool(f["brake"]):
            want = 0.0
        var cur := float(f["cur"])
        f["cur"] = move_toward(cur, want, (12.0 if want < cur else 4.0) * delta)
        n.position += dir * minf(float(f["cur"]) * delta, dist)
        n.rotation.y = lerp_angle(n.rotation.y, atan2(-dir.x, -dir.z), 7.0 * delta)
