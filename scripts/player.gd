extends CharacterBody3D

const SPEED = 6.0
const SPRINT_SPEED = 10.0
const JUMP_SPEED = 4.5
var look_sensitivity := 0.008

var yaw := 0.0
var pitch := -0.27
var move_touch := -1
var look_touch := -1
var jump_touch := -1
var sprint_touch := -1
var interact_touch := -1
var move_origin := Vector2.ZERO
var touch_move := Vector2.ZERO
var jump_requested := false
var message_timer := 0.0

var camera_pivot: Node3D
var camera: Camera3D
var hud: TouchHUD
var status_label: Label
var character_anim: AnimationPlayer

class TouchHUD extends Control:
    var joystick_vector := Vector2.ZERO
    func _notification(what):
        if what == NOTIFICATION_RESIZED:
            queue_redraw()

    func _draw():
        var s = get_viewport_rect().size
        var joy = Vector2(86, s.y - 112)
        var jump = Vector2(s.x - 68, s.y - 112)
        var sprint = Vector2(s.x - 164, s.y - 112)
        var interact = Vector2(s.x - 68, s.y - 205)

        draw_circle(joy, 62, Color(0.03, 0.06, 0.10, 0.48))
        draw_arc(joy, 62, 0.0, TAU, 48, Color(0.85, 0.91, 1.0, 0.8), 3.0)
        draw_circle(joy + joystick_vector * 40.0, 25,
            Color(0.60, 0.78, 0.96, 0.85))

        _button(jump, 39, "JUMP", Color(0.15, 0.65, 0.34, 0.82))
        _button(sprint, 35, "RUN", Color(0.14, 0.42, 0.78, 0.82))
        _button(interact, 35, "USE", Color(0.80, 0.48, 0.12, 0.85))

    func _button(p: Vector2, r: float, label: String, color: Color):
        draw_circle(p, r, Color(0.02, 0.04, 0.07, 0.45))
        draw_circle(p, r - 4, color)
        draw_arc(p, r, 0.0, TAU, 40, Color(1, 1, 1, 0.85), 2.0)
        draw_string(ThemeDB.fallback_font, p + Vector2(-r + 8, 5),
            label, HORIZONTAL_ALIGNMENT_CENTER, r * 2 - 16, 14, Color.WHITE)

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
        character_anim = character_model.setup_animations(character)
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


    camera_pivot = Node3D.new()
    camera_pivot.position.y = 1.4
    add_child(camera_pivot)

    camera = Camera3D.new()
    camera.position = Vector3(0, 3.0, 7.6)
    camera.rotation.x = pitch
    camera.fov = 75.0
    camera.current = true
    camera_pivot.add_child(camera)

    var hud_layer = CanvasLayer.new()
    hud_layer.layer = 10
    add_child(hud_layer)

    hud = TouchHUD.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(hud)

    status_label = Label.new()
    status_label.text = "KASSERINE CITY"
    status_label.position = Vector2(20, 18)
    status_label.add_theme_font_size_override("font_size", 20)
    status_label.add_theme_color_override("font_color", Color.WHITE)
    hud_layer.add_child(status_label)

    get_viewport().size_changed.connect(_refresh_hud)
    _refresh_hud()

func _refresh_hud():
    if is_instance_valid(hud):
        hud.joystick_vector = touch_move
        hud.queue_redraw()

func _point(action: String) -> Vector2:
    var s = get_viewport().get_visible_rect().size
    match action:
        "jump":
            return Vector2(s.x - 68, s.y - 112)
        "sprint":
            return Vector2(s.x - 164, s.y - 112)
        "interact":
            return Vector2(s.x - 68, s.y - 205)
        _:
            return Vector2(86, s.y - 112)

func _near(p: Vector2, center: Vector2, radius: float) -> bool:
    return p.distance_to(center) <= radius

func _input(event):
    if event is InputEventScreenTouch:
        var s = get_viewport().get_visible_rect().size

        if event.pressed:
            if jump_touch == -1 and _near(event.position, _point("jump"), 48):
                jump_touch = event.index
                jump_requested = true
                hud.joystick_vector = touch_move
                hud.queue_redraw()
            elif sprint_touch == -1 and _near(event.position, _point("sprint"), 44):
                sprint_touch = event.index
                hud.joystick_vector = touch_move
                hud.queue_redraw()
            elif interact_touch == -1 and _near(event.position, _point("interact"), 44):
                interact_touch = event.index
                get_parent().interact()
            elif move_touch == -1 and _near(event.position, _point("move"), 82):
                move_touch = event.index
                move_origin = event.position
                touch_move = Vector2.ZERO
                hud.joystick_vector = touch_move
                hud.queue_redraw()
            elif look_touch == -1 and event.position.x > s.x * 0.42 \
                    and event.position.y < s.y - 255:
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

    if direction.length() > 0.01:
        velocity.x = direction.x * current_speed
        velocity.z = direction.z * current_speed
        rotation.y = atan2(-direction.x, -direction.z)
        camera_pivot.rotation.y = yaw - rotation.y
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED * 4 * delta)
        velocity.z = move_toward(velocity.z, 0, SPEED * 4 * delta)

    if (jump_requested or Input.is_key_pressed(KEY_SPACE)) and is_on_floor():
        velocity.y = JUMP_SPEED
    jump_requested = false

    move_and_slide()
    _update_character_animation(direction)

func _update_character_animation(direction: Vector3) -> void:
    if not is_instance_valid(character_anim):
        return

    if not is_on_floor():
        if character_anim.current_animation != "jump":
            if character_anim.has_animation("jump"):
                character_anim.play("jump", 0.08)
        return

    if direction.length() > 0.01:
        if character_anim.has_animation("run"):
            if character_anim.current_animation != "run":
                character_anim.play("run", 0.12)
            character_anim.speed_scale = 1.35 if sprint_touch != -1 else 1.0
    else:
        if character_anim.has_animation("idle"):
            if character_anim.current_animation != "idle":
                character_anim.play("idle", 0.15)
            character_anim.speed_scale = 1.0
