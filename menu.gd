func _on_start_button_pressed() -> void:
	# Hide the menu
	hide()
	# Change to the map scene
	get_tree().change_scene_to_file("res://map.tscn")