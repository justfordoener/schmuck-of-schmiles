extends Node
# - pointy-top layout
# - even-r layout
# - cube coordinates for grid calculations
# for reference use: https://www.redblobgames.com/grids/cube_coords/#basics

var grid : Dictionary[Vector3, Cell]

var corner_mesh : ArrayMesh
var face_mesh : ArrayMesh
var edge_mesh : ArrayMesh

func _ready() -> void:
	grid = {}
	_initialize_grid_layers()
	_initialize_layer_mesh(corner_mesh, Layout.CELL_TYPE.CORNER, Color.YELLOW)
	_initialize_layer_mesh(face_mesh, Layout.CELL_TYPE.FACE, Color.SKY_BLUE)
	_initialize_layer_mesh(edge_mesh, Layout.CELL_TYPE.EDGE, Color.LIME_GREEN)
	_link_neighbors()
	
func _link_neighbors() -> void:
	for pos in grid.keys():
		var cell = grid[pos]
		match cell.type:
			Layout.CELL_TYPE.CORNER:
				_find_corner_neighbors(pos)
			Layout.CELL_TYPE.EDGE:
				_find_edge_neighbors(pos)
			Layout.CELL_TYPE.FACE:
				_find_face_neighbors(pos)

func _find_corner_neighbors(pos : Vector3) -> void:
	# find 6 edge cells
	for i in range(6):
		var edge_pos = create_axial_index(pos + Layout.AXIAL_DIRECTION[i])
		if grid.has(edge_pos):
			grid[pos].neighbors[edge_pos] = grid[edge_pos]
			
func _find_edge_neighbors(pos : Vector3) -> void:
	# find 2 corners
	for neighbor_pos in grid.keys():
		if grid[neighbor_pos].type == Layout.CELL_TYPE.CORNER:
			if pos.distance_to(neighbor_pos) < 1.1:
				grid[pos].neighbors[neighbor_pos] = grid[neighbor_pos]
	# find 2 faces
	for neighbor_pos in grid.keys():
		if grid[neighbor_pos].type == Layout.CELL_TYPE.FACE:
			if pos.distance_to(neighbor_pos) < 0.8:
				grid[pos].neighbors[neighbor_pos] = grid[neighbor_pos]

func _find_face_neighbors(pos : Vector3) -> void:
	# find 3 edge cells
	for neighbor_pos in grid.keys():
		if grid[neighbor_pos].type == Layout.CELL_TYPE.EDGE:
			if pos.distance_to(neighbor_pos) < 0.8:
				grid[pos].neighbors[neighbor_pos] = grid[neighbor_pos]
		
func _initialize_layer_mesh(mesh : ArrayMesh, cell_type : Layout.CELL_TYPE, color : Color) -> void:
	var mesh_array = []
	mesh_array.resize(Mesh.ARRAY_MAX)
	var mesh_verts = PackedVector3Array()
	var mesh_indices = PackedInt32Array()
	var vert_counter = 0
	print("grid: ", grid.keys())
	for pos : Vector3 in grid.keys():
		if grid[create_axial_index(pos)].type == cell_type:
			var position_axial : Vector3 = grid[create_axial_index(pos)].axial_position
			var position_cartesian = axial_to_cartesian(position_axial)
			mesh_verts.append(position_cartesian)
			mesh_indices.append(vert_counter)
			print(vert_counter, " - cell type: ", grid[create_axial_index(pos)].type, " added axial_position ", position_axial, " on cartesian_position ", position_cartesian)
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
		var pos_edge : Vector3 = (center + n1) / 2
		if not grid.has(create_axial_index(pos_edge)):
			var edge_cell : EdgeCell = EdgeCell.new(create_axial_index(pos_edge))
			grid[create_axial_index(pos_edge)] = edge_cell
		var pos_face : Vector3 = (center + n1 + n2) / 3
		if not grid.has(create_axial_index(pos_face)):
			var face_cell : FaceCell = FaceCell.new(create_axial_index(pos_face))
			grid[create_axial_index(pos_face)] = face_cell
			
func _initialize_grid_layers() -> void:
	corner_mesh = ArrayMesh.new()
	edge_mesh = ArrayMesh.new()
	face_mesh = ArrayMesh.new()
	for pos in axial_spiral(Layout.CENTER_TILE_AXIAL, Layout.GRID_RADIUS): #leave on tile empty
		var corner_cell : CornerCell = CornerCell.new(create_axial_index(pos))
		grid[create_axial_index(pos)] = corner_cell
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
	
#-------------------------------- public functions ----------------------------

func create_axial_index(axial_corrdinate : Vector3) -> Vector3:
	var index : Vector3 = Vector3(roundi(axial_corrdinate.x * 1000), roundi(axial_corrdinate.y * 1000), roundi(axial_corrdinate.z * 1000))
	return index / 1000 #return same vector but rounded 
	
