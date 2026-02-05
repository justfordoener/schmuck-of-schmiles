class_name MainManager extends Node

@onready var ui_manager = $UIManager
@onready var placement_manager = $PlacementManager
@onready var camera_controller = $CameraController

func tile_selected(tile : PackedScene):
	placement_manager.place_tile(tile)

func undo():
	placement_manager.undo_last_placement()
