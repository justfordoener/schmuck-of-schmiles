extends Node3D

@onready var main_manager : MainManager = $".."
@onready var camera_controller : CameraController = $"../CameraController"

var preview_instance : Node3D
var current_tile : PackedScene
var camera : Camera3D
var tiles_placed_today : Array[Node3D] = []
var plane : Plane
var previous_position : Vector3 = Vector3.ZERO

func undo_last_placement() -> void:
	var tile : Node3D = tiles_placed_today.pop_back()
	if tile:
		tile.queue_free()

func place_tile(tile : PackedScene) -> void:
	_create_preview_instance(tile)

func _ready() -> void:
	camera = camera_controller.camera
	plane = Plane(Vector3.UP, 0)
	
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
		var snap_position = Grid.snap_position(hit, preview_instance.layer_type)
		var base_rotation = Grid.get_rotation_value(preview_instance.layer_type)
		preview_instance.global_position = snap_position
		if snap_position != previous_position:
			previous_position = snap_position
			preview_instance.rotation.y = deg_to_rad(Grid.snap_rotation(snap_position, preview_instance.layer_type))
		if Input.is_action_just_pressed("mouse_wheel_down"):
			preview_instance.rotate_y(deg_to_rad(base_rotation))
		if Input.is_action_just_pressed("mouse_wheel_up"):
			preview_instance.rotate_y(deg_to_rad(-base_rotation))
		if Input.is_action_just_pressed("mouse_left"):
			_spawn_instance(snap_position, preview_instance.rotation.y)

func _round_rotation(value : float) -> int:
	return roundi(value / 30.0) * 30
	
func _spawn_instance(instance_position: Vector3, instance_rotation : float):
	var instance = current_tile.instantiate()
	get_tree().current_scene.add_child(instance)
	tiles_placed_today.append(instance)
	instance.global_position = instance_position
	instance.global_rotation.y = instance_rotation
	for child in instance.get_children():
		if child is Module:
			Grid.link_module_to_cell(child, child.global_position, _round_rotation(rad_to_deg(instance_rotation)))
	preview_instance.queue_free()
	Grid.propagation_stack = []
	Grid.propagate(Grid.cartesian_to_axial(instance_position))
	
func _is_mouse_over_ui_rect(mouse_pos : Vector2) -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.get_global_rect().has_point(mouse_pos)
	
