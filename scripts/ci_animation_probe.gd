extends SceneTree

func _initialize():
    call_deferred("_probe")

func _probe():
    var paths = [
        "res://assets/characters/characterMedium.fbx",
        "res://assets/characters/idle.fbx",
        "res://assets/characters/run.fbx",
        "res://assets/characters/jump.fbx"
    ]

    for path in paths:
        print("\n========== RESOURCE: ", path, " ==========")
        var packed = load(path) as PackedScene
        if packed == null:
            print("ERROR: Could not load PackedScene")
            continue

        var root = packed.instantiate()
        _walk(root, "")
        root.free()

    print("\n========== PROBE COMPLETE ==========")
    quit()

func _walk(node: Node, prefix: String):
    var full_path = prefix + "/" + node.name
    print("NODE: ", full_path, " | TYPE: ", node.get_class())

    if node is Skeleton3D:
        var skeleton = node as Skeleton3D
        print("SKELETON BONES: ", skeleton.get_bone_count())
        for i in range(skeleton.get_bone_count()):
            print("BONE ", i, ": ", skeleton.get_bone_name(i))

    if node is AnimationPlayer:
        var player = node as AnimationPlayer
        for library_name in player.get_animation_library_list():
            var library = player.get_animation_library(library_name)
            print("ANIMATION LIBRARY: ", library_name)
            for animation_name in library.get_animation_list():
                var animation = library.get_animation(animation_name)
                print("CLIP: ", animation_name,
                    " | LENGTH: ", animation.length,
                    " | TRACKS: ", animation.get_track_count())
                for i in range(animation.get_track_count()):
                    print("TRACK ", i, ": ",
                        animation.track_get_path(i))

    for child in node.get_children():
        _walk(child, full_path)
