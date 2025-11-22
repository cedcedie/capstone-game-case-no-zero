extends Node

# Courtroom Manager - Handles courtroom gameplay, dialogue, evidence presentation, and cross-examination

@onready var anim_player: AnimationPlayer = get_node_or_null("../AnimationPlayer")
var camera: Camera2D = null
var player_camera: Camera2D = null  # Store player's camera to disable it

# Evidence display sprite (shows evidence from EvidenceInventorySettings)
var evidence_display_sprite: Sprite2D = null
var evidence_display_anim_player: AnimationPlayer = null

# Gavel and Objection sprites (create these in scene)
var gavel_sprite: Node2D = null
var objection_sprite: Node2D = null

# Dialogue chooser (autoload or scene node)
var dialog_chooser = null

var dialogue_data: Dictionary = {}
var current_dialogue_index: int = 0
var current_phase: String = "opening_statements_phase"
var evidence_presentation_active: bool = false
var selected_evidence: String = ""
var waiting_for_choice: bool = false
var choice_result: int = -1

# Character positions for camera (adjust based on your scene)
var camera_positions: Dictionary = {
	"judge": Vector2(640, 200),
	"defendant": Vector2(640, 500),
	"prosecutor": Vector2(400, 400),
	"center": Vector2(712, 312),
	"celine": Vector2(500, 450),
	"po1_cordero": Vector2(780, 450),
	"dr_leticia": Vector2(640, 400),
	"kapitana": Vector2(400, 500)
}

# Camera zoom levels (higher = more zoomed in)
var camera_zoom_levels: Dictionary = {
	"judge": Vector2(2.5, 2.5),
	"defendant": Vector2(2.5, 2.5),
	"prosecutor": Vector2(2.5, 2.5),
	"center": Vector2(2.0, 2.0),  # Default zoom
	"celine": Vector2(2.5, 2.5),
	"po1_cordero": Vector2(2.5, 2.5),
	"dr_leticia": Vector2(2.5, 2.5),
	"kapitana": Vector2(2.5, 2.5)
}

# Store original positions for gavel and objection
var gavel_original_pos: Vector2 = Vector2.ZERO
var objection_original_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	print("🎬 Courtroom Manager: Initializing...")
	
	# Load dialogue data
	_load_dialogue_data()
	
	# Find AnimationPlayer if not found
	if not anim_player:
		anim_player = get_tree().current_scene.get_node_or_null("AnimationPlayer")
		if anim_player:
			print("🎬 Courtroom Manager: Found AnimationPlayer")
		else:
			print("⚠️ Courtroom Manager: AnimationPlayer not found")
	
	# Find camera (dedicated courtroom camera)
	_find_camera()
	
	# Disable player camera and enable courtroom camera
	_setup_camera()
	
	# Find DialogChooser
	_find_dialog_chooser()
	
	# Find evidence display sprite and animation
	_find_evidence_display()
	
	# Setup gavel and objection
	_setup_gavel_objection()
	
	# Disable player movement during courtroom
	_disable_player_movement()
	
	# Wait a moment for scene to initialize
	await get_tree().create_timer(0.5).timeout
	
	# Start courtroom sequence
	_start_courtroom_sequence()

func _load_dialogue_data() -> void:
	"""Load courtroom dialogue from JSON"""
	var file = FileAccess.open("res://data/dialogues/courtroom_dialogue.json", FileAccess.READ)
	if file == null:
		print("⚠️ Courtroom Manager: Could not open courtroom_dialogue.json")
		return
	
	var text = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("⚠️ Courtroom Manager: Failed to parse courtroom_dialogue.json")
		return
	
	dialogue_data = parsed.get("courtroom", {})
	print("🎬 Courtroom Manager: Dialogue data loaded")

func _find_dialog_chooser() -> void:
	"""Find DialogChooser autoload or scene node"""
	# Try autoload first
	dialog_chooser = get_node_or_null("/root/DialogChooser")
	if not dialog_chooser:
		# Try scene node
		dialog_chooser = get_tree().current_scene.get_node_or_null("DialogChooser")
	if dialog_chooser:
		if dialog_chooser.has_signal("choice_selected"):
			dialog_chooser.choice_selected.connect(_on_choice_selected)
		print("🎬 Courtroom: DialogChooser found")
	else:
		print("⚠️ Courtroom: DialogChooser not found - choices will not work")

