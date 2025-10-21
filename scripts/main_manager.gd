extends Node

@onready var grid_manager = $grid_manager

func on_ui_grid_layer_button_pressed(layer_key : String):
	grid_manager.set_active_layer(layer_key)
