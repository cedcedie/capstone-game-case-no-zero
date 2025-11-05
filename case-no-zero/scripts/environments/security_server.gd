extends Node2D

var anim_player: AnimationPlayer = null
var player_node: Node = null
var dialogue_lines: Array[Dictionary] = []
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var resume_on_next: bool = false
var cutscene_active: bool = false

func _ready() -> void:
	print("🎬 Security server: _ready() started")
	# Prepare cutscene: disable player, load dialogue, and optionally auto-start animation
	_setup_fade()
	print("🎬 Fade setup complete")
	player_node = _find_player()
	print("🎬 Player found: ", player_node != null, " - Node: ", player_node)
	if player_node != null:
		print("🎬 Player has disable_movement method: ", player_node.has_method("disable_movement"))
	_set_player_active(false)
	_load_dialogue_if_available()
	print("🎬 Dialogue loaded: ", dialogue_lines.size(), " lines")
	# Connect DialogueUI next_pressed signal to resume animation
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_signal("next_pressed") and not dui.next_pressed.is_connected(_on_dialogue_next):
		dui.next_pressed.connect(_on_dialogue_next)
	
	# Find AnimationPlayer (could be child or sibling)
	var root_scene := get_tree().current_scene
	if root_scene != null:
		anim_player = root_scene.get_node_or_null("AnimationPlayer")
		if anim_player == null:
			# Try as child of this node
			anim_player = get_node_or_null("AnimationPlayer")
		if anim_player == null:
			# Try recursive search
			var found := root_scene.find_child("AnimationPlayer", true, false)
			if found is AnimationPlayer:
				anim_player = found
	
	# Start cutscene for first time
	print("🎬 Starting fade in...")
	cutscene_active = true
	show_environment_and_characters()
	await fade_in()
	print("🎬 Fade in complete, checking animation...")
	if anim_player:
		print("🎬 AnimationPlayer found, available animations: ", anim_player.get_animation_list())
		# Play the first available animation or a specific one
		if anim_player.get_animation_list().size() > 0:
			var first_anim = anim_player.get_animation_list()[0]
			print("🎬 Playing first available animation: ", first_anim)
			anim_player.play(first_anim)
		else:
			print("⚠️ No animations found in AnimationPlayer")
	else:
		print("⚠️ AnimationPlayer node not found!")

func end_cutscene() -> void:
	# Dramatic fade out before scene transition
	print("🎬 Cutscene ending - dramatic fade out...")
	await dramatic_fade_out(2.0)
	
	# Hide dialogue UI during fade
	_hide_dialogue_ui()
	
	# Set checkpoint (add checkpoint here if needed)
	cutscene_active = false
	# CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.SECURITY_SERVER_COMPLETED)
	print("🎬 Security server cutscene completed.")
	
	# Set everything visible first
	var root_scene := get_tree().current_scene
	if root_scene:
		for tilemap in root_scene.find_children("*", "TileMapLayer", true, false):
			if tilemap is TileMapLayer:
				(tilemap as TileMapLayer).visible = true
		if player_node:
			if player_node is CanvasItem:
				(player_node as CanvasItem).visible = true
	
	# Now fade in the environment
	await show_environment_and_characters(0.5)
	
	# Fade in the screen overlay to return to normal gameplay
	await fade_in(0.5)
	
	# Re-enable player control
	_set_player_active(true)
	print("🎬 Security server cutscene ended - returning to normal gameplay.")

# Transition to another scene and optionally play an animation
func transition_to_scene(target_scene_path: String, animation_name: String = "") -> void:
	"""Transition to another scene and optionally play an animation there"""
	print("🎬 Transitioning to scene: ", target_scene_path)
	
	# Dramatic fade out current scene before transition
	await dramatic_fade_out(2.0)
	
	# Hide dialogue UI
	_hide_dialogue_ui()
	
	# Change scene
	var tree := get_tree()
	if tree == null:
		print("⚠️ Cannot transition - tree is null")
		return
	
	var result: Error
	if ScenePreloader and ScenePreloader.is_scene_preloaded(target_scene_path):
		print("🚀 Using preloaded scene: ", target_scene_path.get_file())
		var preloaded_scene = ScenePreloader.get_preloaded_scene(target_scene_path)
		result = tree.change_scene_to_packed(preloaded_scene)
	else:
		print("📁 Loading scene from file: ", target_scene_path.get_file())
		result = tree.change_scene_to_file(target_scene_path)
	
	if result != OK:
		print("❌ Failed to change scene to: ", target_scene_path)
		return
	
	# Wait for scene to be ready
	await tree.process_frame
	await tree.process_frame
	
	# If animation name is provided, play it in the new scene
	if animation_name != "":
		var new_scene := tree.current_scene
		if new_scene:
			# Find AnimationPlayer in new scene
			var new_anim_player: AnimationPlayer = new_scene.get_node_or_null("AnimationPlayer")
			if new_anim_player == null:
				new_anim_player = new_scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
			
			if new_anim_player and new_anim_player.has_animation(animation_name):
				print("🎬 Playing animation '", animation_name, "' in new scene")
				new_anim_player.play(animation_name)
			else:
				print("⚠️ AnimationPlayer not found or animation '", animation_name, "' not available in new scene")
	
	# Fade in new scene
	await fade_in(0.5)

