extends CharacterBody3D

const SPEED = 6.0
const SPRINT_SPEED = 10.0
const JUMP_SPEED = 4.5
# v0.4.2: driving the police car (arcade: joystick steers, RUN boosts).
const DRIVE_SPEED = 12.0
const DRIVE_BOOST_SPEED = 18.0
const DRIVE_REVERSE_SPEED = 5.0
var look_sensitivity := 0.008
# v0.4.2: driving state (set by gameplay._enter_car / _exit_car).
var driving := false
var siren_on := false
var drive_prev_first_person := false
var siren_player: AudioStreamPlayer
var siren_playback: AudioStreamGeneratorPlayback
var siren_phase := 0.0
var siren_tone := 0
var siren_time := 0.0

var yaw := 0.0
var pitch := -0.22
var first_person := false
var player_model: Node3D = null
var move_touch := -1
var look_touch := -1
var jump_touch := -1
var sprint_touch := -1
var interact_touch := -1
var camera_touch := -1
var move_origin := Vector2.ZERO
var touch_move := Vector2.ZERO
var jump_requested := false
var message_timer := 0.0

var camera_pivot: Node3D
var camera: Camera3D
var hud: TouchHUD
var status_label: Label
# v0.3.1: UI click sound (procedural) on the round HUD buttons so every
# tap gives immediate audible feedback.
var click_player: AudioStreamPlayer
var click_playback: AudioStreamGeneratorPlayback
var click_frames_left := 0
var click_phase := 0.0

class TouchHUD extends Control:
    var joystick_vector := Vector2.ZERO
    var mode_label := "3RD"
    var player_ref: Node = null
    func _notification(what):
        if what == NOTIFICATION_RESIZED:
            queue_redraw()

    func _draw():
        var s = get_viewport_rect().size
        var joy = Vector2(100, s.y - 140)
        var jump = Vector2(s.x - 78, s.y - 140)
        var sprint = Vector2(s.x - 196, s.y - 140)
        var interact = Vector2(s.x - 78, s.y - 252)
        var cam = Vector2(s.x - 78, s.y - 364)
        var driving_now: bool = player_ref != null and player_ref.get("driving") == true
        var siren_now: bool = player_ref != null and player_ref.get("siren_on") == true

        draw_circle(joy, 78, Color(0.03, 0.06, 0.10, 0.48))
        draw_arc(joy, 78, 0.0, TAU, 48, Color(0.85, 0.91, 1.0, 0.8), 4.0)
        draw_circle(joy + joystick_vector * 52.0, 32,
            Color(0.60, 0.78, 0.96, 0.85))

        _button(jump, 48, "JUMP", Color(0.15, 0.65, 0.34, 0.82))
        _button(sprint, 44, "RUN", Color(0.14, 0.42, 0.78, 0.82))
        # v0.4.2: while driving, USE becomes EXIT (get out of the car)
        # and the camera button becomes the SIREN toggle.
        _button(interact, 44, "EXIT" if driving_now else "USE", Color(0.80, 0.48, 0.12, 0.85))
        if driving_now:
            _button(cam, 44, "SIREN", Color(0.75, 0.15, 0.25, 0.85) if siren_now else Color(0.45, 0.35, 0.65, 0.85))
        else:
            _button(cam, 44, mode_label, Color(0.45, 0.35, 0.65, 0.85))

    func _button(p: Vector2, r: float, label: String, color: Color):
        draw_circle(p, r, Color(0.02, 0.04, 0.07, 0.45))
        draw_circle(p, r - 4, color)
        draw_arc(p, r, 0.0, TAU, 40, Color(1, 1, 1, 0.85), 2.0)
        draw_string(ThemeDB.fallback_font, p + Vector2(-r + 10, 6),
            label, HORIZONTAL_ALIGNMENT_CENTER, r * 2 - 20, 18, Color.WHITE)

