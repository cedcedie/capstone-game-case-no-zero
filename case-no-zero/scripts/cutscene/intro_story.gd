extends Node2D

# --- Node references ---
@onready var cinematic_text: Label = $CinematicText

# --- Scene state ---
var is_cinematic_active: bool = false

# --- Dialogue data ---
var dialogue_lines: Array = []
var current_line: int = 0

# --------------------------
# CINEMATIC TEXT METHODS
# --------------------------

func show_cinematic_text(text: String, fade_in_duration: float = 1.0, hold_duration: float = 2.0) -> void:
	"""Display cinematic text with fade in/out effects"""
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

# --------------------------
# ANIMATION METHODS
# --------------------------

func play_intro_animation():
	"""Play the 'intro' animation from AnimationPlayer"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("intro")
		print("🎬 Playing intro animation")
	else:
		print("⚠️ AnimationPlayer not found")

func stop_intro_animation():
	"""Stop the intro animation"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()
		print("🎬 Stopped intro animation")

func pause_intro_animation():
	"""Pause the intro animation"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.pause()
		print("🎬 Paused intro animation")

func resume_intro_animation():
	"""Resume the intro animation"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play()
		print("🎬 Resumed intro animation")

# --------------------------
# DIALOGUE LOADING
# --------------------------

func load_intro_story() -> void:
	"""Load intro story from Intro_story.json"""
	var file: FileAccess = FileAccess.open("res://data/dialogues/Intro_story.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open Intro_story.json")
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("Intro_story"):
		push_error("Failed to parse Intro_story.json correctly")
		return

	dialogue_lines = parsed["Intro_story"]
	current_line = 0
	print("📝 Intro story loaded:", dialogue_lines.size(), "lines")

# --------------------------
# NARRATOR DIALOGUE METHODS
# --------------------------

func show_narrator_line(line_index: int):
	"""Show a specific narrator line as cinematic text"""
	if line_index >= 0 and line_index < dialogue_lines.size():
		var line = dialogue_lines[line_index]
		var text = line["text"]
		var speaker = line["speaker"]
		
		# Show as cinematic text with narrator styling
		await show_cinematic_text(text, 1.2, 3.0)  # Slower fade and longer hold for narrator

# Individual narrator line functions for AnimationPlayer Method Call tracks
func show_narrator_0(): show_narrator_line(0)
func show_narrator_1(): show_narrator_line(1)
func show_narrator_2(): show_narrator_line(2)
func show_narrator_3(): show_narrator_line(3)
func show_narrator_4(): show_narrator_line(4)
func show_narrator_5(): show_narrator_line(5)

# --------------------------
# CHARACTER FADE METHODS
# --------------------------

func fade_in_character(character_name: String, duration: float = 1.0):
	"""Fade in a character by name"""
	var character = get_node_or_null(character_name)
	if character:
		character.visible = true
		character.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(character, "modulate:a", 1.0, duration)
		await tween.finished
		print("✨ Faded in character:", character_name)
	else:
		print("⚠️ Character not found:", character_name)
		# Try to find character with alternative names
		var alt_names = ["Leo", "leo", "LeoMendoza", "leo_mendoza", "Player", "PlayerM"]
		for alt_name in alt_names:
			character = get_node_or_null(alt_name)
			if character:
				print("🔍 Found character with alternative name:", alt_name)
				character.visible = true
				character.modulate.a = 0.0
				var tween = create_tween()
				tween.tween_property(character, "modulate:a", 1.0, duration)
				await tween.finished
				print("✨ Faded in character:", alt_name)
				return
		print("❌ No character found with any name")

func fade_out_character(character_name: String, duration: float = 1.0):
	"""Fade out a character by name"""
	var character = get_node_or_null(character_name)
	if character:
		var tween = create_tween()
		tween.tween_property(character, "modulate:a", 0.0, duration)
		await tween.finished
		character.visible = false
		print("✨ Faded out character:", character_name)
	else:
		print("⚠️ Character not found:", character_name)
		# Try to find character with alternative names
		var alt_names = ["Leo", "leo", "LeoMendoza", "leo_mendoza", "Player", "PlayerM"]
		for alt_name in alt_names:
			character = get_node_or_null(alt_name)
			if character:
				print("🔍 Found character with alternative name:", alt_name)
				var tween = create_tween()
				tween.tween_property(character, "modulate:a", 0.0, duration)
				await tween.finished
				character.visible = false
				print("✨ Faded out character:", alt_name)
				return
		print("❌ No character found with any name")

