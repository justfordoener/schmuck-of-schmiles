class_name CornerCell extends Cell

func _init(axial : Vector3) -> void:
	super(axial)
	type = Layout.CELL_TYPE.CORNER
	state = 1
	
