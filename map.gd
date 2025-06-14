extends Node3D

@onready var player = $Player
@onready var lava = $lava
@onready var stats = $Stats
@onready var multiplayer_spawner = $MultiplayerSpawner
@onready var world = $World
@onready var platforms = $World/Platforms
@onready var ladders = $World/Ladders
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
var test_number = 0

func _ready():
	print("Map: _ready called")
	
	# Set up MultiplayerSpawner
	multiplayer_spawner.spawn_function = spawn_player
	print("Map: MultiplayerSpawner spawn function set")
	
	# Connect MultiplayerSpawner signals
	multiplayer_spawner.spawned.connect(_on_spawned)
	print("Map: MultiplayerSpawner signals connected")
	
	# Make sure the world is visible from the start
	visible = true
	print("Map: World visibility set to: ", visible)
	
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
			# Set up server's camera
			if player.has_node("Head/Camera3D"):
				player.get_node("Head/Camera3D").current = true
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
	
	# Generate platforms and ladders
	generate_platforms()
	await get_tree().create_timer(0.1).timeout
	generate_ladders()
	
	# Create and set up single player
	print("Map: Creating single player")
	var single_player = load("res://player.tscn").instantiate()
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
	
	# Enable input and physics processing
	single_player.set_process_input(true)
	single_player.set_physics_process(true)
	print("Map: Input and physics processing enabled")
	
	# Set up camera
	if single_player.has_node("Head/Camera3D"):
		var camera = single_player.get_node("Head/Camera3D")
		camera.current = true
		print("Map: Single player camera set as current")
		print("Map: Single player camera transform: ", camera.global_transform)
	else:
		print("Map: ERROR - Single player camera not found!")
	
	# Store in players dictionary
	players[1] = single_player
	print("Map: Single player added to players dictionary")
	
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
	var host_player = load("res://player.tscn").instantiate()
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
	
	# Set up camera
	if host_player.has_node("Head/Camera3D"):
		var camera = host_player.get_node("Head/Camera3D")
		camera.current = true
		print("Map: Host camera set as current")
		print("Map: Host camera transform: ", camera.global_transform)
	else:
		print("Map: ERROR - Host player camera not found!")
	
	# Store in players dictionary and set player variable
	players[1] = host_player
	player = host_player  # Set the player variable for the host
	print("Map: Host player added to players dictionary and player variable set")
	
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
	
	print("Map: Spawning client player with ID: ", multiplayer.get_unique_id())
	# Use the spawner to spawn the player
	var spawn_data = {
		"id": multiplayer.get_unique_id()
	}
	print("Map: Spawn data: ", spawn_data)
	
	# Request spawn from server
	if multiplayer.is_server():
		print("Map: We are server, spawning directly")
		multiplayer_spawner.spawn(spawn_data)
	else:
		print("Map: We are client, requesting spawn from server")
		rpc_id(1, "request_player_spawn", spawn_data)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Map: Client player spawn requested")
	
	# Make sure the world is visible
	visible = true
	print("Map: World visibility set to: ", visible)
	
	# Generate platforms and ladders
	generate_platforms()
	await get_tree().create_timer(0.1).timeout
	generate_ladders()
	print("Map: Platforms and ladders generated")

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
	new_player.position = Vector3(0, 5, 0)  # Raised spawn position
	print("Map: Setting player position to: ", new_player.position)
	
	# Add to scene tree BEFORE setting authority
	print("Map: Adding player to scene tree")
	add_child(new_player, true)
	
	# Set authority AFTER adding to tree
	new_player.set_multiplayer_authority(peer_id)
	print("Map: Player authority set to: ", new_player.get_multiplayer_authority())
	
	# Set up camera based on whether this is our local player
	if new_player.has_node("Head/Camera3D"):
		var camera = new_player.get_node("Head/Camera3D")
		if peer_id == multiplayer.get_unique_id():
			camera.current = true
			print("Map: Camera set as current for local player")
			# Make sure the player is visible
			new_player.show()
			print("Map: Local player visibility set to: ", new_player.visible)
			# Set the player variable for local player
			player = new_player
			print("Map: Local player variable set")
		else:
			camera.current = false
			print("Map: Camera disabled for remote player")
	
	# Store in players dictionary
	players[peer_id] = new_player
	print("Map: Player added to players dictionary")
	
	return new_player

