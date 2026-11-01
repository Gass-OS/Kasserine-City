extends Node

const Sfx = preload("res://scripts/sfx.gd")
const KenneyKit = preload("res://scripts/kenney.gd")

var world: Node3D
var player: Node3D
var active_pos = null
var timer := 110.0
var state := "idle"
var active_t := 0.0
var secure_t := 0.0
var blink := 0.0
var arrived := false
var nodes: Array = []
var lights: Array = []
var last_incident_pos: Vector3 = Vector3.ZERO
var medic_lights: Array = []
var medic_blink := 0.0

func _ready() -> void:
    for i in range(5):
        await get_tree().process_frame
    world = get_parent() as Node3D
    player = world.get_node_or_null("Player") as Node3D

func _say(unit: String, text: String) -> void:
    var r := world.get_node_or_null("Radio")
    if r != null:
        r.call("say", unit, text, true)

func _spawn() -> void:
    var pp := player.global_position
    var pos := Vector3.ZERO
    var ok := false
    for k in range(25):
        var i := randi_range(-3, 3)
        var j := randi_range(-3, 2)
        pos = Vector3(24.0 * float(i) + 2.0, 0.0, 24.0 * float(j) + 12.0)
        var d := Vector2(pos.x - pp.x, pos.z - pp.z).length()
        if d > 40.0 and d < 115.0:
            ok = true
            break
    if not ok:
        timer = 10.0
        return
    var a = world.call("_create_car", pos + Vector3(-1.0, 0.0, 0.0), Color(0.8, 0.2, 0.2), 0.5)
    var b = world.call("_create_car", pos + Vector3(1.4, 0.0, -3.8), Color(0.2, 0.3, 0.8), -1.2)
    nodes.append(a)
    nodes.append(b)
    var l := OmniLight3D.new()
    l.light_color = Color(1.0, 0.6, 0.15)
    l.omni_range = 9.0
    l.light_energy = 0.0
    world.add_child(l)
    l.global_position = pos + Vector3(0, 1.6, -1.5)
    lights.append(l)
    nodes.append(l)
    var p := CPUParticles3D.new()
    p.amount = 40
    p.lifetime = 2.6
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    p.emission_sphere_radius = 0.25
    p.direction = Vector3(0, 1, 0)
    p.spread = 25.0
    p.initial_velocity_min = 0.8
    p.initial_velocity_max = 1.5
    p.gravity = Vector3(0, 0.4, 0)
    p.scale_amount_min = 0.7
    p.scale_amount_max = 1.5
    var sm := SphereMesh.new()
    sm.radius = 0.25
    sm.height = 0.5
    sm.radial_segments = 8
    sm.rings = 4
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.vertex_color_use_as_albedo = true
    sm.material = m
    p.mesh = sm
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(0.35, 0.35, 0.35, 0.6), Color(0.6, 0.6, 0.6, 0.0)])
    g.offsets = PackedFloat32Array([0.0, 1.0])
    p.color_ramp = g
    world.add_child(p)
    p.global_position = pos + Vector3(-1.0, 1.0, -0.8)
    nodes.append(p)
    active_pos = pos
    last_incident_pos = pos
    state = "active"
    active_t = 0.0
    secure_t = 0.0
    arrived = false
    var place := "the avenue"
    var cr := world.get_node_or_null("Crime")
    if cr != null:
        place = String(cr.call("near_name", pos))
    _say("Dispatch", "Unit 7, 10-50 traffic collision near %s. Injuries reported. Respond code 3. Over." % place)
    Sfx.play(self, "crash", -10.0)

func _cleanup(list: Array) -> void:
    for n in list:
        if is_instance_valid(n):
            n.queue_free()

