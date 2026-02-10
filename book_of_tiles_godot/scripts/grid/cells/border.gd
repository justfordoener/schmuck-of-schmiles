class_name Border extends Cell

var profile : Layout.PROFILE_TYPE = Layout.PROFILE_TYPE.EMPTY
var cell_neighbors : Array[Vector3i]
	
func set_neighbors(c1: Vector3i, c2: Vector3i) -> void:
	cell_neighbors.resize(2)
	cell_neighbors[0] = c1
	cell_neighbors[1] = c2
	
func get_neighbor_index(self_axial_index : Vector3i) -> Vector3i:
	var index = cell_neighbors.find(self_axial_index)
	index = (index + 1) % 2
	return cell_neighbors[index]
