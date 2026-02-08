extends Node3D

@onready var main_manager : MainManager = $".."
@onready var camera_controller : CameraController = $"../CameraController"

var preview_instance : Node3D
var current_tile : PackedScene
var camera : Camera3D
var tiles_placed_today : Array[Node3D] = []
var plane : Plane


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
		preview_instance.global_position = Grid.snap_to_layer(hit, preview_instance.layer_type)
		if Input.is_action_just_pressed("mouse_wheel_down"):
			preview_instance.rotate_y(deg_to_rad(60))
			preview_instance.tile_rotation = _round_rotation(preview_instance.rotation_degrees.y)
		if Input.is_action_just_pressed("mouse_wheel_up"):
			preview_instance.rotate_y(deg_to_rad(-60))
			preview_instance.tile_rotation = _round_rotation(preview_instance.rotation_degrees.y)
		if Input.is_action_just_pressed("mouse_left"):
			_spawn_instance(preview_instance.global_position, preview_instance.rotation.y)
			Signals.on_instance_spawned.emit()

func _round_rotation(value : float) -> int:
	return int(ceil(value / 60.0) * 60.0) + 120
	
func _spawn_instance(_position: Vector3, _rotation : float):
	var instance = current_tile.instantiate()
	get_tree().current_scene.add_child(instance)
	tiles_placed_today.append(instance)
	instance.global_position = _position
	instance.global_rotation.y = _rotation
	for child in instance.get_children():
		if child is Module:
			pass
	preview_instance.queue_free()
	
	
func _is_mouse_over_ui_rect(mouse_pos : Vector2) -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.get_global_rect().has_point(mouse_pos)
	
