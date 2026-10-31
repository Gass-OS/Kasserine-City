extends Node

const Sfx = preload("res://scripts/sfx.gd")
const UI = preload("res://scripts/ui_kit.gd")
const KenneyKit = preload("res://scripts/kenney.gd")
const CharacterModel = preload("res://scripts/character_model.gd")

const PLACES = {
    "the Market": Vector3(-24, 0, 0),
    "the Garage": Vector3(24, 0, 0),
    "the School": Vector3(-36, 0, -36),
    "the Police Station": Vector3(36, 0, -36),
    "the Hospital": Vector3(-36, 0, 36),
    "the Cafe": Vector3(36, 0, 36),
    "the Grand Mosque": Vector3(12, 0, -36),
    "the souk": Vector3(-12, 0, 12),
    "the fountain": Vector3(12, 0, 12),
}
const CASES = [
    "pickpocket reported near %s. Male suspect, striped jacket, fleeing on foot.",
    "shop theft near %s. Suspect left on foot with stolen goods.",
    "vandalism near %s. Suspect spray-painting storefronts, now running.",
    "bag snatching near %s. Suspect fled on foot. The victim is unharmed.",
]

var world: Node3D
var gp
var mp
var radio
var player: Node3D
var suspect: Node3D = null
var s_label: Label3D = null
var s_state := "none"
var s_node := Vector2i.ZERO
var s_prev := Vector2i(99, 99)
var s_target := Vector2i.ZERO
var flee_t := 0.0
var frozen_t := 0.0
var boost_t := 0.0
var case_t := 0.0
var cooldown := 25.0
var last_known := Vector3.ZERO
var hint_t := 25.0
var arrests := 0
var lost := 0
var case_label: Label
var prompt_label: Label
var last_notice := 0.0

func _ready() -> void:
    for i in range(4):
        await get_tree().process_frame
    world = get_parent() as Node3D
    gp = world.get_node_or_null("Gameplay")
    mp = world.get_node_or_null("MissionsPlus")
    radio = world.get_node_or_null("Radio")
    player = world.get_node_or_null("Player") as Node3D
    if player == null:
        return
    var layer := CanvasLayer.new()
    layer.layer = 13
    add_child(layer)
    UI.button(layer, "CUFF", Vector2(1196, 150), Color(0.95, 0.55, 0.1), _on_cuff)
    UI.button(layer, "HALT", Vector2(1196, 214), Color(0.85, 0.2, 0.2), _on_halt)
    case_label = _lab(layer, Vector2(300, 672), 18, Color(1, 1, 1))
    prompt_label = _lab(layer, Vector2(470, 612), 22, Color(1.0, 0.85, 0.2))
    _dress_player()

func _lab(layer: CanvasLayer, pos: Vector2, size: int, color: Color) -> Label:
    var l := Label.new()
    l.position = pos
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_constant_override("outline_size", 6)
    l.add_theme_color_override("font_outline_color", Color.BLACK)
    layer.add_child(l)
    return l

func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
    var c := CylinderMesh.new()
    c.top_radius = top
    c.bottom_radius = bottom
    c.height = h
    c.radial_segments = 14
    return c

func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)

func _dress_player() -> void:
    var model := player.get_node_or_null("PlayerCharacter") as Node3D
    var top := 1.75
    if model != null:
        var a := KenneyKit._aabb(model)
        var h := (a.position.y + a.size.y) * model.scale.y
        if h > 0.8 and h < 3.0:
            top = h
    var s := clampf(top / 1.8, 0.6, 1.6)
    var cap := Node3D.new()
    cap.name = "PoliceCap"
    cap.position = Vector3(0.0, top - 0.07 * s, 0.0)
    cap.scale = Vector3.ONE * s
    player.add_child(cap)
    var navy := StandardMaterial3D.new()
    navy.albedo_color = Color(0.06, 0.1, 0.28)
    navy.roughness = 0.7
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(0.03, 0.03, 0.04)
    var gold := StandardMaterial3D.new()
    gold.albedo_color = Color(0.95, 0.78, 0.25)
    gold.metallic = 0.8
    gold.roughness = 0.3
    _part(cap, _cyl(0.2, 0.2, 0.08), Vector3(0, 0.04, 0), navy)
    _part(cap, _cyl(0.16, 0.2, 0.12), Vector3(0, 0.13, 0), navy)
    var vis := BoxMesh.new()
    vis.size = Vector3(0.28, 0.02, 0.16)
    _part(cap, vis, Vector3(0, 0.02, -0.2), dark)
    var bd := SphereMesh.new()
    bd.radius = 0.03
    bd.height = 0.06
    _part(cap, bd, Vector3(0, 0.12, -0.19), gold)

