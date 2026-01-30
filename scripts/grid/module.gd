@abstract class_name Module extends MeshInstance3D

var type : String
var cell_shape : ArrayMesh
@abstract func get_tile_reference() -> String
@abstract func create_cell_shape() -> void
