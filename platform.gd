extends Area3D

var has_disappeared = false
var player_on_platform = false

func _ready() -> void:
	# Connect both body entered and shape entered signals
	body_entered.connect(_on_body_entered)
	body_shape_entered.connect(_on_body_shape_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	# Check if player is on platform and hasn't disappeared yet
	if player_on_platform and not has_disappeared:
		disappear()

func _on_body_shape_entered(body_rid: RID, body: Node3D, _body_shape_index: int, _local_shape_index: int) -> void:
	# This signal is more precise and fires immediately when collision shapes overlap
	if body and body.is_in_group("players"):
		player_on_platform = true
		if not has_disappeared:
			# 30% chance to disappear
			if randf_range(0, 1) < 0.3:
				disappear()

func _on_body_entered(body: Node3D) -> void:
	# Check if body is valid before proceeding
	if body == null:
		return
		
	# Check if the body is the player or if it's a StaticBody3D that's part of the player
	var is_player = body.is_in_group("players")
	if not is_player and body is StaticBody3D:
		is_player = body.get_parent() and body.get_parent().is_in_group("players")
		
	# Only trigger if the body is the player and hasn't disappeared
	if is_player and not has_disappeared:
		player_on_platform = true
		# 30% chance to disappear
		if randf_range(0, 1) < 0.3:
			disappear()

func _on_body_exited(body: Node3D) -> void:
	if body and body.is_in_group("players"):
		player_on_platform = false

func disappear() -> void:
	if not has_disappeared:
		has_disappeared = true
		# Remove from groups before disconnecting signals
		if is_in_group("platform"):
			remove_from_group("platform")
		if is_in_group("ice"):
			remove_from_group("ice")
		# Disconnect the signals before freeing
		body_entered.disconnect(_on_body_entered)
		body_shape_entered.disconnect(_on_body_shape_entered)
		body_exited.disconnect(_on_body_exited)
		# Queue the platform for deletion
		queue_free()
		print("Platform disappeared!")
