extends Node

var player: CharacterBody3D
var world: Node3D
var mission := 0
var panel: PanelContainer
var info: Label
var objective: Label
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
# v0.3.1: walkie-talkie sound — the user's own police.mp3, same dual
# path as the adhan (Download folder first, then the copy baked into
# the APK). When present it replaces the procedural blip; when missing
# the blip stays as the fallback. Cached after the first load.
var radio_sound_player: AudioStreamPlayer
var police_stream: AudioStreamMP3 = null
# v0.3.1: UI click sound (procedural, same generator pattern as the blip)
# so every button tap gives immediate audible feedback.
var click_player: AudioStreamPlayer
var click_playback: AudioStreamGeneratorPlayback
var click_frames_left := 0
var click_phase := 0.0
var score := 0
# v0.4 (H): radio power toggle — ON (default) chatters, OFF is silent.
var radio_on := true
var radio_button: Button
# v0.4.1: police.mp3 is 44.88 s long and v0.4 played the WHOLE file per
# chatter line, every 20-40 s — the radio was nearly continuous. Each
# chatter now plays only a short burst, auto-stopped by this timer.
const RADIO_BURST_SECONDS := 5.5
var radio_burst_left := 0.0
# v0.4 (C): story chapter cards (new officer's first week).
var story_panel: PanelContainer
var story_title: Label
var story_body: Label
var story_shown := {}

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
    _create_story_panel()
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
    # v0.3.1: -6 dB (was -14) — the blip was inaudible on a phone speaker.
    blip_player.volume_db = -6.0
    add_child(blip_player)
    # v0.3.1 FIX: get_stream_playback() on a player that never played
    # returns null ("Player is inactive") — so the blip was dead, not
    # just quiet. play() first (empty buffer = silence until frames
    # are pushed), exactly like the working murmur/engine players.
    blip_player.play()
    blip_playback = blip_player.get_stream_playback() as AudioStreamGeneratorPlayback

    # v0.3.1: dedicated player for police.mp3 (-6 dB, no loop). The
    # stream is loaded lazily on the first radio sound — no file exists
    # in the VM, and a missing file is normal (blip fallback).
    radio_sound_player = AudioStreamPlayer.new()
    radio_sound_player.name = "RadioSoundPlayer"
    radio_sound_player.volume_db = -6.0
    add_child(radio_sound_player)

    # UI click: one short 1600 Hz tick, loud enough to hear on a tap.
    var cgen := AudioStreamGenerator.new()
    cgen.mix_rate = 22050
    cgen.buffer_length = 0.2
    click_player = AudioStreamPlayer.new()
    click_player.stream = cgen
    click_player.volume_db = -6.0
    add_child(click_player)
    # v0.3.1 FIX: same as the blip above — play() before
    # get_stream_playback(), or click_playback stays null and no click
    # is ever heard.
    click_player.play()
    click_playback = click_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _play_click() -> void:
    if click_playback != null:
        click_frames_left = int(0.06 * 22050)
        click_phase = 0.0
        if not click_player.playing:
            click_player.play()

func _click_then(cb: Callable) -> void:
    _play_click()
    cb.call()

func _click_then_open(title: String) -> void:
    _play_click()
    _open(title)

func _create_story_panel() -> void:
    # v0.4 (C): chapter cards for the story (first week in Kasserine).
    var layer = CanvasLayer.new()
    layer.layer = 25
    layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(layer)
    story_panel = PanelContainer.new()
    story_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    story_panel.position = Vector2(-320, -230)
    story_panel.custom_minimum_size = Vector2(640, 460)
    story_panel.visible = false
    layer.add_child(story_panel)
    var column = VBoxContainer.new()
    story_panel.add_child(column)
    story_title = Label.new()
    story_title.add_theme_font_size_override("font_size", 30)
    story_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
    story_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(story_title)
    story_body = Label.new()
    story_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    story_body.add_theme_font_size_override("font_size", 22)
    story_body.custom_minimum_size = Vector2(580, 220)
    column.add_child(story_body)
    var cont = Button.new()
    cont.text = Settings.t("continue")
    cont.custom_minimum_size = Vector2(0, 64)
    cont.add_theme_font_size_override("font_size", 24)
    cont.pressed.connect(_close_story_card)
    column.add_child(cont)

