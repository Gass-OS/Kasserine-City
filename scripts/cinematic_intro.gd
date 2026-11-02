extends CanvasLayer

var overlay: Control
var shade: ColorRect
var finished := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build()
    if is_instance_valid(Watchdog):
        Watchdog.record("CINEMATIC: started")
    call_deferred("_run_intro")

func _build() -> void:
    overlay = Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(overlay)

    shade = ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.012, 0.018, 0.035, 1.0)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(shade)

    var top_bar := ColorRect.new()
    top_bar.color = Color.BLACK
    top_bar.anchor_right = 1.0
    top_bar.offset_bottom = 30.0
    top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(top_bar)

    var bottom_bar := ColorRect.new()
    bottom_bar.color = Color.BLACK
    bottom_bar.anchor_top = 1.0
    bottom_bar.anchor_right = 1.0
    bottom_bar.anchor_bottom = 1.0
    bottom_bar.offset_top = -30.0
    bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(bottom_bar)

func _run_intro() -> void:
    var fade := create_tween()
    fade.tween_property(shade, "color:a", 0.12, 0.9)
    await fade.finished

    if finished:
        return

    await get_tree().create_timer(1.5).timeout

    if not finished:
        await _finish()

func _finish() -> void:
    if finished:
        return

    finished = true
    var fade := create_tween()
    fade.tween_property(overlay, "modulate:a", 0.0, 0.65)
    await fade.finished

    if is_instance_valid(Watchdog):
        Watchdog.record("CINEMATIC: finished")

    queue_free()
