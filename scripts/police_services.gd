extends Node

const CASES := [
    {
        "title": "Lost child / طفل ضايع",
        "citizen": "عسلامة سي أمّار، ضيّعت صغيري في السوق. بالله عاونّي!",
        "detail": "آخر مرة شفتو كان قريب من السوق. لابس قميجة زرقاء.",
        "target": Vector3(-24, 0, 0),
        "radio": "Lost child report near the market. Unit 7, investigate.",
        "done": "لقيت الطفل ورجّعتو لعائلتو. يعطيك الصحة سي أمّار!"
    },
    {
        "title": "Road obstruction / تعطيل طريق",
        "citizen": "خويا سي أمّار، فما كرهبة سادّة الطريق والناس موش عارفة تعدّي.",
        "detail": "الكرهبة واقفة قدّام مدخل المرآب. الطريق ولات خطيرة.",
        "target": Vector3(24, 0, 0),
        "radio": "Road obstruction reported near the garage. Check traffic.",
        "done": "رجعت حركة المرور عادية. ربي يعيشك!"
    },
    {
        "title": "Theft complaint / شكاية سرقة",
        "citizen": "بالله نحب نعمل شكاية، تليفوني تسرقلي في الحومة.",
        "detail": "صار الحادث قريب من مركز الشرطة. اسأل الشهود قبل ما تتحرّك.",
        "target": Vector3(36, 0, -36),
        "radio": "Theft complaint received. Visit the police station.",
        "done": "تم تسجيل الشكاية. شكراً على تعاونك."
    },
    {
        "title": "Medical assistance / مساعدة طبية",
        "citizen": "سي أمّار، فما راجل تعبان ويستحق مساعدة. تنجم تعاون؟",
        "detail": "يلزمنا نوجّهو للمستشفى ونطلبو الإسعاف إذا الحالة تستحق.",
        "target": Vector3(-36, 0, 36),
        "radio": "Medical assistance requested. Coordinate with hospital.",
        "done": "وصلت المساعدة. يعطيك الصحة على التدخّل."
    },
    {
        "title": "Neighbour dispute / مشكلة جيران",
        "citizen": "عسلامة خويا، فما مشكلة بين جيران قدّام القهوة.",
        "detail": "امشي للقهوة واسمع للطرفين بهدوء قبل اتخاذ أي قرار.",
        "target": Vector3(36, 0, 36),
        "radio": "Neighbour dispute near the cafe. Respond and de-escalate.",
        "done": "الوضع هدا والناس تفاهمت. بارك الله فيك."
    },
    {
        "title": "Suspicious activity / تحرّك مشبوه",
        "citizen": "خويا، لاحظنا حركة غريبة قرب المدرسة. تنجم تتثبت؟",
        "detail": "تفقد محيط المدرسة وخليك يقظ، من غير ما تتسرّع في الحكم.",
        "target": Vector3(-36, 0, -36),
        "radio": "Suspicious activity near the school. Check safely.",
        "done": "تفقدت المكان وما عادش فما خطر. نهارك زين."
    }
]

var world: Node3D
var player: Node3D
var gameplay
var radio
var missions

var layer: CanvasLayer
var panel: PanelContainer
var heading: Label
var body: Label
var status: Label

var active_case: Dictionary = {}
var active := false
var completed := 0

func _ready() -> void:
    world = get_parent() as Node3D
    await get_tree().process_frame

    player = world.get_node_or_null("Player") as Node3D
    gameplay = world.get_node_or_null("Gameplay")
    radio = world.get_node_or_null("Radio")
    missions = world.get_node_or_null("MissionsPlus")

    _build_ui()

