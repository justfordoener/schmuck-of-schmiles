class_name CameraController extends Node3D

@export var path = camera
@export var rotation_x: Node3D
@export var camera: Camera3D

# variables
var floatyness : float = 0.0
var move_speed = 0.0
var move_target: Vector3

# rotation
@export var pivot: Node3D
@export var raycast: RayCast3D
var rotate_keys_speed = 0.0
var initial_pitch := 0.0
var rotate_ease := 0.0
var mouse_rotation_boost := 0.0
var rotate_keys_target: float
var drag_rotate_mode := false
var rotate_current_speed := 0.0

# zoom
var zoom_speed = 0.0 
var min_zoom = 0.0 
var max_zoom = 0.0
var min_zoom_speed = 0.0 # as % of max speed (max_speed = 1.0)
var zoom_target: float
var min_pitch := 0.0   # when zoomed out
var max_pitch :=  0.0   # when zoomed in
var controller_zoom_factor := 0.0 # to slow down zoom when using controller

# mouse
var mouse_sensitivity = 0.0
var controller_deadzone = 0.0

# drag movement
var drag_sensitivity := 0.0
var is_dragging := false
var drag_input := Vector2.ZERO

# spherecast
@export var spherecast: ShapeCast3D

# Easing
var move_speed_ease := 0.0
var current_move_speed := 0.0

# Reset to original Values (For the Playtest)
var _initial_values = {}
var _initial_transform: Transform3D
var _initial_rotation_x: Vector3
var _initial_zoom: float
var _initial_camera_position: Vector3

func _ready() -> void:
	load_camera_variables()
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


