class_name TileCard extends Control

const THEME_FOREST  = 1
const THEME_DESERT  = 2
const THEME_SNOW    = 4
const THEME_SWAMP   = 8

const PACK_ANIMALS        = 1
const PACK_INFRASTRUCTURE = 2
const PACK_LANDSCAPE      = 4

@export var tile : PackedScene
@export_flags("forest", "desert", "snow", "swamp") var themes : int = 0
@export var weight_animals : int = 0
@export var weight_infrastructure : int = 0
@export var weight_landscape : int = 0

var hand_index : int
signal button_pressed(tile_card : Control)

func on_button_pressed():
	emit_signal("button_pressed", self)

func get_weight_for_pack(pack_flag : int) -> int:
	match pack_flag:
		PACK_ANIMALS: return weight_animals
		PACK_INFRASTRUCTURE: return weight_infrastructure
		PACK_LANDSCAPE: return weight_landscape
	return 0

func is_in_pack(pack_flag : int) -> bool:
	return get_weight_for_pack(pack_flag) > 0

func is_in_theme(theme_flag : int) -> bool:
	return (themes & theme_flag) != 0
