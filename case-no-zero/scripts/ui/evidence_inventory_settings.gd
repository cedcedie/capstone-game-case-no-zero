extends CanvasLayer

# EvidenceInventorySettings - Autoload for managing evidence and inventory UI

var is_visible: bool = false
var player_camera: Camera2D = null
var ui_container: Control = null

# Evidence system
var evidence_data: Dictionary = {}
var collected_evidence: Array = []
var current_evidence: String = ""

# UI References
var evidence_slots: Array = []
var evidence_display: TextureRect
var evidence_label: Label
var evidence_name: Label
var evidence_description: Label
var evidence_tab: NinePatchRect
var settings_tab: NinePatchRect
var main_bg: NinePatchRect

# Evidence textures - preload them for better performance
var handwriting_sample_texture = preload("res://assets/sprites/evidence/handwriting_sample_evidence.png")
var logbook_texture = preload("res://assets/sprites/evidence/logbook_evidence.png")
var broken_body_cam_texture = preload("res://assets/sprites/evidence/broken_body_cam_evidence.png")
var cctv_footage_texture = preload("res://assets/sprites/evidence/cctv_evidence.png")
var radio_log_texture = preload("res://assets/sprites/evidence/radio_log_evidence.png")
var autopsy_report_texture = preload("res://assets/sprites/evidence/autopsy_evidence.png")
var leos_notebook_texture = preload("res://assets/sprites/evidence/leos_notebook_evidence.png")

func _ready():
	# Start hidden
	hide()
	ui_container = $UIContainer
	
	# Load evidence data
	_load_evidence_data()
	
	# Get UI references
	_get_ui_references()
	
	# Setup evidence slots
	_setup_evidence_slots()
	
	# Initially hide all evidence except the first one
	_initialize_evidence_visibility()
	
	# Debug: Check if textures are loaded
	print("📋 EvidenceInventorySettings: Ready")
	print("📋 Handwriting sample texture loaded: ", handwriting_sample_texture != null)
	print("📋 Logbook texture loaded: ", logbook_texture != null)
	print("📋 Evidence display reference (EvidenceCloseUp/TextureRect): ", evidence_display != null)

func show_evidence_inventory():
	"""Show the evidence inventory UI with smooth fade animation from center"""
	if not is_visible:
		is_visible = true
		show()
		
		# Start with transparent and slightly scaled down
		if ui_container:
			ui_container.modulate = Color.TRANSPARENT
			ui_container.scale = Vector2(0.1, 0.1)  # Start very small for center scaling effect
			
			# Set pivot to center for scaling from center
			ui_container.pivot_offset = ui_container.size / 2
			
			# Create smooth fade and scale animation
			var tween = create_tween()
			tween.set_parallel(true)  # Allow multiple properties to animate simultaneously
			
			# Fade in
			tween.tween_property(ui_container, "modulate", Color.WHITE, 0.5)
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_QUART)
			
			# Scale up smoothly from center
			tween.tween_property(ui_container, "scale", Vector2.ONE, 0.5)
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_BACK)
		
		print("📋 EvidenceInventorySettings: Shown with smooth center scale animation")
		
		# Find player camera
		_find_player_camera()

func hide_evidence_inventory():
	"""Hide the evidence inventory UI with smooth fade animation to center"""
	if is_visible:
		is_visible = false
		
		if ui_container:
			# Ensure pivot is set to center for scaling to center
			ui_container.pivot_offset = ui_container.size / 2
			
			# Create smooth fade and scale animation
			var tween = create_tween()
			tween.set_parallel(true)  # Allow multiple properties to animate simultaneously
			
			# Fade out
			tween.tween_property(ui_container, "modulate", Color.TRANSPARENT, 0.4)
			tween.set_ease(Tween.EASE_IN)
			tween.set_trans(Tween.TRANS_QUART)
			
			# Scale down to center
			tween.tween_property(ui_container, "scale", Vector2(0.1, 0.1), 0.4)
			tween.set_ease(Tween.EASE_IN)
			tween.set_trans(Tween.TRANS_BACK)
			
			await tween.finished
		
		hide()
		print("📋 EvidenceInventorySettings: Hidden with smooth center scale animation")

func toggle_evidence_inventory():
	"""Toggle the evidence inventory UI"""
	if is_visible:
		hide_evidence_inventory()
	else:
		show_evidence_inventory()

