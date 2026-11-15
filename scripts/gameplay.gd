extends Node

var player: CharacterBody3D
var world: Node3D
var mission := 0
var panel: PanelContainer
var info: Label
var objective: Label
var minimap: Label
var notice: Label
var notice_time := 0.0
var chatter_time := 7.0
var bubble_time := 0.0
var speech_bubbles: Array[Label3D] = []
var voice_enabled := true
var sensitivity_slider: HSlider
var voice_toggle: CheckBox
var exit_button: Button
var exit_armed := false
var radio_panel: PanelContainer
var radio_log: Label
var radio_lines: Array[String] = []
var radio_timer := 12.0
var blip_player: AudioStreamPlayer
var blip_playback: AudioStreamGeneratorPlayback
var blip_frames_left := 0
var blip_phase := 0.0
var score := 0

const RADIO_LINES_EN = [
    "Unit 2, all clear at the market.",
    "Patrol 5, check the garage area.",
    "Need backup near the square.",
    "Traffic is heavy on Avenue Bourguiba.",
    "Unit 7 reporting, everything quiet.",
    "Copy that, heading to the hospital.",
    "Suspicious person near the cafe, keep an eye out.",
]
const RADIO_LINES_FR = [
    "Unité 2, tout est calme au marché.",
    "Patrouille 5, vérifiez le garage.",
    "Besoin de renfort près de la place.",
    "Circulation dense avenue Bourguiba.",
    "Unité 7, tout est calme.",
    "Bien reçu, direction l'hôpital.",
    "Personne suspecte près du café, restez vigilants.",
]
const RADIO_LINES_AR = [
    "الوحدة ٢، كل شيء هادئ في السوق.",
    "الدورية ٥، تفقدوا منطقة المرآب.",
    "نحتاج دعمًا قرب الساحة.",
    "المرور مزدحم في شارع بورقيبة.",
    "الوحدة ٧، كل شيء هادئ.",
    "تم الاستلام، متوجه إلى المستشفى.",
    "شخص مشبوه قرب المقهى، انتبهوا.",
]

const TARGETS = [
    Vector3(3, 0, 7),
    Vector3(-24, 0, 0),
    Vector3(24, 0, 0),
    Vector3(3, 0, 7)
]
const TASKS = [
    "Talk to Amine using USE",
    "Explore the market",
    "Visit the garage",
    "Return to Amine"
]
const CITIZEN_LINES = [
    "Aslema! Welcome to Kasserine.",
    "The market is just down the road.",
    "Have you visited the garage today?",
    "Beautiful day in Kasserine!",
    "Drive carefully around the city.",
    "I heard there is more to explore outside town."
]
const NPC_CHAT = [
    "Chnowa ahwelek?",
    "Labes, hamdoullah!",
    "The market is busy today.",
    "See you later, sahbi!",
    "Let's meet near the square."
]

func _ready():
    # Always process so the Android back button is caught even while the
    # game is paused by the pause menu.
    process_mode = Node.PROCESS_MODE_ALWAYS
    world = get_parent()
    player = world.get_node("Player")
    player.look_sensitivity = 0.008 * Settings.look_sensitivity
    _create_interface()
    _create_radio()
    _add_speech_bubbles()
    _update_objective()
    _notice("Welcome to Kasserine City!")
    _speak("Welcome to Kasserine City.")

func _create_radio() -> void:
    # Police walkie-talkie (v0.3): a log panel that never pauses the game.
    var layer = CanvasLayer.new()
    layer.layer = 21
    layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(layer)

    radio_panel = PanelContainer.new()
    radio_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    radio_panel.position = Vector2(-320, -160)
    radio_panel.custom_minimum_size = Vector2(640, 140)
    radio_panel.visible = false
    layer.add_child(radio_panel)

    var column = VBoxContainer.new()
    radio_panel.add_child(column)

    var title = Label.new()
    title.text = "📻 " + Settings.t("radio") + " — POLICE KASSERINE"
    title.add_theme_font_size_override("font_size", 20)
    column.add_child(title)

    radio_log = Label.new()
    radio_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    radio_log.add_theme_font_size_override("font_size", 18)
    column.add_child(radio_log)

    # Short two-tone radio blip, generated procedurally (no audio files).
    var gen := AudioStreamGenerator.new()
    gen.mix_rate = 22050
    gen.buffer_length = 0.2
    blip_player = AudioStreamPlayer.new()
    blip_player.stream = gen
    blip_player.volume_db = -14.0
    add_child(blip_player)
    blip_playback = blip_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _radio_lines() -> Array:
    match Settings.language:
        "fr":
            return RADIO_LINES_FR
        "ar":
            return RADIO_LINES_AR
        _:
            return RADIO_LINES_EN

