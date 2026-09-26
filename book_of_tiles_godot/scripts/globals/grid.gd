#@tool
extends Node
# - pointy-top layout
# - even-r layout
# - cube coordinates for grid calculations
# for reference use: https://www.redblobgames.com/grids/cube_coords/#basics

var grid : Dictionary[Vector3i, Cell] #TODO for cpp rework: make a seperate datastructure for axial indices
var corner_mesh : ArrayMesh
var face_mesh : ArrayMesh
var edge_mesh : ArrayMesh
var modules : Array[PackedScene]
var module_directory : String = "res://scenes/modules/blockout/"
var link_counter : int = 0
# Landmarks currently standing on the board (see merge_landmark). Held so one owner frees
# them; the cells they cover point back at them through Cell.landmark.
var landmarks : Array[Landmark] = []
# True once any landmark has formed. Merging is a hard commit - there is no rollback path
# for the tiles it consumed - so UI_manager hides undo until the next day.
var landmark_formed_today : bool = false

# Uniform-grassland module used to seed the base layer, keyed by cell type.
const GRASS_MODULE_ID : Dictionary[Layout.CELL_TYPE, int] = {
	Layout.CELL_TYPE.CORNER: 20, # corner_grass_grass_grass_grass_grass_grass
	Layout.CELL_TYPE.EDGE: 12,   # edge_grass_grass_grass_grass
	Layout.CELL_TYPE.FACE: 3,    # face_grass_grass_grass
}

# No-geometry, all-AIR-profile module used to seed the two layers above ground, keyed by
# cell type. Exists so cells up there carry a real WFC profile (AIR) instead of the EMPTY
# wildcard, letting composite edges like FOREST_AIR/CLIFF_AIR match correctly against
# unbuilt space. See _cell_occupies_surface(): these placeholders never block stacking.
const AIR_MODULE_ID : Dictionary[Layout.CELL_TYPE, int] = {
	Layout.CELL_TYPE.CORNER: 24, # corner_air_air_air_air_air_air
	Layout.CELL_TYPE.EDGE: 23,   # edge_air_air_air_air
	Layout.CELL_TYPE.FACE: 22,   # face_air_air_air
}

# Stands in for "there is no cell here" - returned by get_neighbor_from_rot() for a border
# direction that points off the edge of the map. No real cell can carry it: every axial index
# is a grid coordinate scaled by 100 (see get_axial_index).
const MAP_BORDER_INDEX : Vector3i = Vector3i(7777, 7777, 7777)

# What a cell on the rim of the map reads on a border pointing off it. The world ends at the
# map's edge, so the only thing out there is open sky - which makes a rim cell resolve to a
# module that transitions from whatever it holds into AIR (a cliff edge on the ground slab, a
# forest-to-air edge under a placed tree) instead of running its own biome off into nothing.
# Treated as a hard, permanent constraint: see get_hard_profiles_for_cell().
const MAP_BORDER_PROFILE : Layout.PROFILE_TYPE = Layout.PROFILE_TYPE.AIR

func _ready() -> void:
	grid = {}
	_initialize_grid_layers()
	#_initialize_layer_mesh(corner_mesh, Layout.CELL_TYPE.CORNER, Color.YELLOW)
	#_initialize_layer_mesh(face_mesh, Layout.CELL_TYPE.FACE, Color.SKY_BLUE)
	#_initialize_layer_mesh(edge_mesh, Layout.CELL_TYPE.EDGE, Color.LIME_GREEN)
	_link_neighbors()
	_load_modules_from_dir(module_directory)
	for cell_index in grid.keys(): #.slice(0, 5):
		_init_cell_possibilities(cell_index)
		#print("cell: ", grid[cell_index].axial_position, " of type ", grid[cell_index].type, " has ", grid[cell_index].possibilities.size(), " possibilites")
	initialize_grass_layer()
	initialize_air_layers()
	_settle_map_border()

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
				if neighbor_index == MAP_BORDER_INDEX:
					# This border points off the edge of the map. Keyed by direction rather than
					# by a neighbour that isn't there, so a cell with two such borders keeps them
					# apart, and the module's own declaration is kept instead of being thrown
					# away - it's what MAP_BORDER_PROFILE gets matched against, which is what
					# makes the rim pick a transition into air. Registered on the cell too, so
					# every profile dict built from cell.profiles.keys() carries the border.
					var map_border_key : String = _get_map_border_key(cell_index, total_direction)
					possible_module.profiles[map_border_key] = module.profiles[border_deg]
					cell.profiles[map_border_key] = MAP_BORDER_PROFILE
					continue
				var border_index = _get_border_index(cell_index, neighbor_index)
				possible_module.profiles[border_index] = module.profiles[border_deg]
			cell.possibilities.append(possible_module)
		cell.initial_possibilities = cell.possibilities.duplicate()

