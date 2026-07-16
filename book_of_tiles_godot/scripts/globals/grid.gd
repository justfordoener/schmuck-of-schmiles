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
var module_directory : String = "res://scenes/modules/blockout/"
var link_counter : int = 0

# Uniform-grassland module used to seed the base layer, keyed by cell type.
const GRASS_MODULE_ID : Dictionary[Layout.CELL_TYPE, int] = {
	Layout.CELL_TYPE.CORNER: 20, # hex_20
	Layout.CELL_TYPE.EDGE: 12,   # quad_12
	Layout.CELL_TYPE.FACE: 3,    # tri_3
}

# No-geometry, all-AIR-profile module used to seed the two layers above ground, keyed by
# cell type. Exists so cells up there carry a real WFC profile (AIR) instead of the EMPTY
# wildcard, letting composite edges like FOREST_AIR/CLIFF_AIR match correctly against
# unbuilt space. See _cell_occupies_surface(): these placeholders never block stacking.
const AIR_MODULE_ID : Dictionary[Layout.CELL_TYPE, int] = {
	Layout.CELL_TYPE.CORNER: 24, # hex_24
	Layout.CELL_TYPE.EDGE: 23,   # quad_23
	Layout.CELL_TYPE.FACE: 22,   # tri_22
}

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
	initialize_grass_layer()
	initialize_air_layers()

func _initialize_grid_layers() -> void:
	corner_mesh = ArrayMesh.new()
	edge_mesh = ArrayMesh.new()
	face_mesh = ArrayMesh.new()
	for layer in range(Layout.GRID_HEIGHT):
		var layer_center : Vector3 = Layout.CENTER_TILE_AXIAL + Vector3(0, layer, 0)
		for pos in axial_spiral(layer_center, Layout.GRID_RADIUS): #leave on tile empty
			var corner_cell : CornerCell = CornerCell.new(pos)
			corner_cell.base_rotation = 0 # corners are rotationally symmetric -> always 0
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
		if neighbor_value.y != index_value.y:
			continue # horizontal-only linking: never cross layers by distance alone
		var dist = index_value.distance_to(neighbor_value)
		if neighbor_cell.type == Layout.CELL_TYPE.CORNER and dist < 1.2:
			_establish_link(index, neighbor_index)
		elif neighbor_cell.type == Layout.CELL_TYPE.FACE and dist < 1.0:
			_establish_link(index, neighbor_index)

func _find_face_neighbors(index : Vector3i) -> void:
	# find 3 edge cells
	var index_value = _get_axial_value(index)
	for neighbor_index in grid.keys():
		if grid[neighbor_index].type == Layout.CELL_TYPE.EDGE:
			var neighbor_value = _get_axial_value(neighbor_index)
			if neighbor_value.y != index_value.y:
				continue # horizontal-only linking: never cross layers by distance alone
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
			edge_cell.base_rotation = _base_rotation_for(Layout.CELL_TYPE.EDGE, i)
			grid[get_axial_index(pos_edge)] = edge_cell
		var pos_face : Vector3 = (center + n1 + n2) / 3
		if not grid.has(get_axial_index(pos_face)):
			var face_cell : FaceCell = FaceCell.new(pos_face)
			face_cell.base_rotation = _base_rotation_for(Layout.CELL_TYPE.FACE, i)
			grid[get_axial_index(pos_face)] = face_cell

func _base_rotation_for(cell_type : Layout.CELL_TYPE, dir_index : int) -> int:
	var result : int = 0 # CORNERs have base rotaion of zero
	match cell_type:
		Layout.CELL_TYPE.EDGE:
			var edge_rotations : Array[int] = [0, 120, 60]
			result = edge_rotations[dir_index % 3]
		Layout.CELL_TYPE.FACE:
			result = 60 if dir_index % 2 == 0 else 0
	return result
			
func _init_cell_possibilities(cell_index : Vector3i) -> void:
	var cell : Cell = grid[cell_index]
	for module_ref in modules:
		var module : Module = module_ref.instantiate()
		if module.module_type != grid[cell_index].type:
			module.queue_free()
			continue
		var base_rotation : int = -cell.base_rotation
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
		cell.initial_possibilities = cell.possibilities.duplicate()

# Seeds every ground-layer cell (axial y == 0) with its uniform-grassland module (see
# GRASS_MODULE_ID), using the already-rotated possibilities computed in
# _init_cell_possibilities so each module seats with the correct mesh orientation for its
# cell. Layers above the ground are seeded separately by initialize_air_layers().
func initialize_grass_layer() -> void:
	for cell_index in grid.keys():
		var cell : Cell = grid[cell_index]
		if cell.axial_position.y != 0:
			continue
		_seed_filler_module(cell_index, GRASS_MODULE_ID[cell.type], "initialize_grass_layer")

