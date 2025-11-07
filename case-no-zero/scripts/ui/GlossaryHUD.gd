extends CanvasLayer

var button: Button = null

func _ready() -> void:
	# Ensure this HUD draws above other UI and receives input even during pause
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Create a small always-on-top button for opening the Glossary globally
	button = Button.new()
	button.text = "Glossary"
	button.focus_mode = Control.FOCUS_ALL
	button.flat = true
	button.size = Vector2(96, 28)
	# Top-left with margin
	button.position = Vector2(8, 8)
	button.z_index = 100
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(button)
	button.pressed.connect(_on_button_pressed)

	# React to scene changes to toggle visibility in menus/cutscenes
	var tree := get_tree()
	if tree != null:
		if tree.has_signal("current_scene_changed"):
			tree.connect("current_scene_changed", Callable(self, "_evaluate_visibility"))
		elif tree.has_signal("scene_changed"):
			tree.connect("scene_changed", Callable(self, "_evaluate_visibility"))
	_evaluate_visibility()

func _evaluate_visibility() -> void:
	var scene := get_tree().current_scene
	var show_btn := true
	if scene != null:
		var name_l := String(scene.name).to_lower()
		if "mainmenu" in name_l or "chaptermenu" in name_l or "introstory" in name_l:
			show_btn = false
		# crude cutscene detection hook used elsewhere in project
		if "cutscene_played" in scene and not scene.cutscene_played:
			show_btn = false
	button.visible = show_btn

func _on_button_pressed() -> void:
	# Delegate to Settings autoload if available
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_method("_on_glossary_pressed"):
		settings._on_glossary_pressed()
	else:
		push_warning("GlossaryHUD: Settings autoload not found or method missing")


