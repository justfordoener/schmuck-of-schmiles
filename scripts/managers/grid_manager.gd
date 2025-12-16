extends Node

@onready var grid_layers = {
	"play_layer" : $grid_layers/play_layer,
	"dual_layer" : $grid_layers/dual_layer,
	"face_layer" : $grid_layers/face_layer,
	"edge_layer" : $grid_layers/edge_layer,
	"corn_layer" : $grid_layers/corn_layer,
	"full_layer" : $grid_layers/full_layer
}

@onready var layer_modules = {
	"play_layer" : play_module,
	"dual_layer" : dual_module,
	"face_layer" : face_module,
	"edge_layer" : edge_module,
	"corn_layer" : corn_module
}

@export var play_module : PackedScene
@export var dual_module : PackedScene
@export var face_module : PackedScene
@export var edge_module : PackedScene
@export var corn_module : PackedScene
@export var camera_path : NodePath

func _ready():
	grid_layers["corn_layer"].show_layer_mesh(true)
	#grid_layers["dual_layer"].show_layer_mesh(true)
	grid_layers["face_layer"].show_layer_mesh(true)
	grid_layers["face_layer"].activate_layer_snapping()
