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

func start_client(ip: String = "localhost", port: int = 135) -> void:
	print("NetworkHandler: Starting client connection to ", ip, ":", port)
	
	# Create ENet peer
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	if error != OK:
		print("NetworkHandler: Failed to create client: ", error)
		return
	
	# Set up multiplayer
	multiplayer.multiplayer_peer = peer
	
	# Connect signals
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	print("NetworkHandler: Client setup complete, attempting connection...")

func _on_connected_to_server() -> void:
	print("NetworkHandler: Connected to server!")
	print("My unique ID: ", multiplayer.get_unique_id())
	
	# Create and setup world for client
	current_world = world_scene.instantiate()
	get_tree().root.add_child(current_world)
	print("NetworkHandler: World added to scene tree")
	
	# Wait a frame to ensure the map is ready
	await get_tree().process_frame
	
	# Request player spawn with client's ID
	var spawn_data = {
		"id": multiplayer.get_unique_id(),
		"position": Vector3(0, 5, 0),
		"rotation": Vector3.ZERO
	}
	
	# Request player spawn
	if has_node("/root/Map"):
		var map = get_node("/root/Map")
		map.request_player_spawn.rpc_id(1, spawn_data)
		print("NetworkHandler: Player spawn requested")
	else:
		print("NetworkHandler: Map node not found!")

func start_single_player():
	print("NetworkHandler: Starting single player")
	# Clean up any existing world
	cleanup()
	
	# Explicitly set multiplayer peer to null for single player mode
	multiplayer.multiplayer_peer = null
	
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

func _on_connection_failed() -> void:
	print("NetworkHandler: Failed to connect to server")
	# Clean up the failed connection
	multiplayer.multiplayer_peer = null
	# Show menu again
	var menu = get_node("/root/Node3D/CanvasLayer/Menu")
	if menu:
		menu.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_server_disconnected() -> void:
	print("NetworkHandler: Disconnected from server")
	# Clean up the connection
	multiplayer.multiplayer_peer = null
	# Show menu again
	var menu = get_node("/root/Node3D/CanvasLayer/Menu")
	if menu:
		menu.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) 
