extends Node

# Checkpoint system for managing game state
signal checkpoint_set(checkpoint_name: String)
signal checkpoint_cleared(checkpoint_name: String)

# Available checkpoints
enum CheckpointType {
	BEDROOM_COMPLETED,
	BEDROOM_CUTSCENE_COMPLETED,
	LOWER_LEVEL_COMPLETED,
	POLICE_LOBBY_CUTSCENE_COMPLETED,
	BARANGAY_HALL_ACCESS_GRANTED,
	BARANGAY_HALL_CUTSCENE_COMPLETED
}

# Current checkpoint states
var checkpoints: Dictionary = {}

func _ready():
	# Load saved checkpoints
	load_checkpoints()
	print("✅ CheckpointManager initialized")

func set_checkpoint(checkpoint: CheckpointType) -> void:
	"""Set a checkpoint as completed"""
	var checkpoint_name = CheckpointType.keys()[checkpoint]
	checkpoints[checkpoint_name] = true
	save_checkpoints()
	checkpoint_set.emit(checkpoint_name)
	print("🎯 Checkpoint set: ", checkpoint_name)

func clear_checkpoint(checkpoint: CheckpointType) -> void:
	"""Clear a checkpoint"""
	var checkpoint_name = CheckpointType.keys()[checkpoint]
	checkpoints.erase(checkpoint_name)
	save_checkpoints()
	checkpoint_cleared.emit(checkpoint_name)
	print("🎯 Checkpoint cleared: ", checkpoint_name)

func has_checkpoint(checkpoint: CheckpointType) -> bool:
	"""Check if a checkpoint exists"""
	var checkpoint_name = CheckpointType.keys()[checkpoint]
	return checkpoints.has(checkpoint_name) and checkpoints[checkpoint_name] == true

func get_checkpoint_name(checkpoint: CheckpointType) -> String:
	"""Get checkpoint name as string"""
	return CheckpointType.keys()[checkpoint]

