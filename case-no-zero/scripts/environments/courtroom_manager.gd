extends Node

# Courtroom Manager - Evidence Branch System with DialogChooser

var camera: Camera2D = null
var player_camera: Camera2D = null

# Gavel and Objection sprites
var gavel_sprite: Node2D = null
var objection_sprite: Node2D = null

# Evidence display
var evidence_display_sprite: Sprite2D = null

# SFX players for objection and gavel
var objection_sfx_player: AudioStreamPlayer = null
var gavel_sfx_player: AudioStreamPlayer = null

# DialogChooser
var dialog_chooser = null

var dialogue_data: Dictionary = {}
var current_dialogue_index: int = 0
var waiting_for_choice: bool = false
var choice_result: int = -1
var waiting_for_evidence_selection: bool = false
var selected_evidence_id: String = ""
var waiting_for_dialogue_next: bool = false

# Evidence branch system
var current_phase: String = "opening_statements_phase"
var evidence_presented: Array[String] = []
var can_present_evidence: bool = false

# Contradiction system
var can_contradict: bool = false
var current_contradictable_line: Dictionary = {}
var waiting_for_contradiction: bool = false
var contradiction_evidence_id: String = ""

# Lifebar system (4 lives)
var max_lives: int = 4
var current_lives: int = 4
var lifebar_ui: Control = null

# Character positions for camera (exact positions from user)
var camera_positions: Dictionary = {
	"judge": Vector2(688.0, 152.0),
	"center": Vector2(688.0, 312.0),
	"player": Vector2(520.0, 440.0),
	"fiscal": Vector2(896.0, 440.0),
	"erwin": Vector2(480.0, 440.0),
	"celine": Vector2(448.0, 440.0),
	"po1_cordero": Vector2(780.0, 450.0),
	"dr_leticia": Vector2(640.0, 400.0),
	"kapitana": Vector2(400.0, 500.0)
}

# Camera zoom levels (based on dialogue action)
var camera_zoom_levels: Dictionary = {
	"judge": Vector2(2.0, 2.0),
	"center": Vector2(1.3, 1.3),  # Center zoom is 1.3 - only used when presenting evidence
	"player": Vector2(2.5, 2.5),
	"fiscal": Vector2(2.0, 2.0),
	"erwin": Vector2(2.5, 2.5),
	"celine": Vector2(2.5, 2.5),
	"po1_cordero": Vector2(2.5, 2.5),
	"dr_leticia": Vector2(2.5, 2.5),
	"kapitana": Vector2(2.5, 2.5)
}

func _ready() -> void:
	print("🎬 Courtroom Manager: Initializing...")
	
	_load_dialogue_data()
	_find_camera()
	_setup_camera()
	_find_dialog_chooser()
	_find_evidence_display()
	_setup_gavel_objection()
	_setup_sfx_players()
	_setup_evidence_listener()
	_setup_courtroom_audio()
	_setup_dialogue_listener()
	_setup_lifebar()
	_disable_player_movement()
	
	await get_tree().create_timer(0.5).timeout
	_start_courtroom_sequence()

func _setup_courtroom_audio() -> void:
	"""Setup courtroom audio - play main courtroom BGM"""
	if AudioManager:
		# Play courtroom intro/main BGM
		AudioManager.play_bgm("courtroom_intro")
		print("🎵 Courtroom: Courtroom BGM started")
	else:
		print("⚠️ Courtroom: AudioManager not found")

func _setup_evidence_listener() -> void:
	"""Setup listener for evidence selection from evidence inventory"""
	if EvidenceInventorySettings:
		if not EvidenceInventorySettings.evidence_selected_for_courtroom.is_connected(_on_evidence_selected_for_courtroom):
			EvidenceInventorySettings.evidence_selected_for_courtroom.connect(_on_evidence_selected_for_courtroom)
		print("🎬 Courtroom: Evidence listener connected")
	else:
		print("⚠️ Courtroom: EvidenceInventorySettings not found")

func _setup_dialogue_listener() -> void:
	"""Setup listener for dialogue next_pressed signal"""
	if DialogueUI:
		if not DialogueUI.next_pressed.is_connected(_on_dialogue_next_pressed):
			DialogueUI.next_pressed.connect(_on_dialogue_next_pressed)
		print("🎬 Courtroom: Dialogue listener connected")
	else:
		print("⚠️ Courtroom: DialogueUI not found")

func _setup_lifebar() -> void:
	"""Setup lifebar UI with 4 lives - modern design"""
	# Create CanvasLayer for lifebar
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "LifebarLayer"
	canvas_layer.layer = 10  # Above game but below dialogue
	get_tree().current_scene.add_child(canvas_layer)
	
	# Create main container with background
	var main_container = Panel.new()
	main_container.name = "LifebarPanel"
	main_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main_container.offset_left = 20.0
	main_container.offset_top = 20.0
	main_container.offset_right = 280.0  # Made wider (was 200, now 280)
	main_container.offset_bottom = 80.0
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)  # Semi-transparent black
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	main_container.add_theme_stylebox_override("panel", style)
	canvas_layer.add_child(main_container)
	
	# Create inner container
	var container = HBoxContainer.new()
	container.name = "LifebarContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.offset_left = 10.0
	container.offset_top = 10.0
	container.offset_right = -10.0
	container.offset_bottom = -10.0
	container.add_theme_constant_override("separation", 10)
	main_container.add_child(container)
	lifebar_ui = container
	
	# Create label
	var label = Label.new()
	label.name = "LifebarLabel"
	label.text = "BUHAY:"
	var label_settings = LabelSettings.new()
	var font = load("res://assets/fonts/PixelOperator-Bold.ttf")
	if font:
		label_settings.font = font
	label_settings.font_size = 20
	label_settings.font_color = Color.WHITE
	label.label_settings = label_settings
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)
	
	# Create life icons container
	var lives_container = HBoxContainer.new()
	lives_container.name = "LivesContainer"
	lives_container.add_theme_constant_override("separation", 8)
	lives_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(lives_container)
	
	# Create 3 life icons (heart symbols)
	for i in range(max_lives):
		var life_icon = Label.new()
		life_icon.name = "Life" + str(i + 1)
		life_icon.text = "❤"
		var icon_settings = LabelSettings.new()
		if font:
			icon_settings.font = font
		icon_settings.font_size = 24
		icon_settings.font_color = Color.RED
		life_icon.label_settings = icon_settings
		life_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		life_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lives_container.add_child(life_icon)
	
	_update_lifebar_display()
	print("❤️ Courtroom: Lifebar initialized with ", max_lives, " lives")

func _update_lifebar_display() -> void:
	"""Update lifebar UI to show current lives"""
	if not lifebar_ui:
		return
	
	var lives_container = lifebar_ui.get_node_or_null("LivesContainer")
	if not lives_container:
		return
	
	for i in range(max_lives):
		var life_icon = lives_container.get_node_or_null("Life" + str(i + 1))
		if life_icon and life_icon is Label:
			if i < current_lives:
				life_icon.modulate = Color.WHITE  # Full color
				life_icon.label_settings.font_color = Color.RED
			else:
				life_icon.modulate = Color(0.3, 0.3, 0.3, 0.5)  # Dimmed/hidden
				life_icon.label_settings.font_color = Color(0.3, 0.0, 0.0, 0.5)
	
	print("❤️ Courtroom: Lifebar updated - ", current_lives, "/", max_lives, " lives remaining")

func lose_life() -> void:
	"""Lose one life - called when wrong evidence is presented or wrong contradiction"""
	if current_lives > 0:
		current_lives -= 1
		_update_lifebar_display()
		print("❤️ Courtroom: Life lost! Remaining: ", current_lives, "/", max_lives)
		
		if current_lives <= 0:
			_game_over()
	else:
		_game_over()

