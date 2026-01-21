class_name CameraController extends Node3D

@export var path = camera

# variables
@export var floatyness : float = 0.10
@export var move_speed = 0.6
var move_target: Vector3

# rotation
@export var rotate_keys_speed = 1.5
var rotate_keys_target: float

# zoom
@export var zoom_speed = 3.0
@export var min_zoom = -28.0 
@export var max_zoom = 10.0
@export var min_zoom_speed = 0.15 # as % of max speed (max_speed = 1.0)
var zoom_target: float
@export var min_pitch := -25.0   # when zoomed out
@export var max_pitch :=  10.0   # when zoomed in

# mouse
@export var mouse_sensitivity = 0.3

@onready var rotation_x = $CameraRotX
@onready var zoom_pivot = $CameraRotX/CameraZoomPivot
@onready var camera = $CameraRotX/CameraZoomPivot/Camera3D

# rotation
@onready var pivot_object = $"../pivot_object"
@onready var raycast = $CameraRotX/CameraZoomPivot/Camera3D/RayCast3D

func _ready() -> void:
	move_target = position
	rotate_keys_target = rotation_degrees.y
	zoom_target = camera.position.z
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("rotate"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if Input.is_action_just_released("rotate"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# get input directions
	var input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var horizontal_basis = Basis(Vector3.UP, deg_to_rad(rotation_degrees.y))
	var movement_direction = (horizontal_basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	var rotate_keys_direction = Input.get_axis("rotate_left", "rotate_right")
	var zoom_direction = (int(Input.is_action_just_released("move_up")) - int(Input.is_action_just_released("move_down")))
	
	# normalize zoom range between 0 and 1
	var current_zoom = 1 - inverse_lerp(min_zoom, max_zoom, zoom_target)
	
	# set movement targets
	var zoom_move_factor = 1.0 - current_zoom + 0.2
	move_target += move_speed * zoom_move_factor * movement_direction
	#rotate_keys_target += rotate_keys_speed * rotate_keys_direction
	
	# Zoom - fast in the middle, slow at edges
	var zoom_curve = 1.0 - abs(current_zoom - 0.5) * 2.0
	zoom_curve = clamp(zoom_curve, min_zoom_speed, 1.0)
	zoom_target += zoom_speed * zoom_direction * zoom_curve
	zoom_target = clamp(zoom_target, min_zoom, max_zoom)
	
	# lerp to movement targets
	position = lerp(position, move_target, floatyness)
	camera.position.z = lerp(camera.position.z, zoom_target, floatyness)
	
	# compute new pitch between min_pitch and max_pitch
	var target_pitch = lerp(min_pitch, max_pitch, current_zoom)
	
	# apply smoothed rotation
	rotation_x.rotation_degrees.x = lerp(
		rotation_x.rotation_degrees.x,
		target_pitch,
		floatyness
	)
	
	# raycast
	raycast.force_raycast_update()
	var raycast_hit_position: Vector3
	if raycast.is_colliding():
		raycast_hit_position = raycast.get_collision_point()
	else:
		raycast_hit_position = camera.global_transform.origin + camera.global_transform.basis.z * -zoom_target
	
	pivot_object.global_position = raycast_hit_position
	
	# pivot rotation
	if rotate_keys_direction != 0:
		pivot_object.rotate_y(rotate_keys_speed * rotate_keys_direction * _delta)
	

	var offset = camera.global_transform.origin - pivot_object.global_transform.origin
	offset = offset.rotated(Vector3.UP, rotate_keys_speed * rotate_keys_direction * _delta)
	camera.global_transform.origin = pivot_object.global_transform.origin + offset
	camera.look_at(pivot_object.global_transform.origin, Vector3.UP)
