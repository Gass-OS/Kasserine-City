extends CharacterBody3D

const SPEED = 6.0
const JUMP_SPEED = 4.5
const LOOK_SENSITIVITY = 0.008

var yaw := 0.0
var pitch := -0.22
var move_touch := -1
var look_touch := -1
var move_origin := Vector2.ZERO
var move_current := Vector2.ZERO
var touch_move := Vector2.ZERO
var camera_pivot: Node3D
var camera: Camera3D

func _ready():
    var collider = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.42
    capsule.height = 1.8
    collider.shape = capsule
    collider.position.y = 0.9
    add_child(collider)

    var character = MeshInstance3D.new()
    var body_mesh = CapsuleMesh.new()
    body_mesh.radius = 0.42
    body_mesh.height = 1.8
    character.mesh = body_mesh
    character.position.y = 0.9
    var skin = StandardMaterial3D.new()
    skin.albedo_color = Color(0.85, 0.48, 0.25)
    character.material_override = skin
    add_child(character)

    camera_pivot = Node3D.new()
    camera_pivot.position.y = 1.4
    add_child(camera_pivot)

    camera = Camera3D.new()
    camera.position = Vector3(0, 2.4, 6.5)
    camera.rotation.x = -0.25
    camera.current = true
    camera_pivot.add_child(camera)

    var hud_layer = CanvasLayer.new()
    add_child(hud_layer)
    var hud = Label.new()
    hud.text = "KASSERINE CITY  |  Drag left to move  |  Drag right to look"
    hud.position = Vector2(20, 20)
    hud.add_theme_font_size_override("font_size", 17)
    hud.add_theme_color_override("font_color", Color.WHITE)
    hud_layer.add_child(hud)

func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < get_viewport().get_visible_rect().size.x * 0.5 and move_touch == -1:
                move_touch = event.index
                move_origin = event.position
                move_current = event.position
                touch_move = Vector2.ZERO
            elif look_touch == -1:
                look_touch = event.index
        else:
            if event.index == move_touch:
                move_touch = -1
                touch_move = Vector2.ZERO
            if event.index == look_touch:
                look_touch = -1

    elif event is InputEventScreenDrag:
        if event.index == move_touch:
            move_current = event.position
            var delta = move_current - move_origin
            touch_move = Vector2(clamp(delta.x / 75.0, -1.0, 1.0), clamp(delta.y / 75.0, -1.0, 1.0))
        elif event.index == look_touch:
            yaw -= event.relative.x * LOOK_SENSITIVITY
            pitch = clamp(pitch - event.relative.y * LOOK_SENSITIVITY, -0.75, 0.35)
            camera_pivot.rotation.y = yaw
            camera.rotation.x = pitch

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

    if direction.length() > 0.01:
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
        rotation.y = atan2(-direction.x, -direction.z)
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED * 4 * delta)
        velocity.z = move_toward(velocity.z, 0, SPEED * 4 * delta)

    if (Input.is_key_pressed(KEY_SPACE)) and is_on_floor():
        velocity.y = JUMP_SPEED

    move_and_slide()
