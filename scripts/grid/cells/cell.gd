@abstract class_name Cell extends Node

var state: int
var neighbors : Dictionary[Vector3i, Cell]
var module_reference: Module

@abstract func create() -> Cell
	
