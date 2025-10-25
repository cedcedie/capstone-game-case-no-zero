extends Node

# --- Node references ---
var dialogue_ui: CanvasLayer = null  # Will reference global DialogueUI autoload
var dialog_chooser: CanvasLayer = null  # Will reference DialogChooser autoload
@onready var player: CharacterBody2D = $PlayerM
@onready var celine: CharacterBody2D = $celine
@onready var boy_trip: CharacterBody2D = $erwin
@onready var guard: CharacterBody2D = $station_guard
@onready var guard_2: CharacterBody2D = $station_guard_2
@onready var guard_3: CharacterBody2D = $station_guard_3
@onready var police_lobby_trigger: Area2D = $Area2D_police_lobby
# Camera is now managed by CameraZoomManager autoload

# --- Task Manager reference ---
var task_manager: Node = null

# --- Dialogue data ---
var dialogue_lines: Array = []
var miguel_choices: Array = []
var current_line: int = 0
var waiting_for_next: bool = false

# --- Choice system ---
var current_choice_data: Dictionary = {}
var waiting_for_choice: bool = false
var choice_completed: bool = false

# --- Guard interaction system removed - guards will have their own scripts ---

# --- Scene state ---
var cutscene_played: bool = false

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
# --- Movement and transition tuning ---
@export var walk_speed: float = 200.0
@export var fade_duration: float = 1.2
@export var text_fade_duration: float = 0.8
@export var transition_pause: float = 0.3
# Camera zoom duration removed - now managed by CameraZoomManager
@export var shake_intensity: float = 12.0
@export var shake_duration: float = 0.5
var current_tween: Tween
var is_first_visit: bool = true

# --------------------------
# DIALOGUE LOADING
# --------------------------
func load_dialogue() -> void:
	var file: FileAccess = FileAccess.open("res://data/dialogues/lower_level_station.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open lower_level_station.json")
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Failed to parse lower_level_station.json")
		return

	dialogue_lines = parsed["DetentionCell"]
	miguel_choices = parsed["MiguelChoices"]
	current_line = 0
	print("✅ Loaded dialogue lines:", dialogue_lines.size())
	print("✅ Loaded Miguel choices:", miguel_choices.size())

# --------------------------
# CHOICE SYSTEM
# --------------------------
func get_choice_for_line(line_index: int) -> Dictionary:
	"""Check if there's a choice for this line index"""
	for choice in miguel_choices:
		if choice.get("line_index", -1) == line_index:
			return choice
	return {}

func show_miguel_choice(choice_data: Dictionary):
	"""Show Miguel's choice options"""
	current_choice_data = choice_data
	waiting_for_choice = true
	choice_completed = false
	
	# Show the choice UI
	dialog_chooser.show_choices(choice_data["choices"])
	
	print("🎯 Showing Miguel choice:", choice_data["choices"])

func _on_choice_selected(choice_index: int):
	"""Handle when player selects a choice"""
	if not waiting_for_choice:
		return
	
	waiting_for_choice = false
	choice_completed = true
	
	# Get the response for the selected choice
	var response = current_choice_data["responses"][choice_index]
	
	# Show Miguel's choice as dialogue
	dialogue_ui.show_dialogue_line("Miguel", current_choice_data["choices"][choice_index])
	await get_tree().create_timer(1.0).timeout
	
	# Show the response
	dialogue_ui.show_dialogue_line("Boy Trip", response)
	await get_tree().create_timer(2.0).timeout
	
	# Advance to next line after choice
	line_in_progress = false
	current_line += 1
	call_deferred("show_next_line")
	
	print("✅ Choice selected:", choice_index, "Response:", response)


# --------------------------
# CUTSCENE START
# --------------------------
func start_detention_scene() -> void:
	print("🎬 Detention cell scene starting...")
	load_dialogue()

	# Cutscene audio is handled by the scene's own audio system
	# No need to change BGM for cutscenes

	# Disable player control
	if player and "control_enabled" in player:
		player.control_enabled = false

	# Setup initial character positions
	setup_initial_positions()
	
	# Start dialogue sequence
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(true)
	await play_dialogue()

func setup_initial_positions() -> void:
	print("🎭 Setting up initial character positions...")
	
	# Station guard 3 - idle_right (same position as placed)
	if guard_3 and guard_3.get_node_or_null("AnimatedSprite2D"):
		guard_3.get_node("AnimatedSprite2D").play("idle_right")
	
	# PlayerM - idle_right at 1056.0, 352.0
	if player:
		player.global_position = Vector2(1056.0, 352.0)
		if player.get_node_or_null("AnimatedSprite2D"):
			player.get_node("AnimatedSprite2D").play("idle_right")
	
	# Celine - idle_left at 1056.0, 384.0
	if celine:
		celine.global_position = Vector2(1056.0, 384.0)
		if celine.get_node_or_null("AnimatedSprite2D"):
			celine.get_node("AnimatedSprite2D").play("idle_left")
	
	# Boy Trip - idle_right at initial position
	if boy_trip:
		if boy_trip.get_node_or_null("AnimatedSprite2D"):
			boy_trip.get_node("AnimatedSprite2D").play("idle_right")
	
	# Camera zoom is now managed by CameraZoomManager autoload
	# No need to manually set zoom here

