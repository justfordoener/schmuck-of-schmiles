#@tool
extends Node

var activated : bool

var selected_nodes : Array[Node] 

func _process(_delta: float) -> void:
	if not activated:
		return
	_set_selected_node()
	_update_node_position()

func _update_node_position() -> void:
	for selected_node in selected_nodes:
		if selected_node == null:
			return
		var point : Vector3 = Vector3(selected_node.global_position.x, selected_node.global_position.y, selected_node.global_position.z)
		selected_node.global_position = Grid.euclidic_snap_to_trigrid(point)
		
func _set_selected_node() -> void:
	if Engine.is_editor_hint():
		var selection = EditorInterface.get_selection()
		if selection.get_selected_nodes().is_empty():
			return
		if selection.get_top_selected_nodes().all(_is_3d_node):
			selected_nodes = selection.get_top_selected_nodes()
	else:
		pass #TODO handle ingame node selection
		
func _is_3d_node(node) -> bool:
	if (node.get_class() == "Node3D"):
		return true
	else:
		return false
