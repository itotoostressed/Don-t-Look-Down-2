extends Node3D

@onready var player_scene = preload("res://Player.tscn")  # Make sure this path matches your player scene
@onready var lava = $lava
@onready var stats = $Stats
@onready var multiplayer_spawner = $MultiplayerSpawner

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

var players = {}
var world_generated = false

func _ready():
	print("Map: _ready called")
	
	# Set up MultiplayerSpawner
	multiplayer_spawner.spawn_function = spawn_player
	print("Map: MultiplayerSpawner spawn function set")
	
	# Connect MultiplayerSpawner signals
	multiplayer_spawner.spawned.connect(_on_spawned)
	print("Map: MultiplayerSpawner signals connected")
	
	# Initially hide the world
	visible = false
	
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Map: Multiplayer signals connected")
	
	# Only generate world on server
	if multiplayer.is_server():
		print("Map: Setting up server player")
		generate_platforms()
		await get_tree().create_timer(0.1).timeout
		generate_ladders()
		world_generated = true
		
		# Spawn server's player directly
		var server_player = spawn_player({"id": 1})
		if server_player:
			print("Map: Server player spawned successfully")
	else:
		print("Map: Setting up client")
		# Request world generation from server
		rpc_id(1, "request_world_generation")
		# Request player spawn from server
		rpc_id(1, "request_player_spawn")

@rpc("any_peer")
func request_world_generation():
	if multiplayer.is_server() and not world_generated:
		print("Map: Generating world for client")
		generate_platforms()
		await get_tree().create_timer(0.1).timeout
		generate_ladders()
		world_generated = true
		# Notify client that world is ready
		rpc_id(multiplayer.get_remote_sender_id(), "world_generation_complete")

@rpc("reliable")
func world_generation_complete():
	print("Map: World generation complete, making world visible")
	visible = true

@rpc("any_peer")
func request_player_spawn():
	var peer_id = multiplayer.get_remote_sender_id()
	print("Map: Received spawn request from peer: ", peer_id)
	multiplayer_spawner.spawn({"id": peer_id})

func spawn_player(data):
	print("Map: spawn_player called with data: ", data)
	var peer_id = data.id
	
	print("Map: Attempting to spawn player with peer ID: ", peer_id)
	print("Map: Current players: ", players.keys())
	print("Map: Is server: ", multiplayer.is_server())
	print("Map: My unique ID: ", multiplayer.get_unique_id())
	
	# Ensure we don't create duplicate players
	if players.has(peer_id):
		print("Map: Player with peer ID ", peer_id, " already exists")
		return players[peer_id]
	
	# Create new player instance
	print("Map: Creating new player instance for peer ID: ", peer_id)
	var new_player = load("res://player.tscn").instantiate()
	if not new_player:
		print("Map: Error - Failed to instantiate player scene")
		return null
	
	# Set up player
	new_player.name = str(peer_id)
	new_player.position = Vector3(0, 1.27678, 0)  # Initial spawn position
	
	# Add to scene tree
	print("Map: Adding player to scene tree with name: ", new_player.name)
	add_child(new_player, true)
	
	# Store in players dictionary
	players[peer_id] = new_player
	
	print("Map: Successfully spawned player with peer ID: ", peer_id)
	print("Map: Player is in tree: ", is_instance_valid(new_player) and new_player.is_inside_tree())
	print("Map: Player name: ", new_player.name)
	print("Map: Player path: ", new_player.get_path())
	
	return new_player

func _on_spawned(node):
	print("Map: Node spawned: ", node.name)
	print("Map: Node path: ", node.get_path())
	print("Map: Node authority: ", node.get_multiplayer_authority())
	print("Map: Is multiplayer authority: ", node.is_multiplayer_authority())
	
	# If this is a player node
	if node.is_in_group("players"):
		print("Map: Spawned node is a player")
		var player_id = int(node.name)
		players[player_id] = node
		
		# If this is our local player
		if player_id == multiplayer.get_unique_id():
			print("Map: This is our local player")
			player = node
			
			# Make sure the world is visible
			visible = true
			print("Map: World visibility set to: ", visible)

func _on_peer_connected(id: int):
	print("Map: Peer connected: ", id)
	if multiplayer.is_server():
		print("Map: Server received new peer connection: ", id)

func _on_peer_disconnected(id: int):
	print("Map: Peer disconnected: ", id)
	if players.has(id):
		print("Map: Cleaning up disconnected player: ", id)
		var disconnected_player = players[id]
		if is_instance_valid(disconnected_player):
			disconnected_player.queue_free()
		players.erase(id)
		print("Map: Successfully cleaned up player: ", id)

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