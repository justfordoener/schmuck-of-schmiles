@tool
extends Node
# - pointy-top layout
# - even-r layout
# - cube coordinates for grid calculations
# for reference use: https://www.redblobgames.com/grids/cube_coords/#basics

var grid : Dictionary[Vector3i, Cell] #TODO for cpp rework: make a seperate datastructure for axial indices
var propagation_stack : Array[Vector3i]
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
	_load_modules_from_dir(module_directory)
	for cell_index in grid.keys(): #.slice(0, 5):
		_init_cell_possibilities(cell_index)
		#print("cell: ", grid[cell_index].axial_position, " of type ", grid[cell_index].type, " has ", grid[cell_index].possibilities.size(), " possibilites")

func _initialize_grid_layers() -> void:
	corner_mesh = ArrayMesh.new()
	edge_mesh = ArrayMesh.new()
	face_mesh = ArrayMesh.new()
	for pos in axial_spiral(Layout.CENTER_TILE_AXIAL, Layout.GRID_RADIUS): #leave on tile empty
		var corner_cell : CornerCell = CornerCell.new(pos)
		grid[get_axial_index(pos)] = corner_cell
		_add_edges_and_faces(pos)
	
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
		var edge_index : Vector3i = index + get_axial_index(Layout.AXIAL_DIRECTION[i])
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

func _establish_link(a_index: Vector3i, b_index: Vector3i) -> void:
	var border_index = _get_border_index(a_index, b_index)
	if not grid[a_index].profiles.has(border_index):
		grid[a_index].profiles[border_index] = Layout.PROFILE_TYPE.EMPTY
		grid[b_index].profiles[border_index] = Layout.PROFILE_TYPE.EMPTY
		grid[a_index].neighbors[border_index] = grid[b_index]
		grid[b_index].neighbors[border_index] = grid[a_index]
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
		if not grid.has(get_axial_index(pos_edge)):
			var edge_cell : EdgeCell = EdgeCell.new(pos_edge)
			grid[get_axial_index(pos_edge)] = edge_cell
		var pos_face : Vector3 = (center + n1 + n2) / 3
		if not grid.has(get_axial_index(pos_face)):
			var face_cell : FaceCell = FaceCell.new(pos_face)
			grid[get_axial_index(pos_face)] = face_cell
			
func _init_cell_possibilities(cell_index : Vector3i) -> void:
	var cell : Cell = grid[cell_index]
	for module_ref in modules:
		var module : Module = module_ref.instantiate()
		if module.module_type != grid[cell_index].type:
			module.queue_free()
			continue
		var base_rotation : int = -round_rotation(snap_rotation(axial_to_cartesian(cell.axial_position), module.module_type))
		var rotation_value : int = round_rotation(get_rotation_value(module.module_type))
		var possible_rotations : int = floor(360.0 / rotation_value)
		for i in range(possible_rotations): 
			var total_rotation : int = posmod(base_rotation + i * rotation_value, 360)
			var possible_module : Possibility = Possibility.new()
			possible_module.module_reference = module
			possible_module.module_rotation = total_rotation
			for border_deg in module.profiles.keys():
				var total_direction : int = posmod(total_rotation + border_deg, 360)
				var neighbor_index : Vector3i = get_neighbor_from_rot(cell_index, total_direction)
				var border_index = _get_border_index(cell_index, neighbor_index)
				if neighbor_index == Vector3i(7777,7777,7777):
					possible_module.profiles[border_index] = Layout.PROFILE_TYPE.EMPTY
					continue # border deg is pointing toward the edge of the map
				else:
					possible_module.profiles[border_index] = module.profiles[border_deg]
			cell.possibilities.append(possible_module)
		
func spawn_debug_module(module : Module, cartvec : Vector3, rotdeg : int) -> void:
	get_tree().root.add_child.call_deferred(module)
	module.global_position = cartvec
	module.rotation_degrees.y = rotdeg
	
	
#-------------------------------- wfc ----------------------------

