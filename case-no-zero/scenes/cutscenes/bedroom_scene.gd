extends Node

# --- Node references ---
var dialogue_ui: CanvasLayer = null  # Will reference global DialogueUI autoload
@onready var player: CharacterBody2D = $PlayerM
@onready var celine: CharacterBody2D = $Celine
@onready var knock_sfx: AudioStreamPlayer = $KnockSFX
@onready var bgm_mystery: AudioStreamPlayer = $BGM_Mystery
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

func play_character_animation(character: CharacterBody2D, animation: String, duration: float = 0.0) -> void:
	if character and "anim_sprite" in character:
		character.anim_sprite.play(animation)
	if duration > 0:
		await get_tree().create_timer(duration).timeout

func move_character_smoothly(character: CharacterBody2D, target_pos: Vector2, walk_animation: String = "walk_down", idle_animation: String = "idle_right") -> void:
	if not character:
		return
		
	var start_pos: Vector2 = character.position
	var distance: float = start_pos.distance_to(target_pos)
	var duration: float = distance / walk_speed
	
	# Play walk animation
	play_character_animation(character, walk_animation)
	
	# Move character
	var t: Tween = create_tween()
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(character, "position", target_pos, duration)
	await t.finished
	
	# Play idle animation
	play_character_animation(character, idle_animation)

func show_dialogue_with_transition(speaker: String, text: String, hide_first: bool = false) -> void:
	if hide_first:
		await dialogue_ui.hide_ui()
		await get_tree().create_timer(transition_pause).timeout
	
	dialogue_ui.show_dialogue_line(speaker, text)
	
	# Calculate dynamic wait time based on text length
	# Typing speed is 0.01s per character, plus extra reading time
	var typing_time = text.length() * 0.01  # Time for typing animation
	var reading_time = max(1.0, text.length() * 0.02)  # Reading time (20ms per char, min 1s)
	var total_wait = typing_time + reading_time
	
	print("💬 Auto-advancing dialogue: ", text.length(), " chars, waiting ", total_wait, "s")
	await get_tree().create_timer(total_wait).timeout
	
	# Auto-advance to next line
	current_line += 1
	show_next_line()

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
	print("✅ Loaded dialogue lines:", dialogue_lines.size())

# --------------------------
# STEP 2: Start intro
# --------------------------
func start_intro() -> void:
	print("🎬 Intro starting...")
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
	await get_tree().create_timer(1.0).timeout
	show_next_line()

