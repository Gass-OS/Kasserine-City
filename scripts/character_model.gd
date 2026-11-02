extends RefCounted

const MODEL_PATH = "res://assets/characters/characterMedium.fbx"
const SKINS = [
    "res://assets/characters/criminalMaleA.png",
    "res://assets/characters/cyborgFemaleA.png",
    "res://assets/characters/skaterFemaleA.png",
    "res://assets/characters/skaterMaleA.png"
]

static func build(skin_index: int) -> Node3D:
    if not ResourceLoader.exists(MODEL_PATH):
        push_error("GassCharacter: FBX resource does not exist: " + MODEL_PATH)
        return null

    var resource := ResourceLoader.load(MODEL_PATH)
    if resource == null:
        push_error("GassCharacter: FBX load returned null. Resource type: " + ResourceLoader.get_resource_type(MODEL_PATH))
        return null

    var packed := resource as PackedScene
    if packed == null:
        push_error("GassCharacter: FBX is not a PackedScene. Loaded type: " + resource.get_class())
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
    model.rotation.y = PI
    preload("res://scripts/anim_helper.gd").setup(model)
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
