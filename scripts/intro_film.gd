extends Node
# v0.4 (B): opening cinematic — an in-engine camera flyover of the
# existing city (mosque -> market -> plaza -> police station -> the
# player), with story title cards. ~17 s, SKIP button, plays once per
# install (Settings.intro_seen). No new assets, no pause — the world
# keeps simulating behind the camera.

const SEG_TIME := 4.0
const POSITIONS: Array[Vector3] = [
	Vector3(34, 26, -6),
	Vector3(-8, 18, 22),
	Vector3(18, 14, 18),
	Vector3(48, 16, -12),
	Vector3(6, 4, 20),
]
const TARGETS: Array[Vector3] = [
	Vector3(12, 2, -36),   # mosque
	Vector3(-24, 2, 0),    # market
	Vector3(0, 2, 0),      # plaza
	Vector3(36, 3, -36),   # police station
	Vector3(0, 1.5, 12),   # the player, at spawn
]
const CARDS: Array[String] = [
	"intro_card1",
	"intro_card2",
	"intro_card3",
	"story_ch1_title",
]

var world: Node
var player: Node3D
var cam: Camera3D
var card_label: Label
var fade: ColorRect
var seg := 0
var seg_t := 0.0
var fade_t := 0.0
var fading_out := false
var finished := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = get_parent()
	world.intro_playing = true
	player = world.get_node_or_null("Player") as Node3D
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	cam = Camera3D.new()
	cam.name = "IntroCamera"
	cam.fov = 62.0
	cam.current = true
	add_child(cam)
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	card_label = Label.new()
	card_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	card_label.position = Vector2(-500, 120)
	card_label.custom_minimum_size = Vector2(1000, 120)
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_label.add_theme_font_size_override("font_size", 40)
	card_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	card_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	card_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(card_label)
	var skip := Button.new()
	skip.text = Settings.t("skip")
	skip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skip.position = Vector2(-90, -120)
	skip.custom_minimum_size = Vector2(180, 64)
	skip.add_theme_font_size_override("font_size", 24)
	skip.pressed.connect(_finish)
	layer.add_child(skip)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	_show_card(0)

func _show_card(i: int) -> void:
	if i < CARDS.size():
		card_label.text = Settings.t(CARDS[i])
		card_label.modulate.a = 0.0
		create_tween().tween_property(card_label, "modulate:a", 1.0, 0.8)
	else:
		card_label.text = ""

func _process(delta: float) -> void:
	if finished:
		return
	# Fade in from black at the start (unless already fading out).
	if not fading_out and fade_t < 0.9:
		fade_t += delta
		fade.color.a = maxf(0.0, 1.0 - fade_t / 0.9)
	if fading_out:
		fade.color.a = minf(1.0, fade.color.a + delta / 0.5)
		if fade.color.a >= 1.0:
			_finish_now()
		return
	seg_t += delta
	var f := clampf(seg_t / SEG_TIME, 0.0, 1.0)
	var s := f * f * (3.0 - 2.0 * f)
	var p0: Vector3 = POSITIONS[seg]
	var p1: Vector3 = POSITIONS[seg + 1]
	var t0: Vector3 = TARGETS[seg]
	var t1: Vector3 = TARGETS[seg + 1]
	cam.position = p0.lerp(p1, s)
	cam.look_at(t0.lerp(t1, s), Vector3.UP)
	if f >= 1.0:
		seg += 1
		seg_t = 0.0
		if seg >= POSITIONS.size() - 1:
			# Last frame reached: fade out, then hand over to the player.
			fading_out = true
		else:
			_show_card(seg)

func _finish() -> void:
	if finished:
		return
	fading_out = true
	fade.color.a = maxf(fade.color.a, 0.0)

func _finish_now() -> void:
	if finished:
		return
	finished = true
	if player != null:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		var pcam := player.get("camera") as Camera3D
		if pcam != null:
			pcam.current = true
	cam.current = false
	world.intro_playing = false
	Settings.intro_seen = true
	Settings.save_settings()
	queue_free()
