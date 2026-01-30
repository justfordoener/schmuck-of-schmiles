class_name TileCard extends Control

@export var tile : PackedScene
var hand_index : int
signal button_pressed(tile_card : Control)

func on_button_pressed():
	emit_signal("button_pressed", self)
