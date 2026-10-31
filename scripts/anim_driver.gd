extends Node

var world: Node
var last := {}
var smooth := {}
var label: Label
var shown := 0.0

func _ready() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    world = get_parent()
    var layer := CanvasLayer.new()
    layer.layer = 20
    add_child(layer)
    label = Label.new()
    label.position = Vector2(20, 370)
    label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
    label.custom_minimum_size = Vector2(900, 0)
    label.add_theme_font_size_override("font_size", 13)
    label.add_theme_constant_override("outline_size", 5)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    layer.add_child(label)

func _bodies() -> Array:
    var out: Array = []
    var p := world.get_node_or_null("Player")
    if p:
        out.append(p)
    var cs = world.get("citizens")
    if cs != null:
        for c in cs:
            out.append(c)
    for g in get_tree().get_nodes_in_group("anim_body"):
        out.append(g)
    return out

func _model_of(n: Node) -> Node3D:
    for nm in ["PlayerCharacter", "KenneyCharacter"]:
        var m := n.get_node_or_null(nm)
        if m:
            return m as Node3D
    return null

func _process(delta: float) -> void:
    if world == null:
        return
    shown += delta
    for n in _bodies():
        if not is_instance_valid(n):
            continue
        var m := _model_of(n)
        if m == null:
            continue
        var pos: Vector3 = (n as Node3D).global_position
        var raw := 0.0
        if last.has(n):
            var d: Vector3 = pos - last[n]
            d.y = 0.0
            raw = d.length() / maxf(delta, 0.0001)
        last[n] = pos
        var s: float = lerpf(float(smooth.get(n, 0.0)), minf(raw, 14.0), 0.2)
        smooth[n] = s
        var ap := m.get_node_or_null("AnimPlayer") as AnimationPlayer
        if ap != null:
            var want := "idle"
            var spd := 1.0
            if n is CharacterBody3D and not (n as CharacterBody3D).is_on_floor() and ap.has_animation("jump"):
                want = "jump"
            elif s > 0.35 and ap.has_animation("run"):
                want = "run"
                spd = clampf(s / 4.5, 0.6, 1.6)
            if ap.current_animation != want and ap.has_animation(want):
                ap.play(want, 0.2)
            ap.speed_scale = spd
        else:
            var t := Time.get_ticks_msec() / 1000.0
            var ph := float(n.get_instance_id() % 7)
            if s > 0.35:
                m.position.y = absf(sin(t * clampf(s, 1.0, 8.0) * 2.0 + ph)) * 0.09
                m.rotation.z = sin(t * clampf(s, 1.0, 8.0) + ph) * 0.07
            else:
                m.position.y = lerpf(m.position.y, 0.0, 0.2)
                m.rotation.z = lerpf(m.rotation.z, 0.0, 0.2)
    if label != null:
        if shown < 20.0:
            var pl := world.get_node_or_null("Player")
            var pm := _model_of(pl) if pl else null
            label.text = "Animation: " + (str(pm.get_meta("anim_status", "?")) if pm else "no player model")
        else:
            label.text = ""
