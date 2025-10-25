extends Node

# --- Node references ---
var dialogue_ui: CanvasLayer = null  # Will reference global DialogueUI autoload
@onready var player: CharacterBody2D = $PlayerM
@onready var celine: CharacterBody2D = $Celine
@onready var knock_sfx: AudioStreamPlayer = $KnockSFX
@onready var bgm: AudioStreamPlayer = $BGM
@onready var shock_sfx: AudioStreamPlayer = $ShockSFX
@onready var cinematic_text: Label = $CinematicText
@onready var door: Area2D = $Door
@onready var fade_overlay: ColorRect = $CanvasLayer/FadeOverlay
@onready var tilemaps: Array = [
	$"Ground layer",
	$"border layer",
	$misc,
	$uppermisc,
	$upperuppermisc
]

# --- Task Manager reference ---
var task_manager: Node = null

# --- Dialogue data ---
var dialogue_lines: Array = []
var current_line: int = 0
var waiting_for_next: bool = false  # kept for compatibility but not used for cutscene advance

# --- Movement and transition tuning ---
@export var walk_speed: float = 200.0
@export var fade_duration: float = 1.2
@export var text_fade_duration: float = 0.8
@export var transition_pause: float = 0.3

# --- Scene state ---
var is_cinematic_active: bool = false
var current_tween: Tween
var intro_complete: bool = false
var celine_interactable: bool = false

# --------------------------
# HELPER FUNCTIONS (Keep only what you need for AnimationPlayer)
# --------------------------

# --------------------------
# STEP 1: Load JSON dialogue
# --------------------------
func load_dialogue() -> void:
	var file: FileAccess = FileAccess.open("res://data/dialogues/Intro.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open Intro.json")
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("Intro"):
		push_error("Failed to parse Intro.json correctly")
		return

	dialogue_lines = parsed["Intro"]
	current_line = 0

# --------------------------
# STEP 2: Start intro
# --------------------------
func start_intro() -> void:
	load_dialogue()


	# Disable player movement
	if player and player.has_method("disable_movement"):
		player.disable_movement()
		print("📋 Player movement disabled for cutscene")

	# Setup initial states
	player.anim_sprite.play("idle_down")
	player.last_facing = "front"

	celine.position = Vector2(9, 40)
	celine.visible = false

	# Hide the fade overlay initially to prevent black square
	if fade_overlay:
		fade_overlay.visible = false

	# Enable cutscene mode in DialogueUI (hide Next, auto-advance handled by timers)
	if dialogue_ui and dialogue_ui.has_method("set_cutscene_mode"):
		dialogue_ui.set_cutscene_mode(true)
	# Start your AnimationPlayer animation
	$AnimationPlayer.play("bedroom_scene")

# --------------------------
# AnimationPlayer Method Call Functions
# --------------------------

# Animation control functions
func start_bedroom_animation():
	$AnimationPlayer.play("bedroom_scene")

func stop_bedroom_animation():
	$AnimationPlayer.stop()

func pause_bedroom_animation():
	$AnimationPlayer.pause()

func resume_bedroom_animation():
	$AnimationPlayer.play()

# Scene setup functions for first 4 dialogues
func setup_black_screen():
	# Hide everything for black screen effect
	for tilemap in tilemaps:
		if tilemap:
			tilemap.visible = false
	if player:
		player.visible = false
	if celine:
		celine.visible = false
	if door:
		door.visible = false

func reveal_scene_after_dialogue_4():
	# Show everything after 4th dialogue
	for tilemap in tilemaps:
		if tilemap:
			tilemap.visible = true
			tilemap.modulate.a = 0.0
	if player:
		player.visible = true
		player.modulate.a = 0.0
	if celine:
		celine.visible = true
		celine.modulate.a = 0.0
	if door:
		door.visible = true
		door.modulate.a = 0.0
	
	# Fade in everything
	await fade_all_in(2.0)

