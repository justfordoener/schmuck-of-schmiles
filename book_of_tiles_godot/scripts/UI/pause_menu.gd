extends Control

@export var settings_button: Button
@export var close_settings_button: Button
@export var back_to_menu_button: Button
@export var close_button: Button
@export var quit_button: Button

@export var settings: Control
@export var pause: Control

func _ready() -> void:
	# connect buttons
	settings_button.pressed.connect(toggle_menu.bind(settings))
	close_settings_button.pressed.connect(toggle_menu.bind(settings))
	back_to_menu_button.pressed.connect(main_menu)
	close_button.pressed.connect(toggle_menu.bind(pause))
	quit_button.pressed.connect(quit_game)
	
	pause.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_menu(pause)
		settings.visible = false

func toggle_menu(menu: Control) -> void:
	menu.visible = ! menu.visible
	if menu == pause:
		get_tree().paused = pause.visible

func main_menu() -> void:
	toggle_menu(pause)
	get_tree().change_scene_to_file("res://scenes/user_interface/menus/main_menu.tscn")
	# after the Main Menu scene is the new main_scene in the project, swap to:
	#get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))

func quit_game():
	get_tree().quit()