# --------------------------
# HELPER FUNCTIONS
# --------------------------
func smooth_fade_in(node: CanvasItem, duration: float = fade_duration) -> void:
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_IN_OUT)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	node.modulate.a = 0.0
	node.visible = true
	current_tween.tween_property(node, "modulate:a", 1.0, duration)

func smooth_fade_out(node: CanvasItem, duration: float = fade_duration) -> void:
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_IN_OUT)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	current_tween.tween_property(node, "modulate:a", 0.0, duration)
	await current_tween.finished
	node.visible = false

func play_character_animation(character: CharacterBody2D, animation: String, duration: float = transition_pause) -> void:
	if not character:
		return
		
	if character.get_node_or_null("AnimatedSprite2D"):
		character.get_node("AnimatedSprite2D").play(animation)
		await get_tree().create_timer(duration).timeout

func move_character_smoothly(character: CharacterBody2D, target_pos: Vector2, walk_animation: String = "walk_down", idle_animation: String = "idle_right") -> void:
	if not character:
		print("⚠️ Character not found for movement")
		return
		
	var start_pos: Vector2 = character.position
	var distance: float = start_pos.distance_to(target_pos)
	var duration: float = distance / walk_speed
	
	print("🎬 Moving character from", start_pos, "to", target_pos, "duration:", duration)
	
	# Play walk animation
	play_character_animation(character, walk_animation)
	
	# Move character
	var t: Tween = create_tween()
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(character, "position", target_pos, duration)
	await t.finished
	
	print("🎬 Character movement completed")
	
	# Play idle animation
	play_character_animation(character, idle_animation)

# Removed show_dialogue_with_transition - using only next-button system now

var dialogue_in_progress = false
var line_in_progress = false

func show_dialogue_with_auto_advance(speaker: String, text: String) -> void:
	"""Show dialogue with next button for cutscenes"""
	if not dialogue_ui:
		print("⚠️ Lower Level: DialogueUI not available")
		# Ensure this function remains awaitable even when UI is missing
		await get_tree().process_frame
		return
	
	# Prevent multiple dialogue calls
	if dialogue_in_progress:
		print("⚠️ Dialogue already in progress, skipping duplicate call")
		return
	
	dialogue_in_progress = true
	print("💬 Showing dialogue for:", speaker, "-", text.substr(0, 50) + "...")
	# Small delay to ensure any camera animations are fully complete
	await get_tree().create_timer(0.1).timeout
	dialogue_ui.show_dialogue_line(speaker, text)
	
	# Wait for user to click next button
	print("💬 Waiting for user input to continue...")
	await dialogue_ui.next_pressed
	print("▶️ User input received, continuing...")
	
	# Small delay to ensure dialogue UI is properly hidden
	await get_tree().create_timer(0.1).timeout
	print("💬 Dialogue sequence completed for:", speaker)
	dialogue_in_progress = false

func play_dialogue():
	"""Simple dialogue system like police lobby - no complex line handling"""
	print("💬 Starting lower level dialogue")
	
	if not DialogueUI:
		print("⚠️ DialogueUI autoload not found")
		return
	
	# Load dialogue from JSON file
	var dialogue_lines = load_dialogue_from_json()
	if dialogue_lines.is_empty():
		print("⚠️ Failed to load dialogue from JSON")
		return
	
	# Show each dialogue line with next button (user-controlled)
	for line in dialogue_lines:
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		DialogueUI.show_dialogue_line(speaker, text)
		
		# Wait for user to click next button
		print("💬 Waiting for user input to continue...")
		await DialogueUI.next_pressed
		print("▶️ User input received, continuing...")
	
	# Hide dialogue after all lines shown
	DialogueUI.hide_ui()
	print("💬 Lower level dialogue completed")
	
	# Complete the task and end cutscene
	complete_task_and_end_cutscene()

func complete_task_and_end_cutscene():
	"""Complete the task and end the cutscene"""
	print("🎬 Completing task and ending cutscene")
	
	# Complete the "Investigate Lower Level" task if it's active
	if task_manager and task_manager.is_task_active():
		var current_task = task_manager.get_current_task()
		if current_task.get("id") == "go_to_police_jail":
			task_manager.complete_current_task()
			print("✅ Task completed: Go to Police Jail")
	
	# Re-enable player control
	if player and "control_enabled" in player:
		player.control_enabled = true
		print("✅ Player control re-enabled")
	
	# Set checkpoint as completed
	if CheckpointManager:
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_COMPLETED)
		print("📋 Lower level cutscene marked as completed")
	
	print("🎬 Cutscene ended - player can now move")

