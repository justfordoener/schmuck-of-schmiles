class_name EdgeModule extends Module

func get_tile_reference() -> String:
	return "edge"

func create_cell_shape() -> void:
	cell_shape = AxialGrid.create_edge_mesh()