# --------------------------
# STEP 3–9: Show dialogue line
# --------------------------
func show_next_line() -> void:
	if current_line >= dialogue_lines.size():
		end_intro()
		return

	var line: Dictionary = dialogue_lines[current_line]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))

	print("🗨️ Showing line", current_line, "Speaker:", speaker)

	# Organized by scene beats for better readability
	match current_line:
		# Opening lines - player alone
		0, 1:
			await play_character_animation(player, "idle_down", transition_pause)
			show_dialogue_with_transition(speaker, text)

		# Knock at door sequence
		2:
			dialogue_ui.hide()
			if knock_sfx:
				knock_sfx.play()
				await knock_sfx.finished

			await play_character_animation(player, "idle_left", 0.5)
			show_dialogue_with_transition(speaker, text, true)

		# Celine enters
		3:
			show_dialogue_with_transition(speaker, text)

		4:
			dialogue_ui.hide()
			celine.visible = true
			await move_character_smoothly(celine, Vector2(9, 184), "walk_down", "idle_right")
			
			# Player reaction sequence
			await play_character_animation(player, "idle_left", 0.4)
			await play_character_animation(player, "idle_right", 0.4)
			show_dialogue_with_transition(speaker, text, true)

		# Celine's introduction
		5:
			show_dialogue_with_transition(speaker, text)

		# Conversation flow - player looking right
		6, 7, 8, 9, 10, 11:
			await play_character_animation(player, "idle_right", transition_pause)
			show_dialogue_with_transition(speaker, text)

		# Player looks left
		12:
			await play_character_animation(player, "idle_left", transition_pause)
			show_dialogue_with_transition(speaker, text)

		# Celine moves right
		13:
			await move_character_smoothly(celine, Vector2(137, celine.position.y), "walk_right", "idle_right")
			show_dialogue_with_transition(speaker, text)

		# More conversation
		14:
			show_dialogue_with_transition(speaker, text)

		# BGM starts and player faces front
		15:
			await play_character_animation(player, "idle_down", transition_pause)
			show_dialogue_with_transition(speaker, text)
			
			# Start background music with smooth fade
			if bgm_mystery and not bgm_mystery.playing:
				bgm_mystery.volume_db = -20
				bgm_mystery.play()
				var music_tween: Tween = create_tween()
				music_tween.set_ease(Tween.EASE_IN_OUT)
				music_tween.tween_property(bgm_mystery, "volume_db", 0, 2.0)

		# Continued conversation
		16, 17, 18:
			show_dialogue_with_transition(speaker, text)

		# Celine faces front
		19, 20, 21:
			await play_character_animation(celine, "idle_front", 0.5)
			show_dialogue_with_transition(speaker, text)

		# Player reactions
		22:
			await play_character_animation(player, "idle_left", transition_pause)
			show_dialogue_with_transition(speaker, text)

		23:
			await play_character_animation(player, "idle_down", transition_pause)
			show_dialogue_with_transition(speaker, text)

		24:
			show_dialogue_with_transition(speaker, text)

		# Celine looks right
		25, 26:
			await play_character_animation(celine, "idle_right", 0.0)
			show_dialogue_with_transition(speaker, text)

		# Player looks left
		27, 28, 29:
			await play_character_animation(player, "idle_left", transition_pause)
			show_dialogue_with_transition(speaker, text)

		# More dialogue
		30, 31, 32:
			show_dialogue_with_transition(speaker, text)

		# Player looks right
		33:
			await play_character_animation(player, "idle_right", transition_pause)
			show_dialogue_with_transition(speaker, text)

		# Player faces front
		34, 35, 36, 37:
			await play_character_animation(player, "idle_down", transition_pause)
			show_dialogue_with_transition(speaker, text)

		# Celine faces front
		38:
			await play_character_animation(celine, "idle_front", 0.0)
			show_dialogue_with_transition(speaker, text)

		# Start cinematic
		39:
			await start_cinematic()

# --------------------------
# STEP 7: On next pressed
# --------------------------
# --------------------------
# STEP 8: Cinematic fade for last line
# --------------------------
func start_cinematic() -> void:
	is_cinematic_active = true
	
	# Smooth transition out of dialogue
	await dialogue_ui.hide_ui()
	
	# Fade out Celine smoothly before hiding environment
	await smooth_fade_out(celine, fade_duration * 0.8)
	celine.visible = false

	# Hide all tilemaps together with smooth fade
	var tilemap_tween: Tween = create_tween()
	tilemap_tween.set_parallel(true)  # Run all tweens in parallel
	for tilemap in tilemaps:
		tilemap_tween.tween_property(tilemap, "modulate:a", 0.0, fade_duration * 0.6)
	if door:
		tilemap_tween.tween_property(door, "modulate:a", 0.0, fade_duration * 0.6)
	await tilemap_tween.finished
	
	# Hide tilemaps after fade
	for tilemap in tilemaps:
		tilemap.visible = false

	# Smooth fade to black
	await smooth_fade_in(fade_overlay, fade_duration * 1.2)

	# --- CINEMATIC PART 1 ---
	await show_cinematic_text("…Sige, Erwin.", 1.0, 1.8)
	await smooth_fade_out(cinematic_text, text_fade_duration)
	
	# Brief pause between texts
	await get_tree().create_timer(0.5).timeout

	# --- CINEMATIC PART 2 ---
	await show_cinematic_text("Tingnan natin kung anong gulong napasukan mo.", 1.2, 2.5)
	
	# Smooth transition back to game
	await smooth_fade_out(cinematic_text, text_fade_duration * 1.2)
	
	# Restore all tilemaps together with smooth fade in
	for tilemap in tilemaps:
		tilemap.visible = true
		tilemap.modulate.a = 0.0
	if door:
		door.visible = true
		door.modulate.a = 0.0

	
	var tilemap_fade_in: Tween = create_tween()
	tilemap_fade_in.set_parallel(true)  # Run all tweens in parallel
	for tilemap in tilemaps:
		tilemap_fade_in.tween_property(tilemap, "modulate:a", 1.0, fade_duration * 0.8)
	if door:
		tilemap_fade_in.tween_property(door, "modulate:a", 1.0, fade_duration * 0.8)
	await tilemap_fade_in.finished
	
	# Restore Celine with smooth fade in
	celine.visible = true
	celine.modulate.a = 0.0
	var celine_tween: Tween = create_tween()
	celine_tween.set_ease(Tween.EASE_IN_OUT)
	celine_tween.set_trans(Tween.TRANS_CUBIC)
	celine_tween.tween_property(celine, "modulate:a", 1.0, fade_duration * 1.0)
	await celine_tween.finished
	
	# Fade out the overlay
	await smooth_fade_out(fade_overlay, fade_duration * 1.5)
	
	# Restore player animation
	player.anim_sprite.play("idle_down")
	
	# Set flags after cinematic; no Celine interaction in bedroom
	intro_complete = true
	celine_interactable = false
	
	# Set global checkpoint to prevent cutscene from replaying
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
	print("🎯 Global checkpoint set: BEDROOM_CUTSCENE_COMPLETED")
	
	# Hide Celine and disable her collision after fade-in
	if celine:
		celine.visible = false
		var cshape := celine.get_node_or_null("CollisionShape2D")
		if cshape:
			cshape.disabled = true
	
	# Start the first task shortly after
	await get_tree().create_timer(0.5).timeout
	start_first_task()
	
	print("✅ Cinematic complete — starting first task.")