# Seeds every cell on the layers above ground (axial y > 0) with its no-geometry, all-AIR
# module (see AIR_MODULE_ID), so unbuilt upper-layer cells carry a real AIR profile instead
# of the EMPTY wildcard. These placeholders are transparent to placement targeting (see
# _cell_occupies_surface) and get freed like any other filler once something real is built
# there.
func initialize_air_layers() -> void:
	for cell_index in grid.keys():
		var cell : Cell = grid[cell_index]
		if cell.axial_position.y == 0:
			continue
		_seed_filler_module(cell_index, AIR_MODULE_ID[cell.type], "initialize_air_layers")

func _seed_filler_module(cell_index : Vector3i, module_id : int, caller_name : String) -> void:
	var cell : Cell = grid[cell_index]
	var possibility : Possibility = null
	for poss : Possibility in cell.possibilities:
		if poss.module_reference.module_id == module_id:
			possibility = poss
			break
	if possibility == null:
		printerr(caller_name, ": no module (id ", module_id, ") found for cell ", cell_index, " of type ", cell.type)
		return
	cell.profiles = possibility.profiles.duplicate()
	spawn_module(possibility, cell_index)

func spawn_debug_module(module : Module, cartvec : Vector3, rotdeg : int) -> void:
	get_tree().root.add_child.call_deferred(module)
	module.global_position = cartvec
	module.rotation_degrees.y = rotdeg
	
	
#-------------------------------- wfc ----------------------------

func batch_place_modules(placements: Array) -> void:
	var placed_indices : Array[Vector3i] = []

	for p in placements:
		var cell_index = p["index"]
		var cell : Cell = grid[cell_index]

		# Reset only the cell(s) actually being placed into (dropping any stale soft-fill
		# state from a previous WFC round) before re-fitting. Everything else in the grid -
		# grass base, other columns, other layers - is left untouched.
		if not cell.is_player_placed:
			cell.module_reference = null
			cell.possibilities = cell.initial_possibilities.duplicate()
			cell.profiles = get_hard_profiles_for_cell(cell_index)

		var possibility : Possibility = get_fitting_possibility(cell_index, p["module"], p["rotation"])

		if possibility != null:
			if cell.instanced_module != null:
				cell.instanced_module.queue_free()
				cell.instanced_module = null

			cell.possibilities = [possibility]
			cell.profiles = possibility.profiles
			cell.module_reference = p["module"]
			cell.is_player_placed = true
			placed_indices.append(cell_index)

	# Propagate and settle the wave outward from just this batch's placements - not every
	# historical player placement on the map, which would re-roll far-away, already-settled
	# cells on every unrelated future placement.
	_process_propagation_queue(placed_indices.duplicate())
	_soft_populate_wave(placed_indices)

func _process_propagation_queue(queue: Array[Vector3i]) -> void:
	while queue.size() > 0:
		var current_index = queue.pop_front()
		var cell = grid[current_index]

		# Contradicted cells (see collapse()) have no well-defined committed profile left to
		# share - don't propagate their partial/stale state further.
		if not cell.is_player_placed and cell.possibilities.size() == 0:
			continue

		for neighbor_key : String in cell.neighbors.keys():
			var neighbor_index : Vector3i = get_axial_index(cell.neighbors[neighbor_key].axial_position)
			var neighbor : Cell = grid[neighbor_index]

			neighbor.profiles[neighbor_key] = cell.profiles[neighbor_key]

			if collapse(neighbor_index):
				if not queue.has(neighbor_index):
					queue.append(neighbor_index)

