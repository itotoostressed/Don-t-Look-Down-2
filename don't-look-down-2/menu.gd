extends Control

@onready var stats_panel = $CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel
@onready var stats_container = $CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel/StatsContainer
@onready var stats_button = $CenterContainer/VBoxContainer/ButtonContainer/StatsButton
@onready var start_button = $CenterContainer/VBoxContainer/ButtonContainer/StartButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Show the cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Connect the buttons' pressed signals to our handlers
	start_button.pressed.connect(_on_start_button_pressed)
	stats_button.pressed.connect(_on_stats_button_pressed)
	
	# Initially hide the stats panel
	stats_panel.visible = false
	
	# Connect to stats update signal
	var stats = get_node("/root/Stats")
	if stats:
		stats.stats_updated.connect(_on_stats_updated)
	
	# Update stats display
	update_stats_display()


# Called when the start button is pressed
func _on_start_button_pressed() -> void:
	# Change to the map scene
	get_tree().change_scene_to_file("res://map.tscn")

func _on_stats_button_pressed() -> void:
	# Toggle stats panel visibility
	stats_panel.visible = !stats_panel.visible
	update_stats_display()

func _on_stats_updated() -> void:
	if stats_panel.visible:
		update_stats_display()

func update_stats_display() -> void:
	# Get the stats node from the autoload/singleton
	var stats = get_node("/root/Stats")
	if stats:
		var stats_data = stats.get_stats()
		print("Updating stats display with: ", stats_data)  # Debug print
		$CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel/StatsContainer/JumpsLabel.text = "Jumps: " + str(stats_data.jumps)
		$CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel/StatsContainer/DeathsLabel.text = "Deaths: " + str(stats_data.deaths)
		$CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel/StatsContainer/ClearsLabel.text = "Clears: " + str(stats_data.clears)
	else:
		print("Warning: Stats node not found when updating display!")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