func _game_over() -> void:
	"""Handle game over when all lives are lost - restart courtroom sequence"""
	print("💀 Courtroom: Game Over - All lives lost! Restarting courtroom sequence...")
	
	# Hide dialogue UI
	if DialogueUI:
		DialogueUI.hide_ui()
	
	# Hide evidence inventory if visible
	if EvidenceInventorySettings:
		EvidenceInventorySettings.hide_evidence_inventory()
	
	# Reset all state variables
	current_lives = max_lives
	current_dialogue_index = 0
	evidence_presented.clear()
	can_present_evidence = false
	waiting_for_evidence_selection = false
	waiting_for_contradiction = false
	waiting_for_choice = false
	waiting_for_dialogue_next = false
	selected_evidence_id = ""
	choice_result = -1
	can_contradict = false
	
	# Reset lifebar display
	_update_lifebar_display()
	
	# Reset camera to center
	if camera:
		camera.global_position = camera_positions["center"]
		camera.zoom = camera_zoom_levels["center"]
	
	# Small delay before restarting
	await get_tree().create_timer(1.0).timeout
	
	# Restart the courtroom sequence
	print("🎬 Courtroom: Restarting sequence from the beginning...")
	_start_courtroom_sequence()

func _on_dialogue_next_pressed() -> void:
	"""Handle dialogue next_pressed signal"""
	print("🎬 Courtroom: Dialogue next_pressed signal received, setting waiting_for_dialogue_next = false")
	waiting_for_dialogue_next = false
	print("🎬 Courtroom: waiting_for_dialogue_next is now: ", waiting_for_dialogue_next)

func _wait_for_dialogue_next() -> void:
	"""Helper function to wait for dialogue next button press using flag-based approach"""
	waiting_for_dialogue_next = true
	# Wait for typing to finish
	while DialogueUI.is_typing:
		await get_tree().process_frame
	# Wait for next button to appear (waiting_for_next becomes true after typing)
	while not DialogueUI.waiting_for_next:
		await get_tree().process_frame
		# Also check if signal was already received (button pressed very quickly)
		if not waiting_for_dialogue_next:
			print("🎬 Courtroom: Signal received during wait, breaking early")
			return
	# Wait for next button to be pressed (waiting_for_dialogue_next becomes false)
	while waiting_for_dialogue_next:
		await get_tree().process_frame
	print("🎬 Courtroom: Dialogue next wait completed")

func _on_evidence_selected_for_courtroom(evidence_id: String) -> void:
	"""Handle evidence selection from evidence inventory"""
	print("🎬 Courtroom: Evidence selection signal received: ", evidence_id, " | waiting_for_evidence_selection: ", waiting_for_evidence_selection, " | waiting_for_contradiction: ", waiting_for_contradiction)
	# Always set the selected evidence ID (even if not currently waiting)
	selected_evidence_id = evidence_id
	# Clear waiting flags if they are set
	if waiting_for_evidence_selection:
		waiting_for_evidence_selection = false
		print("🎬 Courtroom: Evidence selected for presentation: ", evidence_id, " (waiting flag cleared)")
	if waiting_for_contradiction:
		waiting_for_contradiction = false
		print("🎬 Courtroom: Evidence selected for contradiction: ", evidence_id, " (waiting flag cleared)")

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

func _find_camera() -> void:
	"""Find the dedicated courtroom camera"""
	camera = get_tree().current_scene.get_node_or_null("CourtroomCamera")
	if not camera:
		camera = get_tree().current_scene.get_node_or_null("Camera2D")
	
	if camera:
		print("🎬 Courtroom: Camera found at ", camera.global_position)
	else:
		print("⚠️ Courtroom: No camera found")

func _setup_camera() -> void:
	"""Setup camera: disable player camera and enable courtroom camera"""
	var player = get_tree().current_scene.get_node_or_null("PlayerM")
	if player:
		player_camera = player.get_node_or_null("Camera2D")
		if player_camera:
			player_camera.enabled = false
			print("🎬 Courtroom: Player camera disabled")
	
	if camera:
		camera.enabled = true
		camera.make_current()
		camera.global_position = camera_positions["center"]
		camera.zoom = Vector2(1.3, 1.3)  # Center zoom is 1.3
		print("🎬 Courtroom: Courtroom camera enabled")

func _find_dialog_chooser() -> void:
	"""Find DialogChooser"""
	dialog_chooser = get_node_or_null("/root/DialogChooser")
	if not dialog_chooser:
		dialog_chooser = get_tree().current_scene.get_node_or_null("DialogChooser")
	if dialog_chooser:
		if dialog_chooser.has_signal("choice_selected"):
			dialog_chooser.choice_selected.connect(_on_choice_selected)
		print("🎬 Courtroom: DialogChooser found")
	else:
		print("⚠️ Courtroom: DialogChooser not found")

func _find_evidence_display() -> void:
	"""Find evidence display sprite"""
	evidence_display_sprite = get_tree().current_scene.get_node_or_null("EvidenceDisplaySprite")
	if evidence_display_sprite:
		print("🎬 Courtroom: Evidence display sprite found")
	else:
		print("⚠️ Courtroom: Evidence display sprite not found")

func _setup_gavel_objection() -> void:
	"""Setup gavel and objection sprites"""
	gavel_sprite = get_tree().current_scene.get_node_or_null("GavelSprite")
	objection_sprite = get_tree().current_scene.get_node_or_null("ObjectionSprite")
	
	if gavel_sprite:
		gavel_sprite.visible = false
		gavel_sprite.modulate.a = 0.0
		print("🎬 Courtroom: Gavel sprite found")
	
	if objection_sprite:
		objection_sprite.visible = false
		objection_sprite.modulate.a = 0.0
		print("🎬 Courtroom: Objection sprite found")

func _setup_sfx_players() -> void:
	"""Setup SFX players for objection and gavel sounds"""
	# Create objection SFX player
	objection_sfx_player = AudioStreamPlayer.new()
	objection_sfx_player.name = "ObjectionSFXPlayer"
	objection_sfx_player.bus = "SFX"
	objection_sfx_player.volume_db = 0.0
	add_child(objection_sfx_player)
	
	# Create gavel SFX player
	gavel_sfx_player = AudioStreamPlayer.new()
	gavel_sfx_player.name = "GavelSFXPlayer"
	gavel_sfx_player.bus = "SFX"
	gavel_sfx_player.volume_db = 0.0
	add_child(gavel_sfx_player)
	
	print("🔊 Courtroom: SFX players created")

func _disable_player_movement() -> void:
	"""Disable player movement during courtroom"""
	var player = get_tree().current_scene.get_node_or_null("PlayerM")
	if player:
		if "control_enabled" in player:
			player.control_enabled = false
		if "velocity" in player:
			player.velocity = Vector2.ZERO
		print("🎬 Courtroom: Player movement disabled")

func _start_courtroom_sequence() -> void:
	"""Start the courtroom dialogue sequence"""
	print("🎬 Courtroom Manager: Starting courtroom sequence")
	
	var dialogue_lines = dialogue_data.get("dialogue_lines", [])
	if dialogue_lines.is_empty():
		print("⚠️ Courtroom Manager: No dialogue lines found")
		return
	
	# Play intro dialogue until evidence presentation phase
	await _play_dialogue_sequence(dialogue_lines)
	
	print("🎬 Courtroom Manager: Courtroom sequence completed")
	
	# Show summary cutscene
	await _show_summary_cutscene()
	
	# Fade out and return to main menu
	await _fade_out_to_main_menu()

