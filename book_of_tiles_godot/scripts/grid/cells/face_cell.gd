class_name FaceCell extends Cell

func _init(axial : Vector3) -> void:
	super(axial)
	type = Layout.CELL_TYPE.FACE
	state = 1