# Seeds every ground-layer cell (axial y == 0) with its uniform-grass module (see
# GRASS_MODULE_ID), using the already-rotated possibilities computed in
# _init_cell_possibilities so each module seats with the correct mesh orientation for its
# cell. Layers above the ground are seeded separately by initialize_air_layers().
func initialize_grass_layer() -> void:
	for cell_index in grid.keys():
		var cell : Cell = grid[cell_index]
		if cell.axial_position.y != 0:
			continue
		_seed_filler_module(cell_index, GRASS_MODULE_ID[cell.type], Layout.TILE_KIND.GRASS, "initialize_grass_layer")

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
		_seed_filler_module(cell_index, AIR_MODULE_ID[cell.type], Layout.TILE_KIND.NONE, "initialize_air_layers")

# tile_kind is what recipes match against (see Recipes.find_match): seeded ground reads as
# real grass, the empty layers above read NONE. That's why matching never needs a separate
# "was this placed by a player?" flag - every corner always carries a meaningful kind.
func _seed_filler_module(cell_index : Vector3i, module_id : int, tile_kind : Layout.TILE_KIND, caller_name : String) -> void:
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
	cell.tile_kind = tile_kind
	spawn_module(possibility, cell_index)

func spawn_debug_module(module : Module, cartvec : Vector3, rotdeg : int) -> void:
	get_tree().root.add_child.call_deferred(module)
	module.global_position = cartvec
	module.rotation_degrees.y = rotdeg
	
	
#-------------------------------- wfc ----------------------------

# Places every module of one tile, then re-solves the two rings around them. Returns the
# visuals it displaced (the module/tile nodes that were sitting in the placed-into cells),
# already queue_free()d - the caller needs them to drop a replaced tile from its own undo
# history, and can't detect them via is_instance_valid() because queue_free() only takes
# effect at the end of the frame.
func batch_place_modules(placements: Array) -> Array[Node3D]:
	var placed_indices : Array[Vector3i] = []
	var displaced : Array[Node3D] = []

	for p in placements:
		var cell_index = p["index"]
		var cell : Cell = grid[cell_index]

		# Reset the cell(s) actually being placed into before re-fitting, dropping any stale
		# state - a soft fill from a previous WFC round, the seeded grass/AIR filler, or an
		# earlier placement being replaced (water dropped onto existing land). Without this
		# the cell's possibilities are still narrowed to whatever it currently shows, and no
		# other module could ever be fitted into it. Everything else in the grid - other
		# columns, other layers - is left untouched.
		cell.module_reference = null
		cell.possibilities = cell.initial_possibilities.duplicate()
		cell.profiles = get_hard_profiles_for_cell(cell_index)

		var possibility : Possibility = get_fitting_possibility(cell_index, p["module"], p["rotation"])

		if possibility != null:
			if cell.instanced_module != null:
				displaced.append(cell.instanced_module)
				cell.instanced_module.queue_free()
				cell.instanced_module = null

			cell.possibilities = [possibility]
			cell.profiles = possibility.profiles
			cell.module_reference = p["module"]
			# The placed tile node itself is this cell's visual from now on, so a later
			# placement into the same cell (water dropped onto land) frees it through the
			# same path that frees a solver-spawned filler, instead of leaving the old
			# geometry sitting inside the new module.
			cell.instanced_module = p["instance"]
			cell.tile_kind = p["instance"].tile_kind
			placed_indices.append(cell_index)

	# Recipe detection sits between the placement and the propagation wave on purpose: a merge
	# consumes tiles and wipes every cell inside its footprint, so solving the edges and faces
	# around those tiles first would only be work to throw away. Anchored on the corner just
	# placed, since a pattern that didn't match before must contain it.
	var recipe_match : Dictionary = {}
	for cell_index in placed_indices:
		if grid[cell_index].type != Layout.CELL_TYPE.CORNER:
			continue
		recipe_match = Recipes.find_match(cell_index)
		if not recipe_match.is_empty():
			break

	if recipe_match.is_empty():
		_propagate_around(placed_indices, {})
	else:
		var footprint := derive_landmark_footprint(recipe_match["corners"])
		var footprint_set : Dictionary = {}
		for cell_index in footprint:
			footprint_set[cell_index] = true
		displaced.append_array(merge_landmark(recipe_match, footprint))
		# Re-solve outward from the landmark's rim instead of from the placed tile: the
		# footprint's own cells are hard now and must be left alone (hence the exclusion set),
		# but everything just outside it has to re-fit against the boundary it now presents.
		_propagate_around(footprint, footprint_set)

	return displaced