func camera_shake() -> void:
	"""Add camera shake effect for emotional emphasis"""
	print("📸 Starting camera shake...")
	# Get camera from player
	var player_camera = player.get_node_or_null("Camera2D")
	if not player_camera:
		print("⚠️ Camera not found for shake")
		return
	
	var original_offset = player_camera.offset
	print("📸 Original camera offset:", original_offset)
	print("📸 Shake intensity:", shake_intensity, "duration:", shake_duration)
	
	var shake_tween = create_tween()
	shake_tween.set_parallel(false)  # Sequential tweening
	
	# Create more intense random shake pattern with more frames
	for i in range(10):
		var random_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_tween.tween_property(player_camera, "offset", original_offset + random_offset, shake_duration / 10.0)
		print("📸 Shake frame", i, "offset:", random_offset)
	
	# Return to original position
	shake_tween.tween_property(player_camera, "offset", original_offset, shake_duration / 10.0)
	await shake_tween.finished
	print("📸 Camera shake completed, final offset:", player_camera.offset)

func focus_camera_on_erwin() -> void:
	"""Focus camera on Erwin - just moves camera, doesn't return automatically"""
	if not player or not boy_trip:
		return
	
	var player_camera = player.get_node_or_null("Camera2D")
	if not player_camera:
		return
	
	# Calculate position to show both Miguel and Erwin
	var miguel_pos = player.global_position
	var erwin_pos = boy_trip.global_position
	var center_pos = (miguel_pos + erwin_pos) / 2.0
	
	# Create focus animation
	var focus_tween = create_tween()
	focus_tween.set_ease(Tween.EASE_IN_OUT)
	focus_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Move camera to center between Miguel and Erwin
	focus_tween.tween_property(player_camera, "offset", center_pos - player.global_position, 1.0)
	# Keep zoom at 2.0 (no zoom change)
	focus_tween.parallel().tween_property(player_camera, "zoom", Vector2(2.0, 2.0), 1.0)
	
	print("📸 Camera focused on Erwin")
	await focus_tween.finished
	print("📸 Camera focus animation completed")

func return_camera_to_original() -> void:
	"""Return camera to original position and zoom"""
	if not player:
		return
	
	var player_camera = player.get_node_or_null("Camera2D")
	if not player_camera:
		return
	
	# Return camera to original position and zoom
	var return_tween = create_tween()
	return_tween.set_ease(Tween.EASE_IN_OUT)
	return_tween.set_trans(Tween.TRANS_CUBIC)
	return_tween.tween_property(player_camera, "offset", Vector2.ZERO, 1.0)
	return_tween.parallel().tween_property(player_camera, "zoom", Vector2(2.0, 2.0), 1.0)
	
	print("📸 Camera returned to original position")
	await return_tween.finished
	print("📸 Camera return animation completed")

# Camera zoom is now managed by CameraZoomManager autoload
# This function is no longer needed

func fade_out_all() -> void:
	"""Fade out all visible elements"""
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	
	# Fade out all characters
	if player:
		fade_tween.tween_property(player, "modulate:a", 0.0, fade_duration)
	if celine:
		fade_tween.tween_property(celine, "modulate:a", 0.0, fade_duration)
	if boy_trip:
		fade_tween.tween_property(boy_trip, "modulate:a", 0.0, fade_duration)
	if guard:
		fade_tween.tween_property(guard, "modulate:a", 0.0, fade_duration)
	if guard_2:
		fade_tween.tween_property(guard_2, "modulate:a", 0.0, fade_duration)
	if guard_3:
		fade_tween.tween_property(guard_3, "modulate:a", 0.0, fade_duration)
	
	# Fade out tilemaps and other scene elements
	var tilemaps = get_tree().get_nodes_in_group("tilemap")
	for tilemap in tilemaps:
		fade_tween.tween_property(tilemap, "modulate:a", 0.0, fade_duration)
	
	await fade_tween.finished