func _play_dialogue_sequence(dialogue_lines: Array) -> void:
	"""Play through dialogue lines with actions and evidence branches"""
	print("🎬 Courtroom: Starting dialogue sequence with ", dialogue_lines.size(), " lines")
	# Reset dialogue index to prevent looping
	current_dialogue_index = 0
	while current_dialogue_index < dialogue_lines.size():
		print("🎬 Courtroom: Processing line ", current_dialogue_index, " of ", dialogue_lines.size())
		var line = dialogue_lines[current_dialogue_index]
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		var action = line.get("action", "")
		var zoom = line.get("zoom", null)  # Get zoom from dialogue if present
		
		print("🎬 Courtroom: [", speaker, "] ", text)
		
		# Check if this is evidence presentation phase
		if action == "start_evidence_presentation":
			await _handle_evidence_presentation_phase()
			current_dialogue_index += 1
			continue
		
		# Zoom to speaker BEFORE showing dialogue (only if they're actually speaking)
		# Map speaker names to camera targets
		var speaker_target = _get_speaker_camera_target(speaker)
		# Only transition camera if not already on the speaker, or if it's not the judge
		# When judge talks, stay on judge (don't transition to center)
		if speaker_target != "":
			# If judge is speaking, always focus on judge (don't go to center)
			if speaker == "Hukom" or speaker == "Judge":
				await _camera_focus("judge", zoom)
			else:
				await _camera_focus(speaker_target, zoom)
		
		# Handle objection actions BEFORE showing dialogue (if text contains "Tutol")
		# This ensures objection animation shows before "Tutol po!" dialogue
		var objection_shown_before = false
		if action == "play_objection_bgm" or action == "objection_shake":
			if "Tutol" in text or "tutol" in text:
				# Show objection animation FIRST, then dialogue
				await _handle_action(action, zoom)
				objection_shown_before = true
		
		# Determine if dialogue should be shown (only once, avoid duplication)
		var has_choices = line.get("choices", null) != null and (line.get("choices", null) is Array and not (line.get("choices", null) as Array).is_empty())
		var is_contradictable = line.get("contradictable", false)
		var dialogue_shown = false
		
		# Show dialogue ONCE based on line type
		if DialogueUI and not dialogue_shown:
			# Check if this line has choices
			if has_choices:
				# Show dialogue first, then choices
				DialogueUI.show_dialogue_line(speaker, text, false)
				await _wait_for_dialogue_next()
				dialogue_shown = true
				
				# Show DialogChooser with choices
				if dialog_chooser:
					var choices = line.get("choices", [])
					var choice_descriptions: Array[String] = []
					for choice in choices:
						if choice is Dictionary:
							choice_descriptions.append(choice.get("text", ""))
						elif choice is String:
							choice_descriptions.append(choice)
					
					if choice_descriptions.size() > 0:
						dialog_chooser.show_choices(choice_descriptions)
						
						waiting_for_choice = true
						choice_result = -1
						while waiting_for_choice:
							await get_tree().process_frame
						
						# Handle choice result
						if choice_result >= 0 and choice_result < choices.size():
							var selected_choice = choices[choice_result]
							if selected_choice is Dictionary:
								var response_text = selected_choice.get("response", "")
								var response_speaker = selected_choice.get("speaker", "Miguel")
								
								if response_text != "":
									await _camera_focus("player")
									DialogueUI.show_dialogue_line(response_speaker, response_text, false)
									await _wait_for_dialogue_next()
			elif is_contradictable:
				# Show dialogue, then handle contradiction
				DialogueUI.show_dialogue_line(speaker, text, false)
				await _wait_for_dialogue_next()
				dialogue_shown = true
				
				# Handle contradiction logic
				current_contradictable_line = line
				await _handle_contradiction_phase(line)
			else:
				# Normal dialogue - show it
				DialogueUI.show_dialogue_line(speaker, text, false)
				await _wait_for_dialogue_next()
				dialogue_shown = true
		
		# Handle other actions AFTER dialogue (non-camera actions like gavel, etc.)
		# But skip objection actions if we already handled them above
		if action != "" and not action.begins_with("camera_"):
			if not (action == "play_objection_bgm" or action == "objection_shake") or not objection_shown_before:
				await _handle_action(action, zoom)
		
		# Increment dialogue index AFTER processing the line (prevent infinite loops)
		current_dialogue_index += 1
		print("🎬 Courtroom: Moved to dialogue index: ", current_dialogue_index, " of ", dialogue_lines.size())
		
		# Safety check to prevent infinite loops
		if current_dialogue_index >= dialogue_lines.size():
			print("🎬 Courtroom: Reached end of dialogue sequence")
			break
	
	if DialogueUI:
		DialogueUI.hide_ui()
	
	print("🎬 Courtroom Manager: Dialogue sequence completed")

func _get_speaker_camera_target(speaker: String) -> String:
	"""Map speaker name to camera target - only zoom when they're actually speaking"""
	match speaker:
		"Hukom":
			return "judge"
		"Miguel":
			return "player"
		"Fiscal":
			return "fiscal"
		"Erwin":
			return "erwin"
		"Celine":
			return "celine"
		"PO1 Cordero", "PO1":
			return "po1_cordero"
		"Dr. Leticia", "Leticia":
			return "dr_leticia"
		"Kapitana":
			return "kapitana"
		_:
			return ""  # Unknown speaker, don't zoom

func _handle_action(action: String, zoom: Variant = null) -> void:
	"""Handle non-camera actions (gavel, objection, music, etc.)"""
	match action:
		"show_gavel":
			# Ensure camera is on judge before showing gavel
			await _camera_focus("judge")
			await _show_gavel()
		"objection_shake":
			await _show_objection()
		"play_objection_bgm":
			if AudioManager:
				AudioManager.play_bgm("objection_bgm")
			await _show_objection()
		"play_evidence_bgm":
			if AudioManager:
				AudioManager.play_bgm("evidence_bgm")
		"enable_evidence", "show_evidence_inventory":
			can_present_evidence = true
		"camera_return":
			# Only return to center if explicitly requested
			_camera_focus("center", zoom)
		"dramatic_shake":
			_shake_camera(0.5, 15.0, 8) # Longer, stronger shake for dramatic effect
		"play_verdict_bgm":
			if AudioManager:
				AudioManager.play_bgm("verdict_bgm")
		"play_victory_bgm":
			if AudioManager:
				AudioManager.play_bgm("victory_bgm")

func _camera_focus(target: String, zoom: Variant = null) -> void:
	"""Move camera to focus on a character using Tween with fast, modern swipe transition"""
	if not camera:
		print("⚠️ Courtroom Manager: No camera found for focus")
		return
	
	var target_pos = camera_positions.get(target, camera_positions["center"])
	var target_zoom: Vector2
	
	# Use zoom from dialogue if provided, otherwise use default
	if zoom != null and zoom is Vector2:
		target_zoom = zoom
	elif zoom != null and zoom is Array and zoom.size() >= 2:
		target_zoom = Vector2(float(zoom[0]), float(zoom[1]))
	else:
		target_zoom = camera_zoom_levels.get(target, camera_zoom_levels["center"])
	
	# Fast, modern swipe transition - using QUART for snappy feel
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera, "global_position", target_pos, 0.5)  # Fast 0.5s transition
	tween.tween_property(camera, "zoom", target_zoom, 0.5)  # Fast 0.5s zoom
	tween.set_ease(Tween.EASE_OUT)  # EASE_OUT for snappy, modern feel
	tween.set_trans(Tween.TRANS_QUART)  # QUART for smooth but fast transition
	
	await tween.finished
	print("🎬 Courtroom: Camera focused on ", target, " (zoom: ", target_zoom, ")")

func _handle_evidence_presentation_phase() -> void:
	"""Handle evidence presentation phase with branches - uses evidence inventory UI"""
	print("📋 Courtroom: Starting evidence presentation phase")
	
	can_present_evidence = true
	
	# Show evidence inventory in courtroom mode
	if EvidenceInventorySettings:
		print("📋 Courtroom: Showing evidence inventory in courtroom mode")
		EvidenceInventorySettings.show_evidence_inventory(true)  # Enable courtroom mode
		# Verify courtroom mode is set
		if not EvidenceInventorySettings.courtroom_mode:
			print("⚠️ Courtroom: Evidence inventory courtroom_mode not set! Setting manually...")
			EvidenceInventorySettings.courtroom_mode = true
		print("📋 Courtroom: Evidence inventory courtroom_mode verified: ", EvidenceInventorySettings.courtroom_mode)
		# Hide leos_notebook initially if not all other evidence is presented
		_update_final_evidence_visibility()
	
	# Loop until all evidence is presented or player cancels
	while can_present_evidence:
		var selected_evidence = await _get_evidence_selection()
		
		if selected_evidence == "":
			# Player canceled or all evidence presented
			print("📋 Courtroom: Evidence selection canceled or completed")
			break
		
		# Present evidence with branch (with error handling)
		print("📋 Courtroom: Starting evidence presentation for: ", selected_evidence)
		await _present_evidence_branch(selected_evidence)
		print("📋 Courtroom: Evidence presentation completed for: ", selected_evidence)
		
		# Update final evidence visibility after presenting evidence
		_update_final_evidence_visibility()
		
		# Check if this was the last evidence (leos_notebook)
		if selected_evidence == "leos_notebook":
			print("📋 Courtroom: Last evidence (leos_notebook) presented - ending evidence phase")
			break
		
		# Check if all evidence has been presented
		var all_presented = true
		if EvidenceInventorySettings:
			var collected = EvidenceInventorySettings.collected_evidence
			for evidence_id in collected:
				if evidence_id not in evidence_presented:
					all_presented = false
					break
		
		if all_presented:
			print("📋 Courtroom: All evidence has been presented - ending evidence phase")
			break
		
		# Ask if player wants to present another evidence (using DialogChooser for dialogue choice)
		# Only ask if there are still evidence available
		var still_has_evidence = false
		if EvidenceInventorySettings:
			var collected = EvidenceInventorySettings.collected_evidence
			for evidence_id in collected:
				if evidence_id not in evidence_presented:
					still_has_evidence = true
					break
		
		if still_has_evidence and dialog_chooser:
			var choices = ["Ipakita ang ibang ebidensya", "Tapos na"]
			dialog_chooser.show_choices(choices)
			
			waiting_for_choice = true
			choice_result = -1
			while waiting_for_choice:
				await get_tree().process_frame
			
			if choice_result == 1:  # "Tapos na"
				print("📋 Courtroom: Player chose to finish evidence presentation")
				can_present_evidence = false
				break
		else:
			# No more evidence available, break automatically
			print("📋 Courtroom: No more evidence available - ending evidence phase")
			break
	
	# Hide evidence inventory
	if EvidenceInventorySettings:
		EvidenceInventorySettings.hide_evidence_inventory()
	
	print("📋 Courtroom: Evidence presentation phase completed")

