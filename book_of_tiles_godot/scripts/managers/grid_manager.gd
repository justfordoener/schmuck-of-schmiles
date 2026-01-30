class_name GridManager extends Node

@onready var grid_layers = {
	"face_layer" : $grid_layers/face_layer,
	"edge_layer" : $grid_layers/edge_layer,
	"corn_layer" : $grid_layers/corn_layer
}

@onready var layer_modules = {
	"face_layer" : face_module,
	"edge_layer" : edge_module,
	"corn_layer" : corn_module
}

@export var face_module : PackedScene
@export var edge_module : PackedScene
@export var corn_module : PackedScene
@export var camera_path : NodePath

func _ready():
	grid_layers["corn_layer"].show_layer_mesh(true)
	#grid_layers["dual_layer"].show_layer_mesh(true)
	grid_layers["face_layer"].show_layer_mesh(true)
	grid_layers["edge_layer"].show_layer_mesh(true)
	#grid_layers["face_layer"].activate_layer_snapping()
	
func snap(position : Vector3, layer_key : String) -> Vector3:
	grid_layers[layer_key].snap_to_layer(position)
	return position
