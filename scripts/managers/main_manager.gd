extends Node

@onready var grid_manager = $GridManager
@onready var ui_manager = $UIManager
@onready var placement_manager = $PlacementManager

func on_ui_grid_layer_button_pressed(layer_key : String):
	grid_manager.set_active_layer(layer_key)

func tile_selected(tile : PackedScene):
	placement_manager.place_tile(tile)

func undo():
	placement_manager.undo_last_placement()