func fade_in_all() -> void:
	"""Fade in all visible elements"""
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	
	# Fade in all characters
	if player:
		fade_tween.tween_property(player, "modulate:a", 1.0, fade_duration)
	if celine:
		fade_tween.tween_property(celine, "modulate:a", 1.0, fade_duration)
	if boy_trip:
		fade_tween.tween_property(boy_trip, "modulate:a", 1.0, fade_duration)
	if guard:
		fade_tween.tween_property(guard, "modulate:a", 1.0, fade_duration)
	if guard_2:
		fade_tween.tween_property(guard_2, "modulate:a", 1.0, fade_duration)
	if guard_3:
		fade_tween.tween_property(guard_3, "modulate:a", 1.0, fade_duration)
	
	# Fade in tilemaps and other scene elements
	var tilemaps = get_tree().get_nodes_in_group("tilemap")
	for tilemap in tilemaps:
		fade_tween.tween_property(tilemap, "modulate:a", 1.0, fade_duration)
	
	await fade_tween.finished

func reposition_characters_after_fade() -> void:
	"""Reposition characters after fade transition"""
	# Celine is now not visible and collision disabled
	if celine:
		celine.visible = false
		disable_character_collision(celine)
	
	# Erwin: 480.0, 352.0 (back to original position)
	if boy_trip:
		boy_trip.global_position = Vector2(480.0, 352.0)
		if boy_trip.get_node_or_null("AnimatedSprite2D"):
			boy_trip.get_node("AnimatedSprite2D").play("idle_front")
	
	# Station guard 2: 672.0, 464.0 idle_right
	if guard_2:
		guard_2.global_position = Vector2(672.0, 464.0)
		if guard_2.get_node_or_null("AnimatedSprite2D"):
			guard_2.get_node("AnimatedSprite2D").play("idle_right")
	
	# Station guard: 672.0, 504.0 idle_right
	if guard:
		guard.global_position = Vector2(672.0, 504.0)
		if guard.get_node_or_null("AnimatedSprite2D"):
			guard.get_node("AnimatedSprite2D").play("idle_right")
	
	# Player M: 840.0, 472.0 idle_right
	if player:
		player.global_position = Vector2(840.0, 472.0)
		if player.get_node_or_null("AnimatedSprite2D"):
			player.get_node("AnimatedSprite2D").play("idle_right")
		
		# Enable player movement after fade transition
		if player.has_method("enable_movement"):
			player.enable_movement()
	
	print("🎭 Characters repositioned after fade transition")

# Guard interaction system moved to individual guard scripts