func _c(u: int) -> float:
    var b := floori(float(u) / 2.0)
    return 24.0 * float(b) + (5.0 if posmod(u, 2) == 0 else 19.0)

func _pos(u: int, v: int) -> Vector3:
    return Vector3(_c(u), 0.0, _c(v))

func near_name(p: Vector3) -> String:
    var best := "the avenue"
    var bd := 1.0e9
    for k in PLACES.keys():
        var q: Vector3 = PLACES[k]
        var d := Vector2(q.x - p.x, q.z - p.z).length()
        if d < bd:
            bd = d
            best = String(k)
    return best

func add_coins(n: int) -> void:
    if mp == null:
        return
    var c := maxi(0, int(mp.get("coins")) + n)
    mp.set("coins", c)
    var cl = mp.get("coin_label")
    if cl != null and cl.visible:
        cl.text = "Dinars: %d" % c

func _notice(msg: String) -> void:
    if gp != null:
        gp.call("_notice", msg)

func _say(unit: String, text: String, speak := true) -> void:
    if radio != null:
        radio.call("say", unit, text, speak)

func _dist() -> float:
    if suspect == null:
        return 9999.0
    var a := player.global_position
    var b := suspect.global_position
    return Vector2(a.x - b.x, a.z - b.z).length()

func _driving() -> bool:
    var dr := world.get_node_or_null("Drive")
    return dr != null and bool(dr.get("driving"))

func _process(delta: float) -> void:
    if player == null or world == null:
        return
    _poll_witness()
    if suspect == null:
        cooldown -= delta
        if cooldown <= 0.0:
            _new_case()
    else:
        _update_suspect(delta)
    _radar()
    _hud()

func _poll_witness() -> void:
    if gp == null:
        return
    var nt := float(gp.get("notice_time"))
    if nt > last_notice + 0.5 and String(gp.notice.text).begins_with("Citizen:"):
        if suspect != null and s_state != "cuffed":
            if _dist() < 80.0:
                last_known = suspect.position + Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-6.0, 6.0))
                gp.notice.text = "Witness: I saw a man running near %s!" % near_name(suspect.position)
            else:
                gp.notice.text = "Witness: Sorry officer, I saw nothing."
    last_notice = nt

func _new_case() -> void:
    var pp := player.global_position
    var found := false
    var pick := Vector2i.ZERO
    for k in range(60):
        var u := randi_range(-8, 7)
        var v := randi_range(-8, 7)
        var p := _pos(u, v)
        var d := Vector2(p.x - pp.x, p.z - pp.z).length()
        if d > 45.0 and d < 105.0:
            pick = Vector2i(u, v)
            found = true
            break
    if not found:
        cooldown = 5.0
        return
    s_node = pick
    s_prev = Vector2i(99, 99)
    s_target = pick
    suspect = Node3D.new()
    suspect.name = "Suspect"
    suspect.position = _pos(pick.x, pick.y)
    world.add_child(suspect)
    var model: Node3D = CharacterModel.build(0)
    if model != null:
        suspect.add_child(model)
    else:
        var cm := CapsuleMesh.new()
        cm.radius = 0.35
        cm.height = 1.7
        var mi := MeshInstance3D.new()
        mi.mesh = cm
        mi.position = Vector3(0, 0.85, 0)
        suspect.add_child(mi)
    suspect.add_to_group("anim_body")
    s_label = Label3D.new()
    s_label.text = "SUSPECT"
    s_label.font_size = 36
    s_label.pixel_size = 0.01
    s_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    s_label.no_depth_test = true
    s_label.modulate = Color(1.0, 0.3, 0.25)
    s_label.outline_size = 10
    s_label.position = Vector3(0, 2.5, 0)
    s_label.visible = false
    suspect.add_child(s_label)
    s_state = "idle"
    case_t = 0.0
    hint_t = 25.0
    flee_t = 0.0
    boost_t = 0.0
    last_known = suspect.position + Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
    var line: String = CASES[randi() % CASES.size()] % near_name(suspect.position)
    _say("Dispatch", "Unit 7, " + line + " Respond. Over.")

