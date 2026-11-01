extends Node

const TYPES = [
    {"title": "Parking dispute", "a": "You blocked my driveway!", "b": "I only stopped for a minute!"},
    {"title": "Noise complaint", "a": "Your music is too loud!", "b": "It is the middle of the day!"},
    {"title": "Market quarrel", "a": "You cheated me on the price!", "b": "That is the fair price, sahbi!"},
    {"title": "Phone argument", "a": "That phone is MINE!", "b": "I found it, it is mine!"},
    {"title": "Queue jumping", "a": "Wait your turn!", "b": "I was here first!"},
    {"title": "Fence quarrel", "a": "Your fence is on my land!", "b": "The line was always here!"},
]

var world: Node3D
var player: Node3D
var gp
var crime
var radio
var drive
var timer := 95.0
var state := "idle"
var ia := -1
var ib := -1
var pa: Node3D
var pb: Node3D
var kind: Dictionary = {}
var aggressor := 0
var serious := false
var dismissed := false
var active_t := 0.0
var line_t := 0.0
var line_i := 0
var base_a := 0.0
var base_b := 0.0
var bub_a: Label3D
var bub_b: Label3D
var panel: PanelContainer
var title_l: Label
var info_l: Label
var btn_calm: Button
var btn_fine: Button
var btn_arrest: Button
var stat_label: Label
var resolved := 0
var rep := 0
var returns: Array = []

func _ready() -> void:
    for i in range(8):
        await get_tree().process_frame
    world = get_parent() as Node3D
    if world == null:
        return
    player = world.get_node_or_null("Player") as Node3D
    gp = world.get_node_or_null("Gameplay")
    crime = world.get_node_or_null("Crime")
    radio = world.get_node_or_null("Radio")
    drive = world.get_node_or_null("Drive")
    _mk_ui()
    _stats()

func _btn(text: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0, 46)
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 18)
    for st in ["normal", "hover", "pressed", "disabled"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.08, 0.08, 0.1, 0.9) if st != "pressed" else Color(0.95, 0.55, 0.1, 0.95)
        if st == "disabled":
            sb.bg_color = Color(0.2, 0.2, 0.22, 0.7)
        sb.border_color = Color(0.95, 0.6, 0.1)
        sb.border_width_bottom = 3
        sb.set_corner_radius_all(2)
        b.add_theme_stylebox_override(st, sb)
    b.pressed.connect(cb)
    return b

func _mk_ui() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 15
    add_child(layer)
    panel = PanelContainer.new()
    panel.position = Vector2(420, 230)
    panel.visible = false
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.04, 0.04, 0.05, 0.94)
    sb.border_color = Color(0.95, 0.6, 0.1)
    sb.border_width_top = 4
    sb.content_margin_left = 14
    sb.content_margin_right = 14
    sb.content_margin_top = 10
    sb.content_margin_bottom = 12
    panel.add_theme_stylebox_override("panel", sb)
    layer.add_child(panel)
    var v := VBoxContainer.new()
    v.custom_minimum_size = Vector2(440, 0)
    v.add_theme_constant_override("separation", 8)
    panel.add_child(v)
    title_l = Label.new()
    title_l.add_theme_font_size_override("font_size", 22)
    title_l.add_theme_color_override("font_color", Color(0.95, 0.6, 0.1))
    v.add_child(title_l)
    info_l = Label.new()
    info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_l.custom_minimum_size = Vector2(440, 50)
    info_l.add_theme_font_size_override("font_size", 16)
    v.add_child(info_l)
    btn_calm = _btn("Calm them down", _on_calm)
    btn_fine = _btn("Issue a fine (50 DT)", _on_fine)
    btn_arrest = _btn("Arrest the aggressor", _on_arrest)
    v.add_child(btn_calm)
    v.add_child(btn_fine)
    v.add_child(btn_arrest)
    v.add_child(_btn("Walk away", _on_leave))
    stat_label = Label.new()
    stat_label.position = Vector2(300, 698)
    stat_label.add_theme_font_size_override("font_size", 15)
    stat_label.add_theme_constant_override("outline_size", 6)
    stat_label.add_theme_color_override("font_outline_color", Color.BLACK)
    layer.add_child(stat_label)

