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
    world = get_parent()
    player = world.get_node("Player")
    _create_interface()
    _add_speech_bubbles()
    _update_objective()
    _notice("Welcome to Kasserine City!")
    _speak("Welcome to Kasserine City.")

func _create_interface():
    var layer = CanvasLayer.new()
    layer.layer = 20
    layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(layer)

    var menu = HBoxContainer.new()
    menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    menu.position = Vector2(-430, 12)
    menu.custom_minimum_size = Vector2(420, 46)
    layer.add_child(menu)

    for title in ["MENU", "HELP", "MISSIONS", "MAP"]:
        var button = Button.new()
        button.text = title
        button.custom_minimum_size = Vector2(94, 44)
        menu.add_child(button)
        button.pressed.connect(_open.bind(title))

    objective = Label.new()
    objective.position = Vector2(18, 55)
    objective.add_theme_font_size_override("font_size", 17)
    objective.add_theme_color_override("font_color", Color.YELLOW)
    layer.add_child(objective)

    minimap = Label.new()
    minimap.position = Vector2(18, 92)
    minimap.add_theme_font_size_override("font_size", 15)
    minimap.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(minimap)

    notice = Label.new()
    notice.position = Vector2(18, 220)
    notice.add_theme_font_size_override("font_size", 19)
    notice.add_theme_color_override("font_color", Color.YELLOW)
    layer.add_child(notice)

    panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.position = Vector2(-250, -185)
    panel.custom_minimum_size = Vector2(500, 370)
    panel.visible = false
    layer.add_child(panel)

    var column = VBoxContainer.new()
    panel.add_child(column)

    var heading = Label.new()
    heading.text = "KASSERINE CITY"
    heading.add_theme_font_size_override("font_size", 24)
    column.add_child(heading)

    info = Label.new()
    info.custom_minimum_size = Vector2(460, 130)
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_theme_font_size_override("font_size", 17)
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
    resume.custom_minimum_size = Vector2(150, 48)
    resume.pressed.connect(_resume_game)
    actions.add_child(resume)

    var settings = Button.new()
    settings.text = "SETTINGS"
    settings.custom_minimum_size = Vector2(110, 48)
    settings.pressed.connect(_open.bind("SETTINGS"))
    actions.add_child(settings)

    var exit_button = Button.new()
    exit_button.text = "EXIT"
    exit_button.custom_minimum_size = Vector2(90, 48)
    exit_button.pressed.connect(_exit_game)
    actions.add_child(exit_button)

func _open(title: String):
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

func _exit_game():
    get_tree().paused = false
    get_tree().quit()

func _set_sensitivity(value: float):
    player.look_sensitivity = value

func _set_voice_enabled(enabled: bool):
    voice_enabled = enabled

func _task_text() -> String:
    if mission >= TASKS.size():
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

func _add_speech_bubbles():
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
    for citizen in world.citizens:
        var distance = player.global_position.distance_to(citizen.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = citizen

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
