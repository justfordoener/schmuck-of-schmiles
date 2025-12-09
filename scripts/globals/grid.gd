@tool
extends Node
# - even-q layout
# - cube coordinates for grid calculations
# for reference use: https://www.redblobgames.com/grids/cube_coords/#basics

class play_cell extends Cell:
	pass
class dual_cell extends Cell:
	pass
class face_cell extends Cell:
	pass
class edge_cell extends Cell:
	pass
class corn_cell extends Cell:
	pass

var dual_layer_snap_points = {} 
var face_layer_snap_points = {} 
var play_layer_snap_points = {}
var corn_layer_snap_points = {}

func _ready() -> void:
	initialize_grid_layers()

func initialize_grid_layers() -> void:
	# dual layer
	dual_layer_snap_points[Layout.CENTER_TILE_CUBIC] = dual_cell.new()
	for ring in cubic_spiral(Layout.CENTER_TILE_CUBIC, Layout.GRID_RADIUS):
		for pos in ring:
			var new_cell = dual_cell.new()
			new_cell.state = 0
			dual_layer_snap_points[pos] = new_cell
	
	# face layer
	for point in dual_layer_snap_points:
		for direction in range(6):
			var corner = get_euclicdic_dual_corner(cubic_to_euclidic(point), direction)
			if !face_layer_snap_points.has(corner):
				var new_cell = face_cell.new()
				new_cell.state = 0
				face_layer_snap_points[corner] = new_cell
				
	# edge layer #TODO
	
	# corn layer
	for point in dual_layer_snap_points:
		var new_cell = corn_cell.new()
		new_cell.state = 0
		corn_layer_snap_points[point] = new_cell
	
	# play layer
	
	# full layer
	
# ------------------- grid mesh functions --------------------
# ref: https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/arraymesh.html#doc-arraymesh

func get_full_layer_array_mesh() -> ArrayMesh:
	var full_layer_array_mesh: ArrayMesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	var verts = PackedVector3Array()
	var indices = PackedInt32Array()
	var base_index = 0
	for point in dual_layer_snap_points:
		var corner
		for index in range(6):
			corner = get_euclicdic_corn_corner(cubic_to_euclidic(point), index)
			verts.append(corner)
			indices.append(base_index + index)
			indices.append(base_index + ((index + 1) % 6))
		base_index += 6
	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_INDEX] = indices
	full_layer_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, surface_array)
	return full_layer_array_mesh	
	
func get_dual_layer_array_mesh() -> ArrayMesh:
	var dualgrid_array_mesh : ArrayMesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	var verts = PackedVector3Array()
	var indices = PackedInt32Array()
	for point in dual_layer_snap_points:
		var corners = []
		for direction in range(6):
			corners.append(get_euclicdic_dual_corner(cubic_to_euclidic(point), direction))
		verts.append_array(corners)
		var base_index = verts.size() - 6
		for direction in range(6):
			indices.append(base_index + direction)
			indices.append(base_index + ((direction + 1) % 6))
	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_INDEX] = indices
	dualgrid_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, surface_array)
	return dualgrid_array_mesh

func get_face_layer_array_mesh() -> ArrayMesh:
	var trigrid_array_mesh : ArrayMesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	var verts = PackedVector3Array()
	var indices = PackedInt32Array()
	var base_index = 0
	var cube_directions = Layout.CUBIC_DIRECTION
	for point in dual_layer_snap_points:
		var corners = []
		for index in range(cube_directions.size()):
			var orth_normal = (cube_directions[(index + 1) % cube_directions.size()]
							 + cube_directions[(index + 2) % cube_directions.size()]) * 0.0825
			corners.append(cubic_to_euclidic(point + orth_normal + 0.75 * cube_directions[index]))
			corners.append(cubic_to_euclidic(point + orth_normal + 0.25 * cube_directions[index]))
			corners.append(cubic_to_euclidic(point - orth_normal + 0.75 * cube_directions[index]))
			corners.append(cubic_to_euclidic(point - orth_normal + 0.25 * cube_directions[index]))
			verts.append_array(corners)
			indices.append(base_index + 4 * index)
			indices.append(base_index + 4 * index + 1)
			indices.append(base_index + 4 * index + 2)
			indices.append(base_index + 4 * index + 3)
		base_index += cube_directions.size() * 4
	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_INDEX] = indices
	trigrid_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, surface_array)
	return trigrid_array_mesh

func get_play_layer_array_mesh() -> ArrayMesh:
	var playgrid_array_mesh : ArrayMesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	var verts = PackedVector3Array()
	var indices = PackedInt32Array()
	#TODO
	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_INDEX] = indices
	playgrid_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, surface_array)
	return playgrid_array_mesh

# ------------------- snap to grid layer -----------------

func snap_to_full_layer(point: Vector3) -> Vector3:
	return snap_to_dual_layer(point)
	
func snap_to_dual_layer(point : Vector3) -> Vector3:
	var cube_coordinate_rounded : Vector3 = Grid.cubic_round(Grid.euclidic_to_cubic(point))
	var point_new : Vector3 = Grid.cubic_to_euclidic(cube_coordinate_rounded)
	return Vector3(point_new.x, point.y, point_new.z)

