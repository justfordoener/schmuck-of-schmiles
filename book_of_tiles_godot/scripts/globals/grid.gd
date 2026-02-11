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
var link_counter : int = 0

func _ready() -> void:
	grid = {}
	_initialize_grid_layers()
	_initialize_layer_mesh(corner_mesh, Layout.CELL_TYPE.CORNER, Color.YELLOW)
	_initialize_layer_mesh(face_mesh, Layout.CELL_TYPE.FACE, Color.SKY_BLUE)
	_initialize_layer_mesh(edge_mesh, Layout.CELL_TYPE.EDGE, Color.LIME_GREEN)
	_link_neighbors()
	print(grid.size(), link_counter)
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
			_establish_link(index, edge_index)
			
func _find_edge_neighbors(index : Vector3i) -> void:
	var index_value = _get_axial_value(index)
	for neighbor_index in grid.keys(): # possible performance bottleneck for large grids
		var neighbor_cell = grid[neighbor_index]
		var neighbor_value = _get_axial_value(neighbor_index)
		var dist = index_value.distance_to(neighbor_value)
		if neighbor_cell.type == Layout.CELL_TYPE.CORNER and dist < 1.2:
			_establish_link(index, neighbor_index)
		elif neighbor_cell.type == Layout.CELL_TYPE.FACE and dist < 1.0:
			_establish_link(index, neighbor_index)

func _find_face_neighbors(index : Vector3i) -> void:
	# find 3 edge cells
	for neighbor_index in grid.keys():
		if grid[neighbor_index].type == Layout.CELL_TYPE.EDGE:
			var index_value = _get_axial_value(index)
			var neighbor_value = _get_axial_value(neighbor_index)
			if index_value.distance_to(neighbor_value) < 1.0:
				_establish_link(neighbor_index, index)

func _get_border_index(a_index: Vector3i, b_index: Vector3i) -> String:
	var s1 = str(a_index)
	var s2 = str(b_index)
	return s1 + "_" + s2 if s1 < s2 else s2 + "_" + s1

func _establish_link(a_index: Vector3i, b_index: Vector3i) -> void:
	var border = Border.new()
	var border_index = _get_border_index(a_index, b_index)
	if not grid[a_index].borders.has(border_index):
		border.profile = Layout.PROFILE_TYPE.EMPTY
		grid[a_index].borders[border_index] = border
		grid[b_index].borders[border_index] = border
		grid[a_index].neighbors[b_index] = grid[b_index]
		grid[b_index].neighbors[a_index] = grid[a_index]
		link_counter += 1
		#print("added border: ", border_index, " type a: ", grid[a_index].type, " type b: ", grid[b_index].type)
	else:
		pass
		
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
	var x = roundi(axial_coordinate.x * 100.0)
	var y = roundi(axial_coordinate.y * 100.0)
	var z = roundi(axial_coordinate.z * 100.0)
	return Vector3i(x,y,z)

func _get_axial_value(axial_index : Vector3i) -> Vector3:
	return axial_index / 100.0
	
#-------------------------------- public functions ----------------------------

func link_module_to_cell(module : Module, cartesian_position : Vector3, rotation_deg : int) -> void:
	var axial_index = _get_axial_index(cartesian_to_axial(cartesian_position))
	grid[axial_index].module_reference = module
	#print("___", module.module_type, " has borders: ", module.profiles.keys())
	for border_deg : int in module.profiles.keys():
		var profile_dir = Layout.TILE_ROTATION_VALUE[posmod(border_deg - rotation_deg, 360)]
		#var profile_axial_position = _get_axial_value(axial_index) + profile_axial_direction
		#var dir_to_profile = (profile_axial_position - _get_axial_value(axial_index)).normalized()
		for neighbor_index in grid[axial_index].neighbors.keys():
			var neighbor_axial_position = _get_axial_value(neighbor_index)
			var dir_to_neighbor = neighbor_axial_position - _get_axial_value(axial_index)
			if dir_to_neighbor.normalized().dot(profile_dir.normalized()) > 0.99:
				var border_index = _get_border_index(axial_index, neighbor_index)
				if not grid[axial_index].borders.has(border_index):
					printerr("no border ", border_index, " found at axial_index", axial_index)
				var profile : Layout.PROFILE_TYPE = module.profiles[border_deg]
				grid[axial_index].borders[border_index].profile = profile
				grid[neighbor_index].borders[border_index].profile = profile
				#print("updated border ", border_index, " to: ", profile)
				
