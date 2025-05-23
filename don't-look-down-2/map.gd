extends Node3D

@onready var player = $Player
var platformScene = load("res://platform.tscn")

func _ready():
	
	for i in range(5):
		var platform_instance = platformScene.instantiate()
		platform_instance.position = Vector3(4* i, i * 1, 0)
		add_child(platform_instance)