func _get_evidence_selection() -> String:
	"""Get evidence selection from evidence inventory clicks - filters out already presented evidence and final evidence"""
	if not EvidenceInventorySettings:
		print("⚠️ Courtroom: EvidenceInventorySettings not found")
		return ""
	
	# Get collected evidence
	var collected_evidence = EvidenceInventorySettings.collected_evidence
	
	if collected_evidence.is_empty():
		print("⚠️ Courtroom: No evidence collected")
		return ""
	
	# Filter out already presented evidence
	var available_evidence: Array[String] = []
	for evidence_id in collected_evidence:
		if evidence_id not in evidence_presented:
			# Check if this is the final evidence (leos_notebook)
			if evidence_id == "leos_notebook":
				# Only allow if all other evidence has been presented
				if _all_other_evidence_presented():
					available_evidence.append(evidence_id)
			else:
				available_evidence.append(evidence_id)
	
	# Check if all evidence has been presented
	if available_evidence.is_empty():
		print("📋 Courtroom: All evidence has been presented")
		return ""
	
	# Wait for evidence click from inventory
	waiting_for_evidence_selection = true
	selected_evidence_id = ""
	
	print("📋 Courtroom: Waiting for evidence selection... (waiting_for_evidence_selection = ", waiting_for_evidence_selection, ")")
	var wait_timeout = 0
	var max_wait_time = 300  # 5 seconds at 60fps
	while waiting_for_evidence_selection:
		await get_tree().process_frame
		wait_timeout += 1
		if wait_timeout > max_wait_time:
			print("⚠️ Courtroom: Evidence selection timeout! Continuing anyway...")
			waiting_for_evidence_selection = false
			break
		
		# Check if selected evidence is valid and not already presented
		if selected_evidence_id != "":
			print("📋 Courtroom: Evidence ID received: ", selected_evidence_id)
			if selected_evidence_id in available_evidence:
				return selected_evidence_id
			else:
				# Evidence already presented or not available yet, reset and wait again
				if selected_evidence_id == "leos_notebook" and not _all_other_evidence_presented():
					if DialogueUI:
						waiting_for_dialogue_next = true
						DialogueUI.show_dialogue_line("Miguel", "Mahal na Hukom, kailangan ko munang ipresenta ang lahat ng ibang ebidensya.")
						while DialogueUI.is_typing:
							await get_tree().process_frame
						while not DialogueUI.waiting_for_next:
							await get_tree().process_frame
						while waiting_for_dialogue_next:
							await get_tree().process_frame
				elif selected_evidence_id in evidence_presented:
					if DialogueUI:
						waiting_for_dialogue_next = true
						DialogueUI.show_dialogue_line("Miguel", "Mahal na Hukom, naipresenta ko na ang ebidensyang ito. Pumili ako ng iba.")
						while DialogueUI.is_typing:
							await get_tree().process_frame
						while not DialogueUI.waiting_for_next:
							await get_tree().process_frame
						while waiting_for_dialogue_next:
							await get_tree().process_frame
				selected_evidence_id = ""
				waiting_for_evidence_selection = true
	
	return ""

func _present_evidence_branch(evidence_id: String) -> void:
	"""Present evidence with fiscal objection and judge gavel branches"""
	print("📋 Courtroom: Presenting evidence branch for ", evidence_id)
	
	# Error handling: Check if evidence is already presented
	if evidence_id in evidence_presented:
		print("⚠️ Courtroom: Evidence ", evidence_id, " already presented! Skipping.")
		if DialogueUI:
			DialogueUI.show_dialogue_line("Miguel", "Mahal na Hukom, naipresenta ko na ang ebidensyang ito.")
			await _wait_for_dialogue_next()
		return
	
	# Error handling: Check if evidence exists in collected evidence
	if not EvidenceInventorySettings:
		print("⚠️ Courtroom: EvidenceInventorySettings not found!")
		return
	
	if evidence_id not in EvidenceInventorySettings.collected_evidence:
		print("⚠️ Courtroom: Evidence ", evidence_id, " not in collected evidence! Skipping.")
		if DialogueUI:
			DialogueUI.show_dialogue_line("Miguel", "Mahal na Hukom, wala akong ebidensyang ito.")
			await _wait_for_dialogue_next()
		return
	
	# Ensure evidence inventory stays visible and clickable during presentation
	if EvidenceInventorySettings:
		if not EvidenceInventorySettings.is_visible:
			EvidenceInventorySettings.show_evidence_inventory(true)
		# Ensure courtroom mode is still set
		EvidenceInventorySettings.courtroom_mode = true
	
	# Get evidence testimony data
	var evidence_testimony = _get_evidence_testimony(evidence_id)
	print("📋 Courtroom: Looking up testimony for evidence_id: ", evidence_id)
	if evidence_testimony.is_empty():
		print("⚠️ Courtroom: No testimony data found for ", evidence_id, " in dialogue JSON - using default")
		# Use default testimony if none found
		evidence_testimony = {
			"testimony": "Mahal na Hukom, ipinapresenta ko ang ebidensyang ito.",
			"objection": "Tutol po!",
			"counter_objection": "Tutol po! Mahal na Hukom!"
		}
	else:
		print("✅ Courtroom: Found testimony data for ", evidence_id, ": ", evidence_testimony.keys())
	
	# Move camera to center when presenting evidence
	await _camera_focus("center")
	
	# Player presents evidence (all dialogue first)
	if DialogueUI:
		var evidence_name = _get_evidence_display_name(evidence_id)
		DialogueUI.show_dialogue_line("Miguel", "Mahal na Hukom, gusto kong ipresenta ang " + evidence_name + "!")
		await _wait_for_dialogue_next()
		
		DialogueUI.show_dialogue_line("Miguel", evidence_testimony.get("testimony", ""))
		await _wait_for_dialogue_next()
		
		# Move camera to judge
		await _camera_focus("judge")
		
		# Show objection animation FIRST - before "Tutol po!" dialogue
		await _camera_focus("fiscal")
		await _show_objection()
		print("🎬 Courtroom: Objection animation shown FIRST, now fiscal will say 'Tutol po!'")
		
		# Fiscal objects - SAY "Tutol po!" AFTER objection animation
		await _camera_focus("fiscal")
		if DialogueUI:
			DialogueUI.show_dialogue_line("Fiscal", evidence_testimony.get("objection", "Tutol po!"))
			await _wait_for_dialogue_next()
		print("🎬 Courtroom: Fiscal said 'Tutol po!' - moving to fiscal follow-up")
		
		# Fiscal nagrereklamo (follow-up complaint/rebuttal) AFTER objection animation completes
		await _camera_focus("fiscal")
		print("🎬 Courtroom: Camera focused on fiscal for follow-up")
		if DialogueUI:
			var fiscal_complaint = evidence_testimony.get("objection_follow_up", "")
			if fiscal_complaint == "":
				# Default complaint if not specified
				fiscal_complaint = "Mahal na Hukom, ang ebidensyang ito ay walang kaugnayan sa kaso at hindi dapat tanggapin ng hukuman! Ang depensa ay nagpapakita ng kawalan ng paghahanda at hindi maaaring gamitin ang ebidensyang ito laban sa prosecution!"
			DialogueUI.show_dialogue_line("Fiscal", fiscal_complaint)
			await _wait_for_dialogue_next()
			print("🎬 Courtroom: Fiscal follow-up dialogue completed")
			
			# Additional fiscal argument (stretch out dialogue)
			var fiscal_additional = evidence_testimony.get("objection_additional", "")
			if fiscal_additional != "":
				DialogueUI.show_dialogue_line("Fiscal", fiscal_additional)
				await _wait_for_dialogue_next()
				print("🎬 Courtroom: Fiscal additional argument completed")
		
		# Player counters objection
		await _camera_focus("player")
		print("🎬 Courtroom: Camera focused on player for counter")
		if DialogueUI:
			DialogueUI.show_dialogue_line("Miguel", evidence_testimony.get("counter_objection", "Tutol po! Mahal na Hukom!"))
			await _wait_for_dialogue_next()
			print("🎬 Courtroom: Player counter dialogue completed")
			
			# Additional counter argument (stretch out dialogue)
			var counter_additional = evidence_testimony.get("counter_additional", "")
			if counter_additional != "":
				DialogueUI.show_dialogue_line("Miguel", counter_additional)
				await _wait_for_dialogue_next()
				print("🎬 Courtroom: Player additional counter completed")
		
		# Show objection animation again - must complete before gavel
		await _show_objection()
		print("🎬 Courtroom: Second objection animation completed, moving to gavel")
		
		# Show gavel animation - camera MUST be on judge BEFORE gavel
		await _camera_focus("judge")
		print("🎬 Courtroom: Camera focused on judge, showing gavel")
		await _show_gavel()
		print("🎬 Courtroom: Gavel animation completed, moving to judge ruling")
		
		# Judge makes ruling AFTER gavel completes (camera already on judge from gavel)
		await _camera_focus("judge")  # Ensure camera is still on judge
		if DialogueUI:
			var judge_ruling = evidence_testimony.get("judge_response", "Tinatanggap. Ang ebidensya ay maaaring tanggapin. Magpatuloy, Abogado.")
			DialogueUI.show_dialogue_line("Hukom", judge_ruling)
			await _wait_for_dialogue_next()
			print("🎬 Courtroom: Judge ruling completed")
	
	# Show evidence sprite AFTER all dialogue is complete
	await _camera_focus("center")
	await _show_evidence_sprite(evidence_id)
	
	# Add to presented evidence ONLY after successful presentation (with error handling)
	if evidence_id not in evidence_presented:
		evidence_presented.append(evidence_id)
		print("📋 Courtroom: Evidence ", evidence_id, " successfully added to presented list. Total presented: ", evidence_presented.size())
		print("📋 Courtroom: Presented evidence list: ", evidence_presented)
	else:
		print("⚠️ Courtroom: Evidence ", evidence_id, " was already in presented list!")
	
	print("📋 Courtroom: Evidence branch completed for ", evidence_id)