func batch_place_modules(placements: Array) -> void:
	# 1. SCRUB SOFT RULES: Wipe temporary connection profiles from soft cells
	# so they don't block your new hard tiles from propagating correctly.
	for index in grid.keys():
		if grid[index].module_reference == null:
			grid[index].profiles = get_hard_profiles_for_cell(index)

	var queue : Array[Vector3i] = []
	var placed_indices : Array[Vector3i] = []
	
	# 2. PLACE HARD TILES
	for p in placements:
		var cell_index = p["index"]
		var cell : Cell = grid[cell_index]
		var possibility : Possibility = get_fitting_possibility(cell_index, p["module"], p["rotation"])
		
		if possibility != null:
			if cell.instanced_module != null:
				cell.instanced_module.queue_free()
				cell.instanced_module = null
				
			cell.possibilities = [possibility]
			cell.profiles = possibility.profiles
			cell.module_reference = p["module"]
			queue.append(cell_index)
			placed_indices.append(cell_index)
			
	# 3. PROPAGATE NEW HARD CONSTRAINTS GLOBALLY
	_process_propagation_queue(queue)
	
	# 4. CHECK ALL SOFT MODULES: Did the new WFC ripple break them?
	var gaps_to_fill : Array[Vector3i] = []
	for index in grid.keys():
		var cell = grid[index]
		
		# If it is a soft module
		if cell.module_reference == null and cell.instanced_module != null:
			var soft_module : Module = cell.instanced_module
			var is_still_legal = false
			var wfc_rotation = posmod(-roundi(soft_module.rotation_degrees.y), 360)
			
			# Check if it is still allowed by the WFC possibilities list
			for poss in cell.possibilities:
				if poss.module_reference.module_id == soft_module.module_id and poss.module_rotation == wfc_rotation:
					is_still_legal = true
					break
					
			if not is_still_legal:
				# The new hard tile made this soft module invalid! Delete it.
				cell.instanced_module.queue_free()
				cell.instanced_module = null
				gaps_to_fill.append(index)
				
	# 5. REGENERATE: Sprout new soft modules around the new tile AND in any gaps
	var cells_to_populate = placed_indices + gaps_to_fill
	_soft_populate_immediate_neighbors(cells_to_populate)
		
# Extracted the while loop into a helper so we can call it multiple times
func _process_propagation_queue(queue: Array[Vector3i]) -> void:
	while queue.size() > 0:
		var current_index = queue.pop_front()
		var cell = grid[current_index]
		
		for neighbor_key : String in cell.neighbors.keys():
			var neighbor_index : Vector3i = get_axial_index(cell.neighbors[neighbor_key].axial_position)
			var neighbor : Cell = grid[neighbor_index]
			
			neighbor.profiles[neighbor_key] = cell.profiles[neighbor_key]
			
			if collapse(neighbor_index):
				if not queue.has(neighbor_index):
					queue.append(neighbor_index)

func _soft_populate_immediate_neighbors(placed_indices: Array[Vector3i]) -> void:
	var neighbor_set = {}
	
	# Gather all empty, un-locked neighbors
	for index in placed_indices:
		var cell = grid[index]
		for neighbor_key in cell.neighbors.keys():
			var n_index = get_axial_index(cell.neighbors[neighbor_key].axial_position)
			if not placed_indices.has(n_index) and grid[n_index].module_reference == null and grid[n_index].instanced_module == null:
				neighbor_set[n_index] = true
	for n_index in neighbor_set.keys():
		var n_cell = grid[n_index]
		
		# 1. Filter valid choices ON THE FLY based on the cell's current profile constraints.
		# This ensures it respects the soft modules placed immediately before it in this loop!
		var valid_choices : Array[Possibility] = []
		for poss in n_cell.possibilities:
			if do_profiles_match(poss.profiles, n_cell.profiles):
				valid_choices.append(poss)
		
		# 2. Pick a choice and spawn it
		if valid_choices.size() > 0:
			var random_choice = valid_choices[randi() % valid_choices.size()]
			
			# FIX A: Use .duplicate() so we don't accidentally mutate the master template dictionary!
			n_cell.profiles = random_choice.profiles.duplicate()
			
			# FIX B: We DO NOT set n_cell.module_reference here! 
			# Leaving it null tells grid.does_module_fit() that this cell is technically still "empty" 
			# and can be safely overwritten when you place a real tile later.
			
			# FIX C: We DO NOT modify n_cell.possibilities! They stay fully open.
			
			spawn_module(random_choice, n_index)
			
			# FIX D: Manually pass the new connection requirements to neighbors, 
			# WITHOUT running the propagation queue (which would permanently delete their possibilities).
			for neighbor_key in n_cell.neighbors.keys():
				var neighbor_index = get_axial_index(n_cell.neighbors[neighbor_key].axial_position)
				var neighbor = grid[neighbor_index]
				
				# Only pass constraints to cells that aren't hard-locked
				if neighbor.module_reference == null:
					neighbor.profiles[neighbor_key] = n_cell.profiles[neighbor_key]
					
