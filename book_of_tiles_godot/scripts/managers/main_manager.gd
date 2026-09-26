class_name MainManager extends Node

const GRASS_TILE : PackedScene = preload("res://scenes/tiles/hex_grass.tscn")
const FOREST_TILE : PackedScene = preload("res://scenes/tiles/hex_forest.tscn")
const WATER_TILE : PackedScene = preload("res://scenes/tiles/hex_water.tscn")
const BEAVER_TILE : PackedScene = preload("res://scenes/tiles/hex_beaver.tscn")

# Tiles pre-played on top of the seeded grass when the level starts, in order, as axial corner
# positions
# THIS SHOULD BE EXTERNALIZED WHEN MORE LEVELS ARE ADDED 
var initial_placements : Array[Dictionary] = [
	# forests around a grass tile
	{"tile": FOREST_TILE, "axial": Vector3(-4, 0, -4)},
	{"tile": FOREST_TILE, "axial": Vector3(-6, 0, -2)},
	{"tile": FOREST_TILE, "axial": Vector3(-2, 0, -4)},
	{"tile": FOREST_TILE, "axial": Vector3(-2, 0, -2)},
	{"tile": GRASS_TILE, "axial": Vector3(-4, 0, -2)},
	# raised grass
	{"tile": GRASS_TILE, "axial": Vector3(-10, 0, 8)},
	{"tile": GRASS_TILE, "axial": Vector3(-8, 0, 8)},
	{"tile": GRASS_TILE, "axial": Vector3(-10, 0, 10)},
	# forest pair
	{"tile": FOREST_TILE, "axial": Vector3(0, 0, 8)},
	{"tile": FOREST_TILE, "axial": Vector3(-2, 0, 10)},
	# water
	{"tile": WATER_TILE, "axial": Vector3(6, 0, -10)},
	{"tile": WATER_TILE, "axial": Vector3(6, 0, -8)},
	{"tile": WATER_TILE, "axial": Vector3(10, 0, -8)},
	{"tile": WATER_TILE, "axial": Vector3(0, 0, 2)},
	{"tile": WATER_TILE, "axial": Vector3(2, 0, 2)},
	# beaver house
	{"tile": BEAVER_TILE, "axial": Vector3(10, 0, -2)},
]

@onready var ui_manager = $UIManager
@onready var placement_manager = $PlacementManager
@onready var camera_controller = $CameraController

func _ready() -> void:
	# Deferred so the scene tree has finished setting up: placed tiles are added to the
	# current scene, which isn't ready to take children while its own _ready is running.
	_play_initial_placements.call_deferred()

func _play_initial_placements() -> void:
	for placement in initial_placements:
		if not placement_manager.place_tile_at(placement["tile"], Grid.axial_to_cartesian(placement["axial"])):
			push_warning("initial placement failed: ", placement["tile"].resource_path, " at ", placement["axial"])

func tile_selected(tile : PackedScene):
	placement_manager.place_tile(tile)

func undo():
	placement_manager.undo_last_placement()
