extends CanvasLayer

# EvidenceInventorySettings - Autoload for managing evidence and inventory UI

var is_visible: bool = false
var player_camera: Camera2D = null
var ui_container: Control = null

# Cached values for optimization
var _cached_current_scene: Node = null
var _cached_scene_name: String = ""
var _cached_in_cutscene: bool = false
var _last_scene_check_frame: int = -1

# Evidence system
var evidence_data: Dictionary = {}
var collected_evidence: Array = []
var current_evidence: String = ""
var courtroom_mode: bool = false  # Flag to track if we're in courtroom evidence selection mode

# UI References
var evidence_slots: Array = []
var evidence_display: TextureRect
var evidence_label: Label
var evidence_name: Label
var evidence_description: Label
var evidence_tab: NinePatchRect
var settings_tab: NinePatchRect

# Audio players for UI sounds
var open_player: AudioStreamPlayer = null
var close_player: AudioStreamPlayer = null

# Evidence system with 6 evidence types and proper signals
signal evidence_collected(evidence_id: String)
signal evidence_displayed(evidence_id: String)
signal evidence_inventory_opened()
signal evidence_inventory_closed()
signal evidence_selected_for_courtroom(evidence_id: String)  # New signal for courtroom evidence selection

# Evidence mapping: Evidence1-6 to evidence IDs
var evidence_mapping: Array = [
	"broken_body_cam",    # Evidence1
	"radio_log",          # Evidence2
	"logbook",            # Evidence3
	"handwriting_sample", # Evidence4
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
	
	# Setup audio players for UI sounds
	open_player = AudioStreamPlayer.new()
	open_player.stream = load("res://assets/audio/sfx/SoupTonic UI1 SFX Pack 1 - ogg/SFX_UI_OpenMenu.ogg")
	open_player.bus = "SFX"
	add_child(open_player)
	
	close_player = AudioStreamPlayer.new()
	close_player.stream = load("res://assets/audio/sfx/SoupTonic UI1 SFX Pack 1 - ogg/SFX_UI_CloseMenu.ogg")
	close_player.bus = "SFX"
	add_child(close_player)
	
	# Load evidence data
	_load_evidence_data()
	
	# Get UI references
	_get_ui_references()
	
	# Setup evidence slots
	_setup_evidence_slots()
	
	# Setup tab interactions (hover and click)
	_setup_tab_interactions()
	
	# Initially hide all evidence except the first one
	_initialize_evidence_visibility()

func show_evidence_inventory(courtroom_mode_enabled: bool = false):
	"""Show the evidence inventory UI with smooth fade animation from center"""
	courtroom_mode = courtroom_mode_enabled  # Set courtroom mode flag
	print("📋 Evidence Inventory: Showing with courtroom_mode = ", courtroom_mode, " | Evidence slots visible: ", evidence_slots.size())
	# Debug: Print which evidence slots are visible
	for i in range(evidence_slots.size()):
		if i < collected_evidence.size():
			var evidence_id = evidence_mapping[i]
			print("📋 Evidence slot ", i, " (", evidence_id, ") visible: ", evidence_slots[i].visible)
	if not is_visible:
		# Play open sound
		if open_player:
			open_player.play()
		
		# Make sure Settings is hidden before showing Evidence Inventory
		if has_node("/root/Settings"):
			var settings_ui = get_node("/root/Settings")
			if settings_ui.is_visible:
				await settings_ui.hide_settings()
			# Also hide glossary if visible
			if settings_ui.glossary_visible:
				settings_ui.hide_glossary()
		
		is_visible = true
		show()
		
		# Emit signal
		evidence_inventory_opened.emit()
		print("📋 Evidence inventory opened (courtroom_mode: ", courtroom_mode, ")")
		
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
	courtroom_mode = false  # Reset courtroom mode when hiding
	if is_visible:
		# Play close sound
		if close_player:
			close_player.play()
		
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
	# Get tabs - EvidenceTab is inside EvidenceBoxDesvriptionBG, SettingsTab is direct child
	evidence_tab = ui_container.get_node("EvidenceBoxDesvriptionBG/EvidenceTab")
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
	print("📋 _select_evidence called with index: ", evidence_index, " | collected_evidence.size(): ", collected_evidence.size())
	# Check if this evidence slot is visible (has collected evidence)
	if evidence_index >= collected_evidence.size():
		print("⚠️ Evidence index out of range!")
		return
	
	# Get the evidence ID from the mapping
	var evidence_id = evidence_mapping[evidence_index]
	print("📋 Evidence ID from mapping: ", evidence_id)
	if evidence_id in evidence_data.evidence:
		current_evidence = evidence_id
		_display_evidence(evidence_id)
		print("📋 Evidence selected:", evidence_id, "from slot", evidence_index + 1)
		
		# If in courtroom mode, ALWAYS emit signal for courtroom selection (even during dialogue)
		print("📋 Evidence selection - courtroom_mode: ", courtroom_mode, " evidence_id: ", evidence_id)
		if courtroom_mode:
			print("📋 Emitting evidence_selected_for_courtroom signal for: ", evidence_id)
			# Emit signal immediately - this should work even during dialogue
			evidence_selected_for_courtroom.emit(evidence_id)
			print("📋 Courtroom: Evidence selected for presentation:", evidence_id)
		else:
			print("⚠️ Evidence clicked but NOT in courtroom mode! courtroom_mode = ", courtroom_mode)
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
		
		# If this is the last evidence (leos_notebook), mask it as ???????????
		if evidence_id == "leos_notebook":
			# Ensure evidence data is loaded
			if evidence_data.is_empty() or not evidence_data.has("evidence"):
				_load_evidence_data()
			
			# Store original values if not already stored
			if not evidence_data.evidence.has(evidence_id):
				push_error("⚠️ Evidence data not found for: " + evidence_id)
			else:
				# Check if we need to mask it (first time adding)
				var evidence_info = evidence_data.evidence[evidence_id]
				# Only mask if it's not already masked
				if evidence_info.name != "???????????":
					# Store original values in a temporary location (we'll restore them later)
					if not has_meta("original_leos_notebook_name"):
						set_meta("original_leos_notebook_name", evidence_info.name)
						set_meta("original_leos_notebook_description", evidence_info.get("description", ""))
					
					# Mask the evidence data
					evidence_info.name = "???????????"
					evidence_info.description = "???????????"
					print("🔎 Last evidence (leos_notebook) masked as ???????????")
		
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

func _check_cutscene_state(current_scene: Node) -> bool:
	"""Check if we're in a cutscene - extracted for optimization"""
	if not current_scene:
		return false
	
	var scene_name = current_scene.name.to_lower()
	
	# Check for cutscene indicators in all target scenes
	if current_scene.has_method("_input"):
		if "cutscene_played" in current_scene and not current_scene.cutscene_played:
			return true
	
	# Check for specific scene cutscene states
	if "bedroom" in scene_name or "police_lobby" in scene_name or "lower_level" in scene_name or "barangay" in scene_name:
		if "in_cutscene" in current_scene and current_scene.in_cutscene:
			return true
		elif "cutscene_active" in current_scene and current_scene.cutscene_active:
			return true
		elif "dialogue_active" in current_scene and current_scene.dialogue_active:
			return true
	
	# Check for Tween and AnimationPlayer cutscenes (only check once per scene change)
	var tweens = get_tree().get_nodes_in_group("tween")
	for tween in tweens:
		if tween.is_valid() and tween.is_running():
			return true
	
	var animation_players = get_tree().get_nodes_in_group("animation_player")
	for anim_player in animation_players:
		if anim_player.is_playing():
			return true
	
	# Check for any running animations in the current scene
	var scene_animations = current_scene.get_tree().get_nodes_in_group("animation")
	for anim in scene_animations:
		if anim.is_playing():
			return true
	
	# Special case: check if we're in evidence collection phase (line 12 exception)
	if "evidence_collection_phase" in current_scene and current_scene.evidence_collection_phase:
		return false  # Allow during evidence collection phase
	
	return false

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
	# Cache scene checks (only update once per frame)
	var current_frame = Engine.get_process_frames()
	if _last_scene_check_frame != current_frame:
		_last_scene_check_frame = current_frame
		_cached_current_scene = get_tree().current_scene
		if _cached_current_scene:
			_cached_scene_name = _cached_current_scene.name.to_lower()
		else:
			_cached_scene_name = ""
	
	# Check if we're in blocked scenes (main_menu, chapter_menu, intro_story)
	var in_blocked_scene = false
	if _cached_current_scene:
		if "introstory" in _cached_scene_name or "mainmenu" in _cached_scene_name or "chaptermenu" in _cached_scene_name:
			in_blocked_scene = true
	
	# Check if we're in a cutscene - recalculate if scene changed, otherwise use cache
	var current_scene = get_tree().current_scene
	if _cached_current_scene != current_scene:
		_cached_in_cutscene = _check_cutscene_state(current_scene)
	
	var in_cutscene = _cached_in_cutscene
	
	# Check if we're in a menu scene (TAB not allowed) - separate from blocked scenes
	var in_menu_scene = false
	if _cached_current_scene:
		if "main_menu" in _cached_scene_name or "chapter_menu" in _cached_scene_name:
			in_menu_scene = true
	
	# Check if we're in office scene (TAB disabled throughout, even after cutscene completes)
	var in_office_scene = false
	if _cached_current_scene:
		if "office" in _cached_scene_name:
			in_office_scene = true
	
	# Only allow evidence inventory access (not in blocked scenes)
	if event.is_action_pressed("evidence_inventory"):
		if in_blocked_scene:
			pass  # Blocked
		elif in_cutscene:
			pass  # Blocked during cutscene
		elif in_office_scene:
			pass  # Blocked in office scene (even after cutscene completes)
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

func _setup_tab_interactions():
	"""Setup hover and click interactions for Evidence and Settings tabs"""
	if evidence_tab:
		# Make evidence tab interactive
		evidence_tab.mouse_filter = Control.MOUSE_FILTER_STOP
		evidence_tab.mouse_entered.connect(_on_evidence_tab_hover.bind(true))
		evidence_tab.mouse_exited.connect(_on_evidence_tab_hover.bind(false))
		evidence_tab.gui_input.connect(_on_evidence_tab_input)
	
	if settings_tab:
		# Make settings tab interactive
		settings_tab.mouse_filter = Control.MOUSE_FILTER_STOP
		settings_tab.mouse_entered.connect(_on_settings_tab_hover.bind(true))
		settings_tab.mouse_exited.connect(_on_settings_tab_hover.bind(false))
		settings_tab.gui_input.connect(_on_settings_tab_input)

func _on_evidence_tab_hover(is_hovering: bool):
	"""Handle evidence tab hover effect"""
	if not evidence_tab:
		return
	
	var tween = create_tween()
	if is_hovering:
		# Hover effect: slightly scale up and brighten
		tween.set_parallel(true)
		tween.tween_property(evidence_tab, "scale", Vector2(1.1, 1.1), 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(evidence_tab, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.15)
	else:
		# Return to normal
		tween.set_parallel(true)
		tween.tween_property(evidence_tab, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_IN)
		tween.tween_property(evidence_tab, "modulate", Color.WHITE, 0.15)

func _on_settings_tab_hover(is_hovering: bool):
	"""Handle settings tab hover effect"""
	if not settings_tab:
		return
	
	# Check if settings tab is disabled (grayed out)
	var is_disabled = settings_tab.modulate == Color(0.5, 0.5, 0.5, 1.0)
	if is_disabled:
		return  # Don't hover if disabled
	
	var tween = create_tween()
	if is_hovering:
		# Hover effect: slightly scale up and brighten
		tween.set_parallel(true)
		tween.tween_property(settings_tab, "scale", Vector2(1.1, 1.1), 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(settings_tab, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.15)
	else:
		# Return to normal
		tween.set_parallel(true)
		tween.tween_property(settings_tab, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_IN)
		tween.tween_property(settings_tab, "modulate", Color.WHITE, 0.15)

func _on_evidence_tab_input(event: InputEvent):
	"""Handle evidence tab click"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Clicked evidence tab - show evidence inventory
		if has_node("/root/Settings"):
			var settings_ui = get_node("/root/Settings")
			if settings_ui.is_visible:
				# We're in settings, switch to evidence
				show_evidence_inventory()
				print("📋 Switched from Settings to Evidence Inventory")

func _on_settings_tab_input(event: InputEvent):
	"""Handle settings tab click"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if settings tab is disabled
		var is_disabled = settings_tab.modulate == Color(0.5, 0.5, 0.5, 1.0)
		if is_disabled:
			return  # Don't allow click if disabled
		
		# Clicked settings tab - show settings
		if has_node("/root/Settings"):
			var settings_ui = get_node("/root/Settings")
			if not settings_ui.is_visible:
				# We're in evidence, switch to settings
				settings_ui.show_settings()
				print("⚙️ Switched from Evidence Inventory to Settings")


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

func set_evidence_slot_visibility(evidence_id: String, visible: bool) -> void:
	"""Set visibility of a specific evidence slot by evidence ID"""
	var evidence_index = evidence_mapping.find(evidence_id)
	if evidence_index >= 0 and evidence_index < evidence_slots.size():
		evidence_slots[evidence_index].visible = visible
		print("📋 Evidence slot visibility set: ", evidence_id, " = ", visible)
	else:
		print("⚠️ Evidence ID not found in mapping: ", evidence_id)
