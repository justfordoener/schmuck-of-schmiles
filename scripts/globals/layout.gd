extends Node

enum CELL_TYPE {CORNER, EDGE, FACE}

var CELL_SIZE   : float = 1 / sqrt(3) # length of a triangle cell edge on the trigrid 
var CELL_STATE  : int = 1
var GRID_RADIUS : int = 2
var GRID_HEIGHT : int = 1
var CENTER_TILE_EUCLIDIC : Vector3 = Vector3(0,0,0)
var CENTER_TILE_AXIAL : Vector3 = Vector3(0,0,0)
var AXIAL_DIRECTION : Dictionary[int, Vector3]= {
	0: Vector3(1 , 0, 0),	# top top right
	1: Vector3(0,  0, 1),	# right
	2: Vector3(-1, 0, 1),	# bot bot right
	3: Vector3(-1, 0, 0),	# bot bot left
	4: Vector3(0 , 0,-1),	# left
	5: Vector3(1 , 0,-1),	# top top left
	6: Vector3(0 , 1, 0),	# up
	7: Vector3(0 ,-1, 0) 	# down
}
var AXIAL_CENTER := Vector3(0,0,0)

var TILE_ROTATION_VALUE := {
	0:   (AXIAL_DIRECTION[5] + AXIAL_DIRECTION[0]).normalized(),	# facing top
	30:   AXIAL_DIRECTION[0].normalized(),							# facing top top right
	60:  (AXIAL_DIRECTION[0] + AXIAL_DIRECTION[1]).normalized(),	# facing top right right
	90:   AXIAL_DIRECTION[1].normalized(),							# facing right
	120:  (AXIAL_DIRECTION[1] + AXIAL_DIRECTION[2]).normalized(),	# facing bot right right
	150:   AXIAL_DIRECTION[2].normalized(),							# facing bot bot right
	180:  (AXIAL_DIRECTION[2] + AXIAL_DIRECTION[3]).normalized(),	# facing bot
	210:   AXIAL_DIRECTION[3].normalized(),							# facing bot bot left
	240:  (AXIAL_DIRECTION[3] + AXIAL_DIRECTION[4]).normalized(),	# facing bot left left
	270:   AXIAL_DIRECTION[4].normalized(),							# facing left
	300:  (AXIAL_DIRECTION[4] + AXIAL_DIRECTION[5]).normalized(),	# facing top left left
	330:   AXIAL_DIRECTION[5].normalized(),							# facing top top left
}
