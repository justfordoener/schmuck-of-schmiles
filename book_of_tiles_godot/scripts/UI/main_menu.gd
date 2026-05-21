extends Control

@export_category("MainButtons")
@export var level_button: TextureButton
@export var settings_button: TextureButton
@export var credits_button: TextureButton
@export var quit_button: TextureButton

@export_category("LevelButtons")
@export var level_back_button: Button
@export var level_buttons: Array[TextureButton]
var level_folder = "res://levels/"
var level_scenes: Array[String] = []

@export_category("SettingButtons")
@export var settings_back_button: Button

@export_category("CreditsButtons")
@export var credits_back_button: Button

@export_category("menus")
@export var level_selection: Control
@export var settings: Control
@export var credits: Control


func _ready() -> void:
	# connect buttons
	level_button.pressed.connect(toggle_menu.bind(level_selection))
	level_back_button.pressed.connect(toggle_menu.bind(level_selection))
	settings_button.pressed.connect(toggle_menu.bind(settings))
	settings_back_button.pressed.connect(toggle_menu.bind(settings))
	credits_button.pressed.connect(toggle_menu.bind(credits))
	credits_back_button.pressed.connect(toggle_menu.bind(credits))
	quit_button.pressed.connect(quit_game)


func toggle_menu(menu: Control) -> void:
	menu.visible = ! menu.visible
	if menu == level_selection:
		check_levels()


func quit_game():
	get_tree().quit()


# Level Selection
func check_levels():
	level_scenes.clear()

	var directory := DirAccess.open(level_folder)
	if directory == null:
		print("Could not open level folder")
		return

	for button in level_buttons:
		button.visible = false
		if button.pressed.is_connected(load_level):
			button.pressed.disconnect(load_level)

	directory.list_dir_begin()
	var file_name = directory.get_next()

	while file_name != "":
		if not directory.current_is_dir() and file_name.ends_with(".tscn"):

			var level_number = get_level_number(file_name)

			if level_number <= 0:
				print("Error: Invalid level number (Must be > 0) in file: ", file_name)
				return

			if level_number <= level_buttons.size():
				var button_index = level_number - 1
				var button = level_buttons[button_index]
				var full_path = level_folder + file_name

				button.visible = true
				button.pressed.connect(load_level.bind(full_path))

		file_name = directory.get_next()
	directory.list_dir_end()


func load_level(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func get_level_number(file_name: String) -> int:
	var base_name := file_name.get_basename()
	var digits := ""
	
	for characters in base_name:
		if characters.is_valid_int():
			digits += characters
		
	if digits != "":
		return int(digits)
	
	return -1
