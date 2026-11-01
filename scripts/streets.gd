extends Node

const PITCH := 24.0
const Y := 0.085
const TOP := 0.26
const SEGS = {
    0: [1, 1, 1, 0, 1, 1, 1],
    3: [1, 0, 1, 1, 0, 1, 1],
    5: [1, 1, 0, 1, 0, 1, 1],
}

var world: Node3D

func _ready() -> void:
    for i in range(5):
        await get_tree().process_frame
    world = get_parent() as Node3D
    if world == null:
        return
    _markings()
    _signs()
    _bumps()
    _decals()

func _flat_mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.8
    return m

func _spawn_mm(mesh: Mesh, xforms: Array, mat: Material) -> void:
    if xforms.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = xforms.size()
    for i in range(xforms.size()):
        mm.set_instance_transform(i, xforms[i])
    var mi := MultiMeshInstance3D.new()
    mi.multimesh = mm
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world.add_child(mi)

func _markings() -> void:
    var line := BoxMesh.new()
    line.size = Vector3(1.0, 0.012, 1.0)
    var all: Array = []
    for i in range(-4, 5):
        var p := float(i) * PITCH
        for k in range(-4, 4):
            var u := float(k) * PITCH + 12.0
            for side in [-1.0, 1.0]:
                all.append(Transform3D(Basis.from_scale(Vector3(0.12, 1.0, 8.4)), Vector3(p + side * 3.05, Y, u)))
                all.append(Transform3D(Basis.from_scale(Vector3(8.4, 1.0, 0.12)), Vector3(u, Y, p + side * 3.05)))
    for i in range(-4, 5):
        for j in range(-4, 5):
            var px := float(i) * PITCH
            var pz := float(j) * PITCH
            for s in [-1.0, 1.0]:
                for k in range(-3, 4):
                    all.append(Transform3D(Basis.from_scale(Vector3(0.5, 1.0, 3.0)), Vector3(px + float(k) * 0.95, Y, pz + s * 5.5)))
                    all.append(Transform3D(Basis.from_scale(Vector3(3.0, 1.0, 0.5)), Vector3(px + s * 5.5, Y, pz + float(k) * 0.95)))
                all.append(Transform3D(Basis.from_scale(Vector3(3.0, 1.0, 0.35)), Vector3(px + 1.65 * s, Y, pz + 7.6 * s)))
                all.append(Transform3D(Basis.from_scale(Vector3(0.35, 1.0, 3.0)), Vector3(px + 7.6 * s, Y, pz - 1.65 * s)))
    _spawn_mm(line, all, _flat_mat(Color(0.92, 0.92, 0.9)))

func _digit(img: Image, d: int, ox: int, oy: int) -> void:
    var s: Array = SEGS.get(d, SEGS[0])
    var w := 13
    var h := 28
    var t := 4
    var black := Color(0.05, 0.05, 0.05)
    var rects := [
        Rect2i(ox, oy, w, t),
        Rect2i(ox, oy, t, 14),
        Rect2i(ox + w - t, oy, t, 14),
        Rect2i(ox, oy + 12, w, t),
        Rect2i(ox, oy + 14, t, 14),
        Rect2i(ox + w - t, oy + 14, t, 14),
        Rect2i(ox, oy + h - t, w, t),
    ]
    for k in range(7):
        if s[k] == 1:
            img.fill_rect(rects[k], black)

