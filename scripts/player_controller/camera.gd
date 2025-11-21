extends Node3D

@export var move_speed: float 		= 20.0
@export var rotation_speed: float 	= 120  # Degrees per second
@export var smoothness: float 		= 5.0       # Higher = faster interpolation
@export var zoom_speed: float 		= 3.0
@export var min_y: float			= 1
@export var max_y: float			= 5
@onready var camera: Node			= $Camera3D

var _target_position: Vector3 		= Vector3.ZERO
var _target_position_y: float 		= 0.0
var _target_rotation_y: float 		= 0.0
var _target_rotation_x: float 		= 45.0

func _ready():
	_target_position = global_position
	_target_rotation_y = rotation_degrees.y
	_target_rotation_x = rotation_degrees.x
	
func _process(delta):
	handle_input(delta)
	smooth_update(delta)

func smooth_update(delta):
	global_position = global_position.lerp(_target_position, delta * smoothness)
	rotation_degrees.y = lerp_angle(_target_rotation_y, _target_rotation_y, delta * smoothness)
	camera.position.y = lerp(camera.position.y, _target_position_y, delta * smoothness)
	
	
func handle_input(delta):
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		var move_dir = transform.basis * input_dir
		move_dir.y = 0
		_target_position += move_dir * move_speed * delta
	
	if Input.is_action_pressed("rotate_left"):
		_target_rotation_y -= rotation_speed * delta
	if Input.is_action_pressed("rotate_right"):
		_target_rotation_y += rotation_speed * delta
	
	var zoom_direction = (int(Input.is_action_just_released("move_up")) - int(Input.is_action_just_released("move_down")))
	_target_position_y += zoom_speed * zoom_direction
	_target_position_y = clamp(_target_position_y, min_y, max_y)
