extends Control

var ui: Control
var rng := RandomNumberGenerator.new()
var towers: Array = []
var tick := 0.0
var acc := 0.0
var screen := "main"
# v0.3.1: UI click sound (procedural) so every menu tap gives immediate
# audible feedback — the user reported total silence on the phone.
var click_player: AudioStreamPlayer
var click_playback: AudioStreamGeneratorPlayback
var click_frames_left := 0
var click_phase := 0.0
# v0.4 (B): boot sequence — title fades in, loading bar fills, tap to start.
var boot_t := 0.0
var boot_bar: ProgressBar
var boot_tap: Label
var boot_title: Label
# v0.4 (A): on-device MP3 test result label (settings screen).
var test_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rng.seed = 7
	var x := 0.0
	while x < 1.0:
		var w := rng.randf_range(0.04, 0.09)
		towers.append({"x": x, "w": w, "h": rng.randf_range(0.12, 0.42), "s": rng.randi()})
		x += w + 0.004
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui)
	var cgen := AudioStreamGenerator.new()
	cgen.mix_rate = 22050
	cgen.buffer_length = 0.2
	click_player = AudioStreamPlayer.new()
	click_player.stream = cgen
	click_player.volume_db = -6.0
	add_child(click_player)
	# v0.3.1 FIX: play() before get_stream_playback() — without it the
	# playback is null ("Player is inactive") and the click never sounds.
	click_player.play()
	click_playback = click_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_show_boot()

func _play_click() -> void:
	if click_playback != null:
		click_frames_left = int(0.06 * 22050)
		click_phase = 0.0
		if not click_player.playing:
			click_player.play()

func _click_then(cb: Callable) -> void:
	_play_click()
	cb.call()

func _notification(what: int) -> void:
	# Android back button: never quit at once. On the main menu it opens
	# the quit confirmation; on settings / confirm it goes back one step.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen == "boot":
			_show_main()
		elif screen == "quit" or screen == "settings":
			_show_main()
		else:
			_show_quit_confirm()

func _input(event: InputEvent) -> void:
	# v0.4 (B): the boot screen is a tap-to-start screen. A tap during
	# the fill jumps the bar to full; a tap after that enters the menu.
	if screen != "boot":
		return
	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	if not tapped or boot_t < 0.5:
		return
	if boot_bar.value < 100.0:
		boot_bar.value = 100.0
		boot_tap.visible = true
	else:
		_show_main()

func _process(delta: float) -> void:
	tick += delta
	acc += delta
	if acc > 0.6:
		acc = 0.0
		queue_redraw()
	if screen == "boot":
		boot_t += delta
		if boot_bar != null and boot_bar.value < 100.0:
			boot_bar.value = minf(100.0, boot_t / 2.5 * 100.0)
			if boot_bar.value >= 100.0:
				boot_tap.visible = true
		if boot_tap != null and boot_tap.visible:
			# Blink the "tap to start" prompt.
			boot_tap.modulate.a = 0.55 + 0.45 * sin(tick * 5.0)
	# Push the UI click frames (0.06 s at 1600 Hz).
	if click_frames_left > 0 and click_playback != null:
		var avail := click_playback.get_frames_available()
		var n := mini(avail, click_frames_left)
		for i in range(n):
			var s := sin(TAU * 1600.0 * click_phase / 22050.0) * 0.8
			click_playback.push_frame(Vector2(s, s))
			click_phase += 1.0
		click_frames_left -= n

func _draw() -> void:
	var s := size
	var top := Color(0.04, 0.06, 0.16)
	var bot := Color(0.95, 0.5, 0.25)
	var bands := 40
	for i in bands:
		var f := float(i) / float(bands - 1)
		draw_rect(Rect2(0, s.y * i / bands, s.x, s.y / bands + 1.0), top.lerp(bot, pow(f, 1.8)))
	for tw in towers:
		var bw: float = tw["w"] * s.x
		var bh: float = tw["h"] * s.y
		var bx: float = tw["x"] * s.x
		var by: float = s.y - bh
		draw_rect(Rect2(bx, by, bw, bh), Color(0.05, 0.05, 0.09))
		var r := RandomNumberGenerator.new()
		r.seed = tw["s"]
		var j := 0
		var wy := by + 10.0
		while wy < s.y - 10.0:
			var wx := bx + 6.0
			while wx < bx + bw - 10.0:
				j += 1
				var lit := r.randf() > 0.55
				if lit and (j + int(tick)) % 9 != 0:
					draw_rect(Rect2(wx, wy, 6, 8), Color(1.0, 0.85, 0.45))
				wx += 14.0
			wy += 18.0

func _clear() -> void:
	for c in ui.get_children():
		c.queue_free()
	ui.layout_direction = Control.LAYOUT_DIRECTION_RTL if Settings.language == "ar" else Control.LAYOUT_DIRECTION_LTR

func _center_box(width: float) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(width, 0)
	v.add_theme_constant_override("separation", 14)
	cc.add_child(v)
	return v

func _label(text: String, fsize: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 66)
	b.add_theme_font_size_override("font_size", 26)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.1, 0.18, 0.85) if st == "normal" else Color(0.9, 0.45, 0.2, 0.95)
		sb.set_corner_radius_all(14)
		sb.border_color = Color(1, 0.7, 0.4, 0.8)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(_click_then.bind(cb))
	return b