# Updates the two rings around a set of hard cells: the edges directly touching one, then the
# faces touching those. Ring 2 only starts once ring 1 has fully settled, so a face touched by
# two ring-1 edges always sees both of their constraints before it picks anything - no
# dependency on which edge happened to resolve first.
#
# The type filters matter once hard_indices contains more than corners: a landmark footprint
# includes edges, whose neighbours are faces, so without them a face could land in ring 1 and
# pick before the edges beside it settle. For a plain placement they change nothing - the
# neighbours of a corner are all edges already.
func _propagate_around(hard_indices : Array[Vector3i], exclude : Dictionary) -> void:
	var ring1 := _soft_populate_ring(hard_indices, exclude, Layout.CELL_TYPE.EDGE)
	var ring2_triggers : Array[Vector3i] = hard_indices.duplicate()
	ring2_triggers.append_array(ring1)
	_soft_populate_ring(ring2_triggers, exclude, Layout.CELL_TYPE.FACE)

# For every soft (non-CORNER) neighbor of trigger_indices: rebuilds its whole profile dict
# from scratch via get_settled_profiles_for_cell() (so e.g. an edge between two placed
# corners picks up both, and any not-yet-settled border is a clean EMPTY wildcard rather
# than a stale leftover value from the old filler module), then narrows it (collapse()
# first, so an unambiguous winner is picked deterministically), and if more than one
# possibility still remains, arbitrarily settles on one of the valid ones so the cell always
# ends up with a concrete, on-screen module. Returns the touched indices, to feed the next
# ring (its neighbors will then see this ring's just-committed profiles).
# `exclude` holds cell indices that must never be refilled however they are reached - a
# landmark's own footprint. `type_filter` restricts the ring to one cell type; -1 (the
# default) takes every soft cell, which is what a plain placement wants.
func _soft_populate_ring(trigger_indices: Array[Vector3i], exclude : Dictionary = {}, type_filter : int = -1) -> Array[Vector3i]:
	var cells_to_fill := {}
	for index in trigger_indices:
		for neighbor_key in grid[index].neighbors.keys():
			var n_index = get_axial_index(grid[index].neighbors[neighbor_key].axial_position)
			var n_cell : Cell = grid[n_index]
			# Corners are hard (only ever written by an explicit player placement) - never
			# auto-narrowed here, even when reached through an edge's neighbor list. Landmark
			# cells are hard for the same reason: they show a merged object, not a module the
			# solver owns.
			if n_cell.type == Layout.CELL_TYPE.CORNER or n_cell.landmark != null:
				continue
			if exclude.has(n_index):
				continue
			if type_filter != -1 and n_cell.type != type_filter:
				continue
			cells_to_fill[n_index] = true

	var touched : Array[Vector3i] = []
	for n_index : Vector3i in cells_to_fill.keys():
		if _settle_cell(n_index):
			touched.append(n_index)
	return touched

