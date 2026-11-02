extends Node

const DUR := 24.0
const CARDS = [
    [1.0, 5.2, "KASSERINE CITY\nTunisia  ·  2026", 60],
    [8.0, 12.0, "A city that never sleeps.", 34],
    [14.5, 19.0, "Crime does not take a day off.", 34],
    [19.6, 23.4, "Unit 7, report for duty.", 42],
]

var world: Node3D
var player: Node3D
var cam: Camera3D
var layer: CanvasLayer
var bar_top: ColorRect
var bar_bot: ColorRect
var fade: ColorRect
var card: Label
var hidden: Array = []
var kt: Array = []
var kp: Array = []
var kl: Array = []
var t := 0.0
var scan_t := 0.0
var active := false
var finishing := false

func _ready() -> void:
    for i in range(10):
        await get_tree().process_frame
    world = get_parent() as Node3D
    if world == null:
        return
    player = world.get_node_or_null("Player") as Node3D
    if player == null:
        return
    _begin()

func _layers(n: Node, out: Array) -> void:
    if n is CanvasLayer:
        out.append(n)
    for c in n.get_children():
        _layers(c, out)

func _hide_layers() -> void:
    var all: Array = []
    _layers(world, all)
    for l in all:
        if l == layer:
            continue
        if l.visible:
            l.visible = false
            hidden.append(l)

func _begin() -> void:
    var pc := player.get("camera") as Camera3D
    var endp := player.global_position + Vector3(0.0, 3.5, 7.0)
    if pc != null:
        endp = pc.global_position
    var head := player.global_position + Vector3(0.0, 1.4, 0.0)
    kt = [0.0, 7.0, 14.0, 19.5, DUR]
    kp = [Vector3(-95, 105, 150), Vector3(70, 64, 105), Vector3(40, 26, 0), Vector3(12, 15, 36), endp]
    kl = [Vector3(0, 6, 0), Vector3(0, 8, -10), Vector3(26, 3, -34), Vector3(2, 2, 12), head]
    cam = Camera3D.new()
    cam.far = 2500.0
    cam.fov = 62.0
    world.add_child(cam)
    cam.make_current()
    cam.look_at_from_position(kp[0], kl[0], Vector3.UP)
    player.set_process_input(false)
    player.set_physics_process(false)
    var crime := world.get_node_or_null("Crime")
    if crime != null:
        crime.set("cooldown", 25.0 + DUR)
    layer = CanvasLayer.new()
    layer.layer = 100
    add_child(layer)
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.7)])
    g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
    var gt := GradientTexture2D.new()
    gt.gradient = g
    gt.fill = GradientTexture2D.FILL_RADIAL
    gt.fill_from = Vector2(0.5, 0.5)
    gt.fill_to = Vector2(1.0, 0.5)
    gt.width = 256
    gt.height = 256
    var vig := TextureRect.new()
    vig.texture = gt
    vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    vig.stretch_mode = TextureRect.STRETCH_SCALE
    vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(vig)
    bar_top = ColorRect.new()
    bar_top.color = Color.BLACK
    bar_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    bar_top.offset_bottom = 0.0
    layer.add_child(bar_top)
    bar_bot = ColorRect.new()
    bar_bot.color = Color.BLACK
    bar_bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    bar_bot.offset_top = 0.0
    layer.add_child(bar_bot)
    card = Label.new()
    card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    card.add_theme_color_override("font_color", Color(1.0, 0.93, 0.75))
    card.add_theme_constant_override("outline_size", 10)
    card.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    card.modulate.a = 0.0
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(card)
    fade = ColorRect.new()
    fade.color = Color(0, 0, 0, 1.0)
    fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(fade)
    var skip := Button.new()
    skip.text = "SKIP  >>"
    skip.position = Vector2(1140, 652)
    skip.custom_minimum_size = Vector2(120, 46)
    skip.focus_mode = Control.FOCUS_NONE
    skip.pressed.connect(_skip)
    layer.add_child(skip)
    _hide_layers()
    active = true

func _skip() -> void:
    t = maxf(t, DUR - 0.5)

func _spline(arr: Array, i: int, u: float) -> Vector3:
    var p0: Vector3 = arr[maxi(i - 1, 0)]
    var p1: Vector3 = arr[i]
    var p2: Vector3 = arr[i + 1]
    var p3: Vector3 = arr[mini(i + 2, arr.size() - 1)]
    return p1.cubic_interpolate(p2, p0, p3, u)

func _process(delta: float) -> void:
    if not active:
        return
    t += delta
    scan_t += delta
    if scan_t > 0.5:
        scan_t = 0.0
        _hide_layers()
    var bh := 74.0 * clampf(t / 1.2, 0.0, 1.0)
    bar_top.offset_bottom = bh
    bar_bot.offset_top = -bh
    var a := 1.0 - clampf(t / 1.8, 0.0, 1.0)
    if t > DUR - 0.5:
        a = clampf((t - (DUR - 0.5)) / 0.5, 0.0, 1.0)
    fade.color.a = a
    var ca := 0.0
    for c in CARDS:
        if t >= float(c[0]) and t <= float(c[1]):
            card.text = String(c[2])
            card.add_theme_font_size_override("font_size", int(c[3]))
            ca = minf(minf((t - float(c[0])) / 0.7, (float(c[1]) - t) / 0.7), 1.0)
    card.modulate.a = clampf(ca, 0.0, 1.0)
    var seg := kt.size() - 2
    var u := 1.0
    for i in range(kt.size() - 1):
        if t < float(kt[i + 1]):
            seg = i
            u = (t - float(kt[i])) / (float(kt[i + 1]) - float(kt[i]))
            break
    var pos := _spline(kp, seg, clampf(u, 0.0, 1.0))
    var look := _spline(kl, seg, clampf(u, 0.0, 1.0))
    var k := 1.0 - clampf(t / DUR, 0.0, 1.0)
    pos += Vector3(sin(t * 1.7), cos(t * 2.3), sin(t * 1.3)) * 0.12 * k
    cam.fov = lerpf(62.0, 50.0, clampf(t / DUR, 0.0, 1.0))
    cam.look_at_from_position(pos, look, Vector3.UP)
    if t >= DUR:
        _finish()

func _finish() -> void:
    if finishing:
        return
    finishing = true
    active = false
    var pc := player.get("camera") as Camera3D
    if pc != null:
        pc.make_current()
    if is_instance_valid(cam):
        cam.queue_free()
    for l in hidden:
        if is_instance_valid(l):
            l.visible = true
    player.set_process_input(true)
    player.set_physics_process(true)
    var radio := world.get_node_or_null("Radio")
    if radio != null:
        radio.call("say", "Dispatch", "Unit 7, your patrol car is at the station. Standing by for calls.", true)
    var tw := create_tween()
    tw.set_parallel(true)
    tw.tween_property(fade, "color:a", 0.0, 0.7)
    tw.tween_property(bar_top, "offset_bottom", 0.0, 0.7)
    tw.tween_property(bar_bot, "offset_top", 0.0, 0.7)
    tw.chain().tween_callback(layer.queue_free)
