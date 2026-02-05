extends AudioStreamPlayer3D

@onready var tile_placement_sound : AudioStreamPlayer3D = $"."

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("mouse_left"):
		tile_placement_sound.play()
	pass
