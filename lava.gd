extends Area3D

var yPos = 0
var is_rising = false

@onready var mesh = $MeshInstance3D

func _ready():
	# Make sure the mesh is visible
	if mesh:
		mesh.visible = true
	# Set up multiplayer synchronization
	if multiplayer.multiplayer_peer != null:
		set_multiplayer_authority(1)  # Server owns the lava

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_rising:
		global_position.y += .1

func rise():
	is_rising = true

func start_rising():
	is_rising = true

func _on_body_entered(body: Node3D) -> void:
	if body and body.is_in_group("players"):
		# Pause only the map scene
		var map = get_tree().root.get_node_or_null("Map")
		if map:
			map.process_mode = Node.PROCESS_MODE_DISABLED
		
		# Record death in stats
		var stats = get_node("/root/Stats")
		if stats:
			stats.record_death()
			stats.save_stats()
		
		# Change to death screen
		get_tree().change_scene_to_file("res://death_screen.tscn")