func _radio_push_line() -> void:
    var lines := _radio_lines()
    var line: String = lines[randi() % lines.size()]
    radio_lines.append("• " + line)
    while radio_lines.size() > 4:
        radio_lines.remove_at(0)
    if is_instance_valid(radio_log):
        radio_log.text = "\n".join(radio_lines)
    # Two-tone blip: 0.07 s at 1250 Hz, then 0.07 s at 950 Hz.
    if blip_playback != null:
        blip_frames_left = int(0.14 * 22050)
        blip_phase = 0.0
        if not blip_player.playing:
            blip_player.play()

func _toggle_radio() -> void:
    radio_panel.visible = not radio_panel.visible
    if radio_panel.visible and radio_lines.is_empty():
        _radio_push_line()

func _create_interface():
    var layer = CanvasLayer.new()
    layer.layer = 20
    layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(layer)

    var menu = HBoxContainer.new()
    menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    menu.position = Vector2(-650, 12)
    menu.custom_minimum_size = Vector2(622, 56)
    layer.add_child(menu)

    for title in ["MENU", "HELP", "MISSIONS", "MAP", "RADIO"]:
        var button = Button.new()
        button.text = title
        button.custom_minimum_size = Vector2(118, 56)
        button.add_theme_font_size_override("font_size", 22)
        menu.add_child(button)
        button.pressed.connect(_open.bind(title))

    objective = Label.new()
    objective.position = Vector2(18, 68)
    objective.add_theme_font_size_override("font_size", 22)
    objective.add_theme_color_override("font_color", Color.YELLOW)
    layer.add_child(objective)

    minimap = Label.new()
    minimap.position = Vector2(18, 110)
    minimap.add_theme_font_size_override("font_size", 19)
    minimap.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(minimap)

    notice = Label.new()
    notice.position = Vector2(18, 250)
    notice.add_theme_font_size_override("font_size", 24)
    notice.add_theme_color_override("font_color", Color.YELLOW)
    layer.add_child(notice)

    panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.position = Vector2(-290, -215)
    panel.custom_minimum_size = Vector2(580, 430)
    panel.visible = false
    layer.add_child(panel)

    var column = VBoxContainer.new()
    panel.add_child(column)

    var heading = Label.new()
    heading.text = "KASSERINE CITY"
    heading.add_theme_font_size_override("font_size", 30)
    column.add_child(heading)

    info = Label.new()
    info.custom_minimum_size = Vector2(520, 150)
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_theme_font_size_override("font_size", 20)
    column.add_child(info)

    sensitivity_slider = HSlider.new()
    sensitivity_slider.min_value = 0.003
    sensitivity_slider.max_value = 0.020
    sensitivity_slider.step = 0.001
    sensitivity_slider.value = player.look_sensitivity
    sensitivity_slider.value_changed.connect(_set_sensitivity)
    sensitivity_slider.visible = false
    column.add_child(sensitivity_slider)

    voice_toggle = CheckBox.new()
    voice_toggle.text = "NPC voice (device TTS if available)"
    voice_toggle.button_pressed = voice_enabled
    voice_toggle.toggled.connect(_set_voice_enabled)
    voice_toggle.visible = false
    column.add_child(voice_toggle)

    var actions = HBoxContainer.new()
    column.add_child(actions)

    var resume = Button.new()
    resume.text = "RESUME / CLOSE"
    resume.custom_minimum_size = Vector2(180, 60)
    resume.add_theme_font_size_override("font_size", 20)
    resume.pressed.connect(_resume_game)
    actions.add_child(resume)

    var settings = Button.new()
    settings.text = "SETTINGS"
    settings.custom_minimum_size = Vector2(140, 60)
    settings.add_theme_font_size_override("font_size", 20)
    settings.pressed.connect(_open.bind("SETTINGS"))
    actions.add_child(settings)

    exit_button = Button.new()
    exit_button.text = "EXIT"
    exit_button.custom_minimum_size = Vector2(120, 60)
    exit_button.add_theme_font_size_override("font_size", 20)
    exit_button.pressed.connect(_exit_game)
    actions.add_child(exit_button)

    var to_menu = Button.new()
    to_menu.text = "MAIN MENU"
    to_menu.custom_minimum_size = Vector2(140, 60)
    to_menu.add_theme_font_size_override("font_size", 20)
    to_menu.pressed.connect(_to_main_menu)
    actions.add_child(to_menu)