func _find_evidence_display() -> void:
	"""Find evidence display sprite and animation player"""
	evidence_display_sprite = get_tree().current_scene.get_node_or_null("EvidenceDisplaySprite")
	if not evidence_display_sprite:
		# Try alternative names
		evidence_display_sprite = get_tree().current_scene.get_node_or_null("EvidenceSprite")
	
	if evidence_display_sprite:
		# Hide by default
		evidence_display_sprite.visible = false
		evidence_display_sprite.modulate.a = 0.0
		print("🎬 Courtroom: Evidence display sprite found")
		
		# Find AnimationPlayer for evidence display
		evidence_display_anim_player = evidence_display_sprite.get_node_or_null("AnimationPlayer")
		if not evidence_display_anim_player:
			evidence_display_anim_player = get_tree().current_scene.get_node_or_null("EvidenceDisplayAnim")
		if evidence_display_anim_player:
			print("🎬 Courtroom: Evidence display AnimationPlayer found")
		else:
			print("⚠️ Courtroom: Evidence display AnimationPlayer not found")
	else:
		print("⚠️ Courtroom: Evidence display sprite not found - create EvidenceDisplaySprite node")

func _setup_gavel_objection() -> void:
	"""Setup gavel and objection sprites - hide by default and store original positions"""
	if not gavel_sprite:
		gavel_sprite = get_tree().current_scene.get_node_or_null("GavelSprite")
	
	if gavel_sprite:
		gavel_original_pos = gavel_sprite.position
		gavel_sprite.visible = false
		gavel_sprite.modulate.a = 0.0
		print("🎬 Courtroom: Gavel sprite setup at ", gavel_original_pos)
	else:
		print("⚠️ Courtroom: Gavel sprite not found")
	
	if not objection_sprite:
		objection_sprite = get_tree().current_scene.get_node_or_null("ObjectionSprite")
	
	if objection_sprite:
		objection_original_pos = objection_sprite.position
		objection_sprite.visible = false
		objection_sprite.modulate.a = 0.0
		print("🎬 Courtroom: Objection sprite setup at ", objection_original_pos)
	else:
		print("⚠️ Courtroom: Objection sprite not found")

func _start_courtroom_sequence() -> void:
	"""Start the courtroom dialogue sequence"""
	print("🎬 Courtroom Manager: Starting courtroom sequence")
	
	# Check if we should play intro animation
	if anim_player and anim_player.has_animation("courtroom_intro"):
		print("🎬 Courtroom: Playing courtroom_intro animation")
		anim_player.play("courtroom_intro")
		# Wait for animation to finish
		await anim_player.animation_finished
		print("🎬 Courtroom: Intro animation finished")
	
	# Get dialogue lines
	var dialogue_lines = dialogue_data.get("dialogue_lines", [])
	if dialogue_lines.is_empty():
		print("⚠️ Courtroom Manager: No dialogue lines found")
		return
	
	# Play dialogue sequence
	await _play_dialogue_sequence(dialogue_lines)

func _play_dialogue_sequence(dialogue_lines: Array) -> void:
	"""Play through all dialogue lines with actions"""
	for i in range(dialogue_lines.size()):
		var line = dialogue_lines[i]
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		var action = line.get("action", "")
		var emotion = line.get("emotion", "")
		
		print("🎬 Courtroom: [", speaker, "] ", text)
		
		# Handle action before showing dialogue
		if action != "":
			await _handle_action(action, speaker, text)
		
		# Show dialogue (use show_line function if action is show_line, otherwise normal)
		if action == "show_line":
			# show_line action means dialogue is handled by animation
			pass
		elif DialogueUI:
			DialogueUI.show_dialogue_line(speaker, text)
			await DialogueUI.next_pressed
		
		# Handle special cases
		if action == "start_evidence_presentation":
			await _handle_evidence_presentation()
			# After evidence presentation, continue dialogue
			continue
		
		# Check for cross-examination opportunities
		if action == "enable_evidence" or action == "show_evidence_inventory":
			# Check if we should show cross-examination choice
			await _check_cross_examination_opportunity()
	
	# Hide dialogue UI at the end
	if DialogueUI:
		DialogueUI.hide_ui()
	
	print("🎬 Courtroom Manager: Dialogue sequence completed")

