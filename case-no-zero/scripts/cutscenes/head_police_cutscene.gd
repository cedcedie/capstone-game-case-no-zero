extends Node2D

# --- Scene state ---
var is_cinematic_active: bool = false
var is_in_cutscene: bool = false

# --- Dialogue data ---
var dialogue_lines: Array = []
var current_line: int = 0

# --------------------------
# ANIMATION METHODS
# --------------------------

func play_head_police_animation():
	"""Play the 'head_police_cutscene' animation from AnimationPlayer"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("head_police_cutscene")
		print("🎬 Playing head police cutscene animation")
	else:
		print("⚠️ AnimationPlayer not found")

func stop_head_police_animation():
	"""Stop the head police animation"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()
		print("🎬 Stopped head police animation")

func pause_head_police_animation():
	"""Pause the head police animation"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.pause()
		print("🎬 Paused head police animation")

func resume_head_police_animation():
	"""Resume the head police animation"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play()
		print("🎬 Resumed head police animation")

# --------------------------
# DIALOGUE LOADING AND DISPLAY
# --------------------------

func load_head_police_dialogue() -> Array:
	"""Load head police cutscene dialogue from JSON"""
	var file: FileAccess = FileAccess.open("res://data/dialogues/head_police_cutscene_dialogue.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open head_police_cutscene_dialogue.json")
		return []

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("head_police_cutscene"):
		push_error("Failed to parse head_police_cutscene_dialogue.json correctly")
		return []

	dialogue_lines = parsed["head_police_cutscene"]["dialogue_lines"]
	print("📝 Head police cutscene dialogue loaded:", dialogue_lines.size(), "lines")
	return dialogue_lines

func play_dialogue():
	"""Play the head police cutscene dialogue using DialogueUI"""
	print("💬 Starting head police cutscene dialogue")
	
	if not DialogueUI:
		print("⚠️ DialogueUI autoload not found")
		return
	
	# Load dialogue from JSON file
	var dialogue_lines = load_head_police_dialogue()
	if dialogue_lines.is_empty():
		print("⚠️ Failed to load dialogue from JSON")
		return
	
	# Show each dialogue line (auto-advance for cutscene)
	for line in dialogue_lines:
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		DialogueUI.show_dialogue_line(speaker, text)
		
		# Text loads for 1.5 seconds, then 1.5 seconds reading time
		var typing_time = 1.5  # Fixed 1.5s for text to load
		var reading_time = 1.5  # Fixed 1.5s reading time
		var total_wait = typing_time + reading_time
		
		print("💬 Auto-advancing dialogue: ", text.length(), " chars, waiting ", total_wait, "s")
		await get_tree().create_timer(total_wait).timeout
	
	# Hide dialogue after all lines shown
	DialogueUI.hide_ui()
	print("💬 Head police cutscene dialogue completed")

# Individual character line functions for AnimationPlayer Method Call tracks
func show_line_0(): await play_dialogue_line(0)
func show_line_1(): await play_dialogue_line(1)
func show_line_2(): await play_dialogue_line(2)
func show_line_3(): await play_dialogue_line(3)
func show_line_4(): await play_dialogue_line(4)
func show_line_5(): await play_dialogue_line(5)
func show_line_6(): await play_dialogue_line(6)
func show_line_7(): await play_dialogue_line(7)
func show_line_8(): await play_dialogue_line(8)
func show_line_9(): await play_dialogue_line(9)
func show_line_10(): await play_dialogue_line(10)
func show_line_11(): await play_dialogue_line(11)
func show_line_12(): await play_dialogue_line(12)
func show_line_13(): await play_dialogue_line(13)
func show_line_14(): await play_dialogue_line(14)
func show_line_15(): await play_dialogue_line(15)
func show_line_16(): 
	await play_dialogue_line(16)
	# Show evidence inventory after line 16
	await show_evidence_inventory()
func show_line_17(): await play_dialogue_line(17)
func show_line_18(): await play_dialogue_line(18)
func show_line_19(): await play_dialogue_line(19)
func show_line_20(): await play_dialogue_line(20)
func show_line_21(): await play_dialogue_line(21)
func show_line_22(): await play_dialogue_line(22)
func show_line_23(): await play_dialogue_line(23)
func show_line_24(): await play_dialogue_line(24)
func show_line_25(): await play_dialogue_line(25)
func show_line_26(): await play_dialogue_line(26)
func show_line_27(): await play_dialogue_line(27)