# Main dialogue function with dynamic timing
func show_dialogue_line(line_index: int):
	if line_index >= 0 and line_index < dialogue_lines.size():
		var line = dialogue_lines[line_index]
		var text = line["text"]
		var speaker = line["speaker"]
		
		# Calculate faster timing for testing (2 seconds per dialogue)
		var typing_time = text.length() * 0.005  # Faster typing: 5ms per character
		var reading_time = max(0.5, text.length() * 0.01)  # Faster reading: 10ms per char, min 0.5s
		var total_wait = typing_time + reading_time
		
		# Show dialogue (voice blip is handled automatically in DialogueUI)
		dialogue_ui.show_dialogue_line(speaker, text)
		
		# Hide the next button for bedroom scene auto-advance
		if dialogue_ui and dialogue_ui.has_node("Container/Button"):
			dialogue_ui.get_node("Container/Button").hide()
			print("🎬 Bedroom scene: Next button hidden for auto-advance")
		
		# Play voice blip for bedroom scene (since AnimationPlayer bypasses DialogueUI typing)
		if VoiceBlipManager:
			VoiceBlipManager.play_voice_blip(speaker)
			print("🎵 Voice blip called for speaker: " + speaker)
		
		# Wait for the calculated time
		await get_tree().create_timer(total_wait).timeout

# Auto-vanish function for end of dialogue groups
func auto_vanish_dialogue():
	dialogue_ui.hide_ui()

# Shocked camera shake - more dramatic and sudden
func camera_shake_shocked():
	# Play shock sound effect immediately
	if shock_sfx:
		shock_sfx.volume_db = -20  # Louder for impact
		shock_sfx.play()
		print("💥 Shock sound effect played with camera shake")
	
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var original_pos = camera.position
	var shake_tween = create_tween()
	
	# Sudden, dramatic shake for shock effect
	shake_tween.tween_property(camera, "position", original_pos + Vector2(15, 8), 0.05)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(-12, 10), 0.05)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(8, -6), 0.05)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(-5, 7), 0.05)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(3, -2), 0.05)
	shake_tween.tween_property(camera, "position", original_pos, 0.1)

# Individual dialogue line functions for AnimationPlayer Method Call tracks
func show_dialogue_0(): show_dialogue_line(0)
func show_dialogue_1(): show_dialogue_line(1)
func show_dialogue_2(): show_dialogue_line(2)
func show_dialogue_3(): show_dialogue_line(3)
func show_dialogue_4(): show_dialogue_line(4)
func show_dialogue_5(): show_dialogue_line(5)
func show_dialogue_6(): show_dialogue_line(6)
func show_dialogue_7(): show_dialogue_line(7)
func show_dialogue_8(): show_dialogue_line(8)
func show_dialogue_9(): show_dialogue_line(9)
func show_dialogue_10(): show_dialogue_line(10)
func show_dialogue_11(): show_dialogue_line(11)
func show_dialogue_12(): show_dialogue_line(12)
func show_dialogue_13(): show_dialogue_line(13)
func show_dialogue_14(): show_dialogue_line(14)
func show_dialogue_15(): show_dialogue_line(15)
func show_dialogue_16(): show_dialogue_line(16)
func show_dialogue_17(): show_dialogue_line(17)
func show_dialogue_18(): show_dialogue_line(18)
func show_dialogue_19(): show_dialogue_line(19)
func show_dialogue_20(): show_dialogue_line(20)
func show_dialogue_21(): show_dialogue_line(21)
func show_dialogue_22(): show_dialogue_line(22)
func show_dialogue_23(): show_dialogue_line(23)
func show_dialogue_24(): show_dialogue_line(24)
func show_dialogue_25(): show_dialogue_line(25)
func show_dialogue_26(): show_dialogue_line(26)
func show_dialogue_27(): show_dialogue_line(27)
func show_dialogue_28(): show_dialogue_line(28)
func show_dialogue_29(): show_dialogue_line(29)
func show_dialogue_30(): show_dialogue_line(30)
func show_dialogue_31(): show_dialogue_line(31)
func show_dialogue_32(): show_dialogue_line(32)
func show_dialogue_33(): show_dialogue_line(33)
func show_dialogue_34(): show_dialogue_line(34)
func show_dialogue_35(): show_dialogue_line(35)
func show_dialogue_36(): show_dialogue_line(36)
func show_dialogue_37(): show_dialogue_line(37)
func show_dialogue_38(): show_dialogue_line(38)
func show_dialogue_39(): show_dialogue_line(39)
func show_dialogue_40(): show_dialogue_line(40)
func show_dialogue_41(): show_dialogue_line(41)
func show_dialogue_42(): show_dialogue_line(42)
func show_dialogue_43(): show_dialogue_line(43)