func _close_story_card() -> void:
    _play_click()
    story_panel.visible = false
    get_tree().paused = false

func _show_story_card(flag: String, title_key: String, body_key: String) -> void:
    if story_shown.get(flag, false):
        return
    story_shown[flag] = true
    story_title.text = Settings.t(title_key)
    story_body.text = Settings.t(body_key)
    story_panel.visible = true
    get_tree().paused = true

func _update_story() -> void:
    # One card per chapter, in story order. The intro film (if playing)
    # and the pause menu take precedence — the card waits its turn.
    if world.intro_playing:
        return
    if story_panel.visible or panel.visible:
        return
    var mp := world.get_node_or_null("MissionsPlus")
    if not story_shown.get("ch1", false):
        _show_story_card("ch1", "story_ch1_title", "story_ch1_body")
        return
    if mission == 1:
        _show_story_card("ch2", "story_ch2_title", "story_ch2_body")
        return
    if world.criminal_active:
        _show_story_card("ch3", "story_ch3_title", "story_ch3_body")
        return
    if mp != null and mp.wanted_step_active():
        _show_story_card("ch4", "story_ch4_title", "story_ch4_body")
        return
    if mp != null and mp.done:
        _show_story_card("end", "story_end_title", "story_end_body")

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
    _play_radio_sound()


# v0.3.1: dual-path MP3 load, same contract as the adhan in
# city_audio.gd — /storage/emulated/0/Download/police.mp3 first, then
# res://assets/audio/police.mp3. Guarded: a missing file returns null
# and the caller falls back to the procedural blip, never an error.
# v0.3.2 FIX: the bundled path MUST use ResourceLoader.exists(), not
# FileAccess.file_exists() — on Android the raw mp3 is not in the APK
# (only the imported .mp3str + .import remap), so the FileAccess guard
# returned false and load() was never attempted. See city_audio.gd.
func _load_police_stream() -> AudioStreamMP3:
    var ext_path := "/storage/emulated/0/Download/police.mp3"
    if FileAccess.file_exists(ext_path):
        # NOTE: no load() here — ResourceLoader cannot load absolute
        # paths outside res:// (always "No loader found"). Bytes only.
        var bytes := FileAccess.get_file_as_bytes(ext_path)
        if bytes.size() > 0:
            var mp3 := AudioStreamMP3.new()
            mp3.data = bytes
            return mp3
    if ResourceLoader.exists("res://assets/audio/police.mp3"):
        var b := load("res://assets/audio/police.mp3") as AudioStreamMP3
        if b != null:
            return b
    return null


# v0.3.1: the radio sound. police.mp3 when present (once per call,
# restarting if still playing); otherwise the procedural two-tone blip
# (0.07 s at 1250 Hz, then 0.07 s at 950 Hz).
# v0.4.1: the mp3 plays as a SHORT BURST (RADIO_BURST_SECONDS) — the
# file is 45 s long and v0.4 played it whole per chatter line.
func _play_radio_sound() -> void:
    if police_stream == null:
        police_stream = _load_police_stream()
    if police_stream != null:
        if radio_sound_player.playing:
            radio_sound_player.stop()
        radio_sound_player.stream = police_stream
        radio_sound_player.play()
        radio_burst_left = RADIO_BURST_SECONDS
        return
    if blip_playback != null:
        blip_frames_left = int(0.14 * 22050)
        blip_phase = 0.0
        if not blip_player.playing:
            blip_player.play()