# Continues the propagation wave outward from seed_indices' neighbors, arbitrarily settling
# any cell the deterministic collapse() pass left ambiguous (more than one valid
# possibility) so every reachable cell ends up with a concrete, on-screen module - then
# keeps propagating that pick's profile onward, letting collapse() re-narrow further cells,
# until the wave has nothing left to change. This is what turns "6 edges around a corner"
# into "6 edges, then the 6 faces beyond them" instead of stopping after one ring.
func _soft_populate_wave(seed_indices: Array[Vector3i]) -> void:
	var queue : Array[Vector3i] = []
	for index in seed_indices:
		for neighbor_key in grid[index].neighbors.keys():
			var n_index = get_axial_index(grid[index].neighbors[neighbor_key].axial_position)
			if not grid[n_index].is_player_placed and not queue.has(n_index):
				queue.append(n_index)

	while queue.size() > 0:
		var n_index : Vector3i = queue.pop_front()
		var n_cell : Cell = grid[n_index]

		if n_cell.is_player_placed:
			continue
		if n_cell.possibilities.size() == 0:
			continue # contradicted (see collapse()) - leave existing filler, don't spread it

		if n_cell.possibilities.size() > 1:
			# Deterministic narrowing left this cell ambiguous - arbitrarily settle it on one
			# of its still-valid choices so it has a concrete module, same as any other commit.
			var random_choice : Possibility = n_cell.possibilities[randi() % n_cell.possibilities.size()]
			n_cell.possibilities = [random_choice]
			n_cell.profiles = random_choice.profiles.duplicate()
			spawn_module(random_choice, n_index)
		# else: already settled to exactly one by collapse() (profile already synced there);
		# nothing to pick, just propagate its already-correct profile onward below.

		for neighbor_key in n_cell.neighbors.keys():
			var next_index = get_axial_index(n_cell.neighbors[neighbor_key].axial_position)
			var next_cell = grid[next_index]
			if next_cell.is_player_placed:
				continue
			next_cell.profiles[neighbor_key] = n_cell.profiles[neighbor_key]
			collapse(next_index) # re-narrow with the new info; syncs/spawns if it settles to 1
			if not queue.has(next_index):
				queue.append(next_index)

# Narrows cell_index's possibilities against its currently accumulated profiles. Always
# re-derives from initial_possibilities (not the previously-narrowed possibilities list) so
# the result is order-independent - a cell touched by two neighbors gets the same answer
# regardless of which neighbor's constraint arrived first. Syncs cell.profiles and spawns
# the module the moment exactly one possibility remains, so propagation always carries a
# cell's real committed state onward, never a stale partial one.
func collapse(cell_index : Vector3i) -> bool:
	var cell : Cell = grid[cell_index]

	# Skip if already player-placed (immutable)
	if cell.is_player_placed:
		return false

	# Skip if this cell has already "died" (become an empty space / contradiction)
	if cell.possibilities.size() == 0:
		return false

	var possibilities_before_collapse : int = cell.possibilities.size()
	var new_possibilities : Array[Possibility] = []

	for poss : Possibility in cell.initial_possibilities:
		if do_profiles_match(poss.profiles, cell.profiles):
			new_possibilities.append(poss)

	cell.possibilities = new_possibilities
	var changed = possibilities_before_collapse != cell.possibilities.size()

	if cell.possibilities.size() == 1:
		cell.profiles = cell.possibilities[0].profiles.duplicate()
		spawn_module(cell.possibilities[0], cell_index)

	elif cell.possibilities.size() == 0 and possibilities_before_collapse > 0:
		printerr("collapse: contradiction at cell ", cell_index, " (type ", cell.type,
			") - no possibility satisfies accumulated profiles ", cell.profiles,
			"; leaving existing module in place")

	return changed
	
func spawn_module(poss : Possibility, cell_index : Vector3i) -> void:
	var cell = grid[cell_index]
	
	if cell.instanced_module != null:
		cell.instanced_module.queue_free()
	
	var module_instance = poss.module_reference.duplicate() 
	add_child(module_instance)
	
	var cart_pos = axial_to_cartesian(cell.axial_position)
	module_instance.global_position = cart_pos
	module_instance.rotation_degrees.y = -poss.module_rotation
	
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
	if grid[cell_index].is_player_placed:
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
				# Only validate against player-placed neighbors; ignore soft modules.
				# neighbor stores its own clockwise reading -> compare against its mirror.
				if neighbor != null and neighbor.is_player_placed:
					if possibility.profiles[border_key] != Layout.reverse(neighbor.profiles[border_key]):
						fits = false
						break
			
			if fits:
				return possibility
	return null

func clear_all_soft_modules() -> void:
	for index in grid.keys():
		var cell = grid[index]
		
		# If the cell is not hard-locked by a player
		if not cell.is_player_placed:
			if cell.instanced_module != null:
				cell.instanced_module.queue_free()
				cell.instanced_module = null
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
		if neighbor != null and neighbor.is_player_placed:
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
		# p1 = candidate's own clockwise reading; p2 = value sourced from the neighbour
		# (its own reading), so compare against its mirror. reverse() is identity for
		# single-biome/EMPTY values, keeping old behaviour intact.
		if (p1[border_key] != Layout.reverse(p2[border_key])
		and not (p1[border_key] == Layout.PROFILE_TYPE.EMPTY
		or p2[border_key] == Layout.PROFILE_TYPE.EMPTY)):
			return false
	return true
	
func cartesian_to_axial(cartesian_position : Vector3) -> Vector3:
	var axial_position : Vector3 = Vector3.ZERO
	axial_position.y = cartesian_position.y / Layout.CELL_HEIGHT
	var xz_position : Vector3 = cartesian_position / Layout.CELL_SIZE
	axial_position.x = xz_position.x * sqrt(3)/3 + xz_position.z * -1./3
	axial_position.z = xz_position.z * 2./3
	return axial_position

