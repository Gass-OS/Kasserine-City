extends RefCounted

const RATE := 22050
static var _cache := {}

static func _pack(data: PackedByteArray, loop: bool) -> AudioStreamWAV:
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = RATE
    w.stereo = false
    w.data = data
    if loop:
        w.loop_mode = AudioStreamWAV.LOOP_FORWARD
        w.loop_begin = 0
        w.loop_end = int(data.size() * 0.5)
    return w

static func tone(f0: float, f1: float, dur: float, vol: float, noise: float) -> AudioStreamWAV:
    var n := int(dur * float(RATE))
    var data := PackedByteArray()
    data.resize(n * 2)
    var ph := 0.0
    for i in range(n):
        var t := float(i) / float(n)
        ph += TAU * lerpf(f0, f1, t) / float(RATE)
        var s := sin(ph) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
        var env := minf(1.0, t * 30.0) * minf(1.0, (1.0 - t) * 12.0)
        data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
    return _pack(data, false)

static func _noise_burst(dur: float, vol: float, decay: float, smooth: float) -> AudioStreamWAV:
    var n := int(dur * float(RATE))
    var data := PackedByteArray()
    data.resize(n * 2)
    var prev := 0.0
    for i in range(n):
        var t := float(i) / float(n)
        prev = prev * smooth + (randf() * 2.0 - 1.0) * (1.0 - smooth)
        var env := exp(-t * decay) * minf(1.0, t * 40.0)
        data.encode_s16(i * 2, int(clampf(prev * env * vol, -1.0, 1.0) * 32767.0))
    return _pack(data, false)

static func _noise_loop(dur: float, vol: float, smooth: float) -> AudioStreamWAV:
    var n := int(dur * float(RATE))
    var data := PackedByteArray()
    data.resize(n * 2)
    var prev := 0.0
    for i in range(n):
        prev = prev * smooth + (randf() * 2.0 - 1.0) * (1.0 - smooth)
        data.encode_s16(i * 2, int(clampf(prev * vol, -1.0, 1.0) * 32767.0))
    return _pack(data, true)

static func _crash() -> AudioStreamWAV:
    var n := int(0.8 * float(RATE))
    var data := PackedByteArray()
    data.resize(n * 2)
    for i in range(n):
        var t := float(i) / float(n)
        var thump := sin(TAU * 62.0 * float(i) / float(RATE)) * exp(-t * 7.0) * 0.7
        var nz := (randf() * 2.0 - 1.0) * exp(-t * 5.0) * 0.8
        data.encode_s16(i * 2, int(clampf((thump + nz) * 0.8, -1.0, 1.0) * 32767.0))
    return _pack(data, false)

static func _engine() -> AudioStreamWAV:
    var n := int(0.4 * float(RATE))
    var data := PackedByteArray()
    data.resize(n * 2)
    for i in range(n):
        var t := float(i) / float(RATE)
        var s := sin(TAU * 50.0 * t) * 0.5 + sin(TAU * 100.0 * t) * 0.28 + sin(TAU * 150.0 * t) * 0.14 + (randf() * 2.0 - 1.0) * 0.05
        data.encode_s16(i * 2, int(clampf(s * 0.6, -1.0, 1.0) * 32767.0))
    return _pack(data, true)

static func _siren() -> AudioStreamWAV:
    var n := int(1.6 * float(RATE))
    var data := PackedByteArray()
    data.resize(n * 2)
    var ph := 0.0
    for i in range(n):
        var t := float(i) / float(n)
        var f := 620.0 + 480.0 * (0.5 - 0.5 * cos(TAU * t))
        ph += TAU * f / float(RATE)
        var s := sin(ph) * 0.5 + sin(ph * 2.0) * 0.12
        data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
    return _pack(data, true)

