@tool
extends Node
# - pointy-top layout
# - even-r layout
# - cube coordinates for grid calculations
# for reference use: https://www.redblobgames.com/grids/cube_coords/#basics

var grid : Dictionary[Vector3i, Cell] #TODO for cpp rework: make a seperate datastructure for axial indices

var propagation_stack : Array

var corner_mesh : ArrayMesh
var face_mesh : ArrayMesh
var edge_mesh : ArrayMesh
var modules : Array[PackedScene]
var module_directory : String = "res://scenes/modules/"

func _ready() -> void:
	grid = {}
	_initialize_grid_layers()
	_initialize_layer_mesh(corner_mesh, Layout.CELL_TYPE.CORNER, Color.YELLOW)
	_initialize_layer_mesh(face_mesh, Layout.CELL_TYPE.FACE, Color.SKY_BLUE)
	_initialize_layer_mesh(edge_mesh, Layout.CELL_TYPE.EDGE, Color.LIME_GREEN)
	_link_neighbors()
	
	_load_modules_from_dir(module_directory)

func _load_modules_from_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if !dir.current_is_dir():
				# Web/Export Fix: 
				# 1. Strip .remap or .import suffixes added during export
				# 2. Ensure we only load .tscn (scene) files
				var clean_path = path + "/" + file_name.replace(".remap", "").replace(".import", "")
				
				if clean_path.ends_with(".tscn"):
					# Use ResourceLoader to be safe, though load() usually works
					var res = load(clean_path)
					if res is PackedScene:
						modules.append(res)
						print("Successfully loaded module: ", clean_path)
			
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		printerr("Failed to open module directory: ", path)
	
func _link_neighbors() -> void:
	for index in grid.keys():
		var cell = grid[index]
		match cell.type:
			Layout.CELL_TYPE.CORNER:
				_find_corner_neighbors(index)
			Layout.CELL_TYPE.EDGE:
				_find_edge_neighbors(index)
			Layout.CELL_TYPE.FACE:
				_find_face_neighbors(index)

func _find_corner_neighbors(index : Vector3i) -> void:
	# find 6 edge cells
	for i in range(6):
		var edge_index : Vector3i = index + _get_axial_index(Layout.AXIAL_DIRECTION[i])
		if grid.has(edge_index):
			grid[index].neighbors[edge_index] = grid[edge_index]
			
func _find_edge_neighbors(index : Vector3i) -> void:
	# find 2 corners
	for neighbor_index in grid.keys():
		if grid[neighbor_index].type == Layout.CELL_TYPE.CORNER:
			var index_value = _get_axial_value(index)
			var neighbor_value = _get_axial_value(neighbor_index)
			if index_value.distance_to(neighbor_value) < 1.1:
				grid[index].neighbors[neighbor_index] = grid[neighbor_index]
	# find 2 faces
	for neighbor_index in grid.keys():
		if grid[neighbor_index].type == Layout.CELL_TYPE.FACE:
			var index_value = _get_axial_value(index)
			var neighbor_value = _get_axial_value(neighbor_index)
			if index_value.distance_to(neighbor_value) < 0.8:
				grid[index].neighbors[neighbor_index] = grid[neighbor_index]

func _find_face_neighbors(index : Vector3i) -> void:
	# find 3 edge cells
	for neighbor_index in grid.keys():
		if grid[neighbor_index].type == Layout.CELL_TYPE.EDGE:
			var index_value = _get_axial_value(index)
			var neighbor_value = _get_axial_value(neighbor_index)
			if index_value.distance_to(neighbor_value) < 0.8:
				grid[index].neighbors[neighbor_index] = grid[neighbor_index]
		
