extends Node2D

var label: Label = null

var fade_in_duration: float = 1.5
var hold_duration: float = 6.0  # Increased for narrative thoughts
var fade_out_duration: float = 1.5

func _ready() -> void:
	# Position the parent Node2D at viewport center (640, 360)
	# This is half of 1280x720
	position = Vector2(640, 360)
	
	# Create CanvasLayer for UI elements (Control nodes need CanvasLayer)
	var canvas_layer: CanvasLayer = null
	if not has_node("CanvasLayer"):
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer"
		canvas_layer.layer = 100  # High layer to be on top
		add_child(canvas_layer)
	else:
		canvas_layer = $CanvasLayer
	
	# Create label if it doesn't exist
	if not canvas_layer.has_node("Label"):
		label = Label.new()
		label.name = "Label"
		canvas_layer.add_child(label)
	else:
		label = canvas_layer.get_node("Label")
	
	# Setup label - center it properly on 1280x720 viewport
	if label:
		label.modulate.a = 0.0
		label.visible = true
		# Center the label text alignment
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# Load font if label_settings doesn't exist
		if not label.label_settings:
			var label_settings = LabelSettings.new()
			var font = load("res://assets/fonts/PixelOperator-Bold.ttf")
			if font:
				label_settings.font = font
				label_settings.font_size = 22
			label.label_settings = label_settings
		else:
			label.label_settings.font_size = 22
		
		# Center label on 1280x720 viewport
		# Set anchors to center (0.5, 0.5)
		label.set_anchors_preset(Control.PRESET_CENTER)
		# Set size with margins (1000x600 centered)
		label.offset_left = -500
		label.offset_top = -300
		label.offset_right = 500
		label.offset_bottom = 300
		
		print("🎬 CinematicText: Label created and configured at position: ", label.position)
	
	# Start the cinematic sequence
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Show evidence summary directly
	print("🎬 CinematicText: Showing evidence summary")
	show_evidence_summary()

func show_evidence_summary() -> void:
	"""Show a summary of all collected evidence with fade in/out"""
	if not label:
		print("⚠️ CinematicText: Label not found")
		return
	
	# Get collected evidence - access as autoload
	var evidence_manager = get_node_or_null("/root/EvidenceInventorySettings")
	if not evidence_manager:
		print("⚠️ CinematicText: EvidenceInventorySettings not found")
		# Show default text
		await show_text("Evidence collected...", fade_in_duration, hold_duration, fade_out_duration)
		return
	
	print("🎬 CinematicText: EvidenceInventorySettings found")
	
	# Get collected evidence array - access directly as it's a public property
	var collected_evidence: Array = evidence_manager.collected_evidence
	print("🎬 CinematicText: Collected evidence array size: ", collected_evidence.size())
	print("🎬 CinematicText: Collected evidence IDs: ", collected_evidence)
	
	# Also check evidence slots visibility as backup
	var visible_count = 0
	var evidence_slots = evidence_manager.evidence_slots
	for slot in evidence_slots:
		if slot and slot.visible:
			visible_count += 1
	print("🎬 CinematicText: Visible evidence slots: ", visible_count)
	
	# If we have visible slots but empty array, reconstruct from slots
	if visible_count > 0 and collected_evidence.is_empty():
		var evidence_mapping = evidence_manager.evidence_mapping
		for i in range(min(visible_count, evidence_mapping.size())):
			var evidence_id = evidence_mapping[i]
			if evidence_id not in collected_evidence:
				collected_evidence.append(evidence_id)
		print("🎬 CinematicText: Reconstructed evidence from slots: ", collected_evidence)
	
	if collected_evidence.is_empty():
		print("⚠️ CinematicText: No evidence in collected_evidence array")
		await show_text("No evidence collected yet...", fade_in_duration, hold_duration, fade_out_duration)
		return
	
	# Load evidence data to get names
	var evidence_data = _load_evidence_data()
	
	# Build narrative thoughts about the evidence
	var narrative_lines: Array[String] = []
	
	# Generate internal thoughts/dialogue based on collected evidence
	for i in range(collected_evidence.size()):
		var evidence_id = collected_evidence[i]
		var evidence_name = _get_evidence_display_name(evidence_id, evidence_data)
		var evidence_description = _get_evidence_description(evidence_id, evidence_data)
		
		# Generate narrative thought for each evidence
		var thought = _generate_evidence_thought(evidence_id, evidence_name, evidence_description, evidence_data)
		if thought != "":
			narrative_lines.append(thought)
			narrative_lines.append("")  # Add spacing between thoughts
	
	# Join lines with newlines
	var narrative_text = "\n".join(narrative_lines)
	
	# Debug: Check if we have text
	if narrative_text.is_empty():
		print("⚠️ CinematicText: No narrative text generated!")
		narrative_text = "May mga bagay na natagpuan ko... Kailangan kong pag-isipan ang lahat ng ito."
	
	print("🎬 CinematicText: Generated narrative text (", narrative_text.length(), " chars)")
	
	# Show the narrative thoughts with fade in/out
	await show_text(narrative_text, fade_in_duration, hold_duration, fade_out_duration)
	
	# After showing summary, mark checkpoint and transition to courtroom
	_mark_cutscene_completed()
	await _transition_to_courtroom()

