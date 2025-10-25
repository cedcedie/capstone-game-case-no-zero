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

# Evidence system with 6 evidence types and proper signals
signal evidence_collected(evidence_id: String)
signal evidence_displayed(evidence_id: String)
signal evidence_inventory_opened()
signal evidence_inventory_closed()

# Evidence mapping: Evidence1-6 to evidence IDs
var evidence_mapping: Array = [
	"broken_body_cam",    # Evidence1
	"logbook",            # Evidence2  
	"handwriting_sample", # Evidence3
	"radio_log",          # Evidence4
	"autopsy_report",     # Evidence5
	"leos_notebook"       # Evidence6
]

# Evidence textures - preload them for better performance
var evidence_textures: Dictionary = {
	"broken_body_cam": preload("res://assets/sprites/evidence/broken_body_cam_evidence.png"),
	"logbook": preload("res://assets/sprites/evidence/logbook_evidence.png"),
	"handwriting_sample": preload("res://assets/sprites/evidence/handwriting_sample_evidence.png"),
	"radio_log": preload("res://assets/sprites/evidence/radio_log_evidence.png"),
	"autopsy_report": preload("res://assets/sprites/evidence/autopsy_evidence.png"),
	"leos_notebook": preload("res://assets/sprites/evidence/leos_notebook_evidence.png")
}

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

func show_evidence_inventory():
	"""Show the evidence inventory UI with smooth fade animation from center"""
	if not is_visible:
		# Make sure Settings is hidden before showing Evidence Inventory
		if has_node("/root/Settings"):
			var settings_ui = get_node("/root/Settings")
			if settings_ui.is_visible:
				await settings_ui.hide_settings()
		
		is_visible = true
		show()
		
		# Emit signal
		evidence_inventory_opened.emit()
		print("📋 Evidence inventory opened")
		
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
		
		# Check if we're in evidence collection phase and disable Settings tab
		_update_settings_tab_state()
		
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
		var fade_tween = create_tween()
		fade_tween.set_parallel(true)  # Allow multiple properties to animate simultaneously
		
		# Fade out
		fade_tween.tween_property(ui_container, "modulate", Color.TRANSPARENT, 0.4)
		fade_tween.set_ease(Tween.EASE_IN)
		fade_tween.set_trans(Tween.TRANS_QUART)
		
		# Scale down to center
		fade_tween.tween_property(ui_container, "scale", Vector2(0.1, 0.1), 0.4)
		fade_tween.set_ease(Tween.EASE_IN)
		fade_tween.set_trans(Tween.TRANS_BACK)
		
		await fade_tween.finished
	
	# Emit signal
	evidence_inventory_closed.emit()
	print("📋 Evidence inventory closed")
	
	hide()

func toggle_evidence_inventory():
	"""Toggle the evidence inventory UI"""
	if is_visible:
		hide_evidence_inventory()
	else:
		# Also hide Settings if it's visible (unified system)
		if has_node("/root/Settings"):
			var settings_ui = get_node("/root/Settings")
			if settings_ui.is_visible:
				settings_ui.hide_settings()
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
	

func _setup_evidence_slots():
	"""Setup evidence slots with click detection and hover effects"""
	var evidence_list_bg = ui_container.get_node("EvidenceBoxListBG")
	
	# Get evidence slots (Evidence1 through Evidence6 only)
	for i in range(1, 7):  # Only 6 evidence slots
		var evidence_slot = evidence_list_bg.get_node_or_null("Evidence" + str(i))
		if evidence_slot:
			evidence_slots.append(evidence_slot)
			
			# Get the button child for click detection
			var button = evidence_slot.get_node_or_null("Button")
			if button:
				button.pressed.connect(_on_evidence_slot_pressed.bind(i - 1))  # Use 0-based index
				button.mouse_entered.connect(_on_evidence_slot_hover.bind(i - 1, true))
				button.mouse_exited.connect(_on_evidence_slot_hover.bind(i - 1, false))
				print("📋 Evidence slot", i, "connected to evidence ID:", evidence_mapping[i-1])

func _initialize_evidence_visibility():
	"""Initialize evidence visibility - hide all evidence initially"""
	for i in range(evidence_slots.size()):
		evidence_slots[i].visible = false

func _on_evidence_slot_pressed(evidence_index: int):
	"""Handle evidence slot button press"""
	_select_evidence(evidence_index)

