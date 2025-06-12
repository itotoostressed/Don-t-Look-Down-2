extends Control

# Networking variables
var peer = ENetMultiplayerPeer.new()
const PORT = 9999
var ip_address = "127.0.0.1"  # Default to localhost

func _ready():
	# Connect all button signals
	$CenterContainer/VBoxContainer/ButtonContainer/StartButton.pressed.connect(_on_start_button_pressed)
	$CenterContainer/VBoxContainer/ButtonContainer/HostButton.pressed.connect(_on_host_button_pressed)
	$CenterContainer/VBoxContainer/ButtonContainer/JoinButton.pressed.connect(_on_join_button_pressed)
	$CenterContainer/VBoxContainer/ButtonContainer/StatsButton.pressed.connect(_on_stats_button_pressed)

func _on_start_button_pressed() -> void:
	# Single player mode
	hide()
	get_tree().change_scene_to_file("res://map.tscn")

func _on_host_button_pressed() -> void:
	# Host a game
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	hide()
	get_tree().change_scene_to_file("res://map.tscn")

func _on_join_button_pressed() -> void:
	# Join a game
	peer.create_client(ip_address, PORT)
	multiplayer.multiplayer_peer = peer
	hide()
	get_tree().change_scene_to_file("res://map.tscn")

func _on_stats_button_pressed() -> void:
	# Toggle stats panel visibility
	var stats_panel = $CenterContainer/VBoxContainer/ButtonContainer/StatsButton/StatsPanel
	stats_panel.visible = !stats_panel.visible