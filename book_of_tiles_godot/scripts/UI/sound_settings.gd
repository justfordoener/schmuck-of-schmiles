extends Control

var master_volume: float = 1.0

func _on_master_value_changed(value: float) -> void:
	master_volume = value
	$Music.value = value
	$SFX.value = value
	set_bus_volume(1, value)
	set_bus_volume(2, value)

func _on_music_value_changed(value: float) -> void:
	set_bus_volume(1, value * master_volume)


func _on_sfx_value_changed(value: float) -> void:
	set_bus_volume(2, value * master_volume)

func set_bus_volume(bus_index: int, value: float) -> void:
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
