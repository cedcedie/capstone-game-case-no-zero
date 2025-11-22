extends CanvasLayer

# Signal for settings access
signal settings
signal settings_press

# References
@onready var ui_container = $UIContainer
@onready var evidence_tab: Node = null
@onready var settings_tab: Node = null
@onready var glossary_content_bg: NinePatchRect = null
@onready var glossary_list: VBoxContainer = null

var is_visible = false
var glossary_visible = false
var just_closed = false  # Flag to prevent Evidence Inventory from opening when Settings closes
var glossary_data: Dictionary = {}

# Audio player for UI sounds
var open_player: AudioStreamPlayer = null
var close_player: AudioStreamPlayer = null

func _ready():
	"""Initialize the settings UI"""
	# Start completely hidden - only show when Settings tab is clicked from Evidence Inventory
	hide()
	is_visible = false
	
	# Setup audio players for UI sounds
	open_player = AudioStreamPlayer.new()
	open_player.stream = load("res://assets/audio/sfx/SoupTonic UI1 SFX Pack 1 - ogg/SFX_UI_OpenMenu.ogg")
	open_player.bus = "SFX"
	add_child(open_player)
	
	close_player = AudioStreamPlayer.new()
	close_player.stream = load("res://assets/audio/sfx/SoupTonic UI1 SFX Pack 1 - ogg/SFX_UI_CloseMenu.ogg")
	close_player.bus = "SFX"
	add_child(close_player)
	
	# Get UI references
	_get_ui_references()
	
	# Load glossary data
	_load_glossary_data()
	
	# Setup button connections
	_setup_buttons()
	

func _get_ui_references():
	"""Get references to UI elements"""
	# Get the tab nodes directly (they're NinePatchRect, not buttons)
	# EvidenceTab might be in a different location, check both
	if ui_container.has_node("EvidenceTab"):
		evidence_tab = ui_container.get_node("EvidenceTab")
	elif ui_container.has_node("EvidenceBoxDesvriptionBG/EvidenceTab"):
		evidence_tab = ui_container.get_node("EvidenceBoxDesvriptionBG/EvidenceTab")
	
	if ui_container.has_node("SettingsTab"):
		settings_tab = ui_container.get_node("SettingsTab")
	
	if ui_container.has_node("GlossaryContentBG"):
		glossary_content_bg = ui_container.get_node("GlossaryContentBG")
		if glossary_content_bg.has_node("ScrollContainer/GlossaryList"):
			glossary_list = glossary_content_bg.get_node("ScrollContainer/GlossaryList")

func _setup_buttons():
	"""Setup button connections and tab interactions"""
	# Setup tab interactions (hover and click)
	_setup_tab_interactions()

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
	"""Handle evidence tab hover effect in settings view"""
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
	"""Handle settings tab hover effect in settings view"""
	if not settings_tab:
		return
	
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
	"""Handle evidence tab click in settings view"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Hide glossary if visible
		if glossary_visible:
			hide_glossary()
		
		# Clicked evidence tab - switch to evidence inventory
		if has_node("/root/EvidenceInventorySettings"):
			var evidence_ui = get_node("/root/EvidenceInventorySettings")
			if not evidence_ui.is_visible:
				# We're in settings, switch to evidence
				hide_settings()
				evidence_ui.show_evidence_inventory()
				print("📋 Switched from Settings to Evidence Inventory")

func _on_settings_tab_input(event: InputEvent):
	"""Handle settings tab click in settings view"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Clicked settings tab - already in settings, do nothing or refresh
		pass