# Specific character fade methods for AnimationPlayer
func hide_leo():
	"""Immediately hide Leo character at 0 opacity"""
	var leo = get_node_or_null("Leo")
	if leo:
		leo.visible = true
		leo.modulate.a = 0.0
		print("👻 Leo hidden at 0 opacity")
	else:
		print("⚠️ Leo not found, trying alternative names...")
		var alt_names = ["leo", "LeoMendoza", "leo_mendoza", "Player", "PlayerM"]
		for alt_name in alt_names:
			leo = get_node_or_null(alt_name)
			if leo:
				print("🔍 Found Leo with alternative name:", alt_name)
				leo.visible = true
				leo.modulate.a = 0.0
				print("👻 Leo hidden at 0 opacity")
				return
		print("❌ No Leo character found")

func fade_in_leo():
	"""Fade in Leo character"""
	await fade_in_character("Leo")

func fade_out_leo():
	"""Fade out Leo character"""
	await fade_out_character("Leo")

# --------------------------
# AUDIO FADE METHODS
# --------------------------

func fade_out_mystery_bgm(duration: float = 2.0):
	"""Fade out the mystery BGM"""
	if AudioManager:
		await AudioManager.fade_out_bgm(duration)
		print("🎵 Mystery BGM faded out")
	else:
		print("⚠️ AudioManager not found")

func start_mystery_bgm():
	"""Start the mystery BGM for intro story"""
	if AudioManager:
		# Set a mystery BGM for intro story
		AudioManager.set_scene_bgm("intro_story")
		print("🎵 Mystery BGM started for intro story")
	else:
		print("⚠️ AudioManager not found")

func stop_mystery_bgm():
	"""Stop the mystery BGM immediately"""
	if AudioManager:
		AudioManager.stop_bgm()
		print("🎵 Mystery BGM stopped")
	else:
		print("⚠️ AudioManager not found")

# --------------------------
# CHARACTER COLOR METHODS
# --------------------------

func make_character_white(character_name: String):
	"""Make a character completely white"""
	var character = get_node_or_null(character_name)
	if character:
		character.modulate = Color.WHITE
		print("⚪ Character made white:", character_name)
	else:
		print("⚠️ Character not found:", character_name)

func make_character_red(character_name: String):
	"""Make a character red"""
	var character = get_node_or_null(character_name)
	if character:
		character.modulate = Color.RED
		print("🔴 Character made red:", character_name)
	else:
		print("⚠️ Character not found:", character_name)

func make_character_black(character_name: String):
	"""Make a character black"""
	var character = get_node_or_null(character_name)
	if character:
		character.modulate = Color.BLACK
		print("⚫ Character made black:", character_name)
	else:
		print("⚠️ Character not found:", character_name)

func make_character_normal(character_name: String):
	"""Reset character to normal color"""
	var character = get_node_or_null(character_name)
	if character:
		character.modulate = Color.WHITE
		print("🎨 Character reset to normal:", character_name)
	else:
		print("⚠️ Character not found:", character_name)

# Specific Leo color methods for AnimationPlayer
func make_leo_white():
	"""Make Leo white"""
	make_character_white("Leo")

func make_leo_red():
	"""Make Leo red"""
	make_character_red("Leo")

func make_leo_black():
	"""Make Leo black"""
	make_character_black("Leo")

func make_leo_normal():
	"""Reset Leo to normal color"""
	make_character_normal("Leo")


# --------------------------
# CUTSCENE END METHODS
# --------------------------

func end_intro_cutscene():
	"""End the intro cutscene and transition to bedroom scene for bedroom cutscene"""
	print("🎬 Ending intro cutscene...")
	
	# Hide all characters
	hide_leo()
	
	# Set checkpoint to mark intro story as completed (but not bedroom cutscene)
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.BEDROOM_COMPLETED)
	print("📋 Intro story checkpoint set")
	
	# Smooth audio transition - fade out intro BGM
	print("🎵 Fading out intro BGM...")
	await fade_out_mystery_bgm(2.0)  # 2-second fade out
	
	# Brief pause for smooth transition
	await get_tree().create_timer(0.5).timeout
	
	print("🏠 Transitioning to bedroom scene for bedroom cutscene...")
	
	# Try multiple possible scene paths
	var bedroom_scene_paths = [
		"res://scenes/cutscenes/bedroomScene.tscn",
		"res://scenes/cutscenes/bedroom_scene.tscn", 
		"res://scenes/cutscenes/bedroom.tscn",
		"res://bedroomScene.tscn",
		"res://scenes/bedroomScene.tscn"
	]
	
	for scene_path in bedroom_scene_paths:
		if ResourceLoader.exists(scene_path):
			print("🏠 Found bedroom scene at:", scene_path)
			get_tree().change_scene_to_file(scene_path)
			return
	
	print("❌ No bedroom scene found! Available scenes:")
	print("   - res://scenes/cutscenes/bedroomScene.tscn")
	print("   - res://scenes/cutscenes/bedroom_scene.tscn")
	print("   - res://scenes/cutscenes/bedroom.tscn")
	print("   - res://bedroomScene.tscn")
	print("   - res://scenes/bedroomScene.tscn")

