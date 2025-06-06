extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$CenterContainer/VBoxContainer/Button.pressed.connect(_on_return_button_pressed)

func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

func _process(delta: float) -> void:
	pass 