# Special action functions
func play_knock_sound():
	if knock_sfx:
		knock_sfx.play()

# AudioManager now handles BGM - this function is no longer needed
# func start_bgm():
#	if bgm and not bgm.playing:
#		bgm.volume_db = -20
#		bgm.play()


func hide_celine():
	celine.visible = false
	var cshape := celine.get_node_or_null("CollisionShape2D")
	if cshape:
		cshape.disabled = true

# Fade functions
func fade_in(node: CanvasItem, duration: float = fade_duration):
	if not node:
		return
	node.modulate.a = 0.0
	node.visible = true
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)
	await tween.finished

func fade_out(node: CanvasItem, duration: float = fade_duration):
	if not node:
		return
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)
	await tween.finished
	node.visible = false

func fade_to_black(duration: float = fade_duration):
	# Note: fade_overlay node has been removed
	# Use fade_all_out() instead for scene transitions
	await fade_all_out(duration)

func fade_from_black(duration: float = fade_duration):
	# Note: fade_overlay node has been removed
	# Use fade_all_in() instead for scene transitions
	await fade_all_in(duration)

func fade_all_out(duration: float = fade_duration):
	# Fade out all tilemaps, characters, and UI
	var tween = create_tween()
	tween.set_parallel(true)  # Run all tweens simultaneously
	
	# Fade out tilemaps
	for tilemap in tilemaps:
		if tilemap:
			tween.tween_property(tilemap, "modulate:a", 0.0, duration)
	
	# Fade out characters
	if player:
		tween.tween_property(player, "modulate:a", 0.0, duration)
	if celine:
		tween.tween_property(celine, "modulate:a", 0.0, duration)
	
	# Fade out door
	if door:
		tween.tween_property(door, "modulate:a", 0.0, duration)
	
	await tween.finished
	
	# Hide everything after fade
	for tilemap in tilemaps:
		if tilemap:
			tilemap.visible = false
	if player:
		player.visible = false
	if celine:
		celine.visible = false
	if door:
		door.visible = false

func fade_all_in(duration: float = fade_duration):
	# Show everything first
	for tilemap in tilemaps:
		if tilemap:
			tilemap.visible = true
			tilemap.modulate.a = 0.0
	if player:
		player.visible = true
		player.modulate.a = 0.0
	if celine:
		celine.visible = true
		celine.modulate.a = 0.0
	if door:
		door.visible = true
		door.modulate.a = 0.0
	
	# Fade in all elements
	var tween = create_tween()
	tween.set_parallel(true)  # Run all tweens simultaneously
	
	# Fade in tilemaps
	for tilemap in tilemaps:
		if tilemap:
			tween.tween_property(tilemap, "modulate:a", 1.0, duration)
	
	# Fade in characters
	if player:
		tween.tween_property(player, "modulate:a", 1.0, duration)
	if celine:
		tween.tween_property(celine, "modulate:a", 1.0, duration)
	
	# Fade in door
	if door:
		tween.tween_property(door, "modulate:a", 1.0, duration)
	
	await tween.finished

