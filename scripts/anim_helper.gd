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

static func _norm(s: String) -> String:
    var out := ""
    var low := s.to_lower()
    for i in range(low.length()):
        var ch := low[i]
        if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
            out += ch
    return out

static func _bone_map(skel: Skeleton3D) -> Dictionary:
    var m := {}
    for i in range(skel.get_bone_count()):
        var bn := skel.get_bone_name(i)
        m[_norm(bn)] = bn
    return m

static func _match(bone: String, bmap: Dictionary) -> String:
    var nb := _norm(bone)
    if nb == "":
        return ""
    if bmap.has(nb):
        return bmap[nb]
    for k in bmap.keys():
        var ks := String(k)
        if ks.length() > 3 and nb.length() > 3 and (ks.ends_with(nb) or nb.ends_with(ks)):
            return bmap[k]
    return ""

static func setup(model: Node3D) -> void:
    var skel := _find(model, "Skeleton3D") as Skeleton3D
    if skel == null:
        model.set_meta("anim_status", "no Skeleton3D in model -> procedural")
        return
    var bmap := _bone_map(skel)
    var names: Array = []
    for i in range(mini(skel.get_bone_count(), 6)):
        names.append(skel.get_bone_name(i))
    var report := "Skeleton: %d bones (%s...)" % [skel.get_bone_count(), ", ".join(names)]
    var lib := AnimationLibrary.new()
    var skel_path := String(model.get_path_to(skel))
    for clip_name in CLIPS:
        var packed := load(CLIPS[clip_name]) as PackedScene
        if packed == null:
            report += "\n%s: FBX failed to load" % clip_name
            continue
        var inst := packed.instantiate()
        var src := _find(inst, "AnimationPlayer") as AnimationPlayer
        if src == null:
            report += "\n%s: no AnimationPlayer in FBX" % clip_name
            inst.free()
            continue
        var best: Animation = null
        var best_name := ""
        for n in src.get_animation_list():
            if String(n) == "RESET":
                continue
            var a := src.get_animation(n)
            if best == null or a.get_track_count() > best.get_track_count():
                best = a
                best_name = String(n)
        if best == null:
            report += "\n%s: no animations" % clip_name
            inst.free()
            continue
        var anim := best.duplicate() as Animation
        var total := anim.get_track_count()
        var sample := ""
        if total > 0:
            sample = String(anim.track_get_path(0))
        var matched := 0
        for i in range(total - 1, -1, -1):
            var p := anim.track_get_path(i)
            var real := ""
            if p.get_subname_count() > 0:
                real = _match(String(p.get_concatenated_subnames()), bmap)
            if real == "":
                anim.remove_track(i)
            else:
                anim.track_set_path(i, NodePath(skel_path + ":" + real))
                matched += 1
        if clip_name == "jump":
            anim.loop_mode = Animation.LOOP_NONE
        else:
            anim.loop_mode = Animation.LOOP_LINEAR
        report += "\n%s: '%s' tracks %d matched %d e.g. %s" % [clip_name, best_name, total, matched, sample]
        if matched > 0:
            lib.add_animation(clip_name, anim)
        inst.free()
    if lib.get_animation_list().size() == 0:
        model.set_meta("anim_status", "NO MATCH -> procedural\n" + report)
        return
    var ap := AnimationPlayer.new()
    ap.name = "AnimPlayer"
    model.add_child(ap)
    ap.root_node = NodePath("..")
    ap.add_animation_library("", lib)
    if lib.has_animation("idle"):
        ap.autoplay = "idle"
    model.set_meta("anim_status", "OK\n" + report)
