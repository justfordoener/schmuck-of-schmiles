class_name CornerCell extends Cell

func _init(axial : Vector3i) -> void:
	super(axial)
	type = Layout.CELL_TYPE.CORNER
	state = 1
	
