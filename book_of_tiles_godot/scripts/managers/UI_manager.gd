extends CanvasLayer

@onready var main_manager : Node = $".."
@onready var hand_hbox : HBoxContainer = $Control/MarginContainer/HBoxContainer/MarginContainer/HandAreaHBox
@onready var turn_over : VBoxContainer = $Control/MarginContainer/HBoxContainer/TurnOver/TurnOverButtonVBox
@onready var undo : VBoxContainer = $Control/MarginContainer/HBoxContainer/Undo/UndoButtonVBox

@export var tile_card_directory : String
var tile_cards : Array[PackedScene] = []
var hand : Array[PackedScene] = []
var cards_played_today : Array[PackedScene] = []

func _ready():
	_load_tile_cards()
	refill_tiles()
	_check_visibility()

func _load_tile_cards():
	if tile_card_directory == "":
		printerr("Tile card directory is not set!")
		return
		
	var dir = DirAccess.open(tile_card_directory)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if !dir.current_is_dir():
				# Remove export suffixes (.remap for scenes, .import for textures/others)
				var clean_path = tile_card_directory + "/" + file_name.replace(".remap", "").replace(".import", "")
				
				# Only load if it's a scene file and we haven't loaded this exact path yet
				# (The check prevents loading the same resource twice if both .tscn and .tscn.remap are listed)
				if clean_path.ends_with(".tscn"):
					var res = load(clean_path)
					if res is PackedScene and not tile_cards.has(res):
						tile_cards.append(res)
						print("Loaded card: ", clean_path)
			
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		printerr("Could not open directory: ", tile_card_directory)
	
func refill_tiles():
	if hand.size() > 0:
		printerr("ERROR, hand not empty!")
		return
	for i in Parameters.HAND_SIZE:
		var rng_tile_index = randi_range(0, tile_cards.size()-1)
		var card = tile_cards[rng_tile_index]
		add_card_to_hand(i, card)
	_check_visibility()
	cards_played_today = []

func remove_card_from_hand(index : int):
	var cards : Array[Node] = hand_hbox.get_children()
	for card : TileCard in cards:
		if card.hand_index > index:
			card.hand_index -= 1
	cards[index].queue_free()
	cards_played_today.append(hand[index])
	hand.remove_at(index)
	_check_visibility()
	
func add_card_to_hand(index : int, card : PackedScene):
	hand.append(card)
	var tile_card_instance : TileCard = card.instantiate() as TileCard
	tile_card_instance.hand_index = index
	tile_card_instance.button_pressed.connect(_on_card_selected)
	hand_hbox.add_child(tile_card_instance)
		
func get_card_from_hand(index : int) -> TileCard:
	for card in hand_hbox.get_children():
		var tile_card : TileCard = card
		if tile_card.hand_index == index:
			return card
	return 
	
func _on_card_selected(card : TileCard) -> void:
	remove_card_from_hand(card.hand_index)
	main_manager.tile_selected(card.tile)
	
func _check_visibility():
	if hand.is_empty():
		turn_over.show()
	else:
		turn_over.hide()
	if hand.size() == 5:
		undo.hide()
	else:
		undo.show()
	
func _on_turnover_button_pressed() -> void:
	refill_tiles()
	
func _on_undo_button_pressed() -> void:
	main_manager.undo()
	var last_card : PackedScene = cards_played_today.pop_back()
	add_card_to_hand(hand.size(), last_card)
