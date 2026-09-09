class_name Landmark extends Node3D

# A landmark is one big object that replaces a whole constellation of placed tiles - the
# merge recipes in book-of-tiles_recipes.pdf. It carries its own recipe, the same way a
# Module carries its own border profiles (see scripts/grid/modules/module.gd): the scene in
# scenes/landmarks/ is both the pattern definition and the thing that gets spawned, and
# Recipes loads the directory the way Grid loads scenes/modules/blockout/.
#
# The cells a landmark covers are worked out from the matched corners, not authored here -
# see Grid.derive_landmark_footprint().

@export var landmark_id : StringName

# The tiles that must be on the grid for this landmark to form. Order doesn't matter; the
# search tries every slot as the anchor so the pattern is found whichever tile completes it.
@export var slots : Array[LandmarkSlot] = []

# Whether the pattern may match rotated by any multiple of 60 degrees. Turn off only for a
# landmark that must appear in one fixed orientation.
@export var allow_rotation : bool = true

# Whether the pattern may also match mirrored. Needed by any recipe that is chiral - one whose
# mirror image is not one of its own rotations - because a player can build it either way
# round. Beaver Downhill Village is the case in point: its river can sit on either side of the
# two beaver houses, and no rotation carries one arrangement onto the other.
#
# A mirrored match spawns this scene with scale.x = -1, so the mesh has to survive being
# flipped. If it must not be (lettering, a deliberately handed silhouette), leave this off and
# author the second handedness as its own landmark scene.
@export var allow_mirror : bool = false