# Re-fits one soft cell against everything currently committed around it and commits the
# result on screen. Returns false if the cell contradicted - it then has no real committed
# profile, so a caller feeding the next ring must not treat it as a source of constraints
# (that border just stays unconstrained downstream).
func _settle_cell(cell_index : Vector3i) -> bool:
	var cell : Cell = grid[cell_index]
	cell.profiles = get_settled_profiles_for_cell(cell_index)
	collapse(cell_index) # deterministic narrow first, in case this alone resolves it

	if cell.possibilities.size() == 0:
		return false # contradiction - logged by collapse(), filler left in place

	if cell.possibilities.size() > 1:
		var random_choice : Possibility = cell.possibilities[randi() % cell.possibilities.size()]
		cell.possibilities = [random_choice]
		cell.profiles = random_choice.profiles.duplicate()
		spawn_module(random_choice, cell_index)
	# else: collapse() already synced profiles + spawned when it settled to exactly 1.

	return true

# Fits the cells along the rim of the map against the open sky outside it, once, at startup.
#
# Needed because the seeding passes above don't know about the map's edge: they hand every
# ground-layer cell the uniform grass module, which declares GRASS on a border that now has to
# read AIR (see MAP_BORDER_PROFILE). Re-fitting turns that rim into the cliff-into-air modules
# that actually terminate the ground slab - one module fits each ground rim cell, so what boots
# is fixed, not a roll. The layers above seed all-AIR modules, which already satisfy the
# constraint, so up there this pass settles straight back onto the filler: several possibilities
# survive, but they are all the same geometry-less AIR module at different rotations, so
# _settle_cell()'s arbitrary pick between them has nothing to choose.
#
# Edges first, then faces, for the same reason _propagate_around() works in rings: a face has to
# see every edge beside it already settled before it picks. The face set is deliberately wider
# than the edge set - a face with all three of its edges on the map still has to change when two
# of them turned into cliff edges, so every face touching a rim edge is included, not just the
# faces that have a border off the map themselves.
func _settle_map_border() -> void:
	var rim_edges : Array[Vector3i] = []
	var rim_faces : Dictionary = {}
	for cell_index : Vector3i in grid.keys():
		if not _has_map_border(grid[cell_index]):
			continue
		match grid[cell_index].type:
			Layout.CELL_TYPE.EDGE:
				rim_edges.append(cell_index)
			Layout.CELL_TYPE.FACE:
				rim_faces[cell_index] = true

	for cell_index : Vector3i in rim_edges:
		_settle_cell(cell_index)
		for neighbor : Cell in grid[cell_index].neighbors.values():
			if neighbor.type == Layout.CELL_TYPE.FACE:
				rim_faces[get_axial_index(neighbor.axial_position)] = true

	for cell_index : Vector3i in rim_faces.keys():
		_settle_cell(cell_index)

# True if any of this cell's borders points off the edge of the map. Those borders are the ones
# _establish_link() never created a neighbor for - see _get_map_border_key().
func _has_map_border(cell : Cell) -> bool:
	for border_key : String in cell.profiles.keys():
		if not cell.neighbors.has(border_key):
			return true
	return false

# Narrows cell_index's possibilities against its currently accumulated profiles. Always
# re-derives from initial_possibilities (not the previously-narrowed possibilities list) so
# the result is order-independent - a cell touched by two neighbors gets the same answer
# regardless of which neighbor's constraint arrived first. Syncs cell.profiles and spawns
# the module the moment exactly one possibility remains, so propagation always carries a
# cell's real committed state onward, never a stale partial one.
func collapse(cell_index : Vector3i) -> bool:
	var cell : Cell = grid[cell_index]

	# Corners are hard: only ever written by a placement, never narrowed by the solver.
	if cell.type == Layout.CELL_TYPE.CORNER:
		return false

	# So is a cell that has been merged into a landmark - it shows one big object instead of a
	# module, and keeps the boundary profiles it inherited from the tiles that object replaced.
	if cell.landmark != null:
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
	
# ------------------------------ landmarks -------------------------------

