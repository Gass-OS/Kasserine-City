extends Node

# Stage 7A: independent ambient audio system.
# v0.3: procedural street murmur + car engine hum (no audio files).
# Everything is synthesized with AudioStreamGenerator, kept quiet, and
# guarded so a missing audio device can never crash the game.

var ambience: AudioStreamPlayer

var murmur_player: AudioStreamPlayer
var murmur_playback: AudioStreamGeneratorPlayback
var murmur_noise := 0.0
var murmur_level := 0.4
var murmur_voice_phase := 0.0
var murmur_voice_freq := 220.0
var murmur_voice_next := 0.0

var engine_player: AudioStreamPlayer
var engine_playback: AudioStreamGeneratorPlayback
var engine_phase := 0.0

var world: Node = null
var player_node: Node3D = null


func _ready() -> void:
	ambience = AudioStreamPlayer.new()
	ambience.name = "CityAmbience"
	ambience.volume_db = -10.0
	ambience.stream = load("res://assets/audio/city_ambience.wav")

	if ambience.stream == null:
		push_warning("City ambience could not be loaded")
	else:
		add_child(ambience)
		ambience.finished.connect(_restart_ambience)
		ambience.play()

	murmur_player = _make_generator_player(-26.0, "StreetMurmur")
	engine_player = _make_generator_player(-30.0, "EngineHum")
	if murmur_player != null:
		murmur_playback = murmur_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if engine_player != null:
		engine_playback = engine_player.get_stream_playback() as AudioStreamGeneratorPlayback


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
	murmur_player.volume_db = lerpf(murmur_player.volume_db, -28.0 + prox * 8.0, 0.05)
	murmur_level = clampf(murmur_level + (randf() - 0.5) * 0.002, 0.2, 0.7)
	for i in range(n):
		# Brown-ish noise through a one-pole lowpass.
		murmur_noise = murmur_noise * 0.985 + (randf() * 2.0 - 1.0) * 0.015
		var s := murmur_noise * 3.0
		# Occasional voice-like warble on top of the crowd noise.
		murmur_voice_next -= 1.0 / 22050.0
		if murmur_voice_next <= 0.0:
			murmur_voice_next = randf_range(1.5, 5.0)
			murmur_voice_freq = randf_range(170.0, 320.0)
		murmur_voice_phase += TAU * murmur_voice_freq / 22050.0
		s += sin(murmur_voice_phase) * 0.08 * (0.5 + 0.5 * sin(murmur_voice_phase * 0.13))
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
	engine_player.volume_db = lerpf(engine_player.volume_db, -34.0 + closeness * 18.0, 0.05)
	var freq := 55.0 + nearest_speed * 9.0
	for i in range(n):
		engine_phase += TAU * freq / 22050.0
		var s := 0.55 * sin(engine_phase) + 0.3 * sin(engine_phase * 2.0) + 0.15 * sin(engine_phase * 3.02)
		s *= 0.5 * maxf(closeness, 0.05)
		engine_playback.push_frame(Vector2(s, s))
