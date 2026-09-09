class_name LandmarkSlot extends Resource

# One tile a recipe requires. Slots are read relative to each other, not to the grid: the
# match is anchored on whichever corner was just placed, so any slot can be the one the
# player completes the pattern with. See Recipes.find_match().

# Position relative to the pattern's own origin, in CORNER steps - the six neighbours of a
# corner are Layout.AXIAL_DIRECTION[0..5], i.e. (1,0,0), (0,0,1), (-1,0,1), (-1,0,0),
# (0,0,-1), (1,0,-1). y is a layer offset, and slots may sit on different layers: The Great
# Clearing is a grass corner ringed by forest one layer up. The landmark then covers the whole
# volume the pattern spans - see Grid.derive_landmark_footprint().
@export var offset : Vector3i = Vector3i.ZERO

# The tile that must occupy that corner.
@export var tile_kind : Layout.TILE_KIND = Layout.TILE_KIND.NONE
