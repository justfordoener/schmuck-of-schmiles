class_name Cell extends Node

var state: int
var type : String
var neighbors : Dictionary[Vector3i, Cell]
var module_reference: Module
var axial_position : Vector3i

func _init(axial : Vector3i) -> void:
	axial_position = axial
