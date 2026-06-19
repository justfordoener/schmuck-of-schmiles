extends Control

@export var action_buttons: Dictionary[String, Button]
@export var controller_action_buttons: Dictionary[String, Button]
@export var default_button : Button
@export var controller_settings : Node
@export var keyboard_settings : Node

var waiting_for_input := ""
var waiting_for_controller_input := ""
var controller_deadzone := 0.0
var default_key_events: Dictionary = {}
var default_controller_events: Dictionary = {}


func _ready():
	default_button.pressed.connect(reset_to_defaults)
	controller_deadzone = FileManager.balancing_data["controller_controller"]["controller_deadzone"]
	for action in action_buttons.keys():
		default_key_events[action] = get_first_key_event(action)
		action_buttons[action].pressed.connect(_on_action_button_pressed.bind(action))
	for action in controller_action_buttons.keys():
		default_controller_events[action] = get_first_controller_event(action)
		controller_action_buttons[action].pressed.connect(_on_controller_button_pressed.bind(action))
	update_buttons()
	
	ControllerSupport.controller_ui_mode_changed.connect(_on_controller_ui_mode_changed)
	_on_controller_ui_mode_changed(ControllerSupport.controller_ui_mode)

func _on_controller_ui_mode_changed(is_controller: bool) -> void:
	controller_settings.visible = is_controller
	keyboard_settings.visible = !is_controller

func reset_to_defaults():
	for action in default_key_events.keys():
		var old_event = get_first_key_event(action)
		if old_event:
			InputMap.action_erase_event(action, old_event)
		if default_key_events[action]:
			InputMap.action_add_event(action, default_key_events[action])

	for action in default_controller_events.keys():
		var old_event = get_first_controller_event(action)
		if old_event:
			InputMap.action_erase_event(action, old_event)
		if default_controller_events[action]:
			InputMap.action_add_event(action, default_controller_events[action])

	update_buttons()

func get_first_key_event(action: String) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event
	return null

func get_first_joypad_button_event(action: String) -> InputEventJoypadButton:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return event
	return null

func get_first_joypad_motion_event(action: String) -> InputEventJoypadMotion:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			return event
	return null

func get_first_controller_event(action: String) -> InputEvent:
	var e = get_first_joypad_button_event(action)
	if e:
		return e
	return get_first_joypad_motion_event(action)


func update_buttons():
	for action in action_buttons.keys():
		var button = action_buttons[action]
		var event = get_first_key_event(action)
		button.text = event.as_text() if event else "Unassigned"
		button.tooltip_text = button.text

	for action in controller_action_buttons.keys():
		var button = controller_action_buttons[action]
		var event = get_first_controller_event(action)
		button.text = event.as_text() if event else "Unassigned"
		button.tooltip_text = button.text

func _on_action_button_pressed(action: String):
	waiting_for_input = action
	action_buttons[action].text = "Press a key..."

func _on_controller_button_pressed(action: String):
	waiting_for_controller_input = action
	controller_action_buttons[action].text = "Press a button..."

func _input(event: InputEvent) -> void:
	# Keyboard
	if waiting_for_input != "":
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_DELETE or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				waiting_for_input = ""
				update_buttons()
			else:
				for other_action in action_buttons.keys():
					var existing = get_first_key_event(other_action)
					if existing and existing.keycode == event.keycode:
						InputMap.action_erase_event(other_action, existing)

			var old_event = get_first_key_event(waiting_for_input)
			if old_event:
				InputMap.action_erase_event(waiting_for_input, old_event)
			InputMap.action_add_event(waiting_for_input, event)

			waiting_for_input = ""
			update_buttons()

		elif event is InputEventKey and event.keycode == KEY_ESCAPE:
			waiting_for_input = ""
			update_buttons()

	# Controller
	if waiting_for_controller_input != "":
		if event is InputEventJoypadButton and event.pressed:
			if InputMap.action_has_event("pause", event):
				waiting_for_controller_input = ""
				update_buttons()
				return
			for other_action in controller_action_buttons.keys():
				var existing = get_first_joypad_button_event(other_action)
				if existing and existing.button_index == event.button_index:
					InputMap.action_erase_event(other_action, existing)

			var old_event = get_first_joypad_button_event(waiting_for_controller_input)
			if old_event:
				InputMap.action_erase_event(waiting_for_controller_input, old_event)
			InputMap.action_add_event(waiting_for_controller_input, event)

			waiting_for_controller_input = ""
			update_buttons()

		# Controller Deadzone
		elif event is InputEventJoypadMotion and absf(event.axis_value) >= controller_deadzone:
			for other_action in controller_action_buttons.keys():
				var existing = get_first_joypad_motion_event(other_action)
				if existing and existing.axis == event.axis and sign(existing.axis_value) == sign(event.axis_value):
					InputMap.action_erase_event(other_action, existing)

			var old_event = get_first_joypad_motion_event(waiting_for_controller_input)
			if old_event:
				InputMap.action_erase_event(waiting_for_controller_input, old_event)

			var motion := InputEventJoypadMotion.new()
			motion.axis = event.axis
			motion.axis_value = sign(event.axis_value)
			InputMap.action_add_event(waiting_for_controller_input, motion)

			waiting_for_controller_input = ""
			update_buttons()

		elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
			waiting_for_controller_input = ""
			update_buttons()