func _check_cross_examination_opportunity() -> void:
	"""Check if player wants to cross-examine with evidence"""
	if not evidence_presentation_active:
		return
	
	var collected_evidence = EvidenceInventorySettings.collected_evidence if EvidenceInventorySettings else []
	if collected_evidence.is_empty():
		return
	
	# Show choice to cross-examine
	if dialog_chooser:
		var choices = ["Ipakita ang ebidensya", "Magpatuloy sa dialogue"]
		dialog_chooser.show_choices(choices)
		waiting_for_choice = true
		choice_result = -1
		
		# Wait for choice
		while waiting_for_choice:
			await get_tree().process_frame
		
		if choice_result == 0:
			# Player chose to present evidence
			await _handle_evidence_presentation()

func _on_choice_selected(choice_index: int) -> void:
	"""Handle choice selection from DialogChooser"""
	choice_result = choice_index
	waiting_for_choice = false
	print("🎬 Courtroom: Choice selected: ", choice_index)

func _handle_action(action: String, speaker: String, text: String) -> void:
	"""Handle special actions from dialogue"""
	match action:
		"camera_focus_judge":
			_camera_focus("judge")
		
		"camera_focus_defendant":
			_camera_focus("defendant")
		
		"camera_focus_prosecutor":
			_camera_focus("prosecutor")
		
		"camera_focus_celine":
			_camera_focus("celine")
		
		"camera_focus_po1_cordero":
			_camera_focus("po1_cordero")
		
		"camera_focus_dr_leticia":
			_camera_focus("dr_leticia")
		
		"camera_focus_kapitana":
			_camera_focus("kapitana")
		
		"camera_return":
			_camera_focus("center")
		
		"play_evidence_bgm":
			if AudioManager:
				print("🎵 Courtroom: Playing evidence BGM")
		
		"play_objection_bgm":
			_show_objection()
		
		"objection_shake":
			_show_objection()
			_play_objection_shake()
		
		"show_evidence_inventory":
			if EvidenceInventorySettings:
				EvidenceInventorySettings.show_evidence_inventory()
		
		"enable_evidence":
			evidence_presentation_active = true
		
		"start_evidence_presentation":
			pass  # Handled separately
		
		"show_gavel":
			_show_gavel()
		
		"play_gavel":
			_show_gavel()
		
		"show_line":
			# Show dialogue line immediately (for animation callbacks)
			if DialogueUI:
				DialogueUI.show_dialogue_line(speaker, text)

func _camera_focus(target: String) -> void:
	"""Move camera to focus on a character"""
	if not camera:
		print("⚠️ Courtroom Manager: No camera found for focus")
		return
	
	var target_pos = camera_positions.get(target, camera_positions["center"])
	var target_zoom = camera_zoom_levels.get(target, camera_zoom_levels["center"])
	
	# Use AnimationPlayer if available
	if anim_player and anim_player.has_animation("camera_focus_" + target):
		anim_player.play("camera_focus_" + target)
		print("🎬 Courtroom: Camera focusing on ", target, " via animation")
	else:
		# Manual camera movement with tween (includes zoom)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(camera, "global_position", target_pos, 0.8)
		tween.tween_property(camera, "zoom", target_zoom, 0.8)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		print("🎬 Courtroom: Camera focusing on ", target, " via tween (with zoom)")

func _show_gavel() -> void:
	"""Show gavel sprite with tween animation"""
	if not gavel_sprite:
		print("⚠️ Courtroom: Gavel sprite not found")
		return
	
	# Reset to original position
	gavel_sprite.position = gavel_original_pos
	gavel_sprite.visible = true
	gavel_sprite.modulate.a = 0.0
	
	# Fade in and scale up
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(gavel_sprite, "modulate:a", 1.0, 0.3)
	tween.tween_property(gavel_sprite, "scale", Vector2(1.2, 1.2), 0.2)
	await tween.finished
	
	# Scale back to normal
	var tween2 = create_tween()
	tween2.tween_property(gavel_sprite, "scale", Vector2(1.0, 1.0), 0.1)
	await tween2.finished
	
	# Wait a moment
	await get_tree().create_timer(0.5).timeout
	
	# Fade out
	var tween3 = create_tween()
	tween3.tween_property(gavel_sprite, "modulate:a", 0.0, 0.3)
	await tween3.finished
	
	gavel_sprite.visible = false
	gavel_sprite.position = gavel_original_pos

