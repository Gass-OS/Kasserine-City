extends Node

var world: Node
var dn: Node
var acc := 0.0
var night := 0.0
# v0.4.2: real night light from the street lamps. 98 lamp posts exist
# but a mobile GPU cannot run 98 OmniLights, so a pool of 6 follows
# the player — the 6 lamps nearest the player get a real light pool.
# Like the headlights below, these lights are NEVER toggled visible /
# invisible (a visibility switch is a render-state change); only their
# energy fades, and they never cast shadows.
const LAMP_LIGHT_COUNT := 6
const LAMP_LIGHT_ENERGY := 2.2
const LAMP_LIGHT_RANGE := 14.0
var lamp_lights: Array[OmniLight3D] = []
var lamp_logged := false
# v0.4.4: the window/glow materials are only rewritten when `night`
# actually moved. Before, they were rewritten every 0.3 s even with a
# perfectly steady day (night = 0) — hundreds of redundant material
# writes a minute on the render server for zero visual change.
var _last_night_applied := -1.0

func _ready() -> void:
    world = get_parent()
    dn = world.get_node_or_null("DayNight")
    for i in range(LAMP_LIGHT_COUNT):
        var l := OmniLight3D.new()
        l.name = "LampLight%d" % i
        l.omni_range = LAMP_LIGHT_RANGE
        l.omni_attenuation = 1.2
        l.light_color = Color(1.0, 0.82, 0.5)
        l.light_energy = 0.0
        l.shadow_enabled = false
        # Parent to night_glow itself (not the world): _ready runs while
        # the scene is still being set up, and world.add_child() fails
        # then ("Parent node is busy setting up children") — the 6
        # lights were silently never added to the tree. night_glow sits
        # at the world origin with no transform, so global_position
        # behaves exactly as before.
        add_child(l)
        lamp_lights.append(l)

func _process(delta: float) -> void:
    acc += delta
    if acc < 0.3 or dn == null or not is_instance_valid(dn):
        return
    acc = 0.0
    var t: float = dn.t
    var day := clampf(sin((t - 0.25) * TAU) * 2.5 + 0.35, 0.0, 1.0)
    night = 1.0 - day
    var mats = world.get("glow_materials")
    # v0.4.4: only touch the materials when `night` actually moved —
    # a steady day (night = 0) used to rewrite every window material
    # every 0.3 s for nothing. Headlights / lamps below still update
    # every tick (they follow the player), only the material loop is
    # guarded.
    if mats != null and absf(night - _last_night_applied) > 0.001:
        _last_night_applied = night
        for m in mats:
            # v0.4.1: harden — a freed material must never kill the frame.
            if m == null or not is_instance_valid(m):
                continue
            if m.has_meta("pool"):
                var n := night * 0.55
                m.albedo_color = Color(1.0 * n, 0.78 * n, 0.45 * n, 1.0)
            else:
                m.emission_energy_multiplier = float(m.get_meta("glow", 1.0)) * night
    var player := world.get_node_or_null("Player") as Node3D
    var items: Array = []
    for l in get_tree().get_nodes_in_group("car_headlight"):
        if l == null or not is_instance_valid(l):
            continue
        var d := 9999.0
        if player != null:
            d = (l as Node3D).global_position.distance_to(player.global_position)
        items.append([d, l])
    items.sort_custom(func(a, b): return a[0] < b[0])
    for i in range(items.size()):
        var spot := items[i][1] as SpotLight3D
        if spot == null or not is_instance_valid(spot):
            continue
        # v0.4.2 FREEZE FIX: headlights used to toggle visible on/off
        # when night crossed 0.25 (up to 4 lights switching in one
        # frame at the transition). They now stay visible forever and
        # only the energy ramps smoothly — no render-state switch.
        if not spot.visible:
            spot.visible = true
        var on: bool = night > 0.25 and i < 4 and items[i][0] < 45.0
        var target := 0.0
        if on:
            target = 3.0 * clampf((night - 0.25) / 0.25, 0.0, 1.0)
        spot.light_energy = target
    _update_lamp_lights(player)

func _update_lamp_lights(player: Node3D) -> void:
    if lamp_lights.is_empty():
        return
    var positions: Array = world.get("lamp_positions") if world != null else []
    if positions == null or positions.is_empty():
        return
    # 6 lamps nearest the player get the real lights.
    var scored: Array = []
    for p in positions:
        var d := 9999.0
        if player != null:
            d = (p as Vector3).distance_to(player.global_position)
        scored.append([d, p])
    scored.sort_custom(func(a, b): return a[0] < b[0])
    for i in range(lamp_lights.size()):
        var l := lamp_lights[i]
        if l == null or not is_instance_valid(l):
            continue
        if i < scored.size():
            l.global_position = scored[i][1]
            l.light_energy = LAMP_LIGHT_ENERGY * night
        else:
            l.light_energy = 0.0
    if night > 0.5 and not lamp_logged:
        lamp_logged = true
        print("[NIGHT] lamps on: %d real lights near player" % mini(LAMP_LIGHT_COUNT, scored.size()))
    elif night <= 0.5:
        lamp_logged = false
