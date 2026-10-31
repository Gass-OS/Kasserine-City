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

const TARGETS = [
    Vector3(3, 0, 7),
    Vector3(-24, 0, 0),
    Vector3(24, 0, 0),
    Vector3(3, 0, 7)
]

const TASKS = [
    "1. Talk to Amine (yellow name)",
    "2. Explore the market",
    "3. Visit the garage",
    "4. Return to Amine"
]

func _ready():
    world = get_parent()
    player = world.get_node("Player")
    _create_interface()
    _update_objective()
    _notice("Welcome to Kasserine City!")

func _create_interface():
    var layer = CanvasLayer.new()
    layer.layer = 20
    add_child(layer)

    var menu = HBoxContainer.new()
    menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    menu.position = Vector2(650, 12)
    layer.add_child(menu)

    for title in ["HELP", "MISSIONS", "MAP"]:
        var button = Button.new()
        button.text = title
        button.custom_minimum_size = Vector2(105, 48)
        menu.add_child(button)
        button.pressed.connect(_open.bind(title))

    objective = Label.new()
    objective.position = Vector2(20, 52)
    objective.add_theme_font_size_override("font_size", 17)
    objective.add_theme_color_override("font_color", Color.YELLOW)
    layer.add_child(objective)

    minimap = Label.new()
    minimap.position = Vector2(20, 92)
    minimap.add_theme_font_size_override("font_size", 15)
    minimap.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(minimap)

    notice = Label.new()
    notice.position = Vector2(20, 225)
    notice.add_theme_font_size_override("font_size", 20)
    notice.add_theme_color_override("font_color", Color.YELLOW)
    layer.add_child(notice)

    panel = PanelContainer.new()
    panel.position = Vector2(270, 110)
    panel.custom_minimum_size = Vector2(550, 350)
    panel.visible = false
    layer.add_child(panel)

    var column = VBoxContainer.new()
    panel.add_child(column)

    var close = Button.new()
    close.text = "CLOSE  X"
    column.add_child(close)
    close.pressed.connect(func(): panel.hide())

    info = Label.new()
    info.custom_minimum_size = Vector2(510, 260)
    info.add_theme_font_size_override("font_size", 20)
    column.add_child(info)

func _open(title: String):
    panel.visible = true
    match title:
        "HELP":
            info.text = (
                "KASSERINE CITY - HELP\\n\\n"
                + "Left joystick: move\\n"
                + "Drag right side: camera\\n"
                + "RUN: sprint     JUMP: jump\\n"
                + "USE: talk to a nearby character\\n\\n"
                + "Complete objectives to explore the city."
            )
        "MISSIONS":
            info.text = (
                "KASSERINE CITY - MISSIONS\\n\\n"
                + "Current objective:\\n"
                + _task_text()
                + "\\n\\nFind the yellow location labels."
            )
        "MAP":
            info.text = (
                "KASSERINE CITY - DISTRICT MAP\\n\\n"
                + "            NORTH\\n"
                + "               |\\n"
                + " MARKET ---- SQUARE ---- GARAGE\\n"
                + "               |\\n"
                + "           START AREA\\n\\n"
                + "Player X: %.0f    Z: %.0f" %
                [player.global_position.x, player.global_position.z]
            )

func _task_text() -> String:
    if mission >= TASKS.size():
        return "All introductory missions completed!"
    return TASKS[mission]

func _update_objective():
    objective.text = "OBJECTIVE: " + _task_text()

func _notice(message: String):
    notice.text = message
    notice_time = 3.0

func interact():
    if mission == 0 or mission == 3:
        if player.global_position.distance_to(TARGETS[mission]) < 5.0:
            mission += 1
            _update_objective()
            _notice("Mission completed! New objective unlocked.")
        else:
            _notice("Find Amine and stand nearby.")
    else:
        _notice("Follow the current objective.")

func _process(delta):
    if notice_time > 0:
        notice_time -= delta
        if notice_time <= 0:
            notice.text = ""

    minimap.text = (
        "MINIMAP  [NORTH UP]\\n"
        + "X: %.0f   Z: %.0f\\n" %
        [player.global_position.x, player.global_position.z]
        + "M: Market (-24, 0)\\n"
        + "G: Garage (24, 0)\\n"
        + "A: Amine (3, 7)"
    )

    if mission == 1 or mission == 2:
        if player.global_position.distance_to(TARGETS[mission]) < 6.0:
            mission += 1
            _update_objective()
            _notice("Location discovered! Mission completed.")
