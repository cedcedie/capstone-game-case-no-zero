extends Node

# Checkpoint system for managing game state
signal checkpoint_set(checkpoint_name: String)
signal checkpoint_cleared(checkpoint_name: String)

# Available checkpoints
enum CheckpointType {
	INTRO_COMPLETED,
	OFFICE_CUTSCENE_COMPLETED,
	LOWER_LEVEL_CUTSCENE_COMPLETED,
	RECOLLECTION_COMPLETED
}

# Current checkpoint states
var checkpoints: Dictionary = {}

func _ready():
	pass

func set_checkpoint(checkpoint: CheckpointType) -> void:
	"""Set a checkpoint as completed (in-memory)"""
	var name = CheckpointType.keys()[checkpoint]
	checkpoints[name] = true
	checkpoint_set.emit(name)

func clear_checkpoint(checkpoint: CheckpointType) -> void:
	"""Clear a checkpoint"""
	var name = CheckpointType.keys()[checkpoint]
	checkpoints.erase(name)
	checkpoint_cleared.emit(name)

func has_checkpoint(checkpoint: CheckpointType) -> bool:
	"""Check if a checkpoint exists (in-memory)"""
	var name = CheckpointType.keys()[checkpoint]
	return checkpoints.has(name)

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
	if checkpoints.is_empty():
		return "No checkpoints set."
	return ", ".join(checkpoints.keys())

func get_game_flow_status() -> String:
	"""Get current game flow status and what cutscenes should play"""
	var office_played := has_checkpoint(CheckpointType.OFFICE_CUTSCENE_COMPLETED)
	var lower_played := has_checkpoint(CheckpointType.LOWER_LEVEL_CUTSCENE_COMPLETED)
	var recollection_played := has_checkpoint(CheckpointType.RECOLLECTION_COMPLETED)
	return "🎮 GAME FLOW: office_cutscene_completed=" + str(office_played) + ", lower_level_cutscene_completed=" + str(lower_played) + ", recollection_completed=" + str(recollection_played)

func debug_set_phase(phase: String) -> void:
	"""Debug: limited fresh-start phases (start, office)"""
	clear_all_checkpoints()
	match phase.to_lower():
		"start":
			print("🔄 DEBUG: Reset to start - no checkpoints set")
		"office":
			set_checkpoint(CheckpointType.OFFICE_CUTSCENE_COMPLETED)
			print("🔄 DEBUG: Set to office cutscene completed")
		_:
			print("⚠️ DEBUG: Unknown phase. Use: start, office")

func clear_all_checkpoints() -> void:
	"""Clear all checkpoints without saving"""
	checkpoints.clear()
	print("🔄 DEBUG: All checkpoints cleared from memory")

func debug_clear_file() -> void:
	"""Debug function to completely clear checkpoint file"""
	clear_checkpoint_file()
	print("🗑️ DEBUG: Checkpoint file completely deleted")