func _speed_tex(a: int, b: int) -> ImageTexture:
    var img := Image.create(64, 64, true, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for y in range(64):
        for x in range(64):
            var d := Vector2(float(x) - 31.5, float(y) - 31.5).length()
            if d <= 30.0:
                if d >= 24.0:
                    img.set_pixel(x, y, Color(0.85, 0.1, 0.1))
                else:
                    img.set_pixel(x, y, Color(0.97, 0.97, 0.97))
    _digit(img, a, 15, 18)
    _digit(img, b, 36, 18)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _cross_tex() -> ImageTexture:
    var img := Image.create(64, 64, true, Image.FORMAT_RGBA8)
    img.fill(Color(0.05, 0.28, 0.7))
    img.fill_rect(Rect2i(3, 3, 58, 58), Color.WHITE)
    img.fill_rect(Rect2i(6, 6, 52, 52), Color(0.05, 0.28, 0.7))
    for k in range(5):
        img.fill_rect(Rect2i(13 + k * 9, 14, 5, 36), Color.WHITE)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _plate_mat(tex: Texture2D) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_texture = tex
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    m.roughness = 0.6
    return m

func _signs() -> void:
    var pole := BoxMesh.new()
    pole.size = Vector3(0.08, 2.6, 0.08)
    var plate := QuadMesh.new()
    plate.size = Vector2(0.62, 0.62)
    var oct_r := CylinderMesh.new()
    oct_r.top_radius = 0.32
    oct_r.bottom_radius = 0.32
    oct_r.height = 0.05
    oct_r.radial_segments = 8
    oct_r.rings = 1
    var oct_w := CylinderMesh.new()
    oct_w.top_radius = 0.36
    oct_w.bottom_radius = 0.36
    oct_w.height = 0.035
    oct_w.radial_segments = 8
    oct_w.rings = 1
    var corners := [
        [Vector2(-4.2, -4.2), Vector2(0.0, -1.0)],
        [Vector2(4.2, 4.2), Vector2(0.0, 1.0)],
        [Vector2(-4.2, 4.2), Vector2(-1.0, 0.0)],
        [Vector2(4.2, -4.2), Vector2(1.0, 0.0)],
    ]
    var poles: Array = []
    var cross: Array = []
    var s30: Array = []
    var s50: Array = []
    var stop_r: Array = []
    var stop_w: Array = []
    for i in range(-3, 4):
        for j in range(-3, 4):
            if posmod(i + j, 2) != 0:
                continue
            var px := float(i) * PITCH
            var pz := float(j) * PITCH
            for c in range(4):
                var off: Vector2 = corners[c][0]
                var f: Vector2 = corners[c][1]
                var pole_pos := Vector3(px + off.x, TOP + 1.3, pz + off.y)
                poles.append(Transform3D(Basis.IDENTITY, pole_pos))
                var face := Vector3(f.x, 0.0, f.y)
                var yaw := atan2(f.x, f.y)
                var head := Vector3(pole_pos.x, TOP + 2.3, pole_pos.z) + face * 0.07
                var t := posmod(i * 5 + j * 3 + c, 4)
                if t == 1:
                    if posmod(i, 3) == 0:
                        s50.append(Transform3D(Basis(Vector3.UP, yaw), head))
                    else:
                        s30.append(Transform3D(Basis(Vector3.UP, yaw), head))
                elif t == 2:
                    var cb := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI / 8.0)
                    stop_r.append(Transform3D(cb, head + face * 0.01))
                    stop_w.append(Transform3D(cb, head))
                else:
                    cross.append(Transform3D(Basis(Vector3.UP, yaw), head))
    _spawn_mm(pole, poles, _flat_mat(Color(0.35, 0.37, 0.4)))
    _spawn_mm(plate, cross, _plate_mat(_cross_tex()))
    _spawn_mm(plate, s30, _plate_mat(_speed_tex(3, 0)))
    _spawn_mm(plate, s50, _plate_mat(_speed_tex(5, 0)))
    _spawn_mm(oct_r, stop_r, _flat_mat(Color(0.75, 0.05, 0.05)))
    _spawn_mm(oct_w, stop_w, _flat_mat(Color(0.95, 0.95, 0.95)))

func _bumps() -> void:
    var mesh := BoxMesh.new()
    mesh.size = Vector3(1.0, 0.07, 1.0)
    var yellow: Array = []
    var black: Array = []
    for i in range(-4, 5):
        for k in range(-4, 4):
            var u := float(k) * PITCH + 12.0
            if posmod(i * 31 + k * 17 + 7, 6) == 0:
                var pos := Vector3(float(i) * PITCH, 0.095, u)
                yellow.append(Transform3D(Basis.from_scale(Vector3(6.4, 1.0, 0.9)), pos))
                for s in range(4):
                    black.append(Transform3D(Basis.from_scale(Vector3(0.7, 1.15, 0.92)), pos + Vector3(-2.4 + float(s) * 1.6, 0.002, 0.0)))
            if posmod(i * 29 + k * 13 + 3, 6) == 0:
                var pos2 := Vector3(u, 0.095, float(i) * PITCH)
                yellow.append(Transform3D(Basis.from_scale(Vector3(0.9, 1.0, 6.4)), pos2))
                for s in range(4):
                    black.append(Transform3D(Basis.from_scale(Vector3(0.92, 1.15, 0.7)), pos2 + Vector3(0.0, 0.002, -2.4 + float(s) * 1.6)))
    _spawn_mm(mesh, yellow, _flat_mat(Color(0.9, 0.7, 0.1)))
    _spawn_mm(mesh, black, _flat_mat(Color(0.05, 0.05, 0.05)))