# --------------------------
# DIALOGUE SEQUENCE
# --------------------------
# OLD COMPLEX SYSTEM - COMMENTED OUT TO USE SIMPLE POLICE LOBBY PATTERN
# func show_next_line() -> void:
# 	if current_line >= dialogue_lines.size():
# 		end_scene()
# 		return
# 	
# 	# Prevent multiple line calls
# 	if line_in_progress:
# 		print("⚠️ Line already in progress, skipping duplicate call")
# 		return
# 	
# 	line_in_progress = true
# 	var line: Dictionary = dialogue_lines[current_line]
# 	var speaker: String = String(line.get("speaker", ""))
# 	var text: String = String(line.get("text", ""))
# 
# 	print("🗨️ Showing line", current_line, "Speaker:", speaker)
# 	print("🗨️ Current line index:", current_line, "Total lines:", dialogue_lines.size())
# 
# 	# Check if this line has a choice for Miguel (except lines 7 and 15 which are handled separately)
# 	var choice_data = get_choice_for_line(current_line)
# 	if choice_data and not waiting_for_choice and not choice_completed:
# 		show_miguel_choice(choice_data)
# 		return
# 
# 	# Handle specific lines with animations and special logic
# 	match current_line:
# 		0:
# 			# Line 0: Miguel walks to center, camera focuses on Erwin, then dialogue
# 			print("🎬 Line 0: Miguel walks to center")
# 			await move_character_smoothly(player, Vector2(640, 400), "walk_down", "idle_down")
# 			await get_tree().create_timer(0.5).timeout
# 			await focus_camera_on_erwin()
# 			await get_tree().create_timer(0.5).timeout
# 			await return_camera_to_original()
# 			await get_tree().create_timer(0.2).timeout
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		1:
# 			# Line 1: Boy Trip responds, camera focuses on him
# 			print("🎬 Line 1: Boy Trip responds")
# 			await focus_camera_on_erwin()
# 			await get_tree().create_timer(0.5).timeout
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		2:
# 			# Line 2: Miguel responds, camera returns to original
# 			print("🎬 Line 2: Miguel responds")
# 			await return_camera_to_original()
# 			await get_tree().create_timer(0.3).timeout
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		3:
# 			# Line 3: Celine walks to center
# 			print("🎬 Line 3: Celine walks to center")
# 			await move_character_smoothly(celine, Vector2(640, 350), "walk_down", "idle_down")
# 			await get_tree().create_timer(0.3).timeout
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		4:
# 			# Line 4: Boy Trip responds with camera shake
# 			print("🎬 Line 4: Boy Trip responds with camera shake")
# 			await camera_shake()
# 			await get_tree().create_timer(0.3).timeout
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		5:
# 			# Line 5: Miguel responds
# 			print("🎬 Line 5: Miguel responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		6:
# 			# Line 6: Boy Trip responds
# 			print("🎬 Line 6: Boy Trip responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		7:
# 			# Line 7: Miguel choice - handled by choice system
# 			print("🎬 Line 7: Miguel choice")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		8:
# 			# Line 8: Boy Trip responds to choice
# 			print("🎬 Line 8: Boy Trip responds to choice")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		9:
# 			# Line 9: Miguel responds
# 			print("🎬 Line 9: Miguel responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		10:
# 			# Line 10: Boy Trip responds
# 			print("🎬 Line 10: Boy Trip responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		11:
# 			# Line 11: Miguel responds
# 			print("🎬 Line 11: Miguel responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		12:
# 			# Line 12: Boy Trip responds
# 			print("🎬 Line 12: Boy Trip responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		13:
# 			# Line 13: Miguel responds
# 			print("🎬 Line 13: Miguel responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		14:
# 			# Line 14: Boy Trip responds
# 			print("🎬 Line 14: Boy Trip responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		15:
# 			# Line 15: Miguel choice - handled by choice system
# 			print("🎬 Line 15: Miguel choice")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		16:
# 			# Line 16: Boy Trip responds to choice
# 			print("🎬 Line 16: Boy Trip responds to choice")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		17:
# 			# Line 17: Miguel responds
# 			print("🎬 Line 17: Miguel responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		18:
# 			# Line 18: Boy Trip responds
# 			print("🎬 Line 18: Boy Trip responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		19:
# 			# Line 19: Miguel responds
# 			print("🎬 Line 19: Miguel responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		20:
# 			# Line 20: Boy Trip responds
# 			print("🎬 Line 20: Boy Trip responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		21:
# 			# Line 21: Miguel responds
# 			print("🎬 Line 21: Miguel responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		22:
# 			# Line 22: Boy Trip responds
# 			print("🎬 Line 22: Boy Trip responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		23:
# 			# Line 23: Miguel responds
# 			print("🎬 Line 23: Miguel responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		24:
# 			# Line 24: Boy Trip responds
# 			print("🎬 Line 24: Boy Trip responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		25:
# 			# Line 25: Miguel responds
# 			print("🎬 Line 25: Miguel responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		26:
# 			# Line 26: Boy Trip responds
# 			print("🎬 Line 26: Boy Trip responds")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 		
# 		27:
# 			# Line 27: End scene
# 			print("🎬 Line 27: End scene")
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			# Don't call show_next_line() for the last line
# 			# End scene will be called by the dialogue completion
# 		
# 		# Default: Regular dialogue for other lines
# 		_:
# 			await show_dialogue_with_auto_advance(speaker, text)
# 			line_in_progress = false
# 			call_deferred("show_next_line")
# 	
# 	# Increment line counter at the end of each line (except for special cases)
# 	if current_line != 27:  # Don't increment after end scene
# 		current_line += 1
# 		print("📝 Line completed, moving to line", current_line)
	if current_line >= dialogue_lines.size():
		end_scene()
		return
	
	# Prevent multiple line calls
	if line_in_progress:
		print("⚠️ Line already in progress, skipping duplicate call")
		return
	
	line_in_progress = true
	var line: Dictionary = dialogue_lines[current_line]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))

	print("🗨️ Showing line", current_line, "Speaker:", speaker)
	print("🗨️ Current line index:", current_line, "Total lines:", dialogue_lines.size())

	# Check if this line has a choice for Miguel (except lines 7 and 15 which are handled separately)
	var choice_data = get_choice_for_line(current_line)
	if choice_data and speaker == "Miguel" and current_line != 7 and current_line != 15:
		# Show choice instead of regular dialogue
		show_miguel_choice(choice_data)
		return

	# Organized by scene beats for better readability
	match current_line:
		# Opening line - Miguel's initial dialogue
		0:
			await play_character_animation(player, "idle_left", transition_pause)
			await show_dialogue_with_auto_advance(speaker, text)
			line_in_progress = false
			call_deferred("show_next_line")
		
		# Boy Trip's emotional response with camera shake
		1:
			print("🎬 Line 1: Starting camera shake and focus sequence")
			# Build-up: shake + zoom before the dialogue for stronger emphasis
			await camera_shake()
			print("🎬 Camera shake completed")
			# Focus camera on Erwin to show both characters
			await focus_camera_on_erwin()
			print("🎬 Camera focused on Erwin")
			if dialogue_ui:
				dialogue_ui.hide()
			await play_character_animation(boy_trip, "idle_right", transition_pause)
			print("🎬 Boy Trip animation completed")
			# Longer delay to ensure camera is fully positioned and stable
			await get_tree().create_timer(0.5).timeout
			# Show dialogue while camera is focused on Erwin
			print("🎬 Starting dialogue for line 1")
			await show_dialogue_with_auto_advance(speaker, text)
			print("🎬 Dialogue completed for line 1")
			# Return camera to original position after dialogue
			await return_camera_to_original()
			print("🎬 Camera returned to original position")
			# Longer delay to ensure all animations are complete
			await get_tree().create_timer(0.5).timeout
			print("🎬 All animations completed, moving to next line")
			line_in_progress = false
			call_deferred("show_next_line")

		# Miguel walks before line 2
		2:
			# Hide dialogue during movement
			if dialogue_ui:
				dialogue_ui.hide()
			
			# Boy Trip changes to idle_front
			if boy_trip and boy_trip.get_node_or_null("AnimatedSprite2D"):
				boy_trip.get_node("AnimatedSprite2D").play("idle_front")
			
			# Miguel's movement sequence
			# Miguel: walk_down to 1056.0, 480.0
			await move_character_smoothly(player, Vector2(1056.0, 480.0), "walk_down", "idle_back")
			# Miguel: walk_left to 464.0, 480.0
			await move_character_smoothly(player, Vector2(464.0, 480.0), "walk_left", "idle_back")
			
			# Small delay to ensure movement is fully complete
			await get_tree().create_timer(0.3).timeout
			
			# Show dialogue UI and dialogue after Miguel walks
			if dialogue_ui:
				dialogue_ui.show()
			await show_dialogue_with_auto_advance(speaker, text)
			line_in_progress = false
			call_deferred("show_next_line")
		
		# Celine walks before line 3
		3:
			print("🎬 Line 3: Starting Celine movement sequence")
			# Hide dialogue during movement
			if dialogue_ui:
				dialogue_ui.hide()
			
			# Check if Celine exists
			if not celine:
				print("⚠️ Celine not found! Cannot perform movement")
				await show_dialogue_with_auto_advance(speaker, text)
				line_in_progress = false
				current_line += 1
				call_deferred("show_next_line")
				return
			
			print("🎬 Celine found, starting movement sequence")
			print("🎬 Celine current position:", celine.global_position)
			# Celine's movement sequence
			# Celine: walk_down to 1056.0, 480.0
			await move_character_smoothly(celine, Vector2(1056.0, 480.0), "walk_down", "idle_back")
			# Celine: walk_left to 504.0, 480.0
			await move_character_smoothly(celine, Vector2(504.0, 480.0), "walk_left", "idle_back")
			print("🎬 Celine movement sequence completed")
			
			# Small delay to ensure movement is fully complete
			await get_tree().create_timer(0.3).timeout
			
			# Show dialogue UI and dialogue after Celine walks
			if dialogue_ui:
				dialogue_ui.show()
			await show_dialogue_with_auto_advance(speaker, text)
			line_in_progress = false
			call_deferred("show_next_line")

		# Boy Trip's frustration after Celine's line
		4:
			# Add camera shake for Boy Trip's frustration
			await camera_shake()
			# Small delay to ensure camera shake is fully complete
			await get_tree().create_timer(0.3).timeout
			# Hide dialogue during movement
			if dialogue_ui:
				dialogue_ui.hide()
			
			# Boy Trip moves to 480.0, 424.0 with walk_down animation
			await move_character_smoothly(boy_trip, Vector2(480.0, 424.0), "walk_down", "idle_front")
			
			# Small delay to ensure movement is fully complete
			await get_tree().create_timer(0.3).timeout
			
			# Show dialogue UI and dialogue after Boy Trip moves
			if dialogue_ui:
				dialogue_ui.show()
			await show_dialogue_with_auto_advance(speaker, text)
			line_in_progress = false
			call_deferred("show_next_line")
		
		# Normal dialogue lines
		5, 6:
			await show_dialogue_with_auto_advance(speaker, text)
			line_in_progress = false
			call_deferred("show_next_line")
		
		# Line 7: Show dialogue first, then show choices
		7:
			# Reset choice completed flag for this new choice
			choice_completed = false
			# Show Miguel's dialogue first
			await show_dialogue_with_auto_advance(speaker, text)
			# Automatically show choices after dialogue
			var choice_data_7 = get_choice_for_line(current_line)
			if choice_data_7:
				show_miguel_choice(choice_data_7)
			# Don't increment here - choice will handle it
			return
		
		# Normal dialogue lines 8-14
		8, 9, 10, 11, 12, 13, 14:
			await show_dialogue_with_auto_advance(speaker, text)
			line_in_progress = false
			call_deferred("show_next_line")
		
		# Line 15: Show dialogue first, then show choices (notebook question)
		15:
			# Reset choice completed flag for this new choice
			choice_completed = false
			# Show Boy Trip's dialogue first
			await show_dialogue_with_auto_advance(speaker, text)
			# Automatically show choices after dialogue
			var choice_data_15 = get_choice_for_line(current_line)
			if choice_data_15:
				show_miguel_choice(choice_data_15)
			# Don't increment here - choice will handle it
			return
		
		# Normal dialogue lines 16-21
		16, 17, 18, 19, 20, 21:
			await show_dialogue_with_auto_advance(speaker, text)
			line_in_progress = false
			call_deferred("show_next_line")
		
		# Line 22: Station guard 2 movement first, then dialogue
		22:
			await show_dialogue_with_auto_advance(speaker, text)
			line_in_progress = false
			call_deferred("show_next_line")
		# Line 23: Normal dialogue
		23:
			# Hide dialogue during movement
			if dialogue_ui:
				dialogue_ui.hide()
			
			# Station guard 2 movement sequence
			# Guard 2: walk_down to 704.0, 480.0
			await move_character_smoothly(guard_2, Vector2(704.0, 480.0), "walk_down", "idle_left")
			# Guard 2: walk_left to 544.0, 480.0
			await move_character_smoothly(guard_2, Vector2(544.0, 480.0), "walk_left", "idle_left")
			
			# Change character animations when guard reaches destination
			if celine and celine.get_node_or_null("AnimatedSprite2D"):
				celine.get_node("AnimatedSprite2D").play("idle_right")
			if player and player.get_node_or_null("AnimatedSprite2D"):
				player.get_node("AnimatedSprite2D").play("idle_right")
			
			# Small delay to ensure movement is fully complete
			await get_tree().create_timer(0.3).timeout
			
			# Show dialogue UI and dialogue after guard movement
			if dialogue_ui:
				dialogue_ui.show()
			await show_dialogue_with_auto_advance(speaker, text)
			line_in_progress = false
			call_deferred("show_next_line")
		
		
		# Line 24: Boy Trip's plea (after guard movement completes)
		24:
			# Wait for guard movement to fully complete before showing dialogue
			await get_tree().create_timer(0.5).timeout
			
			# Change player to idle_back
			if player and player.get_node_or_null("AnimatedSprite2D"):
				player.get_node("AnimatedSprite2D").play("idle_back")
			
			# Show dialogue after guard movement is completely finished
			await show_dialogue_with_auto_advance(speaker, text)
			line_in_progress = false
			call_deferred("show_next_line")
		
		# Normal dialogue lines 25-26
		25, 26:
			await show_dialogue_with_auto_advance(speaker, text)
			line_in_progress = false
			call_deferred("show_next_line")
		
		# Fade transition and reposition after line 27
		27:
			# Show final dialogue
			await show_dialogue_with_auto_advance(speaker, text)
			
			# Hide dialogue UI then fade out, reposition, fade in, end
			if dialogue_ui:
				await dialogue_ui.hide_ui()
			await fade_out_all()
			reposition_characters_after_fade()
			await fade_in_all()
			end_scene()
			return
		
		# Default: Regular dialogue for other lines
		_:
			await show_dialogue_with_auto_advance(speaker, text)
			line_in_progress = false
			call_deferred("show_next_line")
	
	# Increment line counter at the end of each line (except for special cases)
	if current_line != 27:  # Don't increment after end scene
		current_line += 1
		print("📝 Line completed, moving to line", current_line)

