extends Node3D

@onready var player = $Player
var platformScene = load("res://platform.tscn")

# Configuration variables
var platform_count = 20          # Total number of platforms to spawn
var min_x_distance = 2.0         # Minimum horizontal distance between platforms
var max_x_distance = 6.0         # Maximum horizontal distance
var min_z_distance = -3.0        # Minimum depth variation
var max_z_distance = 3.0         # Maximum depth variation
var min_y_increase = 1.0         # Minimum vertical increase
var max_y_increase = 3.0         # Maximum vertical increase
var no_overlap_radius = 2.5      # Vertical range where platforms shouldn't overlap

func _ready():
	var last_position = Vector3.ZERO  # Start from origin
	var platform_positions = []       # Track all platform positions
	
	for i in range(platform_count):
		var platform_instance = platformScene.instantiate()
		var new_position = Vector3.ZERO
		var valid_position_found = false
		
		# Try to find a valid position
		for attempt in range(platform_count):
			# Calculate random offsets
			var x_offset = randf_range(min_x_distance, max_x_distance)
			var z_offset = randf_range(min_z_distance, max_z_distance)
			var y_increase = randf_range(min_y_increase, max_y_increase)
			
			# Randomly decide if platform goes left or right
			if randf() > 0.5:
				x_offset = -x_offset
			
			# Calculate candidate position
			new_position = Vector3(
				last_position.x + x_offset,
				last_position.y + y_increase,
				last_position.z + z_offset
			)
			
			# Check if this position overlaps with any existing platform
			if not _position_overlaps(new_position, platform_positions):
				valid_position_found = true
				break
		
		# If we couldn't find a valid position, just use the last attempt
		if not valid_position_found:
			print("Warning: Couldn't find non-overlapping position after ", platform_count, " attempts")
		
		platform_instance.position = new_position
		add_child(platform_instance)
		
		# Update tracking variables
		platform_positions.append(new_position)
		last_position = new_position

# Helper function to check if a position overlaps with existing platforms
func _position_overlaps(position: Vector3, existing_positions: Array) -> bool:
	for existing_pos in existing_positions:
		# Calculate horizontal distance (ignore Y-axis for this check)
		var horizontal_dist = Vector2(position.x, position.z).distance_to(
			Vector2(existing_pos.x, existing_pos.z)
		)
		
		# Check vertical range
		var vertical_diff = abs(position.y - existing_pos.y)
		
		# Platforms are too close both horizontally and vertically
		if horizontal_dist < min_x_distance && vertical_diff < no_overlap_radius:
			return true
	
	return false