func show_settings():
	"""Show settings with smooth animation"""
	if not is_visible:
		# Play open sound
		if open_player:
			open_player.play()
		
		# Make sure Evidence Inventory is hidden before showing Settings
		if has_node("/root/EvidenceInventorySettings"):
			var evidence_ui = get_node("/root/EvidenceInventorySettings")
			if evidence_ui.is_visible:
				await evidence_ui.hide_evidence_inventory()
		
		is_visible = true
		show()
		if ui_container:
			ui_container.modulate = Color.TRANSPARENT
			ui_container.scale = Vector2(0.1, 0.1)
			ui_container.pivot_offset = ui_container.size / 2
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(ui_container, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
			tween.tween_property(ui_container, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func hide_settings():
	"""Hide settings with smooth animation"""
	if is_visible:
		# Play close sound
		if close_player:
			close_player.play()
		is_visible = false
		if ui_container:
			ui_container.pivot_offset = ui_container.size / 2
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(ui_container, "modulate", Color.TRANSPARENT, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
			tween.tween_property(ui_container, "scale", Vector2(0.1, 0.1), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			await tween.finished
		hide()

# Tab press functions removed - icons are no longer clickable

func _input(event):
	"""Handle input for opening/closing settings"""
	
	# Check if we're in blocked scenes (main_menu, chapter_menu, intro_story)
	var in_blocked_scene = false
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_name = current_scene.name.to_lower()
		if "introstory" in scene_name or "mainmenu" in scene_name or "chaptermenu" in scene_name:
			in_blocked_scene = true
	
	# Check if we're in a cutscene (any scene with cutscene_played = false)
	var in_cutscene = false
	if current_scene and current_scene.has_method("_input"):
		# Special case: Allow settings/glossary in courtroom scene
		var scene_name = current_scene.name.to_lower()
		if "courtroom" in scene_name:
			in_cutscene = false  # Allow settings/glossary in courtroom
		# Check if this scene has cutscene_played property and it's false
		elif "cutscene_played" in current_scene and not current_scene.cutscene_played:
			in_cutscene = true
		
		# Check for Tween and AnimationPlayer cutscenes (but not in courtroom)
		if "courtroom" not in scene_name:
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
	
	# Check if we're in a menu scene (ESC not allowed) - separate from blocked scenes
	var in_menu_scene = false
	if current_scene:
		var scene_name = current_scene.name.to_lower()
		if "main_menu" in scene_name or "chapter_menu" in scene_name:
			in_menu_scene = true
	
	# TAB is handled by EvidenceInventorySettings, not here
	
	# Handle opening/closing the settings with ESC
	if event.is_action_pressed("ui_cancel"):
		if in_blocked_scene:
			# Don't consume input - let it be handled by other systems
			return
		elif in_cutscene:
			# Don't consume input - let it be handled by other systems
			return
		
		if is_visible:
			# If settings is visible, close it
			hide_settings()
			settings.emit()  # Emit settings signal
			settings_press.emit()  # Emit settings_press signal
		else:
			# If settings is not visible, show it
			show_settings()
			settings_press.emit()  # Emit settings_press signal
		
		get_viewport().set_input_as_handled()

# Hover functions removed - icons are no longer interactive

func _load_glossary_data():
	"""Load glossary data from JSON file"""
	var file = FileAccess.open("res://data/glossary/legal_terms.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			glossary_data = json.data
			print("📚 Glossary data loaded: ", glossary_data.get("terms", []).size(), " terms")
		else:
			print("⚠️ Failed to parse glossary JSON")
	else:
		print("⚠️ Failed to load glossary JSON file")

func _get_available_glossary_terms() -> Array:
	"""Get glossary terms that are unlocked based on checkpoints"""
	if not CheckpointManager:
		return []
	
	var available_terms = []
	var terms = glossary_data.get("terms", [])
	
	for term in terms:
		var unlock_checkpoint = term.get("unlocks_after", "")
		if unlock_checkpoint == "":
			# No checkpoint required, always available
			available_terms.append(term)
		else:
			# Check if checkpoint exists by matching enum keys
			var checkpoint_found = false
			for checkpoint_type in CheckpointManager.CheckpointType.values():
				var checkpoint_name = CheckpointManager.CheckpointType.keys()[checkpoint_type]
				if checkpoint_name == unlock_checkpoint:
					if CheckpointManager.has_checkpoint(checkpoint_type):
						available_terms.append(term)
						checkpoint_found = true
					break
			
			# If checkpoint not found in enum, check by string name in checkpoints dict
			if not checkpoint_found:
				# Try to find checkpoint by string matching in checkpoints dictionary
				if CheckpointManager.checkpoints.has(unlock_checkpoint):
					available_terms.append(term)
	
	return available_terms

func _populate_glossary_list():
	"""Populate the glossary list with available terms"""
	if not glossary_list:
		return
	
	# Clear existing items
	for child in glossary_list.get_children():
		child.queue_free()
	
	var available_terms = _get_available_glossary_terms()
	
	if available_terms.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No glossary terms available yet."
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.visible_characters = -1  # Show all characters immediately
		glossary_list.add_child(empty_label)
		return
	
	for term in available_terms:
		var term_container = VBoxContainer.new()
		term_container.add_theme_constant_override("separation", 5)
		term_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Term label (bold)
		var term_label = Label.new()
		var term_text = term.get("label", "Unknown Term")
		term_label.text = term_text
		term_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
		term_label.add_theme_font_size_override("font_size", 14)
		term_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		term_label.clip_contents = true  # Clip to prevent overflow
		term_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		term_label.visible_characters = -1  # Show all characters immediately
		term_container.add_child(term_label)
		
		# Description
		var desc_label = Label.new()
		var desc_text = term.get("description", "")
		desc_label.text = desc_text
		desc_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.clip_contents = true  # Clip to prevent overflow
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.visible_characters = -1  # Show all characters immediately
		term_container.add_child(desc_label)
		
		# Citation
		var citation_label = Label.new()
		var citation_text = "Citation: " + term.get("citation", "")
		citation_label.text = citation_text
		citation_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		citation_label.add_theme_font_size_override("font_size", 10)
		citation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		citation_label.clip_contents = true  # Clip to prevent overflow
		citation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		citation_label.visible_characters = -1  # Show all characters immediately
		term_container.add_child(citation_label)
		
		# Separator
		var separator = HSeparator.new()
		separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		term_container.add_child(separator)
		
		glossary_list.add_child(term_container)

func _on_glossary_button_pressed():
	"""Show glossary when glossary button is pressed"""
	_populate_glossary_list()
	show_glossary()

func _on_glossary_exit_pressed():
	"""Hide glossary when exit button is pressed"""
	hide_glossary()

func show_glossary():
	"""Show glossary with smooth animation"""
	if not glossary_visible:
		glossary_visible = true
		if glossary_content_bg:
			glossary_content_bg.visible = true
			glossary_content_bg.modulate = Color.TRANSPARENT
			glossary_content_bg.scale = Vector2(0.1, 0.1)
			glossary_content_bg.pivot_offset = glossary_content_bg.size / 2
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(glossary_content_bg, "modulate", Color(0.98, 0.96, 0.9, 1), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
			tween.tween_property(glossary_content_bg, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func hide_glossary():
	"""Hide glossary with smooth animation"""
	if glossary_visible:
		# Play close sound
		if close_player:
			close_player.play()
		glossary_visible = false
		if glossary_content_bg:
			glossary_content_bg.pivot_offset = glossary_content_bg.size / 2
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(glossary_content_bg, "modulate", Color.TRANSPARENT, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
			tween.tween_property(glossary_content_bg, "scale", Vector2(0.1, 0.1), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			await tween.finished
			glossary_content_bg.visible = false
