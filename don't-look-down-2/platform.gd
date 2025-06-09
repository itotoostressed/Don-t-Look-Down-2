extends Area3D

var has_disappeared = false

func _ready() -> void:
	# Connect the body entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Check if body is valid before proceeding
	if body == null:
		return
		
	# If the body is a StaticBody3D, check its parent instead
	var check_body = body
	if body is StaticBody3D:
		check_body = body.get_parent()
		
	# Only trigger if the body is the player
	if check_body and check_body.is_in_group("players") and not has_disappeared:
		disappear()

func disappear() -> void:
	if not has_disappeared:
		has_disappeared = true
		# Remove from groups before disconnecting signals
		if is_in_group("platform"):
			remove_from_group("platform")
		if is_in_group("ice"):
			remove_from_group("ice")
		# Disconnect the signal before freeing
		body_entered.disconnect(_on_body_entered)
		# Queue the platform for deletion
		queue_free()
		print("Platform disappeared!")
