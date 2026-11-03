extends RefCounted

const MODEL_PATH = "res://assets/characters/characterMedium.fbx"
const SKINS = [
    "res://assets/characters/criminalMaleA.png",
    "res://assets/characters/cyborgFemaleA.png",
    "res://assets/characters/skaterFemaleA.png",
    "res://assets/characters/skaterMaleA.png"
]

static func build(skin_index: int) -> Node3D:
    var packed = load(MODEL_PATH) as PackedScene
    if packed == null:
        push_warning("GassCharacter: FBX model failed to load")
        return null

    var model = packed.instantiate() as Node3D
    if model == null:
        push_warning("GassCharacter: FBX root is not Node3D")
        return null

    var texture = load(SKINS[posmod(skin_index, SKINS.size())]) as Texture2D
    if texture != null:
        _apply_skin(model, texture)

    model.name = "KenneyCharacter"
    model.scale = Vector3.ONE * 0.45
    return model

static func _apply_skin(node: Node, texture: Texture2D) -> void:
    if node is MeshInstance3D:
        var instance = node as MeshInstance3D
        if instance.mesh != null:
            for surface_index in range(instance.mesh.get_surface_count()):
                var material = StandardMaterial3D.new()
                material.albedo_texture = texture
                material.roughness = 0.85
                instance.set_surface_override_material(surface_index, material)

    for child in node.get_children():
        _apply_skin(child, texture)


static func setup_animations(model: Node3D) -> AnimationPlayer:
    var library = AnimationLibrary.new()
    var sources = [
        ["res://assets/characters/idle.fbx", "Root|Idle", "idle", true],
        ["res://assets/characters/run.fbx", "Root|Run", "run", true],
        ["res://assets/characters/jump.fbx", "Root|Jump", "jump", false]
    ]

    for source in sources:
        var packed = load(source[0]) as PackedScene
        if packed == null:
            push_warning("GassCharacter: Animation scene missing: " + source[0])
            continue

        var scene = packed.instantiate()
        var source_player = scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
        if source_player != null and source_player.has_animation(source[1]):
            var clip = source_player.get_animation(source[1]).duplicate(true) as Animation
            clip.loop_mode = Animation.LOOP_LINEAR if source[3] else Animation.LOOP_NONE
            library.add_animation(source[2], clip)
        else:
            push_warning("GassCharacter: Animation clip missing: " + source[1])
        scene.free()

    if library.get_animation_list().is_empty():
        push_warning("GassCharacter: No usable animation clips")
        return null

    var player = AnimationPlayer.new()
    player.name = "GameAnimationPlayer"
    player.root_node = NodePath("..")
    model.add_child(player)
    player.add_animation_library("", library)

    if player.has_animation("idle"):
        player.play("idle")
    elif player.has_animation("run"):
        player.play("run")

    return player
