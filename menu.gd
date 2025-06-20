extends Control

@onready var stats_panel = $CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel
@onready var stats_container = $CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel/StatsContainer
@onready var stats_button = $CenterContainer/VBoxContainer/ButtonContainer/StatsButton
@onready var start_button = $CenterContainer/VBoxContainer/ButtonContainer/StartButton
@onready var host_button = $CenterContainer/VBoxContainer/ButtonContainer/HostButton
@onready var join_button = $CenterContainer/VBoxContainer/ButtonContainer/JoinButton
@onready var host_ip_panel = $CenterContainer/VBoxContainer/ButtonContainer/HostButton/HostIPPanel
@onready var join_ip_panel = $CenterContainer/VBoxContainer/ButtonContainer/JoinButton/JoinIPPanel
@onready var host_ip_input = $CenterContainer/VBoxContainer/ButtonContainer/HostButton/HostIPPanel/VBoxContainer/IPInput
@onready var join_ip_input = $CenterContainer/VBoxContainer/ButtonContainer/JoinButton/JoinIPPanel/VBoxContainer/IPInput
@onready var host_connect_button = $CenterContainer/VBoxContainer/ButtonContainer/HostButton/HostIPPanel/VBoxContainer/ConnectButton
@onready var join_connect_button = $CenterContainer/VBoxContainer/ButtonContainer/JoinButton/JoinIPPanel/VBoxContainer/ConnectButton

var is_connecting = false
var is_hosting = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Show the cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Connect the buttons' pressed signals to our handlers
	start_button.pressed.connect(_on_start_button_pressed)
	stats_button.pressed.connect(_on_stats_button_pressed)
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	host_connect_button.pressed.connect(_on_host_connect_pressed)
	join_connect_button.pressed.connect(_on_join_connect_pressed)
	
	# Initially hide the panels
	stats_panel.visible = false
	host_ip_panel.visible = false
	join_ip_panel.visible = false
	
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

func _on_peer_disconnected(id: int):
	print("Peer disconnected signal received for ID: ", id)

func _on_connected_to_server():
	print("Connected to server!")
	print("My unique ID: ", multiplayer.get_unique_id())

func _on_server_disconnected():
	print("Disconnected from server!")

# Called when the start button is pressed
func _on_start_button_pressed() -> void:
	hide()  # Hide menu
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)  # Capture mouse for game
	get_node("/root/NetworkHandler").start_single_player()

func _on_stats_button_pressed() -> void:
	# Toggle stats panel visibility
	stats_panel.visible = !stats_panel.visible
	update_stats_display()

func _on_host_button_pressed() -> void:
	if is_connecting:
		return
		
	# Hide join panel if visible
	join_ip_panel.visible = false
	# Show host panel
	host_ip_panel.visible = true

func _on_join_button_pressed() -> void:
	if is_connecting:
		return
		
	# Hide host panel if visible
	host_ip_panel.visible = false
	# Show join panel
	join_ip_panel.visible = true

func _on_host_connect_pressed() -> void:
	if is_connecting:
		return
		
	is_connecting = true
	
	# Get IP from input field
	var ip = host_ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "localhost"
	
	# Hide the IP input panel
	host_ip_panel.visible = false
	
	# Hide menu
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Start as host
	get_node("/root/NetworkHandler").start_host()
	
	is_connecting = false

func _on_join_connect_pressed() -> void:
	if is_connecting:
		return

	is_connecting = true
	
	# Get IP from input field
	var ip = join_ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "localhost"
	
	# Hide the IP input panel
	join_ip_panel.visible = false
	
	# Hide menu
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Join as client
	get_node("/root/NetworkHandler").start_client(ip)
	
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
