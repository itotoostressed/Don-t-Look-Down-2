extends CharacterBody3D

signal jumped

var numJumps = 0
var maxJumps = 999
const SENSITIVITY = 0.01
const SPEED = 7.0
const JUMP_VELOCITY = 45
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
	print("[AUTHORITY] Player entering tree - Name: ", name, " | Peer ID: ", peer_id, " | My ID: ", multiplayer.get_unique_id())
	
	# Wait a frame to ensure proper node setup
	await get_tree().process_frame
	
	# Set authority to the peer ID
	set_multiplayer_authority(peer_id)
	print("[AUTHORITY] Authority set to: ", get_multiplayer_authority())
	print("[AUTHORITY] Has authority: ", is_multiplayer_authority())
	
	# Ensure we're properly set up for networking
	if synchronizer:
		synchronizer.set_multiplayer_authority(peer_id)
	
	# Defer the player setup to ensure authority is fully established
	call_deferred("_setup_player")

func _setup_player():
	print("[AUTHORITY] Current authority: ", get_multiplayer_authority(), " | Has authority: ", is_multiplayer_authority())
	print("[AUTHORITY] My unique ID: ", multiplayer.get_unique_id())
	print("[AUTHORITY] Player name: ", name)
	
	# Enable input and camera for single player or if we have authority
	if multiplayer.multiplayer_peer == null or is_multiplayer_authority():
		print("[AUTHORITY] Setting up local player controls")
		# Set up camera
		if camera:
			print("[AUTHORITY] Camera node found, current state: ", camera.current)
			camera.current = true
			print("[AUTHORITY] Camera set as current for local player (name: ", name, "), new state: ", camera.current)
		else:
			print("[AUTHORITY] ERROR - Camera node not found!")
		
		# Enable input and physics processing
		set_process_input(true)
		set_physics_process(true)
		
		# Set mouse mode
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		# Ensure we start at a valid position
		position.y = 1.0  # Start slightly above ground
	else:
		print("[AUTHORITY] Setting up remote player (no input/camera)")
		# Disable camera for remote players
		if camera:
			print("[AUTHORITY] Camera node found for remote, current state: ", camera.current)
			camera.current = false
			print("[AUTHORITY] Camera disabled for remote player (name: ", name, "), new state: ", camera.current)
		else:
			print("[AUTHORITY] ERROR - Camera node not found!")
		
		# Disable input and physics processing for remote players
		set_process_input(false)
		set_physics_process(false)

func _unhandled_input(event):
	if multiplayer.multiplayer_peer != null and not is_multiplayer_authority():
		return
		
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer != null and not is_multiplayer_authority():
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
			
			if has_node("/root/Stats"):
				var stats = get_node("/root/Stats")
				stats.record_jump()
				stats.save_stats()
			
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

func check_win_condition():
	# Get reference to map node (adjust path if needed)
	var map = get_parent()  # Assuming player is child of map
	if map.has_method("checkWin"):
		map.checkWin()

func _process(_delta):
	if camera and is_multiplayer_authority():
		var current_state = camera.current
	else:
		pass
