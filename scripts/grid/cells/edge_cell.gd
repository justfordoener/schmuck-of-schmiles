class_name EdgeCell extends Cell

func _init(axial : Vector3i) -> void:
	super(axial)
	type = Layout.CELL_TYPE.EDGE
	state = 1
