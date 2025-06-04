extends Node3D

@onready var player = $Player
@onready var lava = $lava
var platformScene = load("res://platform.tscn")
var ladderScene = load("res://ladder.tscn")

# Configuration variables
var platform_count = 30
var max_x_pos = 50
var max_z_pos = 50
var min_x_pos = 0
var min_z_pos = 0
var min_y_increase = 1.5
var max_y_increase = 8.0
var no_overlap_radius = 4.5
var platform_half_width = 1.5
var platform_half_depth = 1.5

# Spiral configuration
var spiral_radius = 15.0  # Base radius of the spiral
var spiral_radius_increment = 0.5  # How much the radius grows per platform
var spiral_angle_increment = PI / 4  # Angle between platforms (45 degrees)

const LADDER_HEIGHT = 7.85

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
		
		if height_diff >= 2.5 and height_diff <= LADDER_HEIGHT * 1.3:
			# Create and position ladder
			var ladder = ladderScene.instantiate()
			ladder.global_position += Vector3(2, 3.925, 0) + lower_platform.global_position
			# Rotate to face upper platform
			ladder.look_at(upper_platform.global_position, Vector3.UP)
			
			add_child(ladder)
			ladders_placed += 1
			
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
	# Create bounding box for new platform with base dimensions
	var new_min = Vector3(
		position.x - platform_half_width,
		position.y - 2.0,
		position.z - platform_half_depth
	)
	var new_max = Vector3(
		position.x + platform_half_width,
		position.y + 2.0,
		position.z + platform_half_depth
	)
	
	for existing in existing_platforms:
		# Create bounding box for existing platform using stored dimensions
		var existing_min = Vector3(
			existing.position.x - existing.half_width,
			existing.position.y - 2.0,
			existing.position.z - existing.half_depth
		)
		var existing_max = Vector3(
			existing.position.x + existing.half_width,
			existing.position.y + 2.0,
			existing.position.z + existing.half_depth
		)
		
		# Check for AABB overlap using actual platform dimensions
		if (new_min.x <= existing_max.x && new_max.x >= existing_min.x &&
			new_min.y <= existing_max.y && new_max.y >= existing_min.y &&
			new_min.z <= existing_max.z && new_max.z >= existing_min.z):
			return true
	
	return false

func generate_platforms():
	var center_position = Vector3(25, -2.5, 25)  # Center of the spiral within bounds
	var platform_positions = []
	var current_angle = 0.0
	var current_radius = spiral_radius
	
	for i in range(platform_count):
		var platform_instance = platformScene.instantiate()
		var new_position = Vector3.ZERO
		var valid_position_found = false
		
		# Calculate spiral position
		var x_offset = cos(current_angle) * current_radius
		var z_offset = sin(current_angle) * current_radius
		var y_increase = randf_range(min_y_increase, max_y_increase)
		
		# Special case for first platform
		if i == 0:
			y_increase = 3
		
		# Calculate position relative to center
		new_position = Vector3(
			center_position.x + x_offset,
			center_position.y + (i * y_increase),  # You'll handle Y generation yourself
			center_position.z + z_offset
		)
		
		# Try to place platform, with fallback attempts if needed
		for attempt in range(10):
			# Check if position is within bounds
			if _position_within_bounds(new_position) and not _position_overlaps(new_position, platform_positions):
				valid_position_found = true
				break
			else:
				# Adjust angle slightly if position doesn't work
				current_angle += PI / 8  # Small adjustment
				x_offset = cos(current_angle) * current_radius
				z_offset = sin(current_angle) * current_radius
				new_position = Vector3(
					center_position.x + x_offset,
					new_position.y,  # Keep the same Y
					center_position.z + z_offset
				)
		
		if not valid_position_found:
			print("Warning: Couldn't find valid position for platform ", i)
			new_position = _clamp_position_to_bounds(new_position)
		
		platform_instance.position = new_position
		
		# Set platform type and texture
		var platformType = randi() % 2
		
		const REGULAR = 0
		const ICE_PLATFORM = 1
		var ICE_TEXTURE = load("res://ice_texture.tres")
		var NORMAL_TEXTURE = load("res://wood.tres")
		
		if platformType == REGULAR:
			platform_instance.get_node("texture").material_override = NORMAL_TEXTURE
			platform_instance.add_to_group("platform")
		elif platformType == ICE_PLATFORM:
			platform_instance.get_node("texture").material_override = ICE_TEXTURE
			platform_instance.add_to_group("ice")
		
		# Add platform to scene
		add_child(platform_instance)
		
		platform_positions.append({
			"position": new_position,
			"half_width": platform_half_width,
			"half_depth": platform_half_depth
		})
		
		# Update spiral parameters for next platform
		current_angle += spiral_angle_increment
		current_radius += spiral_radius_increment

func _on_lava_body_entered(body: Node3D) -> void:
	pass
