extends Node

var balancing_data: Dictionary = {}
var balancing_file_path = "res://Files/balance.json"

const SAVE_FILE_PATH := "res://Files/temp.json"
# Bumped whenever the record layout below changes, so a loader can refuse a file it predates.
const SAVE_VERSION := 1
var load_file_path : String
const AUTOSAVE_FILE_PATH := "res://Files/autosave.json"
const SAVEGAME_1_PATH := "res://Files/savegame1.json"
const SAVEGAME_2_PATH := "res://Files/savegame2.json"
const SAVEGAME_3_PATH := "res://Files/savegame3.json"

func _ready():
	load_balance()
	# Every placement ends with this signal (see placement_manager._spawn_instance), which is
	# also the point where the propagation wave and any landmark merge have finished - so the
	# board is consistent and the snapshot is worth taking.
	Signals.on_instance_spawned.connect(save_state)
	load_file_path = AUTOSAVE_FILE_PATH

func _input(event):
	if event.is_action_pressed("reload_files"):
		reload_files()

func load_balance():
	if not FileAccess.file_exists(balancing_file_path):
		print("Balance file not found")
		return
	
	var balance_file = FileAccess.open(balancing_file_path, FileAccess.READ)
	balancing_data = JSON.parse_string(balance_file.get_as_text())

func reload_files():
	load_balance()
	print("reloaded")

#-------------------------------- save game ----------------------------

# Writes the whole board to SAVE_FILE_PATH
func save_state() -> void:
	var landmark_records : Array = []
	# Index into landmark_records, so a cell can point at its landmark without repeating it.
	var landmark_slots : Dictionary = {}
	for landmark : Landmark in Grid.landmarks:
		landmark_slots[landmark] = landmark_records.size()
		landmark_records.append({
			"landmark_id": String(landmark.landmark_id),
			"scene": landmark.scene_file_path,
			"position": _vec3_to_array(landmark.global_position),
			# clockwise rotation
			"rotation": landmark.rotation_degrees.y,
			# merge_landmark() spawns a mirrored match with scale.x = -1.
			"mirrored": landmark.scale.x < 0.0,
			"seq": 0,
			"footprint": [],
		})

	var cell_records : Array = []
	for cell_index : Vector3i in Grid.grid.keys():
		var cell : Cell = Grid.grid[cell_index]
		var landmark_slot : int = landmark_slots.get(cell.landmark, -1)
		if landmark_slot != -1:
			landmark_records[landmark_slot]["footprint"].append(_vec3i_to_array(cell_index))
			landmark_records[landmark_slot]["seq"] = maxi(
				landmark_records[landmark_slot]["seq"], cell.placement_seq)
		var module_id : int = -1
		if cell.module_reference != null:
			module_id = cell.module_reference.module_id
		cell_records.append({
			"index": _vec3i_to_array(cell_index),
			"type": int(cell.type),
			"seq": cell.placement_seq,
			"tile_kind": int(cell.tile_kind),
			"module_id": module_id,
			# Grid space, clockwise. Grid.spawn_module() negates it to get rotation_degrees.y.
			"module_rotation": cell.module_rotation,
			"tile_scene": cell.tile_scene_path,
			"landmark": landmark_slot,
			"profiles": _profiles_to_dictionary(cell.profiles),
		})

	var save_data : Dictionary = {
		"version": SAVE_VERSION,
		# The highest round number in the file - i.e. how many steps the timelapse has to play.
		"placement_seq": Grid.placement_seq,
		"landmarks": landmark_records,
		"cells": cell_records,
	}

	var save_file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if save_file == null:
		printerr("save_state: could not open ", SAVE_FILE_PATH, " for writing (",
			error_string(FileAccess.get_open_error()), ")")
		return
	# Indented so the file stays diffable and readable while the format is still settling.
	save_file.store_string(JSON.stringify(save_data, "\t"))
	save_file.close()

# Keys are already plain strings (Grid._get_border_index) and values plain ints, but the dict
# is typed - Dictionary[String, Layout.PROFILE_TYPE] - and JSON.stringify wants an untyped one.
func _profiles_to_dictionary(profiles : Dictionary[String, Layout.PROFILE_TYPE]) -> Dictionary:
	var result : Dictionary = {}
	for border_key : String in profiles.keys():
		result[border_key] = int(profiles[border_key])
	return result

# JSON has no vector type, so both go out as three numbers. A cell index is Vector3i because it
# is the axial position times 100 (see Grid.get_axial_index) - keep it integral.
func _vec3i_to_array(v : Vector3i) -> Array:
	return [v.x, v.y, v.z]

func _vec3_to_array(v : Vector3) -> Array:
	return [v.x, v.y, v.z]

#-------------------------------- load game ----------------------------

func save_to_slot(target_path : String) -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("save_to_slot: no temp save file to copy from")
		return
	var err := DirAccess.copy_absolute(SAVE_FILE_PATH, target_path)
	print("Saved to slot ", target_path)
	if err != OK:
		printerr("save_to_slot: could not copy ", SAVE_FILE_PATH, " to ", target_path,
			" (", error_string(err), ")")

