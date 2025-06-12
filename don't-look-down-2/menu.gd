extends Control

@onready var stats_panel = $CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel
@onready var stats_container = $CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel/StatsContainer
@onready var stats_button = $CenterContainer/VBoxContainer/ButtonContainer/StatsButton
@onready var start_button = $CenterContainer/VBoxContainer/ButtonContainer/StartButton
@onready var host_button = $CenterContainer/VBoxContainer/ButtonContainer/HostButton
@onready var join_button = $CenterContainer/VBoxContainer/ButtonContainer/JoinButton
@onready var world = get_parent().get_node("World")

var peer = ENetMultiplayerPeer.new()
var is_connecting = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Show the cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Connect the buttons' pressed signals to our handlers
	start_button.pressed.connect(_on_start_button_pressed)
	stats_button.pressed.connect(_on_stats_button_pressed)
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	
	# Initially hide the stats panel
	stats_panel.visible = false
	
	# Connect to stats update signal
	var stats = get_node("/root/Stats")
	if stats:
		stats.stats_updated.connect(_on_stats_updated)
	
	# Update stats display
	update_stats_display()
	
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int):
	print("Peer connected signal received for ID: ", id)
	print("Current peer ID: ", peer.get_unique_id())
	print("Current multiplayer ID: ", multiplayer.get_unique_id())
	# Remove direct player spawning - let the map handle it

func _on_peer_disconnected(id: int):
	print("Peer disconnected signal received for ID: ", id)
	if world.has_node(str(id)):
		world.get_node(str(id)).queue_free()

func _on_connected_to_server():
	print("Connected to server!")
	print("My unique ID: ", multiplayer.get_unique_id())

func _on_server_disconnected():
	print("Disconnected from server!")

# Called when the start button is pressed
func _on_start_button_pressed() -> void:
	hide()  # Hide menu
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)  # Capture mouse for game
	world.start_single_player()  # Start single player mode

func _on_stats_button_pressed() -> void:
	# Toggle stats panel visibility
	stats_panel.visible = !stats_panel.visible
	update_stats_display()

func _on_host_button_pressed() -> void:
	if is_connecting:
		return
		
	is_connecting = true
	
	# Start as host
	hide()  # Hide menu
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)  # Capture mouse for game
	
	# Close any existing connection
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer.close()
	
	print("Creating server...")
	# Create server with specific configuration
	peer.create_server(135, 4)  # Port 135, max 4 players
	multiplayer.multiplayer_peer = peer
	
	# Wait for server to be ready
	await get_tree().create_timer(0.1).timeout
	
	print("Server started")
	print("Host peer ID: ", peer.get_unique_id())
	print("Host multiplayer ID: ", multiplayer.get_unique_id())
	
	world.start_multiplayer_host()  # Start as host
	
	is_connecting = false

func _on_join_button_pressed() -> void:
	if is_connecting:
		return
		
	is_connecting = true
	
	# Join as client
	hide()  # Hide menu
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)  # Capture mouse for game
	
	# Close any existing connection
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer.close()
	
	print("Creating client...")
	# Create client with specific configuration
	peer.create_client("localhost", 135)
	multiplayer.multiplayer_peer = peer
	
	print("Client started")
	print("Client peer ID: ", peer.get_unique_id())
	print("Client multiplayer ID: ", multiplayer.get_unique_id())
	
	# Wait for connection before starting client
	await get_tree().create_timer(0.5).timeout
	
	# Only start client if we're actually connected
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		world.start_multiplayer_client()  # Start as client
	else:
		print("Failed to connect to server")
		show()  # Show menu again
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	is_connecting = false

func _on_stats_updated() -> void:
	if stats_panel.visible:
		update_stats_display()

func update_stats_display() -> void:
	# Get the stats node from the autoload/singleton
	var stats = get_node("/root/Stats")
	if stats:
		var stats_data = stats.get_stats()
		print("Updating stats display with: ", stats_data)  # Debug print
		$CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel/StatsContainer/JumpsLabel.text = "Jumps: " + str(stats_data.jumps)
		$CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel/StatsContainer/DeathsLabel.text = "Deaths: " + str(stats_data.deaths)
		$CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel/StatsContainer/ClearsLabel.text = "Clears: " + str(stats_data.clears)
	else:
		print("Warning: Stats node not found when updating display!")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
