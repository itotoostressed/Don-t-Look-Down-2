extends Node

func _ready():
	# Set up multiplayer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id: int):
	print("Peer connected: ", id)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)
	# Remove the disconnected player
	var player = get_node_or_null(str(id))
	if player:
		player.queue_free() 