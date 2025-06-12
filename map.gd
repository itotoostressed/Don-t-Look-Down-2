extends Node3D

@onready var player_scene = preload("res://Player.tscn")  # Make sure this path matches your player scene
@onready var lava = $lava
@onready var stats = $Stats

var platformScene = load("res://platform.tscn")
var ladderScene = load("res://ladder.tscn")

# Configuration variables
var platform_count = 30
var max_x_pos = 50
var max_z_pos = 50
var min_x_pos = 0
var min_z_pos = 0
var min_x_distance = -4.0
var max_x_distance = 4.0
var min_z_distance = -6.0
var max_z_distance = 6.0
var min_y_increase = 8.0
var max_y_increase = 12.0
var no_overlap_radius = 4.5
var platform_half_width = 1.5
var platform_half_depth = 1.5
const LADDER_HEIGHT = 7.85
var changeDirX = false
var changeDirZ = false

func _ready():
	# Set up multiplayer
	if multiplayer.is_server():
		generate_platforms()
		await get_tree().create_timer(0.1).timeout
		generate_ladders()
	
	# Set up player
	if multiplayer.is_server():
		# Spawn the server's player
		spawn_player.rpc_id(1, 1)
	elif multiplayer.is_client():
		# Request player spawn from server
		request_player_spawn.rpc_id(1)

@rpc("any_peer")
func request_player_spawn():
	var peer_id = multiplayer.get_remote_sender_id()
	spawn_player.rpc_id(peer_id, peer_id)

@rpc("any_peer", "call_local")
func spawn_player(id: int):
	var new_player = player_scene.instantiate()
	new_player.name = str(id)
	new_player.set_multiplayer_authority(id)  # Set the authority to the correct peer
	add_child(new_player, true)  # true for force_readable_name
	
	# If this is our player, set up input
	if id == multiplayer.get_unique_id():
		new_player.set_process_input(true)
		new_player.add_to_group("players")

func _process(delta: float) -> void:
	checkWin()

# ... rest of your existing code ...

func _on_lava_body_entered(body: Node3D) -> void:
	if body == player:
		if multiplayer.is_server():
			player_died.rpc()
		else:
			get_tree().change_scene_to_file("res://death_screen.tscn")

@rpc("any_peer", "call_local")
func player_died():
	get_tree().change_scene_to_file("res://death_screen.tscn")

func checkWin():
	if not multiplayer.is_server():
		return
		
	# Get all platforms and find the highest one
	var platforms = get_tree().get_nodes_in_group("platform") + get_tree().get_nodes_in_group("ice")
	
	if platforms.size() == 0:
		return
	
	# Find the highest platform
	var highest_platform = null
	for platform in platforms:
		if platform and is_instance_valid(platform):
			if highest_platform == null or platform.global_position.y > highest_platform.global_position.y:
				highest_platform = platform
	
	if highest_platform == null:
		return
	
	# Check if any player is on the highest platform
	for player_node in get_tree().get_nodes_in_group("players"):
		var player_pos = player_node.global_position
		var platform_pos = highest_platform.global_position
		
		var x_distance = abs(player_pos.x - platform_pos.x)
		var z_distance = abs(player_pos.z - platform_pos.z)
		var y_distance = abs(player_pos.y - platform_pos.y)
		
		if (x_distance <= platform_half_width and 
			z_distance <= platform_half_depth and 
			y_distance <= 3.0):
			if has_node("Stats"):
				var stats = get_node("Stats")
				stats.record_clear()
				stats.save_stats()
			game_won.rpc()

@rpc("any_peer", "call_local")
func game_won():
	get_tree().change_scene_to_file("res://win_screen.tscn") 