# Every cell a landmark swallows - a volume, not a slice. The matched corners give a set of
# columns and a range of layers, and the landmark takes everything in between:
#
#   - project the matched corners onto columns, and note the layers they span
#   - on each layer of that span, take those columns' corner cells, then the edges enclosed by
#     them, then the faces enclosed by those edges (see _footprint_slice)
#
# Splitting it that way is what makes it height-independent. The enclosure rules are purely
# horizontal, and so is the grid: _find_edge_neighbors/_find_face_neighbors never link across
# layers, so each slice is self-contained and the same rules hold at any height.
#
# The vertical span is what a recipe spanning two heights needs. The Great Clearing is a grass
# corner on one layer ringed by forest on the next, so its span is two layers: the landmark
# takes the ring's forest and the ground beneath it, and the hollow's grass and the air above
# it - the whole bowl, so nothing can be built inside the volume it occupies. A flat recipe
# spans a single layer, which reduces this to just the horizontal rules.
func derive_landmark_footprint(corners : Array[Vector3i]) -> Array[Vector3i]:
	var columns : Array[Vector3] = []
	var min_layer : int = roundi(grid[corners[0]].axial_position.y)
	var max_layer : int = min_layer
	for corner_index : Vector3i in corners:
		var axial : Vector3 = grid[corner_index].axial_position
		columns.append(Vector3(axial.x, 0, axial.z))
		min_layer = mini(min_layer, roundi(axial.y))
		max_layer = maxi(max_layer, roundi(axial.y))

	var footprint : Array[Vector3i] = []
	for layer : int in range(min_layer, max_layer + 1):
		for cell_index : Vector3i in _footprint_slice(columns, layer):
			footprint.append(cell_index)
	return footprint

# The footprint's cells on one layer: the corner cells of `columns` that exist there, plus
# every edge whose two corners are both among them, plus every face whose three edges are all
# among those. Cells on the landmark's rim are left out by the neighbour counts - an edge with
# a corner outside the pattern (or off the map) fails the first test, and the faces beyond it
# fail the second.
func _footprint_slice(columns : Array[Vector3], layer : int) -> Array[Vector3i]:
	var corner_set : Dictionary = {}
	for column : Vector3 in columns:
		var corner_index := get_axial_index(Vector3(column.x, layer, column.z))
		if grid.has(corner_index):
			corner_set[corner_index] = true

	var edge_set : Dictionary = {}
	for corner_index : Vector3i in corner_set.keys():
		for neighbor : Cell in grid[corner_index].neighbors.values():
			if neighbor.type != Layout.CELL_TYPE.EDGE:
				continue
			var edge_index := get_axial_index(neighbor.axial_position)
			if not edge_set.has(edge_index) and _neighbors_all_within(neighbor, Layout.CELL_TYPE.CORNER, corner_set, 2):
				edge_set[edge_index] = true

	var face_set : Dictionary = {}
	for edge_index : Vector3i in edge_set.keys():
		for neighbor : Cell in grid[edge_index].neighbors.values():
			if neighbor.type != Layout.CELL_TYPE.FACE:
				continue
			var face_index := get_axial_index(neighbor.axial_position)
			if not face_set.has(face_index) and _neighbors_all_within(neighbor, Layout.CELL_TYPE.EDGE, edge_set, 3):
				face_set[face_index] = true

	var slice : Array[Vector3i] = []
	for corner_index : Vector3i in corner_set.keys():
		slice.append(corner_index)
	for edge_index : Vector3i in edge_set.keys():
		slice.append(edge_index)
	for face_index : Vector3i in face_set.keys():
		slice.append(face_index)
	return slice

# True if every neighbor of `cell` of the given type is in `allowed`, and there are exactly
# `expected_count` of them. The count is what rejects cells on the map border, where a
# missing neighbor would otherwise let a one-sided cell pass as fully enclosed.
func _neighbors_all_within(cell : Cell, neighbor_type : Layout.CELL_TYPE, allowed : Dictionary, expected_count : int) -> bool:
	var count : int = 0
	for neighbor : Cell in cell.neighbors.values():
		if neighbor.type != neighbor_type:
			continue
		if not allowed.has(get_axial_index(neighbor.axial_position)):
			return false
		count += 1
	return count == expected_count

