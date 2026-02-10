extends AudioStreamPlayer3D

@onready var tile_placement_sound : AudioStreamPlayer3D = $"."

func play_placement_sound():
	tile_placement_sound.play()

func _ready():
	Signals.on_instance_spawned.connect(play_placement_sound)
