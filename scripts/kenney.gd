extends RefCounted

const CAR_FLIP := true
const CARS = ["sedan", "hatchback-sports", "suv", "taxi", "van", "sedan-sports", "suv-luxury", "truck", "delivery", "police", "ambulance"]
const CAR_LEN = {"truck": 6.2, "delivery": 5.8, "van": 4.9, "ambulance": 5.2, "suv": 4.7, "suv-luxury": 4.8}
const MID = ["building-a", "building-b", "building-c", "building-d", "building-e", "building-f", "building-g", "building-h", "building-i", "building-j", "building-k", "building-l", "building-m", "building-n"]
const TOWERS = ["building-skyscraper-a", "building-skyscraper-b", "building-skyscraper-c", "building-skyscraper-d", "building-skyscraper-e"]

static var _cache := {}

static func _scene(path: String) -> PackedScene:
    if _cache.has(path):
        return _cache[path]
    var ps: PackedScene = null
    if ResourceLoader.exists(path):
        ps = load(path) as PackedScene
    _cache[path] = ps
    return ps

static func _collect(n: Node, out: Array) -> void:
    if n is MeshInstance3D:
        out.append(n)
    for c in n.get_children():
        _collect(c, out)

static func _rel_xform(n: Node3D, root: Node3D) -> Transform3D:
    var xf := Transform3D.IDENTITY
    var cur: Node = n
    while cur != null and cur != root:
        if cur is Node3D:
            xf = (cur as Node3D).transform * xf
        cur = cur.get_parent()
    return xf

static func _aabb(root: Node3D) -> AABB:
    var meshes: Array = []
    _collect(root, meshes)
    var box := AABB()
    var first := true
    for mi in meshes:
        var m := mi as MeshInstance3D
        if m.mesh == null:
            continue
        var a := _rel_xform(m, root) * m.mesh.get_aabb()
        if first:
            box = a
            first = false
        else:
            box = box.merge(a)
    return box

static func tint(n: Node, color: Color) -> void:
    var meshes: Array = []
    _collect(n, meshes)
    for mi in meshes:
        var m := mi as MeshInstance3D
        if m.mesh == null:
            continue
        for i in range(m.mesh.get_surface_count()):
            var mat := m.get_active_material(i)
            if mat is StandardMaterial3D:
                var d := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
                d.albedo_color = color
                m.set_surface_override_material(i, d)

static func car(index: int) -> Variant:
    var model_name: String = CARS[posmod(index, CARS.size())]
    return car_named(model_name)

static func car_named(model_name: String) -> Variant:
    if not CARS.has(model_name):
        return null
    var ps := _scene("res://assets/kenney/cars/%s.glb" % model_name)
    if ps == null:
        return null
    var inst := ps.instantiate() as Node3D
    if inst == null:
        return null
    var a := _aabb(inst)
    if a.size.x < 0.01 or a.size.z < 0.01:
        inst.free()
        return null
    var rotated := a.size.x > a.size.z
    var length := maxf(a.size.x, a.size.z)
    var target: float = CAR_LEN.get(model_name, 4.4)
    var k := target / length
    var yaw := (PI * 0.5 if rotated else 0.0) + (PI if CAR_FLIP else 0.0)
    var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * k)
    var c := a.position + a.size * 0.5
    inst.transform = Transform3D(b, -(b * Vector3(c.x, a.position.y, c.z)))
    var holder := Node3D.new()
    holder.name = "CarModel"
    holder.add_child(inst)
    var dims := Vector3(a.size.z if rotated else a.size.x, a.size.y, a.size.x if rotated else a.size.z) * k
    return {"node": holder, "size": dims}

static func building(cx: float, cz: float, w: float, d: float, h: float, seed_val: int, color: Color) -> Node3D:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    var pool: Array = TOWERS if h > 17.0 else MID
    var model_name: String = pool[rng.randi() % pool.size()]
    var ps := _scene("res://assets/kenney/commercial/%s.glb" % model_name)
    if ps == null:
        return null
    var inst := ps.instantiate() as Node3D
    if inst == null:
        return null
    var a := _aabb(inst)
    if a.size.x < 0.01 or a.size.y < 0.01 or a.size.z < 0.01:
        inst.free()
        return null
    var fit := minf(w, d) / maxf(a.size.x, a.size.z)
    if a.size.y * fit > 42.0:
        fit = 42.0 / a.size.y
    var holder := Node3D.new()
    holder.name = "KenneyBuilding"
    holder.position = Vector3(cx, 0.0, cz)
    holder.rotation.y = float(rng.randi() % 4) * PI * 0.5
    holder.set_meta("building_local_dimensions", a.size * fit)
    holder.set_meta("building_yaw", holder.rotation.y)
    var b := Basis.from_scale(Vector3.ONE * fit)
    var c := a.position + a.size * 0.5
    inst.transform = Transform3D(b, -(b * Vector3(c.x, a.position.y, c.z)))
    holder.add_child(inst)
    tint(inst, color)
    var body := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = a.size * fit
    shape.shape = box
    shape.position = Vector3(0.0, a.size.y * fit * 0.5, 0.0)
    body.add_child(shape)
    holder.add_child(body)
    return holder

static func height_scale(path: String, target: float) -> float:
    var ps := _scene(path)
    if ps == null:
        return 0.0
    var inst := ps.instantiate() as Node3D
    if inst == null:
        return 0.0
    var a := _aabb(inst)
    inst.free()
    if a.size.y < 0.01:
        return 0.0
    return target / a.size.y

static func scatter(path: String, xforms: Array, parent: Node, shadows := false) -> int:
    var ps := _scene(path)
    if ps == null or xforms.is_empty():
        return 0
    var inst := ps.instantiate() as Node3D
    if inst == null:
        return 0
    var meshes: Array = []
    _collect(inst, meshes)
    var made := 0
    for mi in meshes:
        var m := mi as MeshInstance3D
        if m.mesh == null:
            continue
        var rel := _rel_xform(m, inst)
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = m.mesh
        mm.instance_count = xforms.size()
        for i in range(xforms.size()):
            mm.set_instance_transform(i, (xforms[i] as Transform3D) * rel)
        var mmi := MultiMeshInstance3D.new()
        mmi.multimesh = mm
        if not shadows:
            mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parent.add_child(mmi)
        made += 1
    inst.free()
    return made
