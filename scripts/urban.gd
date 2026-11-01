extends Node

const PITCH := 24.0
const CURB := 3.3
const RUN := 0.55
const RISE := 0.31
const TOP := 0.26
const GROUND_TOP := -0.05
const BMIN := -4
const BMAX := 3

var world: Node3D
var citizens

func _ready() -> void:
    for i in range(4):
        await get_tree().process_frame
    world = get_parent() as Node3D
    if world == null:
        return
    _build()
    _nudge_cars()
    citizens = world.get("citizens")

func _paving() -> ImageTexture:
    var size := 128
    var tile := 32
    var img := Image.create(size, size, true, Image.FORMAT_RGB8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 55
    for ty in range(4):
        for tx in range(4):
            var tone := rng.randf_range(0.6, 0.8)
            var warm := rng.randf_range(0.92, 1.0)
            for y in range(tile):
                for x in range(tile):
                    var n := rng.randf_range(-0.03, 0.03)
                    var c := Color(tone + n, (tone + n) * 0.97, (tone + n) * warm * 0.94)
                    if x < 1 or y < 1:
                        c = Color(0.3, 0.29, 0.27)
                    img.set_pixel(tx * tile + x, ty * tile + y, c)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
    st.add_vertex(a)
    st.add_vertex(b)
    st.add_vertex(c)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    _tri(st, a, b, c)
    _tri(st, a, c, d)

func _wedge_mesh() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var a0 := Vector3(0.0, 0.0, -0.5)
    var b0 := Vector3(RUN, 0.0, -0.5)
    var c0 := Vector3(RUN, RISE, -0.5)
    var a1 := Vector3(0.0, 0.0, 0.5)
    var b1 := Vector3(RUN, 0.0, 0.5)
    var c1 := Vector3(RUN, RISE, 0.5)
    _quad(st, a0, a1, c1, c0)
    _quad(st, b0, c0, c1, b1)
    _quad(st, a0, b0, b1, a1)
    _tri(st, a0, c0, b0)
    _tri(st, a1, b1, c1)
    st.generate_normals()
    return st.commit()

func _build() -> void:
    var span := PITCH - 2.0 * (CURB + RUN)
    var n := BMAX - BMIN + 1
    var slab_mesh := BoxMesh.new()
    slab_mesh.size = Vector3.ONE
    var smm := MultiMesh.new()
    smm.transform_format = MultiMesh.TRANSFORM_3D
    smm.use_colors = true
    smm.mesh = slab_mesh
    smm.instance_count = n * n
    var wmm := MultiMesh.new()
    wmm.transform_format = MultiMesh.TRANSFORM_3D
    wmm.mesh = _wedge_mesh()
    wmm.instance_count = n * n * 4
    var body := StaticBody3D.new()
    body.name = "UrbanPlatforms"
    var hl := span * 0.5
    var wedge_shape := ConvexPolygonShape3D.new()
    wedge_shape.points = PackedVector3Array([
        Vector3(0.0, 0.0, -hl), Vector3(RUN, 0.0, -hl), Vector3(RUN, RISE, -hl),
        Vector3(0.0, 0.0, hl), Vector3(RUN, 0.0, hl), Vector3(RUN, RISE, hl)])
    var rng := RandomNumberGenerator.new()
    rng.seed = 1212
    var si := 0
    var wi := 0
    var inset := PITCH * 0.5 - CURB
    for bx in range(BMIN, BMAX + 1):
        for bz in range(BMIN, BMAX + 1):
            var cx := float(bx) * PITCH + PITCH * 0.5
            var cz := float(bz) * PITCH + PITCH * 0.5
            var sc := Vector3(cx, GROUND_TOP + RISE * 0.5, cz)
            smm.set_instance_transform(si, Transform3D(Basis.from_scale(Vector3(span, RISE, span)), sc))
            var tone := rng.randf_range(0.85, 1.05)
            smm.set_instance_color(si, Color(tone, tone, tone))
            si += 1
            var cs := CollisionShape3D.new()
            var box := BoxShape3D.new()
            box.size = Vector3(span, RISE, span)
            cs.shape = box
            cs.position = sc
            body.add_child(cs)
            var specs := [
                [Vector3(cx - inset, GROUND_TOP, cz), 0.0],
                [Vector3(cx + inset, GROUND_TOP, cz), PI],
                [Vector3(cx, GROUND_TOP, cz - inset), -PI * 0.5],
                [Vector3(cx, GROUND_TOP, cz + inset), PI * 0.5],
            ]
            for sp in specs:
                var org: Vector3 = sp[0]
                var yaw: float = sp[1]
                var rb := Basis(Vector3.UP, yaw)
                wmm.set_instance_transform(wi, Transform3D(rb * Basis.from_scale(Vector3(1.0, 1.0, span)), org))
                wi += 1
                var wc := CollisionShape3D.new()
                wc.shape = wedge_shape
                wc.transform = Transform3D(rb, org)
                body.add_child(wc)
    var paving_mat := StandardMaterial3D.new()
    paving_mat.albedo_texture = _paving()
    paving_mat.vertex_color_use_as_albedo = true
    paving_mat.roughness = 0.92
    paving_mat.uv1_triplanar = true
    paving_mat.uv1_world_triplanar = true
    paving_mat.uv1_scale = Vector3.ONE * 0.5
    var curb_mat := StandardMaterial3D.new()
    curb_mat.albedo_color = Color(0.78, 0.77, 0.74)
    curb_mat.roughness = 0.9
    curb_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var smi := MultiMeshInstance3D.new()
    smi.multimesh = smm
    smi.material_override = paving_mat
    smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var wmi := MultiMeshInstance3D.new()
    wmi.multimesh = wmm
    wmi.material_override = curb_mat
    wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world.add_child(smi)
    world.add_child(wmi)
    world.add_child(body)

func _nudge_cars() -> void:
    var tcars = world.get("traffic_cars")
    for ch in world.get_children():
        if not (ch is Node3D) or not String(ch.name).begins_with("ParkedCar"):
            continue
        if tcars != null and tcars.has(ch):
            continue
        var c := ch as Node3D
        if absf(cos(c.rotation.y)) > 0.7:
            var off := c.position.x - PITCH * roundf(c.position.x / PITCH)
            if absf(off) > 2.2 and absf(off) < 3.8:
                c.position.x -= signf(off) * 0.75
        else:
            var offz := c.position.z - PITCH * roundf(c.position.z / PITCH)
            if absf(offz) > 2.2 and absf(offz) < 3.8:
                c.position.z -= signf(offz) * 0.75

func _surface(x: float, z: float) -> float:
    if absf(x) > 96.0 or absf(z) > 96.0:
        return 0.0
    var mx := fposmod(x, PITCH)
    var mz := fposmod(z, PITCH)
    var d := minf(minf(mx, PITCH - mx), minf(mz, PITCH - mz))
    var t := clampf((d - CURB) / RUN, 0.0, 1.0)
    return TOP * t

func _process(_delta: float) -> void:
    if world == null:
        return
    if citizens != null:
        for c in citizens:
            if is_instance_valid(c) and c.visible:
                c.position.y = _surface(c.position.x, c.position.z)
    var s := world.get_node_or_null("Suspect") as Node3D
    if s != null:
        s.position.y = _surface(s.position.x, s.position.z)