func _get_evidence_testimony(evidence_id: String) -> Dictionary:
	"""Get testimony data for evidence"""
	if not dialogue_data.has("evidence_testimony"):
		print("⚠️ Courtroom: dialogue_data has no 'evidence_testimony' key!")
		return {}
	
	var evidence_testimonies = dialogue_data.get("evidence_testimony", [])
	print("📋 Courtroom: Searching for testimony. Total testimonies in data: ", evidence_testimonies.size())
	
	for testimony in evidence_testimonies:
		var testimony_id = testimony.get("evidence_id", "")
		print("📋 Courtroom: Checking testimony with evidence_id: '", testimony_id, "' vs looking for: '", evidence_id, "'")
		if testimony_id == evidence_id:
			print("✅ Courtroom: Found matching testimony for ", evidence_id)
			return testimony
	
	print("⚠️ Courtroom: No matching testimony found for evidence_id: ", evidence_id)
	print("📋 Courtroom: Available evidence_ids in testimonies: ", evidence_testimonies.map(func(t): return t.get("evidence_id", "")))
	return {}

func _get_evidence_display_name(evidence_id: String) -> String:
	"""Get display name for evidence (leos_notebook shows as ??????????)"""
	if evidence_id == "leos_notebook":
		return "??????????"
	
	var evidence_names = {
		"broken_body_cam": "sirang body camera",
		"logbook": "police logbook",
		"handwriting_sample": "handwriting sample",
		"radio_log": "radio communication log",
		"autopsy_report": "autopsy report"
	}
	return evidence_names.get(evidence_id, evidence_id)

func _show_evidence_sprite(evidence_id: String) -> void:
	"""Show evidence sprite with animation"""
	if not evidence_display_sprite or not EvidenceInventorySettings:
		return
	
	var evidence_texture = EvidenceInventorySettings.evidence_textures.get(evidence_id)
	if not evidence_texture:
		print("⚠️ Courtroom: Texture not found for evidence: ", evidence_id)
		return
	
	if evidence_display_sprite is Sprite2D:
		evidence_display_sprite.texture = evidence_texture
	
	# Ensure evidence sprite is centered on camera viewport
	if camera:
		evidence_display_sprite.global_position = camera.global_position
	else:
		evidence_display_sprite.global_position = Vector2(640, 360)  # Fallback to screen center
	
	evidence_display_sprite.visible = true
	evidence_display_sprite.modulate.a = 0.0
	# Start smaller
	evidence_display_sprite.scale = Vector2(0.3, 0.3)
	
	# Calculate larger size (add 300 pixels worth of scale)
	var viewport_size = get_viewport().get_visible_rect().size
	var target_scale = 1.0
	if evidence_display_sprite is Sprite2D and evidence_display_sprite.texture:
		var sprite_size = evidence_display_sprite.texture.get_size()
		# Make it 300 pixels larger than original
		var target_size = sprite_size + Vector2(300, 300)
		var scale_x = target_size.x / sprite_size.x
		var scale_y = target_size.y / sprite_size.y
		target_scale = min(scale_x, scale_y, 2.5)  # Cap at 2.5x to prevent too large
	
	# Fade in with larger scale
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(evidence_display_sprite, "modulate:a", 1.0, 0.5)
	tween.tween_property(evidence_display_sprite, "scale", Vector2(target_scale, target_scale), 0.5)
	
	# Keep centered during animation
	if camera:
		tween.tween_method(_update_evidence_position, 0.0, 1.0, 0.5)
	
	await tween.finished
	
	await get_tree().create_timer(2.0).timeout
	
	# Fade out
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(evidence_display_sprite, "modulate:a", 0.0, 0.5)
	tween2.tween_property(evidence_display_sprite, "scale", Vector2(0.3, 0.3), 0.5)
	
	# Keep centered during fade out
	if camera:
		tween2.tween_method(_update_evidence_position, 0.0, 1.0, 0.5)
	
	await tween2.finished
	
	evidence_display_sprite.visible = false

