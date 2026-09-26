extends Node3D

const BEAVER_SCENE : PackedScene = preload("res://scenes/beaver.tscn")
# How often a placed beaver lodge comes with a beaver living on it.
const BEAVER_SPAWN_CHANCE : float = 1.0

# Placement animation: the placed tile and every module the solver re-spawned around it start
# DROP_HEIGHT above their cell and fall into place one after another, clockwise around the
# tile, fading in as they go.
const DROP_HEIGHT : float = 20.0
const DROP_DURATION : float = 0.35
# Delay between one module starting its drop and the next.
const DROP_STAGGER : float = 0.03
const FADE_DURATION : float = 0.2

# Time (Time.get_ticks_msec() / 1000.0) at which the latest drop animation has fully landed.
var drop_end_time : float = 0.0

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
		# No cell means nothing can be placed here (column full, or its top can't be built
		# on - see Grid.snap_to_cell), so hide the ghost rather than leave it at the last spot.
		if target_cell == null:
			preview_instance.visible = false
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
	if not _build_tile(current_tile, instance_position, instance_rotation, true, true):
		ControllerSupport.placing_mode = false
		GameState.change_state(GameState.State.TILE_CHOOSING)
		return

	preview_instance.queue_free()
	Signals.on_instance_spawned.emit()
	
	ControllerSupport.placing_mode = false
	GameState.change_state(GameState.State.TILE_CHOOSING)

# Places a tile without the preview/click flow - used to pre-play a level's opening moves (see
# MainManager). It goes through the same targeting as the mouse (Grid.snap_to_cell), so a tile
# stacks or replaces exactly as it would for a player. Not added to the undo history: these
# are part of the starting map, not something the player can take back.
func place_tile_at(tile : PackedScene, world_position : Vector3, instance_rotation : float = 0.0) -> bool:
	var probe : Node3D = tile.instantiate()
	var target_cell := Grid.snap_to_cell(world_position, probe.layer_type, probe.is_water)
	probe.free()
	if target_cell == null:
		push_warning("place_tile_at: nothing can be placed at ", world_position)
		return false
	var instance_position := Grid.axial_to_cartesian(target_cell.axial_position)
	return _build_tile(tile, instance_position, instance_rotation + deg_to_rad(target_cell.base_rotation), false, true)

# Instances the tile into the scene and fits all its modules into the grid. Returns false if
# any module didn't fit, in which case nothing was placed. `undoable` puts the tile into the
# undo history, `animated` plays the drop-in animation (see _animate_drop).
func _build_tile(tile : PackedScene, instance_position: Vector3, instance_rotation : float, undoable : bool, animated : bool) -> bool:
	var instance = tile.instantiate()
	get_tree().current_scene.add_child(instance)
	if undoable:
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
			if undoable:
				tiles_placed_today.pop_back()
			return false
			
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
	for displaced_tile : Node3D in displaced:
		tiles_placed_today.erase(displaced_tile)

	# Rolled here and not in hex_beaver.tscn because _create_preview_instance() puts the
	# preview in the tree too, so a _ready() roll would populate the translucent ghost as
	# well - with an opaque beaver, since the ghost material is only applied to the preview
	# root's own MeshInstance3D children - and would disagree with what the placement does.
	# `displaced` is also what tells us the tile survived: a placement that completes the
	# beaver village recipe is eaten by the landmark merge inside batch_place_modules().
	if not displaced.has(instance):
		_try_spawn_beaver(instance)
	if animated:
		_animate_drop(instance, instance_position)
	return true

# Drops the placed tile first, then the modules the solver re-spawned around it (read back from
# Grid.spawned_modules), sorted clockwise by their direction from the tile. A tile swallowed by
# a landmark merge is already queued for deletion and is skipped, as is anything the same
# placement spawned and then replaced again.
func _animate_drop(instance : Node3D, center : Vector3) -> void:
	var order : Array[Node3D] = []
	if not instance.is_queued_for_deletion():
		order.append(instance)
	var ring : Array[Node3D] = []
	for module in Grid.spawned_modules:
		# AIR filler has no geometry - dropping it would only leave gaps in the sweep.
		if is_instance_valid(module) and not module.is_queued_for_deletion() and not _geometry_of(module).is_empty():
			ring.append(module)
	ring.sort_custom(func(a : Node3D, b : Node3D) -> bool:
		return _clockwise_angle(a.global_position - center) < _clockwise_angle(b.global_position - center))
	order.append_array(ring)
	for i in order.size():
		_drop_in(order[i], i * DROP_STAGGER)
	var end_time : float = Time.get_ticks_msec() / 1000.0 + (order.size() - 1) * DROP_STAGGER \
		+ maxf(DROP_DURATION, FADE_DURATION)
	drop_end_time = maxf(drop_end_time, end_time)

# Angle of `offset` seen from above, 0 at screen-up (-Z, with the camera unrotated) and growing
# clockwise through screen-right (+X).
func _clockwise_angle(offset : Vector3) -> float:
	return fposmod(atan2(offset.x, -offset.z), TAU)

# Lifts the node and hides it right away, so it stays out of sight while it waits its turn. The
# tween is created on the node itself, so it dies with it if the tile is undone or replaced
# mid-drop.
func _drop_in(node : Node3D, delay : float) -> void:
	var target : Vector3 = node.position
	node.position = target + Vector3.UP * DROP_HEIGHT
	var geometry := _geometry_of(node)
	for mesh : GeometryInstance3D in geometry:
		mesh.transparency = 1.0
	var tween := node.create_tween().set_parallel()
	tween.tween_property(node, "position", target, DROP_DURATION).set_delay(delay) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for mesh : GeometryInstance3D in geometry:
		tween.tween_property(mesh, "transparency", 0.0, FADE_DURATION).set_delay(delay)

func _geometry_of(node : Node) -> Array[GeometryInstance3D]:
	var geometry : Array[GeometryInstance3D] = []
	for child : Node in node.find_children("*", "GeometryInstance3D", true, false):
		geometry.append(child as GeometryInstance3D)
	return geometry
		
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
	