func save_checkpoints() -> void:
	"""Save checkpoints to file"""
	var file = FileAccess.open("user://checkpoints.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(checkpoints))
		file.close()
		print("💾 Checkpoints saved")

func load_checkpoints() -> void:
	"""Load checkpoints from file"""
	var file = FileAccess.open("user://checkpoints.save", FileAccess.READ)
	if file:
		var text = file.get_as_text()
		file.close()
		
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			checkpoints = parsed
			print("📂 Checkpoints loaded: ", checkpoints.keys())
		else:
			print("⚠️ Failed to parse checkpoints file")
	else:
		print("📂 No checkpoints file found, starting fresh")

func reset_all_checkpoints() -> void:
	"""Reset all checkpoints (for testing/debugging)"""
	checkpoints.clear()
	save_checkpoints()
	print("🔄 All checkpoints reset")

func clear_checkpoint_file() -> void:
	"""Delete the checkpoint file completely"""
	var file_path = "user://checkpoints.save"
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		print("🗑️ Checkpoint file deleted")
	checkpoints.clear()
	print("🔄 Checkpoints cleared from memory")

func get_debug_info() -> String:
	"""Get debug information about current checkpoints"""
	var info = "Current Checkpoints:\n"
	for checkpoint_name in checkpoints.keys():
		info += "  - " + checkpoint_name + ": " + str(checkpoints[checkpoint_name]) + "\n"
	return info

func get_game_flow_status() -> String:
	"""Get current game flow status and what cutscenes should play"""
	var status = "🎮 GAME FLOW STATUS:\n"
	status += "==========================================\n"
	
	# Check each checkpoint
	var bedroom_completed = has_checkpoint(CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
	var lower_level_completed = has_checkpoint(CheckpointType.LOWER_LEVEL_COMPLETED)
	var police_lobby_completed = has_checkpoint(CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED)
	var barangay_access = has_checkpoint(CheckpointType.BARANGAY_HALL_ACCESS_GRANTED)
	var barangay_completed = has_checkpoint(CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED)
	
	# Determine current phase
	var current_phase = "START"
	if bedroom_completed:
		current_phase = "BEDROOM_COMPLETED"
	if lower_level_completed:
		current_phase = "LOWER_LEVEL_COMPLETED"
	if police_lobby_completed:
		current_phase = "POLICE_LOBBY_COMPLETED"
	if barangay_completed:
		current_phase = "BARANGAY_HALL_COMPLETED"
	
	status += "📍 Current Phase: " + current_phase + "\n"
	status += "==========================================\n"
	
	# Show checkpoint status
	status += "📋 Checkpoint Status:\n"
	status += "  - Bedroom Cutscene: " + ("✅" if bedroom_completed else "❌") + "\n"
	status += "  - Lower Level: " + ("✅" if lower_level_completed else "❌") + "\n"
	status += "  - Police Lobby: " + ("✅" if police_lobby_completed else "❌") + "\n"
	status += "  - Barangay Access: " + ("✅" if barangay_access else "❌") + "\n"
	status += "  - Barangay Cutscene: " + ("✅" if barangay_completed else "❌") + "\n"
	
	status += "==========================================\n"
	
	# Show what cutscenes should play
	status += "🎬 Cutscene Status:\n"
	
	# Bedroom cutscene
	if not bedroom_completed:
		status += "  - Bedroom Cutscene: SHOULD PLAY\n"
	else:
		status += "  - Bedroom Cutscene: COMPLETED\n"
	
	# Lower level cutscene
	if bedroom_completed and not lower_level_completed:
		status += "  - Lower Level Cutscene: SHOULD PLAY\n"
	elif lower_level_completed:
		status += "  - Lower Level Cutscene: COMPLETED\n"
	else:
		status += "  - Lower Level Cutscene: BLOCKED (bedroom not completed)\n"
	
	# Police lobby cutscene
	if lower_level_completed and not police_lobby_completed:
		status += "  - Police Lobby Cutscene: SHOULD PLAY\n"
	elif police_lobby_completed:
		status += "  - Police Lobby Cutscene: COMPLETED\n"
	else:
		status += "  - Police Lobby Cutscene: BLOCKED (lower level not completed)\n"
	
	# Barangay hall cutscene
	if police_lobby_completed and not barangay_completed:
		status += "  - Barangay Hall Cutscene: SHOULD PLAY\n"
	elif barangay_completed:
		status += "  - Barangay Hall Cutscene: COMPLETED\n"
	else:
		status += "  - Barangay Hall Cutscene: BLOCKED (prerequisites not met)\n"
	
	status += "==========================================\n"
	
	# Show next steps
	status += "🎯 Next Steps:\n"
	if not bedroom_completed:
		status += "  → Complete bedroom cutscene\n"
	elif not lower_level_completed:
		status += "  → Go to lower level station\n"
	elif not police_lobby_completed:
		status += "  → Go to police lobby for cutscene\n"
	elif not barangay_access:
		status += "  → Go to barangay hall\n"
	elif not barangay_completed:
		status += "  → Complete barangay hall cutscene\n"
	else:
		status += "  → All main story completed!\n"
	
	return status

func debug_set_phase(phase: String) -> void:
	"""Debug function to set specific game phases"""
	# Always clear all checkpoints first to ensure clean state
	clear_all_checkpoints()
	
	match phase.to_lower():
		"start":
			print("🔄 DEBUG: Reset to start - no checkpoints set")
		"bedroom":
			set_checkpoint(CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
			print("🔄 DEBUG: Set to bedroom completed")
		"lower_level":
			set_checkpoint(CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
			set_checkpoint(CheckpointType.LOWER_LEVEL_COMPLETED)
			print("🔄 DEBUG: Set to lower level completed")
		"police_lobby":
			set_checkpoint(CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
			set_checkpoint(CheckpointType.LOWER_LEVEL_COMPLETED)
			set_checkpoint(CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED)
			print("🔄 DEBUG: Set to police lobby completed")
		"barangay_hall":
			set_checkpoint(CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
			set_checkpoint(CheckpointType.LOWER_LEVEL_COMPLETED)
			set_checkpoint(CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED)
			set_checkpoint(CheckpointType.BARANGAY_HALL_ACCESS_GRANTED)
			print("🔄 DEBUG: Set to barangay hall access granted")
		"barangay_completed":
			set_checkpoint(CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
			set_checkpoint(CheckpointType.LOWER_LEVEL_COMPLETED)
			set_checkpoint(CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED)
			set_checkpoint(CheckpointType.BARANGAY_HALL_ACCESS_GRANTED)
			set_checkpoint(CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED)
			print("🔄 DEBUG: Set to barangay hall completed")
		"apartment_morgue":
			set_checkpoint(CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
			print("🔄 DEBUG: Set to bedroom completed - ready for apartment_morgue")
		_:
			print("⚠️ DEBUG: Unknown phase. Use: start, bedroom, lower_level, police_lobby, barangay_hall, barangay_completed, apartment_morgue")
	
	# Show the new status
	print("📋 DEBUG: Current checkpoints after setting phase:")
	print(get_debug_info())

func clear_all_checkpoints() -> void:
	"""Clear all checkpoints without saving"""
	checkpoints.clear()
	print("🔄 DEBUG: All checkpoints cleared from memory")

func debug_clear_file() -> void:
	"""Debug function to completely clear checkpoint file"""
	clear_checkpoint_file()
	print("🗑️ DEBUG: Checkpoint file completely deleted")

func debug_skip_to_apartment_morgue() -> void:
	"""Debug function to skip to bedroom completed and go to apartment_morgue"""
	print("🚀 DEBUG: Skipping to bedroom completed and transitioning to apartment_morgue")
	
	# Set bedroom cutscene completed
	debug_set_phase("apartment_morgue")
	
	# Change scene to apartment_morgue
	var scene_path = "res://scenes/environments/exterior/apartment_morgue.tscn"
	if FileAccess.file_exists(scene_path):
		print("🏠 DEBUG: Transitioning to apartment_morgue scene")
		get_tree().change_scene_to_file(scene_path)
	else:
		print("⚠️ DEBUG: Scene not found:", scene_path)