func hide_all_characters():
	"""Hide all characters in the scene"""
	hide_leo()
	print("👻 All characters hidden")

# --------------------------
# DEBUG CONTROLS AND LINEAR FLOW
# --------------------------

func skip_to_bedroom():
	"""Skip intro story and go directly to bedroom scene"""
	print("🚀 DEBUG: Skipping intro story, going to bedroom")
	
	# DON'T set bedroom cutscene as completed - let the bedroom scene handle it
	print("📋 Going to bedroom scene - cutscene will play")
	
	# Transition to bedroom scene
	await get_tree().create_timer(0.5).timeout
	print("🏠 Transitioning to bedroom scene...")
	
	# Try multiple possible scene paths
	var bedroom_scene_paths = [
		"res://scenes/cutscenes/bedroomScene.tscn",
		"res://scenes/cutscenes/bedroom_scene.tscn", 
		"res://scenes/cutscenes/bedroom.tscn",
		"res://bedroomScene.tscn",
		"res://scenes/bedroomScene.tscn"
	]
	
	for scene_path in bedroom_scene_paths:
		if ResourceLoader.exists(scene_path):
			print("🏠 Found bedroom scene at:", scene_path)
			get_tree().change_scene_to_file(scene_path)
			return
	
	print("❌ No bedroom scene found!")

func debug_complete_intro():
	"""Debug function to complete intro story instantly"""
	print("🚀 DEBUG: Completing intro story instantly")
	
	# Stop any running animations
	if $AnimationPlayer:
		$AnimationPlayer.stop()
		print("📋 AnimationPlayer stopped")
	
	# DON'T set bedroom cutscene as completed - let the bedroom scene handle it
	print("📋 Going to bedroom scene - cutscene will play")
	
	# Transition to bedroom scene
	await get_tree().create_timer(0.5).timeout
	skip_to_bedroom()

func debug_restart_intro():
	"""Debug function to restart intro story from beginning"""
	print("🔄 DEBUG: Restarting intro story from beginning")
	
	# Restart the intro sequence
	start_intro()

func _unhandled_input(event: InputEvent) -> void:
	"""Handle debug input controls"""
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F10:
				# F10 - Complete intro story instantly and go to bedroom
				debug_complete_intro()
			KEY_F7:
				# F7 - Restart intro story from beginning
				debug_restart_intro()
			KEY_F1:
				# F1 - Skip to bedroom scene
				skip_to_bedroom()
			KEY_F2:
				# F2 - Start mystery BGM
				start_mystery_bgm()
			KEY_F3:
				# F3 - Stop mystery BGM
				stop_mystery_bgm()
			KEY_F4:
				# F4 - Fade out mystery BGM
				fade_out_mystery_bgm()

# --------------------------
# SCENE INITIALIZATION
# --------------------------

func start_intro() -> void:
	"""Start the intro sequence"""
	# Load the intro story dialogue
	load_intro_story()
	
	# Smooth audio transition - start mystery BGM with fade in
	print("🎵 Starting mystery BGM with smooth fade in...")
	start_mystery_bgm()
	
	# Auto-play the intro animation when scene starts
	play_intro_animation()

func _ready() -> void:
	"""Initialize the intro story scene"""
	await get_tree().process_frame
	
	# Set scene BGM using AudioManager
	if AudioManager:
		AudioManager.set_scene_bgm("intro_story")
		print("🎵 Intro Story: Scene BGM set via AudioManager")
	
	# Clear bedroom cutscene checkpoint to ensure it plays
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.clear_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
	print("📋 Cleared bedroom cutscene checkpoint - cutscene will play")
	
	print("📋 Starting intro story sequence")
	# Start the intro sequence
	start_intro()