@rpc("any_peer", "reliable")
func request_player_spawn(data):
	print("Map: Received spawn request from peer: ", multiplayer.get_remote_sender_id())
	if multiplayer.is_server():
		print("Map: Server handling spawn request")
		print("Map: Spawn data: ", data)
		# Let MultiplayerSpawner handle the spawning
		var spawn_result = multiplayer_spawner.spawn(data)
		print("Map: Spawn result: ", spawn_result)
	else:
		print("Map: Non-server received spawn request, ignoring")

@rpc("reliable")
func player_ready(data):
	print("Map: player_ready RPC received with data: ", data)
	var player_id = data.id
	print("Map: Looking for player with ID: ", player_id)
	
	# Wait a frame to ensure the node is in the tree
	await get_tree().process_frame
	
	# Try to find the player node
	var player_node = get_node_or_null(str(player_id))
	if player_node:
		print("Map: Found player node: ", player_node.name)
		print("Map: Player authority: ", player_node.get_multiplayer_authority())
		print("Map: Player path: ", player_node.get_path())
		player = player_node
		player.set_multiplayer_authority(player_id)
		print("Map: Set player authority to: ", player_id)
		
		# Set up camera and input for local player
		if player_id == multiplayer.get_unique_id():
			if player_node.has_node("Head/Camera3D"):
				var camera = player_node.get_node("Head/Camera3D")
				camera.current = true
				print("Map: Camera set as current for local player")
			
			# Enable input and physics processing
			player_node.set_process_input(true)
			player_node.set_physics_process(true)
			print("Map: Input and physics processing enabled")
			
			# Make sure the world is visible
			visible = true
			print("Map: World visibility set to: ", visible)
	else:
		print("Map: Failed to find player node with ID: ", player_id)
		print("Map: Available nodes: ", get_children())

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
		print("Map: Cleaning up disconnected player: ", id)
		var disconnected_player = players[id]
		if is_instance_valid(disconnected_player):
			# Remove from scene tree
			if disconnected_player.is_inside_tree():
				disconnected_player.queue_free()
			# Remove from players dictionary
			players.erase(id)
			print("Map: Successfully cleaned up player: ", id)
		else:
			print("Map: Player instance was already invalid")
			players.erase(id)

func _on_spawned(node):
	print("Map: Player spawned: ", node.name)
	print("Map: Spawned player authority: ", node.get_multiplayer_authority())
	print("Map: Spawned player visibility: ", node.visible)
	if node.has_node("Head/Camera3D"):
		print("Map: Spawned player camera current: ", node.get_node("Head/Camera3D").current)
	
	# If this is a player node
	if node.is_in_group("players"):
		print("Map: Spawned node is a player")
		var player_id = int(node.name)
		players[player_id] = node
		
		# If this is our local player
		if player_id == multiplayer.get_unique_id():
			print("Map: This is our local player")
			player = node
			
			# Set up camera and input
			if node.has_node("Head/Camera3D"):
				var camera = node.get_node("Head/Camera3D")
				# Only set as current if this is our local player
				if player_id == multiplayer.get_unique_id():
					camera.current = true
					print("Map: Camera set as current for local player")
				else:
					camera.current = false
					print("Map: Camera disabled for remote player")
			
			# Enable input and physics processing
			node.set_process_input(true)
			node.set_physics_process(true)
			print("Map: Input and physics processing enabled")
			
			# Make sure the world is visible
			visible = true
			print("Map: World visibility set to: ", visible)

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
	if not is_multiplayer():
		var current_player = players.values()[0]
		if current_player and current_player.position.y < -100:
			show_win_screen()
	else:
		var current_player = null
		if multiplayer.is_server():
			current_player = players.get(1)
		else:
			current_player = players.get(multiplayer.get_unique_id())
		
		if current_player and current_player.position.y < -100:
			show_win_screen()

@rpc("any_peer", "reliable")
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

func _on_lava_body_entered(body: Node3D) -> void:
	if body == player:
		if multiplayer.is_server():
			# Handle death on server
			get_tree().change_scene_to_file("res://death_screen.tscn")
		else:
			# Notify server of death
			rpc_id(1, "_on_player_death")