func play_dialogue_line(line_index: int):
	"""Play a specific dialogue line using DialogueUI"""
	if line_index >= 0 and line_index < dialogue_lines.size():
		var line = dialogue_lines[line_index]
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		
		if DialogueUI:
			DialogueUI.show_dialogue_line(speaker, text)
			# Text loads for 1.5 seconds, then 1.5 seconds reading time
			var typing_time = 1.5  # Fixed 1.5s for text to load
			var reading_time = 1.5  # Fixed 1.5s reading time
			await get_tree().create_timer(typing_time + reading_time).timeout

# --------------------------
# EVIDENCE INVENTORY DISPLAY
# --------------------------

func show_evidence_inventory():
	"""Show evidence inventory after line 16, similar to barangay hall cutscene"""
	print("📋 Showing evidence inventory after line 16")
	
	# Wait 3 seconds before showing evidence (like barangay hall)
	await get_tree().create_timer(3.0).timeout
	
	# Hide dialogue when showing inventory
	if DialogueUI:
		DialogueUI.hide_ui()
		print("📋 Dialogue hidden for inventory")
	
	# Show evidence inventory
	if has_node("/root/EvidenceInventorySettings"):
		var evidence_ui = get_node("/root/EvidenceInventorySettings")
		
		# Show evidence inventory
		evidence_ui.show_evidence_inventory()
		print("📋 Evidence inventory shown")
		
		# Add radio log evidence
		evidence_ui.add_evidence("radio_log")
		print("📋 Added radio_log evidence")
		
		# Flash inventory for 3 seconds then auto-close (like a cutscene)
		print("📋 Flashing evidence inventory for 3 seconds")
		await get_tree().create_timer(3.0).timeout
		
		# Auto-close inventory after 3 seconds
		if evidence_ui:
			await evidence_ui.hide_evidence_inventory()
			print("📋 Evidence inventory auto-closed after 3 seconds")
		
		print("📋 Evidence inventory closed, continuing dialogue")
	else:
		print("⚠️ EvidenceInventorySettings not found")

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

# Specific character fade methods for AnimationPlayer
func fade_in_miguel():
	"""Fade in Miguel character"""
	await fade_in_character("Miguel")

func fade_out_miguel():
	"""Fade out Miguel character"""
	await fade_out_character("Miguel")

func fade_in_celine():
	"""Fade in Celine character"""
	await fade_in_character("Celine")

func fade_out_celine():
	"""Fade out Celine character"""
	await fade_out_character("Celine")

func fade_in_po1_darwin():
	"""Fade in PO1 Darwin character"""
	await fade_in_character("PO1_Darwin")

func fade_out_po1_darwin():
	"""Fade out PO1 Darwin character"""
	await fade_out_character("PO1_Darwin")

func fade_in_random_police():
	"""Fade in Random Police character"""
	await fade_in_character("Random_Police")

func fade_out_random_police():
	"""Fade out Random Police character"""
	await fade_out_character("Random_Police")

# --------------------------
# AUDIO FADE METHODS
# --------------------------

func fade_out_police_bgm(duration: float = 2.0):
	"""Fade out the police station BGM"""
	if AudioManager:
		await AudioManager.fade_out_bgm(duration)
		print("🎵 Police station BGM faded out")
	else:
		print("⚠️ AudioManager not found")

func start_police_bgm():
	"""Start the police station BGM for head police cutscene"""
	if AudioManager:
		AudioManager.set_scene_bgm("police_station")
		print("🎵 Police station BGM started for head police cutscene")
	else:
		print("⚠️ AudioManager not found")

func stop_police_bgm():
	"""Stop the police station BGM immediately"""
	if AudioManager:
		AudioManager.stop_bgm()
		print("🎵 Police station BGM stopped")
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

# Specific character color methods for AnimationPlayer
func make_miguel_white(): make_character_white("Miguel")
func make_miguel_red(): make_character_red("Miguel")
func make_miguel_black(): make_character_black("Miguel")
func make_miguel_normal(): make_character_normal("Miguel")

func make_celine_white(): make_character_white("Celine")
func make_celine_red(): make_character_red("Celine")
func make_celine_black(): make_character_black("Celine")
func make_celine_normal(): make_character_normal("Celine")

func make_po1_darwin_white(): make_character_white("PO1_Darwin")
func make_po1_darwin_red(): make_character_red("PO1_Darwin")
func make_po1_darwin_black(): make_character_black("PO1_Darwin")
func make_po1_darwin_normal(): make_character_normal("PO1_Darwin")

