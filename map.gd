extends Node3D

var player = null  # Remove @onready and initialize as null
@onready var lava = $lava
@onready var stats = $Stats
@onready var world = $World
@onready var platforms = $World/Platforms
@onready var ladders = $World/Ladders
var platformScene = preload("res://platform.tscn")
var ladderScene = preload("res://ladder.tscn") # Make sure to load your ladder scene
var player_scene = preload("res://player.tscn")

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
var min_y_increase = 8.0 # Smaller minimum step
var max_y_increase = 12.0  # Larger maximum step
var no_overlap_radius = 4.5
var platform_half_width = 1.5
var platform_half_depth = 1.5
const LADDER_HEIGHT = 7.85 # Your ladder height
var changeDirX = false
var changeDirZ = false

# Multiplayer variables
var is_client = false
var test_number = 0

func _ready():
	print("Map: _ready called")
	
	# Make sure the world is visible from the start
	visible = true
	print("Map: World visibility set to: ", visible)
	
	# Set up spawn functions for the spawners
	$MultiplayerSpawner2.spawn_function = _spawn_platform
	$MultiplayerSpawner3.spawn_function = _spawn_ladder
	
	# Connect multiplayer signals (only once)
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Map: Multiplayer signals connected")
	
	# Set the spawn function for MultiplayerSpawner
	$MultiplayerSpawner.spawn_function = _spawn
	if ($MultiplayerSpawner.spawn_function == _spawn):
		print("Map: Spawn function set for MultiplayerSpawner")
	
	# Only set up initial player authority if we're the server
	if multiplayer.is_server():
		print("Map: Setting up initial player authority")
		# Try to get the player node if it exists
		player = get_node_or_null("Player")
		if player:
			# Move the player to be a child of the Map node if it isn't already
			if player.get_parent() != self:
				var original_transform = player.global_transform
				player.get_parent().remove_child(player)
				add_child(player)
				player.global_transform = original_transform
			player.set_multiplayer_authority(1)  # Server owns the player
	else:
		# For clients, we'll wait for the MultiplayerSpawner to spawn the player
		print("Map: Client mode - waiting for player spawn")
		# Try to get the player node if it exists
		player = get_node_or_null("Player")
		if player:
			print("Map: Removing pre-instantiated player for client")
			player.queue_free()
			player = null
	
	# Ensure we have the necessary nodes (except Player for clients)
	world = get_node_or_null("World")
	platforms = get_node_or_null("World/Platforms")
	ladders = get_node_or_null("World/Ladders")

func start_single_player():
	print("Map: Starting single player mode")
	visible = true
	
	# Generate platforms and ladders
	generate_platforms()
	await get_tree().create_timer(0.1).timeout
	generate_ladders()
	
	# Create and set up single player
	print("Map: Creating single player")
	var single_player = player_scene.instantiate()
	if not single_player:
		print("Map: ERROR - Failed to instantiate single player")
		return
		
	single_player.name = str(1)  # Single player is always ID 1
	single_player.position = Vector3(0, 5, 0)  # Raised spawn position
	
	# Add to scene tree BEFORE setting authority
	print("Map: Adding single player to scene tree")
	add_child(single_player, true)
	
	# Set authority AFTER adding to tree
	single_player.set_multiplayer_authority(1)
	print("Map: Single player authority set to: ", single_player.get_multiplayer_authority())
	
	# Store player reference
	player = single_player
	print("Map: Single player reference stored")
	
	# Make sure the player is visible
	single_player.show()
	print("Map: Single player visibility set to: ", single_player.visible)
	
	# Set mouse mode
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Map: Mouse mode set to captured")

