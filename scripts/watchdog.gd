extends Node

const PATH := "user://session.json"

var t0 := 0.0
var acc := 0.0
var prev: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    t0 = Time.get_ticks_msec() / 1000.0
    _load_prev()
    _write(true)

func _load_prev() -> void:
    if not FileAccess.file_exists(PATH):
        return
    var f := FileAccess.open(PATH, FileAccess.READ)
    if f == null:
        return
    var data = JSON.parse_string(f.get_as_text())
    f.close()
    if typeof(data) == TYPE_DICTIONARY and bool(data.get("alive", false)):
        prev = data
        _show_notice()

func _fmt(d: Dictionary) -> String:
    var s := int(d.get("secs", 0))
    return "%dm%02ds | game %s | FPS %d | RAM %d MB | VRAM %d MB | objects %d | nodes %d | weather %s" % [s / 60, s % 60, str(d.get("game", "-")), int(d.get("fps", 0)), int(d.get("ram", 0)), int(d.get("vram", 0)), int(d.get("objects", 0)), int(d.get("nodes", 0)), str(d.get("weather", "-"))]

func _show_notice() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 128
    add_child(layer)
    var l := Label.new()
    l.position = Vector2(20, 600)
    l.text = "Previous session ended unexpectedly:\n" + _fmt(prev)
    l.add_theme_font_size_override("font_size", 15)
    l.add_theme_constant_override("outline_size", 6)
    l.add_theme_color_override("font_outline_color", Color.BLACK)
    l.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
    layer.add_child(l)
    get_tree().create_timer(30.0).timeout.connect(layer.queue_free)

func _stats(alive: bool) -> Dictionary:
    var gt := "-"
    var weather := "-"
    var scene := get_tree().current_scene
    if scene != null:
        var dn = scene.get_node_or_null("DayNight")
        if dn != null:
            var tt: float = dn.get("t")
            gt = "%02d:%02d" % [int(tt * 24.0), int(fmod(tt * 24.0, 1.0) * 60.0)]
        var w = scene.get_node_or_null("Weather")
        if w != null:
            weather = str(w.get("state"))
    return {
        "alive": alive,
        "secs": int(Time.get_ticks_msec() / 1000.0 - t0),
        "game": gt,
        "fps": int(Engine.get_frames_per_second()),
        "ram": int(OS.get_static_memory_usage() / 1048576),
        "vram": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576),
        "objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
        "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
        "weather": weather,
    }

func _write(alive: bool) -> void:
    var f := FileAccess.open(PATH, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify(_stats(alive)))
    f.close()

func _process(delta: float) -> void:
    acc += delta
    if acc > 4.0:
        acc = 0.0
        _write(true)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _write(false)
    elif what == NOTIFICATION_APPLICATION_RESUMED:
        _write(true)