func show_cinematic_text(text: String, fade_in_duration: float, hold_duration: float) -> void:
	cinematic_text.text = text
	cinematic_text.visible = true
	cinematic_text.modulate.a = 0.0
	
	# Smooth fade in
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(cinematic_text, "modulate:a", 1.0, fade_in_duration)
	await tween.finished
	
	# Hold the text
	await get_tree().create_timer(hold_duration).timeout

func show_movement_tutorial() -> void:
	# Tutorial removed per request
	pass

# --------------------------
# TASK MANAGEMENT
# --------------------------
func start_first_task() -> void:
	if task_manager:
		print("📋 Starting first task...")
		task_manager.start_next_task()
	else:
		print("⚠️ TaskManager not found!")

# --------------------------
# STEP 9: End intro
# --------------------------
func end_intro() -> void:
	await dialogue_ui.hide_ui()
	if dialogue_ui and dialogue_ui.has_method("set_cutscene_mode"):
		dialogue_ui.set_cutscene_mode(false)
	if "control_enabled" in player:
		player.control_enabled = true
	print("✅ Intro complete — control re-enabled.")

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

# --------------------------
# STEP 10: Ready
# --------------------------
func _ready() -> void:
	await get_tree().process_frame
	
	# Get TaskManager autoload
	if TaskManager:
		task_manager = TaskManager
	else:
		print("⚠️ TaskManager autoload not found - task system disabled")
	
	# Get DialogueUI autoload
	if DialogueUI:
		dialogue_ui = DialogueUI
	else:
		print("⚠️ DialogueUI autoload not found - dialogue system disabled")
	
	# Connect dialogue UI signals
	if dialogue_ui:
		var cb: Callable = Callable(self, "_on_next_pressed")
		if not dialogue_ui.is_connected("next_pressed", cb):
			dialogue_ui.connect("next_pressed", cb)
	
	# Check if bedroom cutscene has already been played
	var checkpoint_manager = get_node("/root/CheckpointManager")
	# TEMPORARY: Clear all checkpoints for testing full flow - remove this line when done
	checkpoint_manager.clear_checkpoint_file()
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
	
	# Hide fade overlay
	if fade_overlay:
		fade_overlay.visible = false
		fade_overlay.modulate.a = 0.0
	
	# Enable player control
	if "control_enabled" in player:
		player.control_enabled = true
	
