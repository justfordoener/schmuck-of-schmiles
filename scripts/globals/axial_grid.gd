@tool
extends Node
# for reference use: https://www.redblobgames.com/grids/cube_coords/#basics

var grid : Dictionary[Vector3i, Cell] = {}
var dual_layer_snap_points

func _ready() -> void:
	_init_grid()
	
func _init_grid() -> void:
	grid = axial_spiral(Layout.AXIAL_CENTER, Layout.GRID_RADIUS)
	
# ------------------- grid mesh functions --------------------

#func create_face_mesh() -> ArrayMesh:
	
# ------------------- snap to grid layer -----------------

func snap_to_face_layer(cartesian_coord: Vector3, _rotation : int) -> Vector3:
	return axial_to_cartesian(cartesian_to_axial(cartesian_coord))

# ------------------- helper functions -------------------

func cartesian_to_axial(cartesian_coord: Vector3) -> Vector3i:
	var axial_fract : Vector3
	axial_fract.x = ( 2./3 * cartesian_coord.z) / Layout.CELL_SIZE
	axial_fract.y = cartesian_coord.y
	axial_fract.z = (-1./3 * cartesian_coord.z + sqrt(3)/3 * cartesian_coord.x) / Layout.CELL_SIZE
	#print("cartesian: " + str(cartesian_coord) + " - axial: " + str(Vector3(axial_fract.x, axial_fract.y, axial_fract.z)))
	return Vector3i(round(axial_fract.x), round(axial_fract.y), round(axial_fract.z))
	
func axial_to_cartesian(axial_coord: Vector3i) -> Vector3:
	var cartesian_coord : Vector3 = Vector3.ZERO
	cartesian_coord.y = axial_coord.y
	cartesian_coord.x = Layout.CELL_SIZE * (sqrt(3)/2 * axial_coord.x + sqrt(3) * axial_coord.z)
	cartesian_coord.z = Layout.CELL_SIZE * 	    (3./2 * axial_coord.x)
	return cartesian_coord

func axial_spiral(center_corner : Vector3i, radius : int) -> Dictionary[Vector3i, Cell]:
	var result : Dictionary[Vector3i, Cell] = {}
	for i in range(radius):
		result.merge(axial_ring(center_corner, i))
	return	result

func axial_ring(center_corn : Vector3i, radius) -> Dictionary[Vector3i, Cell]:
	var result : Dictionary[Vector3i, Cell] = {}
	var center : CornCell = CornCell.new()
	result[center_corn] = center.create()
	for dir_index : int in range(6):
		var dir = Layout.AXIAL_DIRECTION[dir_index]
		var dir_inwards = Layout.AXIAL_DIRECTION[(dir_index + 2) % 6]
		var dir_outwards = Layout.AXIAL_DIRECTION[(dir_index + 1) % 6]
		for i : int in range(radius):
			var corn : CornCell = CornCell.new()
			var edge_inwards : EdgeCell = EdgeCell.new()
			var edge_outwards : EdgeCell = EdgeCell.new()
			var edge_sidewards : EdgeCell = EdgeCell.new()
			var face_inwards : FaceCell = FaceCell.new()
			var face_outwards : FaceCell = FaceCell.new()
			result[dir * radius + dir_inwards * i] = corn.create()
			result[dir * radius + dir_inwards * i - dir / 2] = edge_inwards.create()
			result[dir * radius + dir_inwards * i + dir / 2] = edge_outwards.create()
			result[dir * radius + dir_inwards * i + dir_inwards / 2] = edge_sidewards.create()
			result[dir * radius + dir_inwards * i + (dir_inwards + dir_outwards) / 2] = face_inwards.create()
			result[dir * radius + dir_inwards * i + (dir_inwards - dir) / 2] = face_outwards.create()
	return result
