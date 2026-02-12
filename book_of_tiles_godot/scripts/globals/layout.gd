@tool
extends Node

enum CELL_TYPE {CORNER, EDGE, FACE}
enum PROFILE_TYPE {EMPTY, WATER, LAND, RIVER, PATH, CLIFF_UP, CLIFF_DOWN}

var CELL_SIZE   : float = 1 / sqrt(3) # length of a side of a hexagon
var CELL_STATE  : int = 1
var GRID_RADIUS : int = 3
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