func _notification(what: int) -> void:
    # Android back button: open the pause menu instead of closing the
    # game at once; a second press while the menu is open resumes.
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if panel != null and panel.visible:
            _resume_game()
        else:
            _open("MENU")

func _open(title: String):
    # RADIO is a live log, not a pause screen: it never pauses the game.
    if title == "RADIO":
        _toggle_radio()
        return
    _disarm_exit()
    panel.visible = true
    get_tree().paused = true
    sensitivity_slider.visible = title == "SETTINGS"
    voice_toggle.visible = title == "SETTINGS"

    match title:
        "MENU":
            info.text = "GAME PAUSED\n\nChoose RESUME to continue, SETTINGS to adjust controls and voice, or EXIT to close the game."
        "HELP":
            info.text = "CONTROLS\n\nLeft joystick: move\nDrag the right side: look around\nRUN: sprint    JUMP: jump\nUSE: talk to a nearby citizen\n\nThe camera should now stay steady when your character turns."
        "MISSIONS":
            info.text = "CURRENT MISSION\n\n" + _task_text() + "\n\nFollow the yellow MARKET and GARAGE signs. Use the USE button when near Amine."
        "MAP":
            info.text = "DISTRICT MAP — NORTH UP\n\nMARKET (-24, 0)  ←  SQUARE  →  GARAGE (24, 0)\n\nSTART / AMINE: (3, 7)\n\nYour position: X %.1f, Z %.1f" % [player.global_position.x, player.global_position.z]
        "SETTINGS":
            info.text = "SETTINGS\n\nCamera sensitivity\nUse the slider below. NPC voice uses the device text-to-speech service when supported; dialogue text remains available either way."

func _resume_game():
    panel.visible = false
    get_tree().paused = false
    _disarm_exit()

func _exit_game():
    # Quit needs a confirm tap: first tap arms the button, second quits.
    if not exit_armed:
        exit_armed = true
        exit_button.text = "SURE? TAP AGAIN"
        return
    get_tree().paused = false
    get_tree().quit()

func _disarm_exit() -> void:
    exit_armed = false
    if is_instance_valid(exit_button):
        exit_button.text = "EXIT"

func _set_sensitivity(value: float):
    player.look_sensitivity = value

func _set_voice_enabled(enabled: bool):
    voice_enabled = enabled

func _task_text() -> String:
    if mission >= TASKS.size():
        var mp := world.get_node_or_null("MissionsPlus")
        if mp != null and mp.started and not mp.done:
            var s: Dictionary = mp.STEPS[mp.step]
            return "%s — Dinars: %d" % [String(s["text"]), mp.coins]
        if mp != null and mp.done:
            return "All missions completed! Dinars: %d" % mp.coins
        return "All introductory missions completed!"
    return TASKS[mission]

func _update_objective():
    objective.text = "OBJECTIVE: " + _task_text()

func _notice(message: String):
    notice.text = message
    notice_time = 4.0

func _speak(message: String):
    if not voice_enabled:
        return
    var voices = DisplayServer.tts_get_voices()
    if voices.size() > 0:
        var voice_id = str(voices[0].get("id", ""))
        DisplayServer.tts_speak(message, voice_id, 1.0, 1.0, 1.0, 1, true)

func _add_speech_bubbles_old():
    if not world.has_method("_create_people"):
        return
    for citizen in world.citizens:
        var bubble = Label3D.new()
        bubble.font_size = 28
        bubble.position = Vector3(0, 2.8, 0)
        bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        bubble.modulate = Color(1.0, 0.92, 0.58)
        bubble.visible = false
        citizen.add_child(bubble)
        speech_bubbles.append(bubble)