func start_multiplayer_host():
	print("Map: Starting multiplayer host")
	visible = true
	
	# Generate platforms and ladders
	generate_platforms()
	await get_tree().create_timer(0.1).timeout
	generate_ladders()
	
	# Create and set up host player
	print("Map: Creating host player")
	var host_player = player_scene.instantiate()
	if not host_player:
		print("Map: ERROR - Failed to instantiate host player")
		return
		
	host_player.name = str(1)  # Host is always ID 1
	host_player.position = Vector3(0, 5, 0)  # Raised spawn position
	
	# Add to scene tree BEFORE setting authority
	print("Map: Adding host player to scene tree")
	add_child(host_player, true)
	
	# Set authority AFTER adding to tree
	host_player.set_multiplayer_authority(1)
	print("Map: Host player authority set to: ", host_player.get_multiplayer_authority())
	
	# Store player reference
	player = host_player
	print("Map: Host player reference stored")
	
	# Make sure the player is visible
	host_player.show()
	print("Map: Host player visibility set to: ", host_player.visible)
	
	# Set mouse mode
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Map: Mouse mode set to captured")

func start_multiplayer_client():
	print("Map: Starting multiplayer client")
	visible = true
	is_client = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Make sure the world is visible
	visible = true
	print("Map: World visibility set to: ", visible)
	
	# Ensure world nodes exist
	world = get_node_or_null("World")
	if not world:
		print("Map: ERROR - World node not found!")
		return
		
	platforms = get_node_or_null("World/Platforms")
	if not platforms:
		print("Map: ERROR - Platforms node not found!")
		return
		
	ladders = get_node_or_null("World/Ladders")
	if not ladders:
		print("Map: ERROR - Ladders node not found!")
		return

# Called by MultiplayerSpawner when a new player is spawned
func _spawn(data):
	print("Map: _spawn called with data: ", data)
	print("Map: Current peer ID: ", multiplayer.get_unique_id())
	print("Map: Is server: ", multiplayer.is_server())
	
	var new_player = player_scene.instantiate()
	
	# Set the player's name to the peer ID from the spawn data
	var peer_id = data.get("id", multiplayer.get_unique_id())
	new_player.name = str(peer_id)
	print("Map: Created new player with name: ", new_player.name)
	
	# Add to players group
	new_player.add_to_group("players")
	
	# Set initial position
	new_player.position = Vector3(0, 5, 0)  # Raised spawn position
	
	# Add to scene tree
	add_child(new_player, true)
	print("Map: Added new player to scene tree")
	
	# Set authority to the peer ID
	new_player.set_multiplayer_authority(peer_id)
	print("Map: Set player authority to: ", peer_id)
	
	# Store reference if this is our local player
	if new_player.name == str(multiplayer.get_unique_id()):
		player = new_player
		print("Map: Local player reference stored")
	
	return new_player

@rpc("any_peer", "reliable")
func _on_player_death():
	if multiplayer.is_server():
		get_tree().change_scene_to_file("res://death_screen.tscn")

func _on_peer_connected(id: int):
	print("Map: Peer connected signal received for ID: ", id)
	print("Map: Is server: ", multiplayer.is_server())
	print("Map: My unique ID: ", multiplayer.get_unique_id())
	
	# Only handle peer connection on server
	if multiplayer.is_server():
		print("Map: Server received new peer connection: ", id)
		# Spawn the player for the new peer
		$MultiplayerSpawner.spawn({"id": id})

func _on_peer_disconnected(id: int):
	print("Map: Peer disconnected signal received for ID: ", id)
	
	# Clean up the player
	if player and player.name == str(id):
		print("Map: Cleaning up disconnected player: ", id)
		if is_instance_valid(player):
			# Remove from scene tree
			if player.is_inside_tree():
				player.queue_free()
			print("Map: Successfully cleaned up player: ", id)
		else:
			print("Map: Player instance was already invalid")

@rpc("any_peer", "reliable")
func request_test_number():
	print("Map: Server received test number request from peer: ", multiplayer.get_remote_sender_id())
	if multiplayer.is_server():
		var test_number = randi() % 1000  # Random number between 0 and 999
		print("Map: Server sending test number: ", test_number)
		rpc_id(multiplayer.get_remote_sender_id(), "receive_test_number", test_number)

