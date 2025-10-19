extends Node

# --- Node references ---
var dialogue_ui: CanvasLayer = null  # Will reference global DialogueUI autoload
@onready var player: CharacterBody2D = $PlayerM
@onready var celine: CharacterBody2D = $Celine
@onready var knock_sfx: AudioStreamPlayer = $KnockSFX
@onready var bgm_mystery: AudioStreamPlayer = $BGM_Mystery
@onready var cinematic_text: Label = $CinematicText
@onready var door: Area2D = $Door
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

	# Disable player control
	if "control_enabled" in player:
		player.control_enabled = false

	# Setup initial states
	player.anim_sprite.play("idle_down")
	player.last_facing = "front"

	celine.position = Vector2(9, 40)
	celine.visible = false

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
		
		# Calculate faster timing for testing (2 seconds per dialogue)
		var typing_time = text.length() * 0.005  # Faster typing: 5ms per character
		var reading_time = max(0.5, text.length() * 0.01)  # Faster reading: 10ms per char, min 0.5s
		var total_wait = typing_time + reading_time
		
		# Show dialogue
		dialogue_ui.show_dialogue_line(line["speaker"], text)
		
		# Wait for the calculated time
		await get_tree().create_timer(total_wait).timeout

# Auto-vanish function for end of dialogue groups
func auto_vanish_dialogue():
	dialogue_ui.hide_ui()

# Shocked camera shake - more dramatic and sudden
func camera_shake_shocked():
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
func show_dialogue_44(): show_dialogue_line(44)
func show_dialogue_45(): show_dialogue_line(45)
func show_dialogue_46(): show_dialogue_line(46)
func show_dialogue_47(): show_dialogue_line(47)
func show_dialogue_48(): show_dialogue_line(48)
func show_dialogue_49(): show_dialogue_line(49)
func show_dialogue_50(): show_dialogue_line(50)
func show_dialogue_51(): show_dialogue_line(51)
func show_dialogue_52(): show_dialogue_line(52)
func show_dialogue_53(): show_dialogue_line(53)
func show_dialogue_54(): show_dialogue_line(54)
func show_dialogue_55(): show_dialogue_line(55)
func show_dialogue_56(): show_dialogue_line(56)
func show_dialogue_57(): show_dialogue_line(57)
func show_dialogue_58(): show_dialogue_line(58)
func show_dialogue_59(): show_dialogue_line(59)
func show_dialogue_60(): show_dialogue_line(60)
func show_dialogue_61(): show_dialogue_line(61)
func show_dialogue_62(): show_dialogue_line(62)
func show_dialogue_63(): show_dialogue_line(63)
func show_dialogue_64(): show_dialogue_line(64)
func show_dialogue_65(): show_dialogue_line(65)
func show_dialogue_66(): show_dialogue_line(66)
func show_dialogue_67(): show_dialogue_line(67)

# Special action functions
func play_knock_sound():
	if knock_sfx:
		knock_sfx.play()

func start_bgm():
	if bgm_mystery and not bgm_mystery.playing:
		bgm_mystery.volume_db = -20
		bgm_mystery.play()

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
	
	# Re-enable player control
	if "control_enabled" in player:
		player.control_enabled = true
	
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
	
	# Simple fade out Celine
	celine.modulate.a = 0.0
	celine.visible = false

	# Hide all tilemaps
	for tilemap in tilemaps:
		tilemap.visible = false
	if door:
		door.visible = false

	# Fade to black (using fade_all_out instead of fade_overlay)
	await fade_all_out(fade_duration)

	# --- CINEMATIC PART 1 ---
	await show_cinematic_text("…Sige, Erwin.", 1.0, 1.8)
	cinematic_text.visible = false
	
	# Brief pause between texts
	await get_tree().create_timer(0.5).timeout

	# --- CINEMATIC PART 2 ---
	await show_cinematic_text("Tingnan natin kung anong gulong napasukan mo.", 1.2, 2.5)
	cinematic_text.visible = false
	
	# Restore all tilemaps
	for tilemap in tilemaps:
		tilemap.visible = true
		tilemap.modulate.a = 1.0
	if door:
		door.visible = true
		door.modulate.a = 1.0
	
	# Restore Celine
	celine.visible = true
	celine.modulate.a = 1.0
	
	# Fade out (using fade_all_in instead of fade_overlay)
	await fade_all_in(fade_duration)
	
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
	# Instantly fade out tileset and Celine
	for tilemap in tilemaps:
		if tilemap:
			tilemap.modulate.a = 0.0
			tilemap.visible = false
	if celine:
		celine.modulate.a = 0.0
		celine.visible = false
		# Disable Celine's collision permanently
		var cshape := celine.get_node_or_null("CollisionShape2D")
		if cshape:
			cshape.disabled = true
	
	# Show cinematic text with fade effects
	await show_cinematic_text("Sige, Erwin.", 1.0, 2.0)
	await show_cinematic_text("Papatunayan kita na hindi ka ang may kasalanan.", 1.0, 2.0)
	
	# Fade only tileset back in (NOT Celine)
	for tilemap in tilemaps:
		if tilemap:
			tilemap.visible = true
			tilemap.modulate.a = 0.0
	
	# Fade in only tileset elements (Celine stays hidden)
	var tween = create_tween()
	tween.set_parallel(true)
	
	for tilemap in tilemaps:
		if tilemap:
			tween.tween_property(tilemap, "modulate:a", 1.0, 1.5)
	
	await tween.finished

func show_movement_tutorial() -> void:
	# Tutorial removed per request
	pass

# --------------------------
# TASK MANAGEMENT
# --------------------------
func start_first_task() -> void:
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
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
	if dialogue_ui and dialogue_ui.has_method("set_cutscene_mode"):
		dialogue_ui.set_cutscene_mode(false)
	skip_to_post_cutscene_state()

func _unhandled_input(event: InputEvent) -> void:
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
	
	# Check if bedroom cutscene has already been played
	var checkpoint_manager = get_node("/root/CheckpointManager")
	# TEMPORARY DEBUG: Clear checkpoint to test cutscene repeatedly
	checkpoint_manager.clear_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
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
	
	if celine:
		celine.anim_sprite.play("idle_front")
		celine.modulate.a = 1.0
		celine.visible = true
	
	# Note: fade_overlay node has been removed
	
	# Enable player control
	if "control_enabled" in player:
		player.control_enabled = true
	