func _show_gavel() -> void:
	"""Show gavel sprite with animation - loops frame 0 and 1, shakes on frame 1, always centered and within bounds"""
	if not gavel_sprite:
		print("⚠️ Courtroom: Gavel sprite not found")
		return
	
	# Calculate viewport center in world coordinates
	var viewport_center_world = Vector2.ZERO
	if camera:
		# Camera's global_position is the center of the viewport in world coordinates
		viewport_center_world = camera.global_position
		gavel_sprite.global_position = viewport_center_world
	else:
		gavel_sprite.global_position = Vector2(640, 360)  # Fallback to screen center
	
	# Ensure sprite is visible and properly sized
	gavel_sprite.visible = true
	gavel_sprite.modulate.a = 0.0
	# Start smaller to ensure it fits
	gavel_sprite.scale = Vector2(0.3, 0.3)
	
	# Calculate max scale to fit within viewport (max 80% of viewport height)
	var viewport_size = get_viewport().get_visible_rect().size
	var max_scale = 0.8  # Max scale to ensure it fits
	if gavel_sprite is Sprite2D and gavel_sprite.texture:
		var sprite_size = gavel_sprite.texture.get_size()
		var scale_x = (viewport_size.x * 0.6) / sprite_size.x
		var scale_y = (viewport_size.y * 0.6) / sprite_size.y
		max_scale = min(scale_x, scale_y, 0.8)  # Cap at 0.8 to be safe
	
	# Fade in with tween
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(gavel_sprite, "modulate:a", 1.0, 0.3)
	tween.tween_property(gavel_sprite, "scale", Vector2(max_scale, max_scale), 0.3)
	
	# Keep centered during animation
	if camera:
		tween.tween_method(_update_gavel_position, 0.0, 1.0, 0.3)
	
	await tween.finished
	
	# Find AnimatedSprite2D
	var animated_sprite: AnimatedSprite2D = null
	if gavel_sprite is AnimatedSprite2D:
		animated_sprite = gavel_sprite
	else:
		animated_sprite = gavel_sprite.find_child("*", true, false) as AnimatedSprite2D
	
	# Play animation with frame 1 shake
	if animated_sprite and animated_sprite.sprite_frames:
		var animation_names = animated_sprite.sprite_frames.get_animation_names()
		if animation_names.size() > 0:
			var anim_name = animation_names[0]
			var sprite_frames = animated_sprite.sprite_frames
			if sprite_frames.has_animation(anim_name):
				sprite_frames.set_animation_loop(anim_name, true)
			
			animated_sprite.play(anim_name)
			
			var previous_frame = -1
			var loop_count = 0
			var max_loops = 3
			
			while loop_count < max_loops:
				await get_tree().process_frame
				
				if not animated_sprite.is_playing():
					break
				
				var current_frame = animated_sprite.frame
				
				# Shake on frame 1 - play gavel slam sound
				if current_frame == 1 and previous_frame != 1:
					_play_gavel_slam()
					_shake_camera(0.2)
				
				# Detect loop
				if current_frame == 0 and previous_frame == 1:
					loop_count += 1
				
				previous_frame = current_frame
			
			animated_sprite.stop()
		else:
			await get_tree().create_timer(0.8).timeout
	else:
		await get_tree().create_timer(0.8).timeout
	
	# Fade out with tween
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(gavel_sprite, "modulate:a", 0.0, 0.3)
	tween2.tween_property(gavel_sprite, "scale", Vector2(0.3, 0.3), 0.3)
	
	# Keep centered during fade out
	if camera:
		tween2.tween_method(_update_gavel_position, 0.0, 1.0, 0.3)
	
	await tween2.finished
	
	gavel_sprite.visible = false
	print("🎬 Courtroom: Gavel animation fully completed and hidden")
	
	# Small delay to ensure everything is settled before continuing
	await get_tree().create_timer(0.1).timeout

func _shake_camera(duration: float = 0.2, shake_amount: float = 8.0, shake_count: int = 4) -> void:
	"""Shake camera with configurable intensity"""
	if not camera:
		return
	
	var original_pos = camera.global_position
	
	for i in range(shake_count):
		var offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		camera.global_position = original_pos + offset
		await get_tree().create_timer(duration / shake_count).timeout
	
	camera.global_position = original_pos

func _update_gavel_position(_value: float) -> void:
	"""Update gavel position to stay centered on camera viewport"""
	if gavel_sprite and camera:
		# Camera's global_position is the center of the viewport
		gavel_sprite.global_position = camera.global_position

func _update_evidence_position(_value: float) -> void:
	"""Update evidence position to stay centered on camera viewport"""
	if evidence_display_sprite and camera:
		# Camera's global_position is the center of the viewport
		evidence_display_sprite.global_position = camera.global_position

func _show_objection() -> void:
	"""Show objection sprite centered on camera viewport, always within bounds"""
	if not objection_sprite:
		print("⚠️ Courtroom: Objection sprite not found")
		return
	
	# Calculate viewport center in world coordinates
	var viewport_center_world = Vector2.ZERO
	if camera:
		# Camera's global_position is the center of the viewport in world coordinates
		viewport_center_world = camera.global_position
		objection_sprite.global_position = viewport_center_world
	else:
		objection_sprite.global_position = Vector2(640, 360)  # Fallback to screen center
	
	# Ensure sprite is visible and properly sized
	objection_sprite.visible = true
	objection_sprite.modulate.a = 0.0
	# Start smaller to ensure it fits
	objection_sprite.scale = Vector2(0.3, 0.3)
	
	# Calculate max scale to fit within viewport (HALVED - max 35% of viewport to leave room)
	var viewport_size = get_viewport().get_visible_rect().size
	var max_scale = 0.35  # Max scale halved (was 0.7)
	if objection_sprite is Sprite2D and objection_sprite.texture:
		var sprite_size = objection_sprite.texture.get_size()
		var scale_x = (viewport_size.x * 0.25) / sprite_size.x  # Halved from 0.5
		var scale_y = (viewport_size.y * 0.25) / sprite_size.y  # Halved from 0.5
		max_scale = min(scale_x, scale_y, 0.35)  # Cap at 0.35 (halved from 0.7)
	
	# Fade in with tween
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(objection_sprite, "modulate:a", 1.0, 0.2)
	tween.tween_property(objection_sprite, "scale", Vector2(max_scale, max_scale), 0.2)
	
	# Keep centered during animation
	if camera:
		tween.tween_method(_update_objection_position, 0.0, 1.0, 0.2)
	
	await tween.finished
	
	# Play objection sound when it appears and starts shaking
	_play_objection_sound()
	
	# Shake camera while keeping objection centered
	var original_pos = camera.global_position if camera else Vector2.ZERO
	for i in range(5):
		if camera:
			var offset = Vector2(
				randf_range(-10.0, 10.0),
				randf_range(-10.0, 10.0)
			)
			camera.global_position = original_pos + offset
			# Update objection position to stay centered on viewport
			objection_sprite.global_position = camera.global_position
		await get_tree().create_timer(0.05).timeout
	
	if camera:
		camera.global_position = original_pos
		objection_sprite.global_position = camera.global_position
	
	await get_tree().create_timer(0.6).timeout
	
	# Fade out with tween
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(objection_sprite, "modulate:a", 0.0, 0.3)
	tween2.tween_property(objection_sprite, "scale", Vector2(0.3, 0.3), 0.3)
	
	# Keep centered during fade out
	if camera:
		tween2.tween_method(_update_objection_position, 0.0, 1.0, 0.3)
	
	await tween2.finished
	
	objection_sprite.visible = false
	print("🎬 Courtroom: Objection animation fully completed and hidden")
	
	# Small delay to ensure everything is settled before continuing
	await get_tree().create_timer(0.1).timeout

func _update_objection_position(_value: float) -> void:
	"""Update objection position to stay centered on camera viewport"""
	if objection_sprite and camera:
		# Camera's global_position is the center of the viewport
		objection_sprite.global_position = camera.global_position

func _play_objection_sound() -> void:
	"""Play objection sound effect - prevents double playing"""
	if not objection_sfx_player:
		return
	
	# Check if the same objection sound is already playing - don't restart it
	if objection_sfx_player.playing:
		print("🔊 Courtroom: Objection sound already playing, skipping to prevent double play")
		return
	
	# Load objection sound from project root
	var objection_path = "res://Objection! - Sound Effect - Sound Meme Effect.mp3"
	
	if ResourceLoader.exists(objection_path):
		var stream = load(objection_path)
		if stream:
			objection_sfx_player.stream = stream
			objection_sfx_player.volume_db = -5.0  # Set to -5 dB
			objection_sfx_player.play()
			print("🔊 Courtroom: Playing objection sound from:", objection_path, " at -5 dB")
		else:
			print("⚠️ Courtroom: Failed to load objection sound stream")
	else:
		print("⚠️ Courtroom: Objection sound file not found at:", objection_path)

