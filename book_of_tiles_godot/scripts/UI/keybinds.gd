extends Control

var waiting_for_input := ""

@export var action_buttons: Dictionary[String, Button]

func _ready():
	for action in action_buttons.keys():
		var button = action_buttons[action]
		button.pressed.connect(_on_action_button_pressed.bind(action))
	update_buttons()

func update_buttons():
	for action in action_buttons.keys():
		var button = action_buttons[action]
		var events = InputMap.action_get_events(action)

		if events.size() > 0:
			button.text = events[0].as_text()
		else:
			button.text = "Unassigned"

func _on_action_button_pressed(action: String):
	waiting_for_input = action
	action_buttons[action].text = "Press a key..."

func _input(event: InputEvent) -> void:
	if waiting_for_input != "":
		if event is InputEventKey and event.pressed:
			for other_action in action_buttons.keys():
				InputMap.action_erase_event(other_action, event)
			
			# Rebind
			InputMap.action_erase_events(waiting_for_input)
			InputMap.action_add_event(waiting_for_input, event)
			
			waiting_for_input = ""
			update_buttons()
			
		elif event is InputEventKey and event.keycode == KEY_ESCAPE:
			waiting_for_input = ""
			update_buttons()
