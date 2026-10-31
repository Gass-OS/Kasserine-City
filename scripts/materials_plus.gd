extends Node

const ROAD := Color(0.16, 0.17, 0.18)
const GROUND := Color(0.42, 0.48, 0.31)

var world: Node
var dn
var road_mat: StandardMaterial3D
var cache := {}
var acc := 0.0

func _ready() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    world = get_parent()
    dn = world.get_node_or_null("DayNight")
    _build()
    _apply(world)

func _ramp(a: Color, b: Color) -> Gradient:
    var g := Gradient.new()
    g.colors = PackedColorArray([a, b])
    g.offsets = PackedFloat32Array([0.0, 1.0])
    return g

func _tex(freq: float, seed_val: int, kind: int, lo: Color, hi: Color) -> NoiseTexture2D:
    var n := FastNoiseLite.new()
    n.noise_type = kind
    n.frequency = freq
    n.seed = seed_val
    var t := NoiseTexture2D.new()
    t.noise = n
    t.width = 512
    t.height = 512
    t.seamless = true
    t.color_ramp = _ramp(lo, hi)
    return t

func _nrm(freq: float, seed_val: int, kind: int, bump: float) -> NoiseTexture2D:
    var n := FastNoiseLite.new()
    n.noise_type = kind
    n.frequency = freq
    n.seed = seed_val
    var t := NoiseTexture2D.new()
    t.noise = n
    t.width = 512
    t.height = 512
    t.seamless = true
    t.as_normal_map = true
    t.bump_strength = bump
    return t

func _make(color: Color, albedo: Texture2D, normal: Texture2D, scale: float, rough: float, nscale: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.albedo_texture = albedo
    m.normal_enabled = true
    m.normal_texture = normal
    m.normal_scale = nscale
    m.roughness = rough
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3.ONE * scale
    return m

var asphalt_tex: Texture2D
var asphalt_nrm: Texture2D
var stucco_tex: Texture2D
var stucco_nrm: Texture2D
var ground_tex: Texture2D
var ground_nrm: Texture2D
var ground_mat: StandardMaterial3D

func _build() -> void:
    var k_s := FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    var k_c := FastNoiseLite.TYPE_CELLULAR
    asphalt_tex = _tex(0.12, 11, k_s, Color(0.55, 0.55, 0.57), Color(1, 1, 1))
    asphalt_nrm = _nrm(0.22, 12, k_c, 3.0)
    stucco_tex = _tex(0.07, 21, k_s, Color(0.72, 0.72, 0.72), Color(1, 1, 1))
    stucco_nrm = _nrm(0.14, 22, k_s, 2.5)
    ground_tex = _tex(0.05, 31, k_s, Color(0.55, 0.55, 0.55), Color(1, 1, 1))
    ground_nrm = _nrm(0.18, 32, k_c, 2.0)
    road_mat = _make(ROAD, asphalt_tex, asphalt_nrm, 0.25, 0.8, 0.8)
    ground_mat = _make(GROUND, ground_tex, ground_nrm, 0.15, 0.95, 0.6)

func _apply(n: Node) -> void:
    if n is MeshInstance3D:
        var mi := n as MeshInstance3D
        var bm := mi.mesh as BoxMesh
        var mat := mi.material_override as StandardMaterial3D
        if bm != null and mat != null and not mat.emission_enabled and mat.albedo_texture == null:
            var c := mat.albedo_color
            var s := bm.size
            if c.is_equal_approx(ROAD):
                mi.material_override = road_mat
            elif c.is_equal_approx(GROUND):
                mi.material_override = ground_mat
            elif s.y >= 3.0 and s.x >= 6.0 and s.z >= 6.0:
                var key := c.to_html()
                if not cache.has(key):
                    cache[key] = _make(c, stucco_tex, stucco_nrm, 0.22, 0.9, 0.7)
                mi.material_override = cache[key]
    for ch in n.get_children():
        _apply(ch)

func _process(delta: float) -> void:
    if dn == null or road_mat == null:
        return
    acc += delta
    if acc < 0.5:
        return
    acc = 0.0
    var t: float = dn.t
    var day := clampf(sin((t - 0.25) * TAU) * 2.5 + 0.35, 0.0, 1.0)
    road_mat.roughness = lerpf(0.3, 0.8, day)