func _input(event):
	if event is InputEventMouseMotion and is_dragging:
		drag_input = event.relative
	if event.is_action_pressed("reload_files"):
		load_camera_variables()


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("rotate"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if Input.is_action_just_released("rotate"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# get input directions
	var input_direction = deadzone_vector("move_left", "move_right", "move_forward", "move_back")
	if is_dragging:
		var drag_vector = Vector2(-drag_input.x, -drag_input.y) * drag_sensitivity
		input_direction += drag_vector.limit_length(1.0)
	drag_input = Vector2.ZERO
	
	var horizontal_basis = Basis(Vector3.UP, pivot.rotation.y)
	var movement_direction = (horizontal_basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	var rotate_keys_direction = deadzone_axis("rotate_left", "rotate_right")
	var zoom_direction = (int(Input.is_action_just_released("move_up")) - int(Input.is_action_just_released("move_down")))
	
	if Input.is_action_pressed("controller_camera_mode"):
		rotate_keys_direction += deadzone_axis("controller_rotate_left", "controller_rotate_right")
		zoom_direction += deadzone_axis("controller_move_down", "controller_move_up") * controller_zoom_factor
	
	if drag_rotate_mode or Input.is_action_pressed("mouse_left"): # zoom turned off while rotate_mode is true and while the left mouse button is pressed
		zoom_direction = 0
	
	# drag movement
	var was_dragging = is_dragging
	is_dragging = Input.is_action_pressed("camera_drag")
	drag_rotate_mode = is_dragging
	
	if is_dragging and not was_dragging:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif not is_dragging and was_dragging:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# spherecast to not zoome through the floor
	spherecast.force_shapecast_update()
	if zoom_direction < 0 and spherecast.is_colliding():
		zoom_direction = 0
	
	# normalize zoom range between 0 and 1
	var current_zoom = 1 - inverse_lerp(min_zoom, max_zoom, zoom_target)
	
	# set movement targets
	var zoom_move_factor = 1.0 - current_zoom + 0.2
	
	# Easing movement
	var target_speed = move_speed if input_direction != Vector2.ZERO else 0.0
	if input_direction == Vector2.ZERO:
		current_move_speed = 0.0
	else:
		current_move_speed = lerp(
			current_move_speed,
			target_speed,
			move_speed_ease * _delta
		)
	
	move_target += current_move_speed * zoom_move_factor * movement_direction 
	
	# Zoom - fast in the middle, slow at edges
	var zoom_curve = 1.0 - abs(current_zoom - 0.5) * 2.0
	zoom_curve = clamp(zoom_curve, min_zoom_speed, 1.0)
	zoom_target += zoom_speed * zoom_direction * zoom_curve
	zoom_target = clamp(zoom_target, min_zoom, max_zoom)
	
	# lerp to movement targets
	position = lerp(position, move_target, floatyness * _delta * 60)
	camera.position.z = lerp(camera.position.z, zoom_target, floatyness * _delta * 60)
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
		floatyness * _delta * 60
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
	
	# rotation
	var rotate_input := 0.0
	if rotate_keys_direction != 0:
		rotate_input = rotate_keys_direction
	
	if drag_rotate_mode:
		var scroll_direction = (int(Input.is_action_just_released("move_down")) - int(Input.is_action_just_released("move_up")))
		rotate_input = scroll_direction * mouse_rotation_boost
	
	if rotate_input != 0.0:
		rotate_current_speed = lerp(rotate_current_speed, rotate_input * rotate_keys_speed, rotate_ease * _delta)
	else:
		rotate_current_speed = lerp(rotate_current_speed, 0.0,  rotate_ease * _delta)
	
	pivot.rotate_y(rotate_current_speed * _delta)
	

# deadzone to circumvent stick dragging with controller
func deadzone_axis(negative: String, positive: String) -> float:
	var value = Input.get_axis(negative, positive)
	return value if abs(value) > controller_deadzone else 0.0

# deadzone to circumvent stick dragging with controller
func deadzone_vector(left: String, right: String, up: String, down: String) -> Vector2:
	var value = Input.get_vector(left, right, up, down)
	return value if value.length() > controller_deadzone else Vector2.ZERO

func load_camera_variables():
	# camera, mouse, drag and easing
	floatyness             = FileManager.balancing_data["camera"]["floatyness"]
	move_speed             = FileManager.balancing_data["camera"]["move_speed"]
	mouse_sensitivity      = FileManager.balancing_data["camera"]["mouse_sensitivity"]
	drag_sensitivity       = FileManager.balancing_data["camera"]["drag_sensitivity"]
	move_speed_ease        = FileManager.balancing_data["camera"]["move_speed_ease"]
	
	# camera/rotation
	rotate_keys_speed      = FileManager.balancing_data["camera"]["rotation"]["rotate_keys_speed"]
	initial_pitch          = FileManager.balancing_data["camera"]["rotation"]["initial_pitch"]
	rotate_ease            = FileManager.balancing_data["camera"]["rotation"]["rotate_ease"]
	mouse_rotation_boost   = FileManager.balancing_data["camera"]["rotation"]["mouse_rotation_boost"]
	
	# camera/zoom
	zoom_speed             = FileManager.balancing_data["camera"]["zoom"]["zoom_speed"]
	min_zoom               = FileManager.balancing_data["camera"]["zoom"]["min_zoom"]
	max_zoom               = FileManager.balancing_data["camera"]["zoom"]["max_zoom"]
	min_zoom_speed         = FileManager.balancing_data["camera"]["zoom"]["min_zoom_speed"]
	min_pitch              = FileManager.balancing_data["camera"]["zoom"]["min_pitch"]
	max_pitch              = FileManager.balancing_data["camera"]["zoom"]["max_pitch"]
	controller_zoom_factor = FileManager.balancing_data["camera"]["zoom"]["controller_zoom_factor"]
	
	# controller_controller
	controller_deadzone    = FileManager.balancing_data["controller_controller"]["controller_deadzone"]

# -----------------------------------------------------
# Playtest Value sliders - not really needed afterwards
# -----------------------------------------------------
@onready var min_zoom_label = $"../UIManager/Playtest UI/MinZoom/value"
@onready var max_zoom_label = $"../UIManager/Playtest UI/MaxZoom/value"
@onready var min_pitch_label = $"../UIManager/Playtest UI/MinPitch/value"
@onready var max_pitch_label = $"../UIManager/Playtest UI/MaxPitch/value"
@onready var zoom_speed_label = $"../UIManager/Playtest UI/ZoomSpeed/value"
@onready var move_speed_label = $"../UIManager/Playtest UI/MoveSpeed/value"

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
	
	$"../UIManager/Playtest UI/MinZoom".value = min_zoom
	$"../UIManager/Playtest UI/MaxZoom".value = max_zoom
	$"../UIManager/Playtest UI/MinPitch".value = min_pitch
	$"../UIManager/Playtest UI/MaxPitch".value = max_pitch
	$"../UIManager/Playtest UI/ZoomSpeed".value = zoom_speed
	$"../UIManager/Playtest UI/MoveSpeed".value = move_speed


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
