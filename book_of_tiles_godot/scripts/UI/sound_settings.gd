extends Control

@export var slider_master := HSlider
@export var slider_music := HSlider
@export var slider_sfx := HSlider

@export var value_master := RichTextLabel
@export var value_music := RichTextLabel
@export var value_sfx := RichTextLabel

var master_volume: float = 1.0
var previous_master: float = 1.0
var max_volume # max possible volume in db

func _ready() -> void:
	max_volume = FileManager.balancing_data["max_volume"] 
	
	# Get current volumes from AudioServer in dB
	var master_db = AudioServer.get_bus_volume_db(0)
	var music_db = AudioServer.get_bus_volume_db(1)
	var sfx_db = AudioServer.get_bus_volume_db(2)

	var master_linear = db_to_linear(master_db)
	var music_linear = db_to_linear(music_db)
	var sfx_linear = db_to_linear(sfx_db)

	slider_master.value = master_linear
	slider_music.value = music_linear
	slider_sfx.value = sfx_linear

	# Initialize master tracking variable
	master_volume = master_linear
	previous_master = master_linear

	update_labels()

func _input(event):
	if event.is_action_pressed("reload_files"):
		slider_master.value = 1.0
		slider_music.value = 1.0
		slider_sfx.value = 1.0
		max_volume = FileManager.balancing_data["max_volume"]
		slider_master.max_value = max_volume
		slider_music.max_value = max_volume
		slider_sfx.max_value = max_volume
		update_labels()


func _on_master_value_changed(value: float) -> void:
	var delta = value - previous_master
	previous_master = value
	master_volume = value

	# Move other sliders by same amount
	slider_music.value = clamp(slider_music.value + delta, 0.0, max_volume)
	slider_sfx.value = clamp(slider_sfx.value + delta, 0.0, max_volume)
	if master_volume == 0:
		slider_music.value = 0.0
		slider_sfx.value = 0.0
	elif master_volume == max_volume:
		slider_music.value = max_volume
		slider_sfx.value = max_volume

	apply_volumes()
	update_labels()
	print(slider_master.value)

func _on_music_value_changed(_value: float) -> void:
	apply_volumes()
	update_labels()

func _on_sfx_value_changed(_value: float) -> void:
	apply_volumes()
	update_labels()

func apply_volumes():
	set_bus_volume(1, slider_music.value)
	set_bus_volume(2, slider_sfx.value)

func set_bus_volume(bus_index: int, value: float) -> void:
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

func update_labels() -> void:
	value_master.text = str(to_percent(slider_master.value)) + "%"
	value_music.text = str(to_percent(slider_music.value)) + "%"
	value_sfx.text = str(to_percent(slider_sfx.value)) + "%"

func to_percent(value: float) -> int:
	return int((value / max_volume) * 100)
