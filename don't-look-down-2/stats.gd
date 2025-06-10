extends Node

# Statistics variables
var jumps: int = 0
var deaths: int = 0
var clears: int = 0

# Signal to notify when statistics change
signal stats_updated

func _ready():
	print("Stats node initialized!")  # Debug print
	load_stats()  # Load stats when the game starts

func _process(_delta):
	# Only try to connect to player if we're in the map scene
	var current_scene = get_tree().current_scene
	if current_scene != null and current_scene.name == "Map":
		if not is_connected_to_player():
			print("In map scene, attempting to connect to player...")
			_connect_to_player()

func is_connected_to_player() -> bool:
	var player = get_node_or_null("/root/Map/Player")
	if player:
		return player.jumped.is_connected(Callable(self, "_on_player_jumped"))
	return false

func _connect_to_player():
	print("Attempting to connect to player...")  # Debug print
	var player = get_node_or_null("/root/Map/Player")
	if player:
		print("Player found, connecting jump signal!")  # Debug print
		if not player.jumped.is_connected(Callable(self, "_on_player_jumped")):
			player.connect("jumped", Callable(self, "_on_player_jumped"))
	else:
		print("Player not found! Will retry in next frame...")  # Debug print

func _on_player_jumped():
	record_jump()  # Use the common record_jump function

func record_jump():
	print("Jump recorded!")  # Debug print
	jumps += 1
	save_stats()  # Save stats after each jump
	emit_signal("stats_updated")

func record_death():
	print("Death recorded!")  # Debug print
	deaths += 1
	save_stats()  # Save stats after each death
	emit_signal("stats_updated")

func record_clear():
	print("Clear recorded!")  # Debug print
	clears += 1
	save_stats()  # Save stats after each clear
	emit_signal("stats_updated")

func get_stats() -> Dictionary:
	print("Getting stats - Jumps: ", jumps, " Deaths: ", deaths, " Clears: ", clears)  # Debug print
	return {
		"jumps": jumps,
		"deaths": deaths,
		"clears": clears
	}

func reset_stats():
	print("Stats reset!")  # Debug print
	jumps = 0
	deaths = 0
	clears = 0
	save_stats()  # Save stats after reset
	emit_signal("stats_updated")

func save_stats():
	var save_data = {
		"jumps": jumps,
		"deaths": deaths,
		"clears": clears
	}
	
	# Get the save path
	var save_path = "user://stats.save"
	print("Attempting to save stats to: ", save_path)
	
	# Try to open the file for writing
	var save_file = FileAccess.open(save_path, FileAccess.WRITE)
	if save_file:
		# Convert dictionary to JSON string
		var json_string = JSON.stringify(save_data)
		if json_string.is_empty():
			print("ERROR: Failed to convert stats to JSON!")
			return
			
		save_file.store_string(json_string)
		print("Stats saved successfully!")
		
		# Verify the save by reading it back
		var verify_file = FileAccess.open(save_path, FileAccess.READ)
		if verify_file:
			var verify_json = verify_file.get_as_text()
			if verify_json.is_empty():
				print("WARNING: Save file is empty!")
				return
				
			var verify_data = JSON.parse_string(verify_json)
			if verify_data and verify_data.get("jumps") == jumps and verify_data.get("deaths") == deaths and verify_data.get("clears") == clears:
				print("Save verification successful!")
			else:
				print("WARNING: Save verification failed! Data mismatch.")
				print("Expected: ", save_data)
				print("Got: ", verify_data)
		else:
			print("WARNING: Could not verify save file!")
	else:
		print("ERROR: Could not open save file for writing!")
		print("Error code: ", FileAccess.get_open_error())

func load_stats():
	var save_path = "user://stats.save"
	print("Attempting to load stats from: ", save_path)
	
	if FileAccess.file_exists(save_path):
		var save_file = FileAccess.open(save_path, FileAccess.READ)
		if save_file:
			var json_string = save_file.get_as_text()
			if json_string.is_empty():
				print("ERROR: Save file is empty!")
				return
				
			var save_data = JSON.parse_string(json_string)
			if save_data:
				# Store old values for verification
				var old_jumps = jumps
				var old_deaths = deaths
				var old_clears = clears
				
				# Update values
				jumps = save_data.get("jumps", 0)
				deaths = save_data.get("deaths", 0)
				clears = save_data.get("clears", 0)
				
				print("Stats loaded successfully!")
				print("Loaded stats - Jumps: ", jumps, " Deaths: ", deaths, " Clears: ", clears)
				
				# Verify the values were actually updated
				if jumps == old_jumps and deaths == old_deaths and clears == old_clears:
					print("WARNING: Stats values did not change after loading!")
			else:
				print("ERROR: Could not parse save data!")
				print("Raw JSON: ", json_string)
		else:
			print("ERROR: Could not open save file for reading!")
			print("Error code: ", FileAccess.get_open_error())
	else:
		print("No save file found at: ", save_path)
		print("Starting with fresh stats.")
