extends CanvasLayer

@onready var main_manager : Node = $".."
@onready var hand_hbox : HBoxContainer = $Control/MarginContainer/HBoxContainer/MarginContainer/HandAreaHBox
@onready var turn_over : VBoxContainer = $Control/MarginContainer/HBoxContainer/TurnOver/TurnOverButtonVBox
@onready var undo : VBoxContainer = $Control/MarginContainer/HBoxContainer/Undo/UndoButtonVBox

@export var tile_card_directory : String
var tile_cards : Array[PackedScene] = []
var hand : Array[PackedScene] = []

func _ready():
	var dir_path := tile_card_directory
	var dir : DirAccess = DirAccess.open(tile_card_directory)
	dir.list_dir_begin()
	for file in dir.get_files():
		tile_cards.append(load(dir_path + "/" + file))
	refill_tiles()
	turn_over.hide()
	
func refill_tiles():
	if hand.size() > 0:
		printerr("ERROR, hand not empty!")
		return
	for i in Parameters.HAND_SIZE:
		add_card_to_hand(i)
	undo.hide()
	turn_over.hide()

func remove_card_from_hand(index : int):
	var cards : Array[Node] = hand_hbox.get_children()
	for card : TileCard in cards:
		if card.hand_index > index:
			card.hand_index -= 1
	if cards.size() == 1:
		turn_over.show()
	undo.show()
	cards[index].queue_free()
	hand.remove_at(index)
	
func add_card_to_hand(index : int):
	var rng_tile_index = randi_range(0, tile_cards.size()-1)
	var card = tile_cards[rng_tile_index]
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
	print(card.hand_index)
	remove_card_from_hand(card.hand_index)
	main_manager.tile_selected(card.tile)
	
func _on_turnover_button_pressed() -> void:
	refill_tiles()
	
func _on_undo_button_pressed() -> void:
	pass
