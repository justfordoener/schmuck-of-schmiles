class_name FaceModule extends Module

func get_tile_reference() -> String:
	return "face"

func create_cell_shape() -> void:
	cell_shape = AxialGrid.create_face_mesh()
