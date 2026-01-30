class_name Cell extends Node

var state: int
var type : String
var neighbors : Dictionary[Vector3, Cell]
var module_reference: Module
var axial_position : Vector3

func _init(axial : Vector3) -> void:
	axial_position = axial
