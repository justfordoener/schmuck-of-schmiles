extends Node3D

const BEAVER_SCENE : PackedScene = preload("res://scenes/beaver.tscn")
# How often a placed beaver lodge comes with a beaver living on it.
const BEAVER_SPAWN_CHANCE : float = 1.0

@onready var main_manager : MainManager = $".."
@onready var camera_controller : CameraController = $"../CameraController"

var preview_instance : Node3D
var current_tile : PackedScene
var camera : Camera3D
var tiles_placed_today : Array[Node3D] = []
var plane : Plane
var previous_position : Vector3 = Vector3.ZERO
var saved_rotation : float
var mouse_press_time : float
var mouse_max_action_time : float # time how long you need to hold the left button down without placing the tile
# True once a left-press has been seen over the grid while this preview was already up.
# Only such a press may be completed into a placement - see _process().
var press_started_on_grid : bool = false

func undo_last_placement() -> void:
	var tile : Node3D = tiles_placed_today.pop_back()
	if tile:
		tile.queue_free()

func place_tile(tile : PackedScene) -> void:
	ControllerSupport.placing_mode = true
	press_started_on_grid = false
	_create_preview_instance(tile)

func _ready() -> void:
	camera = camera_controller.camera
	plane = Plane(Vector3.UP, 0)
	load_mouse_variables()

func _input(event):
	if event.is_action_pressed("reload_files"):
		load_mouse_variables()

func load_mouse_variables():
	mouse_max_action_time = FileManager.balancing_data["mouse_controller"]["mouse_max_action_time"]
	
func _create_preview_instance(tile : PackedScene) -> void:
	current_tile = tile
	preview_instance = tile.instantiate()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.flags_transparent = true
	for child in preview_instance.get_children():
		if child is MeshInstance3D:
			child.material_override = material
	add_child(preview_instance)
	
func _process(_delta):
	if !preview_instance:
		return
	if !camera:
		push_warning("WARNING: camera_path is not assigned.")
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	preview_instance.visible = not _is_mouse_over_ui_rect(mouse_pos)
	var hit = plane.intersects_ray(ray_origin, ray_dir)
	if hit != null:
		var target_cell = Grid.snap_to_cell(hit, preview_instance.layer_type, preview_instance.is_water)
		if target_cell == null:
			return
		var snap_position = Grid.axial_to_cartesian(target_cell.axial_position)
		var base_rotation = Grid.get_rotation_value(preview_instance.layer_type)
		preview_instance.global_position = snap_position
		if snap_position != previous_position:
			previous_position = snap_position
			preview_instance.rotation.y = deg_to_rad(target_cell.base_rotation)
			preview_instance.rotate_y(saved_rotation)
		
		if Input.is_action_just_pressed("rotate_key_down"):
			preview_instance.rotate_y(deg_to_rad(base_rotation))
			saved_rotation = deg_to_rad(base_rotation)
		if Input.is_action_just_pressed("rotate_key_up"):
			preview_instance.rotate_y(deg_to_rad(-base_rotation))
			saved_rotation = deg_to_rad(-base_rotation)
		if Input.is_action_pressed("mouse_left"):
			if Input.is_action_just_pressed("mouse_wheel_down"):
				preview_instance.rotate_y(deg_to_rad(base_rotation))
				saved_rotation = deg_to_rad(base_rotation)
			if Input.is_action_just_pressed("mouse_wheel_up"):
				preview_instance.rotate_y(deg_to_rad(-base_rotation))
				saved_rotation = deg_to_rad(-base_rotation)
		# A click places a tile only if BOTH halves of it landed on the grid with this
		# preview already up. The tile card is a TextureButton, which emits `pressed` on
		# mouse *release*, so the release that selects a card arrives in the same frame the
		# preview is created - and its press happened before there was anything to place.
		# Requiring a matching press is what rejects it: the duration test alone couldn't,
		# because mouse_press_time was still holding the press from the previous placement,
		# which reads as a short click whenever the player picks their next card quickly.
		if Input.is_action_just_pressed("mouse_left") and not _is_mouse_over_ui_rect(mouse_pos):
			mouse_press_time = Time.get_ticks_msec() / 1000.0
			press_started_on_grid = true

		if Input.is_action_just_released("mouse_left"):
			var hold_duration = Time.get_ticks_msec() / 1000.0 - mouse_press_time
			if press_started_on_grid and hold_duration < mouse_max_action_time:
				_spawn_instance(preview_instance.global_position, preview_instance.rotation.y)
			press_started_on_grid = false