func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
    var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
    for s in range(steps + 1):
        var p := a.lerp(b, float(s) / float(maxi(steps, 1)))
        var px := clampi(int(p.x), 0, 63)
        var py := clampi(int(p.y), 0, 63)
        img.set_pixel(px, py, c)
        img.set_pixel(clampi(px + 1, 0, 63), py, c)

func _decal_tex(kind: String) -> ImageTexture:
    var img := Image.create(64, 64, true, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(kind)
    match kind:
        "patch":
            for y in range(10, 54):
                for x in range(6, 58):
                    var n := rng.randf_range(-0.02, 0.02)
                    var c := Color(0.09 + n, 0.09 + n, 0.1 + n, 0.88)
                    if x < 9 or x > 54 or y < 13 or y > 50:
                        c = Color(0.2, 0.2, 0.21, 0.8)
                    img.set_pixel(x, y, c)
        "crack":
            for strand in range(3):
                var x := 2.0
                var y := rng.randf_range(16.0, 48.0)
                while x < 62.0:
                    var nx := x + rng.randf_range(3.0, 7.0)
                    var ny := clampf(y + rng.randf_range(-6.0, 6.0), 2.0, 61.0)
                    _line(img, Vector2(x, y), Vector2(nx, ny), Color(0.03, 0.03, 0.03, 0.9))
                    x = nx
                    y = ny
        "manhole":
            for y in range(64):
                for x in range(64):
                    var d := Vector2(float(x) - 31.5, float(y) - 31.5).length()
                    if d <= 27.0:
                        var c := Color(0.1, 0.1, 0.11, 1.0)
                        if d >= 23.0:
                            c = Color(0.3, 0.3, 0.32, 1.0)
                        elif (x % 8) < 2 or (y % 8) < 2:
                            c = Color(0.2, 0.2, 0.21, 1.0)
                        img.set_pixel(x, y, c)
        "grate":
            for y in range(18, 46):
                for x in range(6, 58):
                    var c := Color(0.07, 0.07, 0.08, 1.0)
                    if x < 9 or x > 54 or y < 21 or y > 42:
                        c = Color(0.3, 0.3, 0.32, 1.0)
                    elif (x % 5) < 2:
                        c = Color(0.2, 0.2, 0.22, 1.0)
                    img.set_pixel(x, y, c)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _decal_mat(tex: Texture2D) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_texture = tex
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.roughness = 1.0
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

func _decals() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 2468
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    var lists := {"patch": [], "crack": [], "manhole": [], "grate": []}
    var counts := {"patch": 70, "crack": 110, "manhole": 60, "grate": 80}
    for kind in lists.keys():
        for n in range(int(counts[kind])):
            var i := rng.randi_range(-4, 4)
            var k := rng.randi_range(-4, 3)
            var ns := rng.randf() < 0.5
            var u := float(k) * PITCH + 12.0 + rng.randf_range(-6.0, 6.0)
            var v := rng.randf_range(-2.6, 2.6)
            var sx := 1.0
            var sy := 1.0
            var yaw := 0.0
            match kind:
                "patch":
                    sx = rng.randf_range(1.2, 2.2)
                    sy = rng.randf_range(1.6, 3.0)
                "crack":
                    sx = rng.randf_range(1.4, 2.6)
                    sy = sx
                    yaw = rng.randf() * TAU
                "manhole":
                    sx = 0.9
                    sy = 0.9
                    v = -1.65 if rng.randf() < 0.5 else 1.65
                "grate":
                    sx = 0.55
                    sy = 1.1
                    v = -3.0 if rng.randf() < 0.5 else 3.0
                    u = float(k) * PITCH + (9.0 if rng.randf() < 0.5 else 15.0)
            var pos := Vector3(float(i) * PITCH + v, 0.072, u)
            var base_yaw := yaw
            if not ns:
                pos = Vector3(u, 0.072, float(i) * PITCH + v)
                base_yaw += PI * 0.5
            var b := Basis(Vector3.UP, base_yaw) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(sx, sy, 1.0))
            lists[kind].append(Transform3D(b, pos))
    for kind in lists.keys():
        _spawn_mm(quad, lists[kind], _decal_mat(_decal_tex(kind)))