func _play_gavel_slam() -> void:
	"""Play gavel slam sound effect - called when gavel hits (frame 1)"""
	if not gavel_sfx_player:
		return
	
	# Try to load gavel slam sound
	var gavel_sound_paths = [
		"res://assets/audio/sfx/gavel_slam.ogg",
		"res://assets/audio/sfx/gavel_slam.wav",
		"res://assets/audio/sfx/gavel.ogg",
		"res://assets/audio/sfx/gavel.wav",
		"res://assets/audio/sfx/SFX_UI_Confirm.ogg",  # Fallback
		"res://assets/audio/sfx/powerUp.wav"  # Another fallback
	]
	
	var sound_loaded = false
	for path in gavel_sound_paths:
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream:
				# Stop any currently playing gavel sound
				if gavel_sfx_player.playing:
					gavel_sfx_player.stop()
				gavel_sfx_player.stream = stream
				gavel_sfx_player.play()
				sound_loaded = true
				print("🔊 Courtroom: Playing gavel slam sound from:", path)
				break
	
	if not sound_loaded:
		print("⚠️ Courtroom: Gavel slam sound file not found. Please add gavel_slam.ogg or gavel_slam.wav to assets/audio/sfx/")

func _on_choice_selected(choice_index: int) -> void:
	"""Handle choice selection from DialogChooser"""
	choice_result = choice_index
	waiting_for_choice = false
	print("🎬 Courtroom: Choice selected: ", choice_index)

func _all_other_evidence_presented() -> bool:
	"""Check if all evidence except leos_notebook has been presented (need ALL other evidence)"""
	if not EvidenceInventorySettings:
		return false
	
	var collected_evidence = EvidenceInventorySettings.collected_evidence
	var all_other_evidence: Array[String] = []
	
	# Get all evidence except leos_notebook
	for evidence_id in collected_evidence:
		if evidence_id != "leos_notebook":
			all_other_evidence.append(evidence_id)
	
	# Check if ALL other evidence have been presented (not just 5)
	var all_presented = true
	for evidence_id in all_other_evidence:
		if evidence_id not in evidence_presented:
			all_presented = false
			break
	
	var presented_count = 0
	for evidence_id in all_other_evidence:
		if evidence_id in evidence_presented:
			presented_count += 1
	
	print("📋 Courtroom: Other evidence check - Presented: ", presented_count, " / Total: ", all_other_evidence.size(), " = ", all_presented)
	return all_presented

func _update_final_evidence_visibility() -> void:
	"""Update visibility of leos_notebook in evidence inventory - hide until ALL other evidence are presented"""
	if not EvidenceInventorySettings:
		print("⚠️ Courtroom: EvidenceInventorySettings not found for final evidence visibility update")
		return
	
	# Check if leos_notebook is in collected evidence
	var collected_evidence = EvidenceInventorySettings.collected_evidence
	if "leos_notebook" not in collected_evidence:
		print("📋 Courtroom: leos_notebook not in collected evidence, skipping visibility update")
		return
	
	# Use function in EvidenceInventorySettings to update visibility
	# Hide leos_notebook until ALL other evidence are presented
	var should_show = _all_other_evidence_presented()
	EvidenceInventorySettings.set_evidence_slot_visibility("leos_notebook", should_show)
	
	if should_show:
		print("📋 Courtroom: Final evidence (leos_notebook) is now available - ALL other evidence presented")
	else:
		print("📋 Courtroom: Final evidence (leos_notebook) HIDDEN - need ALL other evidence presented first")

func _handle_contradiction_phase(line: Dictionary) -> void:
	"""Handle contradiction phase - player can press statement or present evidence"""
	var speaker = line.get("speaker", "")
	var contradictions = line.get("contradictions", [])
	
	if contradictions.is_empty():
		print("⚠️ Courtroom: Line marked as contradictable but no contradictions defined")
		return
	
	can_contradict = true
	waiting_for_contradiction = true
	contradiction_evidence_id = ""
	
	# Show options to press or present evidence
	if dialog_chooser:
		var choices = ["Pindutin ang pahayag", "Ipakita ang ebidensya", "Magpatuloy"]
		dialog_chooser.show_choices(choices)
		
		waiting_for_choice = true
		choice_result = -1
		while waiting_for_choice:
			await get_tree().process_frame
		
		match choice_result:
			0:  # Press statement
				await _press_statement(line)
			1:  # Present evidence
				await _present_evidence_for_contradiction(line, contradictions)
			2:  # Continue (skip contradiction)
				can_contradict = false
				waiting_for_contradiction = false
				return
	
	can_contradict = false
	waiting_for_contradiction = false

func _press_statement(line: Dictionary) -> void:
	"""Press a statement to get more information"""
	var press_response = line.get("press_response", "")
	
	if press_response == "":
		press_response = "Mahal na Hukom, maaari po bang linawin ang pahayag na ito?"
	
	if DialogueUI:
		await _camera_focus("player")
		DialogueUI.show_dialogue_line("Miguel", press_response, false)
		await _wait_for_dialogue_next()
		
		# Show follow-up dialogue if available
		var follow_up = line.get("follow_up", null)
		if follow_up != null:
			var follow_up_speaker = follow_up.get("speaker", line.get("speaker", ""))
			var follow_up_text = follow_up.get("text", "")
			if follow_up_text != "":
				await _camera_focus(_get_speaker_camera_target(follow_up_speaker))
				DialogueUI.show_dialogue_line(follow_up_speaker, follow_up_text, false)
				await _wait_for_dialogue_next()

func _present_evidence_for_contradiction(line: Dictionary, contradictions: Array) -> void:
	"""Present evidence to contradict a statement"""
	# Show evidence inventory
	if EvidenceInventorySettings:
		EvidenceInventorySettings.show_evidence_inventory(true)
	
	# Wait for evidence selection (no dialogue - just wait for click)
	waiting_for_contradiction = true
	selected_evidence_id = ""
	
	# Wait for evidence selection with timeout protection
	var timeout = 0.0
	var max_wait_time = 300.0  # 5 minutes max wait (should never happen)
	
	while waiting_for_contradiction and timeout < max_wait_time:
		await get_tree().process_frame
		timeout += get_process_delta_time()
		
		if selected_evidence_id != "":
			# Immediately break the wait loop and process
			waiting_for_contradiction = false
			
			# Check if this evidence is correct for any contradiction
			var correct_contradiction = null
			for contradiction in contradictions:
				var required_evidence = contradiction.get("evidence_id", "")
				if selected_evidence_id == required_evidence:
					correct_contradiction = contradiction
					break
			
			if correct_contradiction != null:
				# Correct evidence - show contradiction dialogue
				# Hide inventory first to avoid conflicts
				if EvidenceInventorySettings:
					EvidenceInventorySettings.hide_evidence_inventory()
				await _show_correct_contradiction(line, correct_contradiction, selected_evidence_id)
				break
			else:
				# Wrong evidence - show failure dialogue and lose a life
				# Hide inventory first
				if EvidenceInventorySettings:
					EvidenceInventorySettings.hide_evidence_inventory()
				lose_life()
				await _show_wrong_contradiction(line, selected_evidence_id)
				# Reset and wait for another selection
				selected_evidence_id = ""
				waiting_for_contradiction = true
				# Show inventory again for retry
				if EvidenceInventorySettings:
					EvidenceInventorySettings.show_evidence_inventory(true)
				timeout = 0.0  # Reset timeout
	
	# Hide evidence inventory (final cleanup)
	if EvidenceInventorySettings:
		EvidenceInventorySettings.hide_evidence_inventory()

