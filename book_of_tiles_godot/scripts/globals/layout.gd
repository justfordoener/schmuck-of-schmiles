@tool
extends Node

enum CELL_TYPE {CORNER, EDGE, FACE}
# Single-biome values first (EMPTY stays 0 so existing wildcard/ordinal logic holds),
# then the ordered TWO-biome edge values. A two-biome edge is directional: the two
# halves are listed in clockwise order, so a neighbour reads the same physical edge
# reversed (GRASS_FOREST <-> FOREST_GRASS). See reverse() below and Grid.do_profiles_match.
enum PROFILE_TYPE {
	EMPTY, WATER, LAND, RIVER, PATH, CLIFF_UP, CLIFF_DOWN, 
	GRASS, FOREST, CLIFF,
	WATER_GRASS, GRASS_WATER,
	WATER_FOREST, FOREST_WATER,
	WATER_CLIFF, CLIFF_WATER,
	GRASS_FOREST, FOREST_GRASS,
	GRASS_CLIFF, CLIFF_GRASS,
	FOREST_CLIFF, CLIFF_FOREST,
}

# Mirror of each two-biome edge (swap the halves). Singles and EMPTY map to themselves,
# so reverse() is identity for the old single-biome content -> fully backward compatible.
const PROFILE_REVERSE := {
	PROFILE_TYPE.WATER_GRASS: PROFILE_TYPE.GRASS_WATER,
	PROFILE_TYPE.GRASS_WATER: PROFILE_TYPE.WATER_GRASS,
	PROFILE_TYPE.WATER_FOREST: PROFILE_TYPE.FOREST_WATER,
	PROFILE_TYPE.FOREST_WATER: PROFILE_TYPE.WATER_FOREST,
	PROFILE_TYPE.WATER_CLIFF: PROFILE_TYPE.CLIFF_WATER,
	PROFILE_TYPE.CLIFF_WATER: PROFILE_TYPE.WATER_CLIFF,
	PROFILE_TYPE.GRASS_FOREST: PROFILE_TYPE.FOREST_GRASS,
	PROFILE_TYPE.FOREST_GRASS: PROFILE_TYPE.GRASS_FOREST,
	PROFILE_TYPE.GRASS_CLIFF: PROFILE_TYPE.CLIFF_GRASS,
	PROFILE_TYPE.CLIFF_GRASS: PROFILE_TYPE.GRASS_CLIFF,
	PROFILE_TYPE.FOREST_CLIFF: PROFILE_TYPE.CLIFF_FOREST,
	PROFILE_TYPE.CLIFF_FOREST: PROFILE_TYPE.FOREST_CLIFF,
}

# Returns the mirrored profile for reading a shared edge from the opposite side.
func reverse(p : PROFILE_TYPE) -> PROFILE_TYPE:
	return PROFILE_REVERSE.get(p, p)

var CELL_SIZE   : float = 1 / sqrt(3) # length of a side of a hexagon
var CELL_STATE  : int = 1
var GRID_RADIUS : int = 5
var GRID_HEIGHT : int = 1
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
