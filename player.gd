extends CharacterBody3D

signal jumped

var numJumps = 0
var maxJumps = 999
const SENSITIVITY = 0.01
const SPEED = 7.0
const JUMP_VELOCITY = 10
const LADDER_CLIMB_SPEED = 4.0

# Coyote time for better jumping
const COYOTE_TIME = 0.15           # Time after leaving ground you can still jump
var coyote_timer = 0.0

var FRICTION = 0.1
var is_on_ladder = false

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var synchronizer = $MultiplayerSynchronizer
@onready var mesh = $MeshInstance3D

func _enter_tree():
	# Set authority based on node name
	var peer_id = name.to_int()
	print("Player: _enter_tree called")
	print("Player: Node name: ", name)
	print("Player: Setting authority to ", peer_id)
	set_multiplayer_authority(peer_id)
	print("Player: Authority set to: ", get_multiplayer_authority())
	
	# Ensure we're properly set up for networking
	if synchronizer:
		synchronizer.set_multiplayer_authority(peer_id)

func _ready():
	print("Player: _ready called")
	print("Player: Name: ", name)
	print("Player: Authority: ", get_multiplayer_authority())
	print("Player: Is in tree: ", is_inside_tree())
	print("Player: My unique ID: ", multiplayer.get_unique_id())
	
	# Only enable input and camera for the local player
	if is_multiplayer_authority():
		print("Player: Setting up local player")
		# Set up camera
		if camera:
			camera.current = true
			print("Player: Camera set as current")
		
		# Enable input and physics processing
		set_process_input(true)
		set_physics_process(true)
		print("Player: Input and physics processing enabled")
		
		# Set mouse mode
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		# Ensure we start at a valid position
		position.y = 1.0  # Start slightly above ground
	else:
		print("Player: Setting up remote player")
		# Disable camera for remote players
		if camera:
			camera.current = false
			print("Player: Camera disabled for remote player")
		
		# Disable input and physics processing for remote players
		set_process_input(false)
		set_physics_process(false)
		print("Player: Input and physics processing disabled for remote player")
	
	if has_node("/root/Stats"):
		print("Player: Stats node found")
	else:
		print("Player: WARNING: Stats node not found")

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return
		
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
		
	# Reset ladder state each frame
	var was_on_ladder = is_on_ladder
	is_on_ladder = false
	
	# Check for ladder collisions
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("ladder"):
			is_on_ladder = true
			numJumps = 0
			break
	
	# Ladder climbing behavior
	if is_on_ladder:
		velocity.y = 0
		coyote_timer = COYOTE_TIME  # Reset coyote time on ladder
		
		if Input.is_action_pressed("moveForward"):
			velocity.y = LADDER_CLIMB_SPEED
		elif Input.is_action_pressed("moveBackward"):
			velocity.y = -LADDER_CLIMB_SPEED
	else:
		# Use Godot's built-in gravity
		if is_on_floor():
			numJumps = 0
			coyote_timer = COYOTE_TIME  # Reset coyote time
			
			# Floor type detection
			if get_slide_collision_count() > 0:
				var floor_collision = get_slide_collision(0)
				var floor_body = floor_collision.get_collider()
				
				if floor_body:
					# Check the parent node for group membership since the collision is with StaticBody3D
					var platform_root = floor_body.get_parent()
					if platform_root and platform_root.is_in_group("ice"):
						FRICTION = 0
					elif platform_root and platform_root.is_in_group("platform"):
						FRICTION = 1
					else:
						FRICTION = SPEED
		else:
			# Apply Godot's built-in gravity when in air
			velocity += get_gravity() * delta
			
			# Count down coyote time
			coyote_timer -= delta
			FRICTION = 1
	
	# Improved jumping with coyote time
	if Input.is_action_just_pressed("jump") and not is_on_ladder:
		# Can jump if: on ground, within coyote time, or have jumps left
		if (is_on_floor() or coyote_timer > 0 or numJumps < maxJumps):
			if not is_on_floor() and coyote_timer <= 0:
				numJumps += 1  # Only count as air jump if not on ground/coyote
			
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0       # Use up coyote time
			print("Player jumped! Recording jump...")
			if has_node("/root/Stats"):
				var stats = get_node("/root/Stats")
				print("Current stats before jump - Jumps: ", stats.jumps, " Deaths: ", stats.deaths, " Clears: ", stats.clears)
				stats.record_jump()
				print("Jump recorded! New stats - Jumps: ", stats.jumps, " Deaths: ", stats.deaths, " Clears: ", stats.clears)
				# Verify the save
				stats.save_stats()
				print("Stats saved after jump")
			else:
				print("ERROR: Stats node not found when trying to record jump!")
			emit_signal("jumped")  # Emit the jump signal
	
	# Horizontal movement
	if not is_on_ladder or (was_on_ladder and not is_on_ladder):
		var input_dir = Input.get_vector("moveLeft", "moveRight", "moveBackward", "moveForward")
		var direction = Vector3.ZERO
		
		var forward = -head.global_transform.basis.z
		var right = head.global_transform.basis.x
		
		direction = forward * input_dir.y + right * input_dir.x
		direction.y = 0
		direction = direction.normalized()
		
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION)
			velocity.z = move_toward(velocity.z, 0, FRICTION)
	
	move_and_slide()
	
	# Ensure we don't fall through the ground
	if position.y < 0:
		position.y = 1.0 