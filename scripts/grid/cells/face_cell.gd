class_name FaceCell extends Cell

func _init(axial : Vector3i) -> void:
	super(axial)
	type = Layout.CELL_TYPE.FACE
	state = 1