func _select_evidence(evidence_index: int):
	"""Select and display evidence"""
	# Check if this evidence slot is visible (has collected evidence)
	if evidence_index >= collected_evidence.size():
		return
	
	# Get the evidence ID from the mapping
	var evidence_id = evidence_mapping[evidence_index]
	if evidence_id in evidence_data.evidence:
		current_evidence = evidence_id
		_display_evidence(evidence_id)
		print("📋 Evidence selected:", evidence_id, "from slot", evidence_index + 1)
	else:
		print("⚠️ Evidence not found in data:", evidence_id)

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
	else:
		evidence_display.visible = false
	
	# Emit signal for evidence display
	evidence_displayed.emit(evidence_id)
	print("📋 Evidence displayed:", evidence_id)
	
	# Add click detection for detailed examination
	_setup_evidence_click_detection(evidence_id)

func _get_evidence_texture(evidence_id: String) -> Texture2D:
	"""Get the texture for evidence based on its ID"""
	if evidence_textures.has(evidence_id):
		return evidence_textures[evidence_id]
	else:
		print("⚠️ Evidence texture not found for:", evidence_id)
		return null

func add_evidence(evidence_id: String):
	"""Add new evidence to the collection and emit signal"""
	if evidence_id not in collected_evidence:
		collected_evidence.append(evidence_id)
		
		# Show the corresponding evidence slot
		var slot_index = collected_evidence.size() - 1
		if slot_index < evidence_slots.size():
			evidence_slots[slot_index].visible = true
			
			# If this is the first evidence, automatically select it
			if collected_evidence.size() == 1:
				_select_evidence(0)
		
		# Emit signal for evidence collection
		evidence_collected.emit(evidence_id)
		print("📋 Evidence collected:", evidence_id, "Total evidence:", collected_evidence.size())

func _update_settings_tab_state():
	"""Update Settings tab state based on evidence collection phase"""
	var current_scene = get_tree().current_scene
	var in_evidence_collection = current_scene and "evidence_collection_phase" in current_scene and current_scene.evidence_collection_phase
	
	if settings_tab:
		# Get the settings icon for grouped animation
		var settings_icon = settings_tab.get_node_or_null("SettingsIcon")
		
		if in_evidence_collection:
			# Gray out both the Settings tab and icon during evidence collection
			settings_tab.modulate = Color(0.5, 0.5, 0.5, 1.0)
			if settings_icon:
				settings_icon.modulate = Color(0.5, 0.5, 0.5, 1.0)
		else:
			# Normal color when not in evidence collection
			settings_tab.modulate = Color.WHITE
			if settings_icon:
				settings_icon.modulate = Color.WHITE

func _find_player_camera():
	"""Find the player's camera for positioning"""
	var scene_root = get_tree().current_scene
	if scene_root:
		var player = scene_root.get_node_or_null("PlayerM")
		if not player:
			player = scene_root.get_node_or_null("Player")
		
		if player:
			player_camera = player.get_node_or_null("Camera2D")

