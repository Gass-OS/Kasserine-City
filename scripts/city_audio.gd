extends Node

# Stage 7A: independent ambient audio system.
# v0.3: procedural street murmur + car engine hum (no audio files).
# v0.3.1: everything was TOO QUIET for a phone speaker — the ambience wav
# itself peaked at 0.046 and played at -10 dB, murmur at -28..-20 dB,
# engine at -34..-16 dB. The user heard nothing at all. All levels were
# raised to clearly audible values (see the volume_db targets below) and
# the wav was normalized to 0.75 peak. Everything is still synthesized
# with AudioStreamGenerator, guarded so a missing audio device can never
# crash the game, and rides the master-volume bus.

var ambience: AudioStreamPlayer

var murmur_player: AudioStreamPlayer
var murmur_playback: AudioStreamGeneratorPlayback
var murmur_noise := 0.0
var murmur_level := 0.8
var murmur_voice_phase := 0.0
var murmur_voice_freq := 220.0
var murmur_voice_next := 0.0

var engine_player: AudioStreamPlayer
var engine_playback: AudioStreamGeneratorPlayback
var engine_phase := 0.0

var world: Node = null
var player_node: Node3D = null

# v0.3.1: adhan at the 5 prayer times. The user supplies his own
# adhan.mp3 — first from the phone's Download folder, then from a copy
# baked into the APK (res://assets/audio/adhan.mp3). No file exists in
# the VM, and a missing file is normal: the prayer still happens with
# the notice + gathering only, never a crash, never an error.
var adhan_player: AudioStreamPlayer
var adhan_stream: AudioStreamMP3 = null


func _ready() -> void:
	ambience = AudioStreamPlayer.new()
	ambience.name = "CityAmbience"
	# v0.3.1: 0 dB — the wav is normalized to 0.75 peak, so this is now
	# clearly audible instead of silent (-10 dB on a 0.046-peak file).
	ambience.volume_db = 0.0
	ambience.stream = load("res://assets/audio/city_ambience.wav")

	if ambience.stream == null:
		push_warning("City ambience could not be loaded")
	else:
		add_child(ambience)
		ambience.finished.connect(_restart_ambience)
		ambience.play()

	murmur_player = _make_generator_player(-16.0, "StreetMurmur")
	engine_player = _make_generator_player(-18.0, "EngineHum")
	if murmur_player != null:
		murmur_playback = murmur_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if engine_player != null:
		engine_playback = engine_player.get_stream_playback() as AudioStreamGeneratorPlayback

	# Dedicated adhan player (-6 dB, no loop, one play per prayer time).
	# The stream is loaded lazily at the first prayer — loading here
	# would try to read a file that does not exist yet in most installs.
	adhan_player = AudioStreamPlayer.new()
	adhan_player.name = "AdhanPlayer"
	adhan_player.volume_db = -6.0
	add_child(adhan_player)


func _make_generator_player(vol_db: float, node_name: String) -> AudioStreamPlayer:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.25
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.stream = gen
	p.volume_db = vol_db
	add_child(p)
	p.play()
	return p


func _restart_ambience() -> void:
	if is_instance_valid(ambience):
		ambience.play()


# v0.3.1: user-supplied MP3, dual path. External file first (the user
# drops adhan.mp3 / police.mp3 in the phone's Download folder), then
# the copy baked into the APK. Both checks are guarded with
# FileAccess.file_exists so a missing file never prints an error and
# never throws — the caller simply gets null and keeps its fallback.
func _load_user_mp3(fname: String) -> AudioStreamMP3:
	var ext_path := "/storage/emulated/0/Download/" + fname
	if FileAccess.file_exists(ext_path):
		var s := load(ext_path) as AudioStreamMP3
		if s == null:
			# ResourceLoader can refuse files outside res:// — read the
			# raw bytes as a second attempt.
			var bytes := FileAccess.get_file_as_bytes(ext_path)
			if bytes.size() > 0:
				var mp3 := AudioStreamMP3.new()
				mp3.data = bytes
				s = mp3
		if s != null:
			return s
	var bundled := "res://assets/audio/" + fname
	if FileAccess.file_exists(bundled):
		var b := load(bundled) as AudioStreamMP3
		if b != null:
			return b
	return null


