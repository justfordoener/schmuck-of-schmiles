@tool
extends Node

var CELL_SIZE := 1 # length of a triangle cell edge on the trigrid 
var CELL_STATE := 1
var GRID_RADIUS := 10
var GRID_HEIGHT := 0.5
var CENTER_TILE_EUCLIDIC := Vector3(0,0,0)
var CENTER_TILE_CUBIC := Vector3(0,0,0)
var CUBIC_DIRECTION := {	
	0: Vector3(0, -1,  1),	# top
	1: Vector3(1, -1,  0),	# top right
	2: Vector3(1,  0, -1),	# bottom right
	3: Vector3(0,  1,  -1),	# bottom
	4: Vector3(-1, 1,  0),	# bottom left
	5: Vector3(-1,  0,  1)	# top left
}
var AXIAL_DIRECTION := {
	0: Vector3i(0 ,6 ,0 ), 	#top right
	1: Vector3i(-6,6 ,0 ), 	#right
	2: Vector3i(-6,0 ,0 ), 	#bottom right
	3: Vector3i(0 ,6 ,0 ), 	#bottom left
	4: Vector3i(6 ,-6,0 ),	#left
	5: Vector3i(6 ,0 ,0 ),	#top left
	6: Vector3i(0 ,0 ,3 ),	#up
	7: Vector3i(0 ,0 ,-3)
}
var AXIAL_CENTER := Vector3i(0,0,0)

var TILE_ROTATION_VALUE := {
	0:    CUBIC_DIRECTION[0],	# facing top
	300:  CUBIC_DIRECTION[1],	# facing top right
	240:  CUBIC_DIRECTION[2],	# facing bottom right
	180:  CUBIC_DIRECTION[3],	# facing bottom
	120:  CUBIC_DIRECTION[4],	# facing bottom left
	60:   CUBIC_DIRECTION[5]	# facing top left
}
