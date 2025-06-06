extends StaticBody3D

var has_printed = false

func _ready() -> void:
	# Connect the body entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Only print once per platform
	if not has_printed:
		# 10% chance to print
		if randf() < 0.1:
			print("I'm disappearing")
			has_printed = true 