func _process(_delta: float) -> void:
	# Continuously disable movement during cutscene
	if cutscene_active and player_node != null:
		if "control_enabled" in player_node and player_node.control_enabled:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO

# ---- Environment visibility helpers ----
func hide_environment_and_characters(duration: float = 0.5) -> void:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return

	var elements_to_fade: Array[CanvasItem] = []
	
	for tilemap in root_scene.find_children("*", "TileMapLayer", true, false):
		if tilemap is TileMapLayer and (tilemap as TileMapLayer).visible:
			elements_to_fade.append(tilemap as CanvasItem)
	
	if player_node == null:
		player_node = _find_player()
	if player_node != null and player_node is CanvasItem and (player_node as CanvasItem).visible:
		elements_to_fade.append(player_node as CanvasItem)
	
	for child in root_scene.get_children():
		if child is Node2D and (String(child.name).to_lower().find("player") != -1):
			if child is CanvasItem and (child as CanvasItem).visible:
				elements_to_fade.append(child as CanvasItem)
	
	if elements_to_fade.is_empty():
		return

	print("🎬 Fading out ", elements_to_fade.size(), " environment elements")
	
	for element in elements_to_fade:
		element.modulate.a = 1.0
		element.visible = true
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	for element in elements_to_fade:
		tween.tween_property(element, "modulate:a", 0.0, duration)
	
	await tween.finished
	
	for element in elements_to_fade:
		element.visible = false
		element.modulate.a = 1.0
	
	print("🎬 Environment fade out complete")

func show_environment_and_characters(duration: float = 0.5) -> void:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return
	
	var elements_to_fade: Array[CanvasItem] = []
	
	for tilemap in root_scene.find_children("*", "TileMapLayer", true, false):
		if tilemap is TileMapLayer:
			elements_to_fade.append(tilemap as CanvasItem)
	
	if player_node == null:
		player_node = _find_player()
	if player_node != null and player_node is CanvasItem:
		elements_to_fade.append(player_node as CanvasItem)
	
	for child in root_scene.get_children():
		if child is Node2D and (String(child.name).to_lower().find("player") != -1):
			if child is CanvasItem:
				elements_to_fade.append(child as CanvasItem)
	
	if elements_to_fade.is_empty():
		return

	for element in elements_to_fade:
		element.visible = true
		element.modulate.a = 0.0
	
	print("🎬 Fading in ", elements_to_fade.size(), " environment elements")
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	for element in elements_to_fade:
		tween.tween_property(element, "modulate:a", 1.0, duration)
	
	await tween.finished
	print("🎬 Environment fade in complete")

# ---- Fade helpers ----
func _setup_fade() -> void:
	if fade_layer:
		return
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.offset_left = 0
	fade_rect.offset_top = 0
	fade_rect.offset_right = 0
	fade_rect.offset_bottom = 0
	fade_layer.add_child(fade_rect)
	print("🎬 Fade layer created with alpha: ", fade_rect.modulate.a)

func fade_in(duration: float = 0.5) -> void:
	if not fade_rect:
		_setup_fade()
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	print("🎬 Fade in starting from alpha: ", fade_rect.modulate.a)
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fade_rect, "modulate:a", 0.0, duration)
	await t.finished
	print("🎬 Fade in complete, alpha: ", fade_rect.modulate.a)
	fade_rect.visible = false

func fade_out(duration: float = 0.5) -> void:
	if not fade_rect:
		_setup_fade()
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fade_rect, "modulate:a", 1.0, duration)
	await t.finished

func dramatic_fade_out(duration: float = 2.0) -> void:
	"""Dramatic fade out with longer duration and smooth easing"""
	if not fade_rect:
		_setup_fade()
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	var t := create_tween()
	# Use QUART transition for more dramatic effect
	t.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	t.tween_property(fade_rect, "modulate:a", 1.0, duration)
	await t.finished
	print("🎬 Dramatic fade out complete")

# ---- Dialogue helpers ----
func show_line(index: int, auto_advance: bool = false) -> void:
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_lines[index]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui == null:
		print("⚠️ DialogueUI autoload not found.")
		return
	if dui.has_method("show_dialogue_line"):
		dui.show_dialogue_line(speaker, text, auto_advance)
		return
	print("⚠️ DialogueUI missing show_dialogue_line().")

