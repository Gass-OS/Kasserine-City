extends Node

const Sfx = preload("res://scripts/sfx.gd")
const UI = preload("res://scripts/ui_kit.gd")
const KenneyKit = preload("res://scripts/kenney.gd")

const HOME := Vector3(26.0, 0.1, -30.0)

var world: Node3D
var player: Node3D
var car: CharacterBody3D
var beacon: MeshInstance3D
var driving := false
var spd := 0.0
var yaw := 0.0
var hp := 100.0
var siren_on := false
var siren_t := 0.0
var siren_player: AudioStreamPlayer
var engine_player: AudioStreamPlayer
var mat_r: StandardMaterial3D
var mat_b: StandardMaterial3D
var light_r: OmniLight3D
var light_b: OmniLight3D
var speed_label: Label
var shake_t := 0.0
var shake_mag := 0.0
var crash_cd := 0.0
var repair_t := 0.0
var obstacles: Array = []
var traffic_orig: Array = []
var pause_until := {}
var civ_cd := {}
var yield_acc := 0.0

func _ready() -> void:
    for i in range(6):
        await get_tree().process_frame
    world = get_parent() as Node3D
    player = world.get_node_or_null("Player") as Node3D
    if player == null:
        return
    _build_car()
    var layer := CanvasLayer.new()
    layer.layer = 13
    add_child(layer)
    UI.button(layer, "CAR", Vector2(1196, 342), Color(0.25, 0.5, 0.95), _on_car)
    UI.button(layer, "SIREN", Vector2(1196, 406), Color(0.7, 0.3, 0.9), _on_siren)
    speed_label = Label.new()
    speed_label.position = Vector2(500, 600)
    speed_label.add_theme_font_size_override("font_size", 26)
    speed_label.add_theme_constant_override("outline_size", 7)
    speed_label.add_theme_color_override("font_outline_color", Color.BLACK)
    speed_label.visible = false
    layer.add_child(speed_label)
    for ch in world.get_children():
        if String(ch.name).begins_with("ParkedCar"):
            obstacles.append(ch)
    var sp = world.get("traffic_speeds")
    if sp != null:
        traffic_orig = sp.duplicate()