# --------------------------
# INPUT HANDLING
# --------------------------
func _on_next_pressed() -> void:
	# Handle choices on specific lines (e.g., 7 and 15)
	var choice_data = get_choice_for_line(current_line)
	if choice_data and not waiting_for_choice and not choice_completed:
		show_miguel_choice(choice_data)
		return
	
	# For normal dialogue progression, this is handled by show_dialogue_with_auto_advance
	# which waits for dialogue_ui.next_pressed signal
	print("📝 Lower Level: Next pressed signal received")
	# If no choice or choice already completed, advance normally
	# Note: current_line is incremented in show_next_line() function
	call_deferred("show_next_line")

# --------------------------
# SCENE END
# --------------------------
func end_scene():
	print("🏁 Detention cell scene ended")
	# Mark cutscene as complete to enable guard interactions
	cutscene_played = true
	print("🔍 cutscene_played set to: ", cutscene_played)
	
	# DON'T restore scene BGM - let it continue playing seamlessly
	# This allows the audio to continue across all 4 station scenes
	print("🎵 Lower Level: BGM continues playing (no restart)")
	
	# Set checkpoint for lower level completion
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_COMPLETED)
	print("🎯 Lower level checkpoint set")
	
	# Don't set any task here - task will be set after police lobby cutscene
	print("📋 Lower level completed - no task set yet")
	
	
	# Transition to next scene or enable player control
	if player and "control_enabled" in player:
		player.control_enabled = true
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(false)