@rpc("authority", "reliable")
func receive_test_number(number: int):
	print("Map: Client received test number: ", number)
	print("Map: My unique ID: ", multiplayer.get_unique_id())
	# Echo back to server to confirm receipt
	rpc_id(1, "confirm_test_number", number)

func generate_ladders():
	var platforms = get_tree().get_nodes_in_group("platform") + get_tree().get_nodes_in_group("ice")
	var ladders_placed = 0
	
	# Sort platforms by height
	platforms.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	
	if platforms.size() < 2:
		print("Not enough platforms for ladders!")
		return
	
	for i in range(platforms.size() - 1):
		var lower_platform = platforms[i]
		var upper_platform = platforms[i + 1]
		var height_diff = upper_platform.global_position.y - lower_platform.global_position.y
		
		if height_diff >= 2.5:
			# Calculate the direction from lower to upper platform
			var direction_to_upper = upper_platform.global_position - lower_platform.global_position
			direction_to_upper.y = 0  # Remove vertical component for horizontal direction only
			direction_to_upper = direction_to_upper.normalized()
			
			# Calculate ladder position on the edge of the lower platform
			# Scale by platform size to place it at the edge
			var edge_offset = direction_to_upper * (platform_half_width * 0.8)  # 0.8 to keep it slightly inset
			
			# Calculate position for the ladder
			var ladder_position = lower_platform.global_position + edge_offset + Vector3(0, 3.925, 0)
			
			# Spawn the ladder through the spawner
			$MultiplayerSpawner3.spawn({
				"position": ladder_position,
				"rotation": Vector3(0, deg_to_rad(90) if abs(direction_to_upper.x) > abs(direction_to_upper.z) else 0, 0)
			})
			
			ladders_placed += 1
			
			# Use more generous ladder limit
			if ladders_placed >= platform_count:
				break

func _position_within_bounds(position: Vector3) -> bool:
	# Check if the platform (including its size) stays within bounds
	var platform_min_x = position.x - platform_half_width
	var platform_max_x = position.x + platform_half_width
	var platform_min_z = position.z - platform_half_depth
	var platform_max_z = position.z + platform_half_depth
	
	return (platform_min_x >= min_x_pos and platform_max_x <= max_x_pos and platform_min_z >= min_z_pos and platform_max_z <= max_z_pos)

func _clamp_position_to_bounds(position: Vector3) -> Vector3:
	# Clamp the position to ensure the platform stays within bounds
	var clamped_position = position
	
	# Clamp X position
	clamped_position.x = clamp(position.x, 
		min_x_pos + platform_half_width, 
		max_x_pos - platform_half_width)
	
	# Clamp Z position
	clamped_position.z = clamp(position.z, 
		min_z_pos + platform_half_depth, 
		max_z_pos - platform_half_depth)
	
	return clamped_position

func _position_overlaps(position: Vector3, existing_platforms: Array) -> bool:
	# Create bounding box for new platform with full platform dimensions
	var new_min = Vector3(
		position.x - platform_half_width,
		position.y - 2.0, # Height buffer below platform
		position.z - platform_half_depth
	)
	var new_max = Vector3(
		position.x + platform_half_width,
		position.y + 2.0, # Height buffer above platform
		position.z + platform_half_depth
	)
	
	for existing in existing_platforms:
		# Create bounding box for existing platform with same dimensions
		var existing_min = Vector3(
			existing.position.x - platform_half_width,
			existing.position.y - 2.0, # Height buffer below platform
			existing.position.z - platform_half_depth
		)
		var existing_max = Vector3(
			existing.position.x + platform_half_width,
			existing.position.y + 2.0, # Height buffer above platform
			existing.position.z + platform_half_depth
		)
		
		# Check for AABB overlap using full platform dimensions
		if (new_min.x <= existing_max.x && new_max.x >= existing_min.x &&
			new_min.y <= existing_max.y && new_max.y >= existing_min.y &&
			new_min.z <= existing_max.z && new_max.z >= existing_min.z):
			return true
	
	return false

