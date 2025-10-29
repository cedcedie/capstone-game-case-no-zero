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
	HEAD_POLICE_COMPLETED,
	BARANGAY_HALL_ACCESS_GRANTED,
	BARANGAY_HALL_CUTSCENE_COMPLETED,
	MORGUE_COMPLETED,
	COURTROOM_COMPLETED
}

# Current checkpoint states
var checkpoints: Dictionary = {}

func _ready():
	pass

func set_checkpoint(checkpoint: CheckpointType) -> void:
	"""Set a checkpoint as completed"""
	var name = CheckpointType.keys()[checkpoint]
	# Do not persist; just emit for compatibility
	checkpoint_set.emit(name)

func clear_checkpoint(checkpoint: CheckpointType) -> void:
	"""Clear a checkpoint"""
	var name = CheckpointType.keys()[checkpoint]
	checkpoints.erase(name)
	checkpoint_cleared.emit(name)

func has_checkpoint(checkpoint: CheckpointType) -> bool:
	"""Check if a checkpoint exists"""
	var name = CheckpointType.keys()[checkpoint]
	return false

func get_checkpoint_name(checkpoint: CheckpointType) -> String:
	"""Get checkpoint name as string"""
	return CheckpointType.keys()[checkpoint]

func save_checkpoints() -> void:
	"""Save checkpoints to file"""
	pass

func load_checkpoints() -> void:
	"""Load checkpoints from file"""
	checkpoints.clear()

func reset_all_checkpoints() -> void:
	"""Reset all checkpoints (for testing/debugging)"""
	checkpoints.clear()

func clear_checkpoint_file() -> void:
	"""Delete the checkpoint file completely"""
	checkpoints.clear()

func get_debug_info() -> String:
	"""Get debug information about current checkpoints"""
	return "Checkpoints are disabled (no-op)."

func get_game_flow_status() -> String:
	"""Get current game flow status and what cutscenes should play"""
	return "🎮 GAME FLOW STATUS: checkpoints disabled (no-op)."

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
		"head_police":
			set_checkpoint(CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
			set_checkpoint(CheckpointType.LOWER_LEVEL_COMPLETED)
			set_checkpoint(CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED)
			set_checkpoint(CheckpointType.BARANGAY_HALL_ACCESS_GRANTED)
			set_checkpoint(CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED)
			set_checkpoint(CheckpointType.HEAD_POLICE_COMPLETED)
			print("🔄 DEBUG: Set to head police completed")
		"apartment_morgue":
			set_checkpoint(CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
			print("🔄 DEBUG: Set to bedroom completed - ready for apartment_morgue")
		_:
			print("⚠️ DEBUG: Unknown phase. Use: start, bedroom, lower_level, police_lobby, barangay_hall, barangay_completed, head_police, apartment_morgue")
	
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