func _initialize_layer_mesh(mesh : ArrayMesh, cell_type : Layout.CELL_TYPE, color : Color) -> void:
	var mesh_array = []
	mesh_array.resize(Mesh.ARRAY_MAX)
	var mesh_verts = PackedVector3Array()
	var mesh_indices = PackedInt32Array()
	var vert_counter = 0
	#print("grid: ", grid.keys())
	for key : Vector3i in grid.keys():
		if grid[key].type == cell_type:
			var position_axial : Vector3 = grid[key].axial_position
			var position_cartesian = axial_to_cartesian(position_axial)
			mesh_verts.append(position_cartesian)
			mesh_indices.append(vert_counter)
			#print(vert_counter, " - cell type: ", grid[key].type, " added axial_position ", position_axial, " on cartesian_position ", position_cartesian)
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
		if not grid.has(_get_axial_index(pos_edge)):
			var edge_cell : EdgeCell = EdgeCell.new(pos_edge)
			grid[_get_axial_index(pos_edge)] = edge_cell
		var pos_face : Vector3 = (center + n1 + n2) / 3
		if not grid.has(_get_axial_index(pos_face)):
			var face_cell : FaceCell = FaceCell.new(pos_face)
			grid[_get_axial_index(pos_face)] = face_cell
			
func _initialize_grid_layers() -> void:
	corner_mesh = ArrayMesh.new()
	edge_mesh = ArrayMesh.new()
	face_mesh = ArrayMesh.new()
	for pos in axial_spiral(Layout.CENTER_TILE_AXIAL, Layout.GRID_RADIUS): #leave on tile empty
		var corner_cell : CornerCell = CornerCell.new(pos)
		grid[_get_axial_index(pos)] = corner_cell
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
	
func _get_axial_index(axial_coordinate : Vector3) -> Vector3i:
	var x = roundi(axial_coordinate.x * 1000.0)
	var y = roundi(axial_coordinate.y * 1000.0)
	var z = roundi(axial_coordinate.z * 1000.0)
	return Vector3i(x,y,z)

func _get_axial_value(axial_index : Vector3i) -> Vector3:
	return axial_index / 1000.0
	
#-------------------------------- public functions ----------------------------

func link_module_to_cell(module : Module, cartesian_position : Vector3, rotation_deg : int) -> void:
	var axial_index = _get_axial_index(cartesian_to_axial(cartesian_position))
	grid[axial_index].module_reference = module
	print("___")
	for border_deg : int in module.profiles.keys():
		var profile_axial_direction = Layout.TILE_ROTATION_VALUE[posmod(border_deg - rotation_deg, 360)]
		var profile_axial_position = _get_axial_value(axial_index) + profile_axial_direction
		var dir_to_profile = (profile_axial_position - _get_axial_value(axial_index)).normalized()
		for neighbor_index in grid[axial_index].neighbors.keys():
			var neighbor_axial_position = _get_axial_value(neighbor_index)
			var dir_to_neighbor = (neighbor_axial_position - _get_axial_value(axial_index)).normalized()
			if dir_to_neighbor.dot(dir_to_profile) > 0.99:
				var border_axial_position = _get_axial_value(axial_index) + (neighbor_axial_position - _get_axial_value(axial_index)) / 2
				var border_index = _get_axial_index(dir_to_neighbor)
				var border : Border
				if grid[axial_index].borders.has(border_index):
					border = grid[axial_index].borders[border_index]
				else:
					border = Border.new(border_axial_position)
				border.profile = module.profiles[border_deg]
				grid[axial_index].borders[border_index] = border
				grid[neighbor_index].borders[border_index] = border
				print("linked profile ", border.profile, " at ax_pos: ", border_axial_position)
	
		
func propagate(axial_position : Vector3) -> void:
	#spawn_debug_sphere(axial_to_cartesian(axial_position), 1.0)
	#print(axial_position, " has neighbors: ", grid[_get_axial_index(axial_position)].neighbors.keys())
	for neighbor_key in grid[_get_axial_index(axial_position)].neighbors.keys():
		if not propagation_stack.has(neighbor_key):
			propagation_stack.append(neighbor_key)
			
			collapse_cell(neighbor_key)
			
			await get_tree().create_timer(0.2).timeout
			#propagate(_get_axial_value(neighbor_key))

func round_rotation(value : float) -> int:
	return roundi(value / 30.0) * 30

