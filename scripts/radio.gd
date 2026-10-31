extends Node

const Sfx = preload("res://scripts/sfx.gd")
const UI = preload("res://scripts/ui_kit.gd")

const CHATTER = [
    ["Unit 9", "10-8, back in service."],
    ["Dispatch", "All units, heavy traffic on Avenue Habib Bourguiba."],
    ["Unit 21", "Traffic stop near the Garage. Running a plate."],
    ["Dispatch", "The market area is crowded today. Stay alert."],
    ["Unit 4", "Quiet in the east district. Over."],
    ["Dispatch", "Unit 12, report to the station for debrief."],
    ["Unit 12", "Copy dispatch. Heading in."],
    ["Patrol 3", "Checking the school perimeter. All clear."],
    ["Dispatch", "Lost child reported near the fountain. Keep an eye out."],
]
const WARM = ["squelch", "beep", "roger", "click", "whistle", "crash", "engine", "siren", "rain", "wind", "thunder"]

var world: Node3D
var gp
var panel: PanelContainer
var label: Label
var lines: Array = []
var hide_t := 0.0
var chatter_t := 45.0

func _ready() -> void:
    for i in range(3):
        await get_tree().process_frame
    world = get_parent() as Node3D
    if world == null:
        return
    gp = world.get_node_or_null("Gameplay")
    var layer := CanvasLayer.new()
    layer.layer = 14
    add_child(layer)
    panel = PanelContainer.new()
    panel.position = Vector2(430, 6)
    panel.visible = false
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.03, 0.05, 0.04, 0.88)
    sb.border_color = Color(0.3, 0.9, 0.4)
    sb.border_width_left = 4
    sb.content_margin_left = 10
    sb.content_margin_right = 10
    sb.content_margin_top = 6
    sb.content_margin_bottom = 6
    panel.add_theme_stylebox_override("panel", sb)
    layer.add_child(panel)
    label = Label.new()
    label.custom_minimum_size = Vector2(380, 0)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 15)
    label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.7))
    panel.add_child(label)
    UI.button(layer, "RADIO", Vector2(1196, 278), Color(0.2, 0.75, 0.35), _on_radio)
    await get_tree().create_timer(1.5).timeout
    for n in WARM:
        Sfx.get_sound(n)
        await get_tree().process_frame
    say("Dispatch", "Unit 7, welcome to Kasserine. Your patrol car is parked outside the police station. Stay sharp.", true)

func say(unit: String, text: String, speak := true) -> void:
    if label == null:
        return
    lines.append("[%s] %s" % [unit, text])
    while lines.size() > 3:
        lines.pop_front()
    label.text = "\n".join(lines)
    panel.visible = true
    hide_t = 9.0
    Sfx.play(self, "squelch", -9.0)
    if speak:
        _tts(text)

func _tts(text: String) -> void:
    if gp != null and not bool(gp.get("voice_enabled")):
        return
    var voices = DisplayServer.tts_get_voices()
    if voices.size() == 0:
        return
    var id := str(voices[0].get("id", ""))
    DisplayServer.tts_speak(text, id, 70, 1.0, 1.0, 0, false)

func _on_radio() -> void:
    var crime := get_parent().get_node_or_null("Crime")
    if crime != null:
        crime.call("radio_request")

func _process(delta: float) -> void:
    if panel == null:
        return
    if hide_t > 0.0:
        hide_t -= delta
        if hide_t <= 0.0:
            panel.visible = false
    chatter_t -= delta
    if chatter_t <= 0.0:
        chatter_t = randf_range(35.0, 70.0)
        var c = CHATTER.pick_random()
        say(c[0], c[1], false)
