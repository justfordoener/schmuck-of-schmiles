class_name Cell extends Node

var state: int
var type : Layout.CELL_TYPE
var axial_position : Vector3

var neighbors : Dictionary[Vector3i, Cell]
var profiles : Dictionary[Vector3, Layout.PROFILE_TYPE]
var module_reference: Module

func _init(axial : Vector3) -> void:
	axial_position = axial
