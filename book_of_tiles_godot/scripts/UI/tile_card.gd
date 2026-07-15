class_name TileCard extends Control

enum themes { forest = 1, desert = 2, snow = 4, swamp = 8 }

enum packs { animal = 1, infrastructure = 2, landscape = 3}


@export var tile : PackedScene
@export_flags("forest", "desert", "snow", "swamp") var export_theme : int = 0
@export var weight_animals : int = 0
@export var weight_infrastructure : int = 0
@export var weight_landscape : int = 0

var hand_index : int
signal button_pressed(tile_card : Control)

func on_button_pressed():
	emit_signal("button_pressed", self)

func get_weight_for_pack(pack_flag : int) -> int:
	match pack_flag:
		packs.animal: return weight_animals
		packs.infrastructure: return weight_infrastructure
		packs.landscape: return weight_landscape
	return 0

func is_in_pack(pack_flag : int) -> bool:
	return get_weight_for_pack(pack_flag) > 0

func is_in_theme(theme_flag : int) -> bool:
	return (export_theme & theme_flag) != 0

static func get_pack_name(pack_flag : int) -> String:
	match pack_flag:
		packs.animal: return "Animal Pack"
		packs.infrastructure: return "Infrastructure Pack"
		packs.landscape: return "Landscape Pack"
	return "Unknown"