# Replaces everything inside `footprint` with the single landmark object the recipe produces.
# Returns the visuals it displaced, already queue_free()d, for the same reason
# batch_place_modules() does: the caller drops the consumed tiles from its undo history and
# can't detect them itself, because queue_free() only takes effect at end of frame.
#
# The landmark's rim is inherited rather than authored: every footprint cell keeps the
# `profiles` it holds on each border pointing out of the footprint, which is what the tiles it
# replaced declared there - forest all the way around a Great Clearing. A landmark that wants
# a different rim (a river running out of it) will need an override table here; nothing does
# yet.
#
# Two of the three cell types are already correct to inherit from. Corners are hard, written
# by placements. Faces contribute nothing: a face only joins the footprint when all three of
# its edges did, so it has no outward border at all. Edges are the exception - see the
# re-settle pass below.
func merge_landmark(recipe_match : Dictionary, footprint : Array[Vector3i]) -> Array[Node3D]:
	var displaced : Array[Node3D] = []
	var landmark : Landmark = recipe_match["scene"].instantiate()
	add_child(landmark)

	# Horizontally the centre of the matched corners, so the object covers them symmetrically
	# however the pattern was rotated into place. Vertically the lowest layer they span, so a
	# landmark mesh is authored upwards from its base the way a module's is. For a recipe that
	# sits on one layer the two are the same thing.
	var centroid : Vector3 = Vector3.ZERO
	var base_layer : int = roundi(grid[recipe_match["corners"][0]].axial_position.y)
	for corner_index : Vector3i in recipe_match["corners"]:
		var axial : Vector3 = grid[corner_index].axial_position
		centroid += Vector3(axial.x, 0, axial.z)
		base_layer = mini(base_layer, roundi(axial.y))
	centroid /= recipe_match["corners"].size()
	centroid.y = base_layer
	landmark.global_position = axial_to_cartesian(centroid)
	# Negated to match spawn_module(): pattern rotation is clockwise in grid space. A mirrored
	# match becomes scale.x = -1, which is exactly the reflection Recipes._mirror_offset() uses;
	# the resulting basis is rotation * mirror, the same order the match was resolved in.
	landmark.rotation_degrees.y = -recipe_match["rotation"]
	if recipe_match.get("mirrored", false):
		landmark.scale.x = -1.0

	# The footprint's own edges are stale by construction. Each last settled against a
	# configuration that did not include the tile which just completed the recipe, because
	# detection deliberately runs before the propagation wave - so an edge between two of the
	# recipe's corners can still be declaring a rim against open air where there is now a
	# neighbouring tile. Those outward borders become the landmark's rim, so settle them
	# against the finished corner set before freezing, or the landmark presents a boundary
	# describing tiles that are no longer there and the faces just outside it contradict.
	for cell_index : Vector3i in footprint:
		if grid[cell_index].type == Layout.CELL_TYPE.EDGE:
			grid[cell_index].profiles = _resolved_profiles_for(cell_index)

	for cell_index : Vector3i in footprint:
		var cell : Cell = grid[cell_index]
		if cell.instanced_module != null:
			displaced.append(cell.instanced_module)
			cell.instanced_module.queue_free()
			cell.instanced_module = null
		cell.module_reference = null
		cell.tile_kind = Layout.TILE_KIND.NONE
		cell.possibilities.clear()
		cell.landmark = landmark

	landmarks.append(landmark)
	landmark_formed_today = true
	print("merged landmark: ", landmark.landmark_id, " over ", footprint.size(), " cells")
	return displaced

# The profiles a cell would commit to if it were collapsed now, without spawning anything -
# used by merge_landmark(), where the module would only be created to be freed a moment later.
# Mirrors the narrowing half of collapse(), including its arbitrary pick when several
# possibilities survive.
func _resolved_profiles_for(cell_index : Vector3i) -> Dictionary[String, Layout.PROFILE_TYPE]:
	var cell : Cell = grid[cell_index]
	var target := get_settled_profiles_for_cell(cell_index)
	for poss : Possibility in cell.initial_possibilities:
		if do_profiles_match(poss.profiles, target):
			return poss.profiles.duplicate()
	# Nothing fits - keep whatever is there rather than inventing a border, same as the
	# contradiction path in collapse() leaves the existing module alone.
	printerr("merge_landmark: no module fits footprint edge ", cell_index,
		" against ", target, "; keeping its current profiles")
	return cell.profiles

# ------------------------------------------------------------------------

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
	cell.module_reference = poss.module_reference

