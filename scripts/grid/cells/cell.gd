@abstract class_name Cell extends Node

var state: int
var type : String
var neighbors : Dictionary[Vector3i, Cell]
var module_reference: Module
var axial_position : Vector3

@abstract func _init() -> void
