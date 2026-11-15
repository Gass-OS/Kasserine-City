extends Node

var world: Node
var last := {}
var smooth := {}

func _ready() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    world = get_parent()

func _bodies() -> Array:
    var out: Array = []
    var p := world.get_node_or_null("Player")
    if p:
        out.append(p)
    var cs = world.get("citizens")
    if cs != null:
        for c in cs:
            out.append(c)
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
                spd = clampf(s / 6.0, 0.35, 1.5)
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
