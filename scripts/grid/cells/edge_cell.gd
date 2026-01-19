class_name EdgeCell extends Cell

func _init(axial : Vector3i) -> void:
	super(axial)
	type = "EdgeCell"
	state = 1
