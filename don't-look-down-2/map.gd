extends Node3D

@onready var player = $Player
@onready var lava = $lava
@onready var stats = $Stats
@onready var multiplayer_spawner = $MultiplayerSpawner
var platformScene = load("res://platform.tscn")
var ladderScene = load("res://ladder.tscn") # Make sure to load your ladder scene

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
var players = {}  # Dictionary to store player instances
var is_client = false

func _ready():
	print("Map: _ready called")
	
	# Initially hide the world
	visible = false
	
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Map: Multiplayer signals connected")
	
	# Only set up initial player authority if we're the server
	if multiplayer.is_server():
		print("Map: Setting up initial player authority")
		if player:
			# Move the player to be a child of the Map node if it isn't already
			if player.get_parent() != self:
				var original_transform = player.global_transform
				player.get_parent().remove_child(player)
				add_child(player)
				player.global_transform = original_transform
			player.set_multiplayer_authority(1)  # Server owns the player
			# Add to players dictionary
			players[1] = player
	else:
		# Remove the pre-instantiated player for clients
		if player:
			print("Map: Removing pre-instantiated player for client")
			player.queue_free()
			player = null
	
	# Test networking if we're a client
	if not multiplayer.is_server():
		print("Map: Client requesting test number from server")
		rpc_id(1, "request_test_number")

func start_single_player():
	print("Map: Starting single player mode")
	visible = true
	generate_platforms()
	await get_tree().create_timer(0.1).timeout
	generate_ladders()
	
	# Set up single player
	if player:
		player.name = str(1)
		player.set_multiplayer_authority(1)
		player.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		# Add to players dictionary
		players[1] = player
		
		print("Map: Single player setup complete")

func start_multiplayer_host():
	print("Map: Starting multiplayer host")
	visible = true
	
	# Generate platforms and ladders
	generate_platforms()
	await get_tree().create_timer(0.1).timeout
	generate_ladders()
	print("Map: Platforms and ladders generated")

@rpc("any_peer", "reliable")
func request_player_spawn(data):
	print("Map: Received spawn request from peer: ", multiplayer.get_remote_sender_id())
	if multiplayer.is_server():
		print("Map: Server handling spawn request")
		var spawned_player = await spawn_player(data)
		if spawned_player:
			print("Map: Server successfully spawned player")
			# The player_ready RPC will be sent from spawn_player
		else:
			print("Map: Server failed to spawn player")
	else:
		print("Map: Non-server received spawn request, ignoring")

@rpc("authority", "reliable")
func player_ready(data):
	print("Map: Received player_ready from server")
	print("Map: Data received: ", data)
	print("Map: My unique ID: ", multiplayer.get_unique_id())
	if data.id == multiplayer.get_unique_id():
		print("Map: This is our player, setting up")
		if data.has("path"):
			print("Map: Player path from server: ", data.path)
			setup_local_player(data.id, data.path)
		else:
			print("Map: Error - No path provided in player_ready data")
	else:
		print("Map: Received player_ready for different ID. Expected: ", multiplayer.get_unique_id(), " Got: ", data.id)