func load_state(path : String) -> void:
	if not FileAccess.file_exists(path):
		print("Save file not found ", path)
		return
	
	var save_file := FileAccess.open(path, FileAccess.READ)
	var save_data = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	
	if save_data == null or int(save_data.get("version", -1)) != SAVE_VERSION:
		printerr("load_state: missing or incompatible save file (expected version ", SAVE_VERSION, ")")
		return
	
	load_file_path = path
	Grid.placement_seq = int(save_data["placement_seq"])
	
	# Landmarks first
	var landmarks : Array[Landmark] = []
	for record in save_data["landmarks"]:
		var landmark : Landmark = load(record["scene"]).instantiate()
		Grid.add_child(landmark)
		
		landmark.landmark_id = StringName(record["landmark_id"])
		landmark.global_position = _array_to_vec3(record["position"])
		landmark.rotation_degrees.y = record["rotation"]
		if record["mirrored"]:
			landmark.scale.x = -1.0
		landmarks.append(landmark)
		Grid.landmarks.append(landmark)
		
	var tile_groups : Dictionary = {}
	for record in save_data["cells"]:
		if record["tile_scene"] != "":
			var key : String = str(int(record["seq"])) + "|" + record["tile_scene"]
			if not tile_groups.has(key):
				tile_groups[key] = []
			tile_groups[key].append(record)
			
	var handled : Dictionary = {}
	for key in tile_groups.keys():
		_load_tile_group(tile_groups[key], handled)
		
	for record in save_data["cells"]:
		var cell_index : Vector3i = _array_to_vec3i(record["index"])
		if handled.has(cell_index):
			continue
		_load_single_cell(cell_index, record, landmarks)


func _load_tile_group(records : Array, handled : Dictionary) -> void:
	var tile_scene_path : String = records[0]["tile_scene"]
	var tile_instance : Node3D = load(tile_scene_path).instantiate()
	get_tree().current_scene.add_child(tile_instance)
	
	var children : Array[Module] = []
	for child in tile_instance.get_children():
		if child is Module:
			children.append(child)
	
	for record in records:
		var cell_index : Vector3i = _array_to_vec3i(record["index"])
		var module_id : int = int(record["module_id"])
		var module_rotation : int = int(record["module_rotation"])
		
		var matched_child : Module = null
		for child : Module in children:
			if child.module_id == module_id:
				matched_child = child
				children.erase(child)
				break
		if matched_child == null:
			printerr("_load_tile_group: kein nubenutztes Kind mit module_id ", module_id, " in ", tile_scene_path, " für Zelle ", cell_index)
			continue
		
		var possibility := Grid.get_possibility_by_id(cell_index, module_id, module_rotation)
		if possibility == null:
			printerr("_load_tile_group: keine Possibility für module_id ", module_id, " bei Rotation ", module_rotation, " auf Zelle ", cell_index) 
			continue
		
		var cell : Cell = Grid.grid[cell_index]
		if cell.instanced_module != null:
			cell.instanced_module.queue_free()
			
		matched_child.global_position = Grid.axial_to_cartesian(cell.axial_position)
		matched_child.rotation_degrees.y = -module_rotation
		
		cell.possibilities = [possibility]
		cell.profiles = _dictionary_to_profiles(record["profiles"])
		cell.module_reference = matched_child
		cell.instanced_module = tile_instance
		cell.tile_kind = int(record["tile_kind"]) as Layout.TILE_KIND
		cell.module_rotation = module_rotation
		cell.tile_scene_path = tile_scene_path
		cell.placement_seq = int(record["seq"])
		
		handled[cell_index] = true


func _load_single_cell(cell_index : Vector3i, record : Dictionary, landmarks : Array[Landmark]) -> void:
	var cell : Cell = Grid.grid[cell_index]
	var landmark_slot : int = int(record["landmark"])
	
	if landmark_slot != -1:
		if cell.instanced_module != null:
			cell.instanced_module.queue_free()
			cell.instanced_module = null
		cell.landmark = landmarks[landmark_slot]
		cell.possibilities.clear()
		cell.module_reference = null
		cell.tile_kind = Layout.TILE_KIND.NONE
		cell.module_rotation = 0
		cell.tile_scene_path = ""
		cell.placement_seq = int(record["seq"])
		cell.profiles = _dictionary_to_profiles(record["profiles"])
		return
	
	var module_id : int = int(record["module_id"])
	if module_id == -1: # Should theoretically never happen
		return
	
	var module_rotation : int = int(record["module_rotation"])
	var possibility := Grid.get_possibility_by_id(cell_index, module_id, module_rotation)
	if possibility == null:
		printerr("_load_single_cell: Keine Possibility für module_id ", module_id, " bei Rotation ", module_rotation, " auf Zelle ", cell_index)
		return

	cell.possibilities = [possibility]
	cell.profiles = _dictionary_to_profiles(record["profiles"])
	cell.tile_kind = int(record["tile_kind"]) as Layout.TILE_KIND
	Grid.spawn_module(possibility, cell_index)
	cell.placement_seq = int(record["seq"])

func _array_to_vec3i(arr : Array) -> Vector3i:
	return Vector3i(int(arr[0]), int(arr[1]), int(arr[2]))
 
func _array_to_vec3(arr : Array) -> Vector3:
	return Vector3(arr[0], arr[1], arr[2])
 
func _dictionary_to_profiles(data : Dictionary) -> Dictionary[String, Layout.PROFILE_TYPE]:
	var result : Dictionary[String, Layout.PROFILE_TYPE] = {}
	for border_key : String in data.keys():
		result[border_key] = int(data[border_key]) as Layout.PROFILE_TYPE
	return result