# True if this module can seat on this cell at this rotation. A cell already holding a
# module is NOT a rejection - placements always target corners, and dropping a new corner
# onto an existing one is how water replaces land. The surrounding edges and faces are the
# ones that have to reconcile the new corner with its neighbours, and they do that by
# re-collapsing in _soft_populate_ring(); a corner itself is only rejected when the module
# can't seat on this cell type/rotation at all.
func does_module_fit(cell_index : Vector3i, module : Module, rotation : int) -> bool:
	var possibility : Possibility = get_fitting_possibility(cell_index, module, rotation)
	if possibility != null:
		return true
	else:
		return false
		
# Resolves module_id + rotation to this cell's precomputed Possibility. Searches
# initial_possibilities, not the narrowed possibilities list: whether a module can seat on a
# cell is a static property of the cell (type + base rotation), independent of whatever the
# cell currently happens to show. does_module_fit() runs in placement_manager's pass 1,
# before batch_place_modules() resets the cell, so searching the narrowed list would only
# ever return the module already sitting there - which is what blocked water from replacing
# an existing tile.
func get_fitting_possibility(cell_index : Vector3i, module : Module, rotation : int) -> Possibility:
	var cell : Cell = grid[cell_index]

	# A cell swallowed by a landmark is spent: nothing can be seated in it any more, so a
	# placement aimed at it fails does_module_fit() and the column stacks above it instead
	# (see _cell_occupies_surface).
	if cell.landmark != null:
		return null

	for possibility : Possibility in cell.initial_possibilities:
		if possibility.module_reference.module_id == module.module_id and possibility.module_rotation == posmod(rotation, 360):
			return possibility
	return null

# ------------------- helper functions -------------------

func get_hard_profiles_for_cell(cell_index: Vector3i) -> Dictionary[String, Layout.PROFILE_TYPE]:
	var cell = grid[cell_index]
	var hard_profiles : Dictionary[String, Layout.PROFILE_TYPE] = {}

	for border_key in cell.profiles.keys():
		var neighbor = cell.neighbors.get(border_key)
		# No neighbor at all means the border points off the map (see _get_map_border_key) -
		# as hard as a corner, and never changes: there is nothing out there but sky.
		if neighbor == null:
			hard_profiles[border_key] = MAP_BORDER_PROFILE
		elif neighbor.type == Layout.CELL_TYPE.CORNER:
			hard_profiles[border_key] = neighbor.profiles[border_key]
		else:
			hard_profiles[border_key] = Layout.PROFILE_TYPE.EMPTY

	return hard_profiles

# Same idea as get_hard_profiles_for_cell(), but also trusts a soft (EDGE) neighbor once it
# has a real committed module showing - not just hard corners. A neighbor
# counts as committed if: it's a corner, it has narrowed to exactly one possibility via
# collapse()/an arbitrary pick, OR it's still showing its untouched default filler (grass on
# the ground layer, AIR above it - see initialize_grass_layer()/initialize_air_layers()).
# That last case matters most: it's what makes a newly-placed corner's soft neighbors
# transition to AIR-compatible modules (FOREST_AIR, CLIFF_AIR, ...) when nothing else has
# been built nearby yet, instead of treating open air as an unconstrained EMPTY wildcard.
#
# FACE neighbors are always treated as unsettled (EMPTY), regardless of their current state.
# Propagation only ever flows CORNER -> EDGE -> FACE (see batch_place_modules): an edge must
# be serious about its corner neighbors (hard, upstream) but must NOT be blocked by whatever
# a face neighbor currently happens to show, since that face hasn't been resolved for this
# placement yet - it adapts to the edge in ring 2, not the other way around. Faces only ever
# have edge neighbors (never other faces), so this exclusion is a no-op when resolving a face.
func get_settled_profiles_for_cell(cell_index: Vector3i) -> Dictionary[String, Layout.PROFILE_TYPE]:
	var cell = grid[cell_index]
	var settled_profiles : Dictionary[String, Layout.PROFILE_TYPE] = {}

	for border_key in cell.profiles.keys():
		var neighbor = cell.neighbors.get(border_key)
		# Off the edge of the map (see get_hard_profiles_for_cell) - always committed, always AIR.
		if neighbor == null:
			settled_profiles[border_key] = MAP_BORDER_PROFILE
			continue
		var neighbor_committed = neighbor.type != Layout.CELL_TYPE.FACE and (
			neighbor.type == Layout.CELL_TYPE.CORNER
			or neighbor.landmark != null
			or neighbor.possibilities.size() == 1
			or neighbor.instanced_module != null
		)
		if neighbor_committed:
			settled_profiles[border_key] = neighbor.profiles[border_key]
		else:
			settled_profiles[border_key] = Layout.PROFILE_TYPE.EMPTY

	return settled_profiles
		
