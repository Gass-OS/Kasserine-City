extends RefCounted

const TIPS = [
    "Tip: press HALT to make a fleeing suspect stop.",
    "Tip: switch SIREN on and traffic gives way.",
    "Tip: press RADIO for dispatch updates.",
    "Tip: wet roads reduce grip during storms.",
    "Tip: talk to citizens for witness clues.",
    "Tip: mediate disputes to earn dinars and reputation.",
    "Tip: a wrongful arrest costs you reputation.",
]
const CARS = ["sedan", "hatchback-sports", "suv", "taxi", "van", "sedan-sports", "suv-luxury", "truck", "delivery", "police", "ambulance"]

static func _paths() -> Array:
    var out: Array = [
        "res://main.tscn",
        "res://assets/characters/characterMedium.fbx",
        "res://assets/characters/idle.fbx",
        "res://assets/characters/run.fbx",
        "res://assets/characters/jump.fbx",
        "res://assets/kenney/suburban/tree-large.glb",
        "res://assets/kenney/suburban/tree-small.glb",
    ]
    for n in CARS:
        out.append("res://assets/kenney/cars/%s.glb" % n)
    for c in "abcdefghijklmn":
        out.append("res://assets/kenney/commercial/building-%s.glb" % c)
    for c in "abcde":
        out.append("res://assets/kenney/commercial/building-skyscraper-%s.glb" % c)
    var ok: Array = []
    for p in out:
        if ResourceLoader.exists(p):
            ok.append(p)
    return ok

static func _lab(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_constant_override("outline_size", 6)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    return l

static func run(menu: Control) -> void:
    Watchdog.record("PLAY: loader started")
    var tree := menu.get_tree()
    var old = menu.get("ui")
    if old != null:
        (old as Control).visible = false
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.add_child(root)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.55)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(shade)
    var cc := CenterContainer.new()
    cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(cc)
    var v := VBoxContainer.new()
    v.custom_minimum_size = Vector2(620, 0)
    v.add_theme_constant_override("separation", 16)
    cc.add_child(v)
    v.add_child(_lab("KASSERINE CITY", 52, Color(1, 0.85, 0.5)))
    var status := _lab("Loading...", 22, Color(0.9, 0.95, 1.0))
    v.add_child(status)
    var bar := ProgressBar.new()
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0, 22)
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.05, 0.05, 0.07, 0.9)
    bg.set_corner_radius_all(4)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color(0.95, 0.55, 0.1)
    fill.set_corner_radius_all(4)
    bar.add_theme_stylebox_override("background", bg)
    bar.add_theme_stylebox_override("fill", fill)
    v.add_child(bar)
    var tip := _lab("", 18, Color(0.8, 0.85, 0.9))
    v.add_child(tip)
    var paths := _paths()
    Watchdog.record("LOADER: requesting %d resources" % paths.size())
    for p in paths:
        var request_error := ResourceLoader.load_threaded_request(p, "", true)
        if request_error != OK:
            Watchdog.record("LOADER: request failed: %s error=%d" % [p, request_error])
    var shown := 0.0
    var elapsed := 0.0
    var tip_t := 99.0
    var tip_i := randi() % TIPS.size()
    while true:
        var dt := menu.get_process_delta_time()
        elapsed += dt
        if elapsed > 90.0:
            status.text = "CITY LOAD TIMEOUT - CHECK DIAGNOSTICS"
            Watchdog.record("LOADER TIMEOUT after 90 seconds")
            return
        var sum := 0.0
        var pending := false
        for p in paths:
            var prog: Array = []
            var st := ResourceLoader.load_threaded_get_status(p, prog)
            if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
                pending = true
                if prog.size() > 0:
                    sum += float(prog[0])
            else:
                sum += 1.0
        var real := sum / float(maxi(paths.size(), 1))
        shown = move_toward(shown, minf(real, elapsed / 4.5), dt * 0.6)
        bar.value = shown * 100.0
        if shown < 0.3:
            status.text = "Loading the city..."
        elif shown < 0.6:
            status.text = "Warming up the engines..."
        elif shown < 0.9:
            status.text = "Briefing dispatch..."
        else:
            status.text = "Ready, Unit 7."
        tip_t += dt
        if tip_t > 3.0:
            tip_t = 0.0
            tip_i = (tip_i + 1) % TIPS.size()
            tip.text = TIPS[tip_i]
        if not pending and shown >= 0.995 and elapsed >= 4.5:
            break
        await tree.process_frame
    Watchdog.record("LOADER: threaded requests settled after %.1f seconds" % elapsed)

    var keep: Array = []
    var packed: PackedScene = null
    for p in paths:
        var load_status := ResourceLoader.load_threaded_get_status(p)
        if load_status != ResourceLoader.THREAD_LOAD_LOADED:
            Watchdog.record("LOADER: resource did not load: %s status=%d" % [p, load_status])
            continue

        var r = ResourceLoader.load_threaded_get(p)
        if r != null:
            keep.append(r)
        if p == "res://main.tscn":
            packed = r as PackedScene

    if packed == null:
        status.text = "CITY SCENE FAILED - CHECK DIAGNOSTICS"
        Watchdog.record("LOADER FATAL: main.tscn was not loaded")
        return

    Watchdog.record("LOADER: main scene packed successfully")
    var st_node := tree.root.get_node_or_null("Settings")
    if st_node != null:
        st_node.set_meta("keep", keep)
    Watchdog.record("LOADER: requesting scene transition")
    var change_error := tree.change_scene_to_packed(packed)
    if change_error != OK:
        status.text = "SCENE TRANSITION FAILED - CHECK DIAGNOSTICS"
        Watchdog.record("LOADER FATAL: scene transition error=%d" % change_error)
        return

    Watchdog.record("LOADER: scene transition accepted")