func _ready():
    var collider = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.42
    capsule.height = 1.8
    collider.shape = capsule
    collider.position.y = 0.9
    add_child(collider)

    var character_model = preload("res://scripts/character_model.gd")
    var character = character_model.build(3)
    if character != null:
        character.name = "PlayerCharacter"
        add_child(character)
        player_model = character
    else:
        var fallback = MeshInstance3D.new()
        var body_mesh = CapsuleMesh.new()
        body_mesh.radius = 0.42
        body_mesh.height = 1.8
        fallback.mesh = body_mesh
        fallback.position.y = 0.9
        var fallback_material = StandardMaterial3D.new()
        fallback_material.albedo_color = Color(0.85, 0.48, 0.25)
        fallback.material_override = fallback_material
        add_child(fallback)
        player_model = fallback


    camera_pivot = Node3D.new()
    camera_pivot.position.y = 1.4
    add_child(camera_pivot)

    camera = Camera3D.new()
    camera.position = Vector3(0, 2.4, 6.5)
    camera.rotation.x = pitch
    camera.current = true
    camera_pivot.add_child(camera)

    # Restore the saved camera view (1st / 3rd person).
    first_person = Settings.first_person
    _apply_camera_mode()

    var hud_layer = CanvasLayer.new()
    hud_layer.layer = 10
    add_child(hud_layer)

    hud = TouchHUD.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.player_ref = self
    hud_layer.add_child(hud)

    status_label = Label.new()
    status_label.text = "KASSERINE CITY"
    status_label.position = Vector2(20, 16)
    status_label.add_theme_font_size_override("font_size", 26)
    status_label.add_theme_color_override("font_color", Color.WHITE)
    hud_layer.add_child(status_label)

    get_viewport().size_changed.connect(_refresh_hud)
    _refresh_hud()

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

    # v0.4.2: police siren — two-tone wail (700 / 950 Hz), generated
    # like the click player. Frames are pushed in _process only while
    # the siren is on; otherwise the player runs silent.
    var sgen := AudioStreamGenerator.new()
    sgen.mix_rate = 22050
    sgen.buffer_length = 0.2
    siren_player = AudioStreamPlayer.new()
    siren_player.stream = sgen
    siren_player.volume_db = -8.0
    add_child(siren_player)
    siren_player.play()
    siren_playback = siren_player.get_stream_playback() as AudioStreamGeneratorPlayback

func toggle_siren() -> void:
    if not driving:
        return
    siren_on = not siren_on
    _play_click()
    if hud != null:
        hud.queue_redraw()

func _play_click() -> void:
    if click_playback != null:
        click_frames_left = int(0.06 * 22050)
        click_phase = 0.0
        if not click_player.playing:
            click_player.play()

func _refresh_hud():
    if is_instance_valid(hud):
        hud.joystick_vector = touch_move
        hud.queue_redraw()

func toggle_camera() -> void:
    first_person = not first_person
    Settings.first_person = first_person
    Settings.save_settings()
    _apply_camera_mode()

func _apply_camera_mode() -> void:
    if camera == null:
        return
    if first_person:
        # Head height, looking where the player looks; the body is hidden
        # so the camera never clips through the character mesh.
        camera.position = Vector3(0, 0.25, 0)
        if player_model != null:
            player_model.visible = false
    else:
        camera.position = Vector3(0, 2.4, 6.5)
        if player_model != null:
            player_model.visible = true
    if hud != null:
        hud.mode_label = "1ST" if first_person else "3RD"
        hud.queue_redraw()

func _point(action: String) -> Vector2:
    var s = get_viewport().get_visible_rect().size
    match action:
        "jump":
            return Vector2(s.x - 78, s.y - 140)
        "sprint":
            return Vector2(s.x - 196, s.y - 140)
        "interact":
            return Vector2(s.x - 78, s.y - 252)
        "camera":
            return Vector2(s.x - 78, s.y - 364)
        _:
            return Vector2(100, s.y - 140)

func _near(p: Vector2, center: Vector2, radius: float) -> bool:
    return p.distance_to(center) <= radius