func wait_for_next() -> void:
	_set_player_active(false)
	if player_node != null:
		if "control_enabled" in player_node:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
	resume_on_next = true
	if anim_player:
		anim_player.pause()
		print("🎬 Animation paused, waiting for next_pressed")

func show_line_wait(index: int) -> void:
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	show_line(index, false)
	wait_for_next()

func show_dialogue_line_wait(speaker: String, text: String) -> void:
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui == null:
		print("⚠️ DialogueUI autoload not found.")
		return
	if dui.has_method("set_cutscene_mode"):
		dui.set_cutscene_mode(true)
	if dui.has_method("show_dialogue_line"):
		dui.show_dialogue_line(speaker, text, false)
		wait_for_next()
	else:
		print("⚠️ DialogueUI missing show_dialogue_line().")

func _on_dialogue_next() -> void:
	if player_node != null:
		if "control_enabled" in player_node:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
	if resume_on_next and anim_player:
		resume_on_next = false
		print("🎬 Resuming animation after next_pressed")
		anim_player.play()

func show_lines_sequence(lines: Array[Dictionary]) -> void:
	for line in lines:
		var speaker: String = String(line.get("speaker", ""))
		var text: String = String(line.get("text", ""))
		await show_dialogue_line_wait(speaker, text)

func hide_ui() -> void:
	_hide_dialogue_ui()

func _hide_dialogue_ui() -> void:
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("hide_ui"):
		dui.hide_ui()

func _load_dialogue_if_available() -> void:
	var path := "res://data/dialogues/security_server_cutscene.json"
	if not ResourceLoader.exists(path):
		print("⚠️ Dialogue file not found: ", path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("⚠️ Cannot open dialogue file: ", path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		print("⚠️ Invalid dialogue JSON format")
		return
	var section: Variant = (parsed as Dictionary).get("security_server_cutscene", {})
	if typeof(section) != TYPE_DICTIONARY:
		print("⚠️ Missing 'security_server_cutscene' section in dialogue file")
		return
	var arr: Variant = (section as Dictionary).get("dialogue_lines", [])
	if typeof(arr) == TYPE_ARRAY:
		for item in (arr as Array):
			if typeof(item) == TYPE_DICTIONARY:
				dialogue_lines.append(item as Dictionary)

# ---- Camera helpers ----
func shake_camera(intensity: float = 6.0, duration: float = 0.3) -> void:
	var cam: Camera2D = _get_camera_2d()
	if cam == null:
		print("⚠️ No Camera2D found to shake.")
		return
	var original_offset: Vector2 = cam.offset
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var steps := 10
	var step_duration: float = duration / float(steps)
	
	for i in range(steps):
		var fade_factor: float = 1.0 - (float(i) / float(steps))
		var current_intensity: float = intensity * fade_factor
		var rand_offset := Vector2(randf_range(-current_intensity, current_intensity), randf_range(-current_intensity, current_intensity))
		tween.tween_property(cam, "offset", original_offset + rand_offset, step_duration)
	
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(cam, "offset", original_offset, 0.12)
	await tween.finished

func _get_camera_2d() -> Camera2D:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam
	if has_node("Camera2D"):
		var c := get_node("Camera2D")
		if c is Camera2D:
			return c
	for child in get_tree().get_nodes_in_group("cameras"):
		if child is Camera2D:
			return child
	return null

# ---- Player helpers ----
func _find_player() -> Node:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return null
	
	var direct := root_scene.get_node_or_null("PlayerM")
	if direct != null:
		return direct
	
	var candidates := root_scene.find_children("*", "", true, false)
	for n in candidates:
		if String(n.name).to_lower().contains("playerm") or String(n.name).to_lower().contains("player"):
			return n
	
	return null

func _set_player_active(active: bool) -> void:
	if player_node == null:
		player_node = _find_player()
	if player_node == null:
		print("⚠️ Cannot set player active - player not found")
		return
	
	if not active:
		if "control_enabled" in player_node:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
		if player_node.has_method("set_process_input"):
			player_node.set_process_input(false)
		if player_node.has_method("set_physics_process"):
			player_node.set_physics_process(false)
		print("🎬 Player movement disabled")
	else:
		if player_node.has_method("enable_movement"):
			player_node.enable_movement()
		if player_node.has_method("set_process_input"):
			player_node.set_process_input(true)
		if player_node.has_method("set_physics_process"):
			player_node.set_physics_process(true)
		if "control_enabled" in player_node:
			player_node.control_enabled = true
		print("🎬 Player movement enabled")