func _load_evidence_data():
	"""Load evidence data from JSON file"""
	var file = FileAccess.open("res://data/evidence_texts.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			evidence_data = json.data
			print("📋 Evidence data loaded successfully")
		else:
			print("⚠️ Failed to parse evidence data JSON")
	else:
		print("⚠️ Failed to load evidence data file")

func _get_ui_references():
	"""Get references to UI elements"""
	evidence_display = ui_container.get_node("EvidenceBoxDesvriptionBG/EvidenceCloseUp/TextureRect")
	evidence_label = ui_container.get_node("EvidenceBoxDesvriptionBG/EvidenceLabel")
	evidence_name = ui_container.get_node("EvidenceBoxDesvriptionBG/EvidenceName")
	evidence_description = ui_container.get_node("EvidenceBoxDesvriptionBG/EvidenceDescription")
	evidence_tab = ui_container.get_node("EvidenceTab")
	settings_tab = ui_container.get_node("SettingsTab")
	main_bg = ui_container.get_node("EvidenceBoxMainBG")

func _setup_evidence_slots():
	"""Setup evidence slots with click detection and hover effects"""
	var evidence_list_bg = ui_container.get_node("EvidenceBoxListBG")
	
	# Get all evidence slots (Evidence1 through Evidence7)
	for i in range(1, 8):
		var evidence_slot = evidence_list_bg.get_node_or_null("Evidence" + str(i))
		if evidence_slot:
			evidence_slots.append(evidence_slot)
			# Make it clickable and hoverable
			evidence_slot.gui_input.connect(_on_evidence_slot_clicked.bind(i - 1))  # Use 0-based index
			evidence_slot.mouse_entered.connect(_on_evidence_slot_hover.bind(i - 1, true))
			evidence_slot.mouse_exited.connect(_on_evidence_slot_hover.bind(i - 1, false))
	
	# Setup hover effects for tabs and main background
	if evidence_tab:
		evidence_tab.gui_input.connect(_on_evidence_tab_clicked)
		evidence_tab.mouse_entered.connect(_on_evidence_tab_hover.bind(true))
		evidence_tab.mouse_exited.connect(_on_evidence_tab_hover.bind(false))
	
	if settings_tab:
		settings_tab.gui_input.connect(_on_settings_tab_clicked)
		settings_tab.mouse_entered.connect(_on_settings_tab_hover.bind(true))
		settings_tab.mouse_exited.connect(_on_settings_tab_hover.bind(false))
	
	if main_bg:
		main_bg.gui_input.connect(_on_main_bg_clicked)
		main_bg.mouse_entered.connect(_on_main_bg_hover.bind(true))
		main_bg.mouse_exited.connect(_on_main_bg_hover.bind(false))

func _initialize_evidence_visibility():
	"""Initialize evidence visibility - hide all evidence initially"""
	for i in range(evidence_slots.size()):
		evidence_slots[i].visible = false

func _on_evidence_slot_clicked(evidence_index: int, event: InputEvent):
	"""Handle evidence slot click"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_evidence(evidence_index)

func _select_evidence(evidence_index: int):
	"""Select and display evidence"""
	# Check if this evidence slot is visible (has collected evidence)
	if evidence_index >= collected_evidence.size():
		return
	
	var evidence_id = collected_evidence[evidence_index]
	if evidence_id in evidence_data.evidence:
		current_evidence = evidence_id
		_display_evidence(evidence_id)
		print("📋 Selected evidence: " + evidence_id)

func _display_evidence(evidence_id: String):
	"""Display evidence information in the description panel"""
	var evidence_info = evidence_data.evidence[evidence_id]
	
	# Update labels
	evidence_label.text = "Evidence:"
	evidence_name.text = evidence_info.name
	evidence_description.text = evidence_info.description
	
	# Update evidence display texture using preloaded textures
	var texture = _get_evidence_texture(evidence_id)
	if texture:
		evidence_display.texture = texture
		evidence_display.visible = true
		print("📋 Evidence display updated with texture for: " + evidence_id)
	else:
		evidence_display.visible = false
		print("⚠️ No texture found for evidence: " + evidence_id)

func _get_evidence_texture(evidence_id: String) -> Texture2D:
	"""Get the texture for evidence based on its ID"""
	match evidence_id:
		"handwriting_sample":
			return handwriting_sample_texture
		"logbook":
			return logbook_texture
		"broken_body_cam":
			return broken_body_cam_texture
		"cctv_footage":
			return cctv_footage_texture
		"radio_log":
			return radio_log_texture
		"autopsy_report":
			return autopsy_report_texture
		"leos_notebook":
			return leos_notebook_texture
		_:
			return null

func add_evidence(evidence_id: String):
	"""Add new evidence to the collection"""
	if evidence_id not in collected_evidence:
		collected_evidence.append(evidence_id)
		
		# Show the corresponding evidence slot
		var slot_index = collected_evidence.size() - 1
		if slot_index < evidence_slots.size():
			evidence_slots[slot_index].visible = true
			print("📋 Evidence added: " + evidence_id)
			
			# If this is the first evidence, automatically select it
			if collected_evidence.size() == 1:
				_select_evidence(0)

func _find_player_camera():
	"""Find the player's camera for positioning"""
	var scene_root = get_tree().current_scene
	if scene_root:
		var player = scene_root.get_node_or_null("PlayerM")
		if not player:
			player = scene_root.get_node_or_null("Player")
		
		if player:
			player_camera = player.get_node_or_null("Camera2D")
			if player_camera:
				print("📋 EvidenceInventorySettings: Player camera found")
			else:
				print("⚠️ EvidenceInventorySettings: Player camera not found")
		else:
			print("⚠️ EvidenceInventorySettings: Player not found")

func _input(event):
	"""Handle input for evidence inventory"""
	# Check if bedroom cutscene is completed
	var checkpoint_manager = get_node_or_null("/root/CheckpointManager")
	var bedroom_cutscene_completed = false
	
	if checkpoint_manager:
		bedroom_cutscene_completed = checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
	
	# Check if we're in a cutscene (any scene with cutscene_played = false)
	var in_cutscene = false
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("_input"):
		# Check if this scene has cutscene_played property and it's false
		if "cutscene_played" in current_scene and not current_scene.cutscene_played:
			in_cutscene = true
		# Special case: check if we're in evidence collection phase (line 12 exception)
		elif "evidence_collection_phase" in current_scene and current_scene.evidence_collection_phase:
			in_cutscene = false  # Allow during evidence collection phase
	
	# Only allow evidence inventory access after bedroom cutscene is completed
	if event.is_action_pressed("evidence_inventory"):
		if not bedroom_cutscene_completed:
			print("⚠️ Evidence inventory access denied - bedroom cutscene not completed")
		elif in_cutscene:
			print("⚠️ Evidence inventory access blocked during cutscene (except line 12)")
		else:
			toggle_evidence_inventory()
			get_viewport().set_input_as_handled()
			print("📋 Evidence inventory toggled via TAB (bedroom cutscene completed)")
	
	# Handle closing the evidence inventory with ESC
	if is_visible and event.is_action_pressed("ui_cancel"):
		hide_evidence_inventory()
		get_viewport().set_input_as_handled()

# Hover and click functions for evidence slots
func _on_evidence_slot_hover(evidence_index: int, is_hovering: bool):
	"""Handle evidence slot hover effects"""
	if evidence_index < evidence_slots.size():
		var evidence_slot = evidence_slots[evidence_index]
		if is_hovering:
			# Hover effect - slightly brighten
			evidence_slot.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			# Normal state
			evidence_slot.modulate = Color.WHITE

func _on_evidence_tab_hover(is_hovering: bool):
	"""Handle evidence tab hover effects"""
	if evidence_tab:
		if is_hovering:
			evidence_tab.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			evidence_tab.modulate = Color.WHITE

func _on_settings_tab_hover(is_hovering: bool):
	"""Handle settings tab hover effects"""
	if settings_tab:
		if is_hovering:
			settings_tab.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			settings_tab.modulate = Color.WHITE

func _on_main_bg_hover(is_hovering: bool):
	"""Handle main background hover effects"""
	if main_bg:
		if is_hovering:
			main_bg.modulate = Color(1.1, 1.1, 1.1, 1.0)
		else:
			main_bg.modulate = Color.WHITE

# Click functions for tabs and background
func _on_evidence_tab_clicked(event: InputEvent):
	"""Handle evidence tab click"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("📋 Evidence tab clicked")

func _on_settings_tab_clicked(event: InputEvent):
	"""Handle settings tab click"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("📋 Settings tab clicked")

func _on_main_bg_clicked(event: InputEvent):
	"""Handle main background click"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("📋 Main background clicked")