func _show_boot() -> void:
	# v0.4 (B): modern boot sequence — the Godot splash is already off,
	# so this animated title + loading bar is the first thing the
	# player sees instead of a dead dark screen.
	screen = "boot"
	boot_t = 0.0
	_clear()
	var v := _center_box(460)
	boot_title = _label("KASSERINE CITY", 54, Color(1, 0.85, 0.5))
	boot_title.modulate.a = 0.0
	v.add_child(boot_title)
	v.add_child(_label(Settings.t("subtitle"), 22, Color(0.85, 0.9, 1.0)))
	v.add_child(Control.new())
	boot_bar = ProgressBar.new()
	boot_bar.min_value = 0.0
	boot_bar.max_value = 100.0
	boot_bar.value = 0.0
	boot_bar.show_percentage = false
	boot_bar.custom_minimum_size = Vector2(0, 26)
	v.add_child(boot_bar)
	v.add_child(_label(Settings.t("loading"), 20, Color(0.85, 0.9, 1.0)))
	boot_tap = _label(Settings.t("tap_to_start"), 24, Color(1, 0.85, 0.5))
	boot_tap.visible = false
	v.add_child(boot_tap)
	create_tween().tween_property(boot_title, "modulate:a", 1.0, 0.9)

func _test_mp3(fname: String, ok_key: String, missing_key: String) -> void:
	# v0.4 (A): play the bundled MP3 right now in the menu, so the user
	# can tell on the device whether the file loads and sounds — no
	# need to wait for a prayer time or a radio chatter.
	_play_click()
	var path := "res://assets/audio/" + fname
	if not ResourceLoader.exists(path):
		test_label.text = Settings.t(missing_key)
		return
	var stream := load(path) as AudioStreamMP3
	if stream == null:
		test_label.text = Settings.t(missing_key)
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -6.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	test_label.text = Settings.t(ok_key)

func _show_main() -> void:
	screen = "main"
	_clear()
	var v := _center_box(380)
	var title := _label("KASSERINE CITY", 56, Color(1, 0.85, 0.5))
	v.add_child(title)
	v.add_child(_label(Settings.t("subtitle"), 22, Color(0.85, 0.9, 1.0)))
	v.add_child(Control.new())
	v.add_child(_button(Settings.t("play"), _on_play))
	v.add_child(_button(Settings.t("settings"), _show_settings))
	v.add_child(_button(Settings.t("quit"), _show_quit_confirm))
	v.modulate.a = 0.0
	create_tween().tween_property(v, "modulate:a", 1.0, 0.8)

func _show_quit_confirm() -> void:
	screen = "quit"
	_clear()
	var v := _center_box(420)
	v.add_child(_label(Settings.t("quit_confirm"), 36, Color(1, 0.85, 0.5)))
	v.add_child(_label("Kasserine City", 22, Color(0.85, 0.9, 1.0)))
	v.add_child(Control.new())
	v.add_child(_button(Settings.t("yes_quit"), func(): get_tree().quit()))
	v.add_child(_button(Settings.t("back"), _show_main))

func _on_play() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _row(parent: Control, key: String, slider_min: float, slider_max: float, step: float, value: float, cb: Callable) -> void:
	parent.add_child(_label(Settings.t(key), 22))
	var s := HSlider.new()
	s.min_value = slider_min
	s.max_value = slider_max
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 44)
	s.value_changed.connect(cb)
	parent.add_child(s)

func _show_settings() -> void:
	screen = "settings"
	_clear()
	var v := _center_box(460)
	v.add_child(_label(Settings.t("settings"), 40, Color(1, 0.85, 0.5)))
	_row(v, "volume", 0.0, 1.0, 0.05, Settings.master_volume, func(x):
		Settings.master_volume = x
		Settings.apply()
		Settings.save_settings())
	_row(v, "sensitivity", 0.3, 2.5, 0.1, Settings.look_sensitivity, func(x):
		Settings.look_sensitivity = x
		Settings.save_settings())
	_row(v, "day_length", 60.0, 3600.0, 60.0, Settings.day_length, func(x):
		Settings.day_length = x
		Settings.save_settings())
	v.add_child(_label(Settings.t("quality"), 22))
	var q := OptionButton.new()
	q.custom_minimum_size = Vector2(0, 52)
	q.add_theme_font_size_override("font_size", 22)
	q.add_item(Settings.t("low"))
	q.add_item(Settings.t("medium"))
	q.add_item(Settings.t("high"))
	q.select(Settings.quality)
	q.item_selected.connect(func(i):
		Settings.quality = i
		Settings.apply()
		Settings.save_settings())
	v.add_child(q)
	v.add_child(_label(Settings.t("language"), 22))
	var lang := OptionButton.new()
	lang.custom_minimum_size = Vector2(0, 52)
	lang.add_theme_font_size_override("font_size", 22)
	lang.add_item("English")
	lang.add_item("Français")
	lang.add_item("العربية")
	lang.select(Settings.LANGS.find(Settings.language))
	lang.item_selected.connect(func(i):
		Settings.language = Settings.LANGS[i]
		Settings.save_settings()
		_show_settings.call_deferred())
	v.add_child(lang)
	test_label = _label("", 20, Color(1, 0.85, 0.5))
	v.add_child(test_label)
	v.add_child(_button(Settings.t("test_adhan"), func(): _test_mp3("adhan.mp3", "adhan_ok", "adhan_missing")))
	v.add_child(_button(Settings.t("test_radio"), func(): _test_mp3("police.mp3", "radio_ok", "radio_missing")))
	v.add_child(_button(Settings.t("back"), _show_main))
