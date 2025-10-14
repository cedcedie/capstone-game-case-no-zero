extends Node

# Barangay Hall Manager - Handles task completion and cutscene triggering
var task_manager: Node = null
var checkpoint_manager: Node = null
var cutscene_played: bool = false

func _ready():
	print("🏛️ Barangay Hall Manager: _ready() called")
	
	# Get managers
	task_manager = get_node("/root/TaskManager")
	checkpoint_manager = get_node("/root/CheckpointManager")
	
	# Check if cutscene already played
	var cutscene_already_played = checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED)
	
	print("🔍 Barangay Hall Manager Debug:")
	print("  - cutscene_already_played:", cutscene_already_played)
	
	# Complete the "Go to Barangay Hall" task if it's active and fade task display
	if task_manager and task_manager.has_active_task():
		var current_task = task_manager.get_current_task()
		if current_task.get("id") == "go_to_barangay_hall":
			task_manager.complete_current_task()
			print("✅ Task completed: Go to Barangay Hall")
			
			# Fade task display like bedroom to police transition
			await get_tree().create_timer(2.0).timeout
			if task_manager.has_method("fade_task_display"):
				task_manager.fade_task_display()
				print("📋 Task display faded")
	
	# Play cutscene if not already played
	if not cutscene_already_played:
		print("🎬 Starting barangay hall investigation cutscene")
		# Wait for scene to fully load
		await get_tree().create_timer(1.0).timeout
		play_barangay_hall_cutscene()
	else:
		print("🔍 Barangay hall cutscene already played")

func play_barangay_hall_cutscene():
	"""Play the barangay hall investigation cutscene"""
	cutscene_played = true
	
	print("🎬 Playing barangay hall investigation cutscene")
	# TODO: Implement investigation cutscene with Miguel and Celine meeting Kapitana
	
	# Set the checkpoint to prevent replay
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED)
	print("🎯 Global checkpoint set: BARANGAY_HALL_CUTSCENE_COMPLETED")
	print("🎬 Barangay hall cutscene completed")
