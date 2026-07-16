@tool
extends Node

enum CELL_TYPE {CORNER, EDGE, FACE}
# EMPTY stays 0: it's the "no profile assigned yet" sentinel used directly by
# border.gd and grid.gd matching logic (distinct from AIR, which is a real
# WFC value meaning "open to air"). The remaining 13 values are the current
# blockout v005 profile vocabulary. A two-biome edge is directional: the two
# halves are listed in clockwise order, read from *outside* the module looking
# at that edge, so a neighbour reads the same physical edge reversed
# (FOREST_AIR <-> AIR_FOREST). See reverse() below and Grid.do_profiles_match.
enum PROFILE_TYPE {
	EMPTY,
	AIR, WATER, GRASS, CLIFF, FOREST,
	FOREST_AIR, AIR_FOREST,
	FOREST_CLIFF, CLIFF_FOREST,
	CLIFF_AIR, AIR_CLIFF,
	WATER_GRASS, GRASS_WATER,
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
