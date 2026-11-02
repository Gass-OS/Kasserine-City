extends Control
const LoadScreen = preload("res://scripts/loader.gd")

var ui: Control
var rng := RandomNumberGenerator.new()
var towers: Array = []
var tick := 0.0
var acc := 0.0

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
	_show_main()

func _process(delta: float) -> void:
	tick += delta
	acc += delta
	if acc > 0.6:
		acc = 0.0
		queue_redraw()

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
	b.pressed.connect(cb)
	return b

func _show_main() -> void:
	_clear()
	var v := _center_box(380)
	var title := _label("KASSERINE CITY", 56, Color(1, 0.85, 0.5))
	v.add_child(title)
	v.add_child(Control.new())
	v.add_child(_button(Settings.t("play"), _on_play))
	v.add_child(_button("STORY / HISTORY", _show_story))
	v.add_child(_button(Settings.t("settings"), _show_settings))
	v.add_child(_button("SUPPORT / SPONSOR", _show_support))
	v.add_child(_button(Settings.t("quit"), func(): get_tree().quit()))
	v.modulate.a = 0.0
	create_tween().tween_property(v, "modulate:a", 1.0, 0.8)

func _on_play() -> void:
	LoadScreen.run(self)

func _show_story() -> void:
        _clear()

        # Keep the story readable on smaller screens and allow vertical scrolling.
        var scroll := ScrollContainer.new()
        scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        scroll.offset_left = 24.0
        scroll.offset_top = 24.0
        scroll.offset_right = -24.0
        scroll.offset_bottom = -24.0
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        ui.add_child(scroll)

        var v := VBoxContainer.new()
        v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        v.custom_minimum_size = Vector2(
                minf(760.0, maxf(280.0, get_viewport_rect().size.x - 48.0)), 0.0)
        v.add_theme_constant_override("separation", 14)
        scroll.add_child(v)

        v.add_child(_label("KASSERINE • WESTERN TUNISIA", 34, Color(1, 0.82, 0.48)))

        var story := _label(
                "THE PLACE\nKasserine lies in western Tunisia among the highlands and mountain landscapes of the country's interior.\n\n"
                + "THE HISTORY\nThe wider region carries traces of ancient North African and Roman-era life. In February 1943, the Kasserine Pass became the site of a major World War II battle.\n\n"
                + "YOUR STORY\nThis game is a fictionalized modern city inspired by Kasserine. Meet residents, explore the market and garage, and discover everyday life.",
                19, Color(0.91, 0.93, 0.98))
        story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        story.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        v.add_child(story)

        v.add_child(_button("BACK TO MAIN MENU", _show_main))

func _show_support() -> void:
	_clear()
	var v := _center_box(500)
	v.add_child(_label("HELP BUILD KASSERINE CITY", 34, Color(1, 0.85, 0.5)))
	var message := _label(
		"An independent open-world project made with care.\n\n"
		+ "Support development by starring the repository, sharing the game, testing builds, and reporting bugs.\n\n"
		+ "FINANCIAL SPONSORSHIP\nOfficial payment links will appear here after a project funding account is configured and verified.",
		19, Color(0.91, 0.93, 0.98))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(message)
	v.add_child(_button("OPEN GASS-OS PROJECT", func(): OS.shell_open("https://github.com/Gass-OS/Kasserine-City")))
	v.add_child(_button("BACK TO MAIN MENU", _show_main))

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
	_row(v, "day_length", 60.0, 600.0, 10.0, Settings.day_length, func(x):
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
	v.add_child(_button(Settings.t("back"), _show_main))