func propagate(axial_position : Vector3) -> void:
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
	var base_snap = snap_rotation(cartesian_position, cell.type)
	for module_res in modules:
		var temp_module = module_res.instantiate()
		if temp_module.module_type != cell.type:
			temp_module.queue_free()
			continue
		var step = get_rotation_value(cell.type)
		var possible_steps = int(360.0 / step)
		for i in range(possible_steps):
			var wfc_offset = int(i * step)
			var total_rotation = int(base_snap + wfc_offset)
			if check_module_fit(cell_index, temp_module, total_rotation):
				add_child(temp_module)
				temp_module.global_position = snap_position(cartesian_position, cell.type)
				temp_module.rotation_degrees.y = total_rotation
				link_module_to_cell(temp_module, cartesian_position, total_rotation)
				return
		temp_module.queue_free()

func check_module_fit(cell_index: Vector3i, module: Module, rotation: int) -> bool:
	var cell_profiles : Array[Layout.PROFILE_TYPE]
	var module_profiles : Array[Layout.PROFILE_TYPE]
	for border in grid[cell_index].borders.values():
		cell_profiles.append(border.profile)
	for module_deg in module.profiles.keys():
		var steps : int = int((rotation) / get_rotation_value(module.module_type))
		module_profiles.append(module.profiles[posmod(module_deg + steps * get_rotation_value(module.module_type), 360)])
	print("cell_index: ", cell_index, "mprofiles: ",module_profiles, " cprofiles: ", cell_profiles)
	if module.module_type != grid[cell_index].type:
		return false
	for i in cell_profiles.size():
		if not evaluate_profiles(cell_profiles[i], module_profiles[i]):
			return false
	return true
		
func evaluate_profiles(p1 : Layout.PROFILE_TYPE, p2 : Layout.PROFILE_TYPE) -> bool:
	if (p1 == Layout.PROFILE_TYPE.EMPTY
	 or p2 == Layout.PROFILE_TYPE.EMPTY
	 or p1 == p2):
		return true
	return false
	
func check_module_fit2(cell_index: Vector3i, module: Module, rotation_deg: int) -> bool:
	var cell = grid[cell_index]
	for local_angle : int in module.profiles.keys():
		var global_angle = posmod(local_angle + rotation_deg, 360)
		var dir_vec = Layout.TILE_ROTATION_VALUE[global_angle]
		
		for n_idx in cell.neighbors.keys():
			var n_dir = (_get_axial_value(n_idx) - _get_axial_value(cell_index)).normalized()
			if n_dir.dot(dir_vec.normalized()) > 0.98:
				var b_key = _get_border_index(cell_index, n_idx)
				var existing = cell.borders[b_key].profile
				if existing == Layout.PROFILE_TYPE.EMPTY:
					continue
				if existing != module.profiles[local_angle]:
					return false
	return true
	
func _check_module_fit2(cell_index: Vector3i, module: Module, rotation_deg: int) -> bool:
	var cell = grid[cell_index]
	var cell_axial_position = _get_axial_value(cell_index)
	# Check every direction where the module has a profile defined
	for local_angle : int in module.profiles.keys():
		var global_angle = posmod(local_angle + rotation_deg, 360)
		var direction_vector = Layout.TILE_ROTATION_VALUE[global_angle]
		var neighbor_direction : Vector3
		# Find the neighbor in the direction of the profile to get the border
		for neighbor_index in cell.neighbors.keys():
			var neighbor_axial_position = grid[neighbor_index].axial_position
			neighbor_direction = neighbor_axial_position - cell_axial_position
			if neighbor_direction.normalized().dot(direction_vector.normalized()) > 0.99:
				break # make sure to only consider the neighbor that aligns with the angle
		# borders are always in between two cells, even if it isn't geometrically accurate
		var border_index = _get_axial_index(cell_axial_position + 0.5 * neighbor_direction)
		if cell.borders.has(border_index):
			# Check if the module's profile matches the border's profile
			if cell.borders[border_index].profile != module.profiles[local_angle]:
				return false # Constraint violation!
					
	return true # All borders match

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
