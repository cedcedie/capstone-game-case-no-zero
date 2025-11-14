extends CanvasLayer

# Signal for settings access
signal settings
signal settings_press

# References
@onready var ui_container = $UIContainer
@onready var evidence_tab: Node = null
@onready var settings_tab: Node = null
@onready var glossary_content_bg: NinePatchRect = null

var is_visible = false
var glossary_visible = false
var just_closed = false  # Flag to prevent Evidence Inventory from opening when Settings closes

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
	
	# Setup button connections
	_setup_buttons()
	

func _get_ui_references():
	"""Get references to UI elements"""
	if ui_container.has_node("EvidenceTab/Button"):
		evidence_tab = ui_container.get_node("EvidenceTab/Button")
	if ui_container.has_node("SettingsTab/Button"):
		settings_tab = ui_container.get_node("SettingsTab/Button")
	glossary_content_bg = ui_container.get_node("GlossaryContentBG")

func _setup_buttons():
	"""Setup button connections - icons are no longer clickable"""
	# Icons are now non-interactive - only for visual indication
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
		# Check if this scene has cutscene_played property and it's false
		if "cutscene_played" in current_scene and not current_scene.cutscene_played:
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

func _on_glossary_button_pressed():
	"""Show glossary when glossary button is pressed"""
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