func _choose_next() -> Vector2i:
    var pp := player.global_position
    var best := s_node
    var best_score := -1.0e9
    for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        var n: Vector2i = s_node + d
        if n.x < -8 or n.x > 7 or n.y < -8 or n.y > 7:
            continue
        var p := _pos(n.x, n.y)
        var score := Vector2(p.x - pp.x, p.z - pp.z).length() + randf() * 14.0
        if n == s_prev:
            score -= 25.0
        if score > best_score:
            best_score = score
            best = n
    return best

func _start_flee() -> void:
    s_state = "flee"
    flee_t = 0.0
    s_target = _choose_next()
    _say("Dispatch", "Suspect is running! Pursue on foot.")

func _move_suspect(spd: float, delta: float) -> void:
    var tp := _pos(s_target.x, s_target.y)
    var d := tp - suspect.position
    d.y = 0.0
    if d.length() < 0.35:
        s_prev = s_node
        s_node = s_target
        s_target = _choose_next()
        return
    var dir := d.normalized()
    suspect.position += dir * spd * delta
    suspect.rotation.y = atan2(-dir.x, -dir.z)

func _update_suspect(delta: float) -> void:
    case_t += delta
    var dist := _dist()
    var sp := suspect.global_position
    if s_label != null:
        s_label.visible = dist < 24.0
    match s_state:
        "idle":
            if dist < 30.0 or case_t > 60.0:
                _start_flee()
        "flee":
            flee_t += delta
            boost_t = maxf(0.0, boost_t - delta)
            var spd := lerpf(7.6, 4.6, clampf(flee_t / 45.0, 0.0, 1.0))
            if boost_t > 0.0:
                spd += 2.5
            _move_suspect(spd, delta)
        "frozen":
            frozen_t -= delta
            if frozen_t <= 0.0:
                s_state = "flee"
    if s_state == "cuffed":
        return
    if dist > 140.0 or case_t > 300.0:
        lost += 1
        _say("Dispatch", "Suspect lost. Case closed. Stay alert, Unit 7.")
        _end_case()
        return
    hint_t -= delta
    if hint_t <= 0.0:
        hint_t = 25.0
        if dist > 45.0:
            last_known = sp + Vector3(randf_range(-9.0, 9.0), 0.0, randf_range(-9.0, 9.0))
            _say("Dispatch", "Air support: suspect last seen near %s, still moving." % near_name(sp), false)

func _end_case() -> void:
    if suspect != null and is_instance_valid(suspect):
        suspect.queue_free()
    suspect = null
    s_label = null
    s_state = "none"
    cooldown = randf_range(20.0, 35.0)

func _bubble(target: Node3D, text: String, color: Color) -> void:
    var l := Label3D.new()
    l.text = text
    l.font_size = 40
    l.pixel_size = 0.01
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = true
    l.modulate = color
    l.outline_size = 12
    l.position = Vector3(0, 2.8, 0)
    target.add_child(l)
    get_tree().create_timer(1.6).timeout.connect(l.queue_free)

