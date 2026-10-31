extends Node

const STEPS = [
    {"text": "Visit the School", "pos": Vector3(-36, 0, -36), "night": false},
    {"text": "Check the Police station", "pos": Vector3(36, 0, -36), "night": false},
    {"text": "Visit the Hospital", "pos": Vector3(-36, 0, 36), "night": false},
    {"text": "Meet at the Cafe after dark", "pos": Vector3(36, 0, 36), "night": true},
]

var world: Node
var gp
var player: Node3D
var dn
var step := 0
var started := false
var done := false
var coins := 0
var marker: MeshInstance3D
var coin_label: Label
var acc := 0.0

func _ready() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    world = get_parent()
    gp = world.get_node_or_null("Gameplay")
    player = world.get_node_or_null("Player") as Node3D
    dn = world.get_node_or_null("DayNight")
    marker = MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 1.2
    cm.bottom_radius = 1.2
    cm.height = 40.0
    cm.radial_segments = 16
    marker.mesh = cm
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color = Color(1.0, 0.85, 0.3, 0.3)
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    marker.material_override = m
    marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    marker.visible = false
    world.add_child(marker)
    var layer := CanvasLayer.new()
    layer.layer = 20
    add_child(layer)
    coin_label = Label.new()
    coin_label.add_theme_font_size_override("font_size", 22)
    coin_label.add_theme_constant_override("outline_size", 6)
    coin_label.add_theme_color_override("font_outline_color", Color.BLACK)
    coin_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    coin_label.position = Vector2(get_viewport().get_visible_rect().size.x - 190.0, 100.0)
    coin_label.visible = false
    layer.add_child(coin_label)

func _process(delta: float) -> void:
    if gp == null or player == null or done or marker == null:
        return
    if int(gp.mission) < 4:
        return
    if not started:
        started = true
        gp._notice("New missions unlocked! Explore the whole city.")
        coin_label.visible = true
        coin_label.text = "Dinars: 0"
    var s: Dictionary = STEPS[step]
    var target: Vector3 = s["pos"]
    marker.visible = true
    marker.global_position = target + Vector3(0, 20, 0)
    var dx: float = player.global_position.x - target.x
    var dz: float = player.global_position.z - target.z
    var dist := Vector2(dx, dz).length()
    var night_ok: bool = (not s["night"]) or (dn != null and dn.is_night())
    acc += delta
    if acc > 0.25:
        acc = 0.0
        if night_ok:
            gp.objective.text = "OBJECTIVE: %s (%d m)" % [s["text"], int(dist)]
        else:
            gp.objective.text = "OBJECTIVE: Wait for night, then go to the Cafe (%d m)" % int(dist)
    if dist < 7.0 and night_ok:
        coins += 100
        coin_label.text = "Dinars: %d" % coins
        step += 1
        if step >= STEPS.size():
            done = true
            marker.visible = false
            gp.objective.text = "ALL MISSIONS COMPLETED - explore freely!"
            gp._notice("All missions complete! Total: %d dinars" % coins)
        else:
            gp._notice("Mission complete! +100 dinars")
