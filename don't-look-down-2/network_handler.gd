extends Node

signal player_spawned

var world_scene = preload("res://map.tscn")
var current_world = null

func _ready():
	print("NetworkHandler: Ready")

func start_host():
	print("NetworkHandler: Starting host")
	# Clean up any existing world
	cleanup()
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(135, 4)
	if error != OK:
		print("NetworkHandler: Failed to create server: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	
	# Remove menu scene
	var menu = get_node("/root/Node3D/CanvasLayer/Menu")
	if menu:
		menu.queue_free()
	
	# Create and setup world
	current_world = world_scene.instantiate()
	get_tree().root.add_child(current_world)
	print("NetworkHandler: World added to scene tree")
	current_world.start_multiplayer_host()

func start_client():
	print("NetworkHandler: Starting client")
	# Clean up any existing world
	cleanup()
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client("localhost", 135)
	if error != OK:
		print("NetworkHandler: Failed to create client: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	
	# Connect to the connected signal BEFORE setting the peer
	if not multiplayer.connected_to_server.is_connected(_on_client_connected):
		multiplayer.connected_to_server.connect(_on_client_connected)

	# Remove menu scene
	var menu_scene = get_node("/root/Node3D/CanvasLayer/Menu")
	if menu_scene:
		menu_scene.queue_free()
	
	print("NetworkHandler: Waiting for connection...")

# New function to handle when client successfully connects
func _on_client_connected():
	print("NetworkHandler: Successfully connected to server!")
	print("NetworkHandler: My peer ID is: ", multiplayer.get_unique_id())
	
	# Now create the world
	current_world = world_scene.instantiate()
	get_tree().root.add_child(current_world)
	print("NetworkHandler: World added to scene tree")
	
	# Wait a frame for the world to be properly set up
	await get_tree().process_frame
	
	# Start multiplayer client mode
	current_world.start_multiplayer_client()

func start_single_player():
	print("NetworkHandler: Starting single player")
	# Clean up any existing world
	cleanup()
	
	# Remove menu scene
	var menu = get_node("/root/Node3D/CanvasLayer/Menu")
	if menu:
		menu.queue_free()
	
	current_world = world_scene.instantiate()
	get_tree().root.add_child(current_world)
	print("NetworkHandler: World added to scene tree")
	current_world.start_single_player()

func cleanup():
	if current_world:
		current_world.queue_free()
		current_world = null
		# Wait for cleanup to complete
		await get_tree().process_frame 