func _stats() -> void:
    if stat_label != null:
        stat_label.text = "Disputes resolved: %d   Reputation: %d" % [resolved, rep]

func _notice(msg: String) -> void:
    if gp != null:
        gp.call("_notice", msg)

func _radio(unit: String, text: String) -> void:
    if radio != null:
        radio.call("say", unit, text, false)

func _coins(n: int) -> void:
    if crime != null:
        crime.call("add_coins", n)

func _face(a: Node3D, b: Node3D) -> void:
    var d := b.global_position - a.global_position
    d.y = 0.0
    if d.length() > 0.01:
        a.rotation.y = atan2(-d.x, -d.z)

func _mk_bubble(parent: Node3D) -> Label3D:
    var l := Label3D.new()
    l.font_size = 38
    l.pixel_size = 0.008
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = true
    l.outline_size = 12
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.width = 420.0
    l.position = Vector3(0, 3.0, 0)
    parent.add_child(l)
    return l

func _spawn() -> void:
    var cits = world.get("citizens")
    var cw = world.get("citizen_waits")
    if cits == null or cw == null or cits.size() < 6:
        timer = 10.0
        return
    var pp := player.global_position
    var cands: Array = []
    for k in range(1, cits.size()):
        var c: Node3D = cits[k]
        if not is_instance_valid(c) or not c.visible or c.has_meta("busy"):
            continue
        var d := Vector2(c.global_position.x - pp.x, c.global_position.z - pp.z).length()
        if d > 30.0 and d < 95.0:
            cands.append(k)
    if cands.size() < 2:
        timer = 8.0
        return
    cands.shuffle()
    ia = cands[0]
    ib = cands[1]
    pa = cits[ia]
    pb = cits[ib]
    var ang := randf() * TAU
    pb.global_position = pa.global_position + Vector3(cos(ang), 0.0, sin(ang)) * 1.7
    _face(pa, pb)
    _face(pb, pa)
    base_a = pa.rotation.y
    base_b = pb.rotation.y
    pa.set_meta("busy", true)
    pb.set_meta("busy", true)
    kind = TYPES[randi() % TYPES.size()]
    serious = randf() < 0.35
    aggressor = randi() % 2
    dismissed = false
    active_t = 0.0
    line_t = 0.0
    line_i = 0
    bub_a = _mk_bubble(pa)
    bub_b = _mk_bubble(pb)
    _lines()
    btn_calm.disabled = false
    btn_fine.disabled = false
    btn_arrest.disabled = false
    info_l.text = "Two citizens are shouting at each other. How do you handle it?"
    world.set_meta("dispute_pos", pa.global_position)
    var place := "the avenue"
    if crime != null:
        place = String(crime.call("near_name", pa.global_position))
    _radio("Dispatch", "Unit 7, 10-16 %s near %s. Citizens are shouting. Respond. Over." % [String(kind["title"]).to_lower(), place])
    state = "active"

func _lines() -> void:
    if not is_instance_valid(bub_a) or not is_instance_valid(bub_b):
        return
    if line_i % 2 == 0:
        bub_a.text = String(kind["a"])
        bub_a.modulate = Color(1, 1, 1)
        bub_b.text = "!"
        bub_b.modulate = Color(1.0, 0.25, 0.2)
    else:
        bub_b.text = String(kind["b"])
        bub_b.modulate = Color(1, 1, 1)
        bub_a.text = "!"
        bub_a.modulate = Color(1.0, 0.25, 0.2)

func _show_panel() -> void:
    if panel.visible:
        return
    title_l.text = "DISPUTE: " + String(kind["title"]).to_upper()
    panel.visible = true

func _hide_panel() -> void:
    if panel != null:
        panel.visible = false

func _on_calm() -> void:
    var chance := 0.35 if serious else 0.75
    if randf() < chance:
        _resolve("calm")
    else:
        serious = true
        btn_calm.disabled = true
        info_l.text = "They are not listening! Things are getting worse."

func _on_fine() -> void:
    var chance := 0.6 if serious else 0.9
    if randf() < chance:
        _resolve("fine")
    else:
        btn_fine.disabled = true
        info_l.text = "They refuse to pay the fine! Try something else."