func _resolve(success: bool) -> void:
    if success:
        _say("Unit 7", "Scene secured. Requesting ambulance and tow. Over.")
        get_tree().create_timer(2.5).timeout.connect(_medics)
        var cr := world.get_node_or_null("Crime")
        if cr != null:
            cr.call("add_coins", 120)
        var gp := world.get_node_or_null("Gameplay")
        if gp != null:
            gp.call("_notice", "Scene secured! +120 dinars")
    else:
        _say("Dispatch", "Unit 8 took the collision call. Resume patrol.")
    for l in lights:
        l.light_energy = 0.0
    var all := nodes.duplicate()
    nodes.clear()
    lights.clear()
    get_tree().create_timer(14.0).timeout.connect(_cleanup.bind(all))
    state = "idle"
    active_pos = null
    timer = randf_range(180.0, 260.0)

func _spawn_ambulance(pos: Vector3) -> void:
    var spawned = KenneyKit.car_named("ambulance")
    if spawned == null:
        _say("Dispatch", "Ambulance model unavailable. Medical response remains pending.")
        return

    var ambulance := Node3D.new()
    ambulance.name = "EmergencyAmbulance"
    ambulance.position = pos + Vector3(0.0, 0.0, -10.0)
    world.add_child(ambulance)
    ambulance.add_child(spawned["node"])

    var dimensions: Vector3 = spawned["size"]
    var roof_y := maxf(dimensions.y, 1.4) + 0.18

    # Visible red and blue roof beacons.
    for i in range(2):
        var red_side := i == 0
        var beacon := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(0.34, 0.16, 0.24)
        beacon.mesh = mesh

        var material := StandardMaterial3D.new()
        var beacon_color := Color(1.0, 0.035, 0.025) if red_side else Color(0.025, 0.18, 1.0)
        material.albedo_color = beacon_color
        material.emission_enabled = true
        material.emission = beacon_color
        material.emission_energy_multiplier = 2.5
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        beacon.material_override = material
        beacon.position = Vector3(-0.38 if red_side else 0.38, roof_y, 0.0)
        ambulance.add_child(beacon)

        var lamp := OmniLight3D.new()
        lamp.light_color = beacon_color
        lamp.omni_range = 13.0
        lamp.light_energy = 0.0
        lamp.shadow_enabled = false
        lamp.position = beacon.position + Vector3(0.0, 0.25, 0.0)
        ambulance.add_child(lamp)
        medic_lights.append(lamp)

    # The siren is spatial and follows the ambulance.
    var siren := AudioStreamPlayer3D.new()
    siren.name = "AmbulanceSiren"
    siren.stream = Sfx.get_sound("siren")
    siren.volume_db = -9.0
    siren.max_distance = 65.0
    siren.unit_size = 10.0
    ambulance.add_child(siren)
    siren.play()

    medic_blink = 0.0
    get_tree().create_timer(24.0).timeout.connect(
        _remove_ambulance.bind(ambulance)
    )

func _remove_ambulance(ambulance: Node3D) -> void:
    if is_instance_valid(ambulance):
        ambulance.queue_free()
    medic_lights.clear()
    medic_blink = 0.0

func _medics() -> void:
    _say("Dispatch", "Copy. Ambulance 12 dispatched to the collision. Good work, Unit 7.")
    _spawn_ambulance(last_incident_pos)
    _say("Medic 12", "Medical team on scene. Beginning patient assessment. Over.")

func _process(delta: float) -> void:
    if world == null or player == null:
        return

    medic_blink += delta
    for i in range(medic_lights.size()):
        var medic_light: OmniLight3D = medic_lights[i]
        if is_instance_valid(medic_light):
            medic_light.light_energy = 3.5 if (int(medic_blink * 4.0) + i) % 2 == 0 else 0.0

    if state == "idle":
        timer -= delta
        if timer <= 0.0:
            _spawn()
        return
    active_t += delta
    blink += delta
    for l in lights:
        l.light_energy = 2.5 if int(blink * 2.0) % 2 == 0 else 0.0
    var pp := player.global_position
    var d := Vector2(pp.x - active_pos.x, pp.z - active_pos.z).length()
    if d < 10.0:
        if not arrived:
            arrived = true
            _say("Unit 7", "On scene, assessing. Over.")
        secure_t += delta
        if secure_t >= 6.0:
            _resolve(true)
            return
    else:
        secure_t = maxf(0.0, secure_t - delta)
    if active_t > 170.0:
        _resolve(false)