func _show_objection() -> void:
	"""Show objection sprite with tween animation"""
	if not objection_sprite:
		print("⚠️ Courtroom: Objection sprite not found")
		return
	
	# Reset to original position
	objection_sprite.position = objection_original_pos
	objection_sprite.visible = true
	objection_sprite.modulate.a = 0.0
	
	# Fade in and scale up
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(objection_sprite, "modulate:a", 1.0, 0.2)
	tween.tween_property(objection_sprite, "scale", Vector2(1.3, 1.3), 0.15)
	await tween.finished
	
	# Scale back to normal
	var tween2 = create_tween()
	tween2.tween_property(objection_sprite, "scale", Vector2(1.0, 1.0), 0.1)
	await tween2.finished
	
	# Wait a moment
	await get_tree().create_timer(0.8).timeout
	
	# Fade out
	var tween3 = create_tween()
	tween3.tween_property(objection_sprite, "modulate:a", 0.0, 0.3)
	await tween3.finished
	
	objection_sprite.visible = false
	objection_sprite.position = objection_original_pos

func _play_objection_effect() -> void:
	"""Play objection sound and visual effect"""
	print("⚖️ Courtroom: OBJECTION!")
	_show_objection()
	
	# Play objection animation if available
	if anim_player and anim_player.has_animation("objection"):
		anim_player.play("objection")
	
	# Play objection sound
	if AudioManager:
		pass  # Add objection sound here

func _play_objection_shake() -> void:
	"""Shake screen for objection"""
	if camera:
		var original_pos = camera.global_position
		var shake_amount = 10.0
		var shake_duration = 0.3
		
		# Shake effect
		for i in range(5):
			var offset = Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount)
			)
			camera.global_position = original_pos + offset
			await get_tree().create_timer(shake_duration / 5.0).timeout
		
		camera.global_position = original_pos

func _handle_evidence_presentation() -> void:
	"""Handle evidence presentation phase with choice system"""
	print("📋 Courtroom: Starting evidence presentation")
	
	# Show evidence inventory
	if EvidenceInventorySettings:
		EvidenceInventorySettings.show_evidence_inventory()
	
	# Wait for player to select evidence via inventory
	# Connect to evidence selection signal
	var evidence_selected = false
	var selected_evidence_id = ""
	
	# Wait for evidence selection (you can connect to EvidenceInventorySettings signals)
	# For now, use a simple timeout and get first evidence
	await get_tree().create_timer(1.0).timeout
	
	# Get collected evidence
	var collected_evidence = EvidenceInventorySettings.collected_evidence if EvidenceInventorySettings else []
	
	if collected_evidence.is_empty():
		print("⚠️ Courtroom: No evidence collected")
		if EvidenceInventorySettings:
			EvidenceInventorySettings.hide_evidence_inventory()
		return
	
	# Show choice for which evidence to present
	if dialog_chooser and collected_evidence.size() > 1:
		var choice_texts: Array[String] = []
		for evidence_id in collected_evidence:
			var evidence_name = _get_evidence_name(evidence_id)
			choice_texts.append("Ipakita ang " + evidence_name)
		choice_texts.append("Kanselahin")
		
		dialog_chooser.show_choices(choice_texts.slice(0, 2))  # Show first 2 choices
		waiting_for_choice = true
		choice_result = -1
		
		while waiting_for_choice:
			await get_tree().process_frame
		
		if choice_result >= 0 and choice_result < collected_evidence.size():
			selected_evidence_id = collected_evidence[choice_result]
		else:
			# Canceled
			if EvidenceInventorySettings:
				EvidenceInventorySettings.hide_evidence_inventory()
			return
	else:
		# Only one evidence or no chooser, use first
		selected_evidence_id = collected_evidence[0]
	
	selected_evidence = selected_evidence_id
	print("📋 Courtroom: Evidence selected: ", selected_evidence)
	
	# Hide evidence inventory
	if EvidenceInventorySettings:
		EvidenceInventorySettings.hide_evidence_inventory()
	
	# Play evidence-specific animation
	_play_evidence_animation(selected_evidence)
	
	# Show evidence presentation dialogue
	await _present_evidence(selected_evidence)

