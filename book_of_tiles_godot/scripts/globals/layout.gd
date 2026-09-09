@tool
extends Node

enum CELL_TYPE {CORNER, EDGE, FACE}

# What kind of tile occupies a CORNER cell - the vocabulary recipes are written in
# (see Recipes.find_match). Every corner always carries one: cells seeded by
# Grid.initialize_grass_layer() read GRASS, the empty layers above read NONE, and a
# placement copies the value off the tile scene (see tile.gd).
#
# Needed because module_id can't tell these apart: hex_water and hex_beaver both instance
# corner_water_..._water (id 21), and only the beaver-house child node distinguishes them.
#
# APPEND-ONLY, same as PROFILE_TYPE below: tile .tscn files store these as raw ints.
enum TILE_KIND {
	NONE,
	GRASS, FOREST, WATER, BEAVER,
}
# This enum is APPEND-ONLY: module .tscn
# files store these as raw ints, so inserting a value renumbers every module.
# SURFACE (14) is not a biome - it's a wildcard, see WILDCARD_MEMBERS below.
#
# A two-biome edge is directional: the two halves are listed in clockwise
# order, read from *outside* the module looking at that edge, so a neighbour
# reads the same physical edge reversed (FOREST_AIR <-> AIR_FOREST). See reverse() below and Grid.do_profiles_match.
enum PROFILE_TYPE {
	EMPTY,
	AIR, WATER, GRASS, CLIFF, FOREST,
	FOREST_AIR, AIR_FOREST,
	FOREST_CLIFF, CLIFF_FOREST,
	CLIFF_AIR, AIR_CLIFF,
	WATER_GRASS, GRASS_WATER,
	SURFACE,
}

# Mirror of each two-biome edge (swap the halves). EMPTY and the single-biome
# values map to themselves, so reverse() is identity for them.
const PROFILE_REVERSE := {
	PROFILE_TYPE.FOREST_AIR: PROFILE_TYPE.AIR_FOREST,
	PROFILE_TYPE.AIR_FOREST: PROFILE_TYPE.FOREST_AIR,
	PROFILE_TYPE.FOREST_CLIFF: PROFILE_TYPE.CLIFF_FOREST,
	PROFILE_TYPE.CLIFF_FOREST: PROFILE_TYPE.FOREST_CLIFF,
	PROFILE_TYPE.CLIFF_AIR: PROFILE_TYPE.AIR_CLIFF,
	PROFILE_TYPE.AIR_CLIFF: PROFILE_TYPE.CLIFF_AIR,
	PROFILE_TYPE.WATER_GRASS: PROFILE_TYPE.GRASS_WATER,
	PROFILE_TYPE.GRASS_WATER: PROFILE_TYPE.WATER_GRASS,
}

# Returns the mirrored profile for reading a shared edge from the opposite side.
func reverse(p : PROFILE_TYPE) -> PROFILE_TYPE:
	return PROFILE_REVERSE.get(p, p)

# Profiles that stand for a set of values instead of one biome.
const WILDCARD_MEMBERS := {
	PROFILE_TYPE.SURFACE: [PROFILE_TYPE.GRASS, PROFILE_TYPE.WATER, PROFILE_TYPE.GRASS_WATER, PROFILE_TYPE.WATER_GRASS],
}

# True if either side is a wildcard whose member set contains the other side.
# Symmetric: the caller has already mirrored one side via reverse().
func matches_wildcard(a : PROFILE_TYPE, b : PROFILE_TYPE) -> bool:
	if WILDCARD_MEMBERS.has(a) and WILDCARD_MEMBERS[a].has(b):
		return true
	return WILDCARD_MEMBERS.has(b) and WILDCARD_MEMBERS[b].has(a)

var CELL_SIZE   : float = 1 / sqrt(3) # length of a side of a hexagon
var CELL_HEIGHT : float = 0.5 # vertical spacing between stacked layers
var CELL_STATE  : int = 1
var GRID_RADIUS : int = 5
var GRID_HEIGHT : int = 3
var CENTER_TILE_EUCLIDIC : Vector3 = Vector3(0,0,0)
var CENTER_TILE_AXIAL : Vector3 = Vector3(0,0,0)
var AXIAL_DIRECTION := {
	0: Vector3(1 , 0, 0), 	#right
	1: Vector3(0 , 0, 1), 	#bot right
	2: Vector3(-1, 0, 1), 	#bot left
	3: Vector3(-1, 0, 0), 	#left
	4: Vector3(0 , 0,-1),	#top left
	5: Vector3(1 , 0,-1),	#top right
	6: Vector3(0 , 1, 0),	#up
	7: Vector3(0 ,-1, 0)	#down
}
var AXIAL_CENTER := Vector3(0,0,0)

var TILE_ROTATION_VALUE := {
	0:  	AXIAL_DIRECTION[0],										# facing right
	30:  	(AXIAL_DIRECTION[0] + AXIAL_DIRECTION[1]) * CELL_SIZE,	# facing bottom right right
	60:  	AXIAL_DIRECTION[1],										# facing bottom bottom right
	90:  	(AXIAL_DIRECTION[1] + AXIAL_DIRECTION[2]) * CELL_SIZE,	# facing bottom
	120:  	AXIAL_DIRECTION[2],										# facing bottom bottom left
	150:  	(AXIAL_DIRECTION[2] + AXIAL_DIRECTION[3]) * CELL_SIZE,	# facing bottom left left
	180:	AXIAL_DIRECTION[3],										# facing left
	210:   	(AXIAL_DIRECTION[3] + AXIAL_DIRECTION[4]) * CELL_SIZE,	# facing top left left
	240:   	AXIAL_DIRECTION[4],										# facing top top left
	270:    (AXIAL_DIRECTION[4] + AXIAL_DIRECTION[5]) * CELL_SIZE,	# facing top
	300:  	AXIAL_DIRECTION[5],										# facing top top right
	330:  	(AXIAL_DIRECTION[5] + AXIAL_DIRECTION[0]) * CELL_SIZE	# facing top right right
}
