extends Node

var balancing_data: Dictionary = {}
var balancing_file_path = "res://Files/balance.json"

func _ready():
	load_balance()

func _input(event):
	if event.is_action_pressed("reload_files"):
		reload_files()

func load_balance():
	if not FileAccess.file_exists(balancing_file_path):
		print("Balance file not found")
		return
	
	var balance_file = FileAccess.open(balancing_file_path, FileAccess.READ)
	balancing_data = JSON.parse_string(balance_file.get_as_text())

func reload_files():
	load_balance()
	print("reloaded")
