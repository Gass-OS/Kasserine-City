extends Node

const NS_ROADS = ["Rue de Gafsa", "Avenue de Carthage", "Rue Ibn Khaldoun", "Avenue Habib Bourguiba", "Avenue de la République", "Rue de Kairouan", "Rue Farhat Hached", "Avenue de la Liberté", "Rue de Sfax"]
const EW_ROADS = ["Rue de Tunis", "Avenue Mohamed V", "Rue de Sousse", "Avenue de l'Indépendance", "Avenue de la Paix", "Rue des Oliviers", "Rue du Marché", "Rue de la Médina", "Avenue des Palmiers"]

class Mini extends Control:
    var world: Node
    var player: Node3D
    var gp
    var mp
    var R := 86.0
    var RANGE := 62.0

    func _p(d: Vector2, cs: float, sn: float) -> Vector2:
        return Vector2(d.x * cs - d.y * sn, d.x * sn + d.y * cs) * (R / RANGE)

    func _target() -> Variant:
        if gp == null:
            return null
        var m := int(gp.mission)
        if m < 4:
            var ts := [Vector3(3, 0, 7), Vector3(-24, 0, 0), Vector3(24, 0, 0), Vector3(3, 0, 7)]
            return ts[m]
        if mp != null and not bool(mp.get("done")):
            var steps := [Vector3(-36, 0, -36), Vector3(36, 0, -36), Vector3(-36, 0, 36), Vector3(36, 0, 36)]
            return steps[clampi(int(mp.get("step")), 0, 3)]
        return null

    func _process(_delta: float) -> void:
        queue_redraw()

    func _draw() -> void:
        var c := Vector2(R, R)
        draw_circle(c, R + 6.0, Color(0, 0, 0, 0.8))
        draw_circle(c, R, Color(0.2, 0.24, 0.2))
        if player == null or not is_instance_valid(player):
            return
        var pp := player.global_position
        var psi := 0.0
        var piv = player.get("camera_pivot")
        if piv != null:
            psi = (piv as Node3D).global_rotation.y
        var cs := cos(psi)
        var sn := sin(psi)
        var k := R / RANGE
        var col := Color(0.56, 0.58, 0.62)
        for i in range(-4, 5):
            var p := float(i) * 24.0
            var a := p - pp.x
            if absf(a) < RANGE:
                var hc := sqrt(RANGE * RANGE - a * a) * 0.97
                draw_line(c + _p(Vector2(a, -hc), cs, sn), c + _p(Vector2(a, hc), cs, sn), col, 8.0 * k)
            var b := p - pp.z
            if absf(b) < RANGE:
                var hc2 := sqrt(RANGE * RANGE - b * b) * 0.97
                draw_line(c + _p(Vector2(-hc2, b), cs, sn), c + _p(Vector2(hc2, b), cs, sn), col, 8.0 * k)
        var cits = world.get("citizens")
        if cits != null:
            for cz in cits:
                if not is_instance_valid(cz):
                    continue
                var d := Vector2(cz.global_position.x - pp.x, cz.global_position.z - pp.z)
                if d.length() < RANGE - 3.0:
                    draw_circle(c + _p(d, cs, sn), 2.4, Color(0.95, 0.95, 0.95, 0.8))
        var tgt = _target()
        if tgt != null:
            var dt := Vector2(tgt.x - pp.x, tgt.z - pp.z)
            var s := _p(dt, cs, sn)
            if s.length() > R - 10.0:
                s = s.normalized() * (R - 10.0)
            draw_circle(c + s, 7.0, Color(0, 0, 0, 0.9))
            draw_circle(c + s, 5.0, Color(1.0, 0.85, 0.2))
        draw_arc(c, R + 8.0, 0.0, TAU, 72, Color(0, 0, 0, 0.95), 16.0)
        draw_arc(c, R + 1.5, 0.0, TAU, 72, Color(1, 1, 1, 0.9), 3.0)
        draw_string(ThemeDB.fallback_font, c + Vector2(sn, -cs) * (R - 13.0) + Vector2(-5, 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1.0, 0.4, 0.35))
        draw_set_transform(c, psi - player.global_rotation.y, Vector2.ONE)
        draw_colored_polygon(PackedVector2Array([Vector2(0, -10), Vector2(8, 9), Vector2(0, 4), Vector2(-8, 9)]), Color(1, 1, 1))
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

var world: Node
var gp
var mp
var player: Node3D
var street_label: Label
var money_label: Label
var acc := 0.0

func _lab(pos: Vector2, size: int, color: Color, layer: CanvasLayer) -> Label:
    var l := Label.new()
    l.position = pos
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_constant_override("outline_size", 6)
    l.add_theme_color_override("font_outline_color", Color.BLACK)
    layer.add_child(l)
    return l

func _style(node: Node) -> void:
    if node is Button:
        var b := node as Button
        b.add_theme_font_size_override("font_size", 18)
        for st in ["normal", "hover", "pressed"]:
            var sb := StyleBoxFlat.new()
            sb.bg_color = Color(0.05, 0.05, 0.06, 0.8) if st == "normal" else Color(0.95, 0.55, 0.1, 0.92)
            sb.border_color = Color(0.95, 0.6, 0.1)
            sb.border_width_bottom = 3
            sb.set_corner_radius_all(2)
            b.add_theme_stylebox_override(st, sb)
    for ch in node.get_children():
        _style(ch)

func _ready() -> void:
    for i in range(3):
        await get_tree().process_frame
    world = get_parent()
    gp = world.get_node_or_null("Gameplay")
    mp = world.get_node_or_null("MissionsPlus")
    player = world.get_node_or_null("Player") as Node3D
    var layer := CanvasLayer.new()
    layer.layer = 12
    add_child(layer)
    var mini := Mini.new()
    mini.world = world
    mini.player = player
    mini.gp = gp
    mini.mp = mp
    mini.position = Vector2(28, 100)
    mini.size = Vector2(172, 172)
    mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(mini)
    money_label = _lab(Vector2(18, 298), 24, Color(0.45, 0.9, 0.4), layer)
    street_label = _lab(Vector2(18, 330), 18, Color(1, 1, 1), layer)
    if gp != null:
        gp.minimap.visible = false
        gp.notice.position = Vector2(230, 120)
        _style(gp)
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.04, 0.04, 0.05, 0.92)
        sb.border_color = Color(0.95, 0.6, 0.1)
        sb.border_width_top = 4
        sb.content_margin_left = 14
        sb.content_margin_right = 14
        sb.content_margin_top = 10
        sb.content_margin_bottom = 10
        gp.panel.add_theme_stylebox_override("panel", sb)

func _process(delta: float) -> void:
    if street_label == null or player == null:
        return
    acc += delta
    if acc < 0.3:
        return
    acc = 0.0
    var coins := 0
    if mp != null:
        coins = int(mp.get("coins"))
    money_label.text = "DT %d" % coins
    var pp := player.global_position
    var ix := clampi(roundi(pp.x / 24.0), -4, 4)
    var iz := clampi(roundi(pp.z / 24.0), -4, 4)
    var dx := absf(pp.x - float(ix) * 24.0)
    var dz := absf(pp.z - float(iz) * 24.0)
    if minf(dx, dz) > 7.0:
        street_label.text = "Kasserine"
    elif dx < dz:
        street_label.text = NS_ROADS[ix + 4]
    else:
        street_label.text = EW_ROADS[iz + 4]