func _on_arrest() -> void:
    if serious:
        _resolve("arrest_ok")
    else:
        _resolve("arrest_bad")

func _on_leave() -> void:
    dismissed = true
    _hide_panel()

func _take(idx: int) -> void:
    var cits = world.get("citizens")
    var cw = world.get("citizen_waits")
    var c: Node3D = cits[idx]
    cw[idx] = 99999.0
    c.visible = false
    c.global_position = Vector3(0, -100, 0)
    returns.append({"i": idx, "t": 50.0})

func _release(took: int) -> void:
    var cw = world.get("citizen_waits")
    for k in [ia, ib]:
        if k >= 0 and k != took and cw != null:
            cw[k] = 1.0
    for c in [pa, pb]:
        if is_instance_valid(c) and c.has_meta("busy"):
            c.remove_meta("busy")
    if is_instance_valid(bub_a):
        bub_a.queue_free()
    if is_instance_valid(bub_b):
        bub_b.queue_free()
    if world.has_meta("dispute_pos"):
        world.remove_meta("dispute_pos")
    _hide_panel()
    state = "idle"
    timer = randf_range(90.0, 150.0)

func _resolve(outcome: String) -> void:
    var took := -1
    var good := true
    match outcome:
        "calm":
            _coins(60)
            rep += 1
            _notice("Dispute calmed down. +60 dinars")
        "fine":
            if not serious and randf() < 0.4:
                _coins(30)
                rep -= 1
                _notice("Fine issued, but the citizens complained. +30 dinars")
            else:
                _coins(50)
                _notice("Fine issued. +50 dinars")
        "arrest_ok":
            _coins(140)
            rep += 1
            took = ia if aggressor == 0 else ib
            _take(took)
            _notice("Aggressor arrested. +140 dinars")
        "arrest_bad":
            _coins(-80)
            rep -= 2
            good = false
            took = ia if aggressor == 0 else ib
            _take(took)
            _notice("Wrongful arrest! Complaint filed. -80 dinars")
    if good:
        resolved += 1
        _radio("Unit 7", "Situation resolved. Parties have been advised. Over.")
        if resolved % 3 == 0:
            _coins(100)
            rep += 1
            _notice("Commendation from the chief! +100 dinars")
    else:
        _radio("Dispatch", "Unit 7, a complaint has been filed about that arrest.")
    _stats()
    _release(took)

func _expire() -> void:
    _radio("Dispatch", "Unit 3 took the disturbance call. Resume patrol.")
    _release(-1)
    timer = randf_range(80.0, 120.0)

func _process(delta: float) -> void:
    if world == null or player == null:
        return
    var cits = world.get("citizens")
    var cw = world.get("citizen_waits")
    for r in returns.duplicate():
        r["t"] = float(r["t"]) - delta
        if float(r["t"]) <= 0.0 and cits != null and cw != null:
            var i: int = r["i"]
            var c: Node3D = cits[i]
            c.visible = true
            var routes = world.get("citizen_routes")
            if routes != null and routes[i].size() > 0:
                c.position = routes[i][0]
            cw[i] = 0.5
            returns.erase(r)
    if state == "idle":
        timer -= delta
        if timer <= 0.0:
            _spawn()
        return
    if not is_instance_valid(pa) or not is_instance_valid(pb):
        _release(-1)
        return
    cw[ia] = 9999.0
    cw[ib] = 9999.0
    active_t += delta
    pa.rotation.y = base_a + sin(active_t * 9.0) * 0.16
    pb.rotation.y = base_b + sin(active_t * 9.0 + 1.5) * 0.16
    line_t += delta
    if line_t > 2.6:
        line_t = 0.0
        line_i += 1
        _lines()
    var d := Vector2(player.global_position.x - pa.global_position.x, player.global_position.z - pa.global_position.z).length()
    var drv := drive != null and bool(drive.get("driving"))
    if d < 5.0 and not drv and not dismissed:
        _show_panel()
    elif d > 9.0 or drv:
        _hide_panel()
        if d > 9.0:
            dismissed = false
    if active_t > 170.0:
        _expire()