func show_text(text: String, fade_in: float, hold: float, fade_out: float) -> void:
	"""Show text with fade in, hold, and fade out"""
	if not label:
		print("⚠️ CinematicText: Label is null in show_text!")
		return
	
	print("🎬 CinematicText: Showing text (length: ", text.length(), ")")
	print("🎬 CinematicText: Text preview: ", text.substr(0, min(100, text.length())))
	
	label.text = text
	label.visible = true
	label.modulate.a = 0.0
	
	# Ensure label is in the scene tree and visible
	if not label.is_inside_tree():
		print("⚠️ CinematicText: Label not in scene tree!")
	
	# Force update
	label.queue_redraw()
	
	print("🎬 CinematicText: Label visible: ", label.visible, ", modulate.a: ", label.modulate.a, ", text length: ", label.text.length())
	print("🎬 CinematicText: Label position: ", label.position, ", size: ", label.size)
	
	# Fade in
	var fade_in_tween = create_tween()
	fade_in_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fade_in_tween.tween_property(label, "modulate:a", 1.0, fade_in)
	await fade_in_tween.finished
	
	# Hold
	await get_tree().create_timer(hold).timeout
	
	# Fade out
	var fade_out_tween = create_tween()
	fade_out_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade_out_tween.tween_property(label, "modulate:a", 0.0, fade_out)
	await fade_out_tween.finished
	
	label.visible = false

func _load_evidence_data() -> Dictionary:
	"""Load evidence data from JSON file"""
	var file = FileAccess.open("res://data/evidence_texts.json", FileAccess.READ)
	if file == null:
		print("⚠️ CinematicText: Could not open evidence_texts.json")
		return {}
	
	var text = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("⚠️ CinematicText: Failed to parse evidence_texts.json")
		return {}
	
	return parsed

func _get_evidence_display_name(evidence_id: String, evidence_data: Dictionary) -> String:
	"""Get the display name for evidence, handling masked evidence"""
	if evidence_data.is_empty() or not evidence_data.has("evidence"):
		return evidence_id
	
	if not evidence_data.evidence.has(evidence_id):
		return evidence_id
	
	var evidence_info = evidence_data.evidence[evidence_id]
	var name = evidence_info.get("name", evidence_id)
	
	# If it's masked (???????????), show it as masked
	if name == "???????????":
		return "???????????"
	
	return name

func _get_evidence_description(evidence_id: String, evidence_data: Dictionary) -> String:
	"""Get the description for evidence, handling masked evidence"""
	if evidence_data.is_empty() or not evidence_data.has("evidence"):
		return ""
	
	if not evidence_data.evidence.has(evidence_id):
		return ""
	
	var evidence_info = evidence_data.evidence[evidence_id]
	var description = evidence_info.get("description", "")
	
	# If it's masked (???????????), show it as masked
	if description == "???????????":
		return "???????????"
	
	return description