func _input(event):
	"""Handle input for evidence inventory"""
	# Check if we're in blocked scenes (main_menu, chapter_menu, intro_story)
	var in_blocked_scene = false
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_name = current_scene.name.to_lower()
		if "introstory" in scene_name or "mainmenu" in scene_name or "chaptermenu" in scene_name:
			in_blocked_scene = true
	
	# Check if we're in a cutscene - comprehensive detection for all scenes
	var in_cutscene = false
	var current_scene_name = ""
	
	if current_scene:
		current_scene_name = current_scene.name.to_lower()
		
		# Check for cutscene indicators in all target scenes
		if current_scene.has_method("_input"):
			# Check if this scene has cutscene_played property and it's false
			if "cutscene_played" in current_scene and not current_scene.cutscene_played:
				in_cutscene = true
		
		# Check for specific scene cutscene states
		if "bedroom" in current_scene_name or "police_lobby" in current_scene_name or "lower_level" in current_scene_name or "barangay" in current_scene_name:
			# Check for cutscene flags in these specific scenes
			if "in_cutscene" in current_scene and current_scene.in_cutscene:
				in_cutscene = true
			elif "cutscene_active" in current_scene and current_scene.cutscene_active:
				in_cutscene = true
			elif "dialogue_active" in current_scene and current_scene.dialogue_active:
				in_cutscene = true
		
		# Check for Tween and AnimationPlayer cutscenes
		var tweens = get_tree().get_nodes_in_group("tween")
		for tween in tweens:
			if tween.is_valid() and tween.is_running():
				in_cutscene = true
				break
		
		var animation_players = get_tree().get_nodes_in_group("animation_player")
		for anim_player in animation_players:
			if anim_player.is_playing():
				in_cutscene = true
				break
		
		# Check for any running animations in the current scene
		var scene_animations = current_scene.get_tree().get_nodes_in_group("animation")
		for anim in scene_animations:
			if anim.is_playing():
				in_cutscene = true
				break
		
		# Special case: check if we're in evidence collection phase (line 12 exception)
		if "evidence_collection_phase" in current_scene and current_scene.evidence_collection_phase:
			in_cutscene = false  # Allow during evidence collection phase
	
	# Check if we're in a menu scene (TAB not allowed) - separate from blocked scenes
	var in_menu_scene = false
	if current_scene:
		var scene_name = current_scene.name.to_lower()
		if "main_menu" in scene_name or "chapter_menu" in scene_name:
			in_menu_scene = true
	
	# Only allow evidence inventory access (not in blocked scenes)
	if event.is_action_pressed("evidence_inventory"):
		if in_blocked_scene:
			pass  # Blocked
		elif in_cutscene:
			pass  # Blocked during cutscene
		else:
			# Check if Settings is visible or just closed - if so, don't toggle Evidence
			var settings_ui = get_node_or_null("/root/Settings")
			if settings_ui and (settings_ui.is_visible or settings_ui.just_closed):
				# Settings will handle its own hiding via its _input, or just closed
				get_viewport().set_input_as_handled()
			else:
				# Toggle Evidence Inventory normally
				toggle_evidence_inventory()
				get_viewport().set_input_as_handled()
	
	# Handle closing the evidence inventory with ESC
	if is_visible and event.is_action_pressed("ui_cancel"):
		hide_evidence_inventory()
		get_viewport().set_input_as_handled()

# Hover and click functions for evidence slots
func _on_evidence_slot_hover(evidence_index: int, is_hovering: bool):
	"""Handle evidence slot hover effects"""
	if evidence_index < evidence_slots.size():
		var evidence_slot = evidence_slots[evidence_index]
		# Only show hover if this slot is visible (has collected evidence)
		if not evidence_slot.visible:
			return
		
		if is_hovering:
			# Hover effect - brighten and scale up
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(evidence_slot, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.1)
			tween.tween_property(evidence_slot, "scale", Vector2(1.1, 1.1), 0.1)
		else:
			# Normal state
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(evidence_slot, "modulate", Color.WHITE, 0.1)
			tween.tween_property(evidence_slot, "scale", Vector2.ONE, 0.1)

# Tab hover functions removed - icons are no longer interactive

# Tab click functions removed - icons are no longer clickable


func _setup_evidence_click_detection(evidence_id: String):
	"""Setup click detection for detailed evidence examination"""
	# Connect the evidence display to click detection
	if evidence_display:
		# Disconnect any existing connections first
		if evidence_display.gui_input.is_connected(_on_evidence_display_clicked):
			evidence_display.gui_input.disconnect(_on_evidence_display_clicked)
		
		# Connect the new signal
		evidence_display.gui_input.connect(_on_evidence_display_clicked.bind(evidence_id))

func _on_evidence_display_clicked(event: InputEvent, evidence_id: String):
	"""Handle clicks on evidence display for detailed examination"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_evidence_details(evidence_id)

func _show_evidence_details(evidence_id: String):
	"""Show detailed evidence information in a popup or expanded view"""
	var evidence_info = evidence_data.evidence[evidence_id]
	
	if "details" in evidence_info:
		var details = evidence_info.details
		var detail_text = ""
		
		# Build detailed information text
		for key in details:
			detail_text += key + ": " + details[key] + "\n\n"
		
		# Show detailed information (you can modify this to show in a popup or expand the description)
		evidence_description.text = evidence_info.description + "\n\n" + "=== DETALYADONG IMPORMASYON ===\n\n" + detail_text
		
		print("🔍 Detailed examination of " + evidence_info.name + ":")
		for key in details:
			print("  " + key + ": " + details[key])
	else:
		print("⚠️ No detailed information available for " + evidence_info.name)

func _on_evidence_description_gui_input(event: InputEvent) -> void:
	pass # Replace with function body.
