extends CharacterBody3D

var numJumps = 0
var maxJumps = 999
const SENSITIVITY = 0.01
const SPEED = 7.0
const JUMP_VELOCITY = 10
const LADDER_CLIMB_SPEED = 4.0  # Speed when climbing ladders

var FRICTION = 0.1
var is_on_ladder = false  # Track if player is on a ladder

@onready var head = $Head
@onready var camera = $Head/Camera3D

func _ready(): 
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		# Only rotate the head (horizontal) and camera (vertical)
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		# Clamp camera pitch
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta: float) -> void:
	# Reset ladder state each frame
	var was_on_ladder = is_on_ladder
	is_on_ladder = false
	
	# Check for ladder collisions
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision.get_collider().is_in_group("ladder"):
			is_on_ladder = true
			numJumps = 0  # Reset jumps when touching ladder
			break
	
	# Ladder climbing behavior
	if is_on_ladder:
		# Gravity doesn't affect player on ladder
		velocity.y = 0
		
		# Vertical movement on ladder
		if Input.is_action_pressed("moveForward"):
			velocity.y = LADDER_CLIMB_SPEED
		elif Input.is_action_pressed("moveBackward"):
			velocity.y = -LADDER_CLIMB_SPEED
	else:
		# Normal gravity when not on ladder
		if not is_on_floor():
			velocity += get_gravity() * delta
			FRICTION = 1  # Default friction in air
		else:
			numJumps = 0
			
			# Determine floor type using slide collision
			if get_slide_collision_count() > 0:
				var floor_collision = get_slide_collision(0)
				var floor_body = floor_collision.get_collider()
				
				if floor_body:
					if floor_body.is_in_group("ice"):
						FRICTION = 0  # No friction on ice
					elif floor_body.is_in_group("platform"):
						FRICTION = 1  # Normal friction on platforms
					else:
						FRICTION = SPEED  # Default friction
	
	# Jumping (can't jump while on ladder)
	if Input.is_action_just_pressed("jump") and numJumps < maxJumps and not is_on_ladder:
		numJumps += 1
		velocity.y = JUMP_VELOCITY
	
	# Horizontal movement (only if not on ladder or when leaving ladder)
	if not is_on_ladder or (was_on_ladder and not is_on_ladder):
		var input_dir = Input.get_vector("moveLeft", "moveRight", "moveBackward", "moveForward")
		var direction = Vector3.ZERO
		
		# Get forward and right vectors from camera basis
		var forward = -head.global_transform.basis.z
		var right = head.global_transform.basis.x
		
		# Combine directions based on input
		direction = forward * input_dir.y + right * input_dir.x
		direction.y = 0  # Remove any vertical component
		direction = direction.normalized()
		
		# Apply movement
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION)
			velocity.z = move_toward(velocity.z, 0, FRICTION)
	
	move_and_slide()

func _change_to_death_scene():
	get_tree().change_scene_to_file("res://death_screen.tscn")

func _on_lava_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		print("player died!")
		call_deferred("_change_to_death_scene")