func collapse(cell_index : Vector3i) -> bool:
	var cell : Cell = grid[cell_index]
	
	# Skip if already fully collapsed
	if cell.module_reference != null:
		return false 

	# Skip if this cell has already "died" (become an empty space)
	if cell.possibilities.size() == 0:
		return false

	var possibilities_before_collapse : int = cell.possibilities.size()
	var new_possibilities : Array[Possibility] = []
	
	for poss : Possibility in cell.possibilities:
		if do_profiles_match(poss.profiles, cell.profiles):
			new_possibilities.append(poss)
			
	cell.possibilities = new_possibilities
	var changed = possibilities_before_collapse != cell.possibilities.size()
	
	# --- SPAWN LOGIC ---
	if cell.possibilities.size() == 1:
		cell.module_reference = cell.possibilities[0].module_reference
		# print("WFC [SUCCESS]: Collapsed cell ", cell_index, " to module ID ", cell.module_reference.module_id)
		spawn_module(cell.possibilities[0], cell_index)
		
	elif cell.possibilities.size() == 0 and possibilities_before_collapse > 0:
		# Gracefully accept the contradiction as an empty space
		# print("WFC [EMPTY]: No fitting modules left for cell ", cell_index, ". Leaving as empty space.")
		
		# CRITICAL: Return false so this dead cell doesn't get added back to the queue.
		# This prevents it from spreading impossible constraints to its neighbors!
		return false
		
	return changed
	
func spawn_module(poss : Possibility, cell_index : Vector3i) -> void:
	var cell = grid[cell_index]
	
	# 1. If a soft-placed module already exists here, delete it!
	if cell.instanced_module != null:
		cell.instanced_module.queue_free()
	
	# 2. Spawn the new module
	var module_instance = poss.module_reference.duplicate() 
	add_child(module_instance)
	
	var cart_pos = axial_to_cartesian(cell.axial_position)
	module_instance.global_position = cart_pos
	module_instance.rotation_degrees.y = -poss.module_rotation
	
	# 3. Save the reference so we can delete it if the cell re-collapses later
	cell.instanced_module = module_instance

func propagate(cell_index : Vector3i) -> void:
	var cell : Cell = grid[cell_index]
	#spawn_debug_sphere(axial_to_cartesian(cell.axial_position))
	for neighbor_key : String in cell.neighbors.keys():
		var neighbor_index : Vector3i = get_axial_index(cell.neighbors[neighbor_key].axial_position)
		var neighbor : Cell = grid[neighbor_index]
		if not propagation_stack.has(neighbor_index):
			propagation_stack.append(neighbor_index)
			neighbor.profiles[neighbor_key] = cell.profiles[neighbor_key]
			if not collapse(neighbor_index):
				continue
			else:
				# await get_tree().create_timer(0.2).timeout
				propagate(neighbor_index)
	
func does_module_fit(cell_index : Vector3i, module : Module, rotation : int) -> bool:
	if grid[cell_index].module_reference != null:
		print("cell occupied")
		return false
	var possibility : Possibility = get_fitting_possibility(cell_index, module, rotation)
	if possibility != null:
		return true
	else:
		return false
		
func get_fitting_possibility(cell_index : Vector3i, module : Module, rotation : int) -> Possibility:
	var cell : Cell = grid[cell_index]
	
	for possibility : Possibility in cell.possibilities:
		if possibility.module_reference.module_id == module.module_id and possibility.module_rotation == posmod(rotation, 360):
			
			var fits = true
			for border_key in possibility.profiles.keys():
				if border_key.contains("7777"): 
					continue # Ignore map edges
				var neighbor = cell.neighbors.get(border_key)
				# If it's a soft module (module_reference == null), we ignore it!
				if neighbor != null and neighbor.module_reference != null:
					if possibility.profiles[border_key] != neighbor.profiles[border_key]:
						fits = false
						break
			
			if fits:
				return possibility
	return null

