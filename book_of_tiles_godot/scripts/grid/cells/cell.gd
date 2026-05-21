class_name Cell extends Node

var state: int
var type : Layout.CELL_TYPE
var axial_position : Vector3

var neighbors : Dictionary[String, Cell]
var profiles : Dictionary[String, Layout.PROFILE_TYPE]
var possibilities : Array[Possibility]
var initial_possibilities : Array[Possibility]
var module_reference: Module
var instanced_module : Node3D = null
var is_player_placed : bool = false
func _init(axial : Vector3) -> void:
	axial_position = axial
