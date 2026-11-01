extends Node

const PAIRS = [
    ["واش حوالك الخو؟", "لاباس الحمد لله، وإنت؟"],
    ["أهلا بيك، خويا الباهي!", "ربي يعيشك، نهارك زين."],
    ["شنوّة صاير في الحومة؟", "فما حركة كبيرة اليوم في السوق."],
    ["وين ماشي يا صاحبي؟", "ماشي للقهوة، تلقاني غادي."],
    ["يعطيك الصحة على المعاونة.", "بالسلامة خويا، ربي معاك."],
    ["القهوة عامرة اليوم؟", "إي، الناس الكلّ قاعدة تحكي على الماتش."],
    ["Aslema! Chnowa ahwelek?", "Labes, hamdoullah! And you?"],
    ["Are you going to the market?", "Yes, I need fresh dates and bread."],
    ["Did you see the new cars?", "Wallah, they are beautiful!"],
    ["Let's have tea near the square.", "Ahla w sahla, sahbi!"],
    ["Bonsoir, sahbi!", "Bonsoir! Comment va la famille?"],
    ["Where is the garage?", "East side, you can't miss the sign."],
    ["Traffic is crazy today!", "Yes, drive carefully, ya khouya."],
    ["Aaychek, thanks for the help!", "Anytime, my friend."],
]
const NIGHT_PAIRS = [
    ["It is late, sahbi. Go home!", "Just five more minutes."],
    ["Beautiful night in Kasserine.", "Yes, the city lights look amazing."],
    ["Careful, the cars drive fast at night.", "Don't worry, I'm staying on the sidewalk."],
]

var world: Node
var player: Node3D
var dn: Node
var gameplay: Node
var bubbles := {}
var timer := 5.0
var busy := false

func _ready() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    world = get_parent()
    player = world.get_node_or_null("Player") as Node3D
    dn = world.get_node_or_null("DayNight")
    gameplay = world.get_node_or_null("Gameplay")
    var citizens = world.get("citizens")
    if citizens == null:
        return
    for c in citizens:
        bubbles[c] = _make_bubble(c)

func _process(delta: float) -> void:
    if busy or bubbles.size() < 2:
        return
    timer -= delta
    if timer > 0.0:
        return
    timer = 3.0
    var pair := _pick_pair()
    if pair.is_empty():
        return
    _converse(pair[0], pair[1], _pick_lines())

func _pick_pair() -> Array:
    var list: Array = bubbles.keys()
    list.shuffle()
    for a in list:
        if not is_instance_valid(a):
            continue
        if a.has_meta("busy"):
            continue
        if player != null and a.global_position.distance_to(player.global_position) > 35.0:
            continue
        for b in list:
            if b != a and is_instance_valid(b) and not b.has_meta("busy") and a.global_position.distance_to(b.global_position) < 18.0:
                return [a, b]
    return []

func _pick_lines() -> Array:
    var night := false
    if dn != null:
        var t: float = dn.t
        night = t < 0.22 or t > 0.78
    if night and randf() < 0.5:
        return NIGHT_PAIRS[randi() % NIGHT_PAIRS.size()]
    return PAIRS[randi() % PAIRS.size()]

func _make_bubble(parent: Node3D) -> Node3D:
    var root := Node3D.new()
    root.position = Vector3(0, 2.9, 0)
    root.visible = false
    parent.add_child(root)
    var bg := MeshInstance3D.new()
    bg.name = "Bg"
    var q := QuadMesh.new()
    q.size = Vector2(3.0, 0.55)
    bg.mesh = q
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color = Color(0.97, 0.97, 1.0, 0.93)
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.no_depth_test = true
    m.render_priority = 0
    bg.material_override = m
    root.add_child(bg)
    var label := Label3D.new()
    label.name = "Text"
    label.font_size = 40
    label.pixel_size = 0.005
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    label.modulate = Color(0.08, 0.09, 0.14)
    label.outline_size = 0
    label.no_depth_test = true
    label.render_priority = 1
    root.add_child(label)
    return root

func _speak_line(text: String) -> bool:
    if gameplay != null and not bool(gameplay.get("voice_enabled")):
        return false

    var voices = DisplayServer.tts_get_voices()
    if voices.is_empty():
        return false

    var voice_id := str(voices[0].get("id", ""))
    DisplayServer.tts_speak(text, voice_id, 0.85, 1.0, 1.0, 0, false)
    return true

func _say(c: Node3D, text: String, hold: float) -> void:
    if not is_instance_valid(c):
        return
    var voice_started := _speak_line(text)
    var root: Node3D = bubbles[c]
    var label := root.get_node("Text") as Label3D
    var bg := root.get_node("Bg") as MeshInstance3D
    var w := clampf(text.length() * 0.115 + 0.5, 1.4, 5.5)
    (bg.mesh as QuadMesh).size = Vector2(w, 0.55)
    label.offset = Vector2(-(w * 0.5 - 0.25) / label.pixel_size, 0.0)
    label.text = ""
    root.visible = true
    for i in range(1, text.length() + 1):
        label.text = text.substr(0, i)
        await get_tree().create_timer(0.03).timeout

    if voice_started:
        var voice_wait := 0.0
        while DisplayServer.tts_is_speaking() and voice_wait < 10.0:
            await get_tree().create_timer(0.1).timeout
            voice_wait += 0.1
        if DisplayServer.tts_is_speaking():
            DisplayServer.tts_stop()

    await get_tree().create_timer(hold).timeout
    root.visible = false

func _converse_old(a: Node3D, b: Node3D, lines: Array) -> void:
    busy = true
    await _say(a, lines[0], 1.6)
    await _say(b, lines[1], 1.6)
    busy = false
    timer = randf_range(5.0, 11.0)

func _face(a: Node3D, b: Node3D) -> void:
    var d := b.position - a.position
    d.y = 0.0
    if d.length() > 0.01:
        a.rotation.y = atan2(-d.x, -d.z)

func _converse(a: Node3D, b: Node3D, lines: Array) -> void:
    busy = true
    var cw = world.get("citizen_waits")
    var cs = world.get("citizens")
    var ia: int = cs.find(a) if cs != null else -1
    var ib: int = cs.find(b) if cs != null else -1
    if cw != null:
        if ia >= 0: cw[ia] = 90.0
        if ib >= 0: cw[ib] = 90.0
    _face(a, b)
    _face(b, a)
    await _say(a, lines[0], 1.6)
    await _say(b, lines[1], 1.6)
    if cw != null:
        if ia >= 0: cw[ia] = 0.8
        if ib >= 0: cw[ib] = 0.8
    busy = false
    timer = randf_range(5.0, 11.0)