func _play_evidence_animation(evidence_id: String) -> void:
	"""Play evidence animation - can be called from AnimationPlayer"""
	_play_evidence_animation_internal(evidence_id)

func _play_evidence_animation_internal(evidence_id: String) -> void:
	"""Play animation for specific evidence cross-examination using EvidenceInventorySettings"""
	if not evidence_display_sprite:
		print("⚠️ Courtroom: Evidence display sprite not found")
		return
	
	# Get evidence texture from EvidenceInventorySettings
	if not EvidenceInventorySettings:
		print("⚠️ Courtroom: EvidenceInventorySettings not found")
		return
	
	var evidence_texture = EvidenceInventorySettings.evidence_textures.get(evidence_id)
	if not evidence_texture:
		print("⚠️ Courtroom: Texture not found for evidence: ", evidence_id)
		return
	
	# Set the texture
	if evidence_display_sprite is Sprite2D:
		evidence_display_sprite.texture = evidence_texture
	elif evidence_display_sprite.has_method("set_texture"):
		evidence_display_sprite.set_texture(evidence_texture)
	
	# Show and animate the evidence sprite
	evidence_display_sprite.visible = true
	evidence_display_sprite.position = Vector2(640, 360)  # Center of screen
	evidence_display_sprite.modulate.a = 0.0
	evidence_display_sprite.scale = Vector2(0.5, 0.5)
	
	# Fade in and scale up
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(evidence_display_sprite, "modulate:a", 1.0, 0.5)
	tween.tween_property(evidence_display_sprite, "scale", Vector2(1.0, 1.0), 0.5)
	await tween.finished
	
	# Play animation if available
	if evidence_display_anim_player and evidence_display_anim_player.has_animation("cross_examine"):
		evidence_display_anim_player.play("cross_examine")
		await evidence_display_anim_player.animation_finished
	else:
		# Wait a moment if no animation
		await get_tree().create_timer(2.0).timeout
	
	# Fade out
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(evidence_display_sprite, "modulate:a", 0.0, 0.5)
	tween2.tween_property(evidence_display_sprite, "scale", Vector2(0.5, 0.5), 0.5)
	await tween2.finished
	
	evidence_display_sprite.visible = false
	print("🎬 Courtroom: Cross-examination animation completed for ", evidence_id)

func _hide_evidence_display() -> void:
	"""Hide evidence display - can be called from AnimationPlayer"""
	if evidence_display_sprite:
		evidence_display_sprite.visible = false
		evidence_display_sprite.modulate.a = 0.0
		print("🎬 Courtroom: Evidence display hidden")

func _present_evidence(evidence_id: String) -> void:
	"""Present the selected evidence"""
	var evidence_name = _get_evidence_name(evidence_id)
	
	if DialogueUI:
		DialogueUI.show_dialogue_line("Miguel", "Your Honor, gusto kong ipresenta ang " + evidence_name + "!")
		await DialogueUI.next_pressed
		
		# Show choice for how to present evidence
		if dialog_chooser:
			var choices = [
				"Gamitin ito para sa cross-examination",
				"Ipresenta bilang ebidensya"
			]
			dialog_chooser.show_choices(choices)
			waiting_for_choice = true
			choice_result = -1
			
			while waiting_for_choice:
				await get_tree().process_frame
			
			if choice_result == 0:
				# Cross-examination
				await _cross_examine_with_evidence(evidence_id)
			else:
				# Regular presentation
				await _regular_evidence_presentation(evidence_id)
		else:
			# No chooser, do regular presentation
			await _regular_evidence_presentation(evidence_id)

func _cross_examine_with_evidence(evidence_id: String) -> void:
	"""Cross-examine witness with evidence"""
	var evidence_name = _get_evidence_name(evidence_id)
	
	if DialogueUI:
		DialogueUI.show_dialogue_line("Miguel", "Your Honor, gusto kong gamitin ang " + evidence_name + " para sa cross-examination!")
		await DialogueUI.next_pressed
		
		# Play evidence animation
		_play_evidence_animation(evidence_id)
		
		# Show gavel
		_show_gavel()
		
		DialogueUI.show_dialogue_line("Hukom", "Sustained. Maaari mong gamitin ang ebidensya para sa cross-examination.")
		await DialogueUI.next_pressed