# --------------------------
# INITIALIZATION
# --------------------------
func _ready() -> void:
	await get_tree().process_frame
	
	# Debug: Print all children to see what's available
	print("🔍 Scene children:")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
		
	# Get TaskManager autoload
	if has_node("/root/TaskManager"):
		task_manager = get_node("/root/TaskManager")
		print("✅ TaskManager connected")
	else:
		print("⚠️ TaskManager autoload not found - task system disabled")
	
	# Get autoload references
	if has_node("/root/DialogueUI"):
		dialogue_ui = get_node("/root/DialogueUI")
		print("✅ DialogueUI connected")
	else:
		print("⚠️ DialogueUI autoload not found - dialogue system disabled")
	
	# Get DialogChooser autoload
	if has_node("/root/DialogChooser"):
		dialog_chooser = get_node("/root/DialogChooser")
		print("✅ DialogChooser connected")
		# Connect choice signal
		dialog_chooser.choice_selected.connect(_on_choice_selected)
	else:
		print("⚠️ DialogChooser autoload not found - choice system disabled")
	
	# Connect dialogue UI signals
	if dialogue_ui:
		var cb: Callable = Callable(self, "_on_next_pressed")
		if not dialogue_ui.is_connected("next_pressed", cb):
			dialogue_ui.connect("next_pressed", cb)
	
	# Guard interactions will be handled by individual guard scripts
	
	# Set scene BGM using AudioManager
	if AudioManager:
		AudioManager.set_scene_bgm("lower_level_station")
		print("🎵 Lower Level Station: Scene BGM set via AudioManager")
	
	# Complete the "Investigate Lower Level" task if it's active (silently, no UI display)
	if task_manager and task_manager.is_task_active():
		var current_task = task_manager.get_current_task()
		if current_task.get("id") == "go_to_police_jail":
			task_manager.complete_current_task()
			print("✅ Task completed: Go to Police Jail")
	
	print("🟢 Scene ready — checking checkpoints...")
	check_checkpoint_and_start()