# --------------------------
# CUTSCENE END METHODS
# --------------------------

func end_head_police_cutscene():
	"""End the head police cutscene and transition to next scene"""
	print("🎬 Ending head police cutscene...")
	
	# Disable cutscene mode for DialogueUI
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(false)
		print("🎬 DialogueUI cutscene mode disabled")
	
	# Hide all characters
	fade_out_miguel()
	fade_out_celine()
	fade_out_po1_darwin()
	fade_out_random_police()
	
	# Set checkpoint to mark head police cutscene as completed
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED)
	print("📋 Head police cutscene checkpoint set")
	
	# Smooth audio transition - fade out police BGM
	print("🎵 Fading out police BGM...")
	await fade_out_police_bgm(2.0)  # 2-second fade out
	
	# Brief pause for smooth transition
	await get_tree().create_timer(0.5).timeout
	
	print("✅ Head police cutscene completed - returning to normal gameplay")

func hide_all_characters():
	"""Hide all characters in the scene"""
	fade_out_miguel()
	fade_out_celine()
	fade_out_po1_darwin()
	fade_out_random_police()
	print("👻 All characters hidden")

# --------------------------
# DEBUG CONTROLS AND LINEAR FLOW
# --------------------------

func skip_to_next_scene():
	"""Skip head police cutscene and go directly to morgue scene"""
	print("🚀 DEBUG: Skipping head police cutscene, going to morgue scene")
	
	# Disable cutscene mode for DialogueUI
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(false)
		print("🎬 DialogueUI cutscene mode disabled")
	
	# Set checkpoint
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED)
	print("📋 Head police cutscene checkpoint set")
	
	# Brief pause for smooth transition
	await get_tree().create_timer(0.5).timeout
	print("✅ Head police cutscene skipped - returning to normal gameplay")

func debug_complete_head_police():
	"""Debug function to complete head police cutscene instantly"""
	print("🚀 DEBUG: Completing head police cutscene instantly")
	
	# Stop any running animations
	if $AnimationPlayer:
		$AnimationPlayer.stop()
		print("📋 AnimationPlayer stopped")
	
	# Set checkpoint
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED)
	print("📋 Head police cutscene checkpoint set")
	
	# Transition to next scene
	await get_tree().create_timer(0.5).timeout
	skip_to_next_scene()

func debug_restart_head_police():
	"""Debug function to restart head police cutscene from beginning"""
	print("🔄 DEBUG: Restarting head police cutscene from beginning")
	
	# Restart the head police sequence
	start_head_police_cutscene()

func _unhandled_input(event: InputEvent) -> void:
	"""Handle debug input controls"""
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F10:
				# F10 - Complete head police cutscene instantly and go to next scene
				debug_complete_head_police()
			KEY_F7:
				# F7 - Restart head police cutscene from beginning
				debug_restart_head_police()
			KEY_F1:
				# F1 - Skip to next scene
				skip_to_next_scene()
			KEY_F2:
				# F2 - Start police BGM
				start_police_bgm()
			KEY_F3:
				# F3 - Stop police BGM
				stop_police_bgm()
			KEY_F4:
				# F4 - Fade out police BGM
				fade_out_police_bgm()

# --------------------------
# SCENE INITIALIZATION
# --------------------------

func start_head_police_cutscene() -> void:
	"""Start the head police cutscene sequence"""
	is_in_cutscene = true
	
	# Enable cutscene mode for DialogueUI (hide Next button)
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(true)
		print("🎬 DialogueUI set to cutscene mode")
	
	# Smooth audio transition - start police BGM with fade in
	print("🎵 Starting police BGM with smooth fade in...")
	start_police_bgm()
	
	# Auto-play the head police animation when scene starts
	play_head_police_animation()
	
	# Start the dialogue after a brief delay
	await get_tree().create_timer(1.0).timeout
	await play_dialogue()
	
	# End the cutscene
	end_head_police_cutscene()

func _ready() -> void:
	"""Initialize the head police cutscene"""
	await get_tree().process_frame
	
	# Set scene BGM using AudioManager
	if AudioManager:
		AudioManager.set_scene_bgm("police_station")
		print("🎵 Head Police Cutscene: Scene BGM set via AudioManager")
	
	# Clear head police cutscene checkpoint to ensure it plays
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.clear_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED)
	print("📋 Cleared head police cutscene checkpoint - cutscene will play")
	
	print("📋 Starting head police cutscene sequence")
	# Start the head police cutscene sequence
	start_head_police_cutscene()
