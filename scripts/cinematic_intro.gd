extends CanvasLayer

# Additive boot + story cinematic. Existing menu, world, missions and controls stay intact.
# Lightweight UI animation for Android; player can skip at any time.
var overlay: Control
var shade: ColorRect
var card: VBoxContainer
var eyebrow: Label
var headline: Label
var description: Label
var boot_box: VBoxContainer
var boot_status: Label
var boot_progress: ProgressBar
var finished := false

const BOOT_LINES := [
    "GASS-OS • KASSERINE CITY",
    "Checking city systems ........ OK",
    "Loading streets and districts .. OK",
    "Preparing traffic and citizens . OK",
    "Radio network .................. ONLINE",
    "Officer Amar ................... ON DUTY"
]

const CARDS := [
    {"eyebrow": "WESTERN TUNISIA • 06:12 AM", "title": "A CITY WAKES", "body": "Sunrise touches the mountains around Kasserine. Shop shutters rise, engines start, and the streets slowly come alive."},
    {"eyebrow": "MEET YOUR OFFICER", "title": "AMAR IS ON DUTY", "body": "Amar wakes before the city gets busy. He puts on his uniform, checks his equipment, and prepares for another unpredictable day on the roads."},
    {"eyebrow": "RADIO ALERT • DISPATCH", "title": "WE HAVE A PROBLEM", "body": "A call breaks the morning quiet. Traffic is building, residents need help, and another incident has been reported nearby. Amar heads out."},
    {"eyebrow": "YOUR SHIFT STARTS NOW", "title": "KASSERINE NEEDS YOU", "body": "Patrol the streets, respond to local problems, help people, and discover the lives behind every doorway. Every shift can bring a different story."}
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
    top_bar.offset_bottom = 30.0
    overlay.add_child(top_bar)

    var bottom_bar := ColorRect.new()
    bottom_bar.color = Color.BLACK
    bottom_bar.anchor_top = 1.0
    bottom_bar.anchor_right = 1.0
    bottom_bar.anchor_bottom = 1.0
    bottom_bar.offset_top = -30.0
    overlay.add_child(bottom_bar)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.offset_left = 24.0
    center.offset_right = -24.0
    overlay.add_child(center)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 22)
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.add_child(stack)

    boot_box = VBoxContainer.new()
    boot_box.add_theme_constant_override("separation", 10)
    stack.add_child(boot_box)
    boot_box.add_child(_label("GASS-OS", 22, Color(0.62, 0.78, 1.0)))
    boot_status = _label("INITIALIZING KASSERINE CITY", 25, Color(1.0, 0.84, 0.50))
    boot_box.add_child(boot_status)

    boot_progress = ProgressBar.new()
    boot_progress.custom_minimum_size = Vector2(0, 12)
    boot_progress.min_value = 0.0
    boot_progress.max_value = float(BOOT_LINES.size())
    boot_progress.value = 0.0
    boot_progress.show_percentage = false
    boot_box.add_child(boot_progress)

    card = VBoxContainer.new()
    card.add_theme_constant_override("separation", 18)
    card.modulate.a = 0.0
    stack.add_child(card)
    eyebrow = _label("", 16, Color(1.0, 0.56, 0.30))
    headline = _label("", 42, Color(1.0, 0.84, 0.50))
    description = _label("", 21, Color(0.91, 0.93, 0.98))
    description.custom_minimum_size = Vector2(0, 110)
    card.add_child(eyebrow)
    card.add_child(headline)
    card.add_child(description)

    var skip := Button.new()
    skip.text = "SKIP INTRO  »"
    skip.anchor_left = 1.0
    skip.anchor_right = 1.0
    skip.offset_left = -184.0
    skip.offset_right = -18.0
    skip.offset_top = 42.0
    skip.offset_bottom = 88.0
    skip.custom_minimum_size = Vector2(166, 44)
    skip.pressed.connect(_finish)
    overlay.add_child(skip)

    var footer := _label("KASSERINE CITY  •  AN OPEN-WORLD STORY", 12, Color(0.75, 0.78, 0.85))
    footer.anchor_top = 1.0
    footer.anchor_bottom = 1.0
    footer.offset_top = -27.0
    footer.offset_bottom = -6.0
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
    fade.tween_property(shade, "color:a", 0.12, 0.7)
    await fade.finished
    if finished:
        return

    for i in range(BOOT_LINES.size()):
        if finished:
            return
        boot_status.text = BOOT_LINES[i]
        boot_progress.value = i + 1
        await get_tree().create_timer(0.30).timeout

    await get_tree().create_timer(0.25).timeout
    if finished:
        return
    boot_box.hide()
    _narrate()

    for i in range(CARDS.size()):
        if finished:
            return
        var item: Dictionary = CARDS[i]
        await _show_card(str(item["eyebrow"]), str(item["title"]), str(item["body"]), 2.15 if i < 3 else 1.8)

    if not finished:
        await _finish()

func _show_card(kicker: String, title_text: String, body_text: String, hold: float) -> void:
    var out := create_tween()
    out.tween_property(card, "modulate:a", 0.0, 0.18)
    await out.finished
    if finished:
        return
    eyebrow.text = kicker
    headline.text = title_text
    description.text = body_text
    var incoming := create_tween()
    incoming.tween_property(card, "modulate:a", 1.0, 0.38)
    await incoming.finished
    if finished:
        return
    await get_tree().create_timer(hold).timeout

func _narrate() -> void:
    # Android device text-to-speech is optional; story text stays visible without it.
    var voices := DisplayServer.tts_get_voices()
    if voices.is_empty():
        return
    var chosen_id := ""
    for voice in voices:
        if str(voice.get("language", "")).to_lower().begins_with("en"):
            chosen_id = str(voice.get("id", ""))
            break
    if chosen_id.is_empty():
        chosen_id = str(voices[0].get("id", ""))
    if not chosen_id.is_empty():
        DisplayServer.tts_speak("Sunrise comes to Kasserine. Officer Amar wakes, prepares for duty, and receives a radio alert. Traffic is building and people need help. Patrol the streets, solve local problems, and shape the story of your city.", chosen_id, 80, 1.0, 0.92, 71, true)

func _finish() -> void:
    if finished:
        return
    finished = true
    if DisplayServer.tts_is_speaking():
        DisplayServer.tts_stop()
    var fade := create_tween()
    fade.tween_property(overlay, "modulate:a", 0.0, 0.45)
    await fade.finished
    queue_free()
