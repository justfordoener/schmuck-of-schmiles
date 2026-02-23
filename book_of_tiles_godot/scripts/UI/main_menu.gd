extends Control

@export_category("MainMenuButtons")
@export var level_button: TextureButton
@export var settings_button: TextureButton
@export var credits_button: TextureButton
@export var quit_button: TextureButton

@export_category("LevelSelectButtons")
@export var level_back_button: Button
@export var level1_button: TextureButton
@export var level2_button: TextureButton
@export var level3_button: TextureButton
@export var level4_button: TextureButton

@export_category("SettingButtons")
@export var settings_back_button: Button

@export_category("CreditsButtons")
@export var credits_back_button: Button

@export_category("menus")
@export var level_selection: Control
@export var settings: Control
@export var credits: Control

func _ready() -> void:
	level_button.pressed.connect(toggle_level_menu)
	level_back_button.pressed.connect(toggle_level_menu)
	settings_button.pressed.connect(toggle_settings)
	settings_back_button.pressed.connect(toggle_settings)
	credits_button.pressed.connect(toggle_credits)
	credits_back_button.pressed.connect(toggle_credits)
	quit_button.pressed.connect(quit_game)

func toggle_level_menu() -> void:
	if level_selection.visible:
		level_selection.visible = false
	else:
		level_selection.visible = true

func toggle_settings() -> void:
	if settings.visible:
		settings.visible = false
	else:
		settings.visible = true

func toggle_credits() -> void:
	if credits.visible:
		credits.visible = false
	else:
		credits.visible = true

func quit_game():
	get_tree().quit()


# Level Selection