func end_cutscene():
	
	# Set checkpoint
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
	
	# Add the first evidence (bodycam) to the evidence inventory
	if has_node("/root/EvidenceInventorySettings"):
		var evidence_ui = get_node("/root/EvidenceInventorySettings")
		evidence_ui.add_evidence("broken_body_cam")
		print("📋 Added bodycam evidence to inventory after bedroom cutscene")
	
	# Re-enable player movement
	if player and player.has_method("enable_movement"):
		player.enable_movement()
		print("📋 Player movement enabled after cutscene")
	
	# Disable cutscene mode
	if dialogue_ui and dialogue_ui.has_method("set_cutscene_mode"):
		dialogue_ui.set_cutscene_mode(false)
	
	# Start first task
	if task_manager:
		task_manager.start_next_task()

# --------------------------
# AnimationPlayer Event Handlers
# --------------------------
func start_cinematic() -> void:
	is_cinematic_active = true
	
	# Hide dialogue UI
	await dialogue_ui.hide_ui()
	
	# Ensure all elements are visible and at full opacity before fading out
	for tilemap in tilemaps:
		if tilemap:
			tilemap.visible = true
			tilemap.modulate.a = 1.0
	if player:
		player.visible = true
		player.modulate.a = 1.0
	if celine:
		celine.visible = true
		celine.modulate.a = 1.0
	if door:
		door.visible = true
		door.modulate.a = 1.0
	
	# Slow fade out everything (including door) to black
	await fade_all_out(fade_duration * 3.0)  # Slower fade out

	# --- CINEMATIC PART 1 ---
	await show_cinematic_text("…Sige, Erwin.", 1.0, 1.8)
	cinematic_text.visible = false
	
	# Brief pause between texts
	await get_tree().create_timer(0.5).timeout

	# --- CINEMATIC PART 2 ---
	await show_cinematic_text("Tingnan natin kung anong gulong napasukan mo.", 1.2, 2.5)
	cinematic_text.visible = false
	
	# Restore all tilemaps and door
	for tilemap in tilemaps:
		tilemap.visible = true
		tilemap.modulate.a = 0.0  # Start transparent for fade in
	if door:
		door.visible = true
		door.modulate.a = 0.0  # Start transparent for fade in
	
	# Restore Celine
	celine.visible = true
	celine.modulate.a = 0.0  # Start transparent for fade in
	
	# Slow fade in everything (including door)
	await fade_all_in(fade_duration * 3.0)  # Match fade out duration
	
	# Restore player animation
	player.anim_sprite.play("idle_down")
	
	# Set flags after cinematic; no Celine interaction in bedroom
	intro_complete = true
	celine_interactable = false
	
	# Set global checkpoint to prevent cutscene from replaying
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
	
	# Hide Celine and disable her collision after fade-in
	if celine:
		celine.visible = false
		var cshape := celine.get_node_or_null("CollisionShape2D")
		if cshape:
			cshape.disabled = true
	
	# Start the first task shortly after
	await get_tree().create_timer(0.5).timeout
	start_first_task()
	

func show_cinematic_text(text: String, fade_in_duration: float, hold_duration: float) -> void:
	cinematic_text.text = text
	cinematic_text.visible = true
	cinematic_text.modulate.a = 0.0
	
	# Fade in
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(cinematic_text, "modulate:a", 1.0, fade_in_duration)
	await fade_in_tween.finished
	
	# Hold the text
	await get_tree().create_timer(hold_duration).timeout
	
	# Fade out
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(cinematic_text, "modulate:a", 0.0, fade_in_duration)
	await fade_out_tween.finished
	
	cinematic_text.visible = false

