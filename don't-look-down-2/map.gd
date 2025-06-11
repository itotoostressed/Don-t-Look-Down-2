extends Node3D

@onready var player = $Player
@onready var lava = $lava
@onready var stats = $Stats  # Add reference to Stats node
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

func _process(delta: float) -> void:
	checkWin()
	#lava.rise()

func _ready():
	generate_platforms()
	await get_tree().create_timer(0.1).timeout
	generate_ladders()

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

func add_player(): #instantiate player when menu button clicked
	var player = player.instantiate() #
	print("added player!")

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

func checkWin():
	# Get all platforms and find the highest one
	var platforms = get_tree().get_nodes_in_group("platform") + get_tree().get_nodes_in_group("ice")
	
	if platforms.size() == 0:
		return  # No platforms to check
	
	# Find the highest platform
	var highest_platform = null
	for platform in platforms:
		if platform and is_instance_valid(platform):  # Check if platform is valid
			if highest_platform == null or platform.global_position.y > highest_platform.global_position.y:
				highest_platform = platform
	
	if highest_platform == null:
		return  # No valid platforms found
	
	# Check if player is within the area of the highest platform
	var player_pos = player.global_position
	var platform_pos = highest_platform.global_position
	
	# Check if player is within platform bounds (horizontally)
	var x_distance = abs(player_pos.x - platform_pos.x)
	var z_distance = abs(player_pos.z - platform_pos.z)
	
	# Check if player is close enough vertically (standing on or near the platform)
	var y_distance = abs(player_pos.y - platform_pos.y)
	
	# Player wins if they're within the platform area and close enough vertically
	if (x_distance <= platform_half_width and 
		z_distance <= platform_half_depth and 
		y_distance <= 3.0):  # 3.0 units vertical tolerance
		if has_node("Stats"):
			var stats = get_node("Stats")
			stats.record_clear()
			stats.save_stats()
		get_tree().change_scene_to_file("res://win_screen.tscn")

func _on_lava_body_entered(body: Node3D) -> void:
	if body == player:
		get_tree().change_scene_to_file("res://death_screen.tscn")