func _spawn_instance(instance_position: Vector3, instance_rotation : float) -> void:
	var instance = current_tile.instantiate()
	get_tree().current_scene.add_child(instance)
	tiles_placed_today.append(instance)
	instance.global_position = instance_position
	instance.rotation.y = instance_rotation
	
	var module_placements = []
	
	# Pass 1: Check if all children are allowed and gather their placement data
	for child : Module in instance.get_children():
		var child_position = Grid.snap_position(child.global_position, child.module_type, instance.is_water)
		var child_index = Grid.get_axial_index(Grid.cartesian_to_axial(child_position))
		var child_rotation = -Grid.round_rotation(rad_to_deg(instance_rotation + child.rotation.y))
		
		if not Grid.does_module_fit(child_index, child, child_rotation):
			print("failed child: ", child.module_type, child_index, child_rotation, " ", child_position)
			# Clean up if even a single module of the tile fails
			instance.queue_free()
			tiles_placed_today.pop_back() 
			ControllerSupport.placing_mode = false
			GameState.change_state(GameState.State.TILE_CHOOSING)
			return
			
		module_placements.append({
			"index": child_index,
			"module": child,
			"rotation": child_rotation,
			"instance": instance
		})

	# Pass 2: If everything fits, batch place them and trigger WFC propagation once
	var displaced := Grid.batch_place_modules(module_placements)

	# Placing into an occupied cell frees whatever was there (see batch_place_modules). If
	# that was an earlier tile - water dropped onto land - drop it from the undo history so
	# undo doesn't spend a press on a node that's about to be deleted. Displaced solver-spawned
	# filler modules were never in the list, so erasing them is a no-op.
	for tile : Node3D in displaced:
		tiles_placed_today.erase(tile)

	# Rolled here and not in hex_beaver.tscn because _create_preview_instance() puts the
	# preview in the tree too, so a _ready() roll would populate the translucent ghost as
	# well - with an opaque beaver, since the ghost material is only applied to the preview
	# root's own MeshInstance3D children - and would disagree with what the placement does.
	# `displaced` is also what tells us the tile survived: a placement that completes the
	# beaver village recipe is eaten by the landmark merge inside batch_place_modules().
	if not displaced.has(instance):
		_try_spawn_beaver(instance)

	preview_instance.queue_free()
	Signals.on_instance_spawned.emit()
	
	ControllerSupport.placing_mode = false
	GameState.change_state(GameState.State.TILE_CHOOSING)
	
# Parents the beaver to the tile's corner module rather than to the tile root, so its patrol
# loop is centred on the hexagon whose rim it walks, whatever else the tile carries. Being a
# child of the tile is what gets it freed for free by undo, by a water tile dropped on top of
# it, and by a landmark merge - all three go through the tile node.
func _try_spawn_beaver(instance : Node3D) -> void:
	if instance.tile_kind != Layout.TILE_KIND.BEAVER:
		return
	if randf() >= BEAVER_SPAWN_CHANCE:
		return
	for child : Node in instance.get_children():
		if child is Module and child.module_type == Layout.CELL_TYPE.CORNER:
			child.add_child(BEAVER_SCENE.instantiate())
			return

func _is_mouse_over_ui_rect(mouse_pos : Vector2) -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.get_global_rect().has_point(mouse_pos)
	
