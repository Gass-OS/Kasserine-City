extends Node3D

const AMBIENCE = preload("res://assets/audio/city_ambience.wav")
const BIRDS = preload("res://assets/audio/birds.wav")
const DOG = preload("res://assets/audio/dog_bark.wav")
const HORN = preload("res://assets/audio/traffic_horn.wav")

var rng := RandomNumberGenerator.new()
var player: Node3D
var bird_timer := 5.0
var dog_timer := 28.0
var horn_timer := 42.0

var ambience_player: AudioStreamPlayer3D
var bird_player: AudioStreamPlayer3D
var dog_player: AudioStreamPlayer3D
var horn_player: AudioStreamPlayer3D

func _ready():
    rng.randomize()
    player = get_parent().get_node_or_null("Player")

    ambience_player = _make_player("OutdoorAmbience", AMBIENCE, -25.0, 260.0, 85.0)
    var ambience_stream = ambience_player.stream as AudioStreamWAV
    if ambience_stream:
        ambience_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    ambience_player.play()

    bird_player = _make_player("BirdChirps", BIRDS, -13.0, 72.0, 17.0)
    dog_player = _make_player("DistantDogs", DOG, -16.0, 82.0, 20.0)
    horn_player = _make_player("TrafficHorn", HORN, -18.0, 95.0, 24.0)

func _make_player(player_name: String, stream: AudioStream, volume: float, distance: float, unit: float) -> AudioStreamPlayer3D:
    var p = AudioStreamPlayer3D.new()
    p.name = player_name
    p.stream = stream
    p.volume_db = volume
    p.max_distance = distance
    p.unit_size = unit
    p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
    add_child(p)
    return p

func _process(delta: float):
    if player == null or not is_instance_valid(player):
        player = get_parent().get_node_or_null("Player")
        return

    bird_timer -= delta
    dog_timer -= delta
    horn_timer -= delta

    if bird_timer <= 0.0:
        bird_player.global_position = player.global_position + Vector3(
            rng.randf_range(-22.0, 22.0), rng.randf_range(4.0, 9.0),
            rng.randf_range(-22.0, 22.0))
        bird_player.play()
        bird_timer = rng.randf_range(13.0, 24.0)

    if dog_timer <= 0.0:
        dog_player.global_position = player.global_position + Vector3(
            rng.randf_range(-34.0, 34.0), 0.5,
            rng.randf_range(-34.0, 34.0))
        dog_player.play()
        dog_timer = rng.randf_range(42.0, 68.0)

    if horn_timer <= 0.0:
        var road_x = round(player.global_position.x / 24.0) * 24.0
        var road_z = round(player.global_position.z / 24.0) * 24.0
        if rng.randf() < 0.5:
            horn_player.global_position = Vector3(road_x, 1.0,
                player.global_position.z + rng.randf_range(-28.0, 28.0))
        else:
            horn_player.global_position = Vector3(
                player.global_position.x + rng.randf_range(-28.0, 28.0),
                1.0, road_z)
        horn_player.play()
        horn_timer = rng.randf_range(48.0, 82.0)
