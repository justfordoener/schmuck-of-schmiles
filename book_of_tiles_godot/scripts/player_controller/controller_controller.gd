extends Node

var controller_sensitivity := 0.0
var controller_deadzone := 0.0
var controller_snap_radius := 0.0
var controller_snap_strength := 0.0 # 0.0 = no snap, 1.0 = instant snap

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_controller_variables()

func _input(event):
	if event.is_action_pressed("reload_files"):
		load_controller_variables()

func _physics_process(_delta: float) -> void:
	if Input.is_action_pressed("controller_camera_mode"):
		return
	
	var joystick_movement = Vector2(
		Input.get_axis("controller_mouse_left", "controller_mouse_right"),
		Input.get_axis("controller_mouse_up", "controller_mouse_down")
	)
	
	if joystick_movement.length() > controller_deadzone:
		var current_position = get_viewport().get_mouse_position()
		var new_position = current_position + joystick_movement * controller_sensitivity
		
		var nearest = _get_nearest_ui(new_position)
		if nearest:
			new_position = new_position.lerp(nearest, controller_snap_strength)
		Input.warp_mouse(new_position)
	
	if Input.is_action_just_pressed("controller_mouse_click"):
		_simulate_mouse_click(true)
	if Input.is_action_just_released("controller_mouse_click"):
		_simulate_mouse_click(false)

func _simulate_mouse_click(pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = get_viewport().get_mouse_position()
	Input.parse_input_event(event)

func _get_nearest_ui(position: Vector2) -> Variant:
	var nearest_position = null
	var nearest_distance = controller_snap_radius
	
	for node in get_tree().get_nodes_in_group("snappable_ui"):
		if node is Control and node.visible:
			var center = node.get_global_rect().get_center()
			var distance = position.distance_to(center)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_position = center
	
	return nearest_position

func load_controller_variables():
	controller_sensitivity   = FileManager.balancing_data["controller_controller"]["controller_sensitivity"]
	controller_deadzone      = FileManager.balancing_data["controller_controller"]["controller_deadzone"]
	controller_snap_radius   = FileManager.balancing_data["controller_controller"]["controller_snap_radius"]
	controller_snap_strength = FileManager.balancing_data["controller_controller"]["controller_snap_strength"]
