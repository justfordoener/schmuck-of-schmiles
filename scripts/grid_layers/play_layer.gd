extends GridLayer

@onready var mesh_instance = $play_layer_mesh

func _ready():
	build_layer_mesh()

func build_layer_mesh():
	#layer_mesh = Grid.get_play_layer_array_mesh()
	#mesh_instance.mesh = layer_mesh
	pass
	
func show_layer_mesh(value : bool):
	mesh_instance.visible = value
	
func activate_layer_snapping():
	print_debug("play layer activated")
	layer_color = PLAY_LAYER_COLOR

func snap_to_layer(point : Vector3) -> Vector3:
	#Grid.snap_to_full_layer(point)
	return point
