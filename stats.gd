extends Node

# Statistics variables
var jumps: int = 0
var deaths: int = 0
var clears: int = 0

# Signal to notify when statistics change
signal stats_updated

func _ready():
	load_stats()

func _process(_delta):
	# Only try to connect to player if we're in the map scene
	var current_scene = get_tree().current_scene
	if current_scene != null and current_scene.name == "Map":
		if not is_connected_to_player():
			_connect_to_player()

func is_connected_to_player() -> bool:
	var player = get_node_or_null("/root/Map/Player")
	if player:
		return player.jumped.is_connected(Callable(self, "_on_player_jumped"))
	return false

func _connect_to_player():
	var player = get_node_or_null("/root/Map/Player")
	if player:
		if not player.jumped.is_connected(Callable(self, "_on_player_jumped")):
			player.connect("jumped", Callable(self, "_on_player_jumped"))

func _on_player_jumped():
	record_jump()

func record_jump():
	jumps += 1
	save_stats()
	emit_signal("stats_updated")

func record_death():
	deaths += 1
	save_stats()
	emit_signal("stats_updated")

func record_clear():
	clears += 1
	save_stats()
	emit_signal("stats_updated")

func get_stats() -> Dictionary:
	return {
		"jumps": jumps,
		"deaths": deaths,
		"clears": clears
	}

func reset_stats():
	jumps = 0
	deaths = 0
	clears = 0
	save_stats()
	emit_signal("stats_updated")

func save_stats():
	var save_data = {
		"jumps": jumps,
		"deaths": deaths,
		"clears": clears
	}
	
	var save_path = "user://stats.save"
	var save_file = FileAccess.open(save_path, FileAccess.WRITE)
	if save_file:
		var json_string = JSON.stringify(save_data)
		if json_string.is_empty():
			return
			
		save_file.store_string(json_string)
		save_file.flush()

func load_stats():
	var save_path = "user://stats.save"
	
	if FileAccess.file_exists(save_path):
		var save_file = FileAccess.open(save_path, FileAccess.READ)
		if save_file:
			var json_string = save_file.get_as_text()
			if json_string.is_empty():
				return
				
			var save_data = JSON.parse_string(json_string)
			if save_data:
				jumps = save_data.get("jumps", 0)
				deaths = save_data.get("deaths", 0)
				clears = save_data.get("clears", 0)
			else:
				print("ERROR: Could not parse save data!")
				print("Raw JSON: ", json_string)
		else:
			print("ERROR: Could not open save file for reading!")
			print("Error code: ", FileAccess.get_open_error())
	else:
		print("No save file found at: ", save_path)
		print("Starting with fresh stats.")
