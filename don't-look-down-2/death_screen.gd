extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Show the cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Connect the button's pressed signal to our handler
	$CenterContainer/VBoxContainer/Button.pressed.connect(_on_return_button_pressed)


# Called when the return button is pressed
func _on_return_button_pressed() -> void:
	# Change to the menu scene
	get_tree().change_scene_to_file("res://menu.tscn")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
