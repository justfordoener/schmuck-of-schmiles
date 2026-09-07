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
func _init(axial : Vector3) -> void:
	axial_position = axial
