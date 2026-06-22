class_name Module extends Node3D

@export var module_type : Layout.CELL_TYPE
@export var module_id : int
# dict key is border direction in degrees (0 = right, 90 = bottom), profile keys ascend in clockwise order
@export var profiles : Dictionary[int, Layout.PROFILE_TYPE]
