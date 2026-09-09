class_name Cell extends Node

var state: int
var type : Layout.CELL_TYPE
var axial_position : Vector3
# Intrinsic orientation of this cell in degrees, computed once from grid geometry
# at creation. This is the rotation a module of the matching type must take to seat
# correctly on this cell (CORNER: 0, EDGE: 0/60/120, FACE: 0/60). Replaces the old
# coordinate-parity heuristic in Grid.snap_rotation.
var base_rotation : int = 0

var neighbors : Dictionary[String, Cell]
var profiles : Dictionary[String, Layout.PROFILE_TYPE]
var possibilities : Array[Possibility]
var initial_possibilities : Array[Possibility]
var module_reference: Module
var instanced_module : Node3D = null
# What sits on this cell, for recipe matching. Only meaningful on CORNER cells; set by
# Grid._seed_filler_module() and by a placement in Grid.batch_place_modules().
var tile_kind : Layout.TILE_KIND = Layout.TILE_KIND.NONE
# Non-null once this cell has been merged into a landmark. Such a cell is hard and inert:
# the solver never narrows or refills it, and nothing can be placed into it - it just keeps
# the profiles it inherited from the tiles it replaced, so neighbours still read a valid
# border across the landmark's edge. See Grid.merge_landmark().
var landmark : Landmark = null
func _init(axial : Vector3) -> void:
	axial_position = axial