func generate_platforms():
	var last_position = Vector3(0, -2.5, 0)  # Set initial platform at y=2 instead of y=0
	var platform_positions = []
	
	for i in range(platform_count):
		var new_position = Vector3.ZERO
		var valid_position_found = false
		
		for attempt in range(platform_count * 2):  # Increased attempts since we have more constraints
			var y_increase = randf_range(min_y_increase, max_y_increase)
			# Calculate random offsets
			if (i == 0):
				y_increase = 3
			
			# Separate direction changes with different probabilities
			if randf() > 0.35:  # 35% chance to flip X direction
				changeDirX = !changeDirX
			if randf() > 0.45:  # 45% chance to flip Z direction
				changeDirZ = !changeDirZ
			
			# Generate varied X offset with actual variation
			var x_offset = randf_range(1.5, 6.0)  # Range from 1.5 to 6.0 units
			if randf() > 0.85:  # 15% chance to not move in X at all
				x_offset = 0
			elif not changeDirX:
				x_offset *= -1  # Apply negative direction if changeDirX is false
			
			# Generate varied Z offset with actual variation  
			var z_offset = randf_range(2.0, 8.0)  # Range from 2.0 to 8.0 units
			if randf() > 0.8:   # 20% chance to not move in Z at all
				z_offset = 0
			elif not changeDirZ:
				z_offset *= -1  # Apply negative direction if changeDirZ is false
			
			# Optional: Add cluster mode for tight groups
			if randf() > 0.9:  # 10% chance for cluster mode
				x_offset = randf_range(0.5, 2.0)
				z_offset = randf_range(0.5, 2.0)
				if not changeDirX: x_offset *= -1
				if not changeDirZ: z_offset *= -1
			
			new_position = Vector3(
				last_position.x + x_offset,
				last_position.y + y_increase,
				last_position.z + z_offset
			)
			
			# Check if position is within bounds
			if _position_within_bounds(new_position) and not _position_overlaps(new_position, platform_positions):
				valid_position_found = true
				break
		
		if not valid_position_found:
			print("Warning: Couldn't find valid position after ", platform_count * 2, " attempts")
			# If we can't find a valid position, try to place it within bounds anyway
			new_position = _clamp_position_to_bounds(new_position)
		
		# Spawn the platform through the spawner
		var platformType = randi() % 2  # 0-1 inclusive
		$MultiplayerSpawner2.spawn({
			"position": new_position,
			"type": platformType  # 0 for regular, 1 for ice
		})
		
		platform_positions.append({
			"position": new_position,
			"half_width": platform_half_width,
			"half_depth": platform_half_depth
		})
		last_position = new_position

# Add spawn functions for the spawners
func _spawn_platform(data):
	var platform = platformScene.instantiate()
	platform.position = data.position
	
	# Set platform type
	if data.type == 1:  # Ice platform
		platform.get_node("texture").material_override = load("res://ice_texture.tres")
		platform.add_to_group("ice")
	else:  # Regular platform
		platform.get_node("texture").material_override = load("res://wood.tres")
		platform.add_to_group("platform")
	
	return platform

func _spawn_ladder(data):
	var ladder = ladderScene.instantiate()
	ladder.position = data.position
	ladder.rotation = data.rotation
	return ladder

func _process(delta: float) -> void:
	if visible:  # Only check win condition if world is visible
		#print("Map: _process called, world is visible")
		checkWin()
	else:
		print("Map: _process called, world is not visible")

func is_multiplayer() -> bool:
	return multiplayer.multiplayer_peer != null

func show_win_screen():
	if has_node("Stats"):
		var stats = get_node("Stats")
		stats.record_clear()
		stats.save_stats()
	get_tree().change_scene_to_file("res://win_screen.tscn")