func get_neighbor_from_rot(cell_index : Vector3i, rot_degree : int) -> Vector3i:
	var cell = grid[cell_index]
	var neighbor_index : Vector3i
	var dir_to_neighbor : Vector3 = Layout.TILE_ROTATION_VALUE[rot_degree].normalized()
	for neighbor : Cell in cell.neighbors.values():
		var dir_to_neighbor_temp : Vector3 = (neighbor.axial_position - cell.axial_position).normalized()
		if dir_to_neighbor.dot(dir_to_neighbor_temp) > 0.9:
			neighbor_index = get_axial_index(neighbor.axial_position)
			return neighbor_index
	return MAP_BORDER_INDEX
	
func _get_border_index(a_index: Vector3i, b_index: Vector3i) -> String:
	var s1 = str(a_index)
	var s2 = str(b_index)
	return s1 + "_" + s2 if s1 < s2 else s2 + "_" + s1

# Border key for a direction that leaves the map. Keyed by the absolute direction, not by the
# missing neighbour, so a cell with more than one such border keeps them separate. Every
# possibility of a cell covers the same set of absolute directions (a module's border set is
# invariant under its own rotation step - 60 deg for corners, 180 for edges, 120 for faces), so
# these keys are stable across the cell's possibilities, exactly like a real neighbour's key.
func _get_map_border_key(cell_index : Vector3i, direction : int) -> String:
	return str(cell_index) + "_border_" + str(direction)
	
func round_rotation(value : float) -> int:
	return roundi(value / 30.0) * 30

func do_profiles_match(p1 : Dictionary[String, Layout.PROFILE_TYPE], p2 : Dictionary[String, Layout.PROFILE_TYPE]) -> bool:
	#print("match profiles", p1.values(), p2.values())
	for border_key : String in p1.keys():
		# p1 = candidate's own clockwise reading; p2 = value sourced from the neighbour
		# (its own reading), so compare against its mirror. reverse() is identity for
		# single-biome/EMPTY values, keeping old behaviour intact.
		var mine : Layout.PROFILE_TYPE = p1[border_key]
		var theirs : Layout.PROFILE_TYPE = p2[border_key]
		if mine == Layout.PROFILE_TYPE.EMPTY or theirs == Layout.PROFILE_TYPE.EMPTY:
			continue # unconstrained border - anything may meet it
		if mine == Layout.reverse(theirs):
			continue
		# A wildcard border accepts any of its members: that's how a raised tile's
		# cliff rim (SURFACE on its inward side) meets whatever biome sits on it.
		if Layout.matches_wildcard(mine, Layout.reverse(theirs)):
			continue
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
	
# ------------------- refactor below code -----------------


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

# True if a cell counts as "occupied" for stacking/placement targeting - derived from the
# module the cell currently shows, so it stays correct however that module got there
# (seeded, solved, placed, or replaced). Every cell always shows something: the ground layer
# is seeded with grass (solid) and the layers above with the geometry-less AIR placeholder
# (open space - see initialize_air_layers()), which is why instanced_module != null is not
# an occupancy signal but "the module isn't AIR" is.
func _cell_occupies_surface(cell : Cell) -> bool:
	# A merged landmark is solid ground: stack on top of it, never into it.
	if cell.landmark != null:
		return true
	if cell.module_reference == null:
		return false
	return cell.module_reference.module_id != AIR_MODULE_ID[cell.type]

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
# player is actually looking at/hovering over. Never null: the ground layer is seeded with
# grass, so layer 0 always counts as occupied.
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
	
# ------------------------------- refactor above code ------------------

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
	