func _build_ui() -> void:
    layer = CanvasLayer.new()
    layer.layer = 24
    layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(layer)

    panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.position = Vector2(-270, -205)
    panel.custom_minimum_size = Vector2(540, 410)
    panel.visible = false

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.045, 0.065, 0.97)
    style.border_color = Color(0.86, 0.62, 0.22)
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 16
    style.content_margin_bottom = 16
    panel.add_theme_stylebox_override("panel", style)
    layer.add_child(panel)

    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 12)
    panel.add_child(col)

    heading = Label.new()
    heading.text = "KASSERINE POLICE • CITIZEN SERVICES"
    heading.add_theme_font_size_override("font_size", 21)
    heading.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
    col.add_child(heading)

    body = Label.new()
    body.custom_minimum_size = Vector2(490, 180)
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_theme_font_size_override("font_size", 19)
    body.add_theme_color_override("font_color", Color(0.94, 0.95, 0.98))
    col.add_child(body)

    status = Label.new()
    status.text = "AMAR • UNIT 7"
    status.add_theme_color_override("font_color", Color(0.55, 0.85, 0.65))
    col.add_child(status)

    var actions := GridContainer.new()
    actions.columns = 2
    actions.add_theme_constant_override("h_separation", 10)
    actions.add_theme_constant_override("v_separation", 8)
    col.add_child(actions)

    _add_button(actions, "ACCEPT CASE / نقبل الشكاية", _accept_case)
    _add_button(actions, "ASK DETAILS / تفاصيل", _ask_details)
    _add_button(actions, "CLOSE / نسكّر", _close_ui)

func _add_button(parent: Control, caption: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size = Vector2(235, 54)
    b.add_theme_font_size_override("font_size", 16)
    b.pressed.connect(callback)
    parent.add_child(b)

func interact(citizen: Node3D) -> bool:
    if active:
        if gameplay != null:
            gameplay.call("_notice", "You already have an active police case. Follow the yellow radar marker.")
        return true

    var citizens = world.get("citizens")
    var index := citizens.find(citizen) if citizens != null else -1

    if index <= 0:
        return false

    active_case = CASES[posmod(index - 1, CASES.size())]

    heading.text = "CITIZEN REQUEST • %s" % active_case["title"]
    body.text = str(active_case["citizen"]) + "\n\nأمّار: عسلامة، احكيلي شنوة صار. نسمعك."
    status.text = "CITIZEN %02d • POLICE UNIT 7" % index

    panel.visible = true
    get_tree().paused = true
    return true

func _ask_details() -> void:
    if active_case.is_empty():
        return

    body.text = str(active_case["citizen"]) + "\n\n"
    body.text += str(active_case["detail"])
    body.text += "\n\nأمّار: فهمتك. باش نتثبت من الموضوع."
    status.text = "DETAILS RECEIVED • REVIEW THE REPORT"

func _accept_case() -> void:
    if active_case.is_empty():
        return

    active = true
    var target: Vector3 = active_case["target"]
    world.set_meta("radar_target", target)

    get_tree().paused = false
    panel.visible = false

    if gameplay != null:
        gameplay.objective.text = "POLICE DUTY: %s" % active_case["title"]
        gameplay.call("_notice", "Case accepted. Follow the radar to the reported location.")

    if radio != null:
        radio.call("say", "Dispatch", str(active_case["radio"]), true)

func _close_ui() -> void:
    panel.visible = false
    get_tree().paused = false

func _process(_delta: float) -> void:
    if not active or player == null or active_case.is_empty():
        return

    var target: Vector3 = active_case["target"]
    var distance := Vector2(
        player.global_position.x - target.x,
        player.global_position.z - target.z
    ).length()

    if distance <= 6.5:
        active = false
        completed += 1
        world.remove_meta("radar_target")

        var reward := 75
        if missions != null:
            var coins := int(missions.get("coins")) + reward
            missions.set("coins", coins)
            if missions.coin_label != null:
                missions.coin_label.visible = true
                missions.coin_label.text = "Dinars: %d" % coins

        if gameplay != null:
            gameplay.objective.text = "POLICE DUTY: Return to patrol"
            gameplay.call(
                "_notice",
                "Case closed! +%d dinars • %d cases completed" % [reward, completed]
            )

        if radio != null:
            radio.call("say", "Unit 7", str(active_case["done"]), true)

        active_case = {}
