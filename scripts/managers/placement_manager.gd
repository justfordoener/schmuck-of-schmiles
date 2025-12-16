extends Node3D

#WARNING needs CameraController node to be located above the GridManager node.
#TODO fix this fragile dependency
@onready var camera_controller = $"../CameraController"

var preview_instance : Node3D
var current_tile : PackedScene
var camera : Camera3D
var tiles_placed_today : Array[Node3D] = []

func undo_last_placement() -> void:
	var tile : Node3D = tiles_placed_today.pop_back()
	if tile:
		tile.queue_free()

func place_tile(tile : PackedScene) -> void:
	_create_preview_instance(tile)

func _ready() -> void:
	camera = camera_controller.camera
	
	
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
	var plane = Plane(Vector3.UP, 0)
	preview_instance.visible = not _is_mouse_over_ui_rect(mouse_pos)
	var hit = plane.intersects_ray(ray_origin, ray_dir)
	if hit != null:
		preview_instance.global_position = Grid.snap_to_face_layer(hit, preview_instance.tile_rotation)
		if Input.is_action_just_pressed("mouse_wheel_down"):
			preview_instance.rotate_y(deg_to_rad(60))
			preview_instance.tile_rotation = _round_rotation(preview_instance.rotation_degrees.y)
		if Input.is_action_just_pressed("mouse_wheel_up"):
			preview_instance.rotate_y(deg_to_rad(-60))
			preview_instance.tile_rotation = _round_rotation(preview_instance.rotation_degrees.y)
		if Input.is_action_just_pressed("mouse_left"):
			_spawn_instance(preview_instance.global_position, preview_instance.rotation.y)

func _round_rotation(value : int) -> int:
	return int(ceil(value / 60.0) * 60.0) + 120
	
func _spawn_instance(position: Vector3, rotation : float):
	var instance = current_tile.instantiate()
	get_tree().current_scene.add_child(instance)
	tiles_placed_today.append(instance)
	instance.global_position = position
	instance.global_rotation.y = rotation
	for child in instance.get_children():
		if child is Module:
			pass
	preview_instance.queue_free()
	
	
func _is_mouse_over_ui_rect(mouse_pos : Vector2) -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.get_global_rect().has_point(mouse_pos)
	
