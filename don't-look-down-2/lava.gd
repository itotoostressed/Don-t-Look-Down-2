extends Area3D

var yPos = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func rise():
	global_position.y += .03
