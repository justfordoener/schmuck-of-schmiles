extends GridLayer

@onready var mesh_instance = $corn_layer_mesh

func _ready():
	build_layer_mesh()

func build_layer_mesh():
	pass
	
func show_layer_mesh(value : bool):
	mesh_instance.visible = value
	
func activate_layer_snapping():
	print_debug("corn layer activated")
	layer_color = CORN_LAYER_COLOR

func snap_to_layer(point : Vector3) -> Vector3:
	return Grid.snap_to_corn_layer(point)
