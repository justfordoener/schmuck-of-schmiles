class_name CornerModule extends Module

func get_tile_reference() -> String:
	return "corn"

func create_cell_shape() -> void:
	cell_shape = AxialGrid.create_corner_mesh()
