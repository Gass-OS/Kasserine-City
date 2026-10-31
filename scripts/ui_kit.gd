extends RefCounted

static func button(layer: CanvasLayer, text: String, pos: Vector2, color: Color, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.custom_minimum_size = Vector2(58, 58)
    b.size = Vector2(58, 58)
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 13)
    for st in ["normal", "hover", "pressed", "focus"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = color if st == "pressed" else color.darkened(0.45)
        sb.bg_color.a = 0.85
        sb.set_corner_radius_all(29)
        sb.border_color = color.lightened(0.2)
        sb.set_border_width_all(3)
        b.add_theme_stylebox_override(st, sb)
    b.pressed.connect(cb)
    layer.add_child(b)
    return b