func clear_all_soft_modules() -> void:
	for index in grid.keys():
		var cell = grid[index]
		
		# If the cell is not hard-locked by a player
		if cell.module_reference == null:
			
			# 1. Delete the soft mesh if one exists
			if cell.instanced_module != null:
				cell.instanced_module.queue_free()
				cell.instanced_module = null
			
			# 2. Scrub any soft constraints from its profile, reverting to hard truth
			cell.profiles = get_hard_profiles_for_cell(index)
	
func place_module(cell_index : Vector3i, module : Module, rotation : int) -> void:
	var cell : Cell = grid[cell_index]
	var possibility : Possibility = get_fitting_possibility(cell_index, module, rotation)
	if possibility == null:
		print("module doesn't fit here")
		return
	cell.possibilities = [possibility]
	cell.profiles = possibility.profiles
	cell.module_reference = module
	propagation_stack = []
	print("cid: ", cell_index, " ppvalues: ", possibility.profiles.values(), " cpvalues: ", cell.profiles.values())
	propagate(cell_index)
	
# collapses a cell down to a single possibility. 
func force_collapse(cell_index : Vector3i, module : Module, rotation : int) -> bool:
	var cell : Cell = grid[cell_index]
	for possibility : Possibility in cell.possibilities:
		if (possibility.module_reference.module_id == module.module_id #TODO actually set module ids in scene
		and possibility.module_rotation == posmod(rotation, 360)
		and do_profiles_match(possibility.profiles, cell.profiles)):
			cell.possibilities = [possibility]
			cell.profiles = possibility.profiles
			cell.module_reference = module
			propagation_stack = []
			print("cid: ", cell_index, " ppvalues: ", possibility.profiles.values(), " cpvalues: ", cell.profiles.values())
			propagate(cell_index)
			return true
	return false

# ------------------- helper functions -------------------

func get_hard_profiles_for_cell(cell_index: Vector3i) -> Dictionary[String, Layout.PROFILE_TYPE]:
	var cell = grid[cell_index]
	var hard_profiles : Dictionary[String, Layout.PROFILE_TYPE] = {}
	
	for border_key in cell.profiles.keys():
		var neighbor = cell.neighbors.get(border_key)
		if neighbor != null and neighbor.module_reference != null:
			hard_profiles[border_key] = neighbor.profiles[border_key]
		else:
			hard_profiles[border_key] = Layout.PROFILE_TYPE.EMPTY
			
	return hard_profiles
		
func get_neighbor_from_rot(cell_index : Vector3i, rot_degree : int) -> Vector3i:
	var cell = grid[cell_index]
	var neighbor_index : Vector3i
	var dir_to_neighbor : Vector3 = Layout.TILE_ROTATION_VALUE[rot_degree].normalized()
	for neighbor : Cell in cell.neighbors.values():
		var dir_to_neighbor_temp : Vector3 = (neighbor.axial_position - cell.axial_position).normalized()
		if dir_to_neighbor.dot(dir_to_neighbor_temp) > 0.9:
			neighbor_index = get_axial_index(neighbor.axial_position)
			return neighbor_index
	return Vector3i(7777, 7777, 7777) # TODO externalize as map border vector
	
func _get_border_index(a_index: Vector3i, b_index: Vector3i) -> String:
	var s1 = str(a_index)
	var s2 = str(b_index)
	return s1 + "_" + s2 if s1 < s2 else s2 + "_" + s1
	
func round_rotation(value : float) -> int:
	return roundi(value / 30.0) * 30

func do_profiles_match(p1 : Dictionary[String, Layout.PROFILE_TYPE], p2 : Dictionary[String, Layout.PROFILE_TYPE]) -> bool:
	#print("match profiles", p1.values(), p2.values())
	for border_key : String in p1.keys():
		if border_key.contains("7777"):
			continue
		if (p1[border_key] != p2[border_key]
		and not (p1[border_key] == Layout.PROFILE_TYPE.EMPTY
		or p2[border_key] == Layout.PROFILE_TYPE.EMPTY)):
			return false
	return true
	
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
	
func get_axial_index(axial_coordinate : Vector3) -> Vector3i:
	var x = roundi(axial_coordinate.x * 100.0)
	var y = roundi(axial_coordinate.y * 100.0)
	var z = roundi(axial_coordinate.z * 100.0)
	return Vector3i(x,y,z)

func _get_axial_value(axial_index : Vector3i) -> Vector3:
	return axial_index / 100.0

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
	