# Removed _process function - guards will handle their own interactions

# All guard interaction functions removed - will be in individual guard scripts

# --------------------------
# CHECKPOINT SYSTEM
# --------------------------
func check_checkpoint_and_start() -> void:
	"""Check if lower level cutscene has been completed"""
	var checkpoint_manager = get_node("/root/CheckpointManager")
	var bedroom_completed = checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
	var lower_level_completed = checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_COMPLETED)
	
	if lower_level_completed:
		print("🎯 Lower level already completed - skipping cutscene")
		# Skip cutscene and go directly to post-cutscene state
		skip_to_post_cutscene_state()
	elif bedroom_completed:
		print("🎯 Bedroom completed, first time in lower level - starting cutscene")
		# Play the cutscene normally
		start_detention_scene()
	else:
		print("🔍 Bedroom cutscene not completed yet - skipping lower level cutscene")
		# Skip to post-cutscene state without playing cutscene
		skip_to_post_cutscene_state()

# --------------------------
# DEBUG: F10 skip
# --------------------------
func _unhandled_input(event: InputEvent) -> void:
	# Block TAB key during cutscene
	if event.is_action_pressed("evidence_inventory"):
		if not cutscene_played:
			print("⚠️ Evidence inventory access blocked during cutscene")
			# Don't call set_input_as_handled() to allow global handler to work
			return
	
	# Press F10 to instantly complete the lower level cutscene (debug only)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F10:
			var checkpoint_manager = get_node("/root/CheckpointManager")
			checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_COMPLETED)
			if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
				DialogueUI.set_cutscene_mode(false)
			skip_to_post_cutscene_state()

func skip_to_post_cutscene_state() -> void:
	"""Skip to the state after cutscene completion"""
	print("🎭 Skipping to post-cutscene state")
	
	# Set cutscene as played
	cutscene_played = true
	
	# Position characters in their final positions (after fade transition)
	reposition_characters_after_fade()
	
	# But put Player M at original spawn position for smoother experience
	if player:
		player.global_position = Vector2(1056.0, 352.0)  # Original spawn position
		if player.get_node_or_null("AnimatedSprite2D"):
			player.get_node("AnimatedSprite2D").play("idle_right")
	
	# Enable player movement
	if player and player.has_method("enable_movement"):
		player.enable_movement()
	
	# DON'T set scene BGM again - it's already playing from the cutscene
	# This prevents the audio from restarting
	
	print("✅ Post-cutscene state loaded - Player M at original spawn position")

func reset_checkpoints() -> void:
	"""Reset all checkpoints for testing"""
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.clear_checkpoint_file()
	print("🔄 Checkpoints reset for testing")
