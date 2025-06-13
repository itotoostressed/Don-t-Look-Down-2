extends Node

signal player_spawned

var world_scene = preload("res://map.tscn")
var current_world = null

func _ready():
	print("NetworkHandler: Ready")

func start_host():
	print("NetworkHandler: Starting host")
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(135, 4)
	multiplayer.multiplayer_peer = peer
	
	# Create and setup world
	current_world = world_scene.instantiate()
	get_tree().root.add_child(current_world)
	print("NetworkHandler: World added to scene tree")
	current_world.start_multiplayer_host()

func start_client():
	print("NetworkHandler: Starting client")
	var peer = ENetMultiplayerPeer.new()
	peer.create_client("localhost", 135)
	multiplayer.multiplayer_peer = peer
	
	# Wait for connection before creating world
	print("NetworkHandler: Waiting for connection...")
	await get_tree().create_timer(0.5).timeout
	
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		print("NetworkHandler: Connected to server, creating world")
		# Create and setup world
		current_world = world_scene.instantiate()
		get_tree().root.add_child(current_world)
		print("NetworkHandler: World added to scene tree")
		current_world.start_multiplayer_client()
	else:
		print("NetworkHandler: Failed to connect to server")
		# Show menu again
		var menu = get_node("/root/Node3D/CanvasLayer/Menu")
		if menu:
			menu.show()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func start_single_player():
	print("NetworkHandler: Starting single player")
	current_world = world_scene.instantiate()
	get_tree().root.add_child(current_world)
	print("NetworkHandler: World added to scene tree")
	current_world.start_single_player()

func cleanup():
	if current_world:
		current_world.queue_free()
		current_world = null 
