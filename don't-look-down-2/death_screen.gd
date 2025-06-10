extends Control

@onready var stats_label = $CenterContainer/VBoxContainer/StatsLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Show the cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Connect the button's pressed signal to our handler
	$CenterContainer/VBoxContainer/Button.pressed.connect(_on_return_button_pressed)
	
	# Display current stats
	display_stats()

func display_stats() -> void:
	var stats = get_node("/root/Stats")
	if stats:
		var stats_data = stats.get_stats()
		print("Death Screen - Current Stats:")
		print("Jumps: ", stats_data.jumps)
		print("Deaths: ", stats_data.deaths)
		print("Clears: ", stats_data.clears)
		
		stats_label.text = "Stats at death:\nJumps: " + str(stats_data.jumps) + "\nDeaths: " + str(stats_data.deaths) + "\nClears: " + str(stats_data.clears)
	else:
		print("Warning: Stats node not found in death screen!")
		stats_label.text = "Stats not available"

# Called when the return button is pressed
func _on_return_button_pressed() -> void:
	# Change to the menu scene
	get_tree().change_scene_to_file("res://menu.tscn")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
