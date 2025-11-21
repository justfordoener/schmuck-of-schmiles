extends GridLayer

@onready var mesh_instance = $face_layer_mesh

func _ready():
	build_layer_mesh()

func build_layer_mesh():
	layer_mesh = Grid.get_face_layer_array_mesh()
	mesh_instance.mesh = layer_mesh
	
func show_layer_mesh(value : bool):
	mesh_instance.visible = value
	
func activate_layer_snapping():
	print_debug("face layer activated")
	layer_color = FACE_LAYER_COLOR

func snap_to_layer(point : Vector3) -> Vector3:
	return Grid.snap_to_face_layer(point)
