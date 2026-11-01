extends Node

const KenneyKit = preload("res://scripts/kenney.gd")

var world: Node3D

func _ready() -> void:
    for i in range(3):
        await get_tree().process_frame
    world = get_parent() as Node3D
    if world == null:
        return
    for ch in world.get_children():
        _try(ch)
    world.child_entered_tree.connect(_on_child)

func _on_child(n: Node) -> void:
    call_deferred("_late", n)

func _late(n: Node) -> void:
    if is_instance_valid(n):
        _try(n)

func _try(n: Node) -> void:
    if not (n is Node3D):
        return
    if not String(n.name).begins_with("ParkedCar"):
        return
    if n.get_node_or_null("Hull") != null:
        return
    var a := KenneyKit._aabb(n as Node3D)
    var size := Vector3(1.9, 1.4, 4.4)
    var center := Vector3(0.0, 0.75, 0.0)
    if a.size.x > 0.5 and a.size.z > 0.5:
        size = Vector3(a.size.x * 0.92, a.size.y, a.size.z * 0.95)
        center = a.position + a.size * 0.5
    var body := StaticBody3D.new()
    body.name = "Hull"
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    body.position = center
    n.add_child(body)
