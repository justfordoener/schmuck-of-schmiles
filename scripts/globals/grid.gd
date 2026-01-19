extends Node
# - even-q layout
# - cube coordinates for grid calculations
# for reference use: https://www.redblobgames.com/grids/cube_coords/#basics

var grid : Dictionary[Vector3, Cell]

var corn_mesh : ArrayMesh
var face_mesh : ArrayMesh
var edge_mesh : ArrayMesh

func _ready() -> void:
	grid = {}
	_initialize_grid_layers()
	_initialize_layer_mesh(corn_mesh, "CornCell", Color.YELLOW)
	_initialize_layer_mesh(face_mesh, "FaceCell", Color.SKY_BLUE)
	_initialize_layer_mesh(edge_mesh, "EdgeCell", Color.LIME_GREEN)
	
func _initialize_layer_mesh(mesh : ArrayMesh, class_name_string : String, color : Color) -> void:
	var mesh_array = []
	mesh_array.resize(Mesh.ARRAY_MAX)
	var mesh_verts = PackedVector3Array()
	var mesh_indices = PackedInt32Array()
	var vert_counter = 0
	print("grid: ", grid.keys())
	for pos : Vector3 in grid.keys():
		if grid[pos].type == class_name_string:
			var position_axial : Vector3 = grid[pos].axial_position
			var position_cartesian = axial_to_cartesian(position_axial)
			mesh_verts.append(position_cartesian)
			mesh_indices.append(vert_counter)
			print(vert_counter, " - cell type: ", grid[pos].type, " added axial_position ", position_axial, " on cartesian_position ", position_cartesian)
			vert_counter += 1
	mesh_array[Mesh.ARRAY_VERTEX] = mesh_verts
	mesh_array[Mesh.ARRAY_INDEX] = mesh_indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, mesh_array)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.use_point_size = true
	mat.point_size = 10.0
	mat.albedo_color = color
	mesh_instance.material_override = mat
	add_child(mesh_instance)
		
func _add_edges_and_faces(center : Vector3) -> void:
	var neighbors = axial_ring(center, 1, 2)
	for i in range(6):
		var n1 = neighbors[i]
		var n2 = neighbors[(i + 1) % 6]
		var grid_index_edge : Vector3 = (center + n1) / 2
		if not grid.has(grid_index_edge):
			var edge_cell : EdgeCell = EdgeCell.new(grid_index_edge)
			grid[grid_index_edge] = edge_cell
		var grid_index_face : Vector3 = (center + n1 + n2) / 3
		if not grid.has(grid_index_face):
			var face_cell : FaceCell = FaceCell.new(grid_index_face)
			grid[grid_index_face] = face_cell
	
func _initialize_grid_layers() -> void:
	corn_mesh = ArrayMesh.new()
	edge_mesh = ArrayMesh.new()
	face_mesh = ArrayMesh.new()
	for pos in axial_spiral(Layout.CENTER_TILE_AXIAL, Layout.GRID_RADIUS): #leave on tile empty
		var corn_cell : CornCell = CornCell.new(pos)
		grid[pos] = corn_cell
		_add_edges_and_faces(pos)

func _create_mesh_instance(color : Color) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.height = 1
	sphere.radius = 0.5
	mesh_instance.mesh = sphere
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ORMMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance
	
func cartesian_to_axial(cartesian_position : Vector3) -> Vector3:
	var axial_position : Vector3 = Vector3.ZERO
	axial_position.x = cartesian_position.z * 2./3
	axial_position.y = cartesian_position.y
	axial_position.z = cartesian_position.x * sqrt(3)/3 + cartesian_position.z * -1./3
	return axial_round(axial_position / Layout.CELL_SIZE)

func axial_round(axial_coordinate : Vector3) -> Vector3:
	var xgrid : int = roundi(axial_coordinate.x)
	var zgrid : int = roundi(axial_coordinate.z)
	var return_vector = Vector3(xgrid, roundi(axial_coordinate.y), zgrid)
	print("rounding: axial ", axial_coordinate, " rounded: ", return_vector)
	return return_vector
	
func axial_to_cartesian(axial_position : Vector3) -> Vector3:
	var cartesian_position : Vector3 = Vector3.ZERO
	cartesian_position.x = axial_position.z * 3. / 2
	cartesian_position.y = axial_position.y
	cartesian_position.z = axial_position.x * sqrt(3) + axial_position.z * sqrt(3) / 2
	return Layout.CELL_SIZE * cartesian_position 

func snap_to_face_layer(point : Vector3, _rotation : int) -> Vector3:
	return point
	
func snap_to_edge_layer(point : Vector3) -> Vector3:
	return point
	
func snap_to_corn_layer(point : Vector3) -> Vector3:
	return point

# ------------------- helper functions -------------------

func configure_grid_mesh(mesh : MeshInstance3D, color : Color) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ORMMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material_override = material
	
func axial_ring(center : Vector3, radius : int, step : int) -> Array[Vector3]:
	var cell_size = Layout.CELL_SIZE
	var results : Array[Vector3] = []
	var point : Vector3 = center + Layout.AXIAL_DIRECTION[0] * radius * cell_size * step
	for direction in range(6): # -2 because we don't want up and down here
		for i in range(0, step * radius, step):
			results.append(point)
			point = point + cell_size * step * Layout.AXIAL_DIRECTION[(direction + 2) % 6] # +4 because we want to choose the hexdirection that matches our circle direction
	return results

func axial_spiral(center : Vector3, radius : int) -> Array[Vector3]:
	var results : Array[Vector3] = [center]
	for i : int in range(1, radius + 1):
		var ring : Array[Vector3] = axial_ring(center, i, 2)
		for elem : Vector3 in ring:
			results.append(elem)
	return results

func convert_to_int(bits : String) -> int:
	var result = 0
	for bit_index in range(bits.length()):
		if (int(bits[bit_index]) == 1):
			result += 2 ** bit_index
	return result
