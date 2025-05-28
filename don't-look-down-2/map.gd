extends Node3D

@onready var player = $Player
@onready var lava = $lava
var platformScene = load("res://platform.tscn")

# Configuration variables
var platform_count = 30
var min_x_distance = -4.0
var max_x_distance = 4.0
var min_z_distance = -6.0
var max_z_distance = 6.0
var min_y_increase = 2.5
var max_y_increase = 2.5
var no_overlap_radius = 4.5
var platform_half_width = 1.5  # Half of platform's X dimension
var platform_half_depth = 1.5  # Half of platform's Z dimension

func _process(delta: float) -> void:
	lava.rise()

func _ready():
	var last_position = Vector3.ZERO
	var platform_positions = []
	
	for i in range(platform_count):
		var platform_instance = platformScene.instantiate()
		var new_position = Vector3.ZERO
		var valid_position_found = false
		
		for attempt in range(platform_count):
			# Calculate random offsets
			var x_offset = randf_range(min_x_distance, max_x_distance)
			var z_offset = randf_range(min_z_distance, max_z_distance)
			var y_increase = randf_range(min_y_increase, max_y_increase)
			
			if randf() > 0.5:
				x_offset = -x_offset
			
			new_position = Vector3(
				last_position.x + x_offset,
				last_position.y + y_increase,
				last_position.z + z_offset
			)
			
			if not _position_overlaps(new_position, platform_positions):
				valid_position_found = true
				break
		
		if not valid_position_found:
			print("Warning: Couldn't find non-overlapping position after ", platform_count, " attempts")
		
		platform_instance.position = new_position
		add_child(platform_instance)
		
		platform_positions.append({
			"position": new_position,
			"half_width": platform_half_width,
			"half_depth": platform_half_depth
		})
		last_position = new_position

func _position_overlaps(position: Vector3, existing_platforms: Array) -> bool:
	# Create bounding box for new platform
	var new_min = Vector3(
		position.x - platform_half_width,
		position.y - no_overlap_radius/2,
		position.z - platform_half_depth
	)
	var new_max = Vector3(
		position.x + platform_half_width,
		position.y + no_overlap_radius/2,
		position.z + platform_half_depth
	)
	
	for existing in existing_platforms:
		# Create bounding box for existing platform
		var existing_min = Vector3(
			existing.position.x - existing.half_width,
			existing.position.y - no_overlap_radius/2,
			existing.position.z - existing.half_depth
		)
		var existing_max = Vector3(
			existing.position.x + existing.half_width,
			existing.position.y + no_overlap_radius/2,
			existing.position.z + existing.half_depth
		)
		
		# Check for AABB overlap
		if (new_min.x < existing_max.x && new_max.x > existing_min.x &&
			new_min.y < existing_max.y && new_max.y > existing_min.y &&
			new_min.z < existing_max.z && new_max.z > existing_min.z):
			return true
	
	return false


func _on_lava_body_entered(body: Node3D) -> void:
	pass # Replace with function body.