func _on_halt() -> void:
    if player == null:
        return
    Sfx.play(self, "whistle", -4.0)
    _bubble(player, "STOP! POLICE!", Color(1.0, 0.9, 0.3))
    if suspect == null or s_state == "cuffed":
        return
    if _dist() > 16.0:
        _notice("Too far for him to hear you.")
        return
    var chance := 0.55
    if flee_t > 20.0:
        chance = 0.8
    if randf() < chance:
        s_state = "frozen"
        frozen_t = 3.0
        _say("Unit 7", "Suspect has stopped! Moving in.", false)
    else:
        if s_state == "idle":
            _start_flee()
        s_state = "flee"
        boost_t = 4.0
        _say("Unit 7", "He is not complying! He is running!", false)

func _on_cuff() -> void:
    if suspect == null or s_state == "cuffed":
        _notice("No suspect nearby.")
        return
    if _driving():
        _notice("Get out of the car first.")
        return
    if _dist() > 2.8:
        _notice("Get closer to the suspect!")
        return
    s_state = "cuffed"
    Sfx.play(self, "click", -2.0)
    var reward := 150 + int(maxf(0.0, 120.0 - case_t))
    add_coins(reward)
    arrests += 1
    if s_label != null:
        s_label.text = "ARRESTED"
        s_label.modulate = Color(0.4, 1.0, 0.4)
        s_label.visible = true
    _notice("Suspect arrested! +%d dinars" % reward)
    _say("Unit 7", "Suspect in custody. Requesting transport. Over.", false)
    get_tree().create_timer(2.0).timeout.connect(_transport_msg)
    var tw := create_tween()
    tw.tween_interval(3.5)
    tw.tween_property(suspect, "scale", Vector3.ZERO, 0.6)
    tw.tween_callback(_end_case)

func _transport_msg() -> void:
    _say("Dispatch", "Copy, transport is on its way. Good work, Unit 7.", false)

func radio_request() -> void:
    Sfx.play(self, "roger", -6.0)
    if suspect != null and s_state != "cuffed":
        if _dist() > 45.0:
            last_known = suspect.position + Vector3(randf_range(-7.0, 7.0), 0.0, randf_range(-7.0, 7.0))
        _say("Unit 7", "Dispatch, requesting a suspect update. Over.", false)
        get_tree().create_timer(1.8).timeout.connect(_update_msg)
    else:
        _say("Unit 7", "Dispatch, any new calls? Over.", false)
        if cooldown > 8.0:
            cooldown = 8.0
        get_tree().create_timer(1.8).timeout.connect(_standby_msg)

func _update_msg() -> void:
    if suspect != null:
        _say("Dispatch", "Last known near %s. Units are tracking. Over." % near_name(last_known), false)

func _standby_msg() -> void:
    _say("Dispatch", "Standby, Unit 7. Stay on patrol.", false)

func _radar() -> void:
    var t = null
    if suspect != null and s_state != "cuffed":
        t = suspect.position if _dist() < 45.0 else last_known
    else:
        var inc := world.get_node_or_null("Incidents")
        if inc != null:
            t = inc.get("active_pos")
    if t != null:
        world.set_meta("radar_target", t)
    elif world.has_meta("radar_target"):
        world.remove_meta("radar_target")

func _hud() -> void:
    if case_label == null:
        return
    if suspect == null:
        case_label.text = "ON PATROL   |   Arrests: %d" % arrests
        prompt_label.text = ""
        return
    if s_state == "cuffed":
        case_label.text = "SUSPECT ARRESTED   |   Arrests: %d" % arrests
        prompt_label.text = ""
        return
    var d := _dist()
    if d < 45.0:
        case_label.text = "CASE ACTIVE - suspect %d m   |   Arrests: %d" % [int(d), arrests]
    else:
        var pp := player.global_position
        var lk := Vector2(last_known.x - pp.x, last_known.z - pp.z).length()
        case_label.text = "CASE ACTIVE - last known %d m   |   Arrests: %d" % [int(lk), arrests]
    if d < 2.8 and not _driving():
        prompt_label.text = "Press CUFF to arrest"
    else:
        prompt_label.text = ""