# Cinematic sequence functions for AnimationPlayer
func cinematic_sequence_70_71():
	# Fade out only tileset, door, and Celine (keep Miguel visible)
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade out tilemaps
	for tilemap in tilemaps:
		if tilemap:
			tween.tween_property(tilemap, "modulate:a", 0.0, 2.0)
	
	# Fade out door
	if door:
		tween.tween_property(door, "modulate:a", 0.0, 2.0)
	
	# Fade out Celine
	if celine:
		tween.tween_property(celine, "modulate:a", 0.0, 2.0)
	
	await tween.finished
	
	# Hide elements after fade out (but keep Miguel visible)
	for tilemap in tilemaps:
		if tilemap:
			tilemap.visible = false
	if door:
		door.visible = false
	if celine:
		celine.visible = false
		# Disable Celine's collision permanently
		var cshape := celine.get_node_or_null("CollisionShape2D")
		if cshape:
			cshape.disabled = true
	
	# Show cinematic text with fade effects
	await show_cinematic_text("Sige, Erwin.", 1.0, 2.0)
	await show_cinematic_text("Papatunayan kita na hindi ka ang may kasalanan.", 1.0, 2.0)
	
	# Fade only tileset and door back in (NOT Celine)
	for tilemap in tilemaps:
		if tilemap:
			tilemap.visible = true
			tilemap.modulate.a = 0.0
	if door:
		door.visible = true
		door.modulate.a = 0.0
	
	# Fade in only tileset and door elements (Celine stays hidden)
	var fade_in_tween = create_tween()
	fade_in_tween.set_parallel(true)
	
	for tilemap in tilemaps:
		if tilemap:
			fade_in_tween.tween_property(tilemap, "modulate:a", 1.0, 1.5)
	if door:
		fade_in_tween.tween_property(door, "modulate:a", 1.0, 1.5)
	
	await fade_in_tween.finished

func show_movement_tutorial() -> void:
	# Tutorial removed per request
	pass

# --------------------------
# TASK MANAGEMENT
# --------------------------
func start_first_task() -> void:
	# Add the first evidence (bodycam) to the evidence inventory
	if has_node("/root/EvidenceInventorySettings"):
		var evidence_ui = get_node("/root/EvidenceInventorySettings")
		evidence_ui.add_evidence("broken_body_cam")
		print("📋 Added bodycam evidence to inventory when starting first task")
	
	if task_manager:
		task_manager.start_next_task()
	else:
		pass

# --------------------------
# STEP 9: End intro
# --------------------------
func end_intro() -> void:
	await dialogue_ui.hide_ui()
	if dialogue_ui and dialogue_ui.has_method("set_cutscene_mode"):
		dialogue_ui.set_cutscene_mode(false)
	if "control_enabled" in player:
		player.control_enabled = true

# --------------------------
# DEBUG: Skip/complete cutscene
# --------------------------
func debug_complete_bedroom_cutscene() -> void:
	print("🚀 DEBUG: Skipping bedroom cutscene and enabling movement")
	
	# Stop any running animations
	if $AnimationPlayer:
		$AnimationPlayer.stop()
		print("📋 AnimationPlayer stopped")
	
	# Hide dialogue UI
	if dialogue_ui:
		dialogue_ui.hide_ui()
		if dialogue_ui.has_method("set_cutscene_mode"):
			dialogue_ui.set_cutscene_mode(false)
		print("📋 Dialogue UI hidden and cutscene mode disabled")
	
	
	# Set checkpoint
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
	
	# Set all completion flags
	intro_complete = true
	celine_interactable = false
	is_cinematic_active = false
	
	# Ensure all tilemaps are visible and at full opacity
	for tilemap in tilemaps:
		if tilemap:
			tilemap.visible = true
			tilemap.modulate.a = 1.0
	
	# Position player properly
	if player:
		player.visible = true
		player.modulate.a = 1.0
		player.anim_sprite.play("idle_down")
		player.last_facing = "front"
		print("📋 Player positioned and visible")
	
	# Hide Celine and disable her collision
	if celine:
		celine.visible = false
		var cshape := celine.get_node_or_null("CollisionShape2D")
		if cshape:
			cshape.disabled = true
		print("📋 Celine hidden and collision disabled")
	
	# Hide door
	if door:
		door.visible = true
		door.modulate.a = 1.0
	
	# Hide the fade overlay
	if fade_overlay:
		fade_overlay.visible = false
	
	# Add the first evidence (bodycam) to the evidence inventory
	if has_node("/root/EvidenceInventorySettings"):
		var evidence_ui = get_node("/root/EvidenceInventorySettings")
		evidence_ui.add_evidence("broken_body_cam")
		print("📋 Added bodycam evidence to inventory")
	
	# Start the first task
	if task_manager:
		task_manager.start_next_task()
		print("📋 First task started")
	
	# CRITICAL: Enable player movement immediately
	if player and player.has_method("enable_movement"):
		player.enable_movement()
		print("✅ Player movement ENABLED - you should be able to move now!")
	else:
		print("⚠️ Player movement enable failed - player or method not found")
	
	print("🚀 DEBUG: Bedroom cutscene skip completed")