func checkWin():
	# For single player, we don't need to check if we're the server
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
		
	# Get all platforms and find the highest one
	var platforms = get_tree().get_nodes_in_group("platform") + get_tree().get_nodes_in_group("ice")
	
	if platforms.size() == 0:
		print("No platforms found, returning")
		return
	
	# Find the highest platform
	var highest_platform = null
	for platform in platforms:
		if platform and is_instance_valid(platform):
			if highest_platform == null or platform.global_position.y > highest_platform.global_position.y:
				highest_platform = platform
	
	if highest_platform == null:
		print("No valid highest platform found, returning")
		return

	# Get all players in the scene
	var players = get_tree().get_nodes_in_group("players")
	if players.size() == 0:
		print("No players found in scene, returning")
		return

	# Check each player's position
	for current_player in players:
		if not current_player or not is_instance_valid(current_player):
			continue
			
		# Check if player is within the area of the highest platform
		var player_pos = current_player.global_position
		var platform_pos = highest_platform.global_position
		
		var x_distance = abs(player_pos.x - platform_pos.x)
		var z_distance = abs(player_pos.z - platform_pos.z)
		var y_distance = abs(player_pos.y - platform_pos.y)
		
		if (x_distance <= platform_half_width and 
			z_distance <= platform_half_depth and 
			y_distance <= 3.0):
			print("Win condition met for player: ", current_player.name)
			if has_node("Stats"):
				var stats = get_node("Stats")
				stats.record_clear()
				stats.save_stats()
			
			# Change to win screen - let it handle cleanup
			get_tree().change_scene_to_file("res://win_screen.tscn")
			return

func _on_lava_body_entered(body: Node3D) -> void:
	if body == player:
		if multiplayer.is_server():
			# Handle death on server
			get_tree().change_scene_to_file("res://death_screen.tscn")
		else:
			# Notify server of death
			rpc_id(1, "_on_player_death")

@rpc("any_peer", "reliable")
func request_world_data():
	if multiplayer.is_server():
		print("Map: Server received world data request from peer: ", multiplayer.get_remote_sender_id())
		# Send platform and ladder data to the requesting client
		var platform_data = []
		var ladder_data = []
		
		# Collect platform data
		for platform in platforms.get_children():
			platform_data.append({
				"position": platform.position,
				"rotation": platform.rotation,
				"scale": platform.scale
			})
		
		# Collect ladder data
		for ladder in ladders.get_children():
			ladder_data.append({
				"position": ladder.position,
				"rotation": ladder.rotation,
				"scale": ladder.scale
			})
		
		print("Map: Sending ", platform_data.size(), " platforms and ", ladder_data.size(), " ladders to peer: ", multiplayer.get_remote_sender_id())
		
		# Send data to requesting client
		rpc_id(multiplayer.get_remote_sender_id(), "receive_world_data", platform_data, ladder_data)
		print("Map: Sent world data to peer: ", multiplayer.get_remote_sender_id())

@rpc("authority", "reliable")
func receive_world_data(platform_data, ladder_data):
	print("Map: Received world data from server - Platforms: ", platform_data.size(), " Ladders: ", ladder_data.size())
	
	# Clear existing platforms and ladders
	for child in platforms.get_children():
		child.queue_free()
	for child in ladders.get_children():
		child.queue_free()
	
	# Create platforms from received data
	for data in platform_data:
		var platform = platformScene.instantiate()
		platforms.add_child(platform)
		platform.position = data.position
		platform.rotation = data.rotation
		platform.scale = data.scale
	
	# Create ladders from received data
	for data in ladder_data:
		var ladder = ladderScene.instantiate()
		ladders.add_child(ladder)
		ladder.position = data.position
		ladder.rotation = data.rotation
		ladder.scale = data.scale
	
	print("Map: World replication complete - Created ", platform_data.size(), " platforms and ", ladder_data.size(), " ladders")
