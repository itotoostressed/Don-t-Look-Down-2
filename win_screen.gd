extends Control

func _ready() -> void:
	# Show the cursor and enable input processing
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_process_input(true)
	
	# Connect the button's pressed signal
	$CenterContainer/VBoxContainer/Button.pressed.connect(_on_return_button_pressed)

func _on_return_button_pressed() -> void:
	# Clean up any existing multiplayer peer
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# Find and clean up the map scene
	var map = get_tree().root.get_node_or_null("Map")
	if map:
		map.queue_free()
	
	# Wait a frame to ensure cleanup is complete
	await get_tree().process_frame
	
	# Change to menu scene
	get_tree().change_scene_to_file("res://menu.tscn")

func _process(delta: float) -> void:
	pass 
