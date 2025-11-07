extends CanvasLayer

# Signal for settings access
signal settings
signal settings_press

# References
@onready var ui_container = $UIContainer
@onready var evidence_tab: Node = null
@onready var settings_tab: Node = null
@onready var glossary_button: Button = null

var is_visible = false
var just_closed = false  # Flag to prevent Evidence Inventory from opening when Settings closes

# Glossary overlay state for global key handling
var glossary_overlay: CanvasLayer = null
var prev_paused_state: bool = false

func _ready():
	"""Initialize the settings UI"""
	# Ensure we still receive input callbacks while the game is paused (for glossary back key)
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if ui_container.has_node("GlossaryTab/Button"):
		glossary_button = ui_container.get_node("GlossaryTab/Button")

func _setup_buttons():
	"""Setup button connections - icons are no longer clickable"""
	# Icons are now non-interactive - only for visual indication
	if glossary_button != null and not glossary_button.is_connected("pressed", Callable(self, "_on_glossary_pressed")):
		glossary_button.pressed.connect(_on_glossary_pressed)

func _on_glossary_pressed():
	# Open the interactive glossary book scene in an overlay CanvasLayer
	var scene_path := "res://glossary/interactive_book_2d.tscn"
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_warning("Glossary: failed to load scene at " + scene_path)
		return
	var overlay := CanvasLayer.new()
	overlay.name = "GlossaryOverlay"
	# Ensure overlay keeps processing while game is paused
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	# Pause gameplay underneath and remember previous state
	var prev_paused: bool = get_tree().paused
	get_tree().paused = true
	# Save for global key handling
	glossary_overlay = overlay
	prev_paused_state = prev_paused
	# Fullscreen blur behind dim
	var blur := ColorRect.new()
	blur.name = "BlurBackground"
	blur.anchors_preset = Control.PRESET_FULL_RECT
	var blur_shader := Shader.new()
	blur_shader.code = """
	shader_type canvas_item;
	uniform float radius = 6.0; // blur radius in pixels
	void fragment() {
		vec2 tex_size = vec2(textureSize(SCREEN_TEXTURE, 0));
		vec2 uv = SCREEN_UV;
		vec4 sum = vec4(0.0);
		float samples = 0.0;
		// 9-tap simple blur
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				vec2 off = vec2(float(x), float(y)) * radius / tex_size;
				sum += texture(SCREEN_TEXTURE, uv + off);
				samples += 1.0;
			}
		}
		COLOR = sum / samples;
	}
	"""
	var blur_mat := ShaderMaterial.new()
	blur_mat.shader = blur_shader
	blur.material = blur_mat
	overlay.add_child(blur)
	# Dim background above blur
	var dim := ColorRect.new()
	dim.color = Color(0,0,0,0.5)
	dim.anchors_preset = Control.PRESET_FULL_RECT
	dim.focus_mode = Control.FOCUS_ALL
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_child(dim)
	# Ensure keyboard focus so Backspace/ESC are delivered here
	dim.call_deferred("grab_focus")
	# Instance book and center on screen
	var inst := packed.instantiate()
	overlay.add_child(inst)
	if inst is Node2D:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		# Scale book responsively: ~35% of width or ~50% of height, whichever fits
		var target_w: float = vp_size.x * 0.35
		var target_h: float = vp_size.y * 0.5
		var base_px: float = 64.0  # each frame is 64x64
		var s: float = min(target_w / base_px, target_h / base_px)
		var scale_vec: Vector2 = Vector2(s, s) * 2.0
		(inst as Node2D).scale = scale_vec
		(inst as Node2D).position = vp_size * 0.5
		(inst as Node2D).z_index = 10
	# Enlarge the in-book Back_Button (CloseButton) and route to Settings
	var close_btn := inst.get_node_or_null("Control/CloseButton")
	if close_btn and close_btn is Control:
		# Remove/disable in-book button; we'll use Backspace to close
		(close_btn as Control).visible = false
		(close_btn as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if close_btn is BaseButton:
			(close_btn as BaseButton).disabled = true
	# ESC to close via dim's GUI input
	dim.gui_input.connect(func(event):
		if event is InputEventKey and (event.is_action_pressed("ui_cancel") or event.keycode == KEY_BACKSPACE or event.physical_keycode == KEY_BACKSPACE):
			_close_glossary_overlay()
		)
	get_tree().root.add_child(overlay)
	glossary_overlay = overlay
	print("📖 Glossary opened")

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

# Close glossary overlay regardless of focus
func _unhandled_input(event: InputEvent) -> void:
	if glossary_overlay == null:
		return
	if event is InputEventKey:
		var ek := event as InputEventKey
		if ek.is_action_pressed("ui_cancel") or ek.keycode == KEY_BACKSPACE or ek.physical_keycode == KEY_BACKSPACE:
			_close_glossary_overlay()
			get_viewport().set_input_as_handled()

func _close_glossary_overlay() -> void:
	if glossary_overlay == null:
		return
	if has_node("/root/Settings"):
		var s = get_node("/root/Settings")
		if s.has_method("show_settings"):
			s.show_settings()
	get_tree().paused = prev_paused_state
	if is_instance_valid(glossary_overlay):
		glossary_overlay.queue_free()
	glossary_overlay = null

# No global key handler needed; dim grabs focus and handles Backspace/ESC