func _regular_evidence_presentation(evidence_id: String) -> void:
	"""Regular evidence presentation"""
	var evidence_name = _get_evidence_name(evidence_id)
	
	# Check if evidence is correct for current phase
	var is_correct = _check_evidence_correctness(evidence_id, current_phase)
	
	if is_correct:
		if DialogueUI:
			DialogueUI.show_dialogue_line("Hukom", "Sustained. Ang ebidensya ay maaaring tanggapin. Magpatuloy, Abogado.")
			await DialogueUI.next_pressed
			_show_gavel()
	else:
		if DialogueUI:
			DialogueUI.show_dialogue_line("Fiscal", "Objection! Ang ebidensyang ito ay hindi maaaring tanggapin!")
			await DialogueUI.next_pressed
			_play_objection_effect()
			await _play_objection_shake()
			DialogueUI.show_dialogue_line("Hukom", "Sustained. Ang objection ay tinanggap. Magpatuloy sa ibang ebidensya.")
			await DialogueUI.next_pressed
			_show_gavel()

func show_line(speaker: String, text: String) -> void:
	"""Show dialogue line - can be called from AnimationPlayer"""
	if DialogueUI:
		DialogueUI.show_dialogue_line(speaker, text)
		print("🎬 Courtroom: show_line called - ", speaker, ": ", text)

func advance_dialogue_lines(line_count: int) -> void:
	"""Auto-advance dialogue lines (Phoenix Wright style)
	
	Args:
		line_count: Number of dialogue lines to advance automatically
		
	This function pauses the AnimationPlayer, plays dialogue lines with auto-advance,
	then resumes the AnimationPlayer. Use this in AnimationPlayer method tracks.
	
	Timing:
	- Normal typing speed (default DialogueUI speed)
	- Waits 0.5 seconds after each line finishes
	- Then auto-advances to next line
	"""
	if not anim_player:
		print("⚠️ Courtroom: No AnimationPlayer found for advance_dialogue_lines")
		return
	
	# Pause the AnimationPlayer
	anim_player.pause()
	print("🎬 Courtroom: AnimationPlayer paused for ", line_count, " dialogue lines")
	
	# Get current dialogue index
	var dialogue_lines = dialogue_data.get("dialogue_lines", [])
	if dialogue_lines.is_empty():
		print("⚠️ Courtroom: No dialogue lines found")
		anim_player.play()  # Resume
		return
	
	# Advance through the specified number of lines
	for i in range(line_count):
		if current_dialogue_index >= dialogue_lines.size():
			print("⚠️ Courtroom: Reached end of dialogue")
			break
		
		var line = dialogue_lines[current_dialogue_index]
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		var action = line.get("action", "")
		
		print("🎬 Courtroom: Auto-advancing line ", current_dialogue_index + 1, " - [", speaker, "] ", text)
		
		# Handle action before showing dialogue
		if action != "":
			await _handle_action(action, speaker, text)
		
		# Show dialogue with auto-advance
		if DialogueUI:
			DialogueUI.show_dialogue_line(speaker, text, true)  # auto_advance = true
			# Wait for typing to finish
			while DialogueUI.is_typing:
				await get_tree().process_frame
			# Wait additional pause after text finishes (Phoenix Wright style)
			await get_tree().create_timer(0.5).timeout
			# Auto-advance: emit next_pressed signal
			DialogueUI.emit_signal("next_pressed")
		
		current_dialogue_index += 1
	
	# Resume AnimationPlayer
	anim_player.play()
	print("🎬 Courtroom: AnimationPlayer resumed after ", line_count, " lines")