func collapse_cell(cell_index : Vector3i) -> void:
	var cell = grid[cell_index]
	var axial_position : Vector3 = cell.axial_position
	var cartesian_position : Vector3 = axial_to_cartesian(axial_position)
	
	# Calculate the grid's required orientation first
	var base_snap = snap_rotation(cartesian_position, cell.type)
	
	for module_res in modules:
		var temp_module = module_res.instantiate()
		if temp_module.module_type != cell.type:
			temp_module.queue_free()
			continue
		
		var step = get_rotation_value(cell.type)
		var possible_steps = int(360.0 / step)
		
		for i in range(possible_steps):
			# The ACTUAL rotation is the grid alignment PLUS the WFC choice
			var wfc_offset = int(i * step)
			var total_rotation = int(base_snap + wfc_offset)
			
			# We pass the TOTAL rotation to the fit check
			if _check_module_fit(cell_index, temp_module, total_rotation):
				add_child(temp_module)
				temp_module.global_position = snap_position(cartesian_position, cell.type)
				temp_module.rotation_degrees.y = total_rotation
				
				# Link using the total rotation
				link_module_to_cell(temp_module, cartesian_position, total_rotation)
				return
				
		temp_module.queue_free()
	
func _check_module_fit(cell_index: Vector3i, module: Module, rotation_deg: int) -> bool:
	var cell = grid[cell_index]
	
	# Check every direction where the module has a profile defined
	for local_angle : int in module.profiles.keys():
		# Calculate which global direction this profile points to after rotation
		var global_angle = posmod(local_angle + rotation_deg, 360)
		var direction_vector = Layout.TILE_ROTATION_VALUE[global_angle]
		
		# Find the neighbor in that direction
		var neighbor_pos = _get_axial_value(cell_index) + direction_vector
		var neighbor_index = _get_axial_index(neighbor_pos)
		
		# If there is a neighbor, check the shared border
		if cell.neighbors.has(neighbor_index):
			# We use the direction vector itself as the key for borders
			var border_index = _get_axial_index(direction_vector.normalized())
			
			if cell.borders.has(border_index):
				var existing_border = cell.borders[border_index]
				var module_profile = module.profiles[local_angle]
				
				# Check if the module's profile matches the border's profile
				if existing_border.profile != module_profile:
					return false # Constraint violation!
					
	return true # All borders match

func collapse_cell2(cell_index : Vector3i) -> void:
	print("collapse cell at ", cell_index)
	var axial_position : Vector3 = grid[cell_index].axial_position
	var cartesian_position : Vector3 = axial_to_cartesian(axial_position)
	var new_module : Module
	var rotation_step : int = 0
	var start_rotation : int
	for module : PackedScene in modules:
		new_module = module.instantiate()
		var snap_position = snap_position(cartesian_position, new_module.module_type)
		new_module.global_position = snap_position
		var snap_rotation = deg_to_rad(snap_rotation(new_module.global_position, new_module.module_type))
		new_module.rotation.y = snap_rotation
		if grid[cell_index].type == new_module.module_type:
			add_child(new_module)
			print("rotation: ", rad_to_deg(snap_rotation), " position: ", snap_position)
			return
		continue
		#-------------------------
		start_rotation = round_rotation(rad_to_deg(new_module.rotation.y))
		rotation_step = int(get_rotation_value(new_module.module_type))
		while round_rotation(rad_to_deg(new_module.rotation.y)) < start_rotation + 360:
			for profile_angle in new_module.profiles.keys():
				print(profile_angle)
			pass
			#rotate module to see if it fits
			#if all profiles match:
				# spawn module
				# link_module_to_cell(new_module, axial_to_cartesian(_get_axial_value(cell_index)), rotation_deg)
			new_module.rotate_y(rad_to_deg(rotation_step))
		new_module.queue_free()
		pass
			
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
	#print("rounding: axial ", axial_coordinate, " rounded: ", return_vector)
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

func spawn_debug_sphere(cartesian_pos: Vector3, duration: float = 2.0) -> void:
	var sphere = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	sphere.mesh = sphere_mesh
	
	get_tree().root.add_child(sphere)
	
	sphere.global_position = cartesian_pos + Vector3(0,0.5, 0)
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