func snap_to_face_layer(point : Vector3) -> Vector3:
	var dual_cell_center = snap_to_dual_layer(point)
	var min_dist = INF
	var closest_corner : Vector3 = Vector3.ZERO
	for direction in range(6):
		var corner = get_euclicdic_dual_corner(dual_cell_center, direction)
		var dist = point.distance_to(corner)
		if dist < min_dist:
			closest_corner = corner
			min_dist = dist
	return closest_corner
	
func snap_to_edge_layer(point : Vector3) -> Vector3:
	# get 2 closest dual points
	var closest_dual : Vector3 = snap_to_dual_layer(point)
	var second_dual : Vector3 = Vector3.ZERO
	var min_dist = INF
	# get second dual by adding vectors of two closest corners
	var closest_corner : Vector3 = Vector3.ZERO
	var second_corner : Vector3 = Vector3.ZERO
	for direction in range(6):
		var corner = get_euclicdic_dual_corner(closest_dual, direction)
		var dist = point.distance_to(corner)
		if dist < min_dist:
			closest_corner = corner
			min_dist = dist
	var max_dist = INF
	for direction in range(6):
		var corner = get_euclicdic_dual_corner(closest_dual, direction)
		var dist = point.distance_to(corner)
		if dist > min_dist and dist < max_dist:
			second_corner = corner
			max_dist = dist
	var closest_dual_euc = cubic_to_euclidic(closest_dual)
	second_dual = closest_dual_euc + (closest_corner - closest_dual_euc) + (second_corner - closest_dual_euc)
	# return point between those duals
	return closest_dual_euc + 0.5 * (second_dual - closest_dual_euc)	
	
func snap_to_corn_layer(point : Vector3) -> Vector3:
	return snap_to_dual_layer(point)

# ------------------- helper functions -------------------

func configure_grid_mesh(mesh : MeshInstance3D, color : Color) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ORMMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material_override = material

func get_euclicdic_dual_corner(euclidic_center : Vector3, direction : int) -> Vector3:
	var angle_degree = 60 * direction + 30
	var angle_radian = deg_to_rad(angle_degree)
	return euclidic_center + Vector3(
		Layout.CELL_SIZE * cos(angle_radian),
		0,
		Layout.CELL_SIZE * sin(angle_radian)
	)
	
func get_euclicdic_corn_corner(euclidic_center : Vector3, direction : int) -> Vector3:
	var angle_degree = 60 * direction + 30
	var angle_radian = deg_to_rad(angle_degree)
	return euclidic_center + Vector3(
		0.5 * 	Layout.CELL_SIZE * cos(angle_radian),
		0,
		0.5 * 	Layout.CELL_SIZE * sin(angle_radian)
	)
	
func cubic_distance_from_to(from: Vector3, to: Vector3) -> Vector3:
	var distance : Vector3 = Vector3.ZERO
	distance.x = to.x - from.x
	distance.y = to.y - from.y
	distance.z = to.z - from.z
	return distance

func euclidic_to_cubic(point: Vector3) -> Vector3:
	var cube_coord : Vector3 = Vector3.ZERO
	cube_coord.x = ( 2./3 * point.z) / 	Layout.CELL_SIZE
	cube_coord.y = (-1./3 * point.z + sqrt(3)/3 * point.x) / 	Layout.CELL_SIZE
	cube_coord.z = -cube_coord.x-cube_coord.y
	return cubic_round(cube_coord)
	
func cubic_to_euclidic(cube_coord: Vector3) -> Vector3:
	var point : Vector3 = Vector3.ZERO
	point.x = 	Layout.CELL_SIZE * (sqrt(3)/2 * cube_coord.x + sqrt(3) * cube_coord.y)
	point.y = 0
	point.z = 	Layout.CELL_SIZE * 	    (3./2 * cube_coord.x)
	return point

func cubic_round(frac_cube_coord: Vector3) -> Vector3:
	var round_x = int(round(frac_cube_coord.x))
	var round_y = int(round(frac_cube_coord.y))
	var round_z = int(round(frac_cube_coord.z))
	var diff_x = abs(round_x - frac_cube_coord.x)
	var diff_y = abs(round_y - frac_cube_coord.y)
	var diff_z = abs(round_z - frac_cube_coord.z)
	if diff_x > diff_y and diff_x > diff_z:
		round_x = -round_y-round_z
	else: if diff_y > diff_z:
		round_y = -round_x-round_z
	else:
		round_z = -round_x-round_y
	return Vector3(round_x, round_y, round_z)

func cubic_ring(center : Vector3, radius : int) -> Array:
	var results = []
	var point = center + Layout.CUBIC_DIRECTION[4] * radius * Layout.CELL_SIZE
	for i in range(6):
		for j in range(radius):
			results.append(point)
			point = point + Layout.CUBIC_DIRECTION[i]
	return results

func cubic_spiral(center : Vector3, radius : int) -> Array:
	var results = [center]
	for i in range(radius):
		results.append(cubic_ring(center, i))
	return results

func convert_to_int(bits : String) -> int:
	var result = 0
	for bit_index in range(bits.length()):
		if (int(bits[bit_index]) == 1):
			result += 2 ** bit_index
	return result