# Example dialogue entries you can add to courtroom_dialogue.json:
# Add these after the existing dialogue_lines array:
#
# {
#   "speaker": "Celine",
#   "text": "Your Honor... may gusto akong sabihin. May kasalanan ako.",
#   "action": "camera_focus_celine",
#   "emotion": "guilty"
# },
# {
#   "speaker": "Celine",
#   "text": "Ako ang nagtago ng ebidensya. Pero hindi ako ang pumatay kay Leo.",
#   "action": "camera_focus_celine",
#   "emotion": "confessed"
# },
# {
#   "speaker": "Miguel",
#   "text": "Sino ang nag-utos sa iyo, Celine?",
#   "action": "camera_focus_celine",
#   "emotion": "questioning"
# },
# {
#   "speaker": "Celine",
#   "text": "Si... si Kapitana. Siya ang nag-utos sa akin na itago ang ebidensya.",
#   "action": "camera_focus_kapitana",
#   "emotion": "afraid"
# },
# {
#   "speaker": "Kapitana",
#   "text": "Huwag kang magsinungaling, Celine! Wala akong kinalaman diyan!",
#   "action": "camera_focus_kapitana",
#   "emotion": "angry"
# },
# {
#   "speaker": "Miguel",
#   "text": "Your Honor, ipakita ko ang notebook ni Leo. Nandito ang lahat ng ebidensya laban kay Kapitana.",
#   "action": "camera_focus_judge",
#   "emotion": "determined"
# },
# {
#   "speaker": "Kapitana",
#   "text": "Hindi! Hindi totoo iyan!",
#   "action": "play_objection_bgm",
#   "emotion": "panicked"
# },
# {
#   "speaker": "Hukom",
#   "text": "Kapitana, tumahimik ka. Magpatuloy, Abogado.",
#   "action": "show_gavel",
#   "emotion": "authoritative"
# }

func _get_evidence_name(evidence_id: String) -> String:
	"""Get display name for evidence"""
	var evidence_names = {
		"broken_body_cam": "sirang body camera",
		"logbook": "police logbook",
		"handwriting_sample": "handwriting sample",
		"radio_log": "radio communication log",
		"autopsy_report": "autopsy report",
		"leos_notebook": "notebook ni Leo"
	}
	return evidence_names.get(evidence_id, evidence_id)

func _check_evidence_correctness(evidence_id: String, phase: String) -> bool:
	"""Check if evidence is correct for the current phase"""
	var correctness_data = dialogue_data.get("evidence_correctness", {})
	var phase_data = correctness_data.get(phase, {})
	var correct_evidence = phase_data.get("correct", [])
	return evidence_id in correct_evidence

func _disable_player_movement() -> void:
	"""Disable player movement during courtroom"""
	var player = get_tree().current_scene.get_node_or_null("PlayerM")
	if player:
		if player.has_method("disable_movement"):
			player.disable_movement()
		elif "control_enabled" in player:
			player.control_enabled = false
		print("🎬 Courtroom: Player movement disabled")

func _enable_player_movement() -> void:
	"""Enable player movement after courtroom"""
	var player = get_tree().current_scene.get_node_or_null("PlayerM")
	if player:
		if player.has_method("enable_movement"):
			player.enable_movement()
		elif "control_enabled" in player:
			player.control_enabled = true
		print("🎬 Courtroom: Player movement enabled")

func _find_camera() -> void:
	"""Find the dedicated courtroom camera in the scene"""
	# First, try to find a dedicated courtroom camera (preferred)
	camera = get_tree().current_scene.get_node_or_null("CourtroomCamera")
	if not camera:
		camera = get_tree().current_scene.get_node_or_null("Camera2D")
	
	if camera:
		print("🎬 Courtroom: Dedicated camera found at ", camera.global_position)
	else:
		print("⚠️ Courtroom: No dedicated camera found - camera movements will be skipped")
		print("💡 Tip: Add a Camera2D node named 'CourtroomCamera' or 'Camera2D' to the courtroom scene root")

func _setup_camera() -> void:
	"""Setup camera: disable player camera and enable courtroom camera"""
	# Find player and their camera
	var player = get_tree().current_scene.get_node_or_null("PlayerM")
	if player:
		player_camera = player.get_node_or_null("Camera2D")
		
		if player_camera:
			# Disable player camera
			player_camera.enabled = false
			print("🎬 Courtroom: Player camera disabled")
		else:
			print("⚠️ Courtroom: Player camera not found")
	else:
		print("⚠️ Courtroom: PlayerM not found")
	
	# Enable courtroom camera if found
	if camera:
		camera.enabled = true
		camera.current = true
		print("🎬 Courtroom: Courtroom camera enabled and set as current")
	else:
		print("⚠️ Courtroom: No courtroom camera to enable")

# NOTE: Create AnimationPlayer tracks manually in the editor
# See COURTROOM_ANIMATION_INSTRUCTIONS.md for details
