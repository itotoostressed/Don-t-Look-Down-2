extends Node3D

@onready var player = $Player
@onready var lava = $lava
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
			# Create and position ladder
			var ladder = ladderScene.instantiate()
			ladder.global_position += Vector3(2, 3.925, 0) + lower_platform.global_position
			# Rotate to face upper platform
			ladder.look_at(upper_platform.global_position, Vector3.UP)
			
			add_child(ladder)
			ladders_placed += 1
			
			# Use more generous ladder limit (you can adjust this as needed)
			if ladders_placed >= platform_count:
				break

func _position_within_bounds(position: Vector3) -> bool:
	# Check if the platform (including its size) stays within bounds
	var platform_min_x = position.x - platform_half_width
	var platform_max_x = position.x + platform_half_width
	var platform_min_z = position.z - platform_half_depth
	var platform_max_z = position.z + platform_half_depth
	
	return (platform_min_x >= min_x_pos and platform_max_x <= max_x_pos and
			platform_min_z >= min_z_pos and platform_max_z <= max_z_pos)

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
			
			# Randomly flip changeDirX and changeDirZ for next iteration (50% chance)
			if randf() > 0.5:
				changeDirX = !changeDirX
				changeDirZ = !changeDirZ
			
			# Generate varied X offset using distance range
			var x_offset = randf_range(abs(min_x_distance), max_x_distance)  # Use abs() to ensure positive min
			if not changeDirX:
				x_offset *= -1  # Apply negative direction if changeDirX is false
			
			# Generate varied Z offset using distance range  
			var z_offset = randf_range(abs(min_z_distance), max_z_distance)  # Use abs() to ensure positive min
			if not changeDirZ:
				z_offset *= -1  # Apply negative direction if changeDirZ is false
			
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
		
		# change platform types
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

func _on_lava_body_entered(body: Node3D) -> void:
	pass # Replace with function body.
