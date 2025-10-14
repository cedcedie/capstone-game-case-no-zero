extends Node

# Checkpoint system for managing game state
signal checkpoint_set(checkpoint_name: String)
signal checkpoint_cleared(checkpoint_name: String)

# Available checkpoints
enum CheckpointType {
	BEDROOM_COMPLETED,
	BEDROOM_CUTSCENE_COMPLETED,
	LOWER_LEVEL_COMPLETED,
	POLICE_LOBBY_CUTSCENE_COMPLETED
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
