extends CharacterBody3D

var numJumps = 0
var maxJumps = 2
const SENSITIVITY = 0.01
const SPEED = 5.0
const JUMP_VELOCITY = 5.5

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
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		numJumps = 0
	
	# Jumping
	if Input.is_action_just_pressed("jump") and numJumps < maxJumps:
		numJumps += 1
		velocity.y = JUMP_VELOCITY
	
	# Movement based on camera direction
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
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	move_and_slide()
