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
	
	# Remove menu scene
	var menu_scene = get_node("/root/Node3D/CanvasLayer/Menu")
	if menu_scene:
		menu_scene.queue_free()
	
	# Wait for connection before creating world
	print("NetworkHandler: Waiting for connection...")
	
	# Wait for connection with timeout
	var timeout = 5.0  # 5 seconds timeout
	var start_time = Time.get_ticks_msec()
	while peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > timeout * 1000:
			print("NetworkHandler: Connection timeout")
			peer.close()
			multiplayer.multiplayer_peer = null
			# Show menu again
			var menu = get_node("/root/Node3D/CanvasLayer/Menu")
			if menu:
				menu.show()
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			return
	
	print("NetworkHandler: Connected to server, creating world")
	# Create and setup world
	current_world = world_scene.instantiate()
	get_tree().root.add_child(current_world)
	print("NetworkHandler: World added to scene tree")
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