func _input(event):
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_C:
            toggle_camera()
            return
    if event is InputEventScreenTouch:
        var s = get_viewport().get_visible_rect().size

        if event.pressed:
            if jump_touch == -1 and _near(event.position, _point("jump"), 56):
                jump_touch = event.index
                jump_requested = true
                _play_click()
                hud.joystick_vector = touch_move
                hud.queue_redraw()
            elif sprint_touch == -1 and _near(event.position, _point("sprint"), 52):
                sprint_touch = event.index
                _play_click()
                hud.joystick_vector = touch_move
                hud.queue_redraw()
            elif interact_touch == -1 and _near(event.position, _point("interact"), 52):
                interact_touch = event.index
                _play_click()
                get_parent().interact()
            elif camera_touch == -1 and _near(event.position, _point("camera"), 52):
                camera_touch = event.index
                # v0.4.2: while driving this button is SIREN, not camera.
                if driving:
                    toggle_siren()
                else:
                    _play_click()
                    toggle_camera()
            elif move_touch == -1 and _near(event.position, _point("move"), 96):
                move_touch = event.index
                move_origin = event.position
                touch_move = Vector2.ZERO
                hud.joystick_vector = touch_move
                hud.queue_redraw()
            elif look_touch == -1 and event.position.x > s.x * 0.42 \
                    and event.position.y < s.y - 300:
                look_touch = event.index
        else:
            if event.index == move_touch:
                move_touch = -1
                touch_move = Vector2.ZERO
                hud.joystick_vector = touch_move
                hud.queue_redraw()
            if event.index == look_touch:
                look_touch = -1
            if event.index == jump_touch:
                jump_touch = -1
            if event.index == sprint_touch:
                sprint_touch = -1
            if event.index == interact_touch:
                interact_touch = -1
            if event.index == camera_touch:
                camera_touch = -1

    elif event is InputEventScreenDrag:
        if event.index == move_touch:
            var delta = (event.position - move_origin) / 60.0
            touch_move = Vector2(
                clamp(delta.x, -1.0, 1.0),
                clamp(delta.y, -1.0, 1.0)
            )
            hud.joystick_vector = touch_move
            hud.queue_redraw()
        elif event.index == look_touch:
            yaw -= event.relative.x * look_sensitivity
            pitch = clamp(pitch - event.relative.y * look_sensitivity, -0.75, 0.35)
            camera_pivot.rotation.y = yaw - rotation.y
            camera.rotation.x = pitch

func _show_message(message: String):
    status_label.text = message
    message_timer = 2.5

func _process(delta):
    if message_timer > 0.0:
        message_timer -= delta
        if message_timer <= 0.0 and is_instance_valid(status_label):
            status_label.text = "KASSERINE CITY"
    # Push the UI click frames (0.06 s at 1600 Hz).
    if click_frames_left > 0 and click_playback != null:
        var avail := click_playback.get_frames_available()
        var n := mini(avail, click_frames_left)
        for i in range(n):
            var s := sin(TAU * 1600.0 * click_phase / 22050.0) * 0.8
            click_playback.push_frame(Vector2(s, s))
            click_phase += 1.0
        click_frames_left -= n
    # v0.4.2: police siren — two-tone wail while driving with siren on.
    if siren_on and siren_playback != null:
        var savail := siren_playback.get_frames_available()
        var sn := mini(savail, 1024)
        for i in range(sn):
            siren_phase += 1.0 / 22050.0
            if siren_phase >= 0.45:
                siren_phase = 0.0
                siren_tone = 1 - siren_tone
            var sf := 700.0 if siren_tone == 0 else 950.0
            var ss := sin(TAU * sf * siren_time / 22050.0) * 0.5
            siren_playback.push_frame(Vector2(ss, ss))
            siren_time += 1.0

func _physics_process(delta):
    if not is_on_floor():
        velocity.y -= 18.0 * delta

    var input_dir = Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        input_dir.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        input_dir.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        input_dir.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        input_dir.y += 1

    if touch_move.length() > 0.08:
        input_dir = touch_move

    var forward = -camera_pivot.global_basis.z
    var right = camera_pivot.global_basis.x
    forward.y = 0
    right.y = 0
    forward = forward.normalized()
    right = right.normalized()
    var direction = (right * input_dir.x - forward * input_dir.y).normalized()

    var current_speed = SPRINT_SPEED if sprint_touch != -1 else SPEED
    # v0.4.2: driving speeds — the police car is faster than running,
    # RUN is the boost, joystick down reverses. No strafing: a car only
    # moves along its forward/back axis.
    if driving:
        var fwd: float = -input_dir.y
        if fwd > 0.05:
            current_speed = DRIVE_BOOST_SPEED if sprint_touch != -1 else DRIVE_SPEED
        elif fwd < -0.05:
            current_speed = DRIVE_REVERSE_SPEED
        else:
            current_speed = 0.0

    if direction.length() > 0.01 and current_speed > 0.0:
        velocity.x = direction.x * current_speed
        velocity.z = direction.z * current_speed
        if first_person:
            # In first person the body turns with the look direction.
            rotation.y = yaw
            camera_pivot.rotation.y = 0.0
        else:
            rotation.y = atan2(-direction.x, -direction.z)
            camera_pivot.rotation.y = yaw - rotation.y
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED * 4 * delta)
        velocity.z = move_toward(velocity.z, 0, SPEED * 4 * delta)
        if first_person:
            rotation.y = yaw
            camera_pivot.rotation.y = 0.0

    # v0.4.2: no jumping while driving.
    if not driving and (jump_requested or Input.is_key_pressed(KEY_SPACE)) and is_on_floor():
        velocity.y = JUMP_SPEED
    jump_requested = false

    move_and_slide()
