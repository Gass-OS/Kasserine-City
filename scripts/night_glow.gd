extends Node

var world: Node
var dn: Node
var acc := 0.0
var night := 0.0

func _ready() -> void:
    world = get_parent()
    dn = world.get_node_or_null("DayNight")

func _process(delta: float) -> void:
    acc += delta
    if acc < 0.3 or dn == null:
        return
    acc = 0.0
    var t: float = dn.t
    var day := clampf(sin((t - 0.25) * TAU) * 2.5 + 0.35, 0.0, 1.0)
    night = 1.0 - day
    var mats = world.get("glow_materials")
    if mats != null:
        for m in mats:
            if m.has_meta("pool"):
                var n := night * 0.55
                m.albedo_color = Color(1.0 * n, 0.78 * n, 0.45 * n, 1.0)
            else:
                m.emission_energy_multiplier = float(m.get_meta("glow", 1.0)) * night
    var player := world.get_node_or_null("Player") as Node3D
    var items: Array = []
    for l in get_tree().get_nodes_in_group("car_headlight"):
        var d := 9999.0
        if player != null:
            d = (l as Node3D).global_position.distance_to(player.global_position)
        items.append([d, l])
    items.sort_custom(func(a, b): return a[0] < b[0])
    for i in range(items.size()):
        var spot := items[i][1] as SpotLight3D
        var on: bool = night > 0.25 and i < 4 and items[i][0] < 45.0
        spot.light_energy = 3.0 * night if on else 0.0
        spot.visible = on

    var lamp_items: Array = []
    for light_node in get_tree().get_nodes_in_group("street_lamp_light"):
        var lamp_light := light_node as OmniLight3D
        if lamp_light == null:
            continue
        var distance := 9999.0
        if player != null:
            distance = lamp_light.global_position.distance_to(player.global_position)
        lamp_items.append([distance, lamp_light])
    lamp_items.sort_custom(func(a, b): return a[0] < b[0])
    for i in range(lamp_items.size()):
        var street_light := lamp_items[i][1] as OmniLight3D
        var lamp_on: bool = night > 0.25 and i < 14 and lamp_items[i][0] < 65.0
        street_light.light_energy = 1.35 * night if lamp_on else 0.0
        street_light.visible = lamp_on