func _generate_evidence_thought(evidence_id: String, evidence_name: String, evidence_description: String, evidence_data: Dictionary) -> String:
	"""Generate internal thought/dialogue about the evidence"""
	# If evidence is masked, show mysterious thought
	if evidence_name == "???????????" or evidence_description == "???????????":
		return "May isang bagay dito na hindi ko pa maintindihan... Bakit kaya nila ito tinatago?"
	
	# Generate thoughts based on evidence type
	match evidence_id:
		"handwriting_sample":
			return "Ang handwriting sample... Hindi ito kay Leo. May nag-tamper sa records. Sino kaya ang may pakana nito?"
		
		"logbook":
			return "Ang patrol logbook... May mga pagkakaiba sa timeline. Bakit kaya may nag-fake ng entry? Ano ang tinatago nila?"
		
		"broken_body_cam":
			return "Ang nasirang body camera... Maaaring may footage dito na makakatulong. Kailangan kong malaman kung ano ang nakita nito."
		
		"radio_log":
			return "Ang radio communication log... May gaps sa critical time period. Bakit walang radio activity? Ano ang nangyari?"
		
		"autopsy_report":
			return "Ang autopsy report... Defensive wounds. Foreign DNA. Hindi ito suicide. May nag-fight back si Leo. Sino ang pumatay sa kanya?"
		
		"leos_notebook":
			return "Ang notebook ni Leo... Mga pangalan, petsa, code words tungkol sa corruption. Ito ang 'treasure chest' niya. Ang katotohanan ay nasa mga pahina na ito."
		
		_:
			# Generic thought based on description
			if evidence_description != "":
				return "Tungkol sa " + evidence_name.to_lower() + "... " + evidence_description
			else:
				return "May natagpuan ako: " + evidence_name + ". Paano kaya ito makakatulong sa kaso?"

func _mark_cutscene_completed() -> void:
	"""Mark the cinematic text cutscene as completed"""
	if CheckpointManager:
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.CINEMATIC_TEXT_CUTSCENE_COMPLETED)
		print("🎬 CinematicText: Cutscene completed checkpoint set")

func _transition_to_courtroom() -> void:
	"""Transition to the courtroom scene after cinematic text"""
	var courtroom_path = "res://scenes/environments/Courtroom/courtroom.tscn"
	print("🎬 CinematicText: Transitioning to courtroom: ", courtroom_path)
	
	# Fade out
	var fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.color.a = 0.0
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 1000
	canvas_layer.add_child(fade_rect)
	get_tree().current_scene.add_child(canvas_layer)
	
	# Fade to black
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, 1.0)
	await fade_tween.finished
	
	# Change scene
	var tree := get_tree()
	if tree == null:
		return
	
	var result: Error
	# Check if ScenePreloader autoload exists
	var scene_preloader = get_node_or_null("/root/ScenePreloader")
	if scene_preloader and scene_preloader.has_method("is_scene_preloaded") and scene_preloader.is_scene_preloaded(courtroom_path):
		print("🚀 Using preloaded scene: ", courtroom_path.get_file())
		var preloaded_scene = scene_preloader.get_preloaded_scene(courtroom_path)
		result = tree.change_scene_to_packed(preloaded_scene)
	else:
		print("📁 Loading scene from file: ", courtroom_path.get_file())
		result = tree.change_scene_to_file(courtroom_path)
	
	if result != OK:
		print("❌ Failed to change scene to: ", courtroom_path)
		return
	
	# Wait for scene to be ready
	await tree.process_frame
	await tree.process_frame

# AnimationPlayer callbacks (if called from animation)
func show_sinister_text(fade_in: float, hold: float, fade_out: float) -> void:
	"""Show sinister text - called from AnimationPlayer"""
	var text = "May pupuntahan pa ako na baka makatulong din sa kaso."
	await show_text(text, fade_in, hold, fade_out)

func show_inventory_with_masked_last_evidence(hold_duration: float) -> void:
	"""Show evidence summary - called from AnimationPlayer at 11 seconds"""
	print("🎬 CinematicText: show_inventory_with_masked_last_evidence called from animation with hold_duration: ", hold_duration)
	# Update hold duration if provided
	if hold_duration > 0:
		hold_duration = hold_duration
	# Call show_evidence_summary which will display the narrative thoughts
	show_evidence_summary()