func cartesian_to_axial(cartesian_position : Vector3) -> Vector3:
	cartesian_position = cartesian_position / Layout.CELL_SIZE
	var axial_position : Vector3 = Vector3.ZERO
	axial_position.x = cartesian_position.x * sqrt(3)/3 + cartesian_position.z * -1./3
	axial_position.y = cartesian_position.y
	axial_position.z = cartesian_position.z * 2./3
	return axial_position

func axial_to_cartesian(axial_position : Vector3) -> Vector3:
	var cartesian_position : Vector3 = Vector3.ZERO
	cartesian_position.x = axial_position.x * sqrt(3) + axial_position.z * sqrt(3) / 2
	cartesian_position.y = axial_position.y
	cartesian_position.z = axial_position.z * 3. / 2
	return Layout.CELL_SIZE * cartesian_position 
	
func axial_round(axial_coordinate : Vector3) -> Vector3:
	var xgrid : int = roundi(axial_coordinate.x)
	var zgrid : int = roundi(axial_coordinate.z)
	var return_vector = Vector3(xgrid, roundi(axial_coordinate.y), zgrid)
	print("rounding: axial ", axial_coordinate, " rounded: ", return_vector)
	return return_vector
	
func snap_position(point : Vector3, cell_type : Layout.CELL_TYPE) -> Vector3:
	var closest_pos : Vector3 = point # Fallback to original point
	var min_dist : float = INF
	
	# might need to limit the grid and only check for cells within a given radius for performance
	for index_key in grid.keys():
		var cell = grid[index_key]
		if cell.type == cell_type:
			var cell_world_pos = axial_to_cartesian(cell.axial_position)
			var dist = point.distance_to(cell_world_pos)
			if dist < min_dist:
				min_dist = dist
				closest_pos = cell_world_pos
	return closest_pos
	
func get_rotation_value(type : Layout.CELL_TYPE) -> float:
	match type:
		Layout.CELL_TYPE.CORNER:
			return 60.0
		Layout.CELL_TYPE.EDGE:
			return 180.0
		Layout.CELL_TYPE.FACE:
			return 120.0
		_:
			return 0
			
func snap_rotation(snap_point: Vector3, cell_type : Layout.CELL_TYPE) -> float:
	#var neighbor : Vector3 = point + axial_to_cartesian((Layout.AXIAL_DIRECTION[0] + Layout.AXIAL_DIRECTION[1]) / 2)
	var y_degrees : float = 0.0
	var axial_point : Vector3 = cartesian_to_axial(snap_point)
	match cell_type:
		Layout.CELL_TYPE.EDGE:
			if (roundi(axial_point.x) % 2) == 0:
				y_degrees = 120.0
			elif (roundi(axial_point.z) % 2) == 0:
				y_degrees = 0.0
			else:
				y_degrees = 60.0
		Layout.CELL_TYPE.FACE:
			var fract_sum : float = axial_point.x + axial_point.z
			var round_sum : int = roundi(axial_point.x) + roundi(axial_point.z)
			y_degrees = 60.0 if fract_sum < round_sum else 0.0
		Layout.CELL_TYPE.CORNER:
			y_degrees = 0.0
		_:
			printerr("ERR: something that doesn't have a cell type wants to snap")			
			y_degrees = 30
	return y_degrees
	
func debug_placement(pos : Vector3) -> void:
	spawn_debug_sphere(pos + axial_to_cartesian((
		Layout.AXIAL_DIRECTION[0] +
		Layout.AXIAL_DIRECTION[1]) / 2), 2.0)
	spawn_debug_sphere(pos + axial_to_cartesian((
		Layout.AXIAL_DIRECTION[2] +
		Layout.AXIAL_DIRECTION[3]) / 2), 2.0)
	spawn_debug_sphere(pos + axial_to_cartesian((
		Layout.AXIAL_DIRECTION[4] +
		Layout.AXIAL_DIRECTION[5]) / 2), 2.0)

func spawn_debug_sphere(pos: Vector3, duration: float = 2.0) -> void:
	var sphere = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	sphere.mesh = sphere_mesh
	sphere.global_position = pos
	
	get_tree().root.add_child(sphere)
	
	await get_tree().create_timer(duration).timeout
	sphere.queue_free()
# ------------------- helper functions -------------------

func configure_grid_mesh(mesh : MeshInstance3D, color : Color) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ORMMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material_override = material
	
func axial_ring(center : Vector3, radius : int, step : int) -> Array[Vector3]:
	var cell_height = Layout.CELL_SIZE * sqrt(3)
	var results : Array[Vector3] = []
	var point : Vector3 = center + Layout.AXIAL_DIRECTION[0] * radius * cell_height * step
	for direction in range(6): # -2 because we don't want up and down here
		for i in range(0, step * radius, step):
			results.append(point)
			point = point + cell_height * step * Layout.AXIAL_DIRECTION[(direction + 2) % 6] # +4 because we want to choose the hexdirection that matches our circle direction
	return results

func axial_spiral(center : Vector3, radius : int) -> Array[Vector3]:
	var results : Array[Vector3] = [center]
	for i : int in range(1, radius + 1):
		var ring : Array[Vector3] = axial_ring(center, i, 2)
		for elem : Vector3 in ring:
			results.append(elem)
	return results
