extends Node

const BLOCKS = [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-2, -1)]

func _ready() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    var world := get_parent()
    var citizens = world.get("citizens")
    var routes = world.get("citizen_routes")
    var idx = world.get("citizen_route_indices")
    var speeds = world.get("citizen_speeds")
    var waits = world.get("citizen_waits")
    if citizens == null or routes == null or idx == null or speeds == null or waits == null:
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = 5150
    for i in range(1, citizens.size()):
        var b: Vector2i = BLOCKS[(i - 1) % BLOCKS.size()]
        var pts := _loop(b.x, b.y, rng.randf() < 0.5, rng.randi() % 4)
        routes[i] = pts
        idx[i] = 1
        speeds[i] = rng.randf_range(1.3, 1.8)
        waits[i] = rng.randf_range(0.0, 2.0)
        citizens[i].position = pts[0]

func _loop(bi: int, bj: int, clockwise: bool, start: int) -> Array:
    var ax := bi * 24.0
    var bz := bj * 24.0
    var lo := 4.9
    var hi := 19.1
    var pts: Array = [Vector3(ax + lo, 0, bz + lo), Vector3(ax + hi, 0, bz + lo), Vector3(ax + hi, 0, bz + hi), Vector3(ax + lo, 0, bz + hi)]
    if not clockwise:
        pts.reverse()
    var out: Array = []
    for k in range(pts.size()):
        out.append(pts[(k + start) % pts.size()])
    return out
