class_name GridLayer extends Node3D

@export var PLAY_LAYER_COLOR := Color.ORANGE
@export var DUAL_LAYER_COLOR := Color.DARK_RED
@export var FACE_LAYER_COLOR := Color.CYAN
@export var EDGE_LAYER_COLOR := Color.LIME_GREEN
@export var CORN_LAYER_COLOR := Color.YELLOW

var layer_color = Color.BLACK
var layer_mesh : ArrayMesh
var current_module : PackedScene

func _ready():
	pass

func build_layer_mesh():
	pass
	
func show_layer_mesh(value : bool):
	print_debug("show_abstract_layer_mesh. value: ", value)
	pass

func activate_layer_snapping():
	print_debug("activated_abstract_layer_snapping")
	pass
	
func snap_to_layer(point : Vector3) -> Vector3:
	return point
