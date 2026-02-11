class_name CameraController extends Node3D

@export var path = camera

# variables
@export var floatyness : float = 0.1
@export var move_speed = 0.2
var move_target: Vector3

# rotation
@export var rotate_keys_speed = 1.5
var rotate_keys_target: float
@export var initial_pitch := -40.0

# zoom
@export var zoom_speed = 3.0 
@export var min_zoom = -7.0 
@export var max_zoom = 20.0
@export var min_zoom_speed = 0.15 # as % of max speed (max_speed = 1.0)
var zoom_target: float
@export var min_pitch := -75.0   # when zoomed out
@export var max_pitch :=  0.0   # when zoomed in

# mouse
@export var mouse_sensitivity = 0.3

@export var rotation_x: Node3D
@export var zoom_pivot: Node3D
@export var camera: Camera3D

# rotation
@export var pivot: Node3D
@export var raycast: RayCast3D

# spherecast
@export var spherecast: ShapeCast3D

# Easing
@export var move_speed_ease := 1.0
var current_move_speed := 0.0

# Reset to original Values (For the Playtest)
var _initial_values = {}
var _initial_transform: Transform3D
var _initial_rotation_x: Vector3
var _initial_zoom: float
var _initial_camera_position: Vector3

func _ready() -> void:
	move_target = position
	rotate_keys_target = rotation_degrees.y
	var initial_pitch_t := inverse_lerp(min_pitch, max_pitch, initial_pitch)
	initial_pitch_t = clamp(initial_pitch_t, 0.0, 1.0)
	zoom_target = lerp(max_zoom, min_zoom, initial_pitch_t)
	camera.position.z = zoom_target
	rotation_x.rotation_degrees.x = initial_pitch
	
	# _initial values for playtest
	_initial_transform = global_transform
	_initial_rotation_x = rotation_x.rotation_degrees
	_initial_zoom = camera.position.z
	_initial_values.min_zoom = min_zoom
	_initial_values.max_zoom = max_zoom
	_initial_values.min_pitch = min_pitch
	_initial_values.max_pitch = max_pitch
	_initial_values.zoom_speed = zoom_speed
	_initial_values.move_speed = move_speed
	_initial_camera_position = camera.position
	

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("rotate"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if Input.is_action_just_released("rotate"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# get input directions
	var input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var horizontal_basis = Basis(Vector3.UP, pivot.rotation.y)
	var movement_direction = (horizontal_basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	var rotate_keys_direction = Input.get_axis("rotate_left", "rotate_right")
	var zoom_direction = (int(Input.is_action_just_released("move_up")) - int(Input.is_action_just_released("move_down")))
	
	# spherecast to not zoome through the floor
	spherecast.force_shapecast_update()
	if zoom_direction < 0 and spherecast.is_colliding():
		zoom_direction = 0
	
	# normalize zoom range between 0 and 1
	var current_zoom = 1 - inverse_lerp(min_zoom, max_zoom, zoom_target)
	
	# set movement targets
	var zoom_move_factor = 1.0 - current_zoom + 0.2
	
	var target_speed = move_speed if input_direction != Vector2.ZERO else 0.0
	current_move_speed = lerp(
		current_move_speed,
		target_speed,
		move_speed_ease * _delta
	)
	
	move_target += current_move_speed * zoom_move_factor * movement_direction
	print(current_move_speed)
	#move_target += move_speed * zoom_move_factor * movement_direction
	
	# Zoom - fast in the middle, slow at edges
	var zoom_curve = 1.0 - abs(current_zoom - 0.5) * 2.0
	zoom_curve = clamp(zoom_curve, min_zoom_speed, 1.0)
	zoom_target += zoom_speed * zoom_direction * zoom_curve
	zoom_target = clamp(zoom_target, min_zoom, max_zoom)
	
	# lerp to movement targets
	position = lerp(position, move_target, floatyness)
	camera.position.z = lerp(camera.position.z, zoom_target, floatyness)
	spherecast.force_shapecast_update()
	if spherecast.is_colliding():
		var collider = spherecast.get_collider(0)
		if collider.collision_layer & (1 << 0):  
			camera.global_position.y = spherecast.get_collision_point(0).y + (spherecast.shape as SphereShape3D).radius
			zoom_target = camera.position.z
	
	# compute new pitch between min_pitch and max_pitch
	var target_pitch = lerp(min_pitch, max_pitch, current_zoom)
	
	# apply smoothed rotation
	rotation_x.rotation_degrees.x = lerp(
		rotation_x.rotation_degrees.x,
		target_pitch,
		floatyness
	)
	
	# raycast
	var pivot_y_target: float
	pivot_y_target = pivot.global_position.y
	raycast.force_raycast_update()
	if raycast.is_colliding():
		pivot_y_target = raycast.get_collision_point().y
		pivot.global_position.y = lerp(
			pivot.global_position.y,
			pivot_y_target,
			floatyness
		)
		
	# pivot rotation
	if rotate_keys_direction != 0:
		pivot.rotate_y(rotate_keys_speed * rotate_keys_direction * _delta)

# -----------------------------------------------------
# Playtest Value sliders - not really needed afterwards
# -----------------------------------------------------
@onready var min_zoom_label = $"../Playtest UI/MinZoom/value"
@onready var max_zoom_label = $"../Playtest UI/MaxZoom/value"
@onready var min_pitch_label = $"../Playtest UI/MinPitch/value"
@onready var max_pitch_label = $"../Playtest UI/MaxPitch/value"
@onready var zoom_speed_label = $"../Playtest UI/ZoomSpeed/value"
@onready var move_speed_label = $"../Playtest UI/MoveSpeed/value"

func reset_camera_values():
	global_transform = _initial_transform
	rotation_x.rotation_degrees = _initial_rotation_x
	camera.position.z = _initial_zoom
	zoom_target = _initial_zoom
	camera.position = _initial_camera_position
	
	min_zoom = _initial_values.min_zoom
	max_zoom = _initial_values.max_zoom
	min_pitch = _initial_values.min_pitch
	max_pitch = _initial_values.max_pitch
	zoom_speed = _initial_values.zoom_speed
	move_speed = _initial_values.move_speed
	
	$"../Playtest UI/MinZoom".value = min_zoom
	$"../Playtest UI/MaxZoom".value = max_zoom
	$"../Playtest UI/MinPitch".value = min_pitch
	$"../Playtest UI/MaxPitch".value = max_pitch
	$"../Playtest UI/ZoomSpeed".value = zoom_speed
	$"../Playtest UI/MoveSpeed".value = move_speed


func camera_set_min_zoom(value: float):
	min_zoom = value
	min_zoom_label.text = str(value)

func camera_set_max_zoom(value: float):
	max_zoom = value
	max_zoom_label.text = str(value)

func camera_set_min_pitch(value: float):
	min_pitch = value
	min_pitch_label.text = str(value)

func camera_set_max_pitch(value: float):
	max_pitch = value
	max_pitch_label.text = str(value)
	
func camera_set_zoom_speed(value: float):
	zoom_speed = value
	zoom_speed_label.text = str(value)

func camera_set_move_speed(value: float):
	move_speed = value
	move_speed_label.text = str(value)