func setup_local_player(player_id: int, player_path: String = ""):
	print("Map: Setting up local player with ID: ", player_id)
	print("Map: Current scene tree:")
	# Print entire scene tree for debugging
	print_tree()
	
	# Try to find the player in the scene tree
	var local_player = null
	var possible_paths = []  # Declare at the start of the function
	
	if player_path != "":
		print("Map: Trying to find player using path: ", player_path)
		# Try different path formats
		possible_paths = [
			str(player_id),  # Just the ID (most likely to work)
			player_path,  # Original path
			player_path.substr("/root/World/".length()) if player_path.begins_with("/root/World/") else "",  # Relative path
		]
		
		print("Map: Trying possible paths:")
		for path in possible_paths:
			if path.is_empty():
				continue
			print("  - Trying path: ", path)
			local_player = get_node_or_null(path)
			if local_player:
				print("  - Found player at path: ", path)
				print("  - Player name: ", local_player.name)
				print("  - Player authority: ", local_player.get_multiplayer_authority())
				break
	else:
		print("Map: Trying to find player using name: ", str(player_id))
		local_player = get_node_or_null(str(player_id))
	
	if local_player:
		print("Map: Found local player in scene tree")
		print("Map: Player path: ", local_player.get_path())
		print("Map: Player name: ", local_player.name)
		print("Map: Player is in tree: ", local_player.is_inside_tree())
		print("Map: Player parent: ", local_player.get_parent().name if local_player.get_parent() else "None")
		
		players[player_id] = local_player
		print("Map: Setting up local player camera and input")
		local_player.show()
		
		# Enhanced authority verification
		print("Map: Verifying player authority before setup")
		print("Map: Current authority: ", local_player.get_multiplayer_authority())
		print("Map: Expected authority: ", player_id)
		print("Map: Is multiplayer authority: ", local_player.is_multiplayer_authority())
		print("Map: My unique ID: ", multiplayer.get_unique_id())
		
		if local_player.get_multiplayer_authority() != player_id:
			print("Map: Fixing player authority")
			local_player.set_multiplayer_authority(player_id)
			# Verify authority was set correctly
			print("Map: New authority: ", local_player.get_multiplayer_authority())
			print("Map: Is multiplayer authority after fix: ", local_player.is_multiplayer_authority())
		
		if local_player.has_node("Head/Camera3D"):
			var camera = local_player.get_node("Head/Camera3D")
			camera.current = true
			print("Map: Camera set as current")
		else:
			print("Map: Warning - Could not find camera node")
		
		# Enable input and physics processing
		local_player.set_process_input(true)
		local_player.set_physics_process(true)
		print("Map: Input and physics processing enabled")
		print("Map: Can process input: ", local_player.can_process())
		print("Map: Can process physics: ", local_player.can_physics_process())
		
		print("Map: Local player setup complete")
		print("Map: Final player authority: ", local_player.get_multiplayer_authority())
		print("Map: Final is multiplayer authority: ", local_player.is_multiplayer_authority())
		
		# Make sure the world is visible
		visible = true
		print("Map: World visibility set to: ", visible)
		
		# Notify server that player setup is complete
		if not multiplayer.is_server():
			rpc_id(1, "player_setup_complete", {"id": player_id})
	else:
		print("Map: Could not find player, will try again")
		print("Map: Looking for player with name: ", str(player_id))
		# If we can't find the player, try again after a longer delay
		await get_tree().create_timer(1.0).timeout  # Increased timeout to 1 second
		
		# Try to find the player again with all possible paths
		if player_path != "":
			print("Map: Retrying with all possible paths:")
			for path in possible_paths:
				if path.is_empty():
					continue
				print("  - Retrying path: ", path)
				local_player = get_node_or_null(path)
				if local_player:
					print("  - Found player at path: ", path)
					print("  - Player name: ", local_player.name)
					print("  - Player authority: ", local_player.get_multiplayer_authority())
					break
		else:
			local_player = get_node_or_null(str(player_id))
			
		if local_player:
			print("Map: Found player on second attempt")
			setup_local_player(player_id, player_path)
		else:
			print("Map: Still could not find player, requesting spawn from server")
			# Request spawn from server if we still can't find the player
			if not multiplayer.is_server():
				print("Map: Requesting spawn from server for player ID: ", player_id)
				rpc_id(1, "request_player_spawn", {"id": player_id})

func start_multiplayer_client():
	print("Map: Starting multiplayer client")
	visible = true
	is_client = true
	
	var client_id = multiplayer.get_unique_id()
	print("Map: Client ID: ", client_id)
	
	# Request player spawn through MultiplayerSpawner
	var spawn_data = {"id": client_id}
	print("Map: Requesting player spawn with data: ", spawn_data)
	multiplayer_spawner.spawn(spawn_data)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Map: Client player spawn requested")
	
	# Generate platforms and ladders
	generate_platforms()
	await get_tree().create_timer(0.1).timeout
	generate_ladders()
	print("Map: Platforms and ladders generated")

# This function is called by MultiplayerSpawner to spawn players
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
	
	var new_player = null
	
	# If this is the server (peer_id == 1) and we have a pre-instantiated player, use it
	if peer_id == 1 and player != null:
		print("Map: Using pre-instantiated player for server")
		new_player = player
		new_player.name = str(peer_id)
	else:
		# For all other cases, create a new player instance
		print("Map: Creating new player instance for peer ID: ", peer_id)
		new_player = load("res://player.tscn").instantiate()
		new_player.name = str(peer_id)
		new_player.position = Vector3(0, 1.27678, 0)  # Initial spawn position
	
	# Set up multiplayer properties
	print("Map: Setting multiplayer authority for peer ID: ", peer_id)
	new_player.set_multiplayer_authority(peer_id)
	
	# Only add to scene tree if it's not the pre-instantiated player
	if new_player != player:
		print("Map: Adding player to scene tree with name: ", new_player.name)
		add_child(new_player, true)
	
	# Store in players dictionary
	players[peer_id] = new_player
	
	print("Map: Successfully spawned player with peer ID: ", peer_id)
	print("Map: Player authority: ", new_player.get_multiplayer_authority())
	print("Map: Player is in scene tree: ", is_instance_valid(new_player) and new_player.is_inside_tree())
	print("Map: Player name: ", new_player.name)
	print("Map: Player path: ", new_player.get_path())
	
	# If we're the server, make sure the player is properly replicated
	if multiplayer.is_server():
		print("Map: Server ensuring player replication")
		# Force a network update
		new_player.set_multiplayer_authority(peer_id)
		# Make sure the player is visible
		new_player.show()
		
		# Notify the client that the player is ready
		if peer_id != 1:  # Don't notify the server
			print("Map: Notifying client ", peer_id, " that player is ready")
			# Send the full path to the client
			var spawn_data = {
				"id": peer_id,
				"path": new_player.get_path()
			}
			# Wait a frame to ensure the player is replicated
			await get_tree().process_frame
			# Force replication of the player node
			new_player.set_multiplayer_authority(peer_id)
			# Send the RPC
			print("Map: Sending player_ready RPC to client ", peer_id, " with data: ", spawn_data)
			rpc_id(peer_id, "player_ready", spawn_data)
	
	return new_player