static func _horn() -> AudioStreamWAV:
    var n := int(0.48 * float(RATE))
    var data := PackedByteArray()
    data.resize(n * 2)
    var phase_a := 0.0
    var phase_b := 0.0
    for i in range(n):
        var t := float(i) / float(n)
        phase_a += TAU * 430.0 / float(RATE)
        phase_b += TAU * 540.0 / float(RATE)
        var pulse := 1.0 if t < 0.34 else 0.0
        var fade := minf(1.0, t * 35.0) * minf(1.0, (0.34 - t) * 18.0)
        var sample := (sin(phase_a) * 0.65 + sin(phase_b) * 0.35) * pulse * fade
        data.encode_s16(i * 2, int(clampf(sample * 0.65, -1.0, 1.0) * 32767.0))
    return _pack(data, false)

static func get_sound(n: String) -> AudioStreamWAV:
    if _cache.has(n):
        return _cache[n]
    var s: AudioStreamWAV
    match n:
        "footstep":
            s = _noise_burst(0.13, 0.30, 18.0, 0.72)
        "horn":
            s = _horn()
        "squelch":
            s = _noise_burst(0.14, 0.5, 5.0, 0.0)
        "beep":
            s = tone(1250.0, 1250.0, 0.08, 0.3, 0.0)
        "roger":
            s = tone(900.0, 1400.0, 0.12, 0.3, 0.0)
        "click":
            s = tone(2200.0, 700.0, 0.07, 0.5, 0.2)
        "whistle":
            s = tone(2100.0, 2700.0, 0.45, 0.35, 0.0)
        "crash":
            s = _crash()
        "thunder":
            s = _noise_burst(3.0, 8.0, 1.5, 0.985)
        "rain":
            s = _noise_loop(2.0, 1.1, 0.55)
        "wind":
            s = _noise_loop(2.5, 4.0, 0.95)
        "engine":
            s = _engine()
        "siren":
            s = _siren()
        _:
            s = tone(800.0, 800.0, 0.1, 0.2, 0.0)
    _cache[n] = s
    return s

static func play(parent: Node, n: String, vol_db: float) -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.stream = get_sound(n)
    p.volume_db = vol_db
    parent.add_child(p)
    p.finished.connect(p.queue_free)
    p.play()
    return p

const VR := 16000
const VOWELS = [[730.0, 1090.0], [530.0, 1840.0], [270.0, 2290.0], [570.0, 840.0], [300.0, 870.0], [660.0, 1700.0]]

static func _horn() -> AudioStreamWAV:
    var n := int(0.45 * float(RATE))
    var data := PackedByteArray()
    data.resize(n * 2)
    for i in range(n):
        var t := float(i) / float(RATE)
        var e := minf(1.0, float(i) / 400.0) * minf(1.0, float(n - i) / 1500.0)
        var s := (sin(TAU * 410.0 * t) + sin(TAU * 520.0 * t) * 0.8 + sin(TAU * 820.0 * t) * 0.2) * 0.33
        data.encode_s16(i * 2, int(clampf(s * e, -1.0, 1.0) * 32767.0 * 0.8))
    return _pack(data, false)

static func _bird() -> AudioStreamWAV:
    var n := int(0.7 * float(RATE))
    var data := PackedByteArray()
    data.resize(n * 2)
    var ph := 0.0
    for i in range(n):
        var t := float(i) / float(n)
        var k := int(t * 3.0)
        var u := t * 3.0 - float(k)
        var f := lerpf(3200.0 + float(k) * 500.0, 4600.0 + float(k) * 300.0, u)
        ph += TAU * f / float(RATE)
        var e := pow(sin(PI * u), 2.0) * (1.0 if u < 0.8 else 0.0)
        data.encode_s16(i * 2, int(clampf(sin(ph) * e * 0.5, -1.0, 1.0) * 32767.0))
    return _pack(data, false)

static func _cricket() -> AudioStreamWAV:
    var n := RATE
    var data := PackedByteArray()
    data.resize(n * 2)
    for i in range(n):
        var t := float(i) / float(RATE)
        var pulse := 1.0 if (0.5 + 0.5 * sin(TAU * 28.0 * t)) > 0.6 else 0.0
        var burst := 1.0 if fposmod(t * 3.0, 1.0) < 0.35 else 0.0
        data.encode_s16(i * 2, int(clampf(sin(TAU * 4300.0 * t) * pulse * burst * 0.35, -1.0, 1.0) * 32767.0))
    return _pack(data, true)

