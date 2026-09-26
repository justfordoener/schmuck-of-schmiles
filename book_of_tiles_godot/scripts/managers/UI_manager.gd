extends CanvasLayer

@onready var main_manager : Node = $".."
@onready var hand_hbox : HBoxContainer = $Control/MarginContainer/HBoxContainer/MarginContainer/HandAreaHBox
@onready var turn_over : VBoxContainer = $Control/MarginContainer/HBoxContainer/TurnOver/TurnOverButtonVBox

@export var pack_selection_overlay : Control
@export var pack_button_1 : Button
@export var pack_button_2 : Button
@export var pack_button_3 : Button
@export var icon_animal_pack : Texture2D
@export var icon_infrastructure_pack : Texture2D
@export var icon_landscape_pack : Texture2D
var _day_started : bool = false

@export var tile_card_directory : String
var tile_cards : Array[PackedScene] = []
var hand : Array[PackedScene] = []
var cards_played_today : Array[PackedScene] = []

var active_pack : int = TileCard.packs.animal
var active_theme : int = TileCard.themes.forest

func _ready():
	Signals.on_instance_spawned.connect(_check_visibility)
	_load_tile_cards()
	start_new_day()
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
	var available := _get_available_cards()
	if available.is_empty():
		printerr("No cards available for theme/pack combination!")
		return
	for i in Parameters.HAND_SIZE:
		add_card_to_hand(i, _pick_weighted(available))
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
	GameState.change_state(GameState.State.TILES_PLACING)
	remove_card_from_hand(card.hand_index)
	main_manager.tile_selected(card.tile)
	
func _check_visibility():
	if hand.is_empty():
		turn_over.show()
	else:
		turn_over.hide()
	
func _on_turnover_button_pressed() -> void:
	start_new_day()
	

func choose_tile_pack(pack : int, theme : int) -> void:
	active_pack = pack
	active_theme = theme

func _get_available_cards() -> Array[PackedScene]:
	var filtered : Array[PackedScene] = []
	for card_scene in tile_cards:
		var instance := card_scene.instantiate() as TileCard
		if instance.is_in_theme(active_theme) and instance.is_in_pack(active_pack):
			filtered.append(card_scene)
		instance.queue_free()
	return filtered

func _pick_weighted(available : Array[PackedScene]) -> PackedScene:
	var total_weight := 0
	for card_scene in available:
		var instance := card_scene.instantiate() as TileCard
		total_weight += instance.get_weight_for_pack(active_pack)
		instance.queue_free()
	
	var roll := randi_range(1, total_weight)
	var cumulative := 0
	for card_scene in available:
		var instance := card_scene.instantiate() as TileCard
		cumulative += instance.get_weight_for_pack(active_pack)
		instance.queue_free()
		if roll <= cumulative:
			return card_scene
	return available[-1]


func start_new_day() -> void:
	GameState.change_state(GameState.State.TILE_PACK_CHOOSING)
	Grid.landmark_formed_today = false
	var offered_packs := _get_available_packs()
	
	if _day_started:
		pack_button_1.pressed.disconnect(_on_pack_chosen)
		pack_button_2.pressed.disconnect(_on_pack_chosen)
		pack_button_3.pressed.disconnect(_on_pack_chosen)
	_day_started = true
	
	pack_button_1.text = TileCard.get_pack_name(offered_packs[0])
	pack_button_2.text = TileCard.get_pack_name(offered_packs[1])
	pack_button_3.text = TileCard.get_pack_name(offered_packs[2])
	
	pack_button_1.icon = _get_pack_icon(offered_packs[0])
	pack_button_2.icon = _get_pack_icon(offered_packs[1])
	pack_button_3.icon = _get_pack_icon(offered_packs[2])
	
	pack_button_1.pressed.connect(_on_pack_chosen.bind(offered_packs[0]), CONNECT_ONE_SHOT)
	pack_button_2.pressed.connect(_on_pack_chosen.bind(offered_packs[1]), CONNECT_ONE_SHOT)
	pack_button_3.pressed.connect(_on_pack_chosen.bind(offered_packs[2]), CONNECT_ONE_SHOT)
	
	pack_selection_overlay.show()

func _get_available_packs() -> Array[int]:
	var all_packs : Array[int] = [
		TileCard.packs.animal,
		TileCard.packs.infrastructure,
		TileCard.packs.landscape
	]
	var valid_packs : Array[int] = []
	for pack in all_packs:
		for card_scene in tile_cards:
			var instance := card_scene.instantiate() as TileCard
			if instance.is_in_theme(active_theme) and instance.is_in_pack(pack):
				valid_packs.append(pack)
				instance.queue_free()
				break
			instance.queue_free()
	valid_packs.shuffle()
	return valid_packs.slice(0, 3)

func _on_pack_chosen(pack : int) -> void:
	GameState.change_state(GameState.State.TILE_CHOOSING)
	active_pack = pack
	pack_selection_overlay.hide()
	refill_tiles()

func _get_pack_icon(pack : int) -> Texture2D:
	match pack:
		TileCard.packs.animal:
			return icon_animal_pack
		TileCard.packs.infrastructure:
			return icon_infrastructure_pack
		TileCard.packs.landscape:
			return icon_landscape_pack
	return null
