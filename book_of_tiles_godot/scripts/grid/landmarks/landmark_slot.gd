class_name LandmarkSlot extends Resource

# One tile a recipe requires. Slots are read relative to each other, not to the grid: the
# match is anchored on whichever corner was just placed, so any slot can be the one the
# player completes the pattern with. See Recipes.find_match().

# Position relative to the pattern's own origin, in CORNER steps - the six neighbours of a
# corner are Layout.AXIAL_DIRECTION[0..5], i.e. (1,0,0), (0,0,1), (-1,0,1), (-1,0,0),
# (0,0,-1), (1,0,-1). y is a layer offset.
#
# Only flat patterns (every slot y == 0) are supported: corners on different layers have no
# cells between them to merge (Grid links neighbours horizontally only), so a landmark
# spanning a height change has nothing to sit on. The field exists so the data format
# doesn't have to change once that's solved.
@export var offset : Vector3i = Vector3i.ZERO

# The tile that must occupy that corner.
@export var tile_kind : Layout.TILE_KIND = Layout.TILE_KIND.NONE
