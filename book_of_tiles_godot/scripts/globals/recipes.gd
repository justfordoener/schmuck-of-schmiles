extends Node
# Recipe detection: spots the tile constellations from book-of-tiles_recipes.pdf and reports
# them so Grid can merge them into one landmark.
#
# A recipe lives on the landmark scene it produces (see scripts/grid/landmarks/landmark.gd),
# the same way a module's border profiles live on the module scene - so this loads a
# directory of scenes exactly like Grid._load_modules_from_dir() does.

var landmarks : Array[PackedScene] = []
# One instance of each landmark scene, kept out of the tree and parallel to `landmarks`.
# find_match() runs on every placement and only needs to read a recipe's slots, so reading
# them off a template avoids instantiating the landmark's geometry each time.
var recipes : Array[Landmark] = []
var landmark_directory : String = "res://scenes/landmarks/"

func _ready() -> void:
	_load_landmarks_from_dir(landmark_directory)

func _exit_tree() -> void:
	# The templates are Nodes held outside the tree, so nothing else will free them.
	for template : Landmark in recipes:
		template.free()
	recipes.clear()

# Looks for a recipe completed by the corner that was just placed. Anchoring the search on
# that corner is what keeps it cheap and correct: a pattern that didn't match before this
# placement must contain the new tile, so only placements involving it need testing -
# slots x 6 rotations per recipe, not a sweep of the grid.
#
# Returns {} when nothing matched, otherwise:
#   {"scene": PackedScene, "corners": Array[Vector3i], "rotation": int (degrees)}
# with "corners" in slot order, so corners[0] is whatever the recipe lists first.
func find_match(anchor_index : Vector3i) -> Dictionary:
	if not Grid.grid.has(anchor_index):
		return {}
	if Grid.grid[anchor_index].type != Layout.CELL_TYPE.CORNER:
		return {}

	for recipe_index : int in range(recipes.size()):
		var landmark : Landmark = recipes[recipe_index]
		var rotation_steps : int = 6 if landmark.allow_rotation else 1
		var found := {}

		for anchor_slot : int in range(landmark.slots.size()):
			for step : int in range(rotation_steps):
				var corners := _resolve_slots(landmark, anchor_slot, step, anchor_index)
				if corners.is_empty():
					continue
				found = {
					"scene": landmarks[recipe_index],
					"corners": corners,
					"rotation": step * 60,
				}
				break
			if not found.is_empty():
				break

		if not found.is_empty():
			return found

	return {}

# Places every slot on the grid with `anchor_slot` sitting on `anchor_index`, rotated by
# `step` * 60 degrees, and checks each one. Returns the resolved corner indices in slot
# order, or [] if any slot doesn't fit.
func _resolve_slots(landmark : Landmark, anchor_slot : int, step : int, anchor_index : Vector3i) -> Array[Vector3i]:
	var empty : Array[Vector3i] = []
	var corners : Array[Vector3i] = []
	var origin : Vector3i = landmark.slots[anchor_slot].offset
	var anchor_axial : Vector3 = Grid.grid[anchor_index].axial_position

	for slot : LandmarkSlot in landmark.slots:
		var offset : Vector3i = _rotate_offset(slot.offset - origin, step)
		# Corner columns sit two axial units apart (see Grid.axial_ring(center, 1, 2)), so a
		# one-corner step in x/z is two axial units; y is already one unit per layer.
		var cell_index : Vector3i = Grid.get_axial_index(anchor_axial + Vector3(
			offset.x * 2, offset.y, offset.z * 2))

		if not Grid.grid.has(cell_index):
			return empty # off the edge of the map
		var cell : Cell = Grid.grid[cell_index]
		if cell.type != Layout.CELL_TYPE.CORNER:
			return empty
		if cell.landmark != null:
			return empty # already spent on another landmark
		if cell.tile_kind != slot.tile_kind:
			return empty
		corners.append(cell_index)

	return corners

# Rotates a corner-space offset by `step` * 60 degrees clockwise. Layout.AXIAL_DIRECTION is
# a standard axial basis (q = x, r = z, with the implied s = -q - r), where one 60 degree
# turn is (q, r, s) -> (-r, -s, -q). Six steps is the identity.
func _rotate_offset(offset : Vector3i, step : int) -> Vector3i:
	var q : int = offset.x
	var r : int = offset.z
	for i in range(posmod(step, 6)):
		var s : int = -q - r
		var new_q : int = -r
		q = new_q
		r = -s
	return Vector3i(q, offset.y, r)

func _load_landmarks_from_dir(path : String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		printerr("Failed to open landmark directory: ", path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if !dir.current_is_dir():
			# Same export fix as Grid._load_modules_from_dir(): strip the .remap/.import
			# suffixes an export adds, and only take scenes.
			var clean_path = path + "/" + file_name.replace(".remap", "").replace(".import", "")
			if clean_path.ends_with(".tscn"):
				var res = load(clean_path)
				if res is PackedScene:
					var template = res.instantiate()
					if template is Landmark:
						landmarks.append(res)
						recipes.append(template)
						print("Successfully loaded landmark: ", clean_path)
					else:
						printerr("Not a Landmark scene, skipping: ", clean_path)
						template.queue_free()
		file_name = dir.get_next()
	dir.list_dir_end()