func _show_correct_contradiction(line: Dictionary, contradiction: Dictionary, evidence_id: String) -> void:
	"""Show correct contradiction response - proper objection/gavel flow"""
	var contradiction_text = contradiction.get("response", "")
	var judge_response = contradiction.get("judge_response", "")
	
	# Show evidence sprite first
	await _camera_focus("center")
	await _show_evidence_sprite(evidence_id)
	
	# Player presents contradiction
	if DialogueUI:
		await _camera_focus("player")
		if contradiction_text == "":
			contradiction_text = "Mahal na Hukom, ang ebidensyang ito ay direktang sumasalungat sa pahayag!"
		DialogueUI.show_dialogue_line("Miguel", contradiction_text, false)
		await _wait_for_dialogue_next()
		
		# Show objection animation FIRST - before "Tutol po!" dialogue
		await _camera_focus("fiscal")
		await _show_objection()
		print("🎬 Courtroom: Objection animation shown FIRST, now fiscal will say 'Tutol po!'")
		
		# Fiscal objects - SAY "Tutol po!" AFTER objection animation
		await _camera_focus("fiscal")
		DialogueUI.show_dialogue_line("Fiscal", "Tutol po!", false)
		await _wait_for_dialogue_next()
		print("🎬 Courtroom: Fiscal said 'Tutol po!' - moving to fiscal follow-up")
		
		# Fiscal nagrereklamo (follow-up complaint) AFTER objection animation
		await _camera_focus("fiscal")
		DialogueUI.show_dialogue_line("Fiscal", "Mahal na Hukom, ang ebidensyang ito ay walang kaugnayan sa pahayag na ito!", false)
		await _wait_for_dialogue_next()
		print("🎬 Courtroom: Fiscal follow-up (nagrereklamo) completed")
		
		# Player counters AFTER fiscal follow-up
		await _camera_focus("player")
		DialogueUI.show_dialogue_line("Miguel", "Tutol po! Mahal na Hukom, ang ebidensya ay direktang sumasalungat!", false)
		await _wait_for_dialogue_next()
		print("🎬 Courtroom: Player counter completed")
		
		# Show objection animation again AFTER player counter
		await _show_objection()
		print("🎬 Courtroom: Second objection animation completed")
		
		# NOW show gavel AFTER all opinions/statements are done (fiscal + miguel)
		await _camera_focus("judge")
		print("🎬 Courtroom: All statements done - showing gavel, then judge will speak")
		await _show_gavel()
		print("🎬 Courtroom: Gavel completed - now judge can speak")
		
		# Judge makes ruling AFTER gavel completes (camera already on judge from gavel)
		await _camera_focus("judge")  # Ensure camera is still on judge
		if judge_response != "":
			DialogueUI.show_dialogue_line("Hukom", judge_response, false)
			await _wait_for_dialogue_next()
			print("🎬 Courtroom: Judge ruling completed")
		
		# Show success dialogue if available
		var success_dialogue = contradiction.get("success_dialogue", null)
		if success_dialogue != null:
			var success_speaker = success_dialogue.get("speaker", "Miguel")
			var success_text = success_dialogue.get("text", "")
			if success_text != "":
				await _camera_focus(_get_speaker_camera_target(success_speaker))
				DialogueUI.show_dialogue_line(success_speaker, success_text, false)
				await _wait_for_dialogue_next()
		
		# Show Erwin dialogue if available (make dialogue longer)
		var erwin_dialogue = contradiction.get("erwin_dialogue", null)
		if erwin_dialogue != null:
			var erwin_speaker = erwin_dialogue.get("speaker", "Erwin")
			var erwin_text = erwin_dialogue.get("text", "")
			if erwin_text != "":
				await _camera_focus(_get_speaker_camera_target(erwin_speaker))
				DialogueUI.show_dialogue_line(erwin_speaker, erwin_text, false)
				await _wait_for_dialogue_next()
				print("🎬 Courtroom: Erwin dialogue completed")
		
		# Show Celine dialogue if available (make dialogue longer)
		var celine_dialogue = contradiction.get("celine_dialogue", null)
		if celine_dialogue != null:
			var celine_speaker = celine_dialogue.get("speaker", "Celine")
			var celine_text = celine_dialogue.get("text", "")
			if celine_text != "":
				await _camera_focus(_get_speaker_camera_target(celine_speaker))
				DialogueUI.show_dialogue_line(celine_speaker, celine_text, false)
				await _wait_for_dialogue_next()
				print("🎬 Courtroom: Celine dialogue completed")
		
		print("🎬 Courtroom: Contradiction flow completed")

func _show_wrong_contradiction(line: Dictionary, evidence_id: String) -> void:
	"""Show wrong contradiction response"""
	if DialogueUI:
		await _camera_focus("judge")
		DialogueUI.show_dialogue_line("Hukom", "Abogado, ang ebidensyang ito ay hindi sumasalungat sa pahayag. Subukan mo ulit o magpatuloy.", false)
		await _wait_for_dialogue_next()

func _fade_out_to_main_menu() -> void:
	"""Fade out and transition to main menu"""
	print("🎬 Courtroom: Fading out to main menu")
	
	# Hide dialogue UI
	if DialogueUI:
		DialogueUI.hide_ui()
	
	# Create full-screen fade overlay
	var canvas_layer = CanvasLayer.new()
	var fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.color.a = 0.0
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(fade_rect)
	
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(canvas_layer)
		canvas_layer.layer = 100
	
	# Fade out audio
	if AudioManager:
		await AudioManager.fade_out_bgm(2.0)
	
	# Fade in to black
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 2.0)
	await tween.finished
	
	# Small delay
	await get_tree().create_timer(0.5).timeout
	
	# Change to main menu - return immediately after scene change
	# Don't continue execution after this point as the scene will be freed
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://scenes/ui/UI by jer/design/main_menu.tscn")
		return  # Exit immediately - old scene will be freed

func _show_summary_cutscene() -> void:
	"""Show a summary cutscene of what happened in the trial"""
	print("🎬 Courtroom: Showing summary cutscene")
	
	# Hide dialogue UI
	if DialogueUI:
		DialogueUI.hide_ui()
	
	# Create full-screen overlay for summary
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "SummaryLayer"
	canvas_layer.layer = 200  # Above everything
	
	var summary_panel = Panel.new()
	summary_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9)  # Dark background
	summary_panel.add_theme_stylebox_override("panel", style)
	canvas_layer.add_child(summary_panel)
	
	# Create container for text
	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.offset_left = 100.0
	container.offset_right = -100.0
	container.offset_top = 150.0
	container.offset_bottom = -150.0
	container.add_theme_constant_override("separation", 30)
	summary_panel.add_child(container)
	
	# Add title
	var title = Label.new()
	title.text = "KATAPUSAN NG KASO"
	var title_settings = LabelSettings.new()
	var font = load("res://assets/fonts/PixelOperator-Bold.ttf")
	if font:
		title_settings.font = font
	title_settings.font_size = 36
	title_settings.font_color = Color.WHITE
	title.label_settings = title_settings
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(title)
	
	# Add summary text slides
	var summary_texts = [
		"Matapos ang masusing paglilitis, ang hukuman ay nagpasyang si Erwin ay INOSENTE.",
		"Ang lahat ng ebidensya na ipinresenta ng depensa ay nagpapatunay na ang akusado ay hindi nagkasala.",
		"Ang confession na ipinakita ng piskalya ay napatunayang peke sa pamamagitan ng pagsusuri ng sulat-kamay.",
		"Ang timeline ng prosecution ay may mga inconsistencies na direktang sumasalungat sa mga ebidensya.",
		"Si Erwin ay napalaya at ang katotohanan ay nanalo."
	]
	
	get_tree().current_scene.add_child(canvas_layer)
	
	# Show each summary text with fade in/out
	for summary_text in summary_texts:
		# Create text label
		var text_label = Label.new()
		text_label.text = summary_text
		var text_settings = LabelSettings.new()
		if font:
			text_settings.font = font
		text_settings.font_size = 24
		text_settings.font_color = Color.WHITE
		text_label.label_settings = text_settings
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.modulate.a = 0.0
		container.add_child(text_label)
		
		# Fade in
		var fade_in = create_tween()
		fade_in.tween_property(text_label, "modulate:a", 1.0, 1.0)
		await fade_in.finished
		
		# Wait for text to be read
		await get_tree().create_timer(3.0).timeout
		
		# Fade out
		var fade_out = create_tween()
		fade_out.tween_property(text_label, "modulate:a", 0.0, 1.0)
		await fade_out.finished
		
		# Remove text label
		text_label.queue_free()
	
	# Fade out the entire summary panel
	var final_fade = create_tween()
	final_fade.tween_property(summary_panel, "modulate:a", 0.0, 1.0)
	await final_fade.finished
	
	# Clean up
	canvas_layer.queue_free()
	print("🎬 Courtroom: Summary cutscene completed")