static func extra(n: String) -> AudioStreamWAV:
    if _cache.has(n):
        return _cache[n]
    var s: AudioStreamWAV
    match n:
        "horn":
            s = _horn()
        "step":
            s = _noise_burst(0.09, 1.2, 28.0, 0.72)
        "bird":
            s = _bird()
        "cricket":
            s = _cricket()
        "water":
            s = _noise_loop(2.0, 1.0, 0.55)
        "hum":
            s = _noise_loop(2.0, 5.0, 0.985)
        _:
            s = tone(800.0, 800.0, 0.1, 0.2, 0.0)
    _cache[n] = s
    return s

static func _res(fc: float, bw: float) -> Array:
    var r := exp(-PI * bw / float(VR))
    var th := TAU * fc / float(VR)
    return [1.0 - r, 2.0 * r * cos(th), -r * r]

static func voice_clip(variant: int, angry: bool) -> AudioStreamWAV:
    var key := "voice_%d_%s" % [variant, str(angry)]
    if _cache.has(key):
        return _cache[key]
    var rng := RandomNumberGenerator.new()
    rng.seed = 7000 + variant * 31 + (999 if angry else 0)
    var female := variant % 2 == 1
    var base := 205.0 if female else 112.0
    var shift := 1.15 if female else 1.0
    if angry:
        base *= 1.18
    var rate := 6.4 if angry else 4.6
    var n := int(2.4 * float(VR))
    var buf := PackedFloat32Array()
    buf.resize(n)
    var ph := 0.0
    var cur := -1
    var c1: Array = [0.0, 0.0, 0.0]
    var c2: Array = [0.0, 0.0, 0.0]
    var gate := 1.0
    var fric := false
    var a1 := 0.0
    var a2 := 0.0
    var b1 := 0.0
    var b2 := 0.0
    var peak := 0.0001
    for i in range(n):
        var t := float(i) / float(VR)
        var syl := int(t * rate)
        if syl != cur:
            cur = syl
            var v: Array = VOWELS[rng.randi() % VOWELS.size()]
            c1 = _res(float(v[0]) * shift, 90.0)
            c2 = _res(float(v[1]) * shift, 120.0)
            gate = 0.0 if rng.randf() < 0.1 else 1.0
            fric = rng.randf() < 0.12
        var u := t * rate - float(syl)
        var env := sin(PI * clampf(u / 0.85, 0.0, 1.0)) * gate
        var f0 := base * (1.0 + 0.10 * sin(TAU * 0.8 * t + float(variant)) + 0.06 * sin(TAU * 2.1 * t))
        ph += f0 / float(VR)
        var x := rng.randf_range(-0.01, 0.01)
        if ph >= 1.0:
            ph -= 1.0
            x += 1.0
        if fric:
            x = rng.randf_range(-1.0, 1.0) * 0.5
        var y1 := float(c1[0]) * x + float(c1[1]) * a1 + float(c1[2]) * a2
        a2 = a1
        a1 = y1
        var y2 := float(c2[0]) * x + float(c2[1]) * b1 + float(c2[2]) * b2
        b2 = b1
        b1 = y2
        var s := (y1 + 0.7 * y2) * env
        buf[i] = s
        peak = maxf(peak, absf(s))
    var data := PackedByteArray()
    data.resize(n * 2)
    for i in range(n):
        data.encode_s16(i * 2, int(clampf(buf[i] / peak * 0.8, -1.0, 1.0) * 32767.0))
    var w := _pack(data, false)
    w.mix_rate = VR
    _cache[key] = w
    return w

static func voice_3d(parent: Node, seconds: float, variant: int, angry := false, db := 5.0) -> void:
    if parent == null or not parent.is_inside_tree():
        return
    var p := AudioStreamPlayer3D.new()
    p.stream = voice_clip(variant % 8, angry)
    p.volume_db = db
    p.unit_size = 14.0
    p.max_distance = 70.0
    parent.add_child(p)
    p.play(randf() * 0.4)
    parent.get_tree().create_timer(seconds).timeout.connect(p.queue_free)
