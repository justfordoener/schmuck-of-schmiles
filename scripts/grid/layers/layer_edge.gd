extends GridLayer

@onready var mesh_instance = $edge_layer_mesh

func _ready():
	build_layer_mesh()

func build_layer_mesh():
	pass
	
func show_layer_mesh(value : bool):
	mesh_instance.visible = value
	
func activate_layer_snapping():
	print_debug("edge layer activated")
	layer_color = EDGE_LAYER_COLOR

func snap_to_layer(point : Vector3) -> Vector3:
	return Grid.snap_to_edge_layer(point)
