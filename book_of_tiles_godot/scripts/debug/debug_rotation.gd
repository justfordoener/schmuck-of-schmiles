@tool
extends Node3D

@export var rotation_value : int:
	set(value):
		rotation_value = value
		if instance and is_inside_tree():
			instance.position = Grid.axial_to_cartesian(Layout.TILE_ROTATION_VALUE[rotation_value])
@onready var instance : MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	instance = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	instance.mesh = mesh
	get_tree().root.add_child(instance)
