extends Node

const EXTRA := 24

func _ready() -> void:
    await get_tree().process_frame
    var world := get_parent()
    var citizens = world.get("citizens")
    var routes = world.get("citizen_routes")
    var idx = world.get("citizen_route_indices")
    var speeds = world.get("citizen_speeds")
    var waits = world.get("citizen_waits")
    if citizens == null or routes == null or idx == null or speeds == null or waits == null:
        return
    for k in range(EXTRA):
        var person := Node3D.new()
        person.name = "Citizen_%02d" % citizens.size()
        world.add_child(person)
        citizens.append(person)
        world.call("_human", person, citizens.size())
        routes.append([])
        idx.append(1)
        speeds.append(1.4)
        waits.append(0.0)
    var rng := RandomNumberGenerator.new()
    rng.seed = 5150
    for i in range(1, citizens.size()):
        var bi := rng.randi_range(-3, 2)
        var bj := rng.randi_range(-3, 2)
        var pts := _loop(bi, bj, rng.randf() < 0.5, rng.randi() % 4, rng)
        routes[i] = pts
        idx[i] = 1
        speeds[i] = rng.randf_range(1.2, 1.8)
        waits[i] = rng.randf_range(0.0, 3.0)
        citizens[i].position = pts[0]

func _loop(bi: int, bj: int, clockwise: bool, start: int, rng: RandomNumberGenerator) -> Array:
    var ax := float(bi) * 24.0
    var bz := float(bj) * 24.0
    var lo := rng.randf_range(4.7, 5.3)
    var hi := rng.randf_range(18.7, 19.3)
    var pts: Array = [Vector3(ax + lo, 0, bz + lo), Vector3(ax + hi, 0, bz + lo), Vector3(ax + hi, 0, bz + hi), Vector3(ax + lo, 0, bz + hi)]
    if not clockwise:
        pts.reverse()
    var out: Array = []
    for k in range(pts.size()):
        out.append(pts[(k + start) % pts.size()])
    return out
