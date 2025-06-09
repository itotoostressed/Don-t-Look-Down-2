extends Area3D

var has_disappeared = false

func _ready() -> void:
	# Connect the body entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Only trigger if the body is the player
	if body.is_in_group("players") and not has_disappeared:
		disappear()

func disappear() -> void:
	if not has_disappeared:
		has_disappeared = true
		# Queue the platform for deletion
		queue_free()
		print("Platform disappeared!")