# v0.3.1: called by world.gd at each prayer trigger. Plays the adhan
# once; if one is still playing from a previous prayer, it stops and
# restarts from the beginning. Missing file = silent no-op.
func play_adhan() -> void:
	if adhan_player == null:
		return
	if adhan_stream == null:
		adhan_stream = _load_user_mp3("adhan.mp3")
	if adhan_stream == null:
		return
	if adhan_player.playing:
		adhan_player.stop()
	adhan_player.stream = adhan_stream
	adhan_player.play()


func _process(_delta: float) -> void:
	if murmur_playback == null or engine_playback == null:
		return
	world = get_parent()
	if world != null:
		player_node = world.get_node_or_null("Player") as Node3D
	_push_murmur()
	_push_engine()


func _push_murmur() -> void:
	var avail := murmur_playback.get_frames_available()
	var n := mini(avail, 1024)
	if n <= 0:
		return
	# Swell near citizens: quiet far away, livelier next to a crowd.
	var prox := 0.25
	if player_node != null and world != null:
		var citizens = world.get("citizens")
		if citizens != null:
			var best := 999.0
			for c in citizens:
				var d: float = (c as Node3D).global_position.distance_to(player_node.global_position)
				if d < best:
					best = d
			prox = clampf(1.0 - best / 30.0, 0.25, 1.0)
	# v0.3.1: -20 dB far from citizens, -14 dB in a crowd (was -28..-20).
	murmur_player.volume_db = lerpf(murmur_player.volume_db, -20.0 + prox * 6.0, 0.05)
	murmur_level = clampf(murmur_level + (randf() - 0.5) * 0.002, 0.6, 1.0)
	for i in range(n):
		# Brown-ish noise through a one-pole lowpass.
		murmur_noise = murmur_noise * 0.985 + (randf() * 2.0 - 1.0) * 0.015
		var s := murmur_noise * 3.0
		# Occasional voice-like warble on top of the crowd noise.
		# v0.3.1: 0.25 amplitude (was 0.08 — barely there).
		murmur_voice_next -= 1.0 / 22050.0
		if murmur_voice_next <= 0.0:
			murmur_voice_next = randf_range(1.5, 5.0)
			murmur_voice_freq = randf_range(170.0, 320.0)
		murmur_voice_phase += TAU * murmur_voice_freq / 22050.0
		s += sin(murmur_voice_phase) * 0.25 * (0.5 + 0.5 * sin(murmur_voice_phase * 0.13))
		s *= murmur_level
		murmur_playback.push_frame(Vector2(s, s))


func _push_engine() -> void:
	var avail := engine_playback.get_frames_available()
	var n := mini(avail, 1024)
	if n <= 0:
		return
	var nearest_dist := 999.0
	var nearest_speed := 0.0
	if player_node != null and world != null:
		var cars = world.get("traffic_cars")
		var speeds = world.get("traffic_speeds")
		if cars != null and speeds != null:
			for i in range(cars.size()):
				var d: float = (cars[i] as Node3D).global_position.distance_to(player_node.global_position)
				if d < nearest_dist:
					nearest_dist = d
					nearest_speed = float(speeds[i])
	var closeness := clampf(1.0 - nearest_dist / 45.0, 0.0, 1.0)
	# v0.3.1: -22 dB with no car near, -14 dB next to one (was -34..-16).
	engine_player.volume_db = lerpf(engine_player.volume_db, -22.0 + closeness * 8.0, 0.05)
	var freq := 55.0 + nearest_speed * 9.0
	for i in range(n):
		engine_phase += TAU * freq / 22050.0
		var s := 0.55 * sin(engine_phase) + 0.3 * sin(engine_phase * 2.0) + 0.15 * sin(engine_phase * 3.02)
		# v0.3.1: 0.9 gain and a 0.15 floor (was 0.5 / 0.05) so the hum is
		# present even at a distance; peaks stay under 1.0, no clipping.
		s *= 0.9 * maxf(closeness, 0.15)
		engine_playback.push_frame(Vector2(s, s))
