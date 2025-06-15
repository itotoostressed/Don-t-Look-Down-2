extends Control
@onready var map = preload("res://map.tscn")
@onready var stats_label = $CenterContainer/VBoxContainer/StatsLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Show the cursor and enable input processing
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_process_input(true)
	
	# Connect the button's pressed signal to our handler
	$CenterContainer/VBoxContainer/Button.pressed.connect(_on_return_button_pressed)
	
	# Record death and display current stats
	record_death()
	display_stats()

func record_death() -> void:
	var stats = get_node("/root/Stats")
	if stats:
		stats.record_death()

func display_stats() -> void:
	var stats = get_node("/root/Stats")
	if stats:
		var stats_data = stats.get_stats()
		stats_label.text = "Stats at death:\nJumps: " + str(stats_data.jumps) + "\nDeaths: " + str(stats_data.deaths) + "\nClears: " + str(stats_data.clears)
	else:
		stats_label.text = "Stats not available"

# Called when the return button is pressed
func _on_return_button_pressed() -> void:
	# Re-enable map processing
	var map = get_tree().root.get_node_or_null("Map")
	if map:
		map.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Clean up any existing multiplayer peer
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# Find and clean up the map scene
	if map:
		map.queue_free()
	
	# Wait a frame to ensure cleanup is complete
	await get_tree().process_frame
	
	# Change to menu scene
	get_tree().change_scene_to_file("res://menu.tscn")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