func axial_to_cartesian(axial_position : Vector3) -> Vector3:
	var cartesian_position : Vector3 = Vector3.ZERO
	cartesian_position.x = axial_position.x * sqrt(3) + axial_position.z * sqrt(3) / 2
	cartesian_position.z = axial_position.z * 3. / 2
	cartesian_position = Layout.CELL_SIZE * cartesian_position
	cartesian_position.y = axial_position.y * Layout.CELL_HEIGHT
	return cartesian_position
	
func axial_round(axial_coordinate : Vector3) -> Vector3:
	var xgrid : int = roundi(axial_coordinate.x)
	var zgrid : int = roundi(axial_coordinate.z)
	var return_vector = Vector3(xgrid, roundi(axial_coordinate.y), zgrid)
	#print("rounding: axial ", axial_coordinate, " rounded: ", return_vector)
	return return_vector
	
# Resolves the (x,z) column nearest to a world-space point, then returns either the lowest
# unoccupied cell in that column (default - stack a new placement above whatever's there),
# or, if target_topmost is set (water tiles), the topmost currently-occupied cell (replace
# the hovered surface in place instead of building above it). Returns null if there's no
# such column, or (non-topmost mode) the column is already full up to GRID_HEIGHT layers.
func snap_to_cell(point : Vector3, cell_type : Layout.CELL_TYPE, target_topmost : bool = false) -> Cell:
	var ground_cell := _nearest_ground_cell(point, cell_type)
	if ground_cell == null:
		return null
	if target_topmost:
		return _topmost_occupied_cell_in_column(ground_cell)
	return _lowest_free_cell_in_column(ground_cell)

# Nearest cell of the given type on the ground layer (y == 0), by XZ-plane distance only
# (ignores point.y so hovering above the ground plane still resolves to the right column).
func _nearest_ground_cell(point : Vector3, cell_type : Layout.CELL_TYPE) -> Cell:
	var closest_cell : Cell = null
	var min_dist : float = INF
	var point_xz := Vector2(point.x, point.z)

	# might need to limit the grid and only check for cells within a given radius for performance
	for index_key in grid.keys():
		var cell = grid[index_key]
		if cell.type == cell_type and cell.axial_position.y == 0:
			var cell_world_pos = axial_to_cartesian(cell.axial_position)
			var dist = point_xz.distance_to(Vector2(cell_world_pos.x, cell_world_pos.z))
			if dist < min_dist:
				min_dist = dist
				closest_cell = cell
	return closest_cell

# True if a cell counts as "occupied" for stacking/placement targeting. Layer 0 is the
# permanent grass floor - always solid, regardless of is_player_placed. Layers above only
# count as occupied once a player has actually built something there: the default AIR
# filler seeded by initialize_air_layers() has a non-null instanced_module too (an empty,
# geometry-less placeholder just carrying an AIR profile for WFC matching), so
# instanced_module alone isn't a reliable occupancy signal - only is_player_placed is.
func _cell_occupies_surface(cell : Cell) -> bool:
	return cell.is_player_placed or cell.axial_position.y == 0

# Walks the column above ground_cell (same x/z, ascending y) and returns the first cell
# that isn't occupied yet (see _cell_occupies_surface).
func _lowest_free_cell_in_column(ground_cell : Cell) -> Cell:
	for layer in range(Layout.GRID_HEIGHT):
		var axial : Vector3 = ground_cell.axial_position
		axial.y = layer
		var index := get_axial_index(axial)
		if not grid.has(index):
			continue
		var cell : Cell = grid[index]
		if not _cell_occupies_surface(cell):
			return cell
	return null

# Walks the column from the ground up and returns the highest occupied cell (see
# _cell_occupies_surface), stopping at the first unoccupied layer - i.e. the surface a
# player is actually looking at/hovering over. Never null: layer 0 is always occupied.
func _topmost_occupied_cell_in_column(ground_cell : Cell) -> Cell:
	var result : Cell = null
	for layer in range(Layout.GRID_HEIGHT):
		var axial : Vector3 = ground_cell.axial_position
		axial.y = layer
		var index := get_axial_index(axial)
		if not grid.has(index):
			break
		var cell : Cell = grid[index]
		if not _cell_occupies_surface(cell):
			break
		result = cell
	return result

func snap_position(point : Vector3, cell_type : Layout.CELL_TYPE, target_topmost : bool = false) -> Vector3:
	var cell := snap_to_cell(point, cell_type, target_topmost)
	return axial_to_cartesian(cell.axial_position) if cell != null else point # fallback to original point
	
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
	