func clear_all_checkpoints_and_restart() -> void:
	"""Clear all checkpoints and restart the bedroom cutscene from the beginning"""
	print("🔄 CLEARING ALL CHECKPOINTS - Starting fresh game")
	
	# Clear all checkpoints
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.clear_checkpoint_file()
	print("📋 All checkpoints cleared")
	
	# Clear evidence inventory
	if has_node("/root/EvidenceInventorySettings"):
		var evidence_ui = get_node("/root/EvidenceInventorySettings")
		evidence_ui.collected_evidence.clear()
		print("📋 Evidence inventory cleared")
	
	# Reset task manager
	if task_manager:
		task_manager.current_task = {}
		task_manager.task_queue = []
		task_manager.task_history = []
		task_manager.initialize_tasks()
		print("📋 Task manager reset")
	
	# Reset scene state
	intro_complete = false
	celine_interactable = true
	is_cinematic_active = false
	
	# Show Celine again
	if celine:
		celine.visible = true
		var cshape := celine.get_node_or_null("CollisionShape2D")
		if cshape:
			cshape.disabled = false
	
	# Hide task display
	if task_manager and task_manager.task_display:
		task_manager.task_display.hide_task()
	
	# Disable player movement for cutscene
	if player and player.has_method("disable_movement"):
		player.disable_movement()
	
	# Start the intro cutscene
	start_intro()
	print("🚀 Fresh game started - bedroom cutscene will play")

func _unhandled_input(event: InputEvent) -> void:
	# Handle evidence inventory input (TAB key)
	if event.is_action_pressed("evidence_inventory"):
		# Check if bedroom cutscene is completed
		var checkpoint_manager = get_node_or_null("/root/CheckpointManager")
		var bedroom_cutscene_completed = false
		
		if checkpoint_manager:
			bedroom_cutscene_completed = checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
		
		# Block TAB key during cutscene or cinematic
		if not bedroom_cutscene_completed or is_cinematic_active:
			print("⚠️ Evidence inventory access blocked during cutscene")
			get_viewport().set_input_as_handled()
			return
		else:
			# Toggle Evidence Inventory
			if has_node("/root/EvidenceInventorySettings"):
				var evidence_ui = get_node("/root/EvidenceInventorySettings")
				evidence_ui.toggle_evidence_inventory()
				print("📋 Evidence inventory toggled via TAB in bedroom scene")
			get_viewport().set_input_as_handled()
	
	# Press F10 to instantly complete the bedroom cutscene (debug only)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F10:
			debug_complete_bedroom_cutscene()
		# Press F9 to test dialogue line 0
		elif event.physical_keycode == KEY_F9:
			show_dialogue_line(0)
		# Press F8 to test knock sound
		elif event.physical_keycode == KEY_F8:
			play_knock_sound()
		# Press F7 to clear ALL checkpoints and restart fresh
		elif event.physical_keycode == KEY_F7:
			clear_all_checkpoints_and_restart()

