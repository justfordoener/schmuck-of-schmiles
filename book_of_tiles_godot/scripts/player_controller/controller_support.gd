extends Node

var controller_sensitivity := 0.0
var controller_deadzone := 0.0
var controller_snap_radius := 0.0
var controller_snap_strength := 0.0 # 0.0 = no snap, 1.0 = instant snap

var controller_ui_mode = false
var current_node: Control = null
var placing_mode = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_controller_variables()

func _input(event):
	if event.is_action_pressed("reload_files"):
		load_controller_variables()
	
	if (event is InputEventMouseButton and event.pressed) or event is InputEventKey: #or (event is InputEventMouseMotion and event.relative.length() > 0):
		current_node = null
		controller_ui_mode = false
	
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		controller_ui_mode = true 
	
	if event.is_action_pressed("controller_next_ui") and placing_mode == false:
		_navigate_ui(Vector2.RIGHT, Vector2.DOWN)
	if event.is_action_pressed("controller_prev_ui") and placing_mode == false:
		_navigate_ui(Vector2.LEFT, Vector2.UP)


func _physics_process(_delta: float) -> void:
	if Input.is_action_pressed("controller_camera_mode"):
		return
	
	var joystick_movement = Vector2(
			Input.get_axis("controller_mouse_left", "controller_mouse_right"),
			Input.get_axis("controller_mouse_up", "controller_mouse_down")
		)

	var navigating = Input.is_action_just_pressed("controller_next_ui") or Input.is_action_just_pressed("controller_prev_ui")
	
	if (joystick_movement.length() > controller_deadzone or Input.is_action_pressed("controller_mouse_click")) and not navigating:
		current_node = null
		controller_ui_mode = true

	
	if current_node:
		if current_node.is_inside_tree() and current_node.visible and current_node.can_process() and current_node.is_visible_in_tree():
			Input.warp_mouse(get_viewport().get_final_transform() * current_node.get_global_rect().get_center())
		else:
			current_node = null
	else:
		if joystick_movement.length() > controller_deadzone:
			var current_position = get_viewport().get_mouse_position()
			var new_position = current_position + joystick_movement * controller_sensitivity
			
			var nearest = _get_nearest_ui(new_position)
			if nearest:
				new_position = new_position.lerp(nearest, controller_snap_strength)
			Input.warp_mouse(get_viewport().get_final_transform() * new_position)
		
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
	
	if placing_mode == false:
		for node in get_tree().get_nodes_in_group("snappable_ui"):
			if node is Control and node.visible and node.can_process():
				var center = node.get_global_rect().get_center()
				var distance = position.distance_to(center)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_position = center
	
	return nearest_position

# Navigate between UI Elements
func _navigate_ui(main_direction: Vector2, fallback_direction: Vector2) -> void:
	var nodes: Array[Control] = []
	for node in get_tree().get_nodes_in_group("snappable_ui"):
		if node is Control and node != current_node and node.is_inside_tree() and node.is_visible_in_tree() and node.can_process():
			nodes.append(node as Control)

	var origin := current_node.get_global_rect().get_center() if current_node else get_viewport().get_mouse_position()

	for direction in [main_direction, fallback_direction]:
		var best: Control = null
		var best_distance := INF
		for node in nodes:
			var to := node.get_global_rect().get_center() - origin
			if to.normalized().dot(direction) > 0.5:
				var distance := to.length_squared()
				if distance < best_distance:
					best_distance = distance
					best = node
		#print("direction: ", direction, " best: ", best, " at: ", best.get_global_rect().get_center() if best else "none")
		if best:
			current_node = best
			return

	# fallback: nothing in either cone, pick nearest overall
	var best_fallback: Control = null
	var best_diststance_fallback := INF
	for node in nodes:
		var distance_fallback := origin.distance_squared_to(node.get_global_rect().get_center())
		if distance_fallback < best_diststance_fallback:
			best_diststance_fallback = distance_fallback
			best_fallback = node
	#print("fallback result: ", best_fallback)
	current_node = best_fallback
	

func load_controller_variables():
	controller_sensitivity   = FileManager.balancing_data["controller_controller"]["controller_sensitivity"]
	controller_deadzone      = FileManager.balancing_data["controller_controller"]["controller_deadzone"]
	controller_snap_radius   = FileManager.balancing_data["controller_controller"]["controller_snap_radius"]
	controller_snap_strength = FileManager.balancing_data["controller_controller"]["controller_snap_strength"]
