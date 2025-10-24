extends CanvasLayer

# Signal for settings access
signal settings
signal settings_press

# References
@onready var ui_container = $UIContainer
@onready var evidence_tab: Node = null
@onready var settings_tab: Node = null

var is_visible = false
var just_closed = false  # Flag to prevent Evidence Inventory from opening when Settings closes

func _ready():
	"""Initialize the settings UI"""
	# Start completely hidden - only show when Settings tab is clicked from Evidence Inventory
	hide()
	is_visible = false
	
	# Get UI references
	_get_ui_references()
	
	# Setup button connections
	_setup_buttons()
	
	print("📋 Settings UI initialized (hidden by default)")

func _get_ui_references():
	"""Get references to UI elements"""
	evidence_tab = ui_container.get_node("EvidenceTab/Button")
	settings_tab = ui_container.get_node("SettingsTab/Button")

func _setup_buttons():
	"""Setup button connections - icons are no longer clickable"""
	# Icons are now non-interactive - only for visual indication
	pass

func show_settings():
	"""Show settings with smooth animation"""
	if not is_visible:
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
		print("📋 Settings: Shown with smooth center scale animation")

func hide_settings():
	"""Hide settings with smooth animation"""
	if is_visible:
		is_visible = false
		if ui_container:
			ui_container.pivot_offset = ui_container.size / 2
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(ui_container, "modulate", Color.TRANSPARENT, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
			tween.tween_property(ui_container, "scale", Vector2(0.1, 0.1), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			await tween.finished
		hide()
		print("📋 Settings: Hidden with smooth center scale animation")

# Tab press functions removed - icons are no longer clickable

func _input(event):
	"""Handle input for opening/closing settings"""
	print("🔍 DEBUG Settings: _input called with event: ", event)
	
	# Check if we're in blocked scenes (main_menu, chapter_menu, intro_story)
	var in_blocked_scene = false
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_name = current_scene.name.to_lower()
		print("🔍 DEBUG Settings: Current scene name: ", scene_name)
		if "introstory" in scene_name or "mainmenu" in scene_name or "chaptermenu" in scene_name:
			in_blocked_scene = true
			print("🔍 DEBUG Settings: In blocked scene: ", scene_name)
	
	# Check if we're in a cutscene (any scene with cutscene_played = false)
	var in_cutscene = false
	if current_scene and current_scene.has_method("_input"):
		# Check if this scene has cutscene_played property and it's false
		if "cutscene_played" in current_scene and not current_scene.cutscene_played:
			in_cutscene = true
		
		# Check for Tween and AnimationPlayer cutscenes
		var tweens = get_tree().get_nodes_in_group("tween")
		for tween in tweens:
			if tween.is_valid() and tween.is_running():
				in_cutscene = true
				print("📋 Settings: Cutscene detected - Tween is running")
				break
		
		var animation_players = get_tree().get_nodes_in_group("animation_player")
		for anim_player in animation_players:
			if anim_player.is_playing():
				in_cutscene = true
				print("📋 Settings: Cutscene detected - AnimationPlayer is playing")
				break
		
		# Check for any running animations in the current scene
		var scene_animations = current_scene.get_tree().get_nodes_in_group("animation")
		for anim in scene_animations:
			if anim.is_playing():
				in_cutscene = true
				print("📋 Settings: Cutscene detected - Animation is playing")
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
			print("📋 Menu scene detected - ESC blocked:", scene_name)
	
	# TAB is handled by EvidenceInventorySettings, not here
	
	# Handle opening/closing the settings with ESC
	if event.is_action_pressed("ui_cancel"):
		print("🔍 DEBUG Settings: ESC pressed!")
		if in_blocked_scene:
			print("⚠️ Settings ESC blocked - in blocked scene")
			# Don't consume input - let it be handled by other systems
			return
		elif in_cutscene:
			print("⚠️ Settings ESC blocked - in cutscene")
			# Don't consume input - let it be handled by other systems
			return
		
		print("🔍 DEBUG Settings: ESC allowed, is_visible = ", is_visible)
		if is_visible:
			# If settings is visible, close it
			hide_settings()
			settings.emit()  # Emit settings signal
			settings_press.emit()  # Emit settings_press signal
			print("📋 Settings closed via ESC and signals emitted")
		else:
			# If settings is not visible, show it
			show_settings()
			settings_press.emit()  # Emit settings_press signal
			print("📋 Settings shown via ESC and signal emitted")
		
		get_viewport().set_input_as_handled()

# Hover functions removed - icons are no longer interactive
