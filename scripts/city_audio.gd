extends Node

# Stage 7A: independent ambient audio system.
# Does not modify player, traffic, dialogue or world geometry.

var ambience: AudioStreamPlayer


func _ready() -> void:
    ambience = AudioStreamPlayer.new()
    ambience.name = "CityAmbience"
    ambience.volume_db = -10.0
    ambience.stream = load("res://assets/audio/city_ambience.wav")

    if ambience.stream == null:
        push_warning("City ambience could not be loaded")
        return

    add_child(ambience)
    ambience.finished.connect(_restart_ambience)
    ambience.play()


func _restart_ambience() -> void:
    if is_instance_valid(ambience):
        ambience.play()