func _emit(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color.darkened(0.5)
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = 0.2
    return m

func _bar(pos: Vector3, mat: Material) -> void:
    var bm := BoxMesh.new()
    bm.size = Vector3(0.5, 0.12, 0.26)
    var mi := MeshInstance3D.new()
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    car.add_child(mi)

func _omni(color: Color, pos: Vector3) -> OmniLight3D:
    var l := OmniLight3D.new()
    l.light_color = color
    l.omni_range = 14.0
    l.light_energy = 0.0
    l.position = pos
    car.add_child(l)
    return l

func _build_car() -> void:
    car = CharacterBody3D.new()
    car.name = "PatrolCar"
    car.position = HOME
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(2.0, 1.3, 4.5)
    shape.shape = box
    shape.position = Vector3(0.0, 0.75, 0.0)
    car.add_child(shape)
    world.add_child(car)
    var dims := Vector3(1.9, 1.5, 4.5)
    var spawned = KenneyKit.car(9)
    if spawned != null:
        car.add_child(spawned["node"])
        dims = spawned["size"]
    else:
        var bm := BoxMesh.new()
        bm.size = Vector3(1.9, 1.2, 4.4)
        var mi := MeshInstance3D.new()
        mi.mesh = bm
        mi.position = Vector3(0, 0.7, 0)
        var m := StandardMaterial3D.new()
        m.albedo_color = Color(0.9, 0.9, 0.95)
        mi.material_override = m
        car.add_child(mi)
    mat_r = _emit(Color(1.0, 0.1, 0.1))
    mat_b = _emit(Color(0.15, 0.3, 1.0))
    _bar(Vector3(-0.38, dims.y + 0.06, 0.1), mat_r)
    _bar(Vector3(0.38, dims.y + 0.06, 0.1), mat_b)
    light_r = _omni(Color(1.0, 0.1, 0.1), Vector3(-0.5, dims.y + 0.5, 0.1))
    light_b = _omni(Color(0.15, 0.3, 1.0), Vector3(0.5, dims.y + 0.5, 0.1))
    var spot := SpotLight3D.new()
    spot.position = Vector3(0, 0.8, -dims.z * 0.5)
    spot.rotation_degrees = Vector3(-4, 0, 0)
    spot.spot_range = 22.0
    spot.spot_angle = 32.0
    spot.light_energy = 0.0
    spot.visible = false
    spot.add_to_group("car_headlight")
    car.add_child(spot)
    var cm := CylinderMesh.new()
    cm.top_radius = 0.35
    cm.bottom_radius = 0.35
    cm.height = 26.0
    beacon = MeshInstance3D.new()
    beacon.mesh = cm
    var bmat := StandardMaterial3D.new()
    bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    bmat.albedo_color = Color(0.3, 0.55, 1.0, 0.3)
    beacon.material_override = bmat
    beacon.position = Vector3(0, 13.0, 0)
    beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    car.add_child(beacon)
    engine_player = AudioStreamPlayer.new()
    engine_player.stream = Sfx.get_sound("engine")
    engine_player.volume_db = -16.0
    add_child(engine_player)
    siren_player = AudioStreamPlayer.new()
    siren_player.stream = Sfx.get_sound("siren")
    siren_player.volume_db = -9.0
    add_child(siren_player)

func _notice(msg: String) -> void:
    var gp := world.get_node_or_null("Gameplay")
    if gp != null:
        gp.call("_notice", msg)

func _radio(unit: String, text: String) -> void:
    var r := world.get_node_or_null("Radio")
    if r != null:
        r.call("say", unit, text, false)

func _wetness() -> float:
    var w := world.get_node_or_null("Weather")
    if w == null:
        return 0.0
    return float(w.get("wetness"))

func _fwd() -> Vector3:
    return Vector3(-sin(yaw), 0.0, -cos(yaw))

func _on_siren() -> void:
    siren_on = not siren_on
    if siren_on and driving:
        siren_player.play()
    else:
        siren_player.stop()
        mat_r.emission_energy_multiplier = 0.2
        mat_b.emission_energy_multiplier = 0.2
        light_r.light_energy = 0.0
        light_b.light_energy = 0.0

func _on_car() -> void:
    if repair_t > 0.0:
        _notice("The patrol car is being repaired.")
        return
    if driving:
        _exit()
        return
    var a := player.global_position
    var b := car.global_position
    if Vector2(a.x - b.x, a.z - b.z).length() < 5.5:
        _enter()
    else:
        _notice("Walk to the patrol car near the police station (blue beam).")

func _set_player_visible(v: bool) -> void:
    for nm in ["PlayerCharacter", "PoliceCap"]:
        var n := player.get_node_or_null(nm) as Node3D
        if n != null:
            n.visible = v
    for ch in player.get_children():
        if ch is CollisionShape3D:
            ch.set_deferred("disabled", not v)

func _enter() -> void:
    driving = true
    _set_player_visible(false)
    player.set_physics_process(false)
    var cam := player.get("camera") as Camera3D
    if cam != null:
        cam.position = Vector3(0, 3.4, 9.5)
    yaw = car.rotation.y
    spd = 0.0
    engine_player.play()
    if siren_on:
        siren_player.play()
    beacon.visible = false
    speed_label.visible = true
    _radio("Unit 7", "Unit 7 mobile.")

func _exit() -> void:
    driving = false
    spd = 0.0
    var side := Vector3(cos(car.rotation.y), 0.0, -sin(car.rotation.y))
    player.global_position = car.global_position + side * 2.6 + Vector3(0, 0.3, 0)
    player.set("velocity", Vector3.ZERO)
    _set_player_visible(true)
    player.set_physics_process(true)
    var cam := player.get("camera") as Camera3D
    if cam != null:
        cam.position = Vector3(0, 2.4, 6.5)
        cam.h_offset = 0.0
        cam.v_offset = 0.0
    engine_player.stop()
    siren_player.stop()
    beacon.visible = true
    speed_label.visible = false

func _burst(pos: Vector3) -> void:
    var p := CPUParticles3D.new()
    p.amount = 24
    p.lifetime = 0.9
    p.one_shot = true
    p.explosiveness = 0.95
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    p.emission_sphere_radius = 0.4
    p.direction = Vector3(0, 1, 0)
    p.spread = 90.0
    p.initial_velocity_min = 2.0
    p.initial_velocity_max = 5.5
    p.gravity = Vector3(0, -7.0, 0)
    var bm := BoxMesh.new()
    bm.size = Vector3(0.08, 0.08, 0.08)
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = Color(1.0, 0.65, 0.2)
    bm.material = m
    p.mesh = bm
    world.add_child(p)
    p.global_position = pos
    p.emitting = true
    get_tree().create_timer(2.0).timeout.connect(p.queue_free)

func _crash(impact: float) -> void:
    crash_cd = 0.8
    hp -= impact * 1.4
    spd = -spd * 0.25
    shake_t = 0.45
    shake_mag = clampf(impact / 40.0, 0.05, 0.5)
    Sfx.play(self, "crash", clampf(-14.0 + impact * 0.5, -14.0, 0.0))
    _burst(car.global_position + _fwd() * 2.0 + Vector3(0, 0.8, 0))
    if impact > 11.0:
        _radio("Unit 7", "Collision! I am okay, vehicle damaged.")
    if hp <= 0.0:
        _wreck()

func _wreck() -> void:
    hp = 0.0
    _exit()
    repair_t = 12.0
    _notice("Patrol car disabled. It will be towed back to the station.")
    _radio("Dispatch", "Unit 7, your vehicle is out of service. Tow truck is coming.")

func _knock(c: Node3D) -> void:
    var tw := create_tween()
    tw.tween_property(c, "rotation:x", -1.45, 0.18)
    tw.tween_interval(2.5)
    tw.tween_property(c, "rotation:x", 0.0, 0.4)

func _process(delta: float) -> void:
    if car == null:
        return
    if siren_on:
        siren_t += delta
        var ph := int(siren_t * 6.0) % 2
        mat_r.emission_energy_multiplier = 5.0 if ph == 0 else 0.3
        mat_b.emission_energy_multiplier = 0.3 if ph == 0 else 5.0
        light_r.light_energy = 3.0 if ph == 0 else 0.0
        light_b.light_energy = 0.0 if ph == 0 else 3.0
    yield_acc += delta
    if yield_acc > 0.3:
        yield_acc = 0.0
        _traffic_logic()
    if driving and speed_label != null:
        speed_label.text = "%d km/h    DMG %d%%" % [int(absf(spd) * 3.6), int(100.0 - hp)]
        engine_player.pitch_scale = 0.7 + absf(spd) / 29.0 * 1.5

func _traffic_logic() -> void:
    var tcars = world.get("traffic_cars")
    var speeds = world.get("traffic_speeds")
    if tcars == null or speeds == null or traffic_orig.size() != speeds.size():
        return
    var now := Time.get_ticks_msec() / 1000.0
    var cp := car.global_position
    for i in range(tcars.size()):
        var c: Node3D = tcars[i]
        if not is_instance_valid(c):
            continue
        if now < float(pause_until.get(i, 0.0)):
            speeds[i] = 0.0
            continue
        var d := Vector2(c.global_position.x - cp.x, c.global_position.z - cp.z).length()
        if siren_on and driving and d < 24.0:
            speeds[i] = float(traffic_orig[i]) * 0.25
        else:
            speeds[i] = float(traffic_orig[i])

func _physics_process(delta: float) -> void:
    if car == null:
        return
    crash_cd = maxf(0.0, crash_cd - delta)
    if repair_t > 0.0:
        repair_t -= delta
        if repair_t <= 0.0:
            hp = 100.0
            car.global_position = HOME
            car.rotation.y = 0.0
            yaw = 0.0
            _notice("Patrol car repaired and back at the station.")
        return
    if not driving:
        if not car.is_on_floor():
            car.velocity = Vector3(0.0, car.velocity.y - 25.0 * delta, 0.0)
            car.move_and_slide()
        return
    var tm: Vector2 = player.get("touch_move")
    var throttle := 0.0
    var steer := 0.0
    if tm.length() > 0.08:
        throttle = -tm.y
        steer = tm.x
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        throttle = 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        throttle = -1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        steer = -1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        steer = 1.0
    var turbo := int(player.get("sprint_touch")) != -1
    var wet := _wetness()
    var grip := 1.0 - 0.3 * wet
    var vmax := 22.0
    if turbo:
        vmax = 29.0
    if throttle > 0.1:
        spd += throttle * (15.0 - 9.0 * clampf(spd / vmax, 0.0, 1.0)) * grip * delta
    elif throttle < -0.1:
        if spd > 0.5:
            spd -= 28.0 * grip * delta
        else:
            spd += throttle * 7.0 * delta
    else:
        spd = move_toward(spd, 0.0, 5.0 * delta)
    spd = clampf(spd, -7.0, vmax)
    var turn := deg_to_rad(88.0) * clampf(absf(spd) / 6.0, 0.0, 1.0) * (1.0 - 0.45 * clampf(absf(spd) / 29.0, 0.0, 1.0)) * (1.0 - 0.3 * wet)
    yaw -= steer * turn * delta * (1.0 if spd >= 0.0 else -1.0)
    car.rotation.y = yaw
    var f := _fwd()
    var vy := car.velocity.y
    if car.is_on_floor():
        vy = 0.0
    else:
        vy -= 25.0 * delta
    car.velocity = Vector3(f.x * spd, vy, f.z * spd)
    car.move_and_slide()
    var rv := car.get_real_velocity()
    var rs := Vector2(rv.x, rv.z).length()
    if crash_cd <= 0.0 and absf(spd) > 6.0 and rs < absf(spd) * 0.4:
        _crash(absf(spd))
    var cp := car.global_position
    if crash_cd <= 0.0 and absf(spd) > 3.0:
        var tcars = world.get("traffic_cars")
        for o in obstacles:
            if not is_instance_valid(o):
                continue
            var dv := Vector2(o.global_position.x - cp.x, o.global_position.z - cp.z)
            if dv.length() < 3.0:
                var dir := Vector3(dv.x, 0.0, dv.y).normalized()
                o.global_position += dir * 1.5
                o.rotation.y += randf_range(-0.4, 0.4)
                if tcars != null:
                    var idx: int = tcars.find(o)
                    if idx >= 0:
                        pause_until[idx] = Time.get_ticks_msec() / 1000.0 + 4.0
                _crash(absf(spd))
                break
    if absf(spd) > 4.0:
        var front := cp + f * 1.6
        var cits = world.get("citizens")
        var cw = world.get("citizen_waits")
        var now := Time.get_ticks_msec() / 1000.0
        if cits != null:
            for k in range(cits.size()):
                var c: Node3D = cits[k]
                if not is_instance_valid(c):
                    continue
                if now < float(civ_cd.get(c, 0.0)):
                    continue
                var d := Vector2(c.global_position.x - front.x, c.global_position.z - front.z).length()
                if d < 1.7:
                    civ_cd[c] = now + 6.0
                    _knock(c)
                    if cw != null and k < cw.size():
                        cw[k] = 3.5
                    var cr := world.get_node_or_null("Crime")
                    if cr != null:
                        cr.call("add_coins", -100)
                    _radio("Dispatch", "Civilian struck! Watch the road, Unit 7!")
                    Sfx.play(self, "crash", -12.0)
    player.global_position = car.global_position + Vector3(0, 0.1, 0)
    var piv := player.get("camera_pivot") as Node3D
    if piv != null:
        piv.global_rotation.y = lerp_angle(piv.global_rotation.y, yaw, 4.0 * delta)
    var cam := player.get("camera") as Camera3D
    if cam != null:
        if shake_t > 0.0:
            shake_t -= delta
            cam.h_offset = randf_range(-1.0, 1.0) * shake_mag
            cam.v_offset = randf_range(-1.0, 1.0) * shake_mag
        else:
            cam.h_offset = 0.0
            cam.v_offset = 0.0
