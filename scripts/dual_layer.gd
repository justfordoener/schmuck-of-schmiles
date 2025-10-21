extends GridLayer

@onready var mesh_instance = $dual_layer_mesh

func _ready():
	build_layer_mesh()

func build_layer_mesh():
	layer_mesh = Grid.get_dual_layer_array_mesh()
	mesh_instance.mesh = layer_mesh
	
func show_layer_mesh(value : bool):
	mesh_instance.visible = value
	
func activate_layer_snapping():
	print_debug("dual layer activated")
	layer_color = DUAL_LAYER_COLOR

func snap_to_layer(point : Vector3) -> Vector3:
	return Grid.snap_to_dual_layer(point)
