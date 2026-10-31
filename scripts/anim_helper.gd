extends RefCounted

const CLIPS = {
    "idle": "res://assets/characters/idle.fbx",
    "run": "res://assets/characters/run.fbx",
    "jump": "res://assets/characters/jump.fbx",
}

static func _find(node: Node, cls: String) -> Node:
    if node.is_class(cls):
        return node
    for c in node.get_children():
        var r := _find(c, cls)
        if r:
            return r
    return null

static func _remap(anim: Animation, model: Node3D, skel: Skeleton3D) -> int:
    var matched := 0
    var skel_path := String(model.get_path_to(skel))
    for i in range(anim.get_track_count()):
        var p := anim.track_get_path(i)
        if p.get_subname_count() == 0:
            continue
        var bone := String(p.get_concatenated_subnames())
        if skel.find_bone(bone) < 0:
            continue
        anim.track_set_path(i, NodePath(skel_path + ":" + bone))
        matched += 1
    return matched

static func setup(model: Node3D) -> void:
    var skel := _find(model, "Skeleton3D") as Skeleton3D
    if skel == null:
        model.set_meta("anim_status", "no skeleton, procedural")
        return
    var lib := AnimationLibrary.new()
    var total_matched := 0
    var total_tracks := 0
    for clip_name in CLIPS:
        var packed := load(CLIPS[clip_name]) as PackedScene
        if packed == null:
            continue
        var inst := packed.instantiate()
        var src := _find(inst, "AnimationPlayer") as AnimationPlayer
        if src != null:
            var picked: Animation = null
            for n in src.get_animation_list():
                if String(n) == "RESET":
                    continue
                picked = src.get_animation(n)
                break
            if picked != null:
                var anim := picked.duplicate() as Animation
                anim.loop_mode = Animation.LOOP_NONE if clip_name == "jump" else Animation.LOOP_LINEAR
                total_tracks += anim.get_track_count()
                total_matched += _remap(anim, model, skel)
                lib.add_animation(clip_name, anim)
        inst.free()
    if total_matched == 0 or not lib.has_animation("idle"):
        model.set_meta("anim_status", "no bone match (%d tracks), procedural" % total_tracks)
        return
    var ap := AnimationPlayer.new()
    ap.name = "AnimPlayer"
    model.add_child(ap)
    ap.root_node = NodePath("..")
    ap.add_animation_library("", lib)
    ap.autoplay = "idle"
    model.set_meta("anim_status", "OK, %d/%d tracks, clips: %s" % [total_matched, total_tracks, ", ".join(lib.get_animation_list())])
