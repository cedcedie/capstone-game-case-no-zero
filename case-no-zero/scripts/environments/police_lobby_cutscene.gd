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

# --------------------------
# HELPER FUNCTIONS
# --------------------------
func disable_character_collision(character: Node) -> void:
	"""Disable collision for a character when hiding/fading"""
	if not character:
		return
	
	# Disable collision shape
	var collision_shape = character.get_node_or_null("CollisionShape2D")
	if collision_shape:
		collision_shape.disabled = true
		print("🚫 Collision disabled for:", character.name)
	
	# Also disable any Area2D collision if it exists
	var area_collision = character.get_node_or_null("Area2D/CollisionShape2D")
	if area_collision:
		area_collision.disabled = true
		print("🚫 Area collision disabled for:", character.name)

func enable_character_collision(character: Node) -> void:
	"""Enable collision for a character when showing/fading in"""
	if not character:
		return
	
	# Enable collision shape
	var collision_shape = character.get_node_or_null("CollisionShape2D")
	if collision_shape:
		collision_shape.disabled = false
		print("✅ Collision enabled for:", character.name)
	
	# Also enable any Area2D collision if it exists
	var area_collision = character.get_node_or_null("Area2D/CollisionShape2D")
	if area_collision:
		area_collision.disabled = false
		print("✅ Area collision enabled for:", character.name)

func _ready():
	print("🔍 Police Lobby Cutscene: _ready() called")
	
	# Set scene BGM using AudioManager
	if AudioManager:
		AudioManager.set_scene_bgm("police_lobby")
		print("🎵 Police Lobby: Scene BGM set")
	
	# Get task manager reference
	task_manager = get_node("/root/TaskManager")
	
	# Check if we should play the cutscene
	var checkpoint_manager = get_node("/root/CheckpointManager")
	
	# Check if we should play the cutscene
	var lower_level_completed = checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_COMPLETED)
	var cutscene_already_played = checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED)
	
	
	print("🔍 Police Lobby Cutscene Debug:")
	print("  - lower_level_completed:", lower_level_completed)
	print("  - cutscene_already_played:", cutscene_already_played)
	print("  - lower_level_checkpoint exists:", checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_COMPLETED))
	print("  - cutscene_checkpoint exists:", checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED))
	
	# Set Celine visibility based on checkpoint (preload her if needed)
	# Only show Celine if lower level is completed AND cutscene hasn't been played yet
	if lower_level_completed and not cutscene_already_played and celine:
		celine.visible = true
		celine.modulate.a = 1.0
		celine.global_position = Vector2(912.0, 368.0)  # Set Celine spawn position
		celine.get_node("AnimatedSprite2D").play("idle_right")
		print("👩 Celine preloaded and visible for cutscene at (912, 368)")
	else:
		if celine:
			celine.visible = false
			disable_character_collision(celine)
			if cutscene_already_played:
				print("👩 Celine hidden and collision disabled (cutscene already played)")
			else:
				print("👩 Celine hidden and collision disabled (no checkpoint)")
	
	# Only play cutscene if lower level is completed AND cutscene hasn't been played yet
	if lower_level_completed and not cutscene_already_played:
		print("🎬 Starting police lobby cutscene")
		
		# Disable player movement immediately when cutscene is about to start
		if player and player.has_method("disable_movement"):
			player.disable_movement()
			print("🚫 Player movement disabled for cutscene")
		
		# Wait for scene_fade_in to complete (scene transition)
		await get_tree().create_timer(1.5).timeout  # Wait for scene fade-in to complete
		play_cutscene()
	else:
		# Ensure DialogueUI is back to normal during regular gameplay
		if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
			DialogueUI.set_cutscene_mode(false)
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
	
	# Enable cutscene mode for DialogueUI (hide Next)
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(true)
	# Start the dialogue
	await play_dialogue()
	
	# Make Celine walk left and fade out
	await celine_walkout()
	
	# Enable player movement and update task
	enable_player_and_update_task()
	# Disable cutscene mode for DialogueUI
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(false)

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
	
	# Step 1: Player walk_back to (992, 368)
	print("🚶 Player walking back to (992, 368)")
	player_sprite.play("walk_back")
	var target_pos_1 = Vector2(992.0, 368.0)
	var distance_1 = player.position.distance_to(target_pos_1)
	var duration_1 = distance_1 / walk_speed
	
	var tween_1 = create_tween()
	tween_1.tween_property(player, "position", target_pos_1, duration_1)
	await tween_1.finished
	
	# Step 2: Player walk_left to (952, 368)
	print("🚶 Player walking left to (952, 368)")
	player_sprite.play("walk_left")
	var target_pos_2 = Vector2(952.0, 368.0)
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
	
	# Show each dialogue line (auto-advance for cutscene)
	for line in dialogue_lines:
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		DialogueUI.show_dialogue_line(speaker, text)
		
		# Calculate dynamic wait time based on text length
		# Typing speed is 0.01s per character, plus extra reading time
		var typing_time = text.length() * 0.01  # Time for typing animation
		var reading_time = 1.5  # Fixed 1.5s reading time for all dialogue
		var total_wait = typing_time + reading_time
		
		print("💬 Auto-advancing dialogue: ", text.length(), " chars, waiting ", total_wait, "s")
		await get_tree().create_timer(total_wait).timeout
	
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
	
	# Make Celine invisible and disable collision
	celine.visible = false
	celine.modulate.a = 1.0  # Reset alpha for next time
	disable_character_collision(celine)
	
	print("👩 Celine has walked out, faded, and collision disabled")

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
	
	# Set global checkpoints to prevent cutscene from replaying and grant barangay hall access
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED)
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_ACCESS_GRANTED)
	print("🎯 Global checkpoint set: POLICE_LOBBY_CUTSCENE_COMPLETED")
	print("🎯 Global checkpoint set: BARANGAY_HALL_ACCESS_GRANTED")
	print("🔍 All checkpoints after police lobby completion:", checkpoint_manager.checkpoints.keys())
	print("🎬 Police lobby cutscene completed")

func _unhandled_input(event: InputEvent) -> void:
	# Press F10 to instantly complete the police lobby cutscene (debug only)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F10:
			var debug_checkpoint_manager = get_node("/root/CheckpointManager")
			debug_checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED)
			if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
				DialogueUI.set_cutscene_mode(false)
			enable_player_and_update_task()
			return
	
	# Block TAB key during cutscene
	if event.is_action_pressed("evidence_inventory"):
		if is_in_cutscene:
			print("⚠️ Evidence inventory access blocked during cutscene")
			# Don't call set_input_as_handled() to allow global handler to work
			return