func interact():
    var nearest: Node3D = null
    var nearest_distance := 999.0
    var nearest_index := -1
    for ci in range(world.citizens.size()):
        var citizen: Node3D = world.citizens[ci]
        var distance = player.global_position.distance_to(citizen.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = citizen
            nearest_index = ci

    # Night criminals (v0.3): USE arrests the nearest one.
    if nearest != null and nearest_distance < 4.5 and nearest_index >= 0:
        if world.criminal_active and world.arrest_criminal(nearest_index):
            score += 100
            var caught: int = world.criminals_caught_count()
            if caught >= 3:
                _notice(Settings.t("all_criminals_caught"))
            else:
                _notice(Settings.t("criminal_caught") % caught)
            _speak("Criminal arrested. Good work, officer.")
            return
        # Most wanted (v0.3): USE arrests the fugitive.
        var mp := world.get_node_or_null("MissionsPlus")
        if mp != null and mp.wanted_step_active() and nearest_index == world.wanted_index:
            world.arrest_wanted()
            mp.complete_wanted()
            score += 500
            _notice(Settings.t("wanted_caught"))
            _speak("Most wanted criminal arrested.")
            return

    if (mission == 0 or mission == 3) and player.global_position.distance_to(TARGETS[mission]) < 5.0:
        mission += 1
        _update_objective()
        _notice("Amine: " + ("Aslema! Let's explore the city." if mission == 1 else "Bravo! Mission complete."))
        _speak("Aslema! Welcome to Kasserine. Mission updated.")
        return

    if nearest != null and nearest_distance < 4.5:
        var line = CITIZEN_LINES[randi() % CITIZEN_LINES.size()]
        _notice("Citizen: " + line)
        _speak(line)
        return

    _notice("Move closer to Amine or another citizen and press USE.")

func _process(delta):
    if notice_time > 0.0:
        notice_time -= delta
        if notice_time <= 0.0:
            notice.text = ""

    minimap.text = "MINIMAP [NORTH UP]\nX: %.0f   Z: %.0f\nM: Market (-24, 0)\nG: Garage (24, 0)\nA: Amine (3, 7)" % [player.global_position.x, player.global_position.z]
    if world.criminal_active:
        minimap.text += "\nNight criminals caught: %d / 3" % world.criminals_caught_count()

    # Police radio chatter (v0.3): a new line every 20-40 s while playing.
    radio_timer -= delta
    if radio_timer <= 0.0:
        radio_timer = randf_range(20.0, 40.0)
        _radio_push_line()
    # Push the two-tone blip frames (1250 Hz, then 950 Hz).
    if blip_frames_left > 0 and blip_playback != null:
        var avail := blip_playback.get_frames_available()
        var n := mini(avail, blip_frames_left)
        for i in range(n):
            var f := 1250.0 if blip_phase < 0.07 * 22050.0 else 950.0
            var s := sin(TAU * f * blip_phase / 22050.0) * 0.5
            blip_playback.push_frame(Vector2(s, s))
            blip_phase += 1.0
        blip_frames_left -= n

    if mission == 1 or mission == 2:
        if player.global_position.distance_to(TARGETS[mission]) < 6.0:
            mission += 1
            _update_objective()
            _notice("Location discovered! Mission completed.")

    chatter_time -= delta
    if chatter_time <= 0.0 and speech_bubbles.size() >= 2:
        chatter_time = 9.0
        var first = randi() % speech_bubbles.size()
        var second = (first + 1 + randi() % (speech_bubbles.size() - 1)) % speech_bubbles.size()
        speech_bubbles[first].text = NPC_CHAT[randi() % NPC_CHAT.size()]
        speech_bubbles[second].text = NPC_CHAT[randi() % NPC_CHAT.size()]
        speech_bubbles[first].visible = true
        speech_bubbles[second].visible = true
        bubble_time = 3.5

    if bubble_time > 0.0:
        bubble_time -= delta
        if bubble_time <= 0.0:
            for bubble in speech_bubbles:
                bubble.visible = false


func _add_speech_bubbles():
    pass

func _to_main_menu():
    get_tree().paused = false
    get_tree().change_scene_to_file("res://menu.tscn")
