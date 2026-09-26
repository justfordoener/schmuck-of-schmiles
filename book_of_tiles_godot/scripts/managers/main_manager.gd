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

# Pause between two initial placements, so they drop in one after another like opening moves.
const INITIAL_PLACEMENT_PAUSE : float = 0.15

@onready var ui_manager = $UIManager
@onready var placement_manager = $PlacementManager
@onready var camera_controller = $CameraController

func _ready() -> void:
	# Deferred so the scene tree has finished setting up: placed tiles are added to the
	# current scene, which isn't ready to take children while its own _ready is running.
	_play_initial_placements.call_deferred()

func _play_initial_placements() -> void:
	for i in initial_placements.size():
		var placement : Dictionary = initial_placements[i]
		if i > 0:
			await get_tree().create_timer(INITIAL_PLACEMENT_PAUSE, false).timeout
		if not placement_manager.place_tile_at(placement["tile"], Grid.axial_to_cartesian(placement["axial"])):
			push_warning("initial placement failed: ", placement["tile"].resource_path, " at ", placement["axial"])
	# Offer the first tile pack only once the last placement has landed.
	var remaining : float = placement_manager.drop_end_time - Time.get_ticks_msec() / 1000.0
	if remaining > 0.0:
		await get_tree().create_timer(remaining, false).timeout
	ui_manager.start_new_day()

func tile_selected(tile : PackedScene):
	placement_manager.place_tile(tile)

func undo():
	placement_manager.undo_last_placement()
