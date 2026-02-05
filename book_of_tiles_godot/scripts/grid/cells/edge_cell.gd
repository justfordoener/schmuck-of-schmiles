class_name EdgeCell extends Cell

func _init(axial : Vector3) -> void:
	super(axial)
	type = Layout.CELL_TYPE.EDGE
	state = 1
