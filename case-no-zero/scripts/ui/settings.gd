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
	
	# Check cutscene conditions (same as Evidence Inventory)
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
	
	# Check if we're in a menu scene (ESC not allowed)
	var in_menu_scene = false
	if current_scene:
		var scene_name = current_scene.name.to_lower()
		if "intro_story" in scene_name or "main_menu" in scene_name or "chapter_menu" in scene_name:
			in_menu_scene = true
			print("📋 Menu scene detected - ESC blocked:", scene_name)
	
	# Handle closing the settings with TAB (evidence_inventory action)
	if event.is_action_pressed("evidence_inventory"):
		# Check if TAB action is allowed
		if not bedroom_cutscene_completed:
			print("⚠️ Settings TAB blocked - bedroom cutscene not completed")
			# Don't consume input - let it be handled by other systems
			return
		elif in_menu_scene:
			print("⚠️ Settings TAB blocked - in menu scene")
			# Don't consume input - let it be handled by other systems
			return
		elif in_cutscene:
			print("⚠️ Settings TAB blocked - in cutscene (except line 12)")
			# Don't consume input - let it be handled by other systems
			return
		
		# All checks passed - just close Settings (don't show Evidence Inventory)
		just_closed = true
		hide_settings()
		get_viewport().set_input_as_handled()
		print("📋 Settings closed via TAB (unified hide)")
		
		# Reset flag after a short delay to allow Evidence Inventory to check it
		await get_tree().create_timer(0.1).timeout
		just_closed = false
	
	# Handle opening/closing the settings with ESC
	if event.is_action_pressed("ui_cancel"):
		if in_menu_scene:
			print("⚠️ Settings ESC blocked - in menu scene")
			# Don't consume input - let it be handled by other systems
			return
		
		# Check if bedroom cutscene is completed (same as TAB)
		if not bedroom_cutscene_completed:
			print("⚠️ Settings ESC blocked - bedroom cutscene not completed")
			# Don't consume input - let it be handled by other systems
			return
		elif in_cutscene:
			print("⚠️ Settings ESC blocked - in cutscene")
			# Don't consume input - let it be handled by other systems
			return
		
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
