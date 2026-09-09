extends Node

@export var layer_type : Layout.CELL_TYPE
# Water replaces whatever currently occupies the hovered cell instead of stacking above it.
@export var is_water : bool = false
# Copied onto the corner cell when this tile is placed; what recipes match against.
@export var tile_kind : Layout.TILE_KIND = Layout.TILE_KIND.NONE
