extends CanvasLayer

# Additive opening cinematic. Existing menu/gameplay remain intact; intro can be skipped.
var overlay: Control
var shade: ColorRect
var card: VBoxContainer
var eyebrow: Label
var headline: Label
var description: Label
var finished := false

const CARDS := [
    {"eyebrow": "GASS-OS ORIGINAL • TUNISIA", "title": "THE WEST AWAKENS", "body": "Beneath the mountains of western Tunisia, a new day begins."},
    {"eyebrow": "KASSERINE • A LAND WITH MEMORY", "title": "HISTORY LIVES HERE", "body": "The wider region carries traces of ancient North African and Roman-era life. In February 1943, the Kasserine Pass became the site of a major World War II battle."},
    {"eyebrow": "YOUR STORY STARTS HERE", "title": "WELCOME TO KASSERINE", "body": "Meet the people. Explore the market. Discover the stories of everyday life."}
]

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build()
    call_deferred("_run_intro")

func _build() -> void:
    overlay = Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)
    shade = ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.012, 0.018, 0.035, 1.0)
    overlay.add_child(shade)

    var top_bar := ColorRect.new()
    top_bar.color = Color.BLACK
    top_bar.anchor_right = 1.0
    top_bar.offset_bottom = 36.0
    overlay.add_child(top_bar)
    var bottom_bar := ColorRect.new()
    bottom_bar.color = Color.BLACK
    bottom_bar.anchor_top = 1.0
    bottom_bar.anchor_right = 1.0
    bottom_bar.anchor_bottom = 1.0
    bottom_bar.offset_top = -36.0
    overlay.add_child(bottom_bar)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.offset_left = 24.0
    center.offset_right = -24.0
    overlay.add_child(center)
    card = VBoxContainer.new()
    card.add_theme_constant_override("separation", 18)
    card.modulate.a = 0.0
    center.add_child(card)
    eyebrow = _label("", 16, Color(1.0, 0.56, 0.30))
    headline = _label("", 46, Color(1.0, 0.84, 0.50))
    description = _label("", 22, Color(0.91, 0.93, 0.98))
    description.custom_minimum_size = Vector2(0, 100)
    card.add_child(eyebrow)
    card.add_child(headline)
    card.add_child(description)

    var skip := Button.new()
    skip.text = "SKIP INTRO  »"
    skip.anchor_left = 1.0
    skip.anchor_right = 1.0
    skip.offset_left = -184.0
    skip.offset_right = -18.0
    skip.offset_top = 48.0
    skip.offset_bottom = 96.0
    skip.custom_minimum_size = Vector2(166, 44)
    skip.pressed.connect(_finish)
    overlay.add_child(skip)
    var footer := _label("KASSERINE CITY  •  A WORLD IN PROGRESS", 12, Color(0.75, 0.78, 0.85))
    footer.anchor_top = 1.0
    footer.anchor_bottom = 1.0
    footer.offset_top = -31.0
    footer.offset_bottom = -8.0
    overlay.add_child(footer)

func _label(value: String, font_size: int, tint: Color) -> Label:
    var result := Label.new()
    result.text = value
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.add_theme_font_size_override("font_size", font_size)
    result.add_theme_color_override("font_color", tint)
    result.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    result.add_theme_constant_override("outline_size", 4)
    return result

func _run_intro() -> void:
    var fade := create_tween()
    fade.tween_property(shade, "color:a", 0.42, 0.9)
    await fade.finished
    if finished: return
    _narrate()
    for i in range(CARDS.size()):
        if finished: return
        var item: Dictionary = CARDS[i]
        await _show_card(str(item["eyebrow"]), str(item["title"]), str(item["body"]), 2.35 if i < 2 else 1.7)
    if not finished:
        await _finish()

func _show_card(kicker: String, title_text: String, body_text: String, hold: float) -> void:
    var out := create_tween()
    out.tween_property(card, "modulate:a", 0.0, 0.2)
    await out.finished
    if finished: return
    eyebrow.text = kicker
    headline.text = title_text
    description.text = body_text
    var incoming := create_tween()
    incoming.tween_property(card, "modulate:a", 1.0, 0.42)
    await incoming.finished
    if finished: return
    await get_tree().create_timer(hold).timeout

func _narrate() -> void:
    # Android device TTS is optional; intro remains usable without it.
    var voices := DisplayServer.tts_get_voices()
    if voices.is_empty(): return
    var chosen_id := ""
    for voice in voices:
        if str(voice.get("language", "")).to_lower().begins_with("en"):
            chosen_id = str(voice.get("id", ""))
            break
    if chosen_id.is_empty(): chosen_id = str(voices[0].get("id", ""))
    if not chosen_id.is_empty():
        DisplayServer.tts_speak("Beneath the mountains of western Tunisia, a new day begins. The wider region carries a deep history. Meet the people, explore the market, and begin your story in Kasserine.", chosen_id, 80, 1.0, 0.92, 71, true)

func _finish() -> void:
    if finished: return
    finished = true
    if DisplayServer.tts_is_speaking(): DisplayServer.tts_stop()
    var fade := create_tween()
    fade.tween_property(overlay, "modulate:a", 0.0, 0.45)
    await fade.finished
    queue_free()