func _toggle_radio() -> void:
    # v0.4 (H): RADIO is a power toggle. ON (default): the log panel
    # shows and chatter runs every 20-40 s. OFF: no chatter, no radio
    # sounds, panel hidden. The button always shows the current state.
    radio_on = not radio_on
    if radio_button != null:
        radio_button.text = Settings.t("radio_on" if radio_on else "radio_off")
    radio_panel.visible = radio_on
    if radio_on:
        radio_timer = randf_range(20.0, 40.0)
        if radio_lines.is_empty():
            _radio_push_line()
        else:
            _play_radio_sound()
        _notice(Settings.t("radio_started"))
    else:
        # v0.4.1 FIX: OFF used to hide the panel only — a playing
        # police.mp3 (45 s!) kept running to the end, and the blip
        # kept going too. OFF now stops all radio sound immediately.
        radio_burst_left = 0.0
        if radio_sound_player != null and radio_sound_player.playing:
            radio_sound_player.stop()
        blip_frames_left = 0
        if blip_player != null and blip_player.playing:
            blip_player.stop()
        _notice(Settings.t("radio_stopped"))

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
        button.pressed.connect(_click_then_open.bind(title))
        if title == "RADIO":
            radio_button = button
            button.text = Settings.t("radio_on")

    objective = Label.new()
    objective.position = Vector2(18, 68)
    objective.add_theme_font_size_override("font_size", 22)
    objective.add_theme_color_override("font_color", Color.YELLOW)
    layer.add_child(objective)

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
    resume.pressed.connect(_click_then.bind(_resume_game))
    actions.add_child(resume)

    var settings = Button.new()
    settings.text = "SETTINGS"
    settings.custom_minimum_size = Vector2(140, 60)
    settings.add_theme_font_size_override("font_size", 20)
    settings.pressed.connect(_click_then_open.bind("SETTINGS"))
    actions.add_child(settings)

    exit_button = Button.new()
    exit_button.text = "EXIT"
    exit_button.custom_minimum_size = Vector2(120, 60)
    exit_button.add_theme_font_size_override("font_size", 20)
    exit_button.pressed.connect(_click_then.bind(_exit_game))
    actions.add_child(exit_button)

    var to_menu = Button.new()
    to_menu.text = "MAIN MENU"
    to_menu.custom_minimum_size = Vector2(140, 60)
    to_menu.add_theme_font_size_override("font_size", 20)
    to_menu.pressed.connect(_click_then.bind(_to_main_menu))
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
    if story_panel == null or not story_panel.visible:
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
    _update_story()
    if notice_time > 0.0:
        notice_time -= delta
        if notice_time <= 0.0:
            notice.text = ""

    # Police radio chatter (v0.3): a new line every 20-40 s while playing.
    # v0.4: only while the radio is ON (RADIO button toggles power).
    if radio_on:
        radio_timer -= delta
        if radio_timer <= 0.0:
            radio_timer = randf_range(20.0, 40.0)
            _radio_push_line()
    # v0.4.1: stop the mp3 burst after RADIO_BURST_SECONDS — the file
    # is 45 s and must never play through on a single chatter line.
    if radio_burst_left > 0.0:
        radio_burst_left -= delta
        if radio_burst_left <= 0.0 and radio_sound_player != null and radio_sound_player.playing:
            radio_sound_player.stop()
    # Push the two-tone blip frames (1250 Hz, then 950 Hz).
    if blip_frames_left > 0 and blip_playback != null:
        var avail := blip_playback.get_frames_available()
        var n := mini(avail, blip_frames_left)
        for i in range(n):
            var f := 1250.0 if blip_phase < 0.07 * 22050.0 else 950.0
            # v0.3.1: 0.9 amplitude (was 0.5) — clearly audible.
            var s := sin(TAU * f * blip_phase / 22050.0) * 0.9
            blip_playback.push_frame(Vector2(s, s))
            blip_phase += 1.0
        blip_frames_left -= n
    # Push the UI click frames (0.06 s at 1600 Hz).
    if click_frames_left > 0 and click_playback != null:
        var cavail := click_playback.get_frames_available()
        var cn := mini(cavail, click_frames_left)
        for i in range(cn):
            var cs := sin(TAU * 1600.0 * click_phase / 22050.0) * 0.8
            click_playback.push_frame(Vector2(cs, cs))
            click_phase += 1.0
        click_frames_left -= cn

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
