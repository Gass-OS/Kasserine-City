extends Node

const Sfx = preload("res://scripts/sfx.gd")

var world: Node3D
var player: Node3D
var dn
var drive
var weather
var hum: AudioStreamPlayer
var crickets: AudioStreamPlayer
var engines: Array = []
var assigned: Array = []
var step_players: Array = []
var last_pos := {}
var speeds := {}
var scan_t := 0.0
var bird_t := 3.0
var horn_t := 15.0
var step_t := 0.0
var step_i := 0
var ready_ok := false

func _ready() -> void:
    for i in range(9):
        await get_tree().process_frame
    world = get_parent() as Node3D
    if world == null:
        return
    player = world.get_node_or_null("Player") as Node3D
    dn = world.get_node_or_null("DayNight")
    drive = world.get_node_or_null("Drive")
    weather = world.get_node_or_null("Weather")
    hum = _bed(Sfx.extra("hum"), -22.0)
    crickets = _bed(Sfx.extra("cricket"), -80.0)
    for k in range(6):
        var p := AudioStreamPlayer3D.new()
        p.stream = Sfx.get_sound("engine")
        p.volume_db = -80.0
        p.unit_size = 7.0
        p.max_distance = 55.0
        world.add_child(p)
        p.play()
        engines.append(p)
        assigned.append(null)
    for k in range(2):
        var sp := AudioStreamPlayer.new()
        sp.stream = Sfx.extra("step")
        sp.volume_db = -10.0
        add_child(sp)
        step_players.append(sp)
    _loop3d(Sfx.extra("water"), Vector3(12.0, 1.0, 12.0), -9.0, 4.0, 28.0)
    ready_ok = true
    for v in range(6):
        Sfx.voice_clip(v, false)
        await get_tree().process_frame
    var cs := Sfx.voice_clip(5, false).duplicate() as AudioStreamWAV
    cs.loop_mode = AudioStreamWAV.LOOP_FORWARD
    cs.loop_begin = 0
    cs.loop_end = int(cs.data.size() / 2)
    _loop3d(cs, Vector3(-12.0, 1.6, 12.0), -4.0, 6.0, 40.0)

func _bed(stream: AudioStream, db: float) -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.stream = stream
    p.volume_db = db
    add_child(p)
    p.play()
    return p

func _loop3d(stream: AudioStream, pos: Vector3, db: float, unit: float, maxd: float) -> void:
    var p := AudioStreamPlayer3D.new()
    p.stream = stream
    p.volume_db = db
    p.unit_size = unit
    p.max_distance = maxd
    world.add_child(p)
    p.global_position = pos
    p.play()

func _oneshot(stream: AudioStream, pos: Vector3, db: float, unit: float, maxd: float, pitch: float) -> void:
    var p := AudioStreamPlayer3D.new()
    p.stream = stream
    p.volume_db = db
    p.unit_size = unit
    p.max_distance = maxd
    p.pitch_scale = pitch
    world.add_child(p)
    p.global_position = pos
    p.play()
    p.finished.connect(p.queue_free)

func _process(delta: float) -> void:
    if not ready_ok or player == null:
        return
    var night := 0.0
    if dn != null:
        var t: float = dn.get("t")
        night = 1.0 - clampf(sin((t - 0.25) * TAU) * 2.5 + 0.35, 0.0, 1.0)
    var rain := 0.0
    if weather != null:
        rain = float(weather.get("rain"))
    crickets.volume_db = lerpf(-80.0, -27.0, night) if rain < 0.4 else -80.0
    var pp := player.global_position
    _engines(delta, pp)
    _birds(delta, pp, night, rain)
    _horns(delta, pp)
    _steps(delta)

func _engines(delta: float, pp: Vector3) -> void:
    scan_t -= delta
    if scan_t <= 0.0:
        scan_t = 0.25
        var cand: Array = []
        for v in get_tree().get_nodes_in_group("ambient_vehicle"):
            if not is_instance_valid(v):
                continue
            var d := (v as Node3D).global_position.distance_to(pp)
            if d < 60.0:
                cand.append([d, v])
        cand.sort_custom(func(a, b): return a[0] < b[0])
        for k in range(engines.size()):
            if k < cand.size():
                assigned[k] = cand[k][1]
            else:
                assigned[k] = null
    for k in range(engines.size()):
        var p: AudioStreamPlayer3D = engines[k]
        var v = assigned[k]
        if v == null or not is_instance_valid(v):
            p.volume_db = -80.0
            continue
        var n := v as Node3D
        p.global_position = n.global_position
        var s := 0.0
        if last_pos.has(v):
            s = (n.global_position - last_pos[v]).length() / maxf(delta, 0.001)
        last_pos[v] = n.global_position
        var sm := lerpf(float(speeds.get(v, 0.0)), s, 0.15)
        speeds[v] = sm
        var scooter: bool = n.has_meta("scooter")
        p.pitch_scale = (0.7 + minf(sm, 14.0) * 0.07) * (1.9 if scooter else 1.0)
        p.volume_db = (-8.0 if sm > 0.5 else -17.0) + (-4.0 if scooter else 0.0)

func _birds(delta: float, pp: Vector3, night: float, rain: float) -> void:
    bird_t -= delta
    if bird_t > 0.0:
        return
    bird_t = randf_range(2.5, 7.0)
    if night > 0.35 or rain > 0.25:
        return
    var a := randf() * TAU
    var pos := pp + Vector3(cos(a), 0.0, sin(a)) * randf_range(12.0, 38.0) + Vector3(0.0, randf_range(6.0, 12.0), 0.0)
    _oneshot(Sfx.extra("bird"), pos, -6.0, 8.0, 60.0, randf_range(0.85, 1.25))

func _horns(delta: float, pp: Vector3) -> void:
    horn_t -= delta
    if horn_t > 0.0:
        return
    horn_t = randf_range(14.0, 30.0)
    for v in get_tree().get_nodes_in_group("ambient_vehicle"):
        if is_instance_valid(v) and not (v as Node3D).has_meta("scooter") and (v as Node3D).global_position.distance_to(pp) < 38.0:
            _oneshot(Sfx.extra("horn"), (v as Node3D).global_position, 0.0, 10.0, 80.0, 1.0)
            return

func _steps(delta: float) -> void:
    if drive != null and bool(drive.get("driving")):
        return
    var vel: Vector3 = player.get("velocity")
    var s := Vector2(vel.x, vel.z).length()
    if s < 1.0 or not (player as CharacterBody3D).is_on_floor():
        step_t = 0.0
        return
    step_t -= delta * (s / 5.5)
    if step_t <= 0.0:
        step_t = 0.36
        var sp: AudioStreamPlayer = step_players[step_i % 2]
        step_i += 1
        sp.pitch_scale = randf_range(0.85, 1.15)
        sp.volume_db = -8.0 if s > 7.0 else -12.0
        sp.play()