func _on_peer_connected(id: int):
	print("Map: Peer connected signal received for ID: ", id)
	print("Map: Is server: ", multiplayer.is_server())
	print("Map: My unique ID: ", multiplayer.get_unique_id())
	
	# Only handle peer connection on server
	if multiplayer.is_server():
		print("Map: Server received new peer connection: ", id)

func _on_peer_disconnected(id: int):
	print("Map: Peer disconnected signal received for ID: ", id)
	
	# Clean up the player
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

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
			
			# Create and position ladder
			var ladder = ladderScene.instantiate()
			
			# Position ladder at the edge of the lower platform
			ladder.global_position = lower_platform.global_position + edge_offset + Vector3(0, 3.925, 0)
			
			# Check if ladder is on left/right side and rotate accordingly
			if abs(direction_to_upper.x) > abs(direction_to_upper.z):
				# Ladder is on left or right side - rotate 90 degrees on Y axis
				ladder.rotation.y = deg_to_rad(90)
			else:
				# Ladder is on front/back - keep normal rotation (face toward upper platform)
				var look_target = upper_platform.global_position
				look_target.y = ladder.global_position.y  # Keep ladder vertical
				ladder.look_at(look_target, Vector3.UP)
			
			add_child(ladder)
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

func _add_player(id = 1):
	
	var new_player = load("res://player.tscn").instantiate()
	new_player.name = str(id)
	new_player.position = Vector3(0, 1.27678, 0)  # Initial spawn position
	add_child(new_player)
	print("Added player: ", new_player.name)
	return new_player

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
		var platform_instance = platformScene.instantiate()
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
		
		platform_instance.position = new_position
		
		# change properties
		var platformType = randi() % 2 # 0-3 inclusive
		const REGULAR = 0
		var ICE_TEXTURE = load("res://ice_texture.tres")
		var NORMAL_TEXTURE = load("res://wood.tres")
		const ICE_PLATFORM = 1
		
		if(platformType == REGULAR):
			platform_instance.get_node("texture").material_override = NORMAL_TEXTURE
			platform_instance.add_to_group("platform")
		if (platformType == ICE_PLATFORM):
			platform_instance.get_node("texture").material_override = ICE_TEXTURE
			platform_instance.add_to_group("ice")
		# instantiate platform
		add_child(platform_instance)
		
		platform_positions.append({
			"position": new_position,
			"half_width": platform_half_width,
			"half_depth": platform_half_depth
		})
		last_position = new_position

func _process(delta: float) -> void:
	if visible:  # Only check win condition if world is visible
		checkWin()
	#lava.rise()

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
	
	# Check if player is within the area of the highest platform
	var player_pos = player.global_position
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
		get_tree().change_scene_to_file("res://win_screen.tscn")

func _on_lava_body_entered(body: Node3D) -> void:
	if body == player:
		if multiplayer.is_server():
			# Handle death on server
			get_tree().change_scene_to_file("res://death_screen.tscn")
		else:
			pass
			# Notify server of death
			rpc_id(1, "_on_player_death")

@rpc("any_peer", "call_local")
func _on_player_death():
	if multiplayer.is_server():
		get_tree().change_scene_to_file("res://death_screen.tscn")

@rpc("any_peer", "reliable")
func player_setup_complete(data):
	print("Map: Received player_setup_complete from peer: ", multiplayer.get_remote_sender_id())
	if multiplayer.is_server():
		print("Map: Server acknowledging player setup complete for ID: ", data.id)
		# Server can now consider this player fully set up
		if players.has(data.id):
			print("Map: Player ", data.id, " is now fully set up")

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

@rpc("any_peer", "reliable")
func confirm_test_number(number: int):
	if multiplayer.is_server():
		print("Map: Server received confirmation of test number ", number, " from peer: ", multiplayer.get_remote_sender_id())
