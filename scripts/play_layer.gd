extends GridLayer

func _ready():
	build_layer_mesh()

func build_layer_mesh():
	#TODO
	pass
	
func show_layer_mesh(value : bool):
	print_debug("show_play_layer_mesh not implemented yet. value: ", value) #TODO
	pass
	
func activate_layer_snapping():
	print_debug("play layer activated")
	layer_color = PLAY_LAYER_COLOR

func snap_to_layer(point : Vector3) -> Vector3:
	return point #TODO