# --------------------------
# STEP 10: Ready
# --------------------------
func _ready() -> void:
	await get_tree().process_frame
	
	# Get TaskManager autoload
	if TaskManager:
		task_manager = TaskManager
	else:
		pass
	
	# Get DialogueUI autoload
	if DialogueUI:
		dialogue_ui = DialogueUI
	else:
		pass
	
	# Connect dialogue UI signals
	if dialogue_ui:
		var cb: Callable = Callable(self, "_on_next_pressed")
		if not dialogue_ui.is_connected("next_pressed", cb):
			dialogue_ui.connect("next_pressed", cb)
	
	# Audio cleanup will be handled by AudioManager automatically
	
	# Set scene BGM using AudioManager
	if AudioManager:
		AudioManager.set_scene_bgm("bedroom")
		print("🎵 Bedroom: Scene BGM set via AudioManager")
	
	# AudioManager now handles BGM - no need for manual BGM playing
	# if bgm and not bgm.playing:
	#	bgm.volume_db = -20
	#	bgm.play()
	#	print("🎵 BGM music started on scene load")
	
	# Check if bedroom cutscene has already been played
	var checkpoint_manager = get_node("/root/CheckpointManager")
	var cutscene_already_played = checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
	
	if cutscene_already_played:
		skip_to_post_cutscene_state()
	else:
		start_intro()

func skip_to_post_cutscene_state() -> void:
	"""Skip to the state after cutscene completion"""
	
	# Set flags as if cutscene was completed
	intro_complete = true
	celine_interactable = false
	
	# Position characters in their final positions
	if player:
		player.anim_sprite.play("idle_down")
		player.last_facing = "front"
	
	# Hide Celine and disable collision if cutscene is completed
	if celine:
		celine.visible = false
		var cshape := celine.get_node_or_null("CollisionShape2D")
		if cshape:
			cshape.disabled = true
	
	# Hide the fade overlay to prevent black square
	if fade_overlay:
		fade_overlay.visible = false
	
	# Add the first evidence (bodycam) to the evidence inventory
	if has_node("/root/EvidenceInventorySettings"):
		var evidence_ui = get_node("/root/EvidenceInventorySettings")
		evidence_ui.add_evidence("broken_body_cam")
		print("📋 Added bodycam evidence to inventory when skipping to post-cutscene state")
	
	# Enable player movement
	if player and player.has_method("enable_movement"):
		player.enable_movement()
		print("📋 Player movement enabled in post-cutscene state")

func cleanup_bedroom_audio() -> void:
	"""Clean up bedroom audio when leaving the scene"""
	# Stop bedroom BGM via AudioManager
	if AudioManager:
		AudioManager.stop_bgm()
		print("🎵 Bedroom: BGM stopped via AudioManager")
	
	# Stop any local audio players
	if bgm:
		bgm.stop()
		print("🎵 Bedroom: Local BGM stopped")
	
	if knock_sfx:
		knock_sfx.stop()
		print("🎵 Bedroom: Knock SFX stopped")
	
	if shock_sfx:
		shock_sfx.stop()
		print("🎵 Bedroom: Shock SFX stopped")
	
	# Force stop all audio streams in the scene
	var audio_players = get_tree().get_nodes_in_group("audio")
	for player in audio_players:
		if player.has_method("stop"):
			player.stop()
	
	# Stop any tweens that might be affecting audio
	var tweens = get_tree().get_nodes_in_group("tween")
	for tween in tweens:
		if tween.has_method("kill"):
			tween.kill()

func _exit_tree() -> void:
	"""Called when the bedroom scene is being removed from the tree"""
	cleanup_bedroom_audio()
	print("🎵 Bedroom: Scene exiting, audio cleaned up")
