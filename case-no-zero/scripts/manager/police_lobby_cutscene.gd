extends Node

# Node references
@onready var player: CharacterBody2D = get_parent().get_node("PlayerM")
@onready var celine: CharacterBody2D = get_parent().get_node("Celine")

# Cutscene state
var is_in_cutscene: bool = false

# Movement and transition settings
@export var walk_speed: float = 200.0
@export var fade_duration: float = 1.2

# Task Manager reference
var task_manager: Node = null

func _ready():
	print("🔍 Police Lobby Cutscene: _ready() called")
	
	# Get task manager reference
	task_manager = get_node("/root/TaskManager")
	
	# DEBUG: Clear checkpoint for testing (uncomment the line below to disable cutscene)
	# var checkpoint_manager = get_node("/root/CheckpointManager")
	# checkpoint_manager.clear_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_COMPLETED)
	# print("🔄 DEBUG: Lower level checkpoint cleared for testing")
	
	# Check if we should play the cutscene
	var checkpoint_manager = get_node("/root/CheckpointManager")
	var lower_level_completed = checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_COMPLETED)
	var cutscene_already_played = checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED)
	
	print("🔍 Police Lobby Cutscene Debug:")
	print("  - lower_level_completed:", lower_level_completed)
	print("  - cutscene_already_played:", cutscene_already_played)
	print("  - lower_level_checkpoint exists:", checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_COMPLETED))
	print("  - cutscene_checkpoint exists:", checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED))
	
	# Set Celine visibility based on checkpoint (preload her if needed)
	if lower_level_completed and celine:
		celine.visible = true
		celine.modulate.a = 1.0
		celine.get_node("AnimatedSprite2D").play("idle_right")
		print("👩 Celine preloaded and visible")
	else:
		if celine:
			celine.visible = false
			print("👩 Celine hidden (no checkpoint)")
	
	# Only play cutscene if lower level is completed AND cutscene hasn't been played yet
	if lower_level_completed and not cutscene_already_played:
		print("🎬 Starting police lobby cutscene")
		# Wait for scene_fade_in to complete (scene transition)
		await get_tree().create_timer(1.5).timeout  # Wait for scene fade-in to complete
		play_cutscene()
	else:
		if cutscene_already_played:
			print("🔍 Police lobby cutscene already played (global checkpoint)")
		else:
			print("🔍 Lower level not completed yet")

func play_cutscene():
	is_in_cutscene = true
	
	# Disable player movement
	if player and player.has_method("disable_movement"):
		player.disable_movement()
	
	# Celine is already visible from preload, just ensure she's in the right state
	if celine:
		celine.get_node("AnimatedSprite2D").play("idle_right")
		print("👩 Celine ready for cutscene")
	
	# Player movement sequence
	await player_movement_sequence()
	
	# Wait a moment before starting dialogue
	await get_tree().create_timer(0.3).timeout
	
	# Start the dialogue
	await play_dialogue()
	
	# Make Celine walk left and fade out
	await celine_walkout()
	
	# Enable player movement and update task
	enable_player_and_update_task()

func player_movement_sequence():
	print("🚶 Starting player movement sequence")
	
	if not player:
		print("⚠️ Player not found")
		return
	
	# Get player's animated sprite
	var player_sprite = player.get_node("AnimatedSprite2D")
	if not player_sprite:
		print("⚠️ Player AnimatedSprite2D not found")
		return
	
	# Step 1: Player walk_back to (1032, 416)
	print("🚶 Player walking back to (1032, 416)")
	player_sprite.play("walk_back")
	var target_pos_1 = Vector2(1032.0, 416.0)
	var distance_1 = player.position.distance_to(target_pos_1)
	var duration_1 = distance_1 / walk_speed
	
	var tween_1 = create_tween()
	tween_1.tween_property(player, "position", target_pos_1, duration_1)
	await tween_1.finished
	
	# Step 2: Player walk_left to (1000, 416)
	print("🚶 Player walking left to (1000, 416)")
	player_sprite.play("walk_left")
	var target_pos_2 = Vector2(1000.0, 416.0)
	var distance_2 = player.position.distance_to(target_pos_2)
	var duration_2 = distance_2 / walk_speed
	
	var tween_2 = create_tween()
	tween_2.tween_property(player, "position", target_pos_2, duration_2)
	await tween_2.finished
	
	# Step 3: Player idle_left
	print("🚶 Player now idle_left")
	player_sprite.play("idle_left")
	
	print("✅ Player movement sequence completed")

func load_dialogue_from_json() -> Array:
	"""Load dialogue from JSON file"""
	var file_path = "res://data/dialogues/police_lobby_cutscene_dialogue.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("⚠️ Could not open dialogue file: ", file_path)
		return []
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("⚠️ Failed to parse dialogue JSON: ", json.get_error_message())
		return []
	
	var data = json.get_data()
	if not data.has("police_lobby_cutscene"):
		print("⚠️ Dialogue JSON missing 'police_lobby_cutscene' key")
		return []
	
	var dialogue_data = data["police_lobby_cutscene"]
	if not dialogue_data.has("dialogue_lines"):
		print("⚠️ Dialogue JSON missing 'dialogue_lines' key")
		return []
	
	var dialogue_lines = dialogue_data["dialogue_lines"]
	print("✅ Loaded ", dialogue_lines.size(), " dialogue lines from JSON")
	return dialogue_lines

func play_dialogue():
	print("💬 Starting police lobby dialogue")
	
	if not DialogueUI:
		print("⚠️ DialogueUI autoload not found")
		return
	
	# Load dialogue from JSON file
	var dialogue_lines = load_dialogue_from_json()
	if dialogue_lines.is_empty():
		print("⚠️ Failed to load dialogue from JSON")
		return
	
	# Show each dialogue line
	for line in dialogue_lines:
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		DialogueUI.show_dialogue_line(speaker, text)
		
		# Wait for player to press next
		await DialogueUI.next_pressed
	
	# Hide dialogue after all lines shown
	DialogueUI.hide_ui()
	print("💬 Police lobby dialogue completed")

func celine_walkout():
	print("🚶 Making Celine walk out")
	
	if not celine:
		print("⚠️ Celine not found")
		return
	
	# Make Celine walk left
	var animated_sprite = celine.get_node("AnimatedSprite2D")
	animated_sprite.play("walk_left")
	
	# Move Celine to the left (off screen)
	var target_position = Vector2(-100, celine.position.y)  # Move off screen to the left
	var tween = create_tween()
	tween.tween_property(celine, "position", target_position, 3.0)
	
	# Wait for movement to complete
	await tween.finished
	
	# Fade out Celine
	var fade_tween = create_tween()
	fade_tween.tween_property(celine, "modulate:a", 0.0, fade_duration)
	
	# Wait for fade to complete
	await fade_tween.finished
	
	# Make Celine invisible
	celine.visible = false
	celine.modulate.a = 1.0  # Reset alpha for next time
	
	print("👩 Celine has walked out and faded")

func enable_player_and_update_task():
	print("🎮 Enabling player movement and updating task")
	
	# Enable player movement
	if player and player.has_method("enable_movement"):
		player.enable_movement()
	
	# Set task to go to barangay hall
	if task_manager:
		task_manager.set_current_task("go_to_barangay_hall")
		print("📋 Task set to: Go to Barangay Hall")
	
	is_in_cutscene = false
	
	# Set global checkpoint to prevent cutscene from replaying
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED)
	print("🎯 Global checkpoint set: POLICE_LOBBY_CUTSCENE_COMPLETED")
	print("🎬 Police lobby cutscene completed